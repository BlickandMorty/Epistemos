---
name: experimental-substrate-verification
description: >
  Verify the embedded agent's OUTPUT against the Epistemos substrate — does a cited note
  actually exist in the vault? is a claim supported? did a tool call obey policy? Distinct
  from retrieval (pulling context IN) and write-back (pushing results OUT): this checks that
  what the agent PRODUCED is grounded in truth. Use for vault.cite-check, vault.claim-status
  (resonance/ClaimLedger), tool.validate (grammar/schema gate), or any "is this real?" chip.
  Composes experimental-vault-context-assembly (the RRF lookup) + experimental-provenance-writeback
  (the epistemos channel). Class: agent output → extract assertions → verify vs substrate → honest verdict.
---

# Experimental: substrate-verification of agent output

## Why (the moat, third axis)
Retrieval grounds the agent's INPUT; write-back persists its OUTPUT; verification proves the
output is TRUE against the user's knowledge. No standalone agent can check its citations
against a personal KB because it has none. This is the trust axis the field study's "hardening
& trust" column calls out.

## The pattern
1. **Extract the assertions from the agent's output** (renderer, pure function): `[[wiki]]`
   citations, factual claims, tool calls. Keep it deterministic + unit-testable
   (`extractCitations` is a regex over `[[…]]`, dedup + normalize).
2. **Verify each against the substrate** — reuse the EXISTING native reach, don't add core code:
   - citation exists? → `rankedVaultSearch(title)` (Cycle-2) + a normalized title match.
   - claim status? → the ClaimLedger read FFIs (`bridge.rs:3470-3531`) via a native handler.
   - tool obeyed policy? → the grammar/preflight gate.
   Best-effort per item; a lookup failure marks it **unverified**, NEVER a fake pass.
3. **Honest verdict UI** — a per-item chip / a summary toast ("N/M verified · not found: [[X]]").
   Gate the control on the native host AND on the output actually containing assertions (don't
   show a cite-check button on a reply with no citations).

## Reuse targets (later cycles compose THIS)
- `vault.claim-status`: swap the existence check for a ClaimLedger resonance read → "this answer
  cites a note you since EDITED — re-verify" (the AtRisk propagation).
- `run.export-bundle` verification: after ReplayBundle export, verify the `.epbundle` with the
  shipped `epistemos-trace` CLI over the epistemos channel.
- The ACS-anchored VRM chip (Verified/Plausible/Speculative) is this class applied to the whole
  AnswerPacket, not just citations.

## Verification (DoD)
Pure-web verification classes need NO app build — use the fast tarball path (bun run build →
build-experimental-web.sh → cp tarball into the app bundle → relaunch; see the loop memory).
Prove live: a reply that cites a REAL note → "verified"; a reply citing a fabricated `[[note]]`
→ "not found in vault" (the honest-negative is the proof it isn't faking). Every fork edit → a
`PATCH_LEDGER.md` row.

## Proven (Cycle 5)
`CiteCheckButton` on assistant replies: extracts `[[citations]]`, verifies each via the RRF
index, reports "N/M verified · not found: [[X]]". Never passes a citation without a real match.

## Reuse (Cycle 33/VRM)
- **Ambient trust chip:** surface the verdict as a per-reply Verified/Plausible/Speculative chip — but bound the cost (auto-run ONCE per item, cached; only on the freshly-completed item; render nothing when N/A). The discipline: an ambient verifier must never fan out backend calls across a scrolled history.
