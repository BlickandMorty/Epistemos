# Capability Ring Implementation Packet

PREPARATION ONLY — subordinate to the July 8 MAS master canon. This document does not change the active execution key or prove implementation.

Execution ID prepared for: `EPISTEMOS-MAS-CAPABILITY-RING-2026-07-08`
Canon sources: 07_CAPABILITY_RING_RESEARCH_CAPTURE_SYNC.md, 03 Prompt 5, 08.
Gate: requires KEELSTONE + June/MiniChat seams; individual features also
depend on LUMENLENS/RECKONER only where noted.

## 0. The one tool surface this ring extends

`Epistemos/JuneAgent/JuneMASToolPolicy.swift` is the single Swift authority.
Current allowlist (read 2026-07-11): `vault.search`, `vault.read`,
`vault.write`, `vault.list`, `pdf.to_markdown`, `knowledge.recall`,
`web.search`, `web.fetch`, `http_fetch`, `think`. Forbidden fragments:
bash/browser/chromium/cli/code_exec/computer/delegate/goose_runtime/localhost/
mcp/process/shell/stdio/subprocess/terminal + an obfuscated byte-matcher for
"docker". Every capability-ring agent tool is a delta to THIS list plus a
`agent_core/src/tools/*` registration — never a side channel.

## 1. Requirements → source map + classification

### 1.1 ResearchHub / LODESTAR

| Requirement (canon 07) | Current source | Classification |
|---|---|---|
| Official APIs / RSS / OA / BYO only; forbidden list (Sci-Hub, LibGen, Scholar scraping, "find any PDF", …) | policy only in canon | policy: EXISTING (doc); enforcement: MISSING (no ResearchHub module exists) |
| arXiv adapter | `Epistemos/Arxiv/ArxivClient.swift` — host allowlist (`arxiv.org`/`export.arxiv.org` only), canonical-ID/PDF path checks, request spacing rate limiter, safe error copy; `ArxivIngestService.swift`; env gate `ArxivPullGateStatus.swift`; UI `Views/Arxiv/ArxivSearchView.swift` | PARTIALLY IMPLEMENTED — adapter core EXISTING; missing per canon adapter rule: recorded attribution rule, cache/purge rule, privacy note, App Review note |
| Crossref / OpenAlex / Unpaywall / PubMed / Semantic Scholar / CORE / DOAJ / EuropePMC / OSF adapters | none | MISSING; each ships only with the six-part adapter record (official URL, terms/rate, attribution, cache/purge, privacy, flag) |
| BYO-token sources (GitHub/Zotero/Readwise/Mastodon/Bluesky/X/Reddit) | Keychain machinery exists (`Engine/Keychain.swift`) | MISSING (adapters); Keychain lane EXISTING |
| RSS/Atom lane | no feed parser found | MISSING |
| Saved items: source ID + canonical URL/DOI + vault ID | vault save paths exist; ResearchHub item schema absent | MISSING; depends on KEELSTONE stable-ID layer |
| Retention/purge job + App Review notes | none | MISSING |

v1 provider subset is a canon-09 OWNER DECISION — prepare adapters as
independent flags; do not hardcode a bundle.

### 1.2 Quick Capture / EMBERCATCH

| Requirement | Current source | Classification |
|---|---|---|
| Zero-loss ingress; survives quit/crash | `Views/Capture/QuickCaptureView.swift` (confirmation card, read-back `QuickCaptureReadBack`, preview signals, task extraction), `Engine/TextCapturePipeline.swift` | PARTIALLY IMPLEMENTED; crash-survival evidence = REQUIRES RUNTIME EVIDENCE (canon 08 soak: "Quick Capture crash mid-record/save") |
| Writes through KEELSTONE | CORRECTED 2026-07-11 — the line-15 header comment is stale. Current persistence: `TextCapturePipeline.swift:779` → `bootstrap.vaultSync.createPage(...)`; `VaultSyncService.createPage` (:4696) creates the `SDPage` AND exports vault-backed Markdown through the current vault/index write path | EXISTING VAULT-BACKED ROUTE AT SOURCE LEVEL + RUNTIME CRASH/RESTORE/PROVENANCE EVIDENCE PENDING. No source-route rewrite unless a later test proves one necessary |
| Voice capture consent + visible recording indication | audio-input entitlement present; `Engine/LiveVoiceInputService.swift`, `EpistemosSpeechAnalyzer.swift`; bridge case `check_recording_source_readiness` | PARTIALLY IMPLEMENTED + REQUIRES RUNTIME EVIDENCE (visible-indicator proof) |
| Enrichment never blocks durable save; promotion preserves provenance | preview-signal design suggests non-blocking; unverified | REQUIRES RUNTIME EVIDENCE + proposed test T-CR-3 |

### 1.3 Sync

| Requirement | Current source | Classification |
|---|---|---|
| Subordinate to KEELSTONE; no parallel reconciler | `Sync/VaultSyncService.swift` is the one reconciler | EXISTING AND REUSABLE |
| iCloud placeholder/dehydration handling | `Sync/iCloudMaterializer.swift` (NSMetadataQuery ubiquitous status, `startDownloadingUbiquitousItem`, `evictUbiquitousItem`) | EXISTING AND REUSABLE |
| Conflicts visible; no silent last-writer-wins for dirty work | conflict owners exist (`VaultSyncService`, `NoteDetailWorkspaceView`, `ProseEditorView`) | PARTIALLY IMPLEMENTED — dirty-conflict UX is the KEELSTONE done-bar item; REQUIRES KEELSTONE |
| `.epcache` local/derived | `.epcache` pattern established (shadow index at `<vault>/.epcache/shadow`) | EXISTING |

### 1.4 Plan 3 capabilities

| Capability | Current source | Classification |
|---|---|---|
| PDF | `LiteParse/` (import controller, `SourcePDFViewer` w/ PDFKit); MAS tool `pdf.to_markdown` root-confined + allowlisted (test `AppStoreJuneSubstrateHardeningTests:1134`) | EXISTING AND REUSABLE |
| Vision/OCR | `Views/Shared/LiveTextImageView.swift`, `Views/Notes/NoteImageProcessor.swift` (Apple Live Text) | EXISTING; consent/privacy disclosure pass pending |
| Speech/STT | `Engine/EpistemosSpeechAnalyzer.swift`, `LiveVoiceInputService.swift`; dictation bridge cases (`list_dictation_history`, `dictation_settings`, `dictation_hotkey_status`) | EXISTING; consent/recording-state evidence pending |
| TTS (adjacent) | `VoicePro/KokoroCoreMLSynthesizer.swift` + voice download hardening (HEAD commit) | EXISTING; English-audible proof is a KEELSTONE runtime item |
| Browser-lite (WebKit only) | `Engine/BrowserCapabilityStatus.swift`, `Engine/BrowserTrackerContentBlocker.swift` (content blocker), WKWebView surfaces | PARTIALLY IMPLEMENTED — scope/verify at phase; automation lanes stay parked |
| Skills as user-approved procedural records (no code exec) | Rust `agent_core/src/skill_discovery/mod.rs`, `nightbrain/live.rs`; Swift `Vault/SkillVaultFileIO.swift`, `SkillDiscoveryCatalog.swift`; observable-composition allowlist in `JuneMASToolPolicy` | PARTIALLY IMPLEMENTED (read-only surface + gates per june-skill-learning-loop doctrine) |

### 1.5 Obscura split (canon 07)

Keep the WKWebView browser surface (potentially MAS-safe, content blocker
already present); the automation/browser-use/Chromium/CDP lane stays parked.
`agent_core/src/tools/browser*.rs` remain forbidden by allowlist fragments
("browser") — no capability-ring feature may rename around that.

## 2. Provider legality table (to finalize with official sources at phase)

Verbatim policy: canon 07 table (arXiv/Crossref/OpenAlex/Unpaywall/NCBI/
Semantic Scholar/CORE/DOAJ/EuropePMC/OSF/bioRxiv = SAFE WITH CONDITIONS;
GitHub/Zotero/Readwise/Mastodon/Bluesky/X/Reddit = BYO/official only;
OpenLibrary/InternetArchive/Gutendex = SAFE WITH CONDITIONS; publisher RSS =
headlines/links only; Elsevier/Scopus/IEEE/Lens = PARK unless licensed).
Official-source URLs are enumerated in canon 08 §source spine — every adapter
re-validates terms there before shipping; record date + terms hash in the
adapter record.

## 3. Storage dependencies

- ResearchHub saved items + media → vault artifacts via `AtomicVaultWriter`;
  retention/purge job must operate on artifacts + derived rows only.
- Capture already routes through `VaultSyncService.createPage` at source
  level (corrected 2026-07-11); what remains is runtime crash/restore/
  provenance evidence and route-journal linkage — not a route rewrite.
- All ring features subscribe to `VaultSyncService` events; none adds a
  watcher.
- Stable-ID carriers already exist (capture `traceID`/`mutationID`/`noteID`,
  frontmatter `id`, `_epdoc_id`); ResearchHub source ID + vault ID are
  defined when ResearchHub is implemented. No new global ID framework unless
  survival tests prove the current contracts insufficient.

## 4. Duplicate-authority traps specific to this ID

1. ResearchHub item DB as a second truth → items are vault notes/artifacts +
   derived index rows.
2. A capture inbox store → captures are vault files in the Quick Capture
   folder from the first byte.
3. Per-adapter HTTP stacks with their own credential storage → Keychain +
   one client pattern (`ArxivClient` shape) per adapter.
4. A second consent framework for mic/recording → reuse the June consent +
   entitlement surface; one visible-recording indicator system.
5. Skills executing code → skills stay procedural records; execution remains
   tool calls through the one registry.

## 5. Smallest implementation batches (dependency order)

- **CR-1 — arXiv adapter completion (smallest, KEELSTONE-independent):**
  attribution rule, cache/purge rule, privacy/App Review note, flag record.
  Touches: `Epistemos/Arxiv/*`, docs. No new lanes.
- **CR-2 — capture runtime-evidence pass (corrected 2026-07-11):** zero-loss,
  crash (kill -9 mid-save), restore, and enrichment-failure evidence on the
  EXISTING `vaultSync.createPage` route, plus route-journal/provenance
  linkage. Source changes only if a failing focused test proves a canonical
  defect (owner correction 5 rule).
- **CR-3 — sync coexistence hardening:** placeholder + conflict acceptance
  tests on `iCloudMaterializer`/`VaultSyncService`; no new code expected.
- **CR-4 — ResearchHub v1 skeleton:** item schema (vault note + frontmatter
  IDs), one adapter (arXiv reuse) through June tool registration
  (`research.search`/`research.save` names must pass
  `JuneMASToolPolicy.isMASPermittedAgentToolName`), retention/purge job.
  OWNER DECISION on provider subset before more adapters.
- **CR-5 — speech/vision/PDF consent+evidence pass:** visible recording
  state, privacy-manifest deltas, App Review notes.
- **CR-6 — browser-lite scope guard:** WebKit-only assertion tests; content
  blocker defaults; no automation entry points.
- **CR-7 — skills read-only surface:** gate-passed skills visible in June;
  no auto-promotion; NightBrain review queue stays native.

## 6. External facts requiring later official-source validation

Every provider's current API terms/rate limits (canon 08 URL spine); Apple
consent/recording-indication rules (App Review Guidelines current text);
privacy-manifest required-reason deltas for Speech/AVAudio/Vision additions;
X/Reddit API commercial-terms volatility (highest-risk BYO lanes — recheck at
adapter time, likeliest to be PARKED).

## 7. Older research: salvage vs reject

- SALVAGE as spec appendix: `RESEARCHHUB_SOURCE_DOSSIER` (open-CC + BYO lane
  analysis, OA chain DOI→Unpaywall→PDF), Plan 3 scope notes (PDF→md,
  provenance, arXiv, STT/voice, lite browser), Kokoro voice canon
  (MAS-safe on-device TTS).
- REJECT: browser-use/Chromium automation (Pro-parked), Python/subprocess
  voice wrappers, "Goose-only AI" framing, any Sci-Hub/Scholar-scrape
  research path, pre-pivot Plan-numbered execution order.

## 8. Manual/runtime evidence required after implementation

Per adapter: one real fetch under recorded rate policy + attribution shown +
purge job run. Capture: kill -9 mid-save recovery; mic capture with visible
indicator screenshot. Sync: placeholder dehydrate/rehydrate cycle; dirty
conflict surfaced not clobbered. Skills: gate-passed skill visible, draft
stays unexposed. Browser: WebKit-only proof (no CDP/Chromium symbols in
archive scan).
