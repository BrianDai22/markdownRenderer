#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> plutil"
plutil -lint MarkdownRenderer/Info.plist

echo "==> swift test"
swift test

echo "==> xcodebuild build"
xcodebuild -project MarkdownRenderer.xcodeproj -target MarkdownRenderer -configuration Debug build

echo "OK"

