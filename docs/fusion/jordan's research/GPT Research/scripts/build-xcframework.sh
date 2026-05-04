#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo not found. Install Rust 1.80+ before building helios-ffi." >&2
  exit 1
fi

cargo build -p helios-ffi --release
mkdir -p build/xcframework
cat > build/xcframework/README.txt <<'EOF'
XCFramework packaging scaffold.
On macOS, replace this placeholder with cargo-xcode or cbindgen + xcodebuild -create-xcframework.
EOF
