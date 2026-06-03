---
falsifier: F-T21-RetrievalContract-Capstone
created_on: 2026-06-03
status: PRIMARY WITNESS
artifact: artifacts/falsifiers/t21_retrieval_contract_capstone/result.json
---

# F-T21 Retrieval Contract Capstone

This capstone proves the T21 retrieval contract is green across the current
main witnesses:

- `F-VaultRecall-50`: exact/title, semantic/paraphrase, and adversarial floors.
- `F-Eidos-Bridge-RoundTrip`: closed-citation membership and forged/mismatched
  citation rejection.
- `F-PageGather-Packetized-Caller`: Vault retrieval consumes packetized
  PageGather scores.
- `F-PageGather-Packetized-Policy-Acceptance`: packetized PageGather is accepted
  only for retrieval/witness surfaces; dense PageGather remains unpromoted.

## Command

```bash
Tools/falsifiers/f_t21_retrieval_contract_capstone.sh
```

## Current Artifact

`artifacts/falsifiers/t21_retrieval_contract_capstone/result.json` records
`overall_pass=true` and `artifact_kind=primary_witness`.

Key axes:

- `vault_recall_semantic_floor=true`
- `eidos_closed_citation_round_trip=true`
- `page_gather_packetized_caller_witness=true`
- `page_gather_packetized_policy_witness=true`
- `dense_page_gather_not_promoted=true`

## Caveat

This closes the T21 retrieval-contract proof. It does not promote dense
`F-PageGather-M2Pro`; that remains separate until the dense measured gate passes.
