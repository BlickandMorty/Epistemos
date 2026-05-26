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

## Resumed Verification

After the user explicitly asked to continue, verification resumed from current
`main` on branch `phase2-terminal-b-vault-recall-tests-2026-05-24`.

The resumed Xcode run first exposed one additional compile issue from the
Terminal A gate surface:

- `ChatCoordinator.runEidosCitationGate` is intentionally nonisolated.
- `EidosBridge.validateCitations(packet:sourceIds:)` was still inferred
  main-actor isolated under the project-wide `-default-isolation=MainActor`
  setting.
- Patch applied: mark `EidosBridge.validateCitations(packet:sourceIds:)`
  `nonisolated`, matching the synchronous Rust FFI validation contract.

Verification after that patch:

- Focused Xcode run passed:
  `AnswerPacketBadgeTests` and `VaultRecallWiringTests`, 10 Swift Testing tests
  passed.
- W-23 gate passed:
  `bash scripts/check-vault-context-contract.sh`.
- F-VaultRecall-50 passed:
  `cargo +stable-aarch64-apple-darwin test --manifest-path agent_core/Cargo.toml --test f_vault_recall_50 -- --nocapture`,
  3 tests passed.

## Current State

Implemented and focused-verified after resume:

- Chat vault recall traces are recorded and carried through chat state,
  persisted message rows, and local RunEventLog events.
- Chat, NoteChatSidebar, ChatInputBar autocomplete, and Halo surfaces render
  visible provenance.
- `AnswerPacketBadge` renders per-row claim kind and confidence.
- Vault recall diagnostics expose the four W-21 metrics honestly.
- W-23 `LIMIT N` / first-notes rg gate is present in CI and passed locally
  after the final compile fix.

Process note:

- The original stop occurred on `docs/deferred-work-guarantee-2026-05-23`.
- The resumed verification and final compile fix are on
  `phase2-terminal-b-vault-recall-tests-2026-05-24`, branched from current
  `main`.
- The local Rust environment had no rustup default. The harness was therefore
  run with explicit `+stable-aarch64-apple-darwin`, avoiding any machine-wide
  rustup default mutation.

## Required Next Action

No stop-condition blocker remains for the focused Terminal B verification
slice. Remaining broader acceptance work is to exercise the live chat
closed-citation emit path end to end once the chat call-sites invoke the Eidos
gate.

## Law / Tier / No-Orphan

- Laws honored by the pending implementation: Law 3 Active-support, Law 5
  Glue, Law 7 Witness.
- Tier: Tier 1 (MAS).
- No-Orphan data classes touched: `VaultRecallTrace`, `VaultRecallCandidate`,
  `VaultRecallMetrics.RecallBenchmarkSnapshot`, `ChatMessage.vaultRecallTrace`,
  `SDMessage.vaultRecallTraceData`, and `vault_recall_trace` EventStore rows.
- Invariants targeted: UAS address, plane, residency, WBO honesty for
  approximate scores/rates, and WRV visibility for product-facing rows.
