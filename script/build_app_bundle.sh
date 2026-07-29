#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-debug}"
APP_NAME="Formic"

case "$CONFIGURATION" in
  debug|release)
    ;;
  *)
    echo "usage: $0 [debug|release]" >&2
    exit 2
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
INFO_PLIST_SOURCE="$ROOT_DIR/Resources/Info.plist"
APP_ICON_SOURCE="$ROOT_DIR/Resources/Formic.icns"

FORMIC_VERSION="${FORMIC_VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST_SOURCE")}"
FORMIC_BUILD_NUMBER="${FORMIC_BUILD_NUMBER:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST_SOURCE")}"

if [[ ! "$FORMIC_VERSION" =~ ^[0-9A-Za-z][0-9A-Za-z.-]*$ ]]; then
  echo "FORMIC_VERSION contains unsupported characters: $FORMIC_VERSION" >&2
  exit 2
fi

if [[ ! "$FORMIC_BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "FORMIC_BUILD_NUMBER must be a positive integer." >&2
  exit 2
fi

swift build --package-path "$ROOT_DIR" --configuration "$CONFIGURATION"
BUILD_BINARY="$(swift build --package-path "$ROOT_DIR" --configuration "$CONFIGURATION" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$APP_ICON_SOURCE" "$APP_RESOURCES/Formic.icns"
cp "$INFO_PLIST_SOURCE" "$INFO_PLIST"
chmod +x "$APP_BINARY"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $FORMIC_VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $FORMIC_BUILD_NUMBER" "$INFO_PLIST"
/usr/bin/plutil -lint "$INFO_PLIST"

# Seal the complete bundle after its executable and resources are in place.
# This is an ad-hoc signature for local/internal use, not a Developer ID signature.
/usr/bin/codesign --force --sign - "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "Built $APP_BUNDLE ($CONFIGURATION, version $FORMIC_VERSION, build $FORMIC_BUILD_NUMBER)"
