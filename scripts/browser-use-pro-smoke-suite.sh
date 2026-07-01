#!/usr/bin/env bash
set -euo pipefail

# Plan 3 browser-use Pro smoke suite.
# Composes the signed gate smoke and loopback server smoke without xcodebuild.

usage() {
  cat <<'USAGE'
Usage: browser-use-pro-smoke-suite.sh [--repo-root PATH] [--artifact-dir PATH] [--timeout SECONDS] [--port PORT]
                                      [--signed-bundle PATH | --payload-root PATH] [--skip-gate] [--skip-loopback]

Runs the bounded browser-use Pro smoke suite:
  1. signed BrowserUsePro.bundle gate smoke (requires --signed-bundle unless --skip-gate)
  2. staged/signed loopback Web UI server smoke (unless --skip-loopback)

This script intentionally does not run xcodebuild or the full test suite.
USAGE
}

repo_root=""
artifact_dir=""
timeout_seconds=90
port=""
signed_bundle=""
payload_root=""
skip_gate=0
skip_loopback=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="${2:?missing --repo-root value}"
      shift 2
      ;;
    --artifact-dir)
      artifact_dir="${2:?missing --artifact-dir value}"
      shift 2
      ;;
    --timeout)
      timeout_seconds="${2:?missing --timeout value}"
      shift 2
      ;;
    --port)
      port="${2:?missing --port value}"
      shift 2
      ;;
    --signed-bundle)
      signed_bundle="${2:?missing --signed-bundle value}"
      shift 2
      ;;
    --payload-root)
      payload_root="${2:?missing --payload-root value}"
      shift 2
      ;;
    --skip-gate)
      skip_gate=1
      shift
      ;;
    --skip-loopback)
      skip_loopback=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$repo_root" ]]; then
  repo_root="$(cd -- "$script_dir/.." && pwd)"
else
  repo_root="$(cd -- "$repo_root" && pwd)"
fi

if [[ -n "$signed_bundle" && -n "$payload_root" ]]; then
  echo "Use either --signed-bundle or --payload-root, not both" >&2
  exit 64
fi

if [[ "$skip_gate" -eq 0 && -z "$signed_bundle" ]]; then
  echo "--signed-bundle is required for the gate smoke; pass --skip-gate to run loopback-only." >&2
  exit 64
fi

if [[ "$skip_gate" -eq 1 && "$skip_loopback" -eq 1 ]]; then
  echo "At least one smoke must run." >&2
  exit 64
fi

if [[ -n "$signed_bundle" ]]; then
  signed_bundle="$(cd -- "$signed_bundle" && pwd)"
fi
if [[ -n "$payload_root" ]]; then
  payload_root="$(cd -- "$payload_root" && pwd)"
fi

if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || (( timeout_seconds < 5 || timeout_seconds > 600 )); then
  echo "Timeout must be an integer from 5 through 600 seconds; got $timeout_seconds" >&2
  exit 64
fi
if [[ -n "$port" ]] && { ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1024 || port > 65535 )); }; then
  echo "Port must be an integer from 1024 through 65535; got $port" >&2
  exit 64
fi

if [[ -z "$artifact_dir" ]]; then
  artifact_dir="$(mktemp -d "${TMPDIR:-/tmp}/epistemos-browser-use-pro-suite.XXXXXX")"
else
  if [[ -L "$artifact_dir" ]]; then
    echo "Artifact directory must not be a symlink: $artifact_dir" >&2
    exit 66
  fi
  mkdir -p "$artifact_dir"
  if [[ -L "$artifact_dir" ]]; then
    echo "Artifact directory must not be a symlink: $artifact_dir" >&2
    exit 66
  fi
  artifact_dir="$(cd -P -- "$artifact_dir" && pwd)"
fi

echo "browser-use Pro smoke suite artifacts: $artifact_dir"

if [[ "$skip_gate" -eq 0 ]]; then
  gate_bin="$artifact_dir/browser-use-pro-gate-smoke"
  swiftc \
    "$repo_root/scripts/browser-use-pro-gate-smoke-stubs.swift" \
    "$repo_root/Epistemos/Engine/FeatureGateOverride.swift" \
    "$repo_root/Epistemos/BrowserUsePro/BrowserUseManifestError.swift" \
    "$repo_root/Epistemos/BrowserUsePro/BrowserUseSymlinkPathGuard.swift" \
    "$repo_root/Epistemos/BrowserUsePro/BrowserUseProGateStatus.swift" \
    "$repo_root/Epistemos/BrowserUsePro/BrowserUseSignedBundleStatus.swift" \
    "$repo_root/scripts/browser-use-pro-gate-smoke.swift" \
    -framework Security \
    -o "$gate_bin"
  "$gate_bin" "$signed_bundle"
fi

if [[ "$skip_loopback" -eq 0 ]]; then
  loopback_args=(
    --repo-root "$repo_root"
    --artifact-dir "$artifact_dir/loopback"
    --timeout "$timeout_seconds"
  )
  if [[ -n "$port" ]]; then
    loopback_args+=(--port "$port")
  fi
  if [[ -n "$signed_bundle" ]]; then
    loopback_args+=(--signed-bundle "$signed_bundle")
  elif [[ -n "$payload_root" ]]; then
    loopback_args+=(--payload-root "$payload_root")
  fi
  "$repo_root/scripts/browser-use-pro-loopback-smoke.sh" "${loopback_args[@]}"
fi

echo "browser-use Pro smoke suite OK"
