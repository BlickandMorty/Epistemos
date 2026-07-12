# MAS C First-Pass Implementation Queue

ID: `MAS-C-FIRST-PASS-IMPLEMENTATION-QUEUE-2026-07-08`

This queue translates the MAS C feature stack into the first safe local
implementation pass. It does not replace the feature plans. It tells an agent
what to do first, what to read before editing, and what proof must exist before
moving to the next queue item.

## Queue Rules

- Work in order unless the owner explicitly redirects.
- Start each item with `MAS_C_EVIDENCE_PROTOCOL.md`.
- Use `MAS_C_LOCAL_SOURCE_ANCHORS.md` as the first source map, then verify
  current files with fresh search before editing.
- Run `MAS_C_ANTI_DRIFT_GUARD.md` searches before implementation edits.
- Keep verification debt in a ledger when builds/tests are batched.
- Do not call a queue item complete without the listed exit evidence.
- If a queue item reveals a strategic contradiction, update
  `MAS_C_TRACEABILITY_MATRIX.md` before changing feature plans.

## Queue Dashboard

| Queue | Feature | First local unit | Read before editing | Exit evidence |
|---|---|---|---|---|
| Q1 | Keelstone | Map vault writers, entitlements, privacy manifest, release scripts, and current archive scan commands. | `features/01-keelstone/*`, `MAS_C_RELEASE_EVIDENCE_GATE.md`, vault writer/provenance source files, `project.yml`, entitlements, privacy manifest. | Evidence pack with current vault/release map, entitlement/privacy printouts, and first release-scan command. |
| Q2 | Release Pruning | Classify App Store target membership and suspicious legacy names as active MAS, legacy-name, parked-provenance, forbidden, or unknown. | `features/11-release-pruning/*`, `MAS_C_ANTI_DRIFT_GUARD.md`, `project.yml`, archive scripts, June bridge files. | Classification table plus proposed smallest safe project/source edit. |
| Q3 | MAS June | Map one active MAS June registry, bridge, approval, cancel, rollback, and event path. | `features/02-mas-june/*`, June gateway/bridge/session files, `agent_core` registry/event files. | One-agent-authority map and list of legacy names that need rename/document/keep decisions. |
| Q4 | Epdoc Assist | Prove selected-note context can flow into the native Epdoc assist surface without a second agent. | `features/05-epdoc-assist/*`, `features/03-lumenlens/*`, Epdoc assist/dock files, editor selection source. | Read-only context-flow evidence and write-flow verification debt ledger. |
| Q5 | LumenLens | Prove one minimal-diff note suggestion/writeback path with provenance and undo. | `features/03-lumenlens/*`, editor writeback, provenance store, undo/source guard tests. | Fixture note before/after, provenance entry, undo proof or logged blocker. |
| Q6 | Storage Fusion | Build the storage truth map before changing storage code. | `features/12-storage-fusion/*`, AtomicVaultWriter, EditorProvenanceStore, index/search/graph rebuild files, old storage docs if referenced by owner. | Keep/hybridize/retire table and one proposed rebuild/recovery fixture. |
| Q7 | Reckoner | Prove one vault dataset artifact path and identify calculation/render ownership. | `features/04-reckoner/*`, dataset/table files, IronCalc/Univer integration seams, Epdoc notebook files. | Dataset truth map plus calc/render/provenance fixture plan. |
| Q8 | Embercatch | Prove one text capture to vault path and identify voice/privacy requirements before audio work. | `features/06-embercatch/*`, capture docs/code, note creation files, privacy manifest. | Capture fixture plan plus privacy/permission evidence ledger. |
| Q9 | Sync | Map current MAS-safe sync candidate and conflict behavior. | `features/08-sync/*`, sync docs/code, storage truth docs, entitlement/privacy files. | Add/update/delete/conflict fixture design and user-visible conflict proof plan. |
| Q10 | Lodestar | Build source-legality matrix before implementing any research source. | `features/07-lodestar/*`, `prompts/03_MAS_C_LEGALITY_MATRIX.md`, current ResearchHub/arXiv/source files. | Source legality table with at least one allowed low-risk source selected. |
| Q11 | Capabilities | Classify existing capability ideas as MAS-safe, parked, forbidden, or needs-source. | `features/09-capabilities/*`, agent capability registry, PDF/browser/voice/tool files. | Capability classification matrix and first safe capability proposal. |
| Q12 | Sigilry | Inventory visible MAS surfaces and define screenshot targets. | `features/10-sigilry/*`, native shell/view files, asset catalog, June/Epdoc/Reckoner visible surfaces. | Screenshot target list plus state-to-symbol mapping. |

## First Agent Prompt

Use this when starting the first MAS C implementation agent:

```text
You are implementing MAS C first pass Q1.

Read:
1. docs/mas-c/README.md
2. docs/mas-c/MAS_C_CONTROL.md
3. docs/mas-c/MAS_C_FEATURE_INDEX.md
4. docs/mas-c/MAS_C_ANTI_DRIFT_GUARD.md
5. docs/mas-c/MAS_C_EVIDENCE_PROTOCOL.md
6. docs/mas-c/MAS_C_FIRST_PASS_IMPLEMENTATION_QUEUE.md
7. docs/mas-c/MAS_C_LOCAL_SOURCE_ANCHORS.md
8. docs/mas-c/features/01-keelstone/PLAN.md
9. docs/mas-c/features/01-keelstone/BUILD_PROMPT.md
10. docs/mas-c/MAS_C_RELEASE_EVIDENCE_GATE.md

Do not edit first. Map the current vault/release state from source: vault
writers, provenance stores, entitlements, privacy manifest, project target
membership, release scripts, and archive scan commands. Leave an evidence pack
using MAS_C_EVIDENCE_PROTOCOL.md. Then propose the smallest safe implementation
edit or release-guard edit for owner/review.
```

## Queue Exit Discipline

When a queue item appears complete:

1. Fill the feature evidence pack.
2. Update verification-debt ledger.
3. Run narrow checks that fit the touched scope.
4. Run broader MAS checks at checkpoint boundaries.
5. Update `MAS_C_PACKET_CHANGELOG.md` only for packet-level changes.
6. Continue to the next queue item unless the owner redirects.
