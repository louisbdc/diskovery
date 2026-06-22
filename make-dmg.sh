#!/bin/bash
#
# make-dmg.sh - Build Diskovery and package it as an unsigned .dmg for personal use.
#
# Produces:
#   dist/Diskovery.app  - a proper macOS application bundle
#   dist/Diskovery.dmg  - a disk image containing the .app
#
# Idempotent: dist/ is wiped on every run.

set -euo pipefail

# --- Configuration -----------------------------------------------------------
APP_NAME="Diskovery"
BUNDLE_ID="com.louis.diskovery"
SHORT_VERSION="1.0.0"
BUILD_VERSION="1"
MIN_SYSTEM_VERSION="14.0"

# --- Paths (resolve relative to this script) ---------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
MACOS_DIR="${APP_DIR}/Contents/MacOS"
RESOURCES_DIR="${APP_DIR}/Contents/Resources"
INFO_PLIST="${APP_DIR}/Contents/Info.plist"
DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"
EXECUTABLE_SRC="${SCRIPT_DIR}/.build/release/${APP_NAME}"

# --- 1. Build release --------------------------------------------------------
echo "==> Building release with swift build -c release"
swift build -c release --package-path "${SCRIPT_DIR}"

if [[ ! -f "${EXECUTABLE_SRC}" ]]; then
    echo "ERROR: expected executable not found at ${EXECUTABLE_SRC}" >&2
    exit 1
fi

# --- 2. Clean dist (idempotency) ---------------------------------------------
echo "==> Cleaning ${DIST_DIR}"
rm -rf "${DIST_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# --- 3. Assemble .app bundle -------------------------------------------------
echo "==> Assembling ${APP_NAME}.app"
cp "${EXECUTABLE_SRC}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

cat > "${INFO_PLIST}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>${APP_NAME}</string>
	<key>CFBundleDisplayName</key>
	<string>${APP_NAME}</string>
	<key>CFBundleIdentifier</key>
	<string>${BUNDLE_ID}</string>
	<key>CFBundleExecutable</key>
	<string>${APP_NAME}</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleShortVersionString</key>
	<string>${SHORT_VERSION}</string>
	<key>CFBundleVersion</key>
	<string>${BUILD_VERSION}</string>
	<key>LSMinimumSystemVersion</key>
	<string>${MIN_SYSTEM_VERSION}</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST

# Validate the plist before continuing.
echo "==> Validating Info.plist"
plutil -lint "${INFO_PLIST}"

# --- 4. Create .dmg ----------------------------------------------------------
echo "==> Creating ${APP_NAME}.dmg"
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${APP_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

echo "==> Done"
echo "    App: ${APP_DIR}"
echo "    DMG: ${DMG_PATH}"
