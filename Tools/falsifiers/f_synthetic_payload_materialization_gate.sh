#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
cargo run --manifest-path agent_core/Cargo.toml --bin falsify_synthetic_payload_materialization_gate
