# MAS C Handoff Prompt Catalog

ID: `MAS-C-HANDOFF-PROMPT-CATALOG-2026-07-08`

This catalog is the quick prompt chooser for MAS C. Use it when starting a
local implementation agent, a cloud research agent, a packet audit agent, or a
feature-specific build agent.

## Prompt Selection

| Situation | Use this prompt | Required attachments or local reads |
|---|---|---|
| Start local implementation from zero | Q1 local implementation prompt | `MAS_C_FIRST_PASS_IMPLEMENTATION_QUEUE.md`, `MAS_C_LOCAL_SOURCE_ANCHORS.md`, Keelstone plan/build prompt |
| Redirect an in-flight local agent | Local redirect prompt | `prompts/05_MAS_C_LOCAL_BUILD_REDIRECT.md` plus affected feature docs |
| Send packet to cloud research | External research prompt | `MAS_C_EXTERNAL_RESEARCH_PROMPT.md` plus listed attachments |
| Audit contradictions after new research | Integration audit prompt | `prompts/02_MAS_C_INTEGRATION_AUDIT.md`, `MAS_C_RESEARCH_INTAKE_PROTOCOL.md` |
| Decide source/API legality | Legality prompt | `prompts/03_MAS_C_LEGALITY_MATRIX.md` |
| Decide storage direction | Storage/pruning prompt | `prompts/04_MAS_C_STORAGE_PRUNING_VERDICT.md`, `features/12-storage-fusion/*` |
| Begin any feature implementation | Feature prompt template below | `MAS_C_FEATURE_INDEX.md`, feature `PLAN.md`, feature `BUILD_PROMPT.md` |
| Verify packet after edits | Packet audit prompt below | full `docs/mas-c/` folder |

## Local Q1 Implementation Prompt

```text
You are implementing MAS C first pass Q1 for Epistemos.

Read before editing:
1. docs/mas-c/README.md
2. docs/mas-c/MAS_C_CONTROL.md
3. docs/mas-c/MAS_C_TERMINOLOGY_CANON.md
4. docs/mas-c/MAS_C_ANTI_DRIFT_GUARD.md
5. docs/mas-c/MAS_C_EVIDENCE_PROTOCOL.md
6. docs/mas-c/MAS_C_LOCAL_SOURCE_ANCHORS.md
7. docs/mas-c/MAS_C_FIRST_PASS_IMPLEMENTATION_QUEUE.md
8. docs/mas-c/features/01-keelstone/PLAN.md
9. docs/mas-c/features/01-keelstone/BUILD_PROMPT.md
10. docs/mas-c/MAS_C_RELEASE_EVIDENCE_GATE.md

Do not edit first. Map the current vault/release state from source: vault
writers, provenance stores, entitlements, privacy manifest, project target
membership, release scripts, App Store hardening tests, and archive scan
commands.

Leave an evidence pack using MAS_C_EVIDENCE_PROTOCOL.md, including files read,
findings, risks, verification debt, and the smallest safe implementation or
release-guard edit you recommend next. Do not claim implementation completion
from a mapping pass.
```

## Feature Implementation Prompt Template

```text
You are implementing MAS C feature <FEATURE ID>.

Read before editing:
1. docs/mas-c/README.md
2. docs/mas-c/MAS_C_CONTROL.md
3. docs/mas-c/MAS_C_TERMINOLOGY_CANON.md
4. docs/mas-c/MAS_C_ANTI_DRIFT_GUARD.md
5. docs/mas-c/MAS_C_EVIDENCE_PROTOCOL.md
6. docs/mas-c/MAS_C_LOCAL_SOURCE_ANCHORS.md
7. docs/mas-c/MAS_C_FEATURE_INDEX.md
8. docs/mas-c/features/<feature>/PLAN.md
9. docs/mas-c/features/<feature>/BUILD_PROMPT.md
10. docs/mas-c/MAS_C_RELEASE_EVIDENCE_GATE.md

Before editing, write the intent checkpoint from MAS_C_EVIDENCE_PROTOCOL.md.
Then run a read-only source map for the touched files and nearby call sites.

Implementation rules:
- follow the feature plan and build prompt
- keep MAS as the only current product target
- keep MAS June as the agent surface
- keep vault files as storage truth
- classify legacy names before renaming or deleting
- collect evidence sized to the claim
- batch builds/tests only with a verification-debt ledger

After the first implementation batch, inspect the diff, run the narrow checks
that fit the touched scope, update the evidence pack, and continue hardening.
```

## Packet Audit Prompt

```text
Audit the MAS C packet for drift and readiness.

Read:
1. docs/mas-c/README.md
2. docs/mas-c/MAS_C_CONTROL.md
3. docs/mas-c/MAS_C_TRACEABILITY_MATRIX.md
4. docs/mas-c/MAS_C_TERMINOLOGY_CANON.md
5. docs/mas-c/MAS_C_ANTI_DRIFT_GUARD.md
6. docs/mas-c/MAS_C_EVIDENCE_PROTOCOL.md
7. docs/mas-c/MAS_C_OBJECTIVE_AUDIT.md
8. docs/mas-c/MAS_C_FILE_MANIFEST.md
9. every feature PLAN.md and BUILD_PROMPT.md

Return:
- missing files
- ID or manifest mismatches
- feature plan/build prompt mismatches
- MAS-only contradictions
- source-anchor gaps
- terms that weaken product-weight language
- unproven completion claims
- exact docs to edit, in order

Do not make code claims. This is a packet audit only.
```

## Cloud Research Prompt

Use `MAS_C_EXTERNAL_RESEARCH_PROMPT.md` as the source of truth. Do not paste a
shortened cloud prompt unless token limits force it; the full prompt carries the
attachment list, non-negotiables, and self-critique rubric.

## Redirect Prompt For In-Flight Agents

Use `prompts/05_MAS_C_LOCAL_BUILD_REDIRECT.md` when an in-flight local agent
needs to pivot to MAS C without losing useful work.

