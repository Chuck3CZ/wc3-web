#!/bin/bash
# Lift Warcraft III 1.26a to C: every module the game runs, each at its fixed
# guest base (docs/PLAN.md "Rozložení paměti").
#   ./gen.sh "<Warcraft III folder>" [module ...]     (default: all modules)
# Writes gen/<module>/ (shards, decls.h, fntab.c, impargs.c, modinfo.c,
# stamp.txt) and out/mod/<module>/ (the relocated analysis copy, fixup slots,
# seeds, logs).  Both are made from the game and never committed.
#
# The input files must be the exact 1.26a ones: their SHA-256 are pinned
# below and anything else is refused (lifted code bakes in addresses, so
# another build of a DLL would run the wrong code).
#
# Lift options (tools/lift.py), web defaults:
#   X87PC=1   x87 precision control (PC=24 as on Windows)
#   X87OPT=1  x87 stack slots as locals within a block
#   JTSWITCH=1 MSVC jump tables as C switches
#   LREGS=1   guest registers and flags as C locals
# NSHARD_<MODULE> overrides a module's shard count.
set -e -o pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"; cd "$ROOT"
W="${1:-${WC3_DATA:-}}"
[ -d "$W" ] || { echo "usage: ./gen.sh \"<Warcraft III folder>\" [module ...]"; exit 1; }
shift || true
PY="${PY:-python3}"
"$PY" -c 'import pefile, capstone' 2>/dev/null || { echo "gen.sh: needs Python with pefile and capstone 5 (requirements.txt)"; exit 1; }

# module  file                     guest base  prefix    shards  sha256
MODULES="
war3     war3.exe                  0x00400000  war3_     16      28173101fcbeb4cdcac0f83e0e724aa444209b479a2ac1c1784e0d4310889909
storm    Storm.dll                 0x00500000  storm_    16      eecc42b05a91413dee10588a654c6cca05836e7513af6c7c568a56124bf97d0a
mss      Mss32.dll                 0x00580000  mss_      16      1f9a83f42de0e7899a7f6772e5cbad6ed10c16cc5f15246c8d80b9f4fe25fc4a
ijl      ijl15.dll                 0x00600000  ijl_      8       334aa12f7dee453d1c6cb1b661a3bb3494d3e4cc9c2ff3f9002064c78404e43a
crt      msvcr80.dll               0x00680000  crt_      16      02bdde38e4c6bd795a092d496b8d6060cdbe71e22ef4d7a204e3050c1be44fa9
mp3dec   redist/miles/Mp3dec.asi   0x00740000  mp3dec_   4       45295e1aae5211d2d32dae22fcc1d328db9d15d5a37bd0af3b4eb1a9a24c275a
mssfast  redist/miles/Mssfast.m3d  0x00770000  mssfast_  4       0215e58966f23bda2f6bd821d91627897e7a878f4e0b8a446c729188beec3e54
game     game.dll                  0x01000000  game_     512     6d21bd9a0f9fbc8446f455c9e89ac994fed68174426fe608fcb9baefd4dec53c
"
WANT=" $* "

export X87PC="${X87PC:-1}" X87OPT="${X87OPT:-1}" JTSWITCH="${JTSWITCH:-1}" LREGS="${LREGS:-1}"
h16(){ sha256sum | cut -c1-16; }
SOURCES="lifter $(cat tools/lift.py tools/lregs.py tools/genall.py tools/argcount.py tools/prepare_module.py tools/ptrscan.py | h16)"

# find a file case-insensitively in the game folder (Mss32.dll vs mss32.dll)
ifind(){ find "$W" -maxdepth 3 -ipath "$W/$1" -type f | head -1; }

echo "$MODULES" | while read -r MOD FILE BASE PFX NSH SHA; do
  [ -n "$MOD" ] || continue
  [ "$WANT" = "  " ] || [[ "$WANT" == *" $MOD "* ]] || continue
  SRC="$(ifind "$FILE")"
  [ -n "$SRC" ] || { echo "gen.sh: $FILE not found in $W"; exit 1; }
  GOT="$(sha256sum "$SRC" | cut -d' ' -f1)"
  [ "$GOT" = "$SHA" ] || { echo "gen.sh: $FILE is not the 1.26a file (sha256 $GOT, want $SHA)"; exit 1; }
  NV="NSHARD_${MOD^^}"; NSH="${!NV:-$NSH}"
  G="gen/$MOD"; O="out/mod/$MOD"
  mkdir -p "$G" "$O"; find "$G" -mindepth 1 -delete
  echo "incomplete: gen.sh has not finished (or failed)" > "$G/stamp.txt"
  T0=$(date +%s)
  if [ "$MOD" = war3 ]; then
    # the exe stays at its own base; it has no .reloc, so its pointers are scanned
    IMG="$SRC"
    "$PY" tools/ptrscan.py "$SRC" "$O" "$G" "$PFX" | sed "s/^/  $MOD: /"
  else
    IMG="$O/image.dll"
    "$PY" tools/prepare_module.py "$SRC" "$BASE" "$O" "$G" "$PFX" > "$O/prepare.log"
    sed -E 's/, exports .*//; s/^/  '"$MOD"': /' "$O/prepare.log"
  fi
  GENOUT="$G" RELOCS="$O/relocs.txt" SEEDS="$O/seeds.txt" SYMPFX="$PFX" \
    "$PY" tools/genall.py "$IMG" "$NSH" > "$O/genall.log" 2>&1 || { tail -20 "$O/genall.log"; echo "gen.sh: genall.py failed for $MOD"; exit 1; }
  grep -E "^  [0-9]+ functions|functions  *:|C source size|traps \(|truncated|MISSING|stubs\)" "$O/genall.log" | sed "s/^ */  $MOD: /"
  IMPD="$SRC"; [ "$MOD" = war3 ] && IMPD=""          # a DLL's import table is read from the unrelocated file
  RELOCS="$O/relocs.txt" IMPOUT="$G/impargs.c" SYMPFX="$PFX" IMPDLL="$IMPD" \
    "$PY" tools/argcount.py "$IMG" > "$O/argcount.log" 2>&1 || { tail -20 "$O/argcount.log"; echo "gen.sh: argcount.py failed for $MOD"; exit 1; }
  { echo "# gen.sh $(date -u +%Y-%m-%dT%H:%M:%SZ): $MOD lifted from $FILE"
    echo "$SOURCES"
    echo "input $FILE $SHA base $BASE"
    echo "options X87PC=$X87PC X87OPT=$X87OPT JTSWITCH=$JTSWITCH LREGS=$LREGS NSHARD=$NSH"; } > "$G/stamp.txt"
  echo "  $MOD: gen OK -> $G ($(ls "$G"/shard_*.c | wc -l) shards, $(( $(date +%s) - T0 )) s)"
done

# gen/modtab.c: the lifted modules for runtime/module.c, in this table's order
# (war3.exe first).  A module gen.sh has not lifted (yet) is left out; the
# runtime then refuses to load it.
{ echo "/* generated by gen.sh: the lifted modules (runtime/module.c) */"
  echo '#include "module.h"'
  N=0; ENTRIES=""
  while read -r MOD FILE BASE PFX NSH SHA; do
    [ -n "$MOD" ] && [ -f "gen/$MOD/fntab.c" ] && ! grep -q '^incomplete' "gen/$MOD/stamp.txt" || continue
    echo "extern const ModInfo g_${PFX}modinfo; extern const ImpEnt g_${PFX}imp[]; extern const uint32_t g_${PFX}imp_count;"
    echo "extern const uint32_t g_${PFX}fn_addr[]; extern const mod_fn g_${PFX}fn_ptr[]; extern const uint32_t g_${PFX}fn_count;"
    ENTRIES="$ENTRIES  { \"$MOD\", &g_${PFX}modinfo, g_${PFX}imp, &g_${PFX}imp_count, g_${PFX}fn_addr, g_${PFX}fn_ptr, &g_${PFX}fn_count },\n"
    N=$((N + 1))
  done <<< "$MODULES"
  echo "const ModEntry g_modtab[] = {"; printf "$ENTRIES"; echo "};"
  echo "const int g_modtab_count = $N;"
} > gen/modtab.c
echo "gen.sh: gen/modtab.c ($N modules)"
