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
