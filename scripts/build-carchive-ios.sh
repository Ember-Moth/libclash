#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-"$ROOT_DIR/dist/cshared/ios"}"
IOS_MIN_VERSION="${IOS_MIN_VERSION:-13.0}"
TAGS="${GO_TAGS:-foss,with_gvisor}"
LDFLAGS="${GO_LDFLAGS:--s -w}"
BUILD_SIMULATOR_X64="${BUILD_SIMULATOR_X64:-1}"

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun is required; run this script on macOS with Xcode installed" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

make_cc_wrapper() {
  local name="$1"
  local sdk="$2"
  local arch="$3"
  local min_flag="$4"
  local clang
  local sdk_path
  local wrapper

  clang="$(xcrun --sdk "$sdk" --find clang)"
  sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"
  wrapper="$WORK_DIR/cc-$name"

  cat > "$wrapper" <<EOF
#!/usr/bin/env bash
exec "$clang" -arch "$arch" -isysroot "$sdk_path" "$min_flag=$IOS_MIN_VERSION" "\$@"
EOF
  chmod +x "$wrapper"
  printf '%s\n' "$wrapper"
}

build_archive() {
  local name="$1"
  local sdk="$2"
  local goarch="$3"
  local clang_arch="$4"
  local min_flag="$5"
  local target_dir="$OUT_DIR/$name"
  local archive_path="$target_dir/libclash.a"
  local cc_wrapper

  mkdir -p "$target_dir"
  cc_wrapper="$(make_cc_wrapper "$name" "$sdk" "$clang_arch" "$min_flag")"

  echo "Building iOS archive: $name"
  (
    cd "$ROOT_DIR"
    export CGO_ENABLED=1
    export GOOS=ios
    export GOARCH="$goarch"
    export CC="$cc_wrapper"

    go build \
      -buildmode=c-archive \
      -trimpath \
      -tags "$TAGS" \
      -ldflags "$LDFLAGS" \
      -o "$archive_path" \
      ./cmd
  )
}

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/include"

build_archive "iphoneos-arm64" "iphoneos" "arm64" "arm64" "-miphoneos-version-min"
build_archive "iphonesimulator-arm64" "iphonesimulator" "arm64" "arm64" "-mios-simulator-version-min"

sim_archives=("$OUT_DIR/iphonesimulator-arm64/libclash.a")
if [[ "$BUILD_SIMULATOR_X64" != "0" ]]; then
  build_archive "iphonesimulator-x64" "iphonesimulator" "amd64" "x86_64" "-mios-simulator-version-min"
  sim_archives+=("$OUT_DIR/iphonesimulator-x64/libclash.a")
fi

cp "$OUT_DIR/iphoneos-arm64/libclash.h" "$OUT_DIR/include/libclash.h"

mkdir -p "$OUT_DIR/iphonesimulator"
if [[ "${#sim_archives[@]}" -gt 1 ]]; then
  xcrun lipo -create "${sim_archives[@]}" -output "$OUT_DIR/iphonesimulator/libclash.a"
else
  cp "${sim_archives[0]}" "$OUT_DIR/iphonesimulator/libclash.a"
fi
cp "$OUT_DIR/iphonesimulator-arm64/libclash.h" "$OUT_DIR/iphonesimulator/libclash.h"

rm -rf "$OUT_DIR/libclash.xcframework"
xcodebuild -create-xcframework \
  -library "$OUT_DIR/iphoneos-arm64/libclash.a" \
  -headers "$OUT_DIR/include" \
  -library "$OUT_DIR/iphonesimulator/libclash.a" \
  -headers "$OUT_DIR/include" \
  -output "$OUT_DIR/libclash.xcframework"

echo "Artifacts written to $OUT_DIR"
