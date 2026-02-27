#!/bin/bash
set -euo pipefail

APP_NAME="Spot"
BUNDLE_DIR="build/${APP_NAME}.app"

echo "Building ${APP_NAME} (release)..."
swift build -c release

echo "Creating app bundle..."
rm -rf build
mkdir -p "${BUNDLE_DIR}/Contents/MacOS"
mkdir -p "${BUNDLE_DIR}/Contents/Resources"

cp .build/release/Spot "${BUNDLE_DIR}/Contents/MacOS/Spot"
cp Info.plist "${BUNDLE_DIR}/Contents/Info.plist"

echo "Creating DMG..."
DMG_PATH="build/${APP_NAME}.dmg"
rm -f "${DMG_PATH}"
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${BUNDLE_DIR}" \
    -ov -format UDZO \
    "${DMG_PATH}" \
    -quiet

echo ""
echo "Done!"
echo "  App bundle: ${BUNDLE_DIR}"
echo "  DMG:        ${DMG_PATH}"
