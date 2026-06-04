#!/usr/bin/env zsh
set -euo pipefail
export LC_ALL=C
cargo run --manifest-path agent_core/Cargo.toml --bin falsify_route_distillation_tournament
cargo run --manifest-path agent_core/Cargo.toml --bin falsifier_validator artifacts/falsifiers/route_distillation_tournament/result.json
