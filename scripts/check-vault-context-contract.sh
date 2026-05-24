#!/usr/bin/env bash
set -euo pipefail

paths=(
  "Epistemos/App/ChatCoordinator.swift"
  "Epistemos/Views/Chat"
  "Epistemos/Views/Halo"
)

pattern='LIMIT[[:space:]]+[0-9?]|first[[:space:]][^[:cntrl:]]*notes'

if rg -n --glob '*.swift' "${pattern}" "${paths[@]}"; then
  echo "Vault context contract violation: chat retrieval surfaces must not build context from LIMIT N or first-N notes." >&2
  exit 1
fi

echo "Vault context contract OK: no LIMIT/first-notes context construction in chat retrieval surfaces."
