#!/bin/bash
# Swift のベンチを作る。Xcode なし、Command Line Tools の swiftc だけで動く
#   bench/swift/build.sh   → bench/swift/build/KodouBench.app
set -euo pipefail
cd "$(dirname "$0")"
../../swift/build.sh
OVERLAY=$PWD/../../swift/clt-overlay.yaml
LIB=../../swift/build
mkdir -p build
swiftc -parse-as-library -O -swift-version 5 -target arm64-apple-macosx14.0 -vfsoverlay "$OVERLAY" -Xcc -ivfsoverlay -Xcc "$OVERLAY" \
  -I "$LIB" -L "$LIB" -lKodouUI Sources/*.swift -o build/KodouBench
APP=build/KodouBench.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
cp build/KodouBench "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.kodou-ui.bench</string>
<key>CFBundleName</key><string>KodouBench</string>
<key>CFBundleExecutable</key><string>KodouBench</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PL
codesign --force --sign - "$APP" >/dev/null 2>&1
echo "built bench/swift/$APP"
