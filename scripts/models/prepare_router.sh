#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

MODEL_KEY="${MODEL_KEY:-router_primary}"
ROLE="$(model_get "${MODEL_KEY}" role)"
[[ "${ROLE}" == "router" ]] || die "Model ${MODEL_KEY} is not a router entry"

prepare_peft_causal_lm_artifact "${MODEL_KEY}"
