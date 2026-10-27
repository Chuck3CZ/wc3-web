# Warcraft III: The Frozen Throne in the browser

A fan project that aims to run the PC game *Warcraft III: The Frozen Throne* (patch 1.26a, 32-bit) in Google Chrome.
The game's x86 code is translated to C ahead of time and compiled to WebAssembly; Win32, Direct3D 8, sound and
Winsock are reimplemented, the graphics run on WebGPU. LAN play between browsers goes through the project's own server.
You bring your own copy of the game.

> Not affiliated with or endorsed by Blizzard Entertainment. This repository contains none of the game's code or
> data: no EXE, DLL or MPQ, no C translated from them, no compiled module (`.gitignore` keeps them out).

**Status:** phase 0 (survey). The plan, the state and the measured numbers are in [docs/PLAN.md](docs/PLAN.md).

## What you need

- **The game:** Warcraft III + The Frozen Throne patched to **1.26a** (`war3.exe` / `Game.dll` 1.26.0.6401). The exact
  files and their SHA-256 are in [docs/PLAN.md](docs/PLAN.md#vstupní-soubory-126a); other versions will not work.
- **To build:** Linux or WSL 2 (clone in the Linux file system, e.g. `~/wc3-web`), Python 3 with `pefile` and
  `capstone` 5, later Node.js 20+, Rust and wasi-sdk.

## Survey (phase 0)

```sh
tools/survey/run.sh "/path/to/Warcraft III"     # -> out/survey/ (never committed)
```

## Layout

- **`tools/`:** the x86 → C lifter (Python, Capstone) and its analyses; `tools/survey/` the phase 0 survey.
- **`runtime/`:** Windows, Direct3D, DirectSound and Winsock reimplemented; `runtime/web/` the browser parts.
- **`web/src/`:** the page's host: game threads as workers on one shared memory, WebGPU, AudioWorklet, the LAN link.
- **`web/server-rs/`:** the server, in Rust: serves the page, the module and the game folder, and is the virtual LAN.
- **`web/deploy/`:** Docker Compose, Caddy and Cloudflare Tunnel examples.

## Origin

The method, the lifter, the Win32/D3D9/sound runtime, the WebGPU and AudioWorklet host and the Rust server come from
[nfsu2-web](https://github.com/Chuck3CZ/nfsu2-web) (MIT), the browser port of *Need for Speed: Underground 2*, which
itself is based on Talha Müderrisoğlu's static recompilation of NFSU2 and follows the method of
[N64: Recompiled](https://github.com/N64Recomp/N64Recomp) and [XenonRecomp](https://github.com/hedge-dev/XenonRecomp).
Built with the help of Claude Code.

## License

MIT ([LICENSE](LICENSE)). *Warcraft* and *Warcraft III: The Frozen Throne* are trademarks of Blizzard Entertainment, Inc.
