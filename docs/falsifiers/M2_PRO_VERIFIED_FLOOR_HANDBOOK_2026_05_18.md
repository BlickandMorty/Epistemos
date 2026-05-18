---
state: t23b-m2-pro-falsifier-handbook
created_on: 2026-05-18
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
branch: codex/t23b-m2pro-falsifier-handbook-2026-05-18
---

# M2 Pro Verified Floor Handbook - 2026-05-18

This handbook pins every falsifier to Jojo's real floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB unified memory, approximately 200 GB/s memory bandwidth. A gate is not marked passed unless this repo contains evidence: a commit SHA, a recorded command, and a passing output artifact.

## Canon

- Prompt deck: `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 `T23B - M2 Pro Falsifier Handbook`.
- Forever-loop discipline: `docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md` §3.5.
- Hardware lock: `docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md`.
- V6.2 falsifier ladder: `docs/fusion/helios v6.2.md` §1.4 and `Falsifier order`.
- UAS-ACS sort: `docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` §5.

## Run-First Order

1. F-Eidos-ClosedCitation
2. F-PageGather-Baseline
3. F-UAS-CopyCount
4. F-ULP-Oracle
5. F-KV-Direct-Gate
6. F-SemiseparableBlockScan
7. F-LocalRecallIsland

The remaining gates are still required and are cataloged below as the loop fills the handbook.

## Falsifier Rows

| Falsifier | Purpose | Current status | Input fixture | Pass threshold | Failure meaning | Fallback route | Product lane | Exact command | Expected artifact |
|---|---|---|---|---|---|---|---|---|---|
| F-Eidos-ClosedCitation | Prove Eidos V0 only lets chat/model output cite source IDs returned in an `EidosContextPacket`, with visible source trace. | NOT IMPLEMENTED. On this branch, `agent_core/src/eidos/` and `Epistemos/Eidos/` are absent; no closed-citation falsifier script exists. | Seed corpus with one note hit, one `.epdoc` projection hit, one code hit, one graph-neighborhood hit, one duplicate source, one fake citation ID, one empty-vault query, and one unicode query. | All generated citations must be members of the returned Eidos context packet; fake citation rejection must be explicit; empty/no-result cases defer instead of fabricating. | Source-truth is not sealed: Brain Panel/chat can display or emit unsupported citations, breaking the witness law before web augmentation. | Keep Eidos V0 local-only; block Brain Panel closed-citation claims; route through existing vault/source trace until T10/T22B land evidence. | Core now; Pro/Research web augmentation later. | `tools/falsifiers/f_eidos_closed_citation.sh` | `artifacts/falsifiers/f_eidos_closed_citation/result.json` plus the returned context packet and rejected fake-citation trace. |
| F-VaultRecall-50 | Prove topical vault recall does not return the first irrelevant index-order notes and surfaces enough candidates plus trace to make retrieval honesty visible. | PARTIAL EVIDENCE, NOT FULLY PASSED. `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md` records Fix B at commit `2281c73f0` and `cargo test --manifest-path agent_core/Cargo.toml --lib` → 1194 passed, plus `strip_query_chatter` 4/4. The broader T21 contract still requires full-manifest inventory, 50-200 candidate retrieval, and visible lexical/semantic/graph/recency/MMR trace across entry points. No T23B script exists. | Vault fixture with at least 50 notes: 7 distractor notes matching chatty terms, 3+ residency-governance target notes, unicode notes, stopword-only query, single-word query, multi-paragraph query, and no-result query. | For `Pull my notes on residency governance`, top packed context includes the residency-governance targets, never just index-order distractors; retrieval considers the full manifest, gathers 50-200 candidates before packing, emits trace components, and weak evidence asks/broadens instead of pretending. | The app still cannot be trusted to find the user's own notes; ceiling research and closed citations become decoration over broken recall. | Keep Fix B query-chatter stripping; block ship claims on full vault context until T21 proves inventory completeness, trace visibility, and broad candidate retrieval. | Core / V1 credibility gate. | `tools/falsifiers/f_vault_recall_50.sh` | `artifacts/falsifiers/f_vault_recall_50/trace.jsonl`, candidate manifest, packed context, and source-trace summary. |
| F-PageGather-Baseline | Calibrate the M2 Pro contiguous-memory floor that every PageGather scatter threshold depends on. | NOT IMPLEMENTED as a hardware gate. `Epistemos/Shaders/PageGather.metal` and `agent_core/src/helios/page_gather.rs` exist as substrate scaffolding, but `docs/ACCEPTANCE_PROOFS_V6_1_2026_05_16.md` explicitly caveats Helios kernel hardware validation as separate; no `falsifier_calibration.toml` or T23B script exists. | STREAM-on-Metal-style contiguous read probe over 256 MB, 512 MB, and 1 GB buffers; 5 runs per size; each measurement window must be at least 1.0 s. | Record median `BW_baseline_M2Pro` per buffer and overall. Canon expects the local sustained band to drive later thresholds, commonly 63-73 GB/s after recalibration, never 70% of theoretical 200 GB/s. | Scatter gates become numerology: using theoretical or sub-second burst bandwidth would either create an impossible pass bar or hide memory-path regressions. | If `BW_baseline_M2Pro` is below 60 GB/s, lower the scatter pass band to at least 65% of the measured baseline and document the rig state; do not pretend. | Research / V2 falsifier-gated; MAS-safe only after measured floor exists. | `tools/falsifiers/f_page_gather_baseline.sh` | `artifacts/falsifiers/page_gather/baseline/falsifier_calibration.toml` plus raw per-run timing JSONL. |
| F-PageGather-Scatter | Prove the active-support memory law by measuring PageGather scatter against the locally measured contiguous baseline. | NOT IMPLEMENTED as a hardware gate. `pageGatherScatter` and `pageGatherScatterScaled` exist in `Epistemos/Shaders/PageGather.metal`, and the CPU reference exists in `agent_core/src/helios/page_gather.rs`; no Swift dispatcher, M2 Pro timing run, or T23B script evidence exists. | Random page-stride index lists over 256 MB and 512 MB source buffers, plus sequential control indices; use the `BW_baseline_M2Pro` artifact from F-PageGather-Baseline. | Sustained scatter throughput is at least 70% of `BW_baseline_M2Pro` over windows of at least 1.0 s for the required working sets; output bytes match the CPU reference. | Active-support page movement is too slow or unverified; LocalRecallIsland and memory-tier claims cannot use PageGather as their bandwidth floor. | Do not run scatter without a baseline. If baseline is low but documented, use the documented lowered percentage route from F-PageGather-Baseline; otherwise keep PageGather feature-gated. | Research / V2 falsifier-gated; MAS Tier-2 only after gate evidence. | `tools/falsifiers/f_page_gather_scatter.sh` | `artifacts/falsifiers/page_gather/scatter/result.json`, raw timings, baseline reference, and CPU-vs-Metal correctness digest. |
