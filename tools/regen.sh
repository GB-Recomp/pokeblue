#!/usr/bin/env bash
#
# Regenerate the recompiled C sources in this repo from a fresh pret/pokeblue
# build via gb-recompiled.
#
# Usage:
#   tools/regen.sh <path-to-pret/pokeblue> <path-to-gb-recompiled>
#
# Requirements (on PATH):
#   - rgbds (rgbasm, rgblink, rgbfix) — to build the ROM
#   - make
#   - cmake, a C/C++ compiler — to build gbrecomp
#
# What it does:
#   1. (Re)build pret/pokeblue to produce pokeblue.gb + pokeblue.sym
#   2. (Re)build gbrecomp from the gb-recompiled clone
#   3. Run gbrecomp with --emit-asset-loader --prefix-symbols on the ROM
#   4. BSS-ify the ROM data buffer (per pgbcomp project convention)
#   5. Copy the generated pokeblue_*.c / .h / manifest / metadata into this
#      repo's root, overwriting the previous regen.
#
# After running, build to confirm:
#   cd build && cmake --build . -j$(nproc)
# and commit the changes.

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <pret/pokeblue-path> <gb-recompiled-path>" >&2
    exit 1
fi

PRET_DIR="$(realpath "$1")"
GBRECOMP_DIR="$(realpath "$2")"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! -d "$PRET_DIR" ]]; then
    echo "pret/pokeblue directory not found: $PRET_DIR" >&2; exit 1
fi
if [[ ! -d "$GBRECOMP_DIR" ]]; then
    echo "gb-recompiled directory not found: $GBRECOMP_DIR" >&2; exit 1
fi

echo "[regen] pret  : $PRET_DIR"
echo "[regen] gbrec : $GBRECOMP_DIR"
echo "[regen] repo  : $REPO_DIR"

# 1. Build the ROM.
echo "[regen] Building pokeblue ROM..."
(cd "$PRET_DIR" && make pokeblue)

ROM="$PRET_DIR/pokeblue.gb"
SYM="$PRET_DIR/pokeblue.sym"
for f in "$ROM" "$SYM"; do
    [[ -f "$f" ]] || { echo "Missing $f" >&2; exit 1; }
done

# 2. Build gbrecomp.
echo "[regen] Building gbrecomp..."
(cd "$GBRECOMP_DIR" && cmake -B build -S . > /dev/null && cmake --build build -j"$(nproc)" --target gbrecomp)
GBRECOMP_BIN="$GBRECOMP_DIR/build/recompiler/gbrecomp"
[[ -x "$GBRECOMP_BIN" ]] || { echo "Missing $GBRECOMP_BIN" >&2; exit 1; }

# 3. Run recompiler.
OUT_DIR="$(mktemp -d)"
trap "rm -rf '$OUT_DIR'" EXIT
echo "[regen] Recompiling to $OUT_DIR..."
"$GBRECOMP_BIN" \
    --emit-asset-loader \
    --prefix-symbols \
    --symbols "$SYM" \
    -o "$OUT_DIR" \
    "$ROM"

# 4. BSS-ify ROM data.
BSS_TOOL="$GBRECOMP_DIR/tools/bss_rom_data.py"
[[ -f "$BSS_TOOL" ]] || BSS_TOOL=""  # tool may live in pgbcomp instead
if [[ -n "$BSS_TOOL" ]]; then
    echo "[regen] BSS-ifying ROM data..."
    python3 "$BSS_TOOL" "$OUT_DIR/pokeblue_rom.c" "$OUT_DIR/pokeblue.c"
fi

# 5. Copy back. Keep launcher_main.cpp and CMakeLists.txt — those are repo-
#    level, not generated.
echo "[regen] Copying generated sources into repo..."
cp -v "$OUT_DIR/pokeblue_main.c" "$REPO_DIR/"
cp -v "$OUT_DIR/pokeblue.c" "$REPO_DIR/"
cp -v "$OUT_DIR/pokeblue_rom.c" "$REPO_DIR/"
cp -v "$OUT_DIR/pokeblue_dispatch_chunk_"*.c "$REPO_DIR/"
cp -v "$OUT_DIR/pokeblue_funcs_"*.c "$REPO_DIR/"
cp -v "$OUT_DIR/pokeblue.h" "$REPO_DIR/"
cp -v "$OUT_DIR/pokeblue_internal.h" "$REPO_DIR/"
cp -v "$OUT_DIR/assets_manifest_pokeblue.h" "$REPO_DIR/"
cp -v "$OUT_DIR/pokeblue_metadata.json" "$REPO_DIR/" 2>/dev/null || true

echo "[regen] Done. Build & test:"
echo "  (cd $REPO_DIR && cmake -B build -S . && cmake --build build -j\$(nproc))"
