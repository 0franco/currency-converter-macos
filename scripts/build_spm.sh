#!/bin/bash

# Build CurrencyConverter using Swift Package Manager (no Xcode required).
# Only the macOS Command Line Tools need to be installed.
#
# Usage:
#   bash scripts/build_spm.sh
#
# Environment overrides:
#   CONFIGURATION   Debug or Release (default: Release)
#   BUILD_DIR       Output directory for the .app bundle (default: ./build)
#   APP_INSTALL_DIR Symlink destination (default: /Applications)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
INSTALL_DIR="${APP_INSTALL_DIR:-/Applications}"
APP_NAME="CurrencyConverter.app"
APP_PATH="$BUILD_DIR/$APP_NAME"
LINK_PATH="$INSTALL_DIR/$APP_NAME"

# Normalise configuration for swift build (lowercase)
SWIFT_CONFIG="$(echo "$CONFIGURATION" | tr '[:upper:]' '[:lower:]')"
if [[ "$SWIFT_CONFIG" != "debug" && "$SWIFT_CONFIG" != "release" ]]; then
  echo "error: CONFIGURATION must be 'debug' or 'release', got '$CONFIGURATION'" >&2
  exit 1
fi

# Verify swift is available
if ! command -v swift >/dev/null 2>&1; then
  echo "error: Swift is not available. Install Xcode Command Line Tools:" >&2
  echo "  xcode-select --install" >&2
  exit 1
fi

echo "Building CurrencyConverter via Swift Package Manager ($SWIFT_CONFIG)..."
echo "This does NOT require Xcode — only the Command Line Tools."
echo ""

# 1. Build the executable target
swift build \
  --package-path "$ROOT_DIR" \
  --product CurrencyConverter \
  -c "$SWIFT_CONFIG" \
  2>&1

BUILT_BINARY="$(swift build --package-path "$ROOT_DIR" --product CurrencyConverter -c "$SWIFT_CONFIG" --show-bin-path)/CurrencyConverter"

if [[ ! -f "$BUILT_BINARY" ]]; then
  echo "error: swift build succeeded but binary not found at $BUILT_BINARY" >&2
  exit 1
fi

echo ""
echo "Binary built at: $BUILT_BINARY"

# 2. Assemble the .app bundle
echo "Assembling $APP_NAME..."

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Copy binary
cp "$BUILT_BINARY" "$APP_PATH/Contents/MacOS/CurrencyConverter"

# Generate Info.plist (expanding build variables that Xcode normally resolves)
cat > "$APP_PATH/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>CurrencyConverter</string>
	<key>CFBundleIdentifier</key>
	<string>com.converter.CurrencyConverter</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>CurrencyConverter</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSUIElement</key>
	<true/>
</dict>
</plist>
PLIST

# Copy app icon if present
ICON_SOURCE="$ROOT_DIR/CurrencyConverter/Assets.xcassets/AppIcon.appiconset"
if [[ -d "$ICON_SOURCE" ]]; then
  # Create a minimal .icns from the largest available PNG using sips + iconutil
  ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET_DIR"

  # Map the PNG sizes to the iconset naming convention
  for size in 16 32 64 128 256 512; do
    src="$ICON_SOURCE/icon_${size}x${size}.png"
    if [[ -f "$src" ]]; then
      cp "$src" "$ICONSET_DIR/icon_${size}x${size}.png"
    fi
  done

  # Also create @2x variants where source PNGs exist at double size
  for size in 16 32 128 256; do
    double=$((size * 2))
    src="$ICON_SOURCE/icon_${double}x${double}.png"
    if [[ -f "$src" ]]; then
      cp "$src" "$ICONSET_DIR/icon_${size}x${size}@2x.png"
    fi
  done

  # 512@2x from 1024
  if [[ -f "$ICON_SOURCE/icon_1024x1024.png" ]]; then
    cp "$ICON_SOURCE/icon_1024x1024.png" "$ICONSET_DIR/icon_512x512@2x.png"
  fi

  if command -v iconutil >/dev/null 2>&1; then
    iconutil -c icns -o "$APP_PATH/Contents/Resources/AppIcon.icns" "$ICONSET_DIR" 2>/dev/null || true
    # Point Info.plist to the icon
    if [[ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]]; then
      /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
    fi
  fi

  rm -rf "$(dirname "$ICONSET_DIR")"
fi

# 3. Ad-hoc sign
echo "Ad-hoc signing..."
codesign --force --sign - "$APP_PATH" 2>/dev/null || true

# 4. Install (symlink)
mkdir -p "$INSTALL_DIR"

if [[ -e "$LINK_PATH" && ! -L "$LINK_PATH" ]]; then
  echo "error: $LINK_PATH already exists and is not a symlink." >&2
  echo "Remove or rename it, or choose another install directory with APP_INSTALL_DIR=/path." >&2
  exit 1
fi

ln -sfn "$APP_PATH" "$LINK_PATH"

echo ""
echo "✅ Done!"
echo "   App bundle:  $APP_PATH"
echo "   Symlinked:   $LINK_PATH"
echo ""
echo "   Open it with:  open $APP_PATH"
echo "   Or find it in: $INSTALL_DIR"
