#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Formic"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
INFO_PLIST_SOURCE="$ROOT_DIR/Resources/Info.plist"
FORMIC_VERSION="${FORMIC_VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST_SOURCE")}"
DMG_NAME="$APP_NAME-$FORMIC_VERSION.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

if [[ ! "$FORMIC_VERSION" =~ ^[0-9A-Za-z][0-9A-Za-z.-]*$ ]]; then
  echo "FORMIC_VERSION contains unsupported characters: $FORMIC_VERSION" >&2
  exit 2
fi

"$ROOT_DIR/script/build_app_bundle.sh" release

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/formic-dmg.XXXXXX")"
STAGING_DIR="$WORK_DIR/Formic"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$STAGING_DIR"
/usr/bin/ditto "$DIST_DIR/$APP_NAME.app" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

/usr/bin/hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$DMG_PATH"

/usr/bin/hdiutil verify "$DMG_PATH"
(
  cd "$DIST_DIR"
  /usr/bin/shasum -a 256 "$DMG_NAME" >"$DMG_NAME.sha256"
)

echo "Created $DMG_PATH"
echo "Checksum: $DMG_PATH.sha256"
echo "This development DMG is ad-hoc signed and not notarized."
