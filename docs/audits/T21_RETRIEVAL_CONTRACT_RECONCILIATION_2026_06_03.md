---
state: t21-retrieval-contract-reconciliation
created_on: 2026-06-03
repo: /Users/jojo/Downloads/Epistemos
head_commit: 9782f0e3ed07773cbb39cc92eeeb46936d868df3
status: partially closed; semantic-recall capstone remains open
---

# T21 Retrieval Contract Reconciliation - 2026-06-03

## Current Evidence On Main

T21 is not missing from main, but it is not fully closed as a capstone.

Current green evidence:

- `F-VaultRecall-50` has a primary in-process artifact at
  `artifacts/falsifiers/vault_recall_50/result.json` with
  `overall_pass=true`, `top_1_exact_title_pct=0.9726`, and
  `adversarial_reject_pct=1.0000`.
- `F-Eidos-Bridge-RoundTrip` has a primary artifact at
  `artifacts/falsifiers/eidos_bridge_round_trip/result.json`; its closed
  citation membership, forged citation rejection, manifest mismatch rejection,
  hit retrieval, and vault manifest prefix axes are all true.
- `F-PageGather-Packetized-Caller` has a pass artifact at
  `artifacts/falsifiers/page_gather_packetized_caller/result.json`; the real
  Vault retrieval caller consumes packetized PageGather scores, keeps a broad
  candidate pool, and defers dense restore.
- `F-PageGather-Packetized-Policy-Acceptance` has a pass artifact at
  `artifacts/falsifiers/page_gather_packetized_policy_acceptance/result.json`;
  packetized PageGather is accepted only for retrieval/witness surfaces and does
  not promote dense `F-PageGather-M2Pro`.

## Remaining Gap

The T21 capstone remains open because semantic/paraphrase recall is not wired
through `VaultBackend`.

The current `falsify_vault_recall_50` harness records `top_5_paraphrase_pct` as
informational with a `0.0` floor. The source says this is intentional until the
Eidos semantic-recall lane is wired into `VaultBackend`; the current measured
artifact records `0/50` paraphrase hits. `agent_core/src/storage/retrieval_trace.rs`
also states that every current `VaultBackend` implementation populates lexical
signals only because the Q2 semantic path is not wired yet.

## What Is Truly Done

- Exact/title-style recall is not the old broken "first notes in manifest"
  behavior; the primary artifact and trace contract are present.
- Weak/rank-only evidence is guarded in Rust and Swift provenance surfaces.
- Eidos closed-citation round-trip evidence exists.
- Packetized PageGather is accepted for retrieval/witness use, while dense
  PageGather remains separate and unpromoted.

## What Is Not Truly Done

- Full T21 capstone unification is not closed.
- Eidos semantic-recall is not yet part of the `VaultBackend` retrieval path.
- The `top_5_paraphrase_pct >= 0.80` bar from the aspirational F' prompt is not
  honestly satisfied; it is currently an informational axis at `0.0`.
- A single capstone artifact tying Eidos semantic recall, VaultRecall candidate
  breadth, and PageGather packet policy together does not exist yet.

## Next Code Target

Wire an Eidos or RRF-fused semantic lane into `VaultBackend::hybrid_search_with_trace`
without removing the current lexical, graph, recency, MMR, confidence, exact
escalation, provenance, or PageGather packetized evidence. After that:

1. Raise `top_5_paraphrase_pct` from informational `0.0` to the real `0.80`
   threshold in `agent_core/src/bin/falsify_vault_recall_50.rs`.
2. Run `falsify_vault_recall_50` and require the paraphrase axis to pass.
3. Add a T21 capstone artifact that depends on the green VaultRecall, Eidos, and
   PageGather packetized artifacts without promoting dense PageGather.
