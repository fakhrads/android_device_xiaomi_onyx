#!/bin/bash
# Builds the Konoha GKI kernel (stock-performance) from source and drops the
# resulting Image where BoardConfig.mk expects the prebuilt kernel.
#
# Usage: build_konoha_kernel.sh <konoha_src_dir> <output_image_path>
set -e

KONOHA_SRC="$1"
OUT_IMAGE="$2"

if [ -z "$KONOHA_SRC" ] || [ -z "$OUT_IMAGE" ]; then
    echo "[konoha] usage: $0 <konoha_src_dir> <output_image_path>" >&2
    exit 1
fi

if [ ! -f "$KONOHA_SRC/build.sh" ]; then
    echo "[konoha] no kernel source at $KONOHA_SRC, skipping (kernel image left untouched)" >&2
    exit 0
fi

cd "$KONOHA_SRC"

# build.sh looks for a clang toolchain at ../toolchains/clang (relative to
# the kernel source dir) if none is found on PATH. Provision the same
# toolchain Konoha's own CI uses if it isn't there yet.
TOOLCHAIN_DIR="$(readlink -f "$KONOHA_SRC/..")/toolchains/clang"
if [ ! -f "$TOOLCHAIN_DIR/bin/clang" ] && ! command -v clang >/dev/null 2>&1; then
    echo "[konoha] no clang found, fetching prebuilt toolchain ..."
    mkdir -p "$(dirname "$TOOLCHAIN_DIR")"
    git clone --depth=1 https://github.com/ZyCromerZ/Clang.git -b main "$TOOLCHAIN_DIR"
fi

BUILD_ARGS=(hz=500 variant=stock lto=thin)

echo "[konoha] building stock-performance (500Hz) ..."
./build.sh "${BUILD_ARGS[@]}"

ZIP="$(ls -t Kono-Ha-Release/Kono-Ha-*.zip 2>/dev/null | head -n1)"
if [ -z "$ZIP" ]; then
    echo "[konoha] build.sh did not produce a release zip" >&2
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
    echo "[konoha] no Image found inside $ZIP" >&2
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
echo "[konoha] wrote $OUT_IMAGE"
