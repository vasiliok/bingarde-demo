#!/bin/sh
# Runs inside mstorsjo/llvm-mingw. Same variant lines as linux-inner.sh;
# builds DemoApp.exe with a real PDB (CodeView debug info, lld --pdb).
set -e
while read -r project branch build revision config arch; do
    [ -n "$project" ] || continue
    dir="out/$project/$branch/$build/windows-$config-$arch"
    mkdir -p "$dir"
    cc="$arch-w64-mingw32-clang"
    if [ "$config" = debug ]; then opt="-O0"; else opt="-O2"; fi
    {
        echo "\$ $cc --version"; $cc --version | head -1
        echo "\$ $cc $opt -g -gcodeview -Wl,--pdb=DemoApp.pdb ... -o DemoApp.exe src/engine.c src/main_cli.c"
        $cc $opt -g -gcodeview -Wall \
            -DPROJECT="\"$project\"" -DBRANCH="\"$branch\"" -DBUILD_NUMBER="$build" -DREVISION="\"$revision\"" \
            -Wl,--pdb="$dir/DemoApp.pdb" -o "$dir/DemoApp.exe" src/engine.c src/main_cli.c 2>&1
        echo "build finished"
    } > "$dir/build.log"
    compiler=$($cc --version | head -1)
    printf '{"platform": "windows", "config": "%s", "arch": "%s", "compiler": "%s", "triple": "%s-w64-windows-gnu"}\n' \
        "$config" "$arch" "$compiler" "$arch" > "$dir/meta.json"
    echo "windows $config $arch: $dir"
done
