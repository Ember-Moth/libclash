#!/usr/bin/env bash
# 用鸿蒙 SDK 自带的 OHOS musl Clang，把 libclash 当成一个
# 特殊 Linux 发行版（aarch64/armv7 musl）来 cgo 编译。
# 产物：dist/cshared/ohos/<ohos-target>/libclash.so + libclash.h
#
# 环境变量：
#   OHOS_SDK_HOME      鸿蒙 SDK 根目录（默认从 env 拿）
#   OHOS_TARGETS       要构建的目标，逗号分隔，默认
#                      "aarch64-unknown-linux-ohos,armv7-unknown-linux-ohos"
#   GO_TAGS            Go build tags，默认 "foss,with_gvisor,cmfa,ohos"
#   STRIP_SO           是否 strip，默认 1
#   OUT_DIR            输出根目录，默认 dist/cshared/ohos
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/dist/cshared/ohos}"
TAGS="${GO_TAGS:-foss,with_gvisor,cmfa,ohos}"
STRIP_SO="${STRIP_SO:-1}"
LDFLAGS="${GO_LDFLAGS:--s -w}"
OHOS_SDK_HOME="${OHOS_SDK_HOME:-/opt/command-line-tools/sdk/default/openharmony}"
OHOS_TARGETS="${OHOS_TARGETS:-aarch64-unknown-linux-ohos,armv7-unknown-linux-ohos}"

LLVM="$OHOS_SDK_HOME/native/llvm/bin"
SYSROOT="$OHOS_SDK_HOME/native/sysroot"

if [[ ! -x "$LLVM/clang" ]]; then
  echo "OHOS clang not found: $LLVM/clang" >&2
  exit 1
fi
if [[ ! -d "$SYSROOT/usr/lib" ]]; then
  echo "OHOS sysroot not found: $SYSROOT" >&2
  exit 1
fi

strip_size() {
  local so_path="$1"
  local before after
  before=$(wc -c < "$so_path" | tr -d ' ')
  "$LLVM/llvm-strip" --strip-unneeded "$so_path"
  after=$(wc -c < "$so_path" | tr -d ' ')
  echo "  stripped: $before -> $after bytes"
}

build_one() {
  local ohostgt="$1"
  local goarch="$2"
  local goarm="${3:-}"
  local cc="$LLVM/${ohostgt}-clang"
  local outdir="$OUT_DIR/$ohostgt"

  if [[ ! -x "$cc" ]]; then
    echo "  SKIP $ohostgt (no clang wrapper: $cc)"
    return 0
  fi

  echo "==> building $ohostgt (GOOS=linux GOARCH=$goarch${goarm:+ GOARM=$goarm})"
  mkdir -p "$outdir"

  (
    cd "$ROOT_DIR"
    # shellcheck disable=SC2030,SC2031
    export CGO_ENABLED=1
    export GOOS=linux
    export GOARCH="$goarch"
    export CC="$cc"
    export CGO_CFLAGS="--target=$ohostgt --sysroot=$SYSROOT -fPIC -O2 -D__OHOS__=1"
    export CGO_CXXFLAGS="$CGO_CFLAGS"
    export CGO_LDFLAGS="--target=$ohostgt --sysroot=$SYSROOT"
    if [[ -n "$goarm" ]]; then
      export GOARM="$goarm"
    else
      unset GOARM || true
    fi

    # 默认走动态 libc（NDK 的 libace_ndk.z.so 等非必要不要链）
    go build \
      -buildmode=c-shared \
      -trimpath \
      -tags "$TAGS" \
      -ldflags "$LDFLAGS" \
      -o "$outdir/libclash.so" \
      ./cmd
  )

  if [[ "$STRIP_SO" == "1" ]]; then
    strip_size "$outdir/libclash.so"
  fi
}

mkdir -p "$OUT_DIR/include"

IFS=',' read -ra TARGETS <<< "$OHOS_TARGETS"
for t in "${TARGETS[@]}"; do
  case "$t" in
    aarch64-unknown-linux-ohos)  build_one "$t" arm64 ""   ;;
    armv7-unknown-linux-ohos)    build_one "$t" arm  7     ;;
    *) echo "unknown ohos target: $t" >&2; exit 1 ;;
  esac
done

# 取第一个产物的头文件作为公共 include
first_so="$(find "$OUT_DIR" -name 'libclash.so' -print -quit)"
if [[ -n "$first_so" ]]; then
  first_dir="$(dirname "$first_so")"
  if [[ -f "$first_dir/libclash.h" ]]; then
    cp "$first_dir/libclash.h" "$OUT_DIR/include/libclash.h"
  fi
fi

echo
echo "Artifacts written to $OUT_DIR"
ls -la "$OUT_DIR" 2>/dev/null
