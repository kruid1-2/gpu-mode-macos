#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
PRODUCT_NAME="PowerMode"
HELPER_NAME="GPUModeHelper"
APP_DISPLAY_NAME="GPU Mode"
BUNDLE_ID="local.gpumode.control"
HELPER_BUNDLE_ID="local.gpumode.control.helper"
MIN_SYSTEM_VERSION="13.0"
APP_VERSION="1.1.0"
APP_BUILD="16"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/$APP_DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_LAUNCH_DAEMONS="$APP_CONTENTS/Library/LaunchDaemons"
APP_BINARY="$APP_MACOS/$PRODUCT_NAME"
HELPER_BINARY="$APP_LAUNCH_DAEMONS/$HELPER_NAME"
HELPER_PLIST="$APP_LAUNCH_DAEMONS/$HELPER_BUNDLE_ID.plist"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON_NAME="GPUMode"
APP_ICON_SOURCE="$ROOT_DIR/Sources/PowerMode/Resources/$APP_ICON_NAME.icns"

cd "$ROOT_DIR"

clean_app_metadata() {
  xattr -cr "$APP_BUNDLE" >/dev/null 2>&1 || true
}

stop_app() {
  pkill -x "$PRODUCT_NAME" >/dev/null 2>&1 || true
  for _ in {1..30}; do
    if ! pgrep -x "$PRODUCT_NAME" >/dev/null; then
      return
    fi
    sleep 0.1
  done
}

stop_app

if [[ ! -f "$APP_ICON_SOURCE" ]]; then
  python3 "$ROOT_DIR/script/generate_app_icon.py" "$APP_ICON_SOURCE"
fi

swift build --product "$PRODUCT_NAME"
swift build --product "$HELPER_NAME"
BUILD_DIR="$(swift build --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$PRODUCT_NAME"
BUILD_HELPER="$BUILD_DIR/$HELPER_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$APP_LAUNCH_DAEMONS"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$BUILD_HELPER" "$HELPER_BINARY"
cp "$APP_ICON_SOURCE" "$APP_RESOURCES/$APP_ICON_NAME.icns"
chmod +x "$APP_BINARY"
chmod +x "$HELPER_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$PRODUCT_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleIconFile</key>
  <string>$APP_ICON_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

cat >"$HELPER_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$HELPER_BUNDLE_ID</string>
  <key>BundleProgram</key>
  <string>Contents/Library/LaunchDaemons/$HELPER_NAME</string>
  <key>MachServices</key>
  <dict>
    <key>$HELPER_BUNDLE_ID</key>
    <true/>
  </dict>
  <key>AssociatedBundleIdentifiers</key>
  <array>
    <string>$BUNDLE_ID</string>
  </array>
</dict>
</plist>
PLIST

clean_app_metadata
/usr/bin/codesign --force --sign - --identifier "$HELPER_BUNDLE_ID" "$HELPER_BINARY"
clean_app_metadata
/usr/bin/codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$PRODUCT_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$PRODUCT_NAME" >/dev/null
    stop_app
    clean_app_metadata
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
