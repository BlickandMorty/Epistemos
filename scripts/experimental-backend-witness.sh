#!/usr/bin/env bash
# EPISTEMOS Experimental — backend regression witness.
#
# Re-runnable, deterministic proof that the Experimental fork's backend surface (the tRPC
# endpoints the web overlays depend on) still behaves correctly after any change. Boots the
# headless backend against a throwaway FIXTURE vault (never the user's real vault) and asserts
# the load-bearing behaviors across all cycles. Exits non-zero on the first failure.
#
# Usage:  bash scripts/experimental-backend-witness.sh
# Covers: vault noteExists (exact-match, incl. the H1 false-verify guard), whole-vault search,
#         graph outlinks + backlinks. (Prompt Forge enhance is a live LLM call — gated behind
#         WITNESS_FORGE=1 + EPISTEMOS_CLAUDE_BINARY so the default run stays offline+free.)
set -euo pipefail

FORK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.research-clones/1code"
PORT="${WITNESS_PORT:-49911}"
TMP="$(mktemp -d)"
FX="$TMP/vault/notes"
mkdir -p "$FX"
UD="$TMP/userdata"

cleanup() { [ -n "${BPID:-}" ] && kill "$BPID" 2>/dev/null || true; rm -rf "$TMP"; }
trap cleanup EXIT

# --- Fixture vault: real notes, an outlink chain, and a backlink -----------------------------
printf '# Alpha Project\n\nDepends on [[Beta Module]] and [[Gamma Service]].\n' > "$FX/Alpha Project.md"
printf '# Beta Module\n\nCore beta logic.\n'                                     > "$FX/Beta Module.md"
printf '# Gamma Service\n\nHandles distributed networking and retries.\n'        > "$FX/Gamma Service.md"
printf '# Omega Plan\n\nRollout schedule. See [[Gamma Service]].\n'              > "$FX/Omega Plan.md"
# Two provenance notes sharing a tool workflow (for the Skills-discovery gate); one one-off.
printf '# Provenance\n\n## Tool-call sequence\n1. **search_notes** — a\n2. **read_file** — b\n' > "$FX/Provenance--run-1.md"
printf '# Provenance\n\n## Tool-call sequence\n1. **search_notes** — c\n2. **read_file** — d\n3. **Bash** — e\n' > "$FX/Provenance--run-2.md"
printf '# Provenance\n\n## Tool-call sequence\n1. **WebFetch** — h\n2. **Write** — i\n' > "$FX/Provenance--run-3.md"
# Numbered/ordinal-prefixed note (common in organized vaults) — cite-check must verify it by TITLE.
printf '# Rollout Schedule\n\nThe rollout schedule.\n' > "$FX/05_ROLLOUT_SCHEDULE.md"

echo "[witness] booting headless backend on :$PORT against fixture vault…"
( cd "$FORK" && EPISTEMOS_VAULT_ROOT="$TMP/vault" EPISTEMOS_ONECODE_PORT="$PORT" \
    EPISTEMOS_ONECODE_USER_DATA="$UD" node headless/dist/index.cjs ) >"$TMP/backend.log" 2>&1 &
BPID=$!

# Wait for health.
for _ in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:$PORT/healthz" >/dev/null 2>&1; then break; fi
  sleep 0.5
done

FAIL=0
q() { python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$1"; }
call() { curl -fsS "http://127.0.0.1:$PORT/trpc/$1?input=$(q "$2")"; }
jget() { python3 -c "import json,sys;d=json.load(sys.stdin);print(json.dumps(d.get('result',{}).get('data',{}).get('json')))"; }

check() { # name  expected-substring  actual-json
  if printf '%s' "$3" | grep -q "$2"; then
    echo "  PASS  $1"
  else
    echo "  FAIL  $1  (expected '$2' in: $3)"; FAIL=1
  fi
}

echo "[witness] asserting vault endpoints…"
check "noteExists: real note verifies" \
  '"exists": true' "$(call epistemosVault.noteExists '{"json":{"title":"Gamma Service"}}' | jget)"
# H1 GUARD: a hallucinated superset of a real title must NOT verify (no substring false-positive).
check "noteExists: H1 superset is rejected" \
  '"exists": false' "$(call epistemosVault.noteExists '{"json":{"title":"Gamma Service Enterprise Edition 2027"}}' | jget)"
check "noteExists: numbered note verifies by TITLE (05_ROLLOUT_SCHEDULE → [[Rollout Schedule]])" \
  '"exists": true' "$(call epistemosVault.noteExists '{"json":{"title":"Rollout Schedule"}}' | jget)"
check "noteExists: partial of a numbered note still rejected (no substring verify)" \
  '"exists": false' "$(call epistemosVault.noteExists '{"json":{"title":"Rollout"}}' | jget)"
check "noteExists: fabricated note is rejected" \
  '"exists": false' "$(call epistemosVault.noteExists '{"json":{"title":"TOTALLY_FAKE_ZZZ"}}' | jget)"
check "search: whole-vault content hit" \
  'Gamma Service' "$(call epistemosVault.search '{"json":{"query":"networking","limit":8}}' | jget)"
check "search: RELEVANCE-ranked (title match ranks first)" \
  '"title": "Gamma Service"' "$(call epistemosVault.search '{"json":{"query":"gamma","limit":8}}' | jget)"
check "search: NATURAL-LANGUAGE query grounds via term overlap (not full-phrase)" \
  '"title": "Alpha Project"' "$(call epistemosVault.search '{"json":{"query":"help me understand the alpha project design","limit":8}}' | jget)"
check "cite-repair: hallucinated citation → nearest real note (did-you-mean)" \
  '"title": "Gamma Service"' "$(call epistemosVault.nearest '{"json":{"title":"Gamma Servicing Plan"}}' | jget)"
check "cite-repair: unrelated citation → NO false suggestion" \
  '"suggestion": null' "$(call epistemosVault.nearest '{"json":{"title":"Quantum Teleportation Xyz"}}' | jget)"
# Edge/degenerate-input robustness (verified: no crash, empty result — the fresh-user/empty paths).
check "edge: no-match search returns empty (no crash)" \
  '"hits": \[\]' "$(call epistemosVault.search '{"json":{"query":"zzznomatchzzz","limit":5,"graph":true}}' | jget)"
check "edge: sub-4-char-token title → no suggestion (token filter)" \
  '"suggestion": null' "$(call epistemosVault.nearest '{"json":{"title":"a b c"}}' | jget)"
check "graph: outlink neighbor surfaced" \
  'linked from Alpha Project' "$(call epistemosVault.search '{"json":{"query":"alpha","limit":8,"graph":true}}' | jget)"
check "graph: backlink surfaced (references, no query-term match)" \
  'references Gamma Service' "$(call epistemosVault.search '{"json":{"query":"networking","limit":8,"graph":true}}' | jget)"
check "skills: recurring workflow discovered (search_notes → read_file, freq 2)" \
  'read_file' "$(call epistemosSkills.discover '{"json":{"minRuns":2}}' | jget)"
check "skills: one-off workflow WITHHELD (no WebFetch/Write in discovered)" \
  '"runsScanned": 3' "$(call epistemosSkills.discover '{"json":{"minRuns":2}}' | jget)"

# Optional: Prompt Forge enhance (real LLM call). Only when explicitly opted in.
if [ "${WITNESS_FORGE:-0}" = "1" ] && [ -n "${EPISTEMOS_CLAUDE_BINARY:-}" ]; then
  echo "[witness] asserting Prompt Forge enhance (live small-model call)…"
  RES="$(curl -fsS -X POST "http://127.0.0.1:$PORT/trpc/epistemosPromptForge.enhance" \
      -H 'Content-Type: application/json' \
      -d '{"json":{"original":"make the login better"}}' | jget)"
  # A real upgrade is longer than the original and differs from it.
  if printf '%s' "$RES" | python3 -c "import json,sys;d=json.load(sys.stdin);u=d.get('upgraded','');print('OK' if u and u.strip()!='make the login better' else 'NO')" | grep -q OK; then
    echo "  PASS  promptForge: upgraded the prompt"
  else
    echo "  FAIL  promptForge: returned original (SDK/binary path?)  $RES"; FAIL=1
  fi

  echo "[witness] asserting System Prompt Forge upgrade (live small-model call)…"
  SRES="$(curl -fsS -X POST "http://127.0.0.1:$PORT/trpc/epistemosSystemPromptForge.upgrade" \
      -H 'Content-Type: application/json' \
      -d '{"json":{"original":"You are a helpful coding assistant. Answer questions and write code."}}' | jget)"
  if printf '%s' "$SRES" | python3 -c "import json,sys;d=json.load(sys.stdin);u=d.get('upgraded','');print('OK' if u and len(u)>120 and u.strip()!='You are a helpful coding assistant. Answer questions and write code.' else 'NO')" | grep -q OK; then
    echo "  PASS  systemPromptForge: upgraded into the layered architecture"
  else
    echo "  FAIL  systemPromptForge: returned original / too short  $SRES"; FAIL=1
  fi
fi

echo ""
if [ "$FAIL" = "0" ]; then echo "[witness] ALL CHECKS PASSED ✓"; else echo "[witness] FAILURES ABOVE ✗"; fi
exit "$FAIL"
