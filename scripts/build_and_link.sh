#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/CurrencyConverter.xcodeproj"
SCHEME="CurrencyConverter"
CONFIGURATION="${CONFIGURATION:-Release}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
INSTALL_DIR="${APP_INSTALL_DIR:-/Applications}"
ARCHITECTURE="${ARCHITECTURE:-$(uname -m)}"
QUIET_BUILD="${QUIET_BUILD:-1}"
CODE_SIGN_IDENTITY_VALUE="${CODE_SIGN_IDENTITY_VALUE:--}"
KEEP_DERIVED_DATA="${KEEP_DERIVED_DATA:-0}"
APP_NAME="CurrencyConverter.app"
APP_PATH="$BUILD_DIR/$APP_NAME"
LINK_PATH="$INSTALL_DIR/$APP_NAME"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild is not available. Install Xcode and its command line tools first." >&2
  exit 1
fi

mkdir -p "$BUILD_DIR"

if [[ -n "${DERIVED_DATA_PATH:-}" ]]; then
  mkdir -p "$DERIVED_DATA_PATH"
  DERIVED_DATA_WAS_PROVIDED=1
else
  DERIVED_DATA_PATH="$(mktemp -d "$ROOT_DIR/.derivedData.XXXXXX")"
  DERIVED_DATA_WAS_PROVIDED=0
fi

cleanup() {
  if [[ "$DERIVED_DATA_WAS_PROVIDED" == "0" && "$KEEP_DERIVED_DATA" != "1" && -d "$DERIVED_DATA_PATH" ]]; then
    rm -rf "$DERIVED_DATA_PATH"
  fi
}

trap cleanup EXIT

XCODEBUILD_ARGS=(
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -destination "platform=macOS,arch=$ARCHITECTURE"
  ONLY_ACTIVE_ARCH=YES
  COMPILER_INDEX_STORE_ENABLE=NO
  CODE_SIGN_STYLE=Manual
  "CODE_SIGN_IDENTITY=$CODE_SIGN_IDENTITY_VALUE"
  DEVELOPMENT_TEAM=
  CONFIGURATION_BUILD_DIR="$BUILD_DIR"
  build
)

if [[ "$QUIET_BUILD" == "1" ]]; then
  XCODEBUILD_ARGS=(-quiet "${XCODEBUILD_ARGS[@]}")
fi

echo "Building $APP_NAME ($CONFIGURATION, arch=$ARCHITECTURE)..."
echo "If you want the full raw xcodebuild output, run with QUIET_BUILD=0."
echo "Derived data: $DERIVED_DATA_PATH"
STARTED_AT="$(date '+%Y-%m-%d %H:%M:%S')"
echo "Build started at $STARTED_AT"
xcodebuild "${XCODEBUILD_ARGS[@]}"

echo "Build finished."

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: expected app bundle was not created at $APP_PATH" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"

if [[ -e "$LINK_PATH" && ! -L "$LINK_PATH" ]]; then
  echo "error: $LINK_PATH already exists and is not a symlink." >&2
  echo "Remove or rename it, or choose another install directory with APP_INSTALL_DIR=/path." >&2
  exit 1
fi

ln -sfn "$APP_PATH" "$LINK_PATH"

echo "App bundle: $APP_PATH"
echo "Application link: $LINK_PATH"
