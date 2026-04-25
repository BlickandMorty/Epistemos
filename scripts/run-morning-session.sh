#!/usr/bin/env bash
# scripts/run-morning-session.sh
#
# Wave 2.6 of the Extended Program Plan
# (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md`,
#  cross-ref dpp §1.1 Task 0.6).
#
# Builds the bench/morning-session crate and runs the binary, which
# writes runtime measurements to build/perf-budgets-runtime.json for
# scripts/check-perf-budgets.sh (Wave 2.5 gate) to consume.
#
# Designed to run on the macos-15 GitHub Actions runner with no extra
# dependencies. Idempotent — repeated runs replace the JSON file.
#
# Usage: ./scripts/run-morning-session.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH_DIR="${REPO_ROOT}/bench"

if [[ ! -d "${BENCH_DIR}" ]]; then
    echo "::error::bench/ directory not found at ${BENCH_DIR}" >&2
    exit 1
fi

echo "==> building bench/morning-session (release, target aarch64-apple-darwin)"
cd "${BENCH_DIR}"
cargo build --release --target aarch64-apple-darwin --bin morning-session

# The bench writes into <repo-root>/build/perf-budgets-runtime.json itself
# (it resolves the path via CARGO_MANIFEST_DIR — see bench/src/morning_session.rs).
echo "==> running morning-session"
"${BENCH_DIR}/target/aarch64-apple-darwin/release/morning-session"

OUT="${REPO_ROOT}/build/perf-budgets-runtime.json"
if [[ ! -f "${OUT}" ]]; then
    echo "::error::morning-session reported success but ${OUT} is missing" >&2
    exit 1
fi
echo "==> morning-session wrote $(wc -c <"${OUT}" | tr -d ' ') bytes to ${OUT}"
