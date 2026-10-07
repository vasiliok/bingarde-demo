#!/bin/sh
# Check symbol files of out/alpha/main/140 with the real tools.
cd "$(dirname "$0")"
docker run --rm -v "$PWD":/work -w /work mstorsjo/llvm-mingw:20260922 sh docker/verify-inner.sh
docker run --rm -v "$PWD":/work -w /work bingarde-demo-linux sh docker/verify-linux-inner.sh
