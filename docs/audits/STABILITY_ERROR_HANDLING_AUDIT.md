# Stability + Error Handling Audit

Date: 2026-04-28

Verdict: Most core surfaces have explicit code paths, but several V1 candidates still fail silently or rely on component tests instead of user-path recovery tests. P0 risk is low in the docs-only pass; P1 risk remains around `.epdoc`, recall, Raw Thoughts, and code-editor large-file behavior.

## Required Risk Table

| Risk | File | Failure mode | User-facing behavior today | Required behavior | Priority |
|---|---|---|---|---|---:|
| Missing or corrupt recall index | `Epistemos/KnowledgeFusion/InstantRecallService.swift`; `Epistemos/State/ContextualShadowsState.swift` | Search returns empty or async task fails | Likely silent no-button/no-results | Show disabled/missing-index state in panel or keep button hidden with recoverable log | P1 |
| Sync recall rebuild called from UI path | `InstantRecallService.rebuildIndex(notes:)` | MainActor stall | Typing/launch hitch on large vault | Async rebuild only; DEBUG catches sync call | P1 |
| `.epdoc` projection corruption | `Epistemos/Engine/EpdocDocument.swift`; `Epistemos/Models/EpdocPackage.swift`; `Epistemos/Sync/ReadableBlocksProjector.swift` | `shadow.md`, `plain.txt`, or `search_blocks.jsonl` missing/corrupt | Code/test proof now regenerates projections and preserves canonical JSON; live UI smoke remains deferred | Regenerate projections from canonical `content.pm.json`; never overwrite canonical from shadow silently | P1 |
| `.epdoc` WebView asset missing | `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`; build scripts/assets | Rich editor canvas may load blank | User sees broken document editor | Empty/error state with fallback to package metadata; build test verifies assets | P1 |
| Raw Thoughts malformed manifest/event line | `agent_core/src/storage/raw_thoughts.rs`; `Epistemos/Views/RawThoughts/RawThoughtsInspectorView.swift` | Scan skips or decode fails | Component proof now keeps valid prior JSONL lines and exposes the partial line for inspection; live browse smoke remains deferred | Keep partial-line recovery test green and add runtime run-browse smoke before default-on | P1 |
| Provider reasoning replay byte identity | `agent_core/src/storage/raw_thoughts.rs`; `agent_core/src/agent_loop.rs`; `agent_core/src/providers/claude.rs` | Anthropic thinking/redacted payload mutated | Storage/provider tests preserve opaque payload bytes; live replay is not smoked | Store opaque payload/signature byte-identically; test round trip; add live replay smoke if replay ships | P0 if replay enabled, P1 otherwise |
| Computer-use surfaces in MAS | `Epistemos/AppStore/AppStoreComputerUseStubs.swift`; `Epistemos/Omega/Vision/ScreenCaptureService.swift` | MAS rejects or permission dead-end | Stubbed in MAS, direct build only | Keep hidden in MAS and test compile-time profile | P0 |
| SpeechAnalyzer live audio format / tap isolation | `Epistemos/Engine/EpistemosSpeechAnalyzer.swift`; `Epistemos/Views/Shared/VoiceInputButton.swift` | Speech.framework trap during live dictation start, raw-buffer analysis, or Swift concurrency isolation check from the audio tap callback | Fresh Apr 29 reports showed `EXC_BREAKPOINT`/`SIGTRAP` in `EpistemosSpeechAnalyzer.startLive`; Patch 47 prepares the analyzer in the best compatible format, converts mic buffers, and shows an unavailable-format error if setup fails. Patch 48 removes MainActor instance access from the AVAudio tap closure. Runtime mic smoke remains deferred | Keep source/policy tests green; run live mic permission/device smoke before shipping dictation default-on | P0 until runtime-smoked, P1 after |
| Code editor Unicode range conversion | `Epistemos/Views/Notes/CodeEditorView.swift`; `SwiftTreeSitterLiveHighlighter.swift` | Wrong highlight range or crash | Component tests now cover Unicode-safe chunk prep; live editor p95 still unmeasured | UTF-8/UTF-16 conversion tests plus runtime large-file smoke | P1 |
| Large code file open | `CodeEditorView.swift` | Whole-string operations become slow | Jank/freezing at 4k+ lines possible | Size guard, visible-range work, and benchmark | P1 |
| Settings copy drift | `Epistemos/Views/Settings/SettingsView.swift`; privacy tests | MAS privacy/cloud wording overclaims | User/App Review confusion | Tests verify exact categories and PrivacyInfo alignment | P0 |
| App bootstrap optional services | `Epistemos/App/AppBootstrap.swift` | Optional service init fails | Crash or missing UI state if force-required | Optional systems degrade with logged disabled state | P1 |
| Search projection write failure | `ReadableBlocksIndex.swift`; `SearchIndexService.swift` | Index stale after save | Search misses artifact/block | Rebuildable projection plus visible rebuild state | P1 |

## Crash / Stub Patterns To Keep Watching

- `fatalError("init(coder:) has not been implemented")` is acceptable only for programmatic AppKit views that cannot load from storyboards.
- `bindingsUnavailable` or placeholder stubs must not be reachable from production UI.
- `try?` on user-data writes is unacceptable unless paired with visible recovery or retry.
- Silent `catch {}` on file, database, model, or bridge paths is a P1 until justified.

## Startup Checks

- App startup must not require models, embeddings, graph index, Raw Thoughts, or `.epdoc` projections to be present.
- Missing optional indexes should log and rebuild in background.
- Corrupt projection files must be treated as rebuildable, not app-bricking.
- Corrupt canonical files must stop the write path and show a recoverable error.

## Required New Tests

| Test | Purpose |
|---|---|
| `ContextualShadowsUnavailableTests` | missing index/disabled flag does not crash or show stale results |
| Raw Thoughts live run-link smoke | storage/recovery proof reaches user-browsable run UI |
| Raw Thoughts high-rate stream test | streaming does not create per-token SwiftUI churn or unbounded growth |
| `EpdocProjectionRecoveryTests` | missing/corrupt projection regenerates from canonical body |
| `CodeEditorUnicodeRangeTests` | syntax spans map safely across emoji/CJK text |
| `SettingsPrivacyCopyDriftTests` | visible Settings categories and copy stay MAS-exact |

## Severity Summary

- P0: MAS computer-use hiding, provider reasoning byte preservation if replay path is enabled, privacy copy exactness.
- P1: recall recovery, `.epdoc` projection recovery, Raw Thoughts live browse/streaming proof, code-editor Unicode/large-file behavior.
- P2: better empty-state copy and logs for optional systems.
