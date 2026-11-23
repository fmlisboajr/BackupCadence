#!/bin/bash
# Builds build/BackupCadence.app (ad hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="0.1.0"
APP="build/BackupCadence.app"

swift build -c release
BIN="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/BackupCadence" "$BIN/backupcadence-agent" "$APP/Contents/MacOS/"

# Localizations (strings keys are the English UI text).
for dir in Resources/*.lproj; do
  [ -d "$dir" ] && cp -R "$dir" "$APP/Contents/Resources/"
done
mkdir -p "$APP/Contents/Resources/en.lproj"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.backupcadence.app</string>
  <key>CFBundleName</key><string>BackupCadence</string>
  <key>CFBundleDisplayName</key><string>BackupCadence</string>
  <key>CFBundleExecutable</key><string>BackupCadence</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>pt</string></array>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep -s - "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"
