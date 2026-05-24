# Vault Recall Visibility Audit - 2026-05-24

## Scope

Terminal B wires visible vault-recall provenance into chat answers and adjacent search surfaces.
Tier classification: **Tier 1 (MAS)**.

This work advances W-19, W-20, W-21, W-23, and W-27. It does not add Pro,
Research, or Vault-shipping behavior. Terminal A's Eidos bridge is now present
on `main`; this pass records and exposes recall trace data and fixes the batch
validator isolation needed by the chat citation gate, but the focused tests did
not exercise a full live chat closed-citation emit path.

Process note: the first verification loop stopped on the user-defined
three-failure rule while an older dirty branch was active. The resumed pass ran
from current `main` on `phase2-terminal-b-vault-recall-tests-2026-05-24`; see
`VAULT_RECALL_VISIBILITY_BLOCKER_2026_05_24.md` for the stop/resume trail.

## Audit

Read order completed before edits:

1. `docs/LEGENDARY_CODEWORD_2026_05_23.md`
2. `docs/LEGENDARY_ARCHITECTURE_NO_COMPROMISE_AUDIT_2026_05_23.md`
3. `docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md`
4. `docs/CANONICAL_CHRONICLE_2026_05_23.md` sections 1.2, 2, and 3
5. `docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md`
6. `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md`
7. `CLAUDE.md`

Local audit found the existing substrate pieces in main:

- `RRFFusionQuery.swift` and `SearchIndexService.fusedSearch` already provide
  ranked fused recall rather than first-N index order.
- `EventStore` already persists run events.
- `ChatState` already carries assistant presentation metadata and
  `AnswerPacketEmitter` already emits per-message packets.
- `NoteChatSidebar` already had the provenance-card pattern; ChatInputBar and
  Halo were the missing W-20 surfaces.

## Build

Implemented:

- `ChatCoordinator` now records `VaultRecallTrace` for explicit note context,
  implicit vault lookup, include-manifest retrieval, indexed fallback answers,
  and vault search/read tool starts.
- `EventStore` now persists `vault_recall_trace` events in the existing local
  event log.
- `ChatMessage`, `ChatState`, and `SDMessage` now carry a recall trace through
  live streaming, cancellation, error, and persisted transcript paths.
- `VaultRecallProvenanceCard` renders visible "why this note" details in chat,
  note chat, autocomplete, and Halo surfaces.
- `AnswerPacketBadge` renders the five-row claim taxonomy
  `synthesis/empirical/mathematical/causal/speculative` and confidence taxonomy
  `verified/plausible/speculative/blocked`.
- `VaultRecallHealthRow` now shows the four W-21 metrics without inventing
  green values: top-1 exact title, top-5 paraphrase, synthesis two-note
  citation, adversarial reject.
- `scripts/check-vault-context-contract.sh` and the CI workflow gate reject
  `LIMIT N` and `first ... notes` context construction in production chat
  retrieval surfaces.

## No-Orphan Check

Touched data classes:

- `VaultRecallTrace`
- `VaultRecallCandidate`
- `VaultRecallMetrics.RecallBenchmarkSnapshot`
- `ChatMessage.vaultRecallTrace`
- `SDMessage.vaultRecallTraceData`
- local `RunEventLog` events of kind `vault_recall_trace`
- product-facing chat provenance cards and AnswerPacket badges

Invariants:

- **UAS address:** traces retain the effective query plus candidate titles,
  paths, ranks, and scores; chat rows retain the message/session address.
- **Plane:** retrieval remains in the existing vault/search plane; UI additions
  are Reader/Witness surfaces and do not mutate vault content.
- **Residency:** traces are kept in local Swift state, local SwiftData message
  rows, and the local event store. No cloud fallback is introduced.
- **WBO if approximate:** scores and recall-health rates are displayed as
  ranked/benchmark signals, with pending values left pending instead of marked
  pass.
- **WRV if product-facing:** every assistant row now has a visible provenance
  card and every row has a visible claim/confidence badge; missing packets are
  explicitly represented as blocked/speculative.

## 7 Laws

- **Law 3 - Active-support:** chat rows carry active recall support metadata
  through streaming and persistence instead of losing it after retrieval.
- **Law 5 - Glue:** ChatCoordinator, EventStore, transcript state, and the UI
  surfaces share one trace object rather than parallel ad hoc labels.
- **Law 7 - Witness:** the product-facing answer shows why notes were selected,
  which claim kind was made, and what confidence class the row carries.

Secondary alignment:

- **Law 2 - Address:** trace rows retain query/candidate/session addresses.
- **Law 4 - Lattice-error:** approximate search evidence is shown as ranked
  signal, not as verified proof.

## W-Rows And Falsifiers

- **W-19:** ChatCoordinator emits a visible recall trace and avoids first-N
  context construction.
- **W-20:** provenance cards now cover NoteChatSidebar, ChatInputBar
  autocomplete, and Halo ShadowPanel.
- **W-21:** VaultRecallHealthRow exposes the four required recall-health
  metrics without fake success states.
- **W-23:** CI now gates `LIMIT N` / `first ... notes` patterns in production
  chat retrieval surfaces.
- **W-27:** every chat row can render claim_kind plus confidence through
  `AnswerPacketBadge`.

Falsifiers:

- `F-VaultRecall-50`: passed in the resumed verification run using the explicit
  local stable Rust toolchain selector.
- W-23 rg gate: passed; chat retrieval surfaces did not regress to index-order
  `LIMIT N` context construction.

## Verify

Completed in the resumed pass:

- Focused Xcode tests:
  `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath build/derived-data-terminal-b -only-testing:EpistemosTests/AnswerPacketBadgeTests -only-testing:EpistemosTests/VaultRecallWiringTests CODE_SIGNING_ALLOWED=NO`
  passed.
  - Swift Testing reported 10 tests passed across
    `AnswerPacketBadgeTests` and `VaultRecallWiringTests`.
  - XCTest also reported 0 selected XCTest failures.
- W-23 gate:
  `bash scripts/check-vault-context-contract.sh` passed with
  "Vault context contract OK".
- F-VaultRecall-50:
  `cargo +stable-aarch64-apple-darwin test --manifest-path agent_core/Cargo.toml --test f_vault_recall_50 -- --nocapture`
  passed.
  - `canonical_chatty_prefix_row_passes_with_fix_b_trace`
  - `summary_aggregates_run_all_outcomes_for_w21_diagnostics`
  - `f_vault_recall_50_canonical_rows_against_seeded_vault`

Earlier stopped attempts:

- First attempt failed on a shared DerivedData build database lock.
- Second attempt failed on `EventStore.appendVaultRecallTrace` actor isolation;
  patched before this resumed pass.
- Third attempt failed on a missing `vaultRecallTrace` argument in
  `MiniChatView`; patched before this resumed pass.
- Resumed attempt initially exposed Terminal A gate isolation:
  `EidosBridge.validateCitations(packet:sourceIds:)` was main-actor isolated
  under `-default-isolation=MainActor` while the chat gate is intentionally
  nonisolated. This pass fixed the bridge by marking the batch validator
  `nonisolated`.

Remaining caveat:

- Terminal A's Eidos bridge is now present on `main`, and this pass fixed the
  batch validator isolation needed by the chat citation gate. The focused tests
  did not exercise a full live chat closed-citation emit path.

## Harden

Hardened against the original "first 7 irrelevant notes" failure by adding a
prod-path rg gate and by making provenance visible even when packets/traces are
missing. The UI now says "pending", "stub", "approximate", or "blocked" where
that is the honest state.
