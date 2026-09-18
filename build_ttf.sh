#!/bin/bash

usage() {
  echo "Usage: $0 <FONTTYPE> [VARIANT]"
  echo "  FONTTYPE: color, flat, hc, or hc-inv"
  echo "  VARIANT:  full (default): COLRv1 + OT-SVG + CBDT bitmaps"
  echo "            colrv1: COLRv1 only (no OT-SVG table, no bitmaps)"
}

# Check arg
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  usage
  exit 1
fi

if [ "$1" = 'color' ]; then
  echo "FONTTYPE: $1"
  FONTTYPE='Color'
elif [ "$1" = 'flat' ]; then
  echo "FONTTYPE: $1"
  FONTTYPE='Flat'
elif [ "$1" = 'hc' ]; then
  echo "FONTTYPE: $1"
  FONTTYPE='High Contrast'
elif [ "$1" = 'hc-inv' ]; then
  echo "FONTTYPE: $1"
  FONTTYPE='High Contrast Inverted'
else
  echo "FONTTYPE: $1"
  usage
  exit 1
fi

VARIANT="${2:-full}"
if [ "${VARIANT}" != 'full' ] && [ "${VARIANT}" != 'colrv1' ]; then
  echo "VARIANT: ${VARIANT}"
  usage
  exit 1
fi
echo "VARIANT: ${VARIANT}"

if ! ls ./build/build/*.ttf >/dev/null 2>&1; then
  ./build_ttf01.sh "$1"
fi

if [ "${VARIANT}" = 'colrv1' ]; then
  # build_ttf01.sh already produces a COLRv1-only font; just skip maximum_color.
  TTFFILENAME=$(echo "FluentEmoji${FONTTYPE}.ttf" | sed 's/ //g')
  cp build/build/"${TTFFILENAME}" dist/
else
  ./build_ttf02.sh "$1"
fi
