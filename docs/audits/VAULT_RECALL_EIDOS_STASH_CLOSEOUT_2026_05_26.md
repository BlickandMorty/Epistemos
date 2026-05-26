# VaultRecall / Eidos Stash Closeout - 2026-05-26

Status: closed for current product recovery.

Sources:

- `stash@{3}` (`auto-pre-pull-after-72-merge`)
- the chat/VaultRecall/Eidos slice of `stash@{6}`

Recovery rule: neither stash was popped, dropped, checked out, or bulk-applied.
The stale code deltas were compared against current `main` and were not
replayed because current `main` already contains the durable product path.

## Decision

Do not raw-apply the chat/VaultRecall/Eidos files from these stashes. The stash
trees are older than the merged Wave-2 and recovery checkpoints. Replaying them
would downgrade current `ChatCoordinator`, `VaultRecallWiring`, chat surfaces,
and provenance tests.

The useful work was the resumed verification record and the reminder that the
old blocker is no longer active. Those facts are now promoted into:

- `docs/audits/VAULT_RECALL_VISIBILITY_2026_05_24.md`
- `docs/audits/VAULT_RECALL_VISIBILITY_BLOCKER_2026_05_24.md`

## Current Main Evidence

- `ChatCoordinator` records `VaultRecallTrace` into `VaultRecallTraceSink` and
  `EventStore`.
- `MessageBubble` renders `AnswerPacketBadge` and `VaultRecallProvenanceCard`.
- `VaultRecallWiringTests` verifies scaffold/stub traces and real
  `SearchIndexService` production traces.
- `EidosBridgeProductionTests` covers production Eidos open/insert/retrieve,
  citation validation, forged-citation rejection, manifest mismatch rejection,
  batch validation, and SearchIndexService mirroring into the Eidos index.
- `scripts/check-vault-context-contract.sh` is wired in CI.
- `artifacts/falsifiers/vault_recall_50/result.json` records the M2 Pro
  F-VaultRecall-50 primary witness.
- `artifacts/falsifiers/eidos_bridge_round_trip/result.json` records the M2 Pro
  F-Eidos-Bridge-RoundTrip primary witness.

## Remaining Caveat

The live chat closed-citation emit path still needs an end-to-end product test
that proves a real assistant response is blocked or rewritten when the emitted
source IDs fail `EidosBridge.validateCitations(packet:sourceIds:)`.

That is Wave 3 product-path acceptance work, not stash recovery.
