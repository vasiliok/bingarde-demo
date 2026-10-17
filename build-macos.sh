#!/bin/sh
# macOS builds with Xcode on the Mac: universal (x86_64 + arm64) app bundle in a
# compressed DemoApp.dmg, debug symbols -> DemoApp.app.dSYM.zip. Usage: build-macos.sh variants.txt
set -e
cd "$(dirname "$0")"
sdk_version=$(xcrun --sdk macosx --show-sdk-version)
compiler=$(xcrun --sdk macosx clang --version | head -1)
while read -r project branch build revision config arch; do
    [ -n "$project" ] || continue
    dir="out/$project/$branch/$build/macos-$config-$arch"
    app="$dir/stage/dmg/DemoApp.app"
    rm -rf "$dir"; mkdir -p "$app/Contents/MacOS"
    if [ "$config" = debug ]; then opt="-O0"; else opt="-O2"; fi
    {
        echo "\$ xcrun --sdk macosx clang --version"; echo "$compiler"
        # Compile to object files first: dsymutil reads the debug info from them.
        mkdir -p "$dir/stage/obj"
        for src in src/engine.c src/main_cli.c; do
            obj="$dir/stage/obj/$(basename "$src").o"
            echo "\$ clang -c -arch x86_64 -arch arm64 -mmacosx-version-min=11.0 $opt -g $src"
            xcrun --sdk macosx clang -c -arch x86_64 -arch arm64 -mmacosx-version-min=11.0 $opt -g -Wall \
                -DPROJECT="\"$project\"" -DBRANCH="\"$branch\"" -DBUILD_NUMBER="$build" -DREVISION="\"$revision\"" \
                -o "$obj" "$src" 2>&1
        done
        echo "\$ clang -arch x86_64 -arch arm64 -o DemoApp *.o"
        xcrun --sdk macosx clang -arch x86_64 -arch arm64 -mmacosx-version-min=11.0 \
            -o "$app/Contents/MacOS/DemoApp" "$dir"/stage/obj/*.o 2>&1
        echo "\$ dsymutil DemoApp -o DemoApp.app.dSYM"
        xcrun dsymutil "$app/Contents/MacOS/DemoApp" -o "$dir/stage/DemoApp.app.dSYM" 2>&1
        echo "\$ strip -S DemoApp"
        xcrun strip -S "$app/Contents/MacOS/DemoApp" 2>&1
        xcrun dwarfdump --uuid "$dir/stage/DemoApp.app.dSYM" | sed 's|(.*||'
        "$app/Contents/MacOS/DemoApp" --version
        echo "\$ hdiutil create -format UDZO DemoApp.dmg"
        hdiutil create -quiet -volname DemoApp -srcfolder "$dir/stage/dmg" -ov -format UDZO "$dir/DemoApp.dmg" 2>&1
        echo "build finished"
    } > "$dir/build.log"
    sed -e "s/__BUILD__/$build/" -e '/LSRequiresIPhoneOS/d' -e '/UIDeviceFamily/d' -e '/UILaunchScreen/d' \
        -e 's|<key>MinimumOSVersion</key><string>15.0</string>|<key>LSMinimumSystemVersion</key><string>11.0</string>|' \
        src/ios/Info.plist > "$app/Contents/Info.plist"
    (cd "$dir/stage" && zip -qry ../DemoApp.app.dSYM.zip DemoApp.app.dSYM)
    rm -rf "$dir/stage"
    printf '{"platform": "macos", "config": "%s", "arch": "%s", "compiler": "%s", "sdk": "MacOSX %s", "triple": "x86_64+arm64-apple-macos11.0"}\n' \
        "$config" "$arch" "$compiler" "$sdk_version" > "$dir/meta.json"
    echo "macos $config $arch: $dir"
done < "$1"
