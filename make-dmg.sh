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

# --- Signing / notarization (optional) ---------------------------------------
# To produce a notarized, Gatekeeper-clean .dmg, set these (e.g. in your shell):
#   export DISKOVERY_SIGN_IDENTITY="Developer ID Application: Jean Dupont (ABCDE12345)"
#   export DISKOVERY_NOTARY_PROFILE="diskovery"   # from `xcrun notarytool store-credentials`
# Leave them empty to fall back to a clean ad-hoc signature (dev / non-notarized).
SIGN_IDENTITY="${DISKOVERY_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${DISKOVERY_NOTARY_PROFILE:-}"

# --- Paths (resolve relative to this script) ---------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
MACOS_DIR="${APP_DIR}/Contents/MacOS"
RESOURCES_DIR="${APP_DIR}/Contents/Resources"
INFO_PLIST="${APP_DIR}/Contents/Info.plist"
DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"
EXECUTABLE_SRC="${SCRIPT_DIR}/.build/release/${APP_NAME}"
ICON_SRC="${SCRIPT_DIR}/icon/AppIcon.png"
ICNS_NAME="AppIcon"
DMG_BG="${SCRIPT_DIR}/icon/dmg-background.tiff"
DMG_WINDOW_W=600
DMG_WINDOW_H=400

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

# --- 3b. Generate the app icon (.icns) from icon/AppIcon.png -----------------
ICON_PLIST_KEYS=""
if [[ -f "${ICON_SRC}" ]]; then
    echo "==> Generating app icon"
    ICONSET="$(mktemp -d)/${ICNS_NAME}.iconset"
    mkdir -p "${ICONSET}"
    # macOS expects these exact size/scale variants.
    for spec in "16 16x16" "32 16x16@2x" "32 32x32" "64 32x32@2x" \
                "128 128x128" "256 128x128@2x" "256 256x256" "512 256x256@2x" \
                "512 512x512" "1024 512x512@2x"; do
        size="${spec% *}"
        label="${spec#* }"
        sips -z "${size}" "${size}" "${ICON_SRC}" --out "${ICONSET}/icon_${label}.png" >/dev/null
    done
    iconutil -c icns "${ICONSET}" -o "${RESOURCES_DIR}/${ICNS_NAME}.icns"
    rm -rf "$(dirname "${ICONSET}")"
    ICON_PLIST_KEYS=$'\t<key>CFBundleIconFile</key>\n\t<string>'"${ICNS_NAME}"$'</string>\n\t<key>CFBundleIconName</key>\n\t<string>'"${ICNS_NAME}"$'</string>'
else
    echo "==> No icon found at ${ICON_SRC}, skipping"
fi

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
${ICON_PLIST_KEYS}
</dict>
</plist>
PLIST

# Validate the plist before continuing.
echo "==> Validating Info.plist"
plutil -lint "${INFO_PLIST}"

# --- 3c. Sign the bundle -----------------------------------------------------
if [[ -n "${SIGN_IDENTITY}" ]]; then
    # Developer ID signature with hardened runtime + secure timestamp (required
    # for notarization). Result: a Gatekeeper-clean app once notarized.
    echo "==> Signing with Developer ID: ${SIGN_IDENTITY}"
    codesign --force --deep --options runtime --timestamp \
        --sign "${SIGN_IDENTITY}" "${APP_DIR}"
else
    # Fallback: clean ad-hoc signature (NOT notarized — first-launch warning,
    # see README "Première ouverture").
    echo "==> Ad-hoc signing the bundle (not notarized)"
    codesign --force --deep --sign - "${APP_DIR}"
fi
codesign --verify --deep --strict "${APP_DIR}" && echo "    signature OK"

# --- 3d. Notarize + staple the app -------------------------------------------
# Notarize the app itself (then staple it) so the copied-out .app works offline.
if [[ -n "${SIGN_IDENTITY}" && -n "${NOTARY_PROFILE}" ]]; then
    echo "==> Notarizing (this can take a minute)"
    NOTARIZE_ZIP="${DIST_DIR}/${APP_NAME}-notarize.zip"
    ditto -c -k --keepParent "${APP_DIR}" "${NOTARIZE_ZIP}"
    xcrun notarytool submit "${NOTARIZE_ZIP}" \
        --keychain-profile "${NOTARY_PROFILE}" --wait
    rm -f "${NOTARIZE_ZIP}"

    echo "==> Stapling the notarization ticket"
    xcrun stapler staple "${APP_DIR}"
    xcrun stapler validate "${APP_DIR}"
elif [[ -n "${SIGN_IDENTITY}" ]]; then
    echo "==> Signed with Developer ID but DISKOVERY_NOTARY_PROFILE unset — skipping notarization"
fi

# --- 4. Create .dmg (with drag-to-Applications layout) -----------------------
# Stage the app next to a symlink to /Applications (so users can drag the app
# onto Applications), plus a background image, then lay out the Finder window.
echo "==> Creating ${APP_NAME}.dmg"
STAGING_PARENT="$(mktemp -d)"
STAGING="${STAGING_PARENT}/stage"
mkdir -p "${STAGING}/.background"
ditto "${APP_DIR}" "${STAGING}/${APP_NAME}.app"
ln -s /Applications "${STAGING}/Applications"
[[ -f "${DMG_BG}" ]] && cp "${DMG_BG}" "${STAGING}/.background/background.tiff"

# Build a read-write image we can lay out, then convert to compressed read-only.
RW_DMG="${STAGING_PARENT}/rw.dmg"
hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGING}" \
    -ov -format UDRW "${RW_DMG}" >/dev/null

# Detach any stale volume of the same name so we mount at a predictable path.
for v in "/Volumes/${APP_NAME}"*; do
    [[ -d "$v" ]] && hdiutil detach "$v" >/dev/null 2>&1 || true
done

ATTACH_OUT="$(hdiutil attach "${RW_DMG}" -noautoopen)"
DEVICE="$(echo "${ATTACH_OUT}" | grep -E '^/dev/' | head -1 | awk '{print $1}')"
MOUNT_DIR="$(echo "${ATTACH_OUT}" | sed -nE 's#.*(/Volumes/.*)$#\1#p' | head -1)"
VOL_NAME="$(basename "${MOUNT_DIR}")"

# Finder layout (background, icon size, positions). Non-fatal: if Finder
# automation is denied, the .dmg still works (just without the pretty layout).
if [[ -n "${VOL_NAME}" && -f "${MOUNT_DIR}/.background/background.tiff" ]]; then
    echo "==> Laying out the .dmg window"
    osascript - "${VOL_NAME}" "${APP_NAME}" "${DMG_WINDOW_W}" "${DMG_WINDOW_H}" <<'OSA' || echo "    (mise en page Finder ignorée — autorisation refusée ?)"
on run argv
    set volName to item 1 of argv
    set appName to item 2 of argv
    set winW to (item 3 of argv) as integer
    set winH to (item 4 of argv) as integer
    tell application "Finder"
        tell disk volName
            open
            set theWindow to container window
            set current view of theWindow to icon view
            set toolbar visible of theWindow to false
            set statusbar visible of theWindow to false
            set the bounds of theWindow to {200, 120, 200 + winW, 120 + winH}
            set opts to the icon view options of theWindow
            set arrangement of opts to not arranged
            set icon size of opts to 128
            set text size of opts to 12
            set background picture of opts to file ".background:background.tiff"
            set position of item (appName & ".app") of theWindow to {150, 200}
            set position of item "Applications" of theWindow to {450, 200}
            update without registering applications
            delay 1
            close
        end tell
    end tell
end run
OSA
fi

sync
hdiutil detach "${DEVICE}" >/dev/null 2>&1 || hdiutil detach "${MOUNT_DIR}" >/dev/null 2>&1 || true
hdiutil convert "${RW_DMG}" -format UDZO -ov -o "${DMG_PATH}" >/dev/null
rm -rf "${STAGING_PARENT}"

# --- 5. Notarize + staple the .dmg itself ------------------------------------
# So the downloaded .dmg opens cleanly too (not just the app inside it).
if [[ -n "${SIGN_IDENTITY}" && -n "${NOTARY_PROFILE}" ]]; then
    echo "==> Notarizing the .dmg"
    xcrun notarytool submit "${DMG_PATH}" \
        --keychain-profile "${NOTARY_PROFILE}" --wait
    echo "==> Stapling the .dmg"
    xcrun stapler staple "${DMG_PATH}"
    xcrun stapler validate "${DMG_PATH}"
fi

echo "==> Done"
echo "    App: ${APP_DIR}"
echo "    DMG: ${DMG_PATH}"
