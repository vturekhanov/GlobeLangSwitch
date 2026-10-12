#!/bin/sh
# Builds build/GlobeLangSwitch.app using only Xcode Command Line Tools. Never launches the app.
# Signs ad hoc by default; with SIGN_IDENTITY="Developer ID Application: …" signs with that
# certificate, the hardened runtime and a secure timestamp (contacts Apple's timestamp server).
set -eu
cd "$(dirname "$0")"

APP=build/GlobeLangSwitch.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/tmp
export TMPDIR="$PWD/build/tmp"  # keep compiler temporary files inside the project

plutil -lint -s Info.plist GlobeLangSwitch.entitlements Resources/*.lproj/*.strings
cp Info.plist "$APP/Contents/"
cp -R Resources/ "$APP/Contents/Resources/"

xcrun swiftc -swift-version 6 -parse-as-library -warnings-as-errors -O \
    -target arm64-apple-macos13.0 -module-cache-path build/ModuleCache \
    -Xlinker -no_adhoc_codesign \
    Sources/*.swift -o "$APP/Contents/MacOS/GlobeLangSwitch"

# App Sandbox with one exception: TISSelectInputSource called from a background app must reach the
# focused app's com.apple.tsm.portname; when it can't, the focused app restores its own layout.
if [ -n "${SIGN_IDENTITY:-}" ]; then
    codesign --sign "$SIGN_IDENTITY" --options runtime --timestamp \
        --entitlements GlobeLangSwitch.entitlements "$APP"
else
    codesign --sign - --entitlements GlobeLangSwitch.entitlements "$APP"
fi
codesign --verify --strict "$APP"
echo "Built $APP"
