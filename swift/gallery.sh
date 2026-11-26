#!/bin/bash
# 部品を並べて見る窓を作って開く。swift/gallery.sh
set -euo pipefail
cd "$(dirname "$0")"
./build.sh >/dev/null
OVERLAY=$PWD/clt-overlay.yaml
swiftc -parse-as-library -O -swift-version 5 -target arm64-apple-macosx14.0 -vfsoverlay "$OVERLAY" -Xcc -ivfsoverlay -Xcc "$OVERLAY" \
  -I build -L build -lKodouUI Gallery/*.swift -o build/KodouGallery
echo "built swift/build/KodouGallery"
[ "${1:-}" = "--build-only" ] || exec build/KodouGallery
