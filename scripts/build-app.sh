#!/bin/bash
# Builds build/Ember.app from source: release binary, Info.plist, ad-hoc
# signature with the hardened runtime. Needs the Xcode Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")/.."

ARCH=$(uname -m)
swift build -c release --arch "$ARCH"
BIN="$(swift build -c release --arch "$ARCH" --show-bin-path)/Ember"

APP=build/Ember.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Ember"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Build number = commit count, so each install is distinguishable.
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo 1)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

# Ad-hoc ("-") signature: no Apple account needed, and a locally built app
# carries no quarantine flag, so Gatekeeper lets it run. No entitlements.
codesign --force --sign - --options runtime "$APP"
codesign --verify --strict "$APP"
echo "built $APP (build $BUILD_NUMBER, $ARCH)"
