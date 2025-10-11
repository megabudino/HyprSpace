#!/usr/bin/env bash
set -euo pipefail

# Script to create a DMG installer for HyprSpace
# Usage: ./create-dmg.sh output.dmg HyprSpace.app

if [ $# -ne 2 ]; then
    echo "Usage: $0 <output.dmg> <app-path>"
    echo "Example: $0 HyprSpace-v1.0.0.dmg HyprSpace.app"
    exit 1
fi

OUTPUT_DMG="$1"
APP_PATH="$2"
VOLUME_NAME="HyprSpace"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

# Create a temporary directory for the DMG contents
TEMP_DIR=$(mktemp -d)
trap "rm -rf '$TEMP_DIR'" EXIT

echo "Creating DMG installer..."

# Copy the app to the temporary directory
cp -R "$APP_PATH" "$TEMP_DIR/"

# Create a symbolic link to /Applications
ln -s /Applications "$TEMP_DIR/Applications"

# Create the DMG with a nice layout
# First create a raw DMG
hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$TEMP_DIR" \
    -ov -format UDRW \
    -size 200m \
    temp.dmg

# Mount the DMG
MOUNT_DIR="/Volumes/$VOLUME_NAME"
hdiutil attach temp.dmg -readwrite -noverify -mountpoint "$MOUNT_DIR"

# Set the background and icon positions using AppleScript
osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 900, 450}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 100
        set position of item "HyprSpace.app" of container window to {150, 180}
        set position of item "Applications" of container window to {350, 180}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Add a background image if we have one
if [ -f "dmg-background.png" ]; then
    mkdir "$MOUNT_DIR/.background"
    cp dmg-background.png "$MOUNT_DIR/.background/background.png"

    osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set theViewOptions to the icon view options of container window
        set background picture of theViewOptions to file ".background:background.png"
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF
fi

# Unmount the DMG
hdiutil detach "$MOUNT_DIR"

# Convert to compressed DMG
hdiutil convert temp.dmg -format UDZO -imagekey zlib-level=9 -o "$OUTPUT_DMG"

# Clean up
rm -f temp.dmg

# Sign the DMG if we have a signing identity
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
    echo "Signing DMG with identity: $CODESIGN_IDENTITY"
    codesign --sign "$CODESIGN_IDENTITY" "$OUTPUT_DMG"
fi

# Notarize if credentials are available
if [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_ID_PASSWORD:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ]; then
    echo "Notarizing DMG..."
    xcrun notarytool submit "$OUTPUT_DMG" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_ID_PASSWORD" \
        --team-id "$APPLE_TEAM_ID" \
        --wait

    # Staple the notarization
    xcrun stapler staple "$OUTPUT_DMG"
fi

echo "DMG created successfully: $OUTPUT_DMG"
ls -lh "$OUTPUT_DMG"