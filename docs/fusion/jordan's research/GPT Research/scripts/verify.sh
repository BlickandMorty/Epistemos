#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
python3 tools/verify_hotpath.py
if command -v cargo >/dev/null 2>&1; then
  cargo test --workspace
else
  echo "cargo not available; Rust compile gate skipped by this container."
fi
