# Bingarde demo builds

Real build data for trying Bingarde, a store for CI build artifacts: one small
C program (`src/`) built for four platforms, with the files a CI would keep.

In the Bingarde repo this repo is the `demo/` submodule.

| Platform | Toolchain | Files per build |
|---|---|---|
| Windows x86_64, release + debug | MSVC on a Windows PC over SSH (or llvm-mingw in Docker) | `.exe`, `.pdb`, JUnit report, log |
| Linux x86_64 + aarch64 | gcc in Docker | `.tar.gz`, separate `.debug`, JUnit report (x86_64), log |
| iOS arm64 | Xcode | `.ipa`, `.dSYM.zip`, log |
| macOS universal | Xcode | `.dmg`, `.dSYM.zip`, log |

3 projects (alpha, beta, gamma) × 2 branches × 2 builds give 72 builds. Each project
also has one failed Linux build: it is compiled with `-DDEMO_BROKEN`, so the log
holds a real compiler error. 75 builds, 255 files in total.

## Build

```bash
./build-all.sh                     # Windows with llvm-mingw in Docker
WIN_HOST=winpc.local ./build-all.sh  # Windows with MSVC over SSH
./verify.sh                        # check the PDB and ELF debug files of one build
```

The output goes to `out/<project>/<branch>/<build>/<platform>-<config>-<arch>/`,
with a `meta.json` per build. iOS and macOS builds need a Mac with Xcode. MSVC
builds need a Windows PC with Visual Studio and OpenSSH Server; the program's
self-test runs there and writes the JUnit report.

## Load into a server

Create a `write` token on the server's **API tokens** page, then:

```bash
export BINGARDE_URL=http://localhost:8080 BINGARDE_TOKEN=bg_...
python3 seed.py                                  # from out/
python3 seed.py --from ~/Downloads/demo-builds.zip
python3 seed.py --from https://example.com/demo-builds.zip
```

`--from` takes a folder, a `.zip` file or the URL of a `.zip`. The zip may hold the
build folders at its top or inside one folder. Each build is created as `uploading`,
its files are uploaded, then it is marked `complete` or `failed`, like a CI job would.

`--replace` deletes all existing builds first (needs an admin's token). Users,
tokens and presets are kept.

## License

MIT, see [LICENSE](LICENSE).
