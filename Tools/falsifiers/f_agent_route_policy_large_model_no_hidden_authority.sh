#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
cargo run --manifest-path agent_core/Cargo.toml --bin falsify_agent_route_policy_large_model_no_hidden_authority
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator -- artifacts/falsifiers/agent_route_policy_large_model_no_hidden_authority/result.json
