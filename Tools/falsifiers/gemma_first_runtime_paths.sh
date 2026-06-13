#!/usr/bin/env bash
set -euo pipefail

gemma_proof_lane() {
  local lane="${EPI_GEMMA_PROOF_LANE:-}"
  if [[ -z "$lane" ]]; then
    local identity="${EPI_GEMMA_SELECTED_MODEL_ID:-}${EPI_GEMMA_LOCAL_MODEL_PATH:-}${EPI_GEMMA_LOCAL_ARTIFACT_RECEIPT:-}${EPI_GEMMA_RUNTIME_PROBE_RECEIPT:-}${EPI_GEMMA_QUALITY_PACKET:-}${EPI_GEMMA_QUALITY_REPLAY_ARTIFACT:-}${EPI_GEMMA_RUNTIME_ROUTER_ADMISSION_PACKET:-}${EPI_GEMMA_SYSTEM_G_DRY_RUN_ROUTE_PACKET:-}${EPI_GEMMA_ROUTE_ANSWER_PACKET_VISIBILITY_PACKET:-}"
    if [[ "$identity" == *"12B"* || "$identity" == *"12b"* ]]; then
      lane="12b"
    elif [[ "$identity" == *"E4B"* || "$identity" == *"e4b"* ]]; then
      lane="e4b"
    else
      lane="e2b"
    fi
  fi

  case "$lane" in
    e2b|e4b|12b) printf '%s\n' "$lane" ;;
    *) echo "unsupported EPI_GEMMA_PROOF_LANE: $lane" >&2; return 2 ;;
  esac
}

gemma_lane_prefix() {
  local lane="$1"
  if [[ "$lane" == "e2b" ]]; then
    printf '%s\n' ""
  else
    printf '%s\n' "$lane/"
  fi
}

gemma_export_default() {
  local key="$1"
  local value="$2"
  if [[ -z "${!key:-}" ]]; then
    export "$key=$value"
  fi
}

gemma_configure_first_runtime_paths() {
  local lane
  lane="$(gemma_proof_lane)"
  export EPI_GEMMA_PROOF_LANE="$lane"

  local prefix
  prefix="$(gemma_lane_prefix "$lane")"

  gemma_export_default \
    EPI_GEMMA_RECEIPT_OUTPUT \
    "artifacts/falsifiers/gemma_owner_approved_local_artifact_receipt_materializer/${prefix}receipt.redacted.json"
  gemma_export_default \
    EPI_GEMMA_LOCAL_ARTIFACT_RECEIPT \
    "artifacts/falsifiers/gemma_owner_approved_local_artifact_receipt_materializer/${prefix}receipt.redacted.json"

  gemma_export_default \
    EPI_GEMMA_RUNTIME_PROBE_OUTPUT \
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_execution_probe/${prefix}receipt.redacted.json"
  gemma_export_default \
    EPI_GEMMA_RUNTIME_PROBE_RECEIPT \
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_execution_probe/${prefix}receipt.redacted.json"

  gemma_export_default \
    EPI_GEMMA_QUALITY_PACKET_OUTPUT \
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_quality_packet/${prefix}packet.redacted.json"
  gemma_export_default \
    EPI_GEMMA_QUALITY_PACKET \
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_quality_packet/${prefix}packet.redacted.json"

  gemma_export_default \
    EPI_GEMMA_QUALITY_REPLAY_OUTPUT \
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_quality_replay/${prefix}result.redacted.json"
  gemma_export_default \
    EPI_GEMMA_QUALITY_REPLAY_ARTIFACT \
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_quality_replay/${prefix}result.redacted.json"

  gemma_export_default \
    EPI_GEMMA_RUNTIME_ROUTER_ADMISSION_OUTPUT \
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_runtime_router_admission/${prefix}admission.redacted.json"
  gemma_export_default \
    EPI_GEMMA_RUNTIME_ROUTER_ADMISSION_PACKET \
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_runtime_router_admission/${prefix}admission.redacted.json"

  gemma_export_default \
    EPI_GEMMA_SYSTEM_G_DRY_RUN_ROUTE_OUTPUT \
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_system_g_dry_run_route/${prefix}system_g_dry_run.redacted.json"
  gemma_export_default \
    EPI_GEMMA_SYSTEM_G_DRY_RUN_ROUTE_PACKET \
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_system_g_dry_run_route/${prefix}system_g_dry_run.redacted.json"

  gemma_export_default \
    EPI_GEMMA_ROUTE_ANSWER_PACKET_VISIBILITY_OUTPUT \
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_route_answer_packet_visibility/${prefix}visibility.redacted.json"
  gemma_export_default \
    EPI_GEMMA_ROUTE_ANSWER_PACKET_VISIBILITY_PACKET \
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_route_answer_packet_visibility/${prefix}visibility.redacted.json"

  gemma_export_default \
    EPI_GEMMA_SETTINGS_DIAGNOSTICS_WRV_OUTPUT \
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_settings_diagnostics_wrv/${prefix}wrv.redacted.json"
}
