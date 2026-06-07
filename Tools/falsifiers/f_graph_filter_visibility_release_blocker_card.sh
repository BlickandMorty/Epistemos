#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
cargo run --manifest-path agent_core/Cargo.toml --bin falsify_graph_filter_visibility_release_blocker_card
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- artifacts/falsifiers/graph_filter_visibility_release_blocker_card/result.json
