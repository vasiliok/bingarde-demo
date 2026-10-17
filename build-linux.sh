#!/bin/sh
# Linux builds in Docker (gcc, x86_64 + aarch64 cross). Usage: build-linux.sh variants.txt
set -e
cd "$(dirname "$0")"
docker build -q -t bingarde-demo-linux -f docker/linux.Dockerfile docker >/dev/null
docker run --rm -i -v "$PWD":/work -w /work bingarde-demo-linux sh docker/linux-inner.sh < "$1"
