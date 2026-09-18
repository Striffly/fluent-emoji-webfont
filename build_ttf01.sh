#!/bin/bash

# Check arg
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <FONTTYPE>"
  echo "  FONTTYPE: color, flat, hc, or hc-inv"
  exit 1
fi

if [ "$1" = 'color' ]; then
  FONTTYPE='Color'
elif [ "$1" = 'flat' ]; then
  FONTTYPE='Flat'
elif [ "$1" = 'hc' ]; then
  FONTTYPE='High Contrast'
elif [ "$1" = 'hc-inv' ]; then
  FONTTYPE='High Contrast Inverted'
fi

# On error, exit immediately.
set -e

# A previous run died while the last build was kept aside: restore it.
if [ -d build.prev ]; then
  rm -rf build
  mv build.prev build
fi

# Remove potential leftovers from older builds.
# build/ is kept on purpose: its build/build/ subfolder holds nanoemoji's ninja
# cache, so that only changed emoji get processed again. Delete build/ to start
# from scratch.
rm -rf venv

# Create clean Python environment.
python -m venv --upgrade-deps venv

if [ -f venv/bin/activate ]; then
  source venv/bin/activate # For Mac, Linux
else
  source venv/Scripts/activate # For Windows
fi

pip install nanoemoji
pip install brotli # Add for conversion of woff2

# prepare.py creates build/ itself: keep the previous one aside meanwhile.
if [ -d build ]; then
  mv build build.prev
fi
python -m prepare "${FONTTYPE}"

if [ -d venv/Lib/site-packages/nanoemoji ]; then
  git apply --directory venv/Lib/site-packages/nanoemoji nanoemoji.patch # For Windows
else
  git apply --directory venv/lib/*/site-packages/nanoemoji nanoemoji.patch # For Mac, Linux
fi

pushd build
FILES=$(find . -maxdepth 1 -name "*.svg" | sort)
for name in ${FILES}; do
  mv ${name} ${name:10:100}
  # Unchanged since the last build: restore its timestamp so ninja skips it.
  if [ -f ../build.prev/${name:10:100} ] && cmp -s ${name:10:100} ../build.prev/${name:10:100}; then
    touch -r ../build.prev/${name:10:100} ${name:10:100}
  fi
done
popd

# Restore the ninja cache. SVGs of emoji removed upstream are dropped.
if [ -d build.prev/build ]; then
  mv build.prev/build build/build
fi
rm -rf build.prev

pushd build

FILES=$(find . -maxdepth 1 -name "*.svg" | sort)

TTFFILENAME=$(echo "FluentEmoji${FONTTYPE}.ttf" | sed 's/ //g')

nanoemoji --color_format glyf_colr_1 --family "Fluent Emoji ${FONTTYPE}" --output_file "${TTFFILENAME}" ${FILES} > /dev/null

# Delete intermediate files of emoji removed upstream (no longer in build.ninja).
ninja -C build -t cleandead > /dev/null

# SVGs are kept for the timestamp comparison of the next build.
popd
rm -rf venv
