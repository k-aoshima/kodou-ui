#!/bin/bash
# KodouUI を swiftc で静的ライブラリにする（Xcode なし、Command Line Tools だけで動く）。
# Package.swift もあるが、Command Line Tools の SwiftPM はマニフェストのリンクで失敗する環境があるため、こちらを正とする。
#   swift/build.sh            → swift/build/libKodouUI.a と KodouUI.swiftmodule
set -euo pipefail
cd "$(dirname "$0")"
OVERLAY=$PWD/clt-overlay.yaml   # Command Line Tools に残った古い modulemap を空に見せる
FLAGS=(-parse-as-library -O -swift-version 5 -target arm64-apple-macosx14.0 -vfsoverlay "$OVERLAY" -Xcc -ivfsoverlay -Xcc "$OVERLAY")
mkdir -p build
swiftc "${FLAGS[@]}" -wmo -module-name KodouUI -emit-module -emit-module-path build/KodouUI.swiftmodule \
  -emit-library -static -o build/libKodouUI.a Sources/KodouUI/*.swift
echo "built swift/build/libKodouUI.a"
