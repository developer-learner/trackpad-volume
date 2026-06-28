#!/bin/bash
set -euo pipefail

APP_NAME="trackpad-volume"
SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEST_DIR="$HOME/Applications"
BUNDLE_DIR="$DEST_DIR/$APP_NAME.app"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"

SIGN_IDENTITY="TrackpadVolume Dev"

echo "==> Checking code signing identity..."
touch /tmp/.signtest
if ! codesign -fs "$SIGN_IDENTITY" --timestamp=none /tmp/.signtest 2>/dev/null; then
    rm -f /tmp/.signtest
    echo "ERROR: Cannot sign with '$SIGN_IDENTITY'."
    echo "Create it in Keychain Access → Certificate Assistant → Create a Certificate"
    echo "  Name: $SIGN_IDENTITY | Type: Self Signed Root | Cert Type: Code Signing"
    exit 1
fi
rm -f /tmp/.signtest

echo "==> Building release binary..."
swift build -c release --package-path "$SRC_DIR"

echo "==> Copying to $BUNDLE_DIR..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
cp "$SRC_DIR/.build/release/$APP_NAME" "$BUNDLE_DIR/Contents/MacOS/$APP_NAME"
cp "$SRC_DIR/Info.plist" "$BUNDLE_DIR/Contents/Info.plist"

echo "==> Signing app bundle..."
codesign -fs "$SIGN_IDENTITY" "$BUNDLE_DIR"

echo "==> Installing LaunchAgent..."
mkdir -p "$LAUNCH_AGENT_DIR"
cat > "$LAUNCH_AGENT_DIR/com.user.trackpad-volume.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.trackpad-volume</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BUNDLE_DIR/Contents/MacOS/$APP_NAME</string>
    </array>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/trackpad-volume.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/trackpad-volume.log</string>
</dict>
</plist>
EOF
launchctl unload "$LAUNCH_AGENT_DIR/com.user.trackpad-volume.plist" 2>/dev/null || true
launchctl load "$LAUNCH_AGENT_DIR/com.user.trackpad-volume.plist" 2>&1

echo "==> Done. Binary at: $BUNDLE_DIR/Contents/MacOS/$APP_NAME"
echo ""
echo "To stop: launchctl unload $LAUNCH_AGENT_DIR/com.user.trackpad-volume.plist"
