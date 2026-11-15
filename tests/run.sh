#!/bin/sh
# Runs every Rewind test: the C math checks and the scrobble tool's Python tests.
# Any arguments (a test selection) are ignored; the whole suite takes under a second.
set -e
cd "$(dirname "$0")/.."
mkdir -p build
for t in wheel scroll scrobble; do clang "tests/$t.c" -o "build/$t-tests" && "build/$t-tests"; done
python3 tests/test_scrobble.py
