#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

TOOLCHAIN="${RUSTUP_TOOLCHAIN:-stable-aarch64-apple-darwin}"

cargo +"$TOOLCHAIN" run --manifest-path agent_core/Cargo.toml --bin kv_direct_prompt_suite -- "$@"
