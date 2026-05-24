# Vault Recall Visibility Blocker - 2026-05-24

## Stop Condition

Terminal B hit the user-defined stop condition: build/test failed three
consecutive verification attempts.

Attempts:

1. Focused Xcode tests failed before compile because the shared DerivedData
   build database was locked.
2. Isolated DerivedData focused Xcode tests failed during Swift compile:
   `EventStore.appendVaultRecallTrace(sessionId:trace:)` was main-actor
   isolated when called from nonisolated `ChatCoordinator.recordVaultRecallTrace`.
   Patch applied: the vault trace append path now matches EventStore's existing
   nonisolated queue-backed APIs.
3. Focused Xcode tests failed during Swift compile:
   `MiniChatView` constructed `ChatCoordinator.NotesContextResolution` without
   the new `vaultRecallTrace` field. Patch applied:
   `vaultRecallTrace: nil` is now provided on the no-context path.

No fourth build/test run was started after the third failure.

## Current State

Implemented but not fully verified after the last patch:

- Chat vault recall traces are recorded and carried through chat state,
  persisted message rows, and local RunEventLog events.
- Chat, NoteChatSidebar, ChatInputBar autocomplete, and Halo surfaces render
  visible provenance.
- `AnswerPacketBadge` renders per-row claim kind and confidence.
- Vault recall diagnostics expose the four W-21 metrics honestly.
- W-23 `LIMIT N` / first-notes rg gate is present in CI and passed locally
  before the final compile fixes.

Process note:

- The worktree is currently on `docs/deferred-work-guarantee-2026-05-23`
  (`cd0c33165b`), not on the expected fresh Terminal B branch from `main`
  (`04b7331e4c`). I did not switch branches after the stop condition because
  the tree contains unrelated in-progress edits that must not be reverted or
  moved implicitly.

## Required Next Action

Resume with a single focused verification run after this stop:

```sh
./scripts/xcodebuild_epistemos.sh test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/derived-data-terminal-b \
  -only-testing:EpistemosTests/AnswerPacketBadgeTests \
  -only-testing:EpistemosTests/VaultRecallWiringTests \
  CODE_SIGNING_ALLOWED=NO
```

Then run:

```sh
bash scripts/check-vault-context-contract.sh
cargo test --manifest-path agent_core/Cargo.toml --test f_vault_recall_50 -- --nocapture
```

Report `F-VaultRecall-50` honestly. The Terminal A Eidos bridge dependency
still blocks closed-citation end-to-end acceptance.

## Law / Tier / No-Orphan

- Laws honored by the pending implementation: Law 3 Active-support, Law 5
  Glue, Law 7 Witness.
- Tier: Tier 1 (MAS).
- No-Orphan data classes touched: `VaultRecallTrace`, `VaultRecallCandidate`,
  `VaultRecallMetrics.RecallBenchmarkSnapshot`, `ChatMessage.vaultRecallTrace`,
  `SDMessage.vaultRecallTraceData`, and `vault_recall_trace` EventStore rows.
- Invariants targeted: UAS address, plane, residency, WBO honesty for
  approximate scores/rates, and WRV visibility for product-facing rows.
