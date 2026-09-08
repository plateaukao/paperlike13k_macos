#!/bin/bash

cd "$(dirname "$0")"

APP_NAME="PaperlikeNative"
APP_DIR="$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Creating App Bundle Directory Structure..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "Writing Info.plist..."
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.paperlike.native</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>0.2</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "Compiling Swift UI App..."
swiftc PaperlikeCore.swift PaperlikeNativeApp.swift CarbonHotkeyManager.swift -o "$MACOS_DIR/$APP_NAME"

# Sign the *bundle* (not the bare binary) so Info.plist is bound and resources
# are sealed, with a stable identifier matching CFBundleIdentifier. macOS Tahoe
# 26.1+ keys TCC/permissions on a stable signing identity; the default swiftc
# ad-hoc "linker-signed" identity (Identifier=PaperlikeNative, Info.plist not
# bound) is treated as untrusted. No Developer ID available, so we ad-hoc sign
# (-s -) with hardened runtime + the serial/usb entitlements.
echo "Code signing bundle..."
codesign --force --deep --options runtime \
    --entitlements paperlike.entitlements \
    --identifier com.paperlike.native \
    -s - "$APP_DIR"

echo "Verifying signature..."
codesign -dvvv "$APP_DIR" 2>&1 | grep -E "Identifier|Sealed|TeamIdentifier" || true

echo "Done! The app is located at $APP_DIR"
echo "NOTE: downloaded copies are quarantined by Gatekeeper. On the target Mac run:"
echo "  xattr -dr com.apple.quarantine \"$APP_DIR\""
