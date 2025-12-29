#!/bin/sh
set -eu

rm -rf zig-out build

mkdir build

zig build release -Doptimize=ReleaseFast

# Windows
zip -9 -j build/zscene-x86_64-windows.zip zig-out/x86_64-windows-x86_64_v3/zscene.dll
zip -9 -j build/zscene-x86_64-windows-znver4.zip zig-out/x86_64-windows-znver4/zscene.dll

# Mac
zip -9 -j build/zscene-x86_64-macos.zip zig-out/x86_64-macos-default/libzscene.dylib
zip -9 -j build/zscene-aarch64-macos.zip zig-out/aarch64-macos-default/libzscene.dylib

# Linux GNU
zip -9 -j build/zscene-x86_64-linux-gnu.zip zig-out/x86_64-linux-gnu.2.17-x86_64_v3/libzscene.so
zip -9 -j build/zscene-x86_64-linux-gnu-znver4.zip zig-out/x86_64-linux-gnu.2.17-znver4//libzscene.so
zip -9 -j build/zscene-aarch64-linux-gnu.zip zig-out/aarch64-linux-gnu.2.17-default/libzscene.so

# Linux Musl
zip -9 -j build/zscene-x86_64-linux-musl.zip zig-out/x86_64-linux-musl-x86_64_v3/libzscene.so
zip -9 -j build/zscene-x86_64-linux-musl-znver4.zip zig-out/x86_64-linux-musl-znver4/libzscene.so
zip -9 -j build/zscene-aarch64-linux-musl.zip zig-out/aarch64-linux-musl-default/libzscene.so

pushd build

sha256sum *zscene* > zscene_checksums.sha256
popd
