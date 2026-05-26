# Chat Citation UI Integration Audit - 2026-05-24

Terminal: Phase 2 Terminal B, Chat Citation UI Integration.

Branch: `phase2-terminal-b-prime-chat-citations-2026-05-24`.

## Scope

This pass was limited to wiring existing answer-packet and vault-recall provenance surfaces into chat rows, W-20 autocomplete, W-20 Halo recall surfaces, coordinator trace capture, and the CI vault-context contract gate.

Terminal B touched:

- `.github/workflows/ci.yml`
- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/Models/ChatTypes.swift`
- `Epistemos/Models/SDMessage.swift`
- `Epistemos/State/ChatState.swift`
- `Epistemos/State/EventStore.swift`
- `Epistemos/Views/Chat/MessageBubble.swift`
- `Epistemos/Views/Chat/NotesMentionDropdown.swift`
- `Epistemos/Views/Chat/VaultRecallProvenanceCard.swift`
- `Epistemos/Views/Halo/ShadowPanelContent.swift`
- `docs/audits/CHAT_CITATION_UI_INTEGRATION_2026_05_24.md`

W-21 was audited only. `VaultRecallHealthRow` was not flipped green and remains governed by its trace-scaffold path until F-VaultRecall-50 has real measurements.

## Audit

The existing `AnswerPacketBadge` and `VaultRecallProvenanceCard` components were present but were not mounted in the per-row assistant chat rendering path. `MessageBubble` was the row render point.

Vault recall provenance existed in retrieval-adjacent surfaces, but assistant rows did not carry a stable row-local trace. Without row residency, a user could not inspect whether an answer was produced from explicit note context, vault-wide recall, attached context, or no vault retrieval.

The W-23 script existed at `scripts/check-vault-context-contract.sh`, but CI did not run it.

## Build

`MessageBubble` now renders a visible provenance surface for every assistant answer row:

- `AnswerPacketBadge` is mounted inline for assistant rows.
- `VaultRecallProvenanceCard` is mounted in an expandable row-local disclosure.
- Rows without vault retrieval still render an explicit provenance card state rather than silently omitting provenance.

Trace residency was extended through the chat stack:

- `ChatMessage` carries `vaultRecallTrace`.
- `SDMessage` persists an encoded `VaultRecallTrace` snapshot.
- `ChatState` keeps the current pending trace and stamps completed assistant messages.
- `EventStore` can append a `vault_recall_trace` event payload with session, message, answer-packet, and trace data.
- `VaultRecallTraceSink` keeps a bounded live lookup keyed by message id and answer-packet id for row hydration.

`ChatCoordinator` now records vault recall traces for explicit note context, vault-wide fallback, attached-note context, and indexed fallback paths. On answer completion it records the trace into the live sink and into `EventStore` when available.

W-20 surfaces were extended with the same provenance-card pattern:

- `NotesMentionDropdown` shows vault-recall candidate chips for all-notes and note candidate rows.
- `ShadowPanelContent` uses a vault-recall provenance strip for Halo recall rows.

CI now runs:

```bash
bash scripts/check-vault-context-contract.sh
```

early in `.github/workflows/ci.yml`.

## Verify

W-23 gate:

```bash
bash scripts/check-vault-context-contract.sh
```

Result:

```text
Vault context contract OK: no LIMIT/first-notes context construction in chat retrieval surfaces.
```

Scoped retrieval scan across Terminal B chat and Halo surfaces found no `LIMIT N` or `first ... notes` retrieval construction hits.

App-target build:

```bash
./scripts/xcodebuild_epistemos.sh build -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath build/derived-data-terminal-b-prime CODE_SIGNING_ALLOWED=NO
```

Result:

```text
** BUILD SUCCEEDED **
```

Cargo:

```bash
cargo test --manifest-path agent_core/Cargo.toml --lib --quiet
```

Result:

```text
4004 passed; 0 failed
```

Targeted Xcode command:

```bash
./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath build/derived-data-terminal-b-prime -only-testing:EpistemosTests/ChatPresentationTests -only-testing:EpistemosTests/ChatCoordinatorPersistenceTests -only-testing:EpistemosTests/VaultRecallWiringTests CODE_SIGNING_ALLOWED=NO
```

Result:

- The app target and focused test bundle compiled after the provenance-card getter fix.
- XCTest did not establish its app-hosted runner connection:
  `Epistemos (29145) encountered an error (The test runner hung before establishing connection.)`
- Xcode result: `build/xcode-results/2026-05-25-184008-78103.xcresult`
- A focused `test-without-building` retry for `EpistemosTests/ChatPresentationTests` reached the same runner-connection hang and was interrupted.
- Retry result: `build/xcode-results/terminal-b-prime-chatpresentation-retry.xcresult`

No Terminal B source file was added outside the existing project structure. The repo-wide orphan report remains noisy against the current project layout, but the Xcode compile logs show the touched Terminal B app sources are included in the app target. The only new Terminal B file is this audit document.

## Harden

The row provenance path is tolerant of partial data:

- Missing answer-packet ids still render the badge component.
- Missing vault traces render an explicit no-vault or unavailable provenance card state.
- The live sink is bounded to 64 traces.
- Persisted `SDMessage` snapshots keep provenance available after restore.
- EventStore appends provide a durable witness event for completed turns.

The implementation did not introduce index-order `LIMIT N` chat context construction. The CI gate enforces this.

## 7-Law Check

1. Density: assistant rows now carry compact provenance without replacing the answer body.
2. Address: traces are keyed by chat/session id, message id, and answer-packet id.
3. Active support: only the active row trace and a bounded recent trace sink are held live.
4. Lattice/error: absent or scaffold trace data is rendered as unavailable or no-vault provenance, not as a green health claim.
5. Glue: retrieval motion flows through `ChatCoordinator` to `ChatState`, `ChatMessage`, `SDMessage`, `EventStore`, and row UI.
6. Duplex: live UI hydration and persisted row snapshots both carry the trace.
7. Witness: badge/card UI, `vault_recall_trace` events, persisted snapshots, and the W-23 CI gate are falsifiable witnesses.

## PR No-Orphan Check

Project / Compress / Recall motion is now visible in the chat row instead of ending at retrieval context construction.

- Project: vault recall traces are projected from retrieval paths into the active chat turn.
- Compress: the trace is compacted into `VaultRecallTrace` and answer-packet row metadata.
- Recall: row UI, autocomplete, and Halo surfaces expose the recall provenance back to the user.

No new Swift source file was introduced. Existing modified Swift files compiled into the app target during the targeted Xcode run. The new audit document is intentionally outside the Xcode target.

Rollback path: remove the `MessageBubble` provenance disclosure, drop the `vaultRecallTrace` fields from row/state persistence, remove the EventStore event helper, and remove the CI step. The W-23 script itself was not changed.

## Limitations

This pass records `VaultRecallTrace` through `EventStore` using a `vault_recall_trace` event payload and through row-local chat metadata. It does not modify a canonical Swift `RunEventLog` enum variant in this branch. If Terminal A adds or has added a dedicated `RunEventLog.append(VaultRecallTrace)` API in a separate file, this row wiring can be bridged to that API without changing the visible row contract.

The targeted test command remains blocked by the app-hosted XCTest runner hanging before establishing its connection. The app target and focused test bundle compile, and the standalone app build succeeds.

## Second-Pass Audit

Follow-up audit on the same branch checked:

- `MessageBubble` provenance placement is inside `assistantBubble`; user rows and error bubbles do not receive assistant provenance chrome.
- `AnswerPacketBadge` renders visible speculative/blocked chips even when `answerPacketId` is missing.
- `VaultRecallProvenanceCard` renders explicit no-vault or trace-unavailable states when no trace is attached.
- `currentVaultRecallTrace` is reset on new chat, streaming metadata consumption, no-context query paths, and clear-chat cleanup.
- `ChatCoordinator` records completed-row traces into `VaultRecallTraceSink` and `EventStore`.
- `ChatCoordinator` no longer asks `VaultRecallBridge.trace(query:)` for row provenance; row traces are built from the actual referenced, matched, attached, briefing, or indexed vault candidates with ladder tier `vault-chat-context-v1`.
- `VaultRecallProvenanceCard` distinguishes no retrieval, unavailable trace, scaffold trace, real trace, and zero-candidate retrieval without inflating `0/0` retained counts.
- The row `real path` chip reports provenance origin only. W-21 health remains gated by measured benchmark data, so production trace presence does not become a green benchmark claim.
- `.github/workflows/ci.yml` runs the W-23 vault-context contract gate.
- `bash scripts/check-vault-context-contract.sh` still passes after the audit doc update.

Repo-wide `xcode_orphan_report.py` remains noisy against the current Xcode project layout and reports many files that the successful app build compiled. No new Swift source file was added by this pass; the only new file is this audit document.
