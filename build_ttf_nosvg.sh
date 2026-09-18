#!/bin/bash
# Build a Fluent Emoji TTF as pure COLRv1: no OT-SVG table, no CBDT bitmaps.
#
# Why: the upstream TTF build (build_ttf02.sh -> maximum_color) adds an OT-SVG table in
# which ~950 glyphs share a single ~36 MB SVG document. Gecko apps (Firefox, Thunderbird,
# Betterbird) prefer OT-SVG over COLR and parse that whole document on the main thread
# the first time one of those emoji is drawn -> multi-second UI freezes.
#
# Differences from build_ttf01.sh:
#   - fluentui-emoji submodule is updated to the latest upstream main (shallow clone)
#   - Python 3.14 venv created with uv (~5% faster than the 3.12 used by upstream CI, identical output)
#   - output goes to out/ (dist/ holds the upstream prebuilt fonts tracked in git)
#   - incremental: build/ is kept between runs; SVGs whose content did not change get their
#     previous mtime back, so ninja only reprocesses changed emoji (and skips the slow,
#     single-threaded write_font step entirely when nothing changed)
#
# Usage:  ./build_ttf_nosvg.sh [--clean] [color|flat|hc|hc-inv]     (default: color)
#         --clean  wipe build/ and rebuild from scratch (e.g. after a nanoemoji upgrade,
#                  or when switching font type)
# Output: out/FluentEmoji<Type>.ttf
# Needs:  git, uv, patch
set -euo pipefail
cd "$(dirname "$0")"

if [ "${1:-}" = "--clean" ]; then
  rm -rf build
  shift
fi

case "${1:-color}" in
  color) FONTTYPE='Color' ;;
  flat) FONTTYPE='Flat' ;;
  hc) FONTTYPE='High Contrast' ;;
  hc-inv) FONTTYPE='High Contrast Inverted' ;;
  *) echo "Usage: $0 [color|flat|hc|hc-inv]"; exit 1 ;;
esac
TTFFILENAME=$(echo "FluentEmoji${FONTTYPE}.ttf" | sed 's/ //g')

# Latest upstream assets. Reset first: prepare.py re-applies replaceSVG.diff itself.
git submodule update --init --remote --depth 1 fluentui-emoji
git -C fluentui-emoji checkout -- .
echo "fluentui-emoji @ $(git -C fluentui-emoji log -1 --format='%h %cd')"

# a previous run died between the two moves below -> build.prev is the real cache
if [ -d build.prev ]; then
  rm -rf build
  mv build.prev build
fi

rm -rf venv
uv venv --python 3.14 --seed venv
source venv/bin/activate
uv pip install nanoemoji brotli
git apply --directory venv/lib/python3.14/site-packages/nanoemoji nanoemoji.patch

# prepare.py insists on creating build/ itself, so keep the previous one aside
[ -d build ] && mv build build.prev

# Copies the SVGs of the chosen style to build/ as NNN_NNN_emoji_u<codepoints>.svg
python -m prepare "${FONTTYPE}"

pushd build
for name in [0-9][0-9][0-9]_[0-9][0-9][0-9]_*.svg; do
  new="${name:8}" # drop the NNN_NNN_ grouping prefix (only used for woff2 splitting)
  mv "${name}" "${new}"
  # unchanged since last build -> restore old mtime so ninja does not redo it
  if [ -f "../build.prev/${new}" ] && cmp -s "${new}" "../build.prev/${new}"; then
    touch -r "../build.prev/${new}" "${new}"
  fi
done
popd
# restore ninja's intermediate files and log (stale SVGs of removed emoji are dropped)
[ -d build.prev/build ] && mv build.prev/build build/build
rm -rf build.prev

pushd build
# glyf_colr_1 = COLRv1 color glyphs + plain glyf outlines; no SVG, no bitmaps
nanoemoji --color_format glyf_colr_1 --family "Fluent Emoji ${FONTTYPE}" --output_file "${TTFFILENAME}" *.svg
# delete intermediate files of emoji removed upstream (no longer in build.ninja)
ninja -C build -t cleandead > /dev/null
popd

mkdir -p out
cp "build/build/${TTFFILENAME}" out/
rm -rf venv
echo "Built out/${TTFFILENAME}"
