#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH_DIR="${ROOT_DIR}/.build-release"
DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/A taste of Gray.app"
EXECUTABLE_PATH="${SCRATCH_DIR}/release/ATasteOfGray"
TMP_ROOT="${TMPDIR:-/tmp}"
ICONSET_DIR="${TMP_ROOT}/atasteofgray.iconset"
ICON_PATH="${APP_DIR}/Contents/Resources/AppIcon.icns"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-${TMP_ROOT}/atasteofgray-clang-cache}"
export SWIFTPM_CUSTOM_CACHE_DIR="${SWIFTPM_CUSTOM_CACHE_DIR:-${TMP_ROOT}/atasteofgray-swiftpm-cache}"

swift build -c release --product ATasteOfGray --scratch-path "${SCRATCH_DIR}"

rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${EXECUTABLE_PATH}" "${APP_DIR}/Contents/MacOS/ATasteOfGray"

rm -rf "${ICONSET_DIR}"
swift "${ROOT_DIR}/scripts/generate-icon.swift" "${ICONSET_DIR}"
iconutil -c icns "${ICONSET_DIR}" -o "${ICON_PATH}"
rm -rf "${ICONSET_DIR}"

cat > "${APP_DIR}/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>ATasteOfGray</string>
    <key>CFBundleIdentifier</key>
    <string>com.mayabazar.atasteofgray</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleDisplayName</key>
    <string>A taste of Gray</string>
    <key>CFBundleName</key>
    <string>A taste of Gray</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

touch "${APP_DIR}"
printf 'Created %s\n' "${APP_DIR}"
