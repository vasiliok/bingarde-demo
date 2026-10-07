#!/bin/sh
# Windows builds in Docker (llvm-mingw: clang + lld, real PDB files). Usage: build-windows.sh variants.txt
set -e
cd "$(dirname "$0")"
docker run --rm -i -v "$PWD":/work -w /work mstorsjo/llvm-mingw:20260922 sh docker/windows-inner.sh < "$1"
