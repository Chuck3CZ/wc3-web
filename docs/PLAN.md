# WC3 1.26a v prohlížeči – plán a stav

> **Na začátku každého sezení si přečti tento soubor.** Na konci každého kroku ho aktualizuj, commitni a pushni.

## Stav (2026-10-27)

| Fáze | Stav |
|---|---|
| 0 – průzkum | **hotovo** (tento dokument) |
| 1 – překlad: krok 4 (strom repa) | **hotovo** – `tools/import_nfsu2.sh`, `docs/ORIGIN.md` |
| 1 – překlad: krok 5 (lift, gen.sh/build.sh) | další |
| 2 – spuštění až po hlavní menu v Chrome | – |
| 3+ – vstup, skirmish, zvuk, LAN, Docker/QNAP, videa | jen plán (níže) |

**Další krok:** krok 5 – nainstalovat do `~` wasi-sdk 34, Node 20, Rust; `prepare_module.py` + `genall.py` na
war3.exe, Game.dll, Storm.dll, msvcr80.dll (pak Mss32, ijl15); `gen.sh`/`build.sh` pro WC3 s kontrolou SHA-256.

### Krok 4 – co je v repu (2026-10-27)

`tools/import_nfsu2.sh` zkopíroval z nfsu2-web `606ee35` 277 souborů (4,9 MB, žádné binárky): lifter a jeho analýzy
(`tools/`), obecný runtime (`runtime/`, `runtime/web/`), web host/GPU/audio/síť (`web/src/`), Rust server bez crates
`online`, `roam`, `roamload`, `vault`, `names` (`web/server-rs/`), nasazení (`web/deploy/`), testy bez hry. Seznam je
v tom skriptu; vše ostatní (kariéra, drift, free roam, klaksony, Online, DirectInput, D3DX, macOS/Metal, stránky
aplikace NFSU2, Discord bot) zůstalo venku.

**Ještě nezkompilovatelné** – úklid při prvním buildu (krok 5/6), s kompilátorem, ne naslepo:
- odkazy z ponechaných souborů na odstraněný kód (`tools/survey/deadrefs.py ~/nfsu2-web .`, ~100 výskytů):
  `com.c` 30 (widescreen, dinput, d3dx, headlights, overrides), `web/main_web.c` 15 (registrace NFSU2 modulů),
  `debug.c` 9, `web/status_web.c` 7, `win32.c` 6, `dispatch.c` 4 (d3dx), `web/input_web.c` 4, `net_proto.h` 4 (roam),
  `win32_ext.c` 4 (framerate, language), `winsock.c` 4 (Online), `web/gpu_web.c` 3, `perflog.c` 2,
  `web/audio_web.c` 2 (carsfx, horn), drobnosti v `cpu.h`, `heap.c`, `lifecycle.c`, `web/gcpu.c`;
- include odstraněných hlaviček: `enhance.h`, `widescreen.h`, `texrep.h`, `dxrec.h` (com.c, vsemu.c, win32.c),
  `gamepad.h`, `roam_plat.h`, `racenet.h`, `horn.h`, `carsfx.h` (runtime/web);
- `web/build.sh`/`build.mjs`/`gen.sh` stále sestavují NFSU2 (SPEED2.EXE, server.dll, stránky aplikace) → přepsat pro WC3;
- `web/server-rs/Cargo.toml` (workspace) stále jmenuje odstraněné crates;
- 156 souborů obsahuje jména `NFSU2_*`/`SPEED2`/`nfsu2` (proměnné prostředí, logy) → přejmenovat na `WC3_*`.

**Git:** lokální repo `~/wc3-web`, remote `origin` = `github.com/Chuck3CZ/wc3-web` (soukromé), větev `main`. WSL nemá
vlastní přihlášení: repo má v lokálním configu `credential.helper` = Windows Git Credential Manager
(`/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe`). Git ve WSL je 2.25 (`git init -b` neumí).

## Prostředí

- PC: Windows 10 + WSL 2, Ubuntu 20.04, Python 3.8 (bez sudo; `pefile 2024.8.26` a `capstone 5.0.7` přes `pip --user`).
- Pracovní kopie: `~/wc3-web` (repo), `~/nfsu2-web` (zdroj, commit `606ee35`, 2026-10-26).
- Hra: `/mnt/c/Users/Chuck/Desktop/Warcraft 3 Frozen-Throne CZ full HD + maps/Warcraft III` (jen čtení, česká verze).
- Ještě chybí (fáze 1): wasi-sdk 34, Node.js 20+ (nvm), Rust (rustup) – vše do `~`, bez sudo. Ověřit, že binárky wasi-sdk
  34 běží na glibc 2.31 z Ubuntu 20.04; jinak novější distro ve WSL.
- Cíl provozu: Docker na QNAP TVS-485 (AMD RX-421BD, 32 GB RAM).

## Vstupní soubory (1.26a)

Verze je **ověřená**: `war3.exe` i `Game.dll` mají ve version resource `1, 26, 0, 6401` (= 1.26a), Patch.txt začíná
„AKTUALIZACE 1.26“.

| Soubor | Velikost | SHA-256 | Verze | Image base | SizeOfImage | Relokace (HIGHLOW) | Importy | Exporty |
|---|---:|---|---|---|---|---:|---:|---:|
| war3.exe | 471 040 | `28173101fcbeb4cdcac0f83e0e724aa444209b479a2ac1c1784e0d4310889909` | 1.26.0.6401 | 0x00400000 | 0x07D000 | **žádné** | 494 | 708 |
| Game.dll | 12 042 240 | `6d21bd9a0f9fbc8446f455c9e89ac994fed68174426fe608fcb9baefd4dec53c` | 1.26.0.6401 | 0x6F000000 | 0xBB5000 | 401 895 | 668 | 1 (`GameMain`) |
| Storm.dll | 339 968 | `eecc42b05a91413dee10588a654c6cca05836e7513af6c7c568a56124bf97d0a` | 1.09 | 0x15000000 | 0x061000 | 6 244 | 259 | 459 |
| Mss32.dll | 347 648 | `1f9a83f42de0e7899a7f6772e5cbad6ed10c16cc5f15246c8d80b9f4fe25fc4a` | Miles 6.1d | 0x21100000 | 0x05F000 | 10 498 | 132 | 353 |
| ijl15.dll | 372 736 | `334aa12f7dee453d1c6cb1b661a3bb3494d3e4cc9c2ff3f9002064c78404e43a` | 1.5.4.36 | 0x60000000 | 0x05D000 | 4 203 | 59 | 6 |
| msvcr80.dll | 626 688 | `02bdde38e4c6bd795a092d496b8d6060cdbe71e22ef4d7a204e3050c1be44fa9` | 8.0.50727.762 | 0x78130000 | 0x09B000 | 6 078 | 161 | 1 466 |
| msvcp80.dll | 548 864 | `2026f3c4f830dff6883b88e2647272a52a132f25eb42c0d423e36b3f65a94d08` | 8.0.50727.762 | 0x7C420000 | 0x087000 | 6 149 | 134 | 3 178 |
| blizzard.ax | 606 208 | `a52741551312d81198d713e75e08740b115e5a74988dcec4dafd931d0841ece5` | 5.0.2 | 0x1C400000 | 0x096000 | 3 062 | 113 | 5 |
| Frozen Throne.exe | 274 432 | `2b13e318be8b41deffa80c3bd7fdec20de9688d5ceedfbb56cf43d4996a62bed` | 1.5.0.0 | 0x00400000 | 0x044000 | žádné | 96 | 0 |
| Warcraft III.exe | 274 432 | `5e64bf5061a9d72b4b9eb6aa3e646d3727deb2c087a5887f5c3bcdafe8751f92` | 1.0.0.1 | 0x00400000 | 0x044000 | žádné | 96 | 0 |
| redist/miles/Mp3dec.asi | 125 952 | `45295e1aae5211d2d32dae22fcc1d328db9d15d5a37bd0af3b4eb1a9a24c275a` | 6.1d | 0x26F00000 | 0x02A000 | 2 868 | 45 | 0 |
| redist/miles/Mssfast.m3d | 64 000 | `0215e58966f23bda2f6bd821d91627897e7a878f4e0b8a446c729188beec3e54` | 6.1d | 0x22600000 | 0x016000 | 1 191 | 72 | 0 |
| redist/miles/Mssdolby.m3d | 65 536 | `c7c1b5fe0c7da4203a24f1a98ddd337285094399d864c26e27f2fc6a15046431` | 6.1d | 0x22700000 | 0x017000 | 1 229 | 72 | 0 |
| redist/miles/Msseax2.m3d | 70 144 | `56ac180cbf80e353f7baf170b96f69e634e927a442248438d304785cb8070e9e` | 6.1d | 0x22C00000 | 0x018000 | 1 311 | 60 | 0 |
| redist/miles/Reverb3.flt | 56 832 | `3fa324230a19a20d2fe83731d79a718944863cebfc6bbb43c9640a595f8bd302` | 6.1d | 0x24600000 | 0x011000 | 921 | 46 | 0 |

- **`binkw32.dll` ve hře není.** Videa (`Movies/*.mpq`) jsou ve skutečnosti RIFF AVI s kodekem **BLZ0** (fourcc `divx`,
  varianta MPEG-4 ASP) a přehrávají se přes DirectShow filtr `blizzard.ax` (`war3.exe`: `LoadLibrary("blizzard.ax")` +
  `DllRegisterServer`). ffmpeg BLZ0 dekóduje jako mpeg4 → převod do AV1 je proveditelný (fáze 3+).
- `Frozen Throne.exe` / `Warcraft III.exe` jsou jen spouštěče (`CreateProcess` na `war3.exe`), nepřekládáme je. Hru
  spouštíme přímo: `war3.exe -window` (bez `-classic` = TFT).
- `msvcp80.dll` žádný z modulů neimportuje → nepotřebujeme ho.
- MPQ: `war3.mpq` 457 555 861 B, `War3x.mpq` 354 772 367 B, `War3xlocal.mpq` 50 477 946 B, `War3Patch.mpq`
  37 068 262 B (cca 900 MB celkem; SHA-256 MPQ spočítat v kroku 5 do gen.sh).
- Ve složce je i `enbconvertor.ini` (zbytek po ENB/d3d8-to-d3d9 wrapperu); žádné `d3d8.dll` ve složce není, takže se nic
  nepodstrčí.

### Kdo co importuje (staticky)

| Modul | DLL (počet funkcí) |
|---|---|
| war3.exe | KERNEL32 112, USER32 96, mss32 110, MSVCR80 52, Storm 51 (ordinály), WSOCK32 25, GDI32 16, COMCTL32 13, SHELL32 7, ADVAPI32 6, IMM32 2, comdlg32 2, WINMM 1, WININET 1 |
| Game.dll | KERNEL32 111, Storm 112 (ordinály), mss32 110, USER32 104, MSVCR80 85, **OPENGL32 50**, GDI32 25, WSOCK32 25, COMCTL32 13, IMM32 9, ADVAPI32 7, SHELL32 7, ijl15 3, ole32 3, comdlg32 2, WINMM 1, WININET 1 |
| Storm.dll | KERNEL32 84, USER32 74, MSVCR80 57, GDI32 29, ADVAPI32 11, VERSION 3, comdlg32 1 |
| Mss32.dll | KERNEL32 86, WINMM 35, USER32 11 |
| ijl15.dll | KERNEL32 59 |

### Dynamické načítání (LoadLibrary / GetProcAddress)

Zjištěno heuristikou `tools/survey/dynload.py` (řetězce pushnuté před voláním; „?“ = jméno počítané za běhu).

| Modul | LoadLibraryA | GetProcAddress |
|---|---|---|
| war3.exe | **`Game.dll`**, `blizzard.ax`, `mswsock.dll`, `ws2_32.dll`, `kernel32.dll`, ? | **`GameMain`**, `DllRegisterServer`, `AcceptEx`, `GetAcceptExSockaddrs`, `WSAIoctl`, `WSARecv`, `WSASend`, `GetDiskSpaceExA`, `GetSystemDefaultUILanguage`, `TryEnterCriticalSection`, `CheckRevision`, `ExtraWork` |
| Game.dll | **`d3d8.dll`**, `mswsock.dll`, `ws2_32.dll`, `advapi32.dll`, `kernel32.dll`, ? | **`Direct3DCreate8`**, `AcceptEx`, `GetAcceptExSockaddrs`, `WSAIoctl`, `WSARecv`, `WSASend`, `GetDiskSpaceExA`, `GetSystemDefaultUILanguage`, `TryEnterCriticalSection`, `CheckRevision`, `ExtraWork`, ? |
| Storm.dll | `advapi32.dll`, `ddraw.dll`, `dbghelp.dll`, `kernel32.dll`, `%s%s` (SNP) | `Crypt*` (8× – podpisy MPQ), `DirectDrawCreate`, `Sym*`/`StackWalk` (crash dump), `IsDebuggerPresent`, `SnpBind`/`SnpQuery`, `TryEnterCriticalSection` |
| Mss32.dll | **`DSOUND.DLL`**, `user32.dll`, ? (pluginy z `redist\miles`) | **`DirectSoundCreate`**, `DirectSoundEnumerateA`, `DLS*` (jen MIDI), `IsProcessorFeaturePresent`, `MessageBoxA`, … |
| ijl15.dll | `user32`, `advapi32` | `Reg*`, `MessageBoxA`, … (jen chybové cesty) |

Důsledky:
- `CheckRevision`/`ExtraWork` jsou Battle.net (stahované DLL) → mimo rozsah, `LoadLibrary` selže.
- `Sym*`, `StackWalk`, `ddraw`, `SnpBind` → nechat `LoadLibrary` selhat (Storm s tím počítá).
- Miles načítá pluginy z `redist\miles` přes `FindFirstFile` + `LoadLibrary` → překládáme jako moduly
  `Mp3dec.asi` (hudba MP3) a `Mssfast.m3d` (2D/3D zvuk), ostatní `.m3d`/`.flt` nechat najít jen pokud je hra vyžaduje.

## Odhad velikosti kódu

`tools/survey/fncount.py` (lineární průchod; cíle přímých `call` + ukazatele z relokací do `.text`; horní mez – část
ukazatelů jsou cíle jump-tabulek, které JTSWITCH nezapočítá):

| Modul | .text | instrukcí | kandidátů na funkce |
|---|---:|---:|---:|
| Game.dll | 0x86B60A (8,8 MB) | ~3,56 M | ~64 500 (32 287 call + 32 996 ukazatelů) |
| war3.exe | 0x54AC4 | ~146 k | ~1 350 |
| msvcr80.dll | 0x6272A | ~141 k | ~1 550 |
| Mss32.dll | 0x377D2 | ~80 k | ~930 |
| Storm.dll | 0x3FBFA | ~92 k | ~840 |
| ijl15.dll | 0x4D5DA | ~84 k | ~490 |

Pro srovnání: SPEED2.EXE má `.text` 0x381AF1 (3,7 MB) a ~23 000 funkcí → wasm 35 MB. **Game.dll je ~2,4× větší** →
očekávám wasm **~80–100 MB** (pak zkusit `-Oz` na studené shardy, brotli na přenos; Cloudflare/HTTP cache drží modul
podle hashe).

## Co převzít z nfsu2-web

### Obecné (převzít, příp. upravit)

| Oblast | Soubory nfsu2-web | Poznámka pro WC3 |
|---|---|---|
| Lifter x86 → C | `tools/lift.py`, `genall.py`, `lregs.py`, `flagabi.py`, `argcount.py`, `inline_pick.py`, `isatest.py`, `fuzzisa.py`, `genstamp.sh`, `disasm.py` | beze změny; jen víc modulů |
| Relokace / druhý modul | `tools/prepare_module.py`, `runtime/module.c`, `module.h` | **základ** pro přesun Game.dll/Storm/Mss32/ijl15/msvcr80; zobecnit na N modulů |
| `reloc2.py` | ruční parser vynulované relokační tabulky SPEED2.EXE | pro WC3 **nepotřeba** (DLL mají normální `.reloc`, war3.exe relokace nemá a zůstává na 0x400000) |
| CPU, dispatch, paměť | `runtime/cpu.h`, `dispatch.c`, `genexec.c`, `mem.c`, `heap.c`, `modheap.c` | `DISPATCH_TEXT_BASE/SIZE` je natvrdo SPEED2 → tabulka rozsahů po modulech; `GUEST_END` a rozložení paměti nové (níže) |
| Win32 | `win32.c`, `win32_ext.c` (vlákna, GIL – ticket lock, eventy, mutexy, pacer), `fileio.c` (WASI soubory, `/data` + `/save` overlay, registry.txt), `keyboard.c`, `lifecycle.c`, `debug.c`, `watchdog.c`, `perflog.c` | doplnit chybějící API (níže); natvrdo zadané adresy SPEED2 vyhodit |
| D3D9 + shadery | `com.c` (D3D9/DSound COM), `d3d9_tables.h`, `vsemu.c` + `web/vsemu_wgsl.inc` (VS/PS → WGSL), `web/gpu_web.c`, `gpu_proto.h`, `docs/web/gpu-abi.md` | základ pro D3D8; `d3dx_hle.c` WC3 nepotřebuje |
| Zvuk | `com.c` (DirectSound), `web/audio_web.c`, `audio_proto.h`, `web/src/audio/*` (AudioWorklet) | Miles bude výstup do DirectSound bufferů |
| Winsock + virtuální LAN | `winsock.c/.h`, `net_vlan.c`, `web/net_lan.c`, `lan_vfd.h`, `net_proto.h`, `web/src/net/*`, server `crates/lan`, `crates/ws` | WSOCK32 má všech 25 funkcí, které WC3 importuje; chybí IOCP/AcceptEx/WSARecv/WSASend |
| Web host | `web/src/host/*` (procesy/workery, WASI I/O worker, OPFS cache bloků, datacache), `web/src/gpu/*` (WebGPU encoder, DXT), `web/src/input/{index,keymap,proto,synth}.ts`, `web/src/app/{loader,logs,lastgame,shell,settings,savefs,status,display,device,overlay,i18n,predownload,instance,page-id,checks}.ts`, `sw.ts`, `web/build.mjs`, `web/build.sh`, `web/gen.sh` | NFSU2 texty/ovládání pryč |
| Web runtime | `runtime/web/{main_web,input_web,status_web,null_platform,sha256,stackprobe,thread_exit,memchk,memcmp,tz,gcpu}.c`, `compat/`, `ticketlock.h`, `host_abi.h` | |
| Server (Rust) | `web/server-rs` crates `http`, `headers`, `util`, `lan`, `ws`, `bans`; `src/app/{blocks,files,manifest,etag,kept,wasm,run,pool,url,control}.rs`, `Dockerfile` | `online`, `roam*`, `vault`, `names` vyhodit/odložit |
| Testy | `web/tools/run-page.mjs`, `isatest.sh`, `aliastest.sh`, test pages `hostcheck` | Playwright screenshoty |

### Specifické pro NFSU2 (nepřebírat)

`career.c`, `drift*.c`, `roam*.c` (free roam), `racenet.c`, `mprace.c`, `online.c`, `carsfx.c`, `carshadow.c`,
`headlights.c`, `horn*.c`, `racehorn.c`, `hornmenu.c`, `sms.c`, `sponsors.c`, `powerunits.c`, `tunegraph.c`,
`photo.c`, `lobbyclick.c`, `menusize.c`, `widescreen.c`, `language.c` (Thai patch), `movie.c` (VP6 hooky),
`intro.c`, `enhance.c`, `discord.c`, `overrides.c` (adresy SPEED2 – mechanismus ponechat prázdný), `framerate.c`
(30fps opravy NFSU2; pacer z win32_ext stačí), `dinput_*.c`/`dikeys.c`/`gamepad*` (WC3 DirectInput nepoužívá),
`d3dx_hle.c`, všechny `*.m` (macOS/Metal), `autotest.c` (skripty NFSU2; mechanismus možná později), `discord-bot/`,
`tools/` pro kariéru/drift/roam/langpacks/musicpack/texpacks/movies_av1, web `app/` části crews, drift, horn, nitro,
photo, quickchat, vault, wheel, lobby, players, touch/padnav.

## Potřebná API: co runtime má a co chybí

`tools/survey/apidiff.py`: sjednocení importů war3.exe + Game.dll + Storm + Mss32 + ijl15 (mimo vzájemné importy
přeložených modulů) + dynamicky získané funkce, porovnané s identifikátory, které runtime nfsu2-web rozpoznává
(řetězce v `runtime/*.c` – jen orientačně, „má“ neznamená plně implementované).

| DLL | potřeba | má | chybí | Hlavní chybějící / poznámka |
|---|---:|---:|---:|---|
| KERNEL32 | 175 | 132 | 43 | **IOCP** (`CreateIoCompletionPort`, `Get/PostQueuedCompletionStatus`), **`CreateFileMappingA`/`MapViewOfFile`** (Storm, war3), `GetTempPathA`, `FormatMessageA`, `GetVolumeInformationA`, locale (`GetUserDefaultLCID`, `CompareStringA/W`, `GetDate/TimeFormatA`), `lstr*`, `MulDiv`, `OpenEventA/OpenMutexA`, `CreateProcessA` (selhat) |
| USER32 | 129 | 41 | 88 | okno/zprávy pro -window: `GetDC/ReleaseDC`, `ClientToScreen/ScreenToClient`, `ClipCursor`, `GetKeyState`, `SetTimer/KillTimer`, `AdjustWindowRectEx`, `CallWindowProcA`, `Set/GetPropA`, `ChangeDisplaySettings*`, `EnumDisplaySettingsA`, `SystemParametersInfoA`, `LoadImageA`, `CreateCursor`, schránka (`Open/Get/SetClipboardData`); dialogy/menu (`CreateDialogIndirectParamA`, `*Menu*`) jen stuby |
| MSVCR80 | 115 | 1 | 114 | celé CRT – **doporučuji přeložit `msvcr80.dll` jako modul** a nativně přepsat jen horké funkce (`memcpy/memset/memmove/strlen/_ftol`…) |
| GDI32 | 42 | 2 | 40 | DC/DIB/region/text stuby (`CreateCompatibleDC`, `GetDIBits`, `SelectObject`, `GetTextMetricsA`, `Get/SetDeviceGammaRamp`…); pixel format jen pro OpenGL |
| OPENGL32 | 50 | 0 | 50 | jen režim `-opengl`; **nepoužijeme** (D3D8 je výchozí) – stuby / alternativa, kdyby D3D8 nešlo |
| WINMM | 35 | 1 | 34 | `waveOut*`/`midiOut*`/`mixer*`/`aux*` z Mss32 – stačí „žádné zařízení“, Miles jede přes DirectSound |
| D3D8 | 1 | 0 | 1 | `Direct3DCreate8` → nová vrstva `d3d8.c` nad `com.c` |
| DSOUND | 2 | 1 | 1 | `DirectSoundEnumerateA` |
| WSOCK32 | 25 | 25 | 0 | vše |
| WS2_32 / MSWSOCK | 5 | 1 | 4 | `WSARecv`, `WSASend`, `AcceptEx`, `GetAcceptExSockaddrs` (overlapped + IOCP – síťová vrstva Game.dll) |
| ADVAPI32 | 20 | 8 | 12 | `Crypt*` (Storm ověřuje podpisy MPQ – vracet „bez podpisu/OK“), `GetUserNameA`, `RegQueryInfoKeyA`, `RegFlushKey`, `FreeSid` |
| IMM32 | 9 | 0 | 9 | IME – stuby „bez IME“ |
| COMCTL32 | 13 | 0 | 13 | `ImageList_*` (kurzor drag), `InitCommonControlsEx`, `_TrackMouseEvent` – stuby |
| SHELL32 / COMDLG32 / OLE32 / VERSION / WININET | 7 / 2 / 3 / 3 / 1 | 0 | 16 | `ShellExecuteA` (odkazy) no-op, `CoInitialize` OK, `CoCreateInstance` (DirectShow videa) selhat, `GetFileVersionInfo*` z PE resource, `InternetCanonicalizeUrlA` |
| **celkem** | **637** | **212** | **425** | (`out/survey/apidiff.txt` má úplný seznam) |

Další věci mimo tabulku:
- **Vazby mezi přeloženými moduly**: Game.dll a war3.exe importují Storm **ordinály** (112 + 51), mss32 (110), ijl15,
  MSVCR80. nfsu2-web váže každý IAT slot na HLE (`IMP_MAGIC + index`); tady musí loader IAT vyplnit **adresou exportu**
  přeloženého modulu (a ordinály rozlišit).
- **SEH / C++ výjimky**: všechny moduly importují `__CxxFrameHandler3` a `_except_handler4_common`, nikdo
  `_CxxThrowException`. runtime nfsu2-web nemá dispatch SEH (`RaiseException` jen loguje). Pro první spuštění stačí; pokud
  hra používá `__try` pro řízení toku (Storm?), doplnit SEH chain přes `fs:[0]` (lifter už `fs` adresuje přes TEB).
- **Vstup**: WC3 nepoužívá DirectInput; jen zprávy okna (`WM_KEYDOWN/WM_CHAR/WM_MOUSEMOVE/WM_*BUTTON*`), `GetKeyState`,
  `GetCursorPos/SetCursorPos`, `ClipCursor`. Fronta zpráv (`PeekMessageA`, `kbd_post`, `win32_post_message`) v runtime je.
- **Vlákna**: `_beginthreadex` (CRT) → `CreateThread`; GIL z nfsu2-web beze změny.
- **TLS**: `TlsAlloc` (war3, Game, msvcr80); msvcr80 navíc `FlsAlloc` přes GetProcAddress (vracet NULL → CRT použije TLS).

## Rozložení paměti

Přeložený kód má absolutní adresy zapečené v C, takže každou DLL **přeložíme už přesunutou** na pevnou bázi
(`prepare_module.py` – kopie relokovaná na bázi; za běhu `module.c` namapuje originál a aplikuje jeho vlastní
relokace → stejné bajty, ověřeno SHA-256). Game.dll na 0x6F000000 leží mimo prostor hosta `[0, GUEST_END)`
(nfsu2: heap VA 0x08000000–0x28000000), proto přesun.

| Rozsah | Obsah | Pref. base |
|---|---|---|
| 0x00000000–0x00010000 | null guard | |
| 0x00400000–0x0047D000 | **war3.exe** (bez relokací – musí zůstat) | 0x00400000 |
| 0x00500000–0x00561000 | Storm.dll | 0x15000000 |
| 0x00580000–0x005DF000 | Mss32.dll | 0x21100000 |
| 0x00600000–0x0065D000 | ijl15.dll | 0x60000000 |
| 0x00680000–0x0071B000 | msvcr80.dll | 0x78130000 |
| 0x00740000–0x0076A000 | Mp3dec.asi | 0x26F00000 |
| 0x00770000–0x00786000 | Mssfast.m3d | 0x22600000 |
| 0x00790000–0x007A1000 | Reverb3.flt (jen bude-li potřeba) | 0x24600000 |
| 0x00BE0000–0x00C00000 | Winsock hostent buffery (jako nfsu2) | |
| 0x00C00000–0x01000000 | TEB | |
| 0x01000000–0x01BB5000 | **Game.dll** (11,7 MB) | 0x6F000000 |
| 0x02000000–0x03000000 | hlavní zásobník 16 MB | |
| 0x03000000–0x05000000 | zásobníky vláken | |
| 0x05000000–0x08000000 | `VirtualAlloc` mimo heap, `MapViewOfFile` | |
| 0x08000000–0x38000000 | heap VA 768 MB (`GUEST_END = 0x38000000`) | |
| 0x38000000– | data runtime, C zásobníky, malloc (`--global-base=0x38000000`); initial 1,25 GB, max 4 GB | |

Dispatch: `DISPATCH_TEXT_BASE/SIZE` → tabulka `{lo, hi, fn_addr[], fn_ptr[]}` pro každý modul (war3, Game, Storm,
Mss32, ijl15, msvcr80, pluginy). `GetModuleHandle("game.dll")` vrátí 0x01000000. Mapy s memory hacky počítají s
0x6F000000 → nefungují (s tím se počítá).

## Fáze a odhad práce

Odhad v pracovních sezeních (jedno sezení ≈ několik hodin práce agenta); nejistota je velká hlavně ve fázi 2.

| Krok | Obsah | Odhad |
|---|---|---|
| 4 | strom repa z obecných částí nfsu2-web, odstranit NFSU2, build skripty | 1 |
| 5 | lift war3.exe, Game.dll, Storm, msvcr80, Mss32, ijl15; opravy lifteru; `gen.sh`/`build.sh` s SHA-256; první link do wasm | 2–3 |
| 6 | N-modulový loader (IAT mezi moduly, ordinály, DllMain, TLS), CRT, KERNEL32/USER32 doplňky, MPQ přes WASI (Storm čte sám: CreateFile/ReadFile/SetFilePointer; ověřit MapViewOfFile) | 3–5 |
| 7 | D3D8 → D3D9: `IDirect3D8`/`IDirect3DDevice8` vtables jako tenké překladače (rozdíly: `SetVertexShader(FVF)`, `CreateImageSurface`, `CopyRects`, `GetBackBuffer`, `SetTextureStageState` vs. sampler states, `D3DPRESENT_PARAMETERS`, `SetRenderState(D3DRS_*)` číslování, lock flags) | 2–3 |
| 8 | hlavní menu v Chrome + Playwright screenshot | 1–2 |
| 3a | myš/klávesnice: Pointer Lock (posun mapy u okraje, `ClipCursor`), Keyboard Lock (F1–F12, Esc), `GetKeyState` | 1–2 |
| 3b | skirmish proti AI, ukládání pozic (`Save/` do OPFS), výkon (profil, inline list) | 2–4 |
| 3c | zvuk: **přeložit Mss32 + Mp3dec.asi** (výstup přes existující DirectSound HLE → AudioWorklet); reimplementace AIL API (~110 funkcí, 3D zvuk, streamy, MP3) je záložní varianta | 1–2 |
| 3d | LAN 3 hráči: UDP 6112 broadcast (hledání her) + TCP 6112 přes virtuální LAN serveru; IOCP/AcceptEx/WSARecv/WSASend nad existujícím winsock.c | 2–3 |
| 3e | Docker image serveru, QNAP: data na datovém svazku (`/share/...`), ne na kořenovém disku v RAM; port ≠ 8080 (obsazen QTS) – např. 8086; Cloudflare Tunnel pro HTTPS (WebGPU + SharedArrayBuffer vyžadují secure context) | 1 |
| 3f | videa BLZ0 → AV1 (ffmpeg), přehrávač místo DirectShow (`CoCreateInstance` filter graph) | 1–2 |

**Celkem zhruba 20–30 sezení.** Nejrizikovější: velikost Game.dll (čas liftu/kompilace, velikost wasm, paměť
prohlížeče), N-modulový loader, SEH, IOCP v síťové vrstvě.

## Rizika a otevřené otázky

- **Velikost:** ~64 k kandidátů na funkce v Game.dll; kompilace wasi-sdk může trvat dlouho a modul ~80–100 MB. CPU
  RX-421BD na QNAPu jen servíruje, nekompiluje – build poběží na PC ve WSL.
- **Výkon v prohlížeči**: WC3 je CPU-bound (pathfinding, JASS VM). Inline list a override horkých funkcí podle profilu.
- **Playwright ve WSL**: Chrome ve WSL nemusí mít WebGPU (GPU). Záloha: Playwright na Windows proti serveru ve WSL
  (localhost forwarding).
- **CZ verze**: `War3xlocal.mpq` je česká lokalizace; nevadí, jen jiné texty.
- **Battle.net/Warden** mimo rozsah. Mapy s vlastním strojovým kódem (memory hacky 1.24–1.26) nepojedou.
- **Determinismus LAN**: WC3 LAN je lockstep; všichni 3 hráči musí mít **stejný** build modulu a stejná MPQ (server
  servíruje jednu kopii → splněno). Plovoucí čárka musí být bit-přesná mezi prohlížeči (x87 emulace v lifteru je
  deterministická – ověřit replay testem).

## Naměřená čísla

| Datum | Co | Hodnota |
|---|---|---|
| 2026-10-27 | kandidátů na funkce Game.dll (horní mez) | ~64 516 |
| 2026-10-27 | relokací HIGHLOW Game.dll | 401 895 |
| 2026-10-27 | importovaných systémových API (unikátní) | 637, z toho runtime rozpoznává 212 |

## Postup průzkumu (reprodukce)

```sh
tools/survey/run.sh "/mnt/c/Users/Chuck/Desktop/Warcraft 3 Frozen-Throne CZ full HD + maps/Warcraft III" ~/nfsu2-web
```
