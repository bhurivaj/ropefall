#!/bin/sh
# Build target/ropefall_<VERSION>.rbz from src/ (VERSION is read from the loader)
set -e
cd "$(dirname "$0")"
VERSION=$(sed -n "s/.*VERSION *= *'\([^']*\)'.*/\1/p" src/sketchrope_ropefall.rb)
rm -rf target
mkdir -p target/stage
cp -R src/sketchrope_ropefall.rb src/sketchrope_ropefall target/stage/
# MIT notice must ship with every copy; keep it inside the plugin folder (rbz root = Plugins folder)
cp LICENSE target/stage/sketchrope_ropefall/LICENSE.txt
(cd target/stage && zip -rq "../ropefall_${VERSION}.rbz" . -x '*.DS_Store')
rm -rf target/stage
echo "Built target/ropefall_${VERSION}.rbz"
