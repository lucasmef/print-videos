#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build/module-cache
stage=$(mktemp -d /private/tmp/lookprint-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
app="$stage/LookPrint.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
swiftc -module-cache-path build/module-cache -O -target arm64-apple-macosx14.0 Sources/Engine.swift Sources/App.swift -o "$app/Contents/MacOS/LookPrint" 2>build/app-build.log
cp -X Info.plist "$app/Contents/Info.plist"
if [[ -f AppIcon.icns ]]; then cp -X AppIcon.icns "$app/Contents/Resources/"; fi
codesign --force --deep --sign - "$app"
ditto --norsrc "$app" 'build/LookPrint.app'
codesign --verify --deep 'build/LookPrint.app'
echo 'LookPrint compilado.'
