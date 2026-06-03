#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-"$ROOT_DIR/dist/android"}"
API_LEVEL="${ANDROID_API_LEVEL:-21}"
TAGS="${GO_TAGS:-foss,with_gvisor,cmfa}"
PACKAGE="${GO_PACKAGE:-github.com/Ember-Moth/libclash}"
JAVA_PKG="${JAVA_PKG:-com.github.embermoth}"
AAR_NAME="${AAR_NAME:-libclash.aar}"
NDK_DIR="${ANDROID_NDK_HOME:-${NDK_HOME:-}}"

if [[ -z "$NDK_DIR" ]]; then
  echo "ANDROID_NDK_HOME or NDK_HOME is required" >&2
  exit 1
fi

if ! command -v gomobile >/dev/null 2>&1; then
  echo "gomobile is required; install golang.org/x/mobile/cmd/gomobile" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

(
  cd "$ROOT_DIR"
  export ANDROID_NDK_HOME="$NDK_DIR"

  gomobile bind \
    -target "${GOMOBILE_TARGET:-android}" \
    -androidapi "$API_LEVEL" \
    -javapkg "$JAVA_PKG" \
    -trimpath \
    -tags "$TAGS" \
    -o "$OUT_DIR/$AAR_NAME" \
    "$PACKAGE"
)

echo "Artifact written to $OUT_DIR/$AAR_NAME"
