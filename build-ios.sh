#!/bin/sh
# iOS builds with Xcode on the Mac: arm64 device app -> DemoApp.ipa (unsigned,
# for demos), debug symbols -> DemoApp.app.dSYM.zip. Usage: build-ios.sh variants.txt
set -e
cd "$(dirname "$0")"
sdk_version=$(xcrun --sdk iphoneos --show-sdk-version)
compiler=$(xcrun --sdk iphoneos clang --version | head -1)
while read -r project branch build revision config arch; do
    [ -n "$project" ] || continue
    dir="out/$project/$branch/$build/ios-$config-$arch"
    app="$dir/stage/Payload/DemoApp.app"
    rm -rf "$dir"; mkdir -p "$app"
    if [ "$config" = debug ]; then opt="-O0"; else opt="-O2"; fi
    {
        echo "\$ xcrun --sdk iphoneos clang --version"; echo "$compiler"
        # Compile to object files first: dsymutil reads the debug info from them.
        mkdir -p "$dir/stage/obj"
        for src in src/ios/main.m src/engine.c; do
            obj="$dir/stage/obj/$(basename "$src").o"
            echo "\$ clang -c -arch $arch -mios-version-min=15.0 -fobjc-arc $opt -g $src"
            xcrun --sdk iphoneos clang -c -arch "$arch" -mios-version-min=15.0 -fobjc-arc $opt -g -Wall \
                -DPROJECT="\"$project\"" -DBRANCH="\"$branch\"" -DBUILD_NUMBER="$build" -DREVISION="\"$revision\"" \
                -o "$obj" "$src" 2>&1
        done
        echo "\$ clang -arch $arch -framework UIKit -framework Foundation -o DemoApp *.o"
        xcrun --sdk iphoneos clang -arch "$arch" -mios-version-min=15.0 -framework UIKit -framework Foundation \
            -o "$app/DemoApp" "$dir"/stage/obj/*.o 2>&1
        echo "\$ dsymutil DemoApp -o DemoApp.app.dSYM"
        xcrun dsymutil "$app/DemoApp" -o "$dir/stage/DemoApp.app.dSYM" 2>&1
        echo "\$ strip -S DemoApp"
        xcrun strip -S "$app/DemoApp" 2>&1
        xcrun dwarfdump --uuid "$dir/stage/DemoApp.app.dSYM" | sed 's|(.*||'
        echo "build finished"
    } > "$dir/build.log"
    sed "s/__BUILD__/$build/" src/ios/Info.plist > "$app/Info.plist"
    (cd "$dir/stage" && zip -qry ../DemoApp.ipa Payload && zip -qry ../DemoApp.app.dSYM.zip DemoApp.app.dSYM)
    rm -rf "$dir/stage"
    printf '{"platform": "ios", "config": "%s", "arch": "%s", "compiler": "%s", "sdk": "iPhoneOS %s", "triple": "%s-apple-ios15.0"}\n' \
        "$config" "$arch" "$compiler" "$sdk_version" "$arch" > "$dir/meta.json"
    echo "ios $config $arch: $dir"
done < "$1"
