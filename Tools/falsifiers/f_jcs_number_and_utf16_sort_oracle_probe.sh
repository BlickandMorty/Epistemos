#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
cargo run --manifest-path agent_core/Cargo.toml --bin falsify_jcs_number_and_utf16_sort_oracle_probe
