# Agent-B Hardening Handoff — 2026-07-04

Autonomous continuous-hardening run on the **Epistemos** macOS app (Swift 6 / SwiftUI / macOS 26),
**Agent-B lane**, branch `feat/goose-surface`, in a multi-lane shared git tree. This hands off to an
**unbounded agent** (no lane restriction / owner authority to open mounts + make product calls).

Agent-B's lane (what it was allowed to edit): `Views/Arxiv`, `Arxiv/`, `LiteParse/`,
`Views/HTMLWorkspace`, `Views/Recall`, `Views/Skills`, `Vault/`, `A2UI/`,
`Engine/{DataviewService,GenUIDispatcher,SpotlightIndexer,HaloController,ShadowSearchService,EpdocBlockTemplateStore}.swift`.
Off-limits (other lanes / owner-fenced): Goose, June, all agent lanes, the **graph** (VIEW *and* diff
core), `Views/{Notes,Epdoc,Settings,Journal,Sessions,Landing,Browser,Meeting,Onboarding,Cost,Capture}`,
`Sync/**`, `App`, `State`, `Models`, `Intents`.

The full per-finding record + a CONNECT-DISCONNECTED MAP + a SESSION SUMMARY live in
`HARDENING_AUDIT.md`; process lessons in `LESSONS.md`.

---

## WHAT'S LEFT (the point of this handoff)

Everything below was **out of Agent-B's reach** — it needs crossing a lane boundary, an owner product
decision, or a bigger feature-build. Ordered by value.

### A. Built-but-dark features — each is ~1 line from live, blocked only by an off-limits mount
These are **complete, compiling, reachable code** that is simply never mounted/consumed. Highest latent
value — small wiring, big payoff.

1. **`SkillEvolutionView`** (`Views/Skills/SkillEvolutionView.swift`) — a complete GEPA proposal/approve
   UI backed by a working `SkillEvolutionService`, but **zero reachability**. Mount it: add a nav entry
   (App / Settings / routing — off-limits to Agent-B). Most self-contained win.
2. **A2UI** (`A2UI/*`, incl. `A2UI/Components/NoteCard.swift`) — a fully-orphaned **producer**.
   `A2UICatalog.payload/render` + `A2UIValidator` have **zero callers**. It emits a `.provenanceTrace`
   `GenUIPayload` that `GenUIDispatcher` already renders — but every GenUI render surface is off-limits
   (`Views/Settings/ProvenanceConsoleView.swift:20`, `Views/Landing/LandingView.swift:1351`,
   `Views/Approval/ApprovalModalView.swift:168`), and no in-lane producer holds claim/evidence data.
3. **`DataviewService`** (`Engine/DataviewService.swift`) — a working DQL parser+executor that
   **self-documents "zero Swift callers" at line 336**. Consumer would be a ` ```dataview ` fenced-block
   renderer in the Notes/Epdoc editor (off-limits). Also incomplete: tag `FROM` unsupported (line 163).
4. **`EpdocBlockTemplateStore`** (`Engine/EpdocBlockTemplateStore.swift`) — per-vault `/template`
   slash-menu library, **zero callers**. Consumer is the Epdoc slash menu (`Views/Epdoc`, off-limits).
5. **Recall "Open Chat" is a no-op** — `ContextualShadowsPanel`'s `onOpen` is correctly wired for notes,
   but the chat case is `case .chat: break` at `Views/Notes/NoteDetailWorkspaceView.swift:950` (off-limits).
   Wire a chat-open call there.

### B. FSRS import → spaced-repetition review enrollment (off-lane fix + product decision)
`FSRSDecayStore` (`Engine/FSRSDecayState.swift:393`, `public actor`, `public func ensure(noteId:)` at
`:495`) is a **LIVE consumer with ZERO producer**: the review sidebar reads
`FSRSDecayStore.shared.topAtRisk()` (`Views/Sessions/FSRSReviewSidebar.swift:40`, mounted live) but
**nothing anywhere enrolls a note** — the store is empty every launch. Blockers before wiring:
- `FSRSDecayStore.configurePersistence` (`:414`) is **never called** → in-memory, resets each launch
  (fix at bootstrap — off-limits to Agent-B).
- A freshly-enrolled note only crosses the 0.80 surfacing threshold after ~2.1 days (`0.9^days < 0.8`).
- Auto-enrolling **every** import into spaced-repetition vs. an opt-in affordance is a **product call**.

Once persistence + policy are decided, the wire is one line per importer:
`await FSRSDecayStore.shared.ensure(noteId: page.id)` in `Arxiv/ArxivIngestService.swift` (~line 352,
beside the existing GAP-1/INT-3/GAP-RECALL-1 index block) and `LiteParse/LiteParsePDFImportController.swift`
(~line 121). Wiring it *without* the persistence fix ships a connection that silently does nothing —
Agent-B deliberately did **not** do this.

### C. Dead-on-both-sides services (feature-builds, not wirings)
`ContradictionDetectionService` (INT-13), `KnowledgeGraphService`, `LiveNoteExecutor`,
`ConversationPersistence` (all `Vault/`) have **zero external callers** — no producer *and* no consumer.
Connecting any is a new feature, not a call to an existing API. (KnowledgeGraphService is graph-adjacent —
respect the graph fence.)

### D. Deferred micro-items (found by the deep audits; each needs care Agent-B couldn't safely take)
- **SS-1** (MED): `ShadowSearchService`'s related-notes path awaits the `@MainActor`
  `AgentToolProvenanceRecorder` → 3-4 main-thread hops, contradicting its "off-main" doc. A drop-in
  `nonisolated AgentToolProvenanceSyncRecorder` already exists (`Engine/AgentToolProvenanceRecorder.swift:72`,
  same `recordToolEvent` API + `EventStore.shared?.saveAgentEvent` target). **Blocked for Agent-B**: swapping
  `ShadowSearchService`'s injecting `init` param type touches callers in off-limits `AppBootstrap`/`Bridge`/`Omega`
  — an unbounded agent can update those. Non-hot path (only `VaultSemanticBacklinks.relatedNotes`), so low urgency.
- **SS-2** (LOW): `ShadowSearchService` passes the *untrimmed* query text to the FFI (computes `normalizedText`
  for the empty-guard/telemetry but sends `text`). Behavior change — confirm the Rust tokenizer trims before touching.
- **HC-2 / HC-3** (LOW): `HaloController.extractQueryContext` scans the full doc O(n) per keystroke (within its
  stated <0.5 ms budget); the debounce Task holds strong `self` across the 400 ms sleep (needed for the telemetry
  interval bracketing, self-heals). Both left as-is intentionally.
- **GU-1** (LOW): `GenUIDispatcher` `FallbackGenUIView` allocates an encoder per render — but it's a never-hit
  schema-drift fallback; hoisting is gold-plating. Left as-is.

### E. arXiv-surface deep audit — DONE (clean-negative-leaning; 4 fixes landed, commit `80ba63012`)
A systematic deep pass over `Views/Arxiv/**` + `Arxiv/**` verified the surface **genuinely well-hardened**
(XXE off, 5 MiB / 64 KB / 50-paper / 32-value caps, host+scheme+path+query pinning on both the search response
and the PDF final URL, symlink/hardlink/regular-file + `%PDF` checks, the throttle actor's reserve-before-await,
off-main parsing — all confirmed, ~30 tests). Agent-B landed 4 clean fixes: **ARX-CANCEL-1** (MED — the
cold-start featured load never assigned `searchTask`, so Stop was a dead no-op *and* new-search was blocked for
up to 15 s; now routed through `searchTask`), ARX-DEAD-1 (removed write-only `elementStack`), ARX-PERF-1 (cache
the invariant pull-gate status), ARX-PERF-2 (ISO8601 formatters `var`→`static let`).
**Left for you (parked, low value):** ARX-NET-1 (search transfer has only a post-hoc 5 MiB cap on
`URLSession.shared` with no transfer-time wall like RES-3 gave PDFs — low threat since the host is pinned; add a
dedicated bounded session for defense-in-depth if desired), ARX-UX-1 (a failed category tap leaves stale papers
+ a highlighted chip — trivial `selectedCategory` reset), ARX-DEAD-2 (`ArxivPDFURLPolicy.isAllowed(_:)` has 0
callers — a harmless security helper, delete-or-keep).

---

## WHAT LANDED (20 findings, all `** BUILD SUCCEEDED **`, committed to `feat/goose-surface`)

| Theme | Findings |
|---|---|
| Import resilience | RES-2 (bounded/abandonable PDF→MD conversion), RES-3 (download timeout), #3 (bulk progress/cancel), #4 (search cancel), #6 (featured retry), ARX-IDX-1 (off-main + logged index) |
| Perf | RECALL-1 (off-main recall preview), PERF-8-REFINE (graph-timer occlusion gate), HW-PKG-1/HW-EXPORT-1a/HW-EXPORT-1b (off-main HTMLWorkspace reads + all exports), HW-DOM-1 (per-keystroke regex hoist), HW-CHAT-1 (per-row formatter hoist), HC-1 (per-keystroke `@Observable` guard), SI-1 (supersede/cancel stale Spotlight reindex) |
| arXiv audit | ARX-CANCEL-1 (cold-start Stop/search dead-zone), ARX-DEAD-1 (write-only state), ARX-PERF-1 (invariant gate cache), ARX-PERF-2 (formatter `var`→`let`) |
| Connect-disconnected | #5 (open-after-import), GAP-RECALL-1 (imports → instant recall) |
| Dead code | HW-DEAD-1/2 |

Three deep adversarial audits (HTMLWorkspace, Shadow/Halo Engine, arXiv surface) drove the back half; each
verified its subsystem otherwise well-hardened.

Two deep adversarial audits (HTMLWorkspace, Shadow/Halo Engine) drove the back half and verified those
subsystems otherwise well-hardened.

---

## PROCESS GUIDANCE (so you don't re-learn the multi-lane hazards the hard way)

- **BUILD in isolated DerivedData** — the fix for all shared-DerivedData contention (the `@Model` macro
  race, mutual incremental-state corruption, cargo-lock stalls):
  `xcodebuild -scheme Epistemos -destination 'platform=macOS' -configuration Debug -derivedDataPath ~/.cache/epistemos-dd-<lane> build`.
  First build cold (~15-25 min), every build after warm + race-free. The Rust cargo target dir is
  repo-relative (shared), so concurrent builds still serialize briefly on the cargo lock — it self-resolves.
- **A plain `build` compiles the TEST target too** (the scheme builds tests), so another lane's broken test
  file fails your build tree-wide. Verify via the `Ld .../Epistemos.app/Contents/MacOS/Epistemos` link line +
  "only-foreign errors." SourceKit "Cannot find type" in same-module symbols = index noise, not a real error.
- **Shared `.git` index** — **NEVER `git add -A`**. `git add` + pause lets another lane's `git add -A && commit`
  sweep your staged files into *their* commit. Commit atomically: `git commit -o -F - -- <explicit paths>`
  (uses working-tree content, ignores the shared index).
- **Shared append-only docs** (`HARDENING_AUDIT.md`, `LESSONS.md`, `DECISIONS.md`) get concurrent appends —
  write with `cat >>` (O_APPEND) and `git diff <doc>` to confirm no foreign lines rode in before staging.
  **At handoff time `HARDENING_AUDIT.md` was contaminated** by another lane's uncommitted block, so Agent-B's
  SI-1 + HW-CHAT-1 audit entries are in its working tree, **uncommitted** — commit them once the foreign block
  lands or is reconciled.
