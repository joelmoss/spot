#!/bin/bash
set -euo pipefail

APP_NAME="Spot"
BUNDLE_DIR="build/${APP_NAME}.app"
TEAM_ID="B898J443L9"
SIGNING_IDENTITY="Developer ID Application: Joel Moss (${TEAM_ID})"
NOTARY_PROFILE="spot-notary"
ENTITLEMENTS="scripts/entitlements.plist"

echo "Building ${APP_NAME} (release)..."
swift build -c release

echo "Creating app bundle..."
rm -rf build
mkdir -p "${BUNDLE_DIR}/Contents/MacOS"
mkdir -p "${BUNDLE_DIR}/Contents/Resources"
mkdir -p "${BUNDLE_DIR}/Contents/Frameworks"

cp .build/release/Spot "${BUNDLE_DIR}/Contents/MacOS/Spot"
cp Info.plist "${BUNDLE_DIR}/Contents/Info.plist"
cp Sources/Spot/Resources/AppIcon.icns "${BUNDLE_DIR}/Contents/Resources/"
cp -R .build/release/Spot_Spot.bundle "${BUNDLE_DIR}/Contents/Resources/"
cp -R .build/release/Sparkle.framework "${BUNDLE_DIR}/Contents/Frameworks/"
install_name_tool -add_rpath @executable_path/../Frameworks "${BUNDLE_DIR}/Contents/MacOS/Spot"

echo "Signing Sparkle framework..."
codesign --force --options runtime --timestamp \
    --sign "${SIGNING_IDENTITY}" \
    "${BUNDLE_DIR}/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc" \
    "${BUNDLE_DIR}/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc" \
    "${BUNDLE_DIR}/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" \
    "${BUNDLE_DIR}/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app" \
    "${BUNDLE_DIR}/Contents/Frameworks/Sparkle.framework"

echo "Signing app bundle..."
codesign --force --options runtime --timestamp \
    --sign "${SIGNING_IDENTITY}" \
    --entitlements "${ENTITLEMENTS}" \
    "${BUNDLE_DIR}"

echo "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "${BUNDLE_DIR}"

echo "Creating DMG..."
DMG_PATH="build/${APP_NAME}.dmg"
rm -f "${DMG_PATH}"
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${BUNDLE_DIR}" \
    -ov -format UDZO \
    "${DMG_PATH}" \
    -quiet

echo "Signing DMG..."
codesign --force --timestamp \
    --sign "${SIGNING_IDENTITY}" \
    "${DMG_PATH}"

echo "Submitting for notarization..."
xcrun notarytool submit "${DMG_PATH}" \
    --keychain-profile "${NOTARY_PROFILE}" \
    --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "${DMG_PATH}"

echo ""
echo "Done!"
echo "  App bundle: ${BUNDLE_DIR}"
echo "  DMG:        ${DMG_PATH}"
