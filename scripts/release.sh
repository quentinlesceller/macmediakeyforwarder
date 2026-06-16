#!/usr/bin/env bash
#
# Build, sign, notarize and staple a distributable MacMediaKeyForwarder.dmg.
#
# This uses the canonical Apple flow: xcodebuild archive -> exportArchive with a
# Developer ID ExportOptions.plist (Xcode signs the app with a secure timestamp
# and the Hardened Runtime), then notarize and staple both the app and the dmg.
#
# One-time setup (stores an app-specific password in the keychain):
#
#   xcrun notarytool store-credentials "mmkf-notary" \
#       --apple-id "you@example.com" \
#       --team-id  "9K3SQ64X5H" \
#       --password "abcd-efgh-ijkl-mnop"     # app-specific password from appleid.apple.com
#
# Then just run:  ./scripts/release.sh
#
set -euo pipefail

# ---- Config ---------------------------------------------------------------
PROJECT="MacMediaKeyForwarder.xcodeproj"
SCHEME="MacMediaKeyForwarder"
CONFIG="Release"
APP_NAME="MacMediaKeyForwarder"
VOL_NAME="Mac Media Key Forwarder"
IDENTITY="Developer ID Application: Quentin Le Sceller (9K3SQ64X5H)"
NOTARY_PROFILE="${NOTARY_PROFILE:-mmkf-notary}"   # keychain profile from store-credentials
XCODEBUILD="${XCODEBUILD:-/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="build/release"
ARCHIVE="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP="$EXPORT_DIR/$APP_NAME.app"
DIST_DIR="dist"
DMG="$DIST_DIR/$APP_NAME.dmg"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

# ---- 1. Archive -----------------------------------------------------------
echo "==> Archiving $SCHEME ($CONFIG, universal)…"
"$XCODEBUILD" -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
    -archivePath "$ARCHIVE" \
    archive >/tmp/mmkf-archive.log 2>&1 \
    || { echo "Archive failed; see /tmp/mmkf-archive.log"; tail -20 /tmp/mmkf-archive.log; exit 1; }

# ---- 2. Export with Developer ID ------------------------------------------
echo "==> Exporting Developer ID app…"
"$XCODEBUILD" -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "scripts/ExportOptions.plist" >/tmp/mmkf-export.log 2>&1 \
    || { echo "Export failed; see /tmp/mmkf-export.log"; tail -20 /tmp/mmkf-export.log; exit 1; }
[ -d "$APP" ] || { echo "Exported app not found at $APP"; exit 1; }

# ---- 3. Verify the exported signature -------------------------------------
echo "==> Verifying exported signature…"
codesign --verify --deep --strict --verbose=2 "$APP"
if codesign -d --entitlements :- "$APP" 2>/dev/null | grep -q "get-task-allow"; then
    echo "ERROR: get-task-allow present in exported app; notarization would fail."; exit 1
fi
echo "    version:   $(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
echo "    bundle id: $(codesign -dvv "$APP" 2>&1 | awk -F= '/^Identifier=/{print $2}')"

# ---- 4. Notarize and staple the app ---------------------------------------
APP_ZIP="$BUILD_DIR/$APP_NAME.zip"
echo "==> Notarizing the app (profile: $NOTARY_PROFILE)…"
/usr/bin/ditto -c -k --keepParent "$APP" "$APP_ZIP"
xcrun notarytool submit "$APP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
echo "==> Stapling the app…"
xcrun stapler staple "$APP"

# ---- 5. Build the DMG (with an Applications symlink) ----------------------
echo "==> Building DMG…"
STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

# ---- 6. Sign, notarize and staple the DMG ---------------------------------
echo "==> Signing DMG…"
codesign --force --sign "$IDENTITY" --timestamp "$DMG"
echo "==> Notarizing DMG…"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
echo "==> Stapling DMG…"
xcrun stapler staple "$DMG"

# ---- 7. Final verification ------------------------------------------------
echo "==> Verifying with Gatekeeper…"
xcrun stapler validate "$DMG"
spctl -a -t open --context context:primary-signature -vvv "$DMG" || true
spctl -a -vvv "$APP"

echo
echo "Done. Distributable: $DMG"
echo "SHA-256: $(shasum -a 256 "$DMG" | cut -d' ' -f1)"
