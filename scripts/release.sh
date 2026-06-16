#!/usr/bin/env bash
#
# Build, sign, notarize and staple a distributable MacMediaKeyForwarder.app.
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
TARGET="MacMediaKeyForwarder"
CONFIG="Release"
IDENTITY="Developer ID Application: Quentin Le Sceller (9K3SQ64X5H)"
ENTITLEMENTS="MacMediaKeyForwarder/MacMediaKeyForwarder.entitlements"
NOTARY_PROFILE="${NOTARY_PROFILE:-mmkf-notary}"   # keychain profile name from store-credentials
XCODEBUILD="${XCODEBUILD:-/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="build/$CONFIG/$TARGET.app"
DIST_DIR="dist"
ZIP="$DIST_DIR/$TARGET.zip"

# ---- 1. Build -------------------------------------------------------------
echo "==> Building $CONFIG (universal)…"
"$XCODEBUILD" -project "$PROJECT" -target "$TARGET" -configuration "$CONFIG" \
    clean build >/tmp/mmkf-build.log 2>&1 \
    || { echo "Build failed; see /tmp/mmkf-build.log"; tail -20 /tmp/mmkf-build.log; exit 1; }
[ -d "$APP" ] || { echo "App not found at $APP"; exit 1; }

# ---- 2. Deep re-sign for distribution -------------------------------------
# Sign nested code inside-out first, then the app bundle. We pass our own
# entitlements (no get-task-allow) and --timestamp for a secure timestamp;
# both are required for notarization.
echo "==> Re-signing nested frameworks/dylibs…"
find "$APP/Contents/Frameworks" \( -name "*.dylib" -o -name "*.framework" \) -print0 2>/dev/null |
    while IFS= read -r -d '' item; do
        codesign --force --options runtime --timestamp --sign "$IDENTITY" "$item"
    done

echo "==> Re-signing app bundle…"
codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$IDENTITY" "$APP"

# ---- 3. Verify signature --------------------------------------------------
echo "==> Verifying signature…"
codesign --verify --deep --strict --verbose=2 "$APP"
if codesign -d --entitlements :- "$APP" 2>/dev/null | grep -q "get-task-allow"; then
    echo "ERROR: get-task-allow still present — notarization will fail."; exit 1
fi

# ---- 4. Zip for submission ------------------------------------------------
echo "==> Zipping…"
mkdir -p "$DIST_DIR"
rm -f "$ZIP"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"

# ---- 5. Notarize ----------------------------------------------------------
echo "==> Submitting to notary service (profile: $NOTARY_PROFILE)…"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

# ---- 6. Staple + re-zip the stapled app -----------------------------------
echo "==> Stapling…"
xcrun stapler staple "$APP"
rm -f "$ZIP"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"

# ---- 7. Final gatekeeper verification -------------------------------------
echo "==> Verifying with Gatekeeper…"
xcrun stapler validate "$APP"
spctl -a -vvv "$APP"

echo
echo "Done. Distributable: $ZIP"
