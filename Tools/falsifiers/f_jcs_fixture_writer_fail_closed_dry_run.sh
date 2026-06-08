#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
cargo run --manifest-path agent_core/Cargo.toml --bin falsify_jcs_fixture_writer_fail_closed_dry_run
