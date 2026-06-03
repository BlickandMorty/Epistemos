---
state: t21-retrieval-contract-reconciliation
created_on: 2026-06-03
repo: /Users/jojo/Downloads/Epistemos
head_commit: semantic-fallback primary witness commit on main
status: closed by primary capstone witness
---

# T21 Retrieval Contract Reconciliation - 2026-06-03

## Current Evidence On Main

T21 is not missing from main. VaultRecall semantic recall is closed, and the
single capstone artifact over VaultRecall, Eidos, and PageGather is now green.

Current green evidence:

- `F-VaultRecall-50` has a primary in-process artifact at
  `artifacts/falsifiers/vault_recall_50/result.json` with
  `overall_pass=true`, `top_1_exact_title_pct=0.9726`, `top_5_paraphrase_pct=0.9800`,
  and `adversarial_reject_pct=1.0000`.
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
- `F-T21-RetrievalContract-Capstone` has a primary artifact at
  `artifacts/falsifiers/t21_retrieval_contract_capstone/result.json`; it binds
  the VaultRecall, Eidos, PageGather caller, and PageGather policy witnesses
  into one T21 proof.

## Remaining Caveat

The dense `F-PageGather-M2Pro` primary remains separate and unpromoted. This is
intentional: T21 accepts packetized PageGather only for retrieval/witness
surfaces and does not convert the dense memory-bandwidth gate to green.

`falsify_vault_recall_50` now gates `top_5_paraphrase_pct` at the real `0.80`
floor and records `49/50` paraphrase hits. The semantic fallback fires only
when lexical/path-title retrieval retains nothing, so exact/title, Unicode,
Synthesis, ChattyPrefix, PureChatter, and Adversarial rows stay green.

## What Is Truly Done

- Exact/title-style recall is not the old broken "first notes in manifest"
  behavior; the primary artifact and trace contract are present.
- Semantic/paraphrase recall clears the real F' floor: `49/50` top-5
  paraphrase hits against a required `0.80`.
- Weak/rank-only evidence is guarded in Rust and Swift provenance surfaces.
- Eidos closed-citation round-trip evidence exists.
- Packetized PageGather is accepted for retrieval/witness use, while dense
  PageGather remains separate and unpromoted.
- A single T21 capstone artifact now ties the green VaultRecall, Eidos, and
  PageGather packetized witnesses together.

## What Is Not Truly Done

- Dense `F-PageGather-M2Pro` is not green and is not promoted by T21.

## Next Code Target

Move to the next non-T21 architecture gate from the main-only reconciliation
queue. Future dense Eidos/HNSW adapters can replace the concept-normalized
fallback behind the same `RetrievalSignal::Semantic` trace channel.
