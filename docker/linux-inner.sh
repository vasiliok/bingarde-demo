#!/bin/sh
# Runs inside the linux image. Reads variants (one per line):
#   project branch build revision config arch
# and builds each into out/<project>/<branch>/<build>/linux-<config>-<arch>/.
set -e
while read -r project branch build revision config arch mode; do
    [ -n "$project" ] || continue
    if [ "$mode" = fail ]; then
        # A real failing build: the compiler stops with an #error.
        dir="out/$project/$branch/$build/linux-$config-$arch"
        rm -rf "$dir"; mkdir -p "$dir"
        cc=aarch64-linux-gnu-gcc; [ "$arch" = x86_64 ] && cc=gcc
        {
            echo "\$ $cc -O0 -g -DDEMO_BROKEN ... -o demoapp src/engine.c src/main_cli.c"
            $cc -O0 -g -Wall -DDEMO_BROKEN -o "$dir/demoapp" src/engine.c src/main_cli.c 2>&1 || echo "build FAILED (exit $?)"
        } > "$dir/build.log"
        printf '{"platform": "linux", "config": "%s", "arch": "%s", "compiler": "%s", "triple": "%s-linux-gnu", "status": "failed"}\n' \
            "$config" "$arch" "$($cc --version | head -1)" "$arch" > "$dir/meta.json"
        echo "linux $config $arch: $dir (failed on purpose)"
        continue
    fi
    dir="out/$project/$branch/$build/linux-$config-$arch"
    rm -rf "$dir"; mkdir -p "$dir/stage"
    case "$arch" in
        x86_64) cc=gcc; objcopy=objcopy; strip=strip; triple=x86_64-linux-gnu ;;
        aarch64) cc=aarch64-linux-gnu-gcc; objcopy=aarch64-linux-gnu-objcopy; strip=aarch64-linux-gnu-strip; triple=aarch64-linux-gnu ;;
    esac
    if [ "$config" = debug ]; then opt="-O0"; else opt="-O2"; fi
    {
        echo "\$ $cc --version"; $cc --version | head -1
        echo "\$ $cc $opt -g -Wall -Wl,--build-id ... -o demoapp src/engine.c src/main_cli.c"
        $cc $opt -g -Wall -Wl,--build-id \
            -DPROJECT="\"$project\"" -DBRANCH="\"$branch\"" -DBUILD_NUMBER="$build" -DREVISION="\"$revision\"" \
            -o "$dir/stage/demoapp" src/engine.c src/main_cli.c 2>&1
        echo "\$ $objcopy --only-keep-debug demoapp demoapp.debug"
        $objcopy --only-keep-debug "$dir/stage/demoapp" "$dir/demoapp.debug"
        echo "\$ $strip --strip-debug --strip-unneeded demoapp"
        $strip --strip-debug --strip-unneeded "$dir/stage/demoapp"
        echo "\$ $objcopy --add-gnu-debuglink=demoapp.debug demoapp"
        (cd "$dir" && $objcopy --add-gnu-debuglink=demoapp.debug stage/demoapp)
        file "$dir/stage/demoapp" | sed 's|^.*stage/||'
        echo "build finished"
    } > "$dir/build.log"
    if [ "$arch" = x86_64 ]; then
        "$dir/stage/demoapp" --self-test > "$dir/tests.junit.xml" || true
    fi
    tar -czf "$dir/demoapp-$arch.tar.gz" -C "$dir/stage" demoapp
    rm -rf "$dir/stage"
    compiler=$($cc --version | head -1)
    printf '{"platform": "linux", "config": "%s", "arch": "%s", "compiler": "%s", "triple": "%s"}\n' \
        "$config" "$arch" "$compiler" "$triple" > "$dir/meta.json"
    echo "linux $config $arch: $dir"
done
