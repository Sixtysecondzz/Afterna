#!/bin/zsh
# Full clean rebuild after Google Mobile Ads / XcodeGen changes.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
git pull origin master

echo "Clearing DerivedData + SPM caches…"
rm -rf "$HOME/Library/Developer/Xcode/DerivedData/Afterna-"*
rm -rf "$HOME/Library/Caches/org.swift.swiftpm"
rm -rf "$ROOT/ios/Afterna.xcodeproj"
rm -rf "$ROOT/ios/.swiftpm"

cd "$ROOT/ios"
~/bin/xcodegen generate
open Afterna.xcodeproj

cat <<'EOF'
In Xcode:
  1) File → Packages → Reset Package Caches
  2) File → Packages → Resolve Package Versions
  3) Product → Clean Build Folder
  4) Run

If you see arm64 vs x86_64 linker errors on Intel MacinCloud, run on a physical iPhone
(GMA 12 Simulator slices are arm64-only).
EOF
