#!/bin/bash
# Builds the (stripped) Konoha kernel from source and refreshes the
# prebuilt Image that lives in device/xiaomi/onyx-kernel (PREBUILT_PATH in
# BoardConfig.mk). This is a STANDALONE step, run manually - it is not
# hooked into `mka bacon`. The ROM build only ever consumes the prebuilt
# repo, same as when the Image came from extract-files.sh.
#
# Usage (run from the root of the synced onyx_manifest tree):
#   device/xiaomi/onyx/build_kernel.sh
#
# What it does:
#   1. build device/xiaomi/onyx-konoha (stock variant, 500Hz/performance,
#      HTSR on, no wifi/kgsl/data exploits - see that repo's own commit
#      history for what was stripped and why)
#   2. extract the Image from the resulting AnyKernel3 zip
#   3. copy it into device/xiaomi/onyx-kernel/images/kernel
#
# It does NOT commit or push - review the diff in device/xiaomi/onyx-kernel
# yourself and commit/push when you're happy with it.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TREE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
KONOHA_SRC="$TREE_ROOT/device/xiaomi/onyx-konoha"
PREBUILT_REPO="$TREE_ROOT/device/xiaomi/onyx-kernel"
OUT_IMAGE="$PREBUILT_REPO/images/kernel"

if [ ! -f "$KONOHA_SRC/build.sh" ]; then
    echo "[kernel] no kernel source at $KONOHA_SRC" >&2
    echo "[kernel] sync it first: repo sync device/xiaomi/onyx-konoha" >&2
    exit 1
fi

if [ ! -d "$PREBUILT_REPO" ]; then
    echo "[kernel] prebuilt repo not found at $PREBUILT_REPO" >&2
    exit 1
fi

cd "$KONOHA_SRC"

# build.sh looks for a clang toolchain at ../toolchains/clang (relative to
# the kernel source dir) if none is on PATH.
TOOLCHAIN_DIR="$(readlink -f "$KONOHA_SRC/..")/toolchains/clang"
if [ ! -f "$TOOLCHAIN_DIR/bin/clang" ] && ! command -v clang >/dev/null 2>&1; then
    echo "[kernel] no clang found, fetching prebuilt toolchain ..."
    mkdir -p "$(dirname "$TOOLCHAIN_DIR")"
    git clone --depth=1 https://github.com/ZyCromerZ/Clang.git -b main "$TOOLCHAIN_DIR"
fi

echo "[kernel] building stock-performance (500Hz, HTSR on) ..."
./build.sh hz=500 variant=stock lto=thin htsr=on

ZIP="$(ls -t Kono-Ha-Release/Kono-Ha-*.zip 2>/dev/null | head -n1)"
if [ -z "$ZIP" ]; then
    echo "[kernel] build.sh did not produce a release zip" >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
unzip -oq "$ZIP" -d "$WORK"

IMG=""
for name in Image Image.gz Image.gz-dtb; do
    [ -f "$WORK/$name" ] && IMG="$WORK/$name" && break
done

if [ -z "$IMG" ]; then
    echo "[kernel] no Image found inside $ZIP" >&2
    exit 1
fi

case "$IMG" in
    *.gz|*.gz-dtb)
        cp "$IMG" "$WORK/Image.gz"
        gzip -dkf "$WORK/Image.gz"
        IMG="$WORK/Image"
        ;;
esac

mkdir -p "$(dirname "$OUT_IMAGE")"
cp -v "$IMG" "$OUT_IMAGE"

echo "[kernel] wrote $OUT_IMAGE"
echo "[kernel] review the diff, then commit+push device/xiaomi/onyx-kernel yourself:"
echo "         cd $PREBUILT_REPO && git status"
