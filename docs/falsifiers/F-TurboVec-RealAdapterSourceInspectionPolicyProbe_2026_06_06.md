---
falsifier: F-TurboVec-RealAdapterSourceInspectionPolicyProbe
date: 2026-06-06
artifact: artifacts/falsifiers/turbovec_real_adapter_source_inspection_policy_probe/result.json
scope: metadata-only / T1-L1
---

# F-TurboVec-RealAdapterSourceInspectionPolicyProbe

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS ships
the safe floor, Pro contains the gated/research/vault/omega ladder, and no
claim promotes without visible proof.

## Result

PASS as a metadata-only T1/L1 primary witness.

- Command:
  `Tools/falsifiers/f_turbovec_real_adapter_source_inspection_policy_probe.sh`
- Artifact:
  `artifacts/falsifiers/turbovec_real_adapter_source_inspection_policy_probe/result.json`
- Pinned upstream: `https://github.com/RyanCodrai/turbovec`
- Pinned revision: `efe29a184986cbf562a9847c2ac52a2990bfaca2`
- Source-inspection-policy address:
  `turbovec_real_adapter_source_inspection_policy_probe:0a9d02db1360ce978634c1df4190f32a89e6f8087bf4455234de6b1146ec555f@1779040903000`
- Policy rows: 22.
- Future-readable rows by later witness: 16.
- Blocked rows: 6.
- Future raw-source byte cap for later witnesses: `196608`.
- Red fixtures rejected: 72.
- Former next research-to-build unit landed:
  `F-TurboVec-RealAdapterMotifExtractionCardProbe`.
- Current next research-to-build unit:
  `turbovec_quarantine_real_adapter_exact_baseline_shadow_replay_probe`.
- Intermediate next research-to-build unit, now landed as
  `F-TurboVec-RealAdapterCleanRoomAdapterPlanProbe`:
  `turbovec_quarantine_real_adapter_clean_room_adapter_plan_probe`.
- Historical next cursor recorded in this artifact:
  `turbovec_quarantine_real_adapter_motif_extraction_card_probe`.

## What This Proves

The pinned TurboVec branch now has a manifest-bound source-inspection policy
after the source-byte-manifest gate. The policy separates future
quarantine-only reads for provenance, documentation, API shapes, Rust behavior
specs, dependency metadata, test intent, and benchmark harness metadata from
blocked native-link, binary, symlink, and integration rows.

The witness rejects source inspection without a manifest row, verbatim code
copying, product import, dependency insertion, native-link probes, adapter
builds, benchmark-authority laundering, route authority, hidden context
injection, hidden cloud fallback, MAS/Live/T2+ promotion, live dense 70B
claims, SSD-as-RAM claims, bad proof refs, missing clean-room notes, missing
AnswerPacket caveats, nonzero current source/archive/quarantine/product/index/
model/runtime/provider bytes, and stale blocked-row reads.

## What It Does Not Prove

This does not read TurboVec source content, clone the repo, open a codeload
archive, write quarantine files, import source, add dependencies, build an
adapter, run a benchmark, probe native links, open index bytes, load
Gemma/QAT/GGUF/MLX/LiteRT/model bytes, choose RuntimeRouter/System G routes,
advance L2 capability, or make L3 user-facing model capability green. It is
not live 70B, live sparse 70B, or product runtime proof.

## Architecture Consequence

TurboVec remains Eidos/AppColdStore rebuildable cache material and quarantine
research, but the large-local-model path is more buildable: future motif
extraction now has a clean-room policy, per-row read/block decisions, byte
ceilings, no-product-graph proof, native-link blocks, benchmark caveats,
rollback, RunEventLog, and AnswerPacket visibility. This lets Epistemos study
TurboVec for compressed retrieval and context-selection motifs that may later
support Gemma/QAT and 70B-class cold assembly without contaminating product code
or turning research into hidden route authority.

## 2026-06-06 Follow-On

`F-TurboVec-RealAdapterMotifExtractionCardProbe` is now landed. The source
inspection policy remains the upstream gate, and the next safe research-to-build
step is a clean-room adapter plan, not product import, native-link probing,
benchmark authority, route mutation, or model/runtime execution.
