// Host self-test page: runs a test module (?wasm=...) through the real host
// (pool, I/O worker, mounts) and reports its output; title becomes DONE.
import { startProcess } from '../host/process';
import { attachNet } from '../net/index';
import { attachRenderer } from '../gpu/index';
import { attachInput } from '../input/index';
import { attachAudio } from '../audio/index';
const q = new URLSearchParams(location.search);
const gpu = q.has('gpu');
const canvas = document.createElement('canvas');
if (gpu) { canvas.width = 1280; canvas.height = 720; canvas.style.cssText = 'display:block;width:1280px;max-width:100%;background:#000';
           document.body.append(canvas);
           const fs = document.createElement('button'); fs.textContent = 'Celá obrazovka'; fs.style.cssText = 'margin:6px 0;font-size:14px';
           fs.onclick = () => { canvas.requestFullscreen({ navigationUI: 'hide' }).then(() => canvas.focus(), e => console.log('fullscreen: ' + e)); };
           document.body.append(fs); }
const pre = document.createElement('pre'); document.body.append(pre);
if (gpu) pre.style.cssText = 'max-height:30vh;overflow:auto;font-size:11px';
// ?logpost: the log also goes to the server (POST /log, web/tools/wc3-dev-server.mjs keeps it in
// out/browser.log), so a run can be read without copying it from the page
const posting = q.has('logpost');
let outq: string[] = ['@@start ' + new Date().toISOString() + ' ' + location.search];
const flush = () => { if (!posting || !outq.length) return; const body = outq.join('\n') + '\n'; outq = [];
  fetch('/log', { method: 'POST', body, keepalive: true }).catch(() => {}); };
if (posting) setInterval(flush, 500);
const log = (s: string) => { pre.append(s + '\n'); console.log(s); if (posting) outq.push(s); };
const t0 = performance.now();
const mod = await WebAssembly.compileStreaming(fetch(q.get('wasm') ?? '/test/hostcheck.wasm'));
log(`compiled in ${(performance.now() - t0).toFixed(0)} ms`);
if (q.has('fresh')) {
  const root = await navigator.storage.getDirectory();
  for await (const [name] of (root as any).entries()) if (name === (q.get('save') ?? 'save-test')) await root.removeEntry(name, { recursive: true });
}
// ?reg=/tests/web/seed/x.txt: registry seed, copied in as /save/registry.txt
async function preload(url: string, name: string) {
  const txt = await (await fetch(url, { cache: 'no-store' })).text();
  const dir = await (await navigator.storage.getDirectory()).getDirectoryHandle(q.get('save') ?? 'save-test', { create: true });
  const w = await (await dir.getFileHandle(name, { create: true })).createWritable();
  await w.write(txt); await w.close();
}
const env0: Record<string, string> = {};
if (q.get('reg')) { await preload(q.get('reg')!, 'registry.txt'); env0.NFSU2_REGFILE = '/save/registry.txt'; }
// ?script=/tests/scripts/x.txt: an autotest input script, copied into the save dir
const env: Record<string, string> = env0;
if (gpu) env.NFSU2_RENDERER = 'webgpu';
const script = q.get('script');
if (script) {
  const txt = await (await fetch(script, { cache: 'no-store' })).text();
  const dir = await (await navigator.storage.getDirectory()).getDirectoryHandle(q.get('save') ?? 'save-test', { create: true });
  const w = await (await dir.getFileHandle('autotest-script.txt', { create: true })).createWritable();
  await w.write(txt); await w.close();
  env.NFSU2_INPUT_SCRIPT = '/save/autotest-script.txt';
}
const p = await startProcess({
  module: mod, pool: +(q.get('pool') ?? 24), initialPages: +(q.get('pages') ?? 1024),
  cfg: { args: ['nfsu2', ...(q.getAll('arg'))], env: { HOME: '/save', NFSU2_DATA: '/data', ...env, ...Object.fromEntries(q.getAll('env').map(e => [e.slice(0, e.indexOf('=')), e.slice(e.indexOf('=') + 1)])) }, dataBase: '/data/', manifestUrl: '/data-manifest', saveDir: q.get('save') ?? 'save-test' },
  onLog: (s, fd, tid) => log(`[${tid}${fd === 2 ? '!' : ''}] ${s}`),
  onNote: log,
});
if (gpu) {
  try {
    const r = await attachRenderer(p, canvas, { log });
    log('[page] WebGPU renderer attached');
    // mouse and keyboard over the picture (imageRect is in canvas pixels; the input wants CSS px)
    const inp = attachInput(p, canvas, { log, hideCursor: false, viewRect: () => {
      const ir = r.imageRect(), k = canvas.clientWidth / (canvas.width || 1);
      return { x: ir.x * k, y: ir.y * k, w: ir.w * k, h: ir.h * k }; } });
    (globalThis as any).wc3Input = inp;
    // sound: the context starts on the first click or key (the browser's rule)
    attachAudio(p, { log, gestureTarget: window }).then(a => { (globalThis as any).wc3Audio = a; log('[page] audio attached'); },
                                                       e => log('[page] no audio: ' + e));
    canvas.tabIndex = 0; canvas.focus();
    const every = +(q.get('shot') ?? 0);
    if (every > 0) setInterval(async () => {
      try { const png = await r.dump('shot'); await fetch('/shot', { method: 'POST', body: png }); }
      catch (e) { log(`[page] screenshot: ${e}`); }
    }, every * 1000);
  } catch (e) { log(`[page] no renderer: ${e}`); }
}
// ?net=<name>: the virtual LAN (web/src/net) under that player name; the notices the app shows over the game, logged
const net = q.has('net') ? attachNet(p, { name: q.get('net') || 'test', log, onNotice: t => log(`[notice] ${t}`), onLobby: j => log(`[lobby] ${j}`) }) : null;
(globalThis as any).nfsu2Net = net;
const code = await p.exited;
if (net) log(`NET ${JSON.stringify(net.stats())}`);
log(`EXIT ${code}`); flush(); document.title = 'DONE';
