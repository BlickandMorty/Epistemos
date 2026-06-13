#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
source Tools/falsifiers/gemma_first_runtime_paths.sh
gemma_configure_first_runtime_paths

cargo run --manifest-path agent_core/Cargo.toml \
  --bin materialize_gemma_first_runtime_system_g_dry_run_route_packet --quiet
