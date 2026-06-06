#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

cargo run --manifest-path agent_core/Cargo.toml \
  --bin falsify_compressed_route_answer_packet_dry_run

cargo run --manifest-path agent_core/Cargo.toml \
  --bin falsifier_validator \
  artifacts/falsifiers/compressed_route_answer_packet_dry_run/result.json
