#!/bin/sh
# Build every demo variant: 3 projects x 2 branches x 2 builds, for
#   windows x86_64 release + debug, linux x86_64 + aarch64 release,
#   ios arm64 release, macos universal release.
# Output: out/<project>/<branch>/<build>/<platform>-<config>-<arch>/ with meta.json.
# Set WIN_HOST (e.g. winpc.local) to build Windows with MSVC over SSH.
set -e
cd "$(dirname "$0")"
rm -rf out variants
mkdir -p out variants
for project in alpha beta gamma; do
    case $project in alpha) base=100 ;; beta) base=300 ;; gamma) base=500 ;; esac
    for branch in main release-1.0; do
        [ "$branch" = main ] && start=$((base + 40)) || start=$base
        for build in $start $((start + 1)); do
            revision=$(printf '%s/%s/%s' "$project" "$branch" "$build" | shasum | cut -c1-40)
            line="$project $branch $build $revision"
            echo "$line release x86_64" >> variants/windows.txt
            echo "$line debug x86_64" >> variants/windows.txt
            echo "$line release x86_64" >> variants/linux.txt
            echo "$line release aarch64" >> variants/linux.txt
            echo "$line release arm64" >> variants/ios.txt
            # The newest main build of each project also has one real failed variant.
            if [ "$branch" = main ] && [ "$build" = $((start + 1)) ]; then
                echo "$line debug aarch64 fail" >> variants/linux.txt
            fi
            echo "$line release universal" >> variants/macos.txt
        done
    done
done
sh build-linux.sh variants/linux.txt
# Windows: real MSVC on a Windows PC over SSH when WIN_HOST is set,
# otherwise clang + lld (llvm-mingw) in Docker.
if [ -n "$WIN_HOST" ]; then
    sh build-windows-msvc.sh variants/windows.txt
else
    sh build-windows.sh variants/windows.txt
fi
sh build-ios.sh variants/ios.txt
sh build-macos.sh variants/macos.txt
echo "variants built: $(find out -name meta.json | wc -l | tr -d ' ')"
