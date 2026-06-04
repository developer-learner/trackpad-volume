#!/bin/bash
set -euo pipefail

APP_NAME="trackpad-volume"
SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEST_DIR="$HOME/Applications"

echo "==> Building release binary..."
swift build -c release --package-path "$SRC_DIR"

echo "==> Copying to $DEST_DIR/$APP_NAME.app..."
rm -rf "$DEST_DIR/$APP_NAME.app"
mkdir -p "$DEST_DIR/$APP_NAME.app/Contents/MacOS"
cp "$SRC_DIR/.build/release/$APP_NAME" "$DEST_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME"
cp "$SRC_DIR/$APP_NAME.app/Contents/Info.plist" "$DEST_DIR/$APP_NAME.app/Contents/Info.plist"

echo "==> Installing LaunchAgent..."
cp "$SRC_DIR/com.user.trackpad-volume.plist" "$HOME/Library/LaunchAgents/com.user.trackpad-volume.plist"
launchctl load "$HOME/Library/LaunchAgents/com.user.trackpad-volume.plist"

echo "==> Done. Binary at: $DEST_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME"
echo ""
echo "If you haven't granted Accessibility permission yet:"
echo "  System Settings → Privacy & Security → Accessibility → add $APP_NAME"
echo ""
echo "To unload: launchctl unload ~/Library/LaunchAgents/com.user.trackpad-volume.plist"
