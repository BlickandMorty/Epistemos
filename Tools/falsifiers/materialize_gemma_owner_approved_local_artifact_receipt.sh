#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source Tools/falsifiers/gemma_first_runtime_paths.sh
gemma_configure_first_runtime_paths

cargo run \
  --manifest-path agent_core/Cargo.toml \
  --bin materialize_gemma_owner_approved_local_artifact_receipt
