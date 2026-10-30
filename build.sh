#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP='build/Codex Pulse.app'
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp server.py index.html "$APP/Contents/Resources/"
swiftc Float.swift -o "$APP/Contents/MacOS/CodexPulse" -framework Cocoa
codesign --force --sign - "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" 'build/Codex Pulse.zip'
echo '构建完成：build/Codex Pulse.app'
