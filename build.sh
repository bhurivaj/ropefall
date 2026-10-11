#!/bin/sh
# Build target/ropefall_<VERSION>.rbz from src/ (VERSION is read from the loader)
set -e
cd "$(dirname "$0")"
VERSION=$(sed -n "s/.*VERSION *= *'\([^']*\)'.*/\1/p" src/sketchrope_ropefall.rb)
rm -rf target
mkdir -p target
(cd src && zip -rq "../target/ropefall_${VERSION}.rbz" sketchrope_ropefall.rb sketchrope_ropefall -x '*.DS_Store')
zip -q "target/ropefall_${VERSION}.rbz" LICENSE  # MIT notice must ship with every copy
echo "Built target/ropefall_${VERSION}.rbz"
