#!/bin/zsh
# Full clean rebuild for MacinCloud / Intel Simulator after Ads SDK changes.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

git pull origin master

echo "Clearing DerivedData + SPM caches…"
rm -rf "$HOME/Library/Developer/Xcode/DerivedData/Afterna-"*
rm -rf "$HOME/Library/Caches/org.swift.swiftpm"
rm -rf "$ROOT/ios/Afterna.xcodeproj"
rm -rf "$ROOT/ios/.swiftpm"
rm -rf "$ROOT/ios/Afterna.xcworkspace"

cd "$ROOT/ios"
~/bin/xcodegen generate
open Afterna.xcodeproj

echo "In Xcode: File → Packages → Reset Package Caches, then Resolve Package Versions,"
echo "then Product → Clean Build Folder, then Run."
echo "Confirm GoogleMobileAds resolves to 11.13.0 (not 12.x)."
