// A small development server for the WC3 port, until the Rust server
// (web/server-rs) is adapted: the host and test pages, the module and the
// game folder, on 127.0.0.1 only.
//   node web/tools/wc3-dev-server.mjs --data "<Warcraft III folder>" [--port 8086]
// Serves
//   /test/*, /host/*, /gpu/*, /audio/*   web/dist-dev, web/dist (node web/build.mjs)
//   /wc3.wasm                            out/web/wc3.wasm (./build.sh)
//   /data-manifest                       every file of the game folder (the I/O worker's
//                                        manifest without "blocks": it reads byte ranges)
//   /data/<path>                         the game folder's files, with Range
//   POST /log                            the test page's log -> out/browser.log
//   POST /shot                           the test page's screenshot -> out/shot.png
// with the headers that make the page cross-origin isolated (SharedArrayBuffer).
// Port 8086: 8080 is the QNAP's admin page (docs/PLAN.md).
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const arg = (k, d) => { const i = process.argv.indexOf(k); return i > 0 ? process.argv[i + 1] : d; };
const DATA = arg('--data');
const PORT = +arg('--port', 8086);
const HOST = arg('--host', '127.0.0.1');   // 0.0.0.0: reachable from the LAN (Chrome there needs a secure origin)
if (!DATA || !fs.statSync(DATA, { throwIfNoEntry: false })?.isDirectory()) {
  console.error('usage: node web/tools/wc3-dev-server.mjs --data "<Warcraft III folder>" [--port 8086]'); process.exit(2);
}
const STATIC = [path.join(ROOT, 'web', 'dist-dev'), path.join(ROOT, 'web', 'dist')];
const TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.map': 'application/json', '.json': 'application/json',
  '.wasm': 'application/wasm', '.css': 'text/css', '.txt': 'text/plain; charset=utf-8' };
const ISOLATION = { 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp',
  'Cross-Origin-Resource-Policy': 'same-origin', 'Cache-Control': 'no-store' };

// the manifest: files and folders, '/'-separated paths relative to the game folder
function manifest() {
  const files = [];
  const walk = (dir, rel) => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const p = rel ? `${rel}/${e.name}` : e.name, full = path.join(dir, e.name);
      if (e.isDirectory()) { files.push({ p, d: 1 }); walk(full, p); }
      else if (e.isFile()) { const st = fs.statSync(full); files.push({ p, s: st.size, m: Math.floor(st.mtimeMs / 1000) }); }
    }
  };
  walk(DATA, '');
  return { files };
}
let MANIFEST = JSON.stringify(manifest());
console.log(`[dev-server] game folder ${DATA}: ${JSON.parse(MANIFEST).files.length} entries`);

// a path inside root, or null (no "..", no absolute paths)
function inside(root, rel) {
  const full = path.resolve(root, '.' + path.posix.normalize('/' + rel));
  return full === root || full.startsWith(root + path.sep) ? full : null;
}
function sendFile(req, res, full, type) {
  let st; try { st = fs.statSync(full); } catch { res.writeHead(404, ISOLATION).end('not found'); return; }
  if (!st.isFile()) { res.writeHead(404, ISOLATION).end('not found'); return; }
  const h = { ...ISOLATION, 'Content-Type': type ?? TYPES[path.extname(full).toLowerCase()] ?? 'application/octet-stream', 'Accept-Ranges': 'bytes' };
  const m = /^bytes=(\d+)-(\d*)$/.exec(req.headers.range ?? '');
  if (m) {
    const start = +m[1], end = m[2] ? Math.min(+m[2], st.size - 1) : st.size - 1;
    if (start >= st.size || end < start) { res.writeHead(416, { ...h, 'Content-Range': `bytes */${st.size}` }).end(); return; }
    res.writeHead(206, { ...h, 'Content-Range': `bytes ${start}-${end}/${st.size}`, 'Content-Length': end - start + 1 });
    if (req.method === 'HEAD') { res.end(); return; }
    fs.createReadStream(full, { start, end }).pipe(res);
  } else {
    res.writeHead(200, { ...h, 'Content-Length': st.size });
    if (req.method === 'HEAD') { res.end(); return; }
    fs.createReadStream(full).pipe(res);
  }
}

http.createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  const p = decodeURIComponent(url.pathname);
  // the test page's log (hostcheck.ts ?logpost): out/browser.log, started over by a new run
  // the test page's screenshot (hostcheck.ts ?gpu&shot=N): out/shot.png, replaced each time
  if (req.method === 'POST' && p === '/shot') {
    const parts = []; let n = 0;
    req.on('data', d => { parts.push(d); n += d.length; if (n > 32e6) req.destroy(); });
    req.on('end', () => {
      fs.writeFileSync(path.join(ROOT, 'out', 'shot.png'), Buffer.concat(parts));
      res.writeHead(204, ISOLATION).end();
    });
    return;
  }
  if (req.method === 'POST' && p === '/log') {
    let body = ''; req.setEncoding('utf8');
    req.on('data', d => { body += d; if (body.length > 8e6) req.destroy(); });
    req.on('end', () => {
      const f = path.join(ROOT, 'out', 'browser.log');
      if (body.startsWith('@@start')) fs.writeFileSync(f, body); else fs.appendFileSync(f, body);
      res.writeHead(204, ISOLATION).end();
    });
    return;
  }
  if (req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405, ISOLATION).end(); return; }
  if (p === '/data-manifest') { res.writeHead(200, { ...ISOLATION, 'Content-Type': 'application/json' }).end(MANIFEST); return; }
  if (p.startsWith('/data/')) { const f = inside(DATA, p.slice(6)); return f ? sendFile(req, res, f) : res.writeHead(403, ISOLATION).end(); }
  if (p === '/wc3.wasm') return sendFile(req, res, path.join(ROOT, 'out', 'web', 'wc3.wasm'));
  if (p === '/') { res.writeHead(302, { ...ISOLATION, Location: '/test/hostcheck.html' }).end(); return; }
  for (const root of STATIC) {
    const f = inside(root, p.slice(1));
    if (f && fs.existsSync(f) && fs.statSync(f).isFile()) return sendFile(req, res, f);
  }
  res.writeHead(404, ISOLATION).end('not found');
}).listen(PORT, HOST, () => console.log(`[dev-server] http://${HOST}:${PORT}/`));
