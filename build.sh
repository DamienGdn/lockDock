#!/bin/bash
# Construit build/DockLock.app (signature ad hoc) et build/DockLock.zip
set -euo pipefail
cd "$(dirname "$0")"
APP=build/DockLock.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O DockLock.swift -o "$APP/Contents/MacOS/DockLock"
cp Info.plist "$APP/Contents/Info.plist"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
swift scripts/make-icon.swift build/icon.iconset
iconutil -c icns build/icon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
xattr -cr "$APP"
codesign --force --sign - "$APP"
(cd build && ditto -c -k --keepParent DockLock.app DockLock.zip)
echo "OK : $APP et build/DockLock.zip"
