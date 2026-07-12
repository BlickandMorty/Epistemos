# Test, Fixture, and Acceptance Matrix

PREPARATION ONLY — subordinate to the July 8 MAS master canon. This document does not change the active execution key or prove implementation.

No test code is written here. These are exact proposed names, fixtures,
assertions, and target files, in batch order. Conventions: Swift Testing
(`@Test` + `#expect`), no `try!`, background-actor-safe fixtures; Rust tests
in `#[cfg(test)]` modules (remember: only `cargo test` compiles them);
proposed js-editor tests contingent on the bundle's test runner (verify
`js-editor/package.json` at implementation time).

## Shared fixtures (define once, reuse)

| Fixture | Contents | Consumers |
|---|---|---|
| `RichMarkdownFixture` | YAML frontmatter (incl. unusual keys), tables, blockquotes, nested lists, links, wikilinks, inline+block math, unknown fenced directive, plus an intentionally-empty variant (mirrors KEELSTONE runtime item 4) | T-LL-2/3/4, T-J2-2 |
| `TmpVaultFixture` | temp-dir vault with `notes/`, `chats/`, Quick Capture folder; no security scope needed in tests | T-J2-*, T-RK-1..4, T-CR-2/3/4 |
| `SuggestionJSONFixture` | assistant-reply JSON matching `JuneEpdocAssistNoteSuggestionParser` shape: current-selection match, stale-selection, blind (no selection) variants | T-J1-1, T-J2-1/2 |
| `DatasetCSVFixture` | small CSV + `.dataset.md` sidecar with dataset ID + one formula column definition | T-RK-1..6, T-CR-4 |
| `ConsentStateFixture` | June cloud-consent preference absent / granted-provider-A / revoked states | T-J3-1, T-CR-5 |

## JUNE / MiniChat (`EPISTEMOS-MAS-JUNE-MINICHAT-INTEGRATOR-2026-07-08`)

| ID | Proposed test (exact name) | Target file | Fixture | Key assertions |
|---|---|---|---|---|
| T-J0-1 | `@Test("parked-name scan exceptions are enumerated and justified")` | `EpistemosTests/AppStoreJuneSourceGuard.swift` | none (reads source + the adjudicated exception ledger) | evidence-first (owner correction 2026-07-11): every parked-name identifier on the active June lane is either renamed (because the current artifact gate failed on it) or listed in a justification ledger this test enforces; the ledger may not drift from source reality |
| T-J1-1 | `@Test("June Epdoc assist sessions are explicit child sessions linked to note and ledger")` | `EpistemosTests/AppStoreJuneSubstrateHardeningTests.swift` | in-memory `JuneSessionStore` + `SuggestionJSONFixture` | assist submit creates/reuses a session carrying parent/origin note identity; ledger row references (sessionID, noteID, turnID); no second store touched |
| T-J2-1 | `@Test("assist suggestion apply requires approval and routes through the vault writer")` | `EpistemosTests/EpdocCopilotSurfaceTests.swift` | `TmpVaultFixture` + parsed suggestion | apply without approval → refused; approved apply → exactly one vault-writer invocation (spy/DI seam), ledger event contains applied-artifact hash + undo reference |
| T-J2-2 | `@Test("denied assist suggestion leaves the note byte-identical")` | `EpistemosTests/EpdocCopilotSurfaceTests.swift` | `RichMarkdownFixture` in `TmpVaultFixture` | note bytes identical pre/post; suggestion accept state = rejected; zero vault-writer calls |
| T-J3-1 | `@Test("assist cloud turns inherit the June consent blocker")` | `EpistemosTests/AppStoreJuneSubstrateHardeningTests.swift` | `ConsentStateFixture` (absent) | submission surfaces the visible consent blocker; no provider request object constructed; granting consent for provider A does not unblock provider B |

## LUMENLENS (batches LL-1..3 of `EPISTEMOS-MAS-LUMENLENS-RECKONER-WORKSPACE-2026-07-08`)

| ID | Proposed test | Target file | Fixture | Key assertions |
|---|---|---|---|---|
| T-LL-1 | `stale epoch transactions are rejected after a new load begins` | `js-editor/src/bridge/__tests__/document-load-state.test.ts` (runner presence to verify) | scripted load-epoch bump + queued stale transaction | stale transaction dropped; no outbound markdown emit; fresh-epoch transaction passes |
| T-LL-2 | `@Test("frontmatter survives byte-identical through the four-lens round trip")` | `EpistemosAppStoreKeelstoneTests/MarkdownDocumentLensSwitchTests.swift` | `RichMarkdownFixture` | frontmatter block byte-equal after Epdoc→Source→Prose→Epdoc; body semantic-equal per tier rules |
| T-LL-3 | `@Test("Tier-C unknown content is preserved byte-identical and disclosed")` | `EpistemosAppStoreKeelstoneTests/MarkdownDocumentLensSwitchTests.swift` | unknown fenced directive from `RichMarkdownFixture` | `QuarantineArchive` entry captured; `LensFidelityDisclosure.items` lists it; serialized output byte-identical |
| T-LL-4 | `@Test("one-paragraph edit produces a single minimal writeback region")` | `EpistemosTests/EditorProvenanceStoreTests.swift` | 3-paragraph doc, middle edited | writeback regions count == 1; untouched paragraphs byte-identical (extends existing :177 apply test with minimality assertion) |
| T-LL-5 | `@Test("two windows cannot silently clobber the same note")` | `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift` | two `NoteSessionStateMachine` sessions on one manifestID | second writer lands in conflict/lease-handoff path; no silent overwrite; both buffers recoverable |
| T-LL-6a | Rust: `suggestion_projection_round_trips_editor_store_fields` | `agent_core/src/provenance/suggestion_schema.rs` `#[cfg(test)]` | serde JSON fixture mirroring `EditorProvenanceStore` row | prose-span row ↔ `Suggestion` mapping lossless; unmapped fields enumerated, not dropped silently |
| T-LL-6b | `@Test("editor provenance rows project onto the canonical Rust suggestion schema")` | `EpistemosTests/EditorProvenanceStoreTests.swift` | same JSON fixture | Swift row → canonical schema → Swift row round trip; accept-state transitions preserved |

## RECKONER (batches RK-1..7)

| ID | Proposed test | Target file | Fixture | Key assertions |
|---|---|---|---|---|
| T-RK-1 | `@Test("dataset artifact writes are atomic and rebuild-equivalent")` | new `EpistemosTests/ReckonerDatasetArtifactTests.swift` | `DatasetCSVFixture` in `TmpVaultFixture` | writes go through the vault-writer seam; deleting the GRDB dataset cache then rebuilding reproduces identical values (canon 04 rebuild-equivalence) |
| T-RK-2 | `@Test("opening a dataset emits zero autosave or change events")` | `EpistemosTests/ReckonerDatasetArtifactTests.swift` | dataset tab mount + event recorder | zero mutation/autosave events during load + render (canon 06 acceptance) |
| T-RK-3 | `@Test("the renderer never persists computed values")` | `EpistemosTests/ReckonerDatasetArtifactTests.swift` | formula column fixture | artifact bytes unchanged after render+recalc display; persisted values only via calc-authority write path |
| T-RK-4 | `@Test("dataset embeds serialize references only, never cell data")` | `EpistemosTests/ReckonerDatasetArtifactTests.swift` | note embedding `DatasetCSVFixture` | embed markdown contains dataset ID/path reference; contains no cell value strings from the fixture |
| T-RK-5 | `@Test("tabular suggestions stage as pending and cannot apply without approval")` | `EpistemosTests/ReckonerDatasetArtifactTests.swift` (+ existing Rust `requires_approval` coverage) | `TabularRange` suggestion via unified schema | staged suggestion visible; direct apply refused; approved apply mutates artifact + ledger row with hash |
| T-RK-6 | `@Test("chart render requires an existing provenance row")` | `EpistemosTests/ReckonerDatasetArtifactTests.swift` | chart request fixture | render without provenance row → refused; with row → allowed (canon 06 "chart has provenance before render") |
| T-RK-7 | `@Test("no data room or dataset chat surface exists")` | `EpistemosTests/AppStoreJuneSourceGuard.swift` | none (source scan) | no dataset-scoped chat view/route; dataset tabs mount inside the existing workspace tab system |

## Capability Ring (batches CR-1..7)

| ID | Proposed test | Target file | Fixture | Key assertions |
|---|---|---|---|---|
| T-CR-1a | `@Test("arXiv requests stay on allowlisted hosts and respect spacing")` | new `EpistemosTests/ArxivAdapterPolicyTests.swift` | canned queries | only `arxiv.org`/`export.arxiv.org` URLs constructed; rapid-fire calls spaced by the limiter |
| T-CR-1b | `@Test("the arXiv adapter record is complete")` | `EpistemosTests/ArxivAdapterPolicyTests.swift` | adapter record struct | attribution rule, cache/purge rule, terms note, privacy note, feature flag all non-empty (canon 07 six-part rule) |
| T-CR-2 | `@Test("quick capture persists through the vault sync write path with durable identity")` | `EpistemosTests/QuickCapturePipelineTests.swift` (new) | `TmpVaultFixture` | exercises the EXISTING `vaultSync.createPage` route (corrected 2026-07-11 — no rewrite presumed): vault-backed Markdown exists after capture; capture `traceID`/`mutationID`/`noteID` linkage recorded; route-journal/op-log row asserted once linkage lands |
| T-CR-3 | `@Test("capture enrichment failure never blocks the durable save")` | `EpistemosTests/QuickCapturePipelineTests.swift` | enrichment stub that throws | raw capture file exists with submitted text despite enrichment error; error surfaced non-fatally |
| T-CR-4 | `@Test("research items save as vault notes with source and canonical IDs")` | `EpistemosTests/ResearchHubItemTests.swift` (new) | fake adapter result (DOI + arXiv ID) | saved note frontmatter carries source ID, canonical URL/DOI, vault ID; derived index row rebuildable |
| T-CR-5 | `@Test("mic capture requires readiness and shows recording state")` | `EpistemosTests/QuickCapturePipelineTests.swift` | `ConsentStateFixture` | capture refuses without readiness; recording-state flag observable while active (visual proof stays a runtime item) |
| T-CR-6 | `@Test("browser-lite is WebKit-only with the content blocker installed")` | `EpistemosTests/AppStoreJuneSourceGuard.swift` | none | browser surface config uses WKWebView; `BrowserTrackerContentBlocker` installed; no automation entry points reachable |
| T-CR-7 | `@Test("only gate-passed skills surface in June and drafts stay hidden")` | `EpistemosTests/AppStoreJuneSubstrateHardeningTests.swift` | skill catalog fixture (draft + gate-passed) | June skill listing includes gate-passed only; drafts/NightBrain queue not exposed to the webview |

## Acceptance ↔ runtime split

Everything above is automatable. The paired manual/runtime evidence per phase
(exact archive, consent screenshots, kill -9 soak, audible voice, provider
turns) is listed in each packet §8–9 and remains REQUIRED — tests alone never
satisfy a canon done bar (canon 02 Phase 6; ARCHITECTURE_TIER_PROMOTION rule
that L1/source proof is not green).
