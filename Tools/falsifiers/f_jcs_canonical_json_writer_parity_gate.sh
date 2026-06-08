#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
cargo run --manifest-path agent_core/Cargo.toml --bin falsify_jcs_canonical_json_writer_parity_gate
