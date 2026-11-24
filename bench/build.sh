#!/bin/bash
# 3 つの版を本番用に縮めて dist に出す
set -e; cd "$(dirname "$0")"; mkdir -p dist
npx esbuild src/kodou.js --bundle --minify --format=iife --outfile=dist/kodou.js --log-level=warning
npx esbuild src/react-app.jsx --bundle --minify --format=iife --jsx=automatic --define:process.env.NODE_ENV='"production"' --outfile=dist/react.js --log-level=warning
page() { printf '<!doctype html><meta charset="utf-8"><title>%s</title>%s<body><div id="root"></div>%s<script src="%s"></script>\n' "$1" "$2" "$3" "$4" > "dist/$1.html"; }
page kodou '<link rel="stylesheet" href="../src/style.css">' '' kodou.js
page react-plain '<style>body{margin:0}</style>' '<script>__TUNED=false</script>' react.js
page react-tuned '<style>body{margin:0}</style>' '<script>__TUNED=true</script>' react.js
ls -l dist/*.js | awk '{print $5, $9}'
