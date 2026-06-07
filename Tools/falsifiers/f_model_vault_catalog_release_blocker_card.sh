#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
cargo run --manifest-path agent_core/Cargo.toml --bin falsify_model_vault_catalog_release_blocker_card
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- artifacts/falsifiers/model_vault_catalog_release_blocker_card/result.json
