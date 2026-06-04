#!/usr/bin/env bash
set -euo pipefail

cargo run --manifest-path agent_core/Cargo.toml --bin falsify_construction_search_tournament
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- artifacts/falsifiers/construction_search_tournament/result.json
