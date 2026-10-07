#!/bin/sh
# Inspect one Linux variant's split debug file (inside the gcc image).
lin=out/alpha/main/140/linux-release-x86_64
mkdir -p /tmp/x && tar -xzf "$lin/demoapp-x86_64.tar.gz" -C /tmp/x
echo "--- build-id: binary vs .debug"
readelf -n /tmp/x/demoapp | grep 'Build ID'
readelf -n "$lin/demoapp.debug" | grep 'Build ID'
echo "--- debuglink in binary"
readelf -p .gnu_debuglink /tmp/x/demoapp | grep demoapp
echo "--- DWARF sections in .debug"
readelf -S "$lin/demoapp.debug" | grep -o '\.debug_[a-z_]*' | sort -u | tr '\n' ' '; echo
echo "--- functions in .debug"
nm "$lin/demoapp.debug" | grep -E ' [Tt] (world_|engine_|entity_)' | awk '{print $3}' | tr '\n' ' '; echo
