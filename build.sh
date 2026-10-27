#!/bin/bash
# Compile the lifted modules (gen/<module>, made by ./gen.sh) to wasm objects.
#   ./build.sh [module ...]          (default: every module gen.sh made)
# Objects go to out/web/obj/<module>/; a content-addressed cache
# (~/.cache/wc3-web/obj, keyed by the shard, cpu.h and the flags) makes a
# rebuild after a partial re-lift cheap.  Linking the runtime and the page
# comes with step 6 (docs/PLAN.md); until then this is the check that every
# lifted shard compiles, with the numbers PLAN.md records.
#
# A module is refused when gen/<module>/stamp.txt is missing or incomplete,
# or names another lifter than this checkout's (the lift and the runtime must
# agree on cpu.h's macros).
set -e -o pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"; cd "$ROOT"
WASI="${WASI:-$ROOT/deps/wasi-sdk}"
[ -x "$WASI/bin/clang" ] || { echo "build.sh: wasi-sdk not found in deps/wasi-sdk (set WASI=...)"; exit 1; }
CC="$WASI/bin/clang"
J="${J:-$(nproc)}"
OPT="${OPT:--O3}"
TARGET="--target=wasm32-wasip1-threads -pthread"
FEAT="-msimd128 -mbulk-memory -mnontrapping-fptoint -mtail-call -mexception-handling -mllvm -wasm-enable-sjlj -mllvm -wasm-use-legacy-eh=false"
DEFS="-D_WASI_EMULATED_MMAN -D_WASI_EMULATED_SIGNAL -D_WASI_EMULATED_PROCESS_CLOCKS"
CFLAGS="$TARGET $OPT $FEAT $DEFS -fno-delete-null-pointer-checks -include runtime/web/compat/wasm_plat.h -Iruntime/web/compat -Iruntime"
# the lifted shards: guest memory as an object of its own (cpu.h)
SHARDFLAGS="-DNFSU2_GUEST_OBJ -Wno-unused-label -Wno-parentheses-equality"
CACHE="${OBJCACHE:-$HOME/.cache/wc3-web/obj}"; mkdir -p "$CACHE"
HDRSUM="$( (cat runtime/cpu.h runtime/web/compat/wasm_plat.h; "$CC" --version | head -1; echo "$CFLAGS $SHARDFLAGS") | sha256sum | cut -c1-16)"
LIFTER="lifter $(cat tools/lift.py tools/lregs.py tools/genall.py tools/argcount.py tools/prepare_module.py tools/ptrscan.py | sha256sum | cut -c1-16)"

MODS="$*"
[ -n "$MODS" ] || MODS="$(ls -d gen/*/ 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"
[ -n "$MODS" ] || { echo "build.sh: nothing in gen/ (run ./gen.sh first)"; exit 1; }

# one shard -> one object (run by xargs; prints "<status> <seconds> <bytes> <shard>")
compile_one(){
  src="$1"; mod="$2"; obj="$ROOT/out/web/obj/$mod/$(basename "${src%.c}").o"
  key="$( (cat "$src" "gen/$mod/decls.h"; echo "$HDRSUM") | sha256sum | cut -c1-32)"
  if [ -f "$CACHE/$key.o" ]; then cp "$CACHE/$key.o" "$obj"; echo "cached 0 $(stat -c%s "$obj") $src"; return; fi
  t0=$(date +%s.%N)
  if ! err=$($CC $CFLAGS $SHARDFLAGS -I"gen/$mod" -c -o "$obj" "$src" 2>&1); then
    echo "$err" | head -30 >&2; echo "FAILED 0 0 $src"; return 1
  fi
  cp "$obj" "$CACHE/$key.o.tmp$$" && mv "$CACHE/$key.o.tmp$$" "$CACHE/$key.o"
  echo "built $(awk -v a="$(date +%s.%N)" -v b="$t0" 'BEGIN{printf "%.2f", a-b}') $(stat -c%s "$obj") $src"
}
export -f compile_one; export ROOT CC CFLAGS SHARDFLAGS CACHE HDRSUM

FAIL=0
for MOD in $MODS; do
  G="gen/$MOD"
  [ -f "$G/stamp.txt" ] && ! grep -q '^incomplete' "$G/stamp.txt" || { echo "build.sh: $G is missing or incomplete (./gen.sh)"; exit 1; }
  grep -qxF "$LIFTER" "$G/stamp.txt" || { echo "build.sh: $G was lifted by another lifter than this checkout's (re-run ./gen.sh)"; exit 1; }
  mkdir -p "out/web/obj/$MOD"
  T0=$(date +%s)
  ls "$G"/*.c | xargs -P "$J" -I{} bash -c 'compile_one "$@"' _ {} "$MOD" > "out/web/obj/$MOD/build.log" || FAIL=1
  read -r NB NC NF SZ CPU <<<"$(awk '{n[$1]++; s+=$3; t+=$2} END{printf "%d %d %d %d %.0f", n["built"], n["cached"], n["FAILED"], s, t}' "out/web/obj/$MOD/build.log")"
  printf "  %-8s %4d objects (%d built, %d cached, %d FAILED)  %6.1f MB  %5d s wall, %6.0f s CPU\n" \
    "$MOD" $((NB + NC + NF)) "$NB" "$NC" "$NF" "$(awk -v s="$SZ" 'BEGIN{print s/1048576}')" $(( $(date +%s) - T0 )) "$CPU"
done
[ "$FAIL" = 0 ] || { echo "build.sh: some shards failed (out/web/obj/<module>/build.log)"; exit 1; }
