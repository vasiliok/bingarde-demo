#!/bin/sh
# Windows builds with real MSVC on a Windows PC over SSH.
# Usage: build-windows-msvc.sh variants.txt
#   WIN_HOST (required: ssh host of the Windows PC), WIN_DIR (default bingarde-demo,
#   relative to the Windows home)
set -e
cd "$(dirname "$0")"
host=${WIN_HOST:?set WIN_HOST to the ssh host of the Windows PC}
dir=${WIN_DIR:-bingarde-demo}
windir=$(printf '%s' "$dir" | tr '/' '\\')
ssh -o BatchMode=yes "$host" "if not exist $windir mkdir $windir"
scp -q src/engine.c src/engine.h src/main_cli.c windows-msvc/build.cmd "$host:$dir/"
sed 's/$/\r/' "$1" > variants/msvc-upload.txt
scp -q variants/msvc-upload.txt "$host:$dir/variants.txt"
ssh -o BatchMode=yes "$host" "cd /d %USERPROFILE%\\$windir && build.cmd"
# Copy the results back into out/ (same layout as the other platforms).
rm -rf variants/msvc-out && mkdir -p variants/msvc-out
scp -q -r "$host:$dir/out/*" variants/msvc-out/
cp -R variants/msvc-out/. out/
