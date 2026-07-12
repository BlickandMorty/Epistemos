# MAS C Traceability Matrix

ID: `MAS-C-TRACEABILITY-MATRIX-2026-07-08`

This matrix records how the Cursor MAS pivot research was converted into MAS C.
It is the anti-drift bridge between external research and the standalone packet.

## Source Artifacts

- Cursor minimal prompt pack:
  `/Users/jojo/Downloads/epistemos-mas-pivot-cloud-research-packet-2026-07-07 2/MAS_PIVOT_MINIMAL_PROMPT_PACK_2026_07_07.md`
- Cursor integrated dossier:
  `/Users/jojo/Downloads/epistemos-mas-pivot-cloud-research-packet-2026-07-07 2/MAS_PIVOT_INTEGRATED_RESEARCH_DOSSIER_2026_07_07.md`
- Existing local MAS lock:
  `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md`
- Existing fabric/rubric docs:
  `docs/prompts/INTEGRATION_FABRIC.md`
  and `docs/prompts/RESEARCH_PROMPT_STANDARD.md`

## Accepted Research To MAS C Mapping

| Cursor / local research finding | MAS C destination | Status |
|---|---|---|
| Use one MAS product, not Pro/Experimental/1Code/OpenChamber. | `MAS_C_CONTROL.md`, `README.md`, every feature `PLAN.md` parked/forbidden section. | Accepted. |
| Replace many overlapping operational prompts with a small control set. | `prompts/01` through `prompts/05`, plus `MAS_C_MASTER_BUILD_PROMPT.md`. | Accepted. |
| Treat phase plans as attachments instead of giant paste prompts. | Each feature folder has `PLAN.md` and `BUILD_PROMPT.md`; operational prompts are separate. | Accepted. |
| Build order should start with Keelstone, then MAS June, then LumenLens/Reckoner, then capture/sync/research. | `MAS_C_MASTER_PLAN.md` build order. | Accepted and refined. |
| MiniChat should become native Epdoc assist backed by MAS June. | `features/05-epdoc-assist/PLAN.md` and `BUILD_PROMPT.md`. | Accepted. |
| Storage should hybridize file truth plus append-only provenance/op-log and derived indexes. | `MAS_C_MASTER_PLAN.md`, `features/12-storage-fusion/PLAN.md`, `prompts/04`. | Accepted. |
| ResearchHub/source work needs legality matrix before build. | `features/07-lodestar/PLAN.md`, `prompts/03`, `MAS_C_EXTERNAL_RESEARCH_PROMPT.md`. | Accepted. |
| Base app pruning and archive scans are first-class MAS work. | `features/11-release-pruning/PLAN.md`, `MAS_C_RELEASE_EVIDENCE_GATE.md`. | Accepted. |
| `network.server` entitlement requires justification or removal. | `MAS_C_CONTROL.md`, `MAS_C_RELEASE_EVIDENCE_GATE.md`, Keelstone/June plans. | Accepted. |
| Privacy manifest currently has no collected data/tracking and required-reason APIs are present. | `MAS_C_RESEARCH_ABSORPTION.md`, release gate. | Accepted as current local fact, not permanent proof. |
| Current archive/source names include Goose/Hermes bridge names. | `MAS_C_CONTROL.md`, MAS June, Release Pruning. | Accepted with nuance. |
| Reddit commercial API use is risky without explicit review/terms. | `features/07-lodestar/PLAN.md`, `prompts/03`, `MAS_C_EXTERNAL_RESEARCH_PROMPT.md`. | Accepted. |
| Older storage architecture may contain useful ideas but should not replace vault truth wholesale. | `features/12-storage-fusion/PLAN.md`, `prompts/04`. | Accepted. |
| Every feature should integrate through F1-F6 fabric. | `MAS_C_MASTER_PLAN.md` and every feature `PLAN.md`. | Accepted. |
| External/cloud agents need a focused prompt and attachment list. | `MAS_C_EXTERNAL_RESEARCH_PROMPT.md`. | Accepted. |
| Future agents need a cross-feature dashboard to avoid reading plans out of order. | `MAS_C_FEATURE_INDEX.md`. | Accepted as hardening. |
| Future agents need a repeatable anti-drift preflight. | `MAS_C_ANTI_DRIFT_GUARD.md`. | Accepted as hardening. |
| Future agents need a repeatable evidence shape for intent, verification debt, release proof, UI proof, storage proof, and source legality. | `MAS_C_EVIDENCE_PROTOCOL.md`. | Accepted as hardening. |
| Future research batches need a controlled merge path. | `MAS_C_RESEARCH_INTAKE_PROTOCOL.md`. | Accepted as hardening. |
| Packet evolution needs a lightweight changelog. | `MAS_C_PACKET_CHANGELOG.md`. | Accepted as hardening. |
| Local implementation agents need a first-pass queue that prevents jumping into later features before storage/release proof. | `MAS_C_FIRST_PASS_IMPLEMENTATION_QUEUE.md`. | Accepted as hardening. |
| Owner product-weight language needs operational definitions so "new stack", "hard", "native", and "replace" cannot be flattened into polish. | `MAS_C_TERMINOLOGY_CANON.md`. | Accepted as hardening. |
| Local implementation agents need grounded source starting points for each MAS C queue item. | `MAS_C_LOCAL_SOURCE_ANCHORS.md`. | Accepted as hardening; refresh before implementation. |
| Future agents need a quick prompt chooser for local start, redirect, packet audit, legality, storage, and cloud research modes. | `MAS_C_HANDOFF_PROMPT_CATALOG.md`. | Accepted as hardening. |

## Corrected Or Reframed Findings

| Research finding | MAS C correction | Why |
|---|---|---|
| Release archive strings containing Goose/Hermes are failures. | Names trigger classification, not automatic deletion. | Cursor Appendix O clarified in-process MAS bridge names can be retained temporarily if loopback-only, documented, and leak-scanned. |
| `network.server` is a direct blocker. | It is a blocker unless justified by actual loopback-only MAS behavior or removed. | The right gate is behavior plus App Review explanation, not entitlement panic. |
| Old storage could be restored if current storage feels weak. | Old storage is research input; default is file truth plus additive hardening. | User wants best storage, not a brittle rollback. |
| MiniChat can inherit 1Code patterns. | Only the product idea survives; runtime/UI stack is MAS-native Epdoc Assist. | Avoids the exact reskin/wrapper failure the owner rejected. |

## Feature Coverage Check

| Feature | Plan | Build prompt | Research absorbed |
|---|---|---|---|
| Keelstone | `features/01-keelstone/PLAN.md` | `features/01-keelstone/BUILD_PROMPT.md` | vault/release safety, entitlement/privacy/archive proof |
| MAS June | `features/02-mas-june/PLAN.md` | `features/02-mas-june/BUILD_PROMPT.md` | single agent surface, bridge classification, no hidden runtime |
| LumenLens | `features/03-lumenlens/PLAN.md` | `features/03-lumenlens/BUILD_PROMPT.md` | Epdoc editor, minimal diff, provenance, notebook seams |
| Reckoner | `features/04-reckoner/PLAN.md` | `features/04-reckoner/BUILD_PROMPT.md` | vault-native datasets, IronCalc authority, render-only table layer |
| Epdoc Assist | `features/05-epdoc-assist/PLAN.md` | `features/05-epdoc-assist/BUILD_PROMPT.md` | MAS-native MiniChat replacement |
| Embercatch | `features/06-embercatch/PLAN.md` | `features/06-embercatch/BUILD_PROMPT.md` | quick capture, voice privacy, vault notes |
| Lodestar | `features/07-lodestar/PLAN.md` | `features/07-lodestar/BUILD_PROMPT.md` | ResearchHub, source legality, citations |
| Sync | `features/08-sync/PLAN.md` | `features/08-sync/BUILD_PROMPT.md` | MAS-safe sync, conflict UX, no Pro git lane |
| Capabilities | `features/09-capabilities/PLAN.md` | `features/09-capabilities/BUILD_PROMPT.md` | PDF/browser/voice/tools through MAS June |
| Sigilry | `features/10-sigilry/PLAN.md` | `features/10-sigilry/BUILD_PROMPT.md` | native design coherence, real status art |
| Release Pruning | `features/11-release-pruning/PLAN.md` | `features/11-release-pruning/BUILD_PROMPT.md` | target membership, archive scans, classification |
| Storage Fusion | `features/12-storage-fusion/PLAN.md` | `features/12-storage-fusion/BUILD_PROMPT.md` | file truth, op-log, derived indexes, old-storage verdict |

## Not Yet Proven By MAS C

MAS C is a control packet, not a code implementation. It does not prove:

- A fresh MAS release archive is clean.
- Current `network.server` entitlement is accepted or removable.
- App Store target membership has been pruned.
- Old storage architecture has been fully compared against live source.
- ResearchHub source legality has been exhaustively rechecked.
- Native UI implementation quality has changed.

Those belong to feature execution and release evidence.
