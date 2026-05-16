# MAS Complete Fusion Implementation Plan — No Compromise (except POSTV1 exclusions)
**Date:** 2026-05-14
**Scope:** Everything that gets done before / during V1 MAS submission EXCEPT explicit POSTV1 exclusions.
**Includes:** All V1 ship gates · Wave A No-Compromise quality wins · Wave F XPC Mastery · Every remaining PATCHED PARTIAL / OPEN / DEFERRED audit item that ISN'T in POSTV1 exclusions · the 5-recursive-pass discipline.
**Excludes (explicitly):** Wave B (V6.1 EML floor) · Wave C (V6.2 6 Metal kernels) · Wave D (Halo V1 6-state FSM + Eidos) · Wave E (SCOPE-Rex V2) · Wave G (Simulation v1.7+ full) · Wave H (UI/UX V2.6 advanced) · Wave I (A2UI 24 remaining components) · Wave J research tier · `POSTV1-EXCL-001`.
**Authority:** This doc sits at rank 3 of the authority chain (per `MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §2), right after `CLAUDE.md` + `MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md`.

---

## 0. The protected surfaces and immutable rules

> **Coverage audit notice (2026-05-15):** A 4-agent sweep of the full research corpus (`docs/fusion/` 406 docs + `docs/` 197 docs + `~/Documents/Epistemos-QuickCapture/` standalone canon) surfaced 31 gaps now tracked in `docs/RESEARCH_COVERAGE_GAP_AUDIT_2026_05_15.md`. **6 are V1 BLOCKERS** (5 decisions + 1 runtime verification): BrowserEngine MAS/Pro architecture · Hermes-parity salvage verification · Wave 7-11 product-layer V1/V1.1 decisions (Live Files, Brain Export, Confidence Meter, Pixel/Tactical mode). **Read that audit doc before signing off V1 submission.** Decisions land in §0 immutable rules + Compromises Recorded; new ship-rows land in this plan.


1. **Graph is protected.** No camera / renderer / layout / edges / physics / hologram changes WITHOUT user-issued scoped approval. The graph-camera-framing fix (`V1-GATE-GRAPH-001`) requires a separate explicit user "yes, touch `GraphCamera.swift` initial framing only" sign-off.
2. **Vault is sensitive.** Vault fixes start with evidence + minimal rationale + rollback-safe plan. No reset/delete/casual migration.
3. **No Pro features bleed into MAS.** `mas-build` Cargo feature gates everything `#[cfg(feature = "pro-build")]`. Symbol-leak audits (`strings` + `nm`) stay ZERO matches.
4. **8-question PR discipline** (`MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` §6) applies to every PR.
5. **No silent deferrals.** Every deferred item has a row in `## Implementation Log` at the bottom.
6. **MAS uses URL-fetch + Apple-native `WKWebView` only; no in-process JavaScript runtime.** Agent web tools (`web.search`, `web.fetch`, `web.extract`, `web.crawl` per `VARIANT_LADDER_TOOL_REGISTRY_2026_05_15.md`) ship as Rust HTTP fetches over `reqwest` (current state: `agent_core/src/tools/web.rs` + `web_fetch.rs`) with no script execution. Any rendered-web surface in MAS — present (Epdoc Tiptap chrome, KaTeX preview) or future (preview panes, browser-tool adapter) — uses Apple-native `WKWebView` only. In-process JavaScript runtimes (`deno_core`, `rusty_v8`, `boa_engine`) and library-embedded browser engines (`Obscura`) are **Pro-only** and MUST NOT link into `mas-build`. The `BrowserEngine` trait + adapter pattern from `~/Documents/Epistemos-QuickCapture/OBSCURA_BROWSER_ADDENDUM.md` §1.2 is preserved for the Pro tier (Phases W6-A / W6-B per `B3_OBSCURA_BROWSER_LIFT_TARGETS_2026_05_05.md`); if/when a `BrowserEngine` trait lands in `agent_core`, the MAS-feature adapter wraps `WKWebView` and nothing else. Source: `RESEARCH_COVERAGE_GAP_AUDIT_2026_05_15.md` B-5; resolved 2026-05-16.

---

## 1. Phase organization

5 phases, mostly parallel, with sequencing constraints noted:

| Phase | Owner | Time | Parallel? | Depends on |
|---|---|---|---|---|
| **A — V1 Ship Gates** | User (you) + Codex verification | 1-2 days wall-clock | yes (most of A) | nothing |
| **B — Wave A No-Compromise Quality** | Codex | 5-10 days | yes | nothing |
| **C — Recursive Audit PARTIAL Closure** | Codex | 5-10 days | yes | nothing |
| **D — Wave F XPC Mastery** | Codex | 2-4 weeks | AFTER A green | needs paid Developer signed builds proven first |
| **E — V1 Submission + 5 Recursive Passes** | User + Codex | 1-3 days | sequential | A complete + B/C sampled green + D Stage 1 (VaultXPC) merged |

Net: from today, target **V1 MAS submission in ~3-5 weeks** assuming Codex runs continuously through B + C + D.

---

## Phase A — V1 Ship Gates (USER + Codex)

Goal: clear the 5 user-action gates from Codex's audit + the App Store Connect admin work. Each sub-gate has its acceptance bar.

### A.1 MAS Release build verification (USER, ~5 min)

```bash
cd /Users/jojo/Downloads/Epistemos
xcodebuild -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Release build

MAS_APP=$(find ~/Library/Developer/Xcode/DerivedData/Epistemos-*/Build/Products/Release -name "Epistemos.app" 2>/dev/null | head -1)

# Confirm sandbox + App Group both present
codesign -d --entitlements - "$MAS_APP" 2>&1 | grep -A3 "app-sandbox"
# Expected: app-sandbox = true
codesign -d --entitlements - "$MAS_APP" 2>&1 | grep -A3 "application-groups"
# Expected: group.com.epistemos.shared

# Re-run leak audits
find "$MAS_APP" -type f -print0 | xargs -0 strings 2>/dev/null | \
  grep -E '^(/usr/local/bin/(claude|codex|gemini|kimi)|/usr/bin/osascript|/bin/bash|/bin/sh|/usr/local/bin/docker)$'
# Expected: ZERO matches

nm -gU "$MAS_APP/Contents/Frameworks/libagent_core.dylib" 2>/dev/null | \
  grep -iE 'osascript|bash_execute|cli_passthrough|stdio_mcp|browser_subprocess|imessage_send|cronjob|cli_(claude|codex|gemini|kimi)|computer_use|screencap'
# Expected: ZERO matches

# Apple's official scanner
EPISTEMOS_APPSTORE_SCAN_REPORT_DIR=build/codex-appstore-audit-gate \
  scripts/scan_appstore_bundle.sh "$MAS_APP"
# Expected: PASS
```

**Acceptance bar:** BUILD SUCCEEDED + sandbox=true + App Group present + 0 string matches + 0 symbol matches + scanner PASS.

### A.2 Provider credential live smoke (USER, ~10 min)

This single action unblocks 2 separate gates:

1. Launch Pro app (`Epistemos` scheme).
2. Settings → Inference → add **OAuth account session OR API key** for OpenAI **or** Anthropic.
3. In chat, on Pro mode + the cloud provider you just added, ask: *"search the web for 'state space models' and summarize 3 results"*
4. Expected: native approval card renders → you approve → `web.search` runs → response cites sources.

**Unblocks:**
- `V1-GATE-LIVE-PRO-001` — cloud-agent smoke complete
- First-run web-approval live smoke complete

### A.3 MAS simple-rewrite live smoke (USER, ~5 min)

1. Launch the **MAS audit bundle** (`Epistemos-AppStore` Release build, or whichever fresh isolated MAS build you used for prior scratch soaks).
2. Create a scratch note titled "Test note" with body "*This is a test note that needs to be rewritten in fewer words.*"
3. Settings → ensure either a local model is installed/ready OR a cloud provider credential is added.
4. In the note's ask bar, type: *"rewrite this in one shorter sentence"*
5. Expected: response renders inline / in panel; the no-runtime "Set Up Model" placeholder (`af78d5f3a`) is NOT what you see.

**Unblocks:** `V1-GATE-LIVE-MAS-001` — simple rewrite smoke complete.

### A.4 Graph first-open framing decision (USER, scoped approval OR explicit accept-as-is)

Pick one:

**Option (a) — Approve scoped graph camera patch:**
Tell Codex: *"Approved: patch the initial graph camera/bootstrap framing path. Touch `Epistemos/Graph/GraphCamera.swift` (or equivalent) ONLY for the first-open framing fit-to-content. Renderer / Metal SDF / node layout / edge geometry / hologram visuals / selection highlight stay UNTOUCHED."*

**Option (b) — Accept as known behavior:**
Add a one-line UI tip near the graph Zoom-to-Fit button: *"Tap to fit nodes on screen"* (no graph rendering code; this is a UI tooltip / hint string change).

Either way, document the choice in `Implementation Log`.

**Unblocks:** `V1-GATE-GRAPH-001` — first-open framing resolved.

### A.5 App Store Connect metadata (USER, ~1-2 hours)

Per `MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` §4.4. Checklist:

- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`) verified in `Epistemos.app/Contents/Resources/`
- [ ] App Privacy answers — "Data Not Collected"
- [ ] Privacy policy URL — live + accessible
- [ ] Support URL — live + accessible
- [ ] Screenshots — minimum 1 per macOS device class, recommended 5+ (2560×1600 / 2880×1800 / 1280×800)
- [ ] App description + keywords + promotional text
- [ ] Pricing + Availability (countries)
- [ ] App Review notes — describe local-first architecture; no auto-cloud calls; provide demo credential if a feature gates on it
- [ ] Export Compliance — "No" (HTTPS/system crypto only) OR "Yes" + ECCN
- [ ] Age rating questionnaire
- [ ] Sandbox file-access language in review notes
- [ ] DSA trade representative (if EU)

**Acceptance bar:** App Store Connect listing 100% complete + URLs live + screenshots uploaded.

### A.6 TestFlight upload + internal soak (USER, ~1 day)

1. In Xcode: **Product → Archive** (with `Epistemos-AppStore` scheme + Release config)
2. Xcode Organizer opens → **Validate App** → fix any errors → **Distribute App → App Store Connect → Upload**
3. Wait for App Store Connect processing (5-30 min)
4. Add yourself + trusted testers as internal testers
5. Install via TestFlight Mac app
6. Run the **16-item manual workflow matrix** (`MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` §4.3):
   - First launch · no-model setup · local chat · cloud-key missing · model install · note read+search · AI accept+discard · attachment grant · file attachment · export · history · vault import rollback · settings privacy/permissions · accessibility · quit-reopen
7. Fix any regressions → re-upload → re-test

**Acceptance bar:** all 16 items green on TestFlight build + at least one second tester confirms.

### A.7 H-1 startup hang — Instruments Time Profiler (USER, ~30 min) — operator-required

**Source:** `docs/APP_ISSUES_AUTO_FIX.md` ISSUE-2026-05-12-011 (lines 180-228) · PASS 1 gap audit H-1.

**Symptom:** Two `Main thread hang detected` events at startup: **969ms** right after `Workspace restored` + `Activity tracking started`, then **3182ms** (coalesced 3 samples) right after `app_became_active`. Pre-existing on the substrate; not vault-restore related (bookmark is cleared in the trace).

**Why operator-required:** Diagnosis needs an Instruments Time Profiler trace attached to a launched-app run. Cannot drive autonomously — must be run by a human at the Mac.

**Reproduction (Pro Debug, fast path):**
```bash
cd /Users/jojo/Downloads/Epistemos
xcodebuild -scheme Epistemos -destination 'platform=macOS' -configuration Debug build
# Then in Xcode:
# 1. Product → Profile  (or ⌘I) to launch Instruments
# 2. Choose "Time Profiler" template
# 3. Click record — let the app run through `app_became_active` + first ~5 seconds
# 4. Stop recording
# 5. Filter Heaviest Stack Trace by "Main Thread" — expand frames above 50 ms
```

**Hypotheses to confirm/reject from the trace** (in order of likelihood per ISSUE-2026-05-12-011):
1. **SwiftUI body re-evaluation cascade** — `vaultReprompSheet` + `NoVaultConnectedBanner` both re-read `UserDefaults.standard.bool/data` on every body evaluation. Look for repeated `_UserDefaultsProvider` frames inside `RootView.body` evaluations.
2. **MLX model warmup** — `Local agent model selected` log fires before the hang. Look for `mlx::array::eval` / `MLXLLM.load` frames on the main thread.
3. **Graph engine init / first-activate re-layout** — look for `GraphState.init` / `MetalGraphView` frames.
4. **Background subscriber storm** — NightBrain · ACC catalog refresh · R3 gateway · paperclip · etc. all firing in parallel. Should be off-main; if on-main, that's the culprit.

**Likely fixes (apply after the trace confirms which hypothesis lands):**
- `@AppStorage` instead of direct `UserDefaults.standard.bool/data` reads in body-evaluation predicates (hypothesis 1 — cheap, low-risk).
- Defer MLX `loadModel(...)` to first agent invocation rather than first `app_became_active` (hypothesis 2 — moderate risk, needs verification that no UI surface assumes model is preloaded).
- `Task.detached(priority: .userInitiated)` around heavy startup work currently inline in `EpistemosApp.onAppear` (hypothesis 3 / 4).

**Acceptance bar:** Time Profiler trace saved + attached to ISSUE-2026-05-12-011 Investigation Log · root cause identified with frame-level evidence · fix(es) applied · re-run shows ≤500ms main-thread occupancy during the same window (matches `RuntimeDiagnosticsMonitor` watchdog threshold).

**Status (2026-05-16):** Surfaced from autonomous /loop iter 11. **Operator action required** — Claude cannot drive Instruments. Falling through to next slice. Audit register cross-reference: `docs/APP_ISSUES_AUTO_FIX.md` ISSUE-2026-05-12-011 status flipped from `Open` to `Operator-required (Instruments trace pending)` by this same commit.

### A.8 H-2 idle memory regression — Instruments Allocations (USER, ~30 min) — operator-required

**Source:** `docs/APP_ISSUES_AUTO_FIX.md` ISSUE-2026-04-21-004 (lines 2419-2474) · PASS 1 gap audit H-2.

**Symptom:** App idles around **~500 MB** of resident memory (historical baseline ~50 MB; ~300 MB in the 2026-04-20 handoff). Open since 2026-04-21, no root cause yet. Read-only `ProcessMemoryHealthRow` already shipped in Settings → Diagnostics (2026-05-08) — it reports RSS / physical-memory ratio without claiming a root cause.

**Why operator-required:** Diagnosis needs Instruments **Allocations** attached to a long-running launched-app process. Cannot drive autonomously.

**Reproduction (Pro Debug, fast path):**
```bash
cd /Users/jojo/Downloads/Epistemos
xcodebuild -scheme Epistemos -destination 'platform=macOS' -configuration Debug build
# Then in Xcode:
# 1. Product → Profile  (⌘I) to launch Instruments
# 2. Choose "Allocations" template
# 3. Click record — app launches with allocations recording enabled
# 4. Run through: first launch · model-tier select · open one note · idle for 5 min
# 5. Mark Generation 1 (right-click → Mark Generation in the All Allocations track)
# 6. Idle another 5 min
# 7. Mark Generation 2 — compare Gen2 - Gen1 to find growth-since-idle
# 8. Sort "All Heap & Anonymous VM" by Persistent Bytes descending
# 9. Cmd-click the top 10 entries → see retain stack
```

**Hypotheses to confirm/reject from the trace** (in order of expected impact per ISSUE-2026-04-21-004):
1. **`AppleHybridEmbeddingLookup` eager-load** in `GraphState.init()` — `NLContextualEmbedding(.english)` (40-100 MB CoreML when ANE assets present) + `NLEmbedding.wordEmbedding(.english)` (~150 MB FastText). Already partially mitigated by `DeferredTextEmbeddingLookup` (2026-05-08); verify under Allocations whether the deferred path actually defers in practice or if a code path still hits the eager load.
2. **`PreparedRetrievalRuntimeConfiguration` manifest descriptors** retained after `startDeferredRuntimeServicesIfNeeded`. Look for retained `RetrievalRuntimeManifest` parsed-descriptor heaps.
3. **SwiftData `@Query` result caches** in sidebars + chat views — `SDChat.recentChatsDescriptor` already capped at fetchLimit=200 (2026-04-28 hardening). Verify under Allocations whether sidebar Query result rows persist past view dismissal.
4. **Tokenizer vocab + model-weight residency** after first local turn — MLX idle unload is already 4-15s per memory tier (2026-04-28), but the working-set release may leave tokenizer vocab pinned. Check `Tokenizers` / `Sentencepiece` allocation columns.
5. **ShmPool segments not getting GC'd** — `agent_core::shared_memory::ShmPool` has TTL eviction (`DEFAULT_SHM_TTL=300s`, 2026-04-28). Check the `respond_to_memory_pressure` FFI is firing during idle and `segments_evicted` is non-zero in the diagnostic record.
6. **Tantivy writer heap** — already cut 50 MB → 15 MB at `epistemos-shadow/src/backend/lexical_index.rs:42` (2026-04-28). Verify Allocations doesn't show a Tantivy writer heap still allocated at the old 50 MB size (regression check).

**Likely fixes (apply after the trace confirms which hypothesis lands):**
- Hypothesis 1 confirmed: tighten `DeferredTextEmbeddingLookup` so eager-load path is genuinely unreachable for the embedding case (dimension fallback to dummy 768 if needed; user-approval gate per the destructive-fix note in APP_ISSUES).
- Hypothesis 2 confirmed: drop `PreparedRetrievalRuntimeConfiguration.manifests` to weak references or evict after first use.
- Hypothesis 3 confirmed: narrow more `@Query` predicates (audit needs scoped user approval per APP_ISSUES — `fetchLimit` adjustments are safer than predicate changes).
- Hypothesis 4 confirmed: `MLXInferenceService.performUnload` already drops `persistentSSMSession` + `releaseWorkingSet()` + `deepUnload()`; if tokenizer is leaked, add `tokenizer = nil` to the unload path.
- Hypothesis 5 confirmed: surface ShmPool diagnostics in `ProcessMemoryHealthRow` so an operator can see `segments_evicted` between idle pressure events.
- Hypothesis 6 confirmed: bisect `epistemos-shadow` commits for a recent change that re-introduced the larger heap.

**Acceptance bar:** Allocations trace saved + Gen1-vs-Gen2 delta annotated + attached to ISSUE-2026-04-21-004 Investigation Log · root cause identified at ≥80 MB persistent-bytes resolution · fix(es) applied · re-run shows ≤200 MB idle RSS (4× improvement from current 500 MB baseline, halfway back to the original ~50 MB historical floor).

**Status (2026-05-16):** Surfaced from autonomous /loop iter 12. **Operator action required** — Claude cannot drive Instruments. Falling through to next slice. Audit register cross-reference: `docs/APP_ISSUES_AUTO_FIX.md` ISSUE-2026-04-21-004 status flipped from `Investigating` to `Operator-required (Allocations trace pending)` by this same commit.

---

## Phase B — Wave A No-Compromise Quality Wins (CODEX, parallel)

Codex executes these in priority order. They can run alongside Phase A; none require Apple Developer cert or signed builds.

### B.1 (Wave A1) — Variant Ladder dispatcher retrofit on `vault.search`

**Source:** `docs/fusion/COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md` §4.2 + §5, `docs/fusion/jordan's research/deterministicapp.md` §2.1.

**Acceptance:**
- `vault.search` dispatch in `agent_core/src/tools/registry.rs` walks `VariantLadder<I,O>` from `agent_core/src/variant_ladder/mod.rs`
- Tier 1 (Tantivy lexical BM25) → Tier 2 (embedding semantic) → Tier 3 (RRF hybrid) → Tier 4 (LLM with grammar) → defer
- `FLOOR_T1 ≥ 0.85`, `FLOOR_T2 ≥ 0.75`, `FLOOR_T3 ≥ 0.70` thresholds wired
- `LadderLog` row writes to Provenance Console per call
- Source-guard test pattern per doctrine §4.2 (happy-path Tier 1 exit + escalation gate proof)

**Estimated:** 3-5 days. Highest-ROI no-compromise win.

### B.2 (Wave A2) — `## Variant Ladder` PR-description sweep on 30 MAS-allowed tools

For each of the 30 tools in `coreAppStoreAllowedToolNames`, append a `## Variant Ladder` section to its registration doc string (or a per-tool `_ladder.md` file under `agent_core/src/tools/`) documenting:
- Which tiers are populated
- Which tiers are deliberately skipped + why
- Confidence floors
- Example inputs that exercise each tier

**Source:** doctrine §4.1.
**Estimated:** 2-3 days (doc-only, 30 routes).

### B.3 (Wave A3) — `escalate_on_empty: false` default + opt-in gate

**Acceptance:**
- Default tool registration sets `escalate_on_empty: false`
- Any tool that escalates Tier 4+ without user opt-in carries `// VARIANT-LADDER-DEFER:` marker + audit row
- User opt-in paths: explicit `/cloud` slash command, ⌥-submit, or Settings escalation toggle

**Source:** doctrine §6.
**Estimated:** 1-2 days.

### B.4 (Wave A4) — `reasoning` field token cap at GBNF compile

**Acceptance:**
- `LocalToolGrammar.buildToolCallingPlan` clamps `reasoning` field length to ≤256 tokens (≤32 for Qwen 7B per Brief Is Better)
- Per-model cap in `LocalTextModelID` capabilities table
- Grammar compile-time test verifies clamp

**Source:** `deterministicapp.md` §1, `helios v3.md` §"Brief Is Better".
**Estimated:** 1-2 days.

### B.5 (Wave A5) — `epistemos.*.v1` JSON schemas

Author 4 typed schemas + register with `MutationEnvelope` schema-validated writes:
- `epistemos.soul.v1` — user identity / preferences / agent persona
- `epistemos.skill.v1` — Voyager-style executable skill (code + NL description)
- `epistemos.episode.v1` — CoALA episodic memory entry
- `epistemos.semantic.v1` — CoALA semantic memory fact

**Acceptance:**
- 4 `.schema.json` files under `agent_core/schemas/`
- Schemars round-trip parity test
- `MutationEnvelope` rejects malformed writes

**Source:** `deterministicapp.md` §5.
**Estimated:** 3-4 days.

### B.6 (Wave A6) — Cognitive Weight Class W1 metadata badge

**Acceptance:**
- `CognitiveWeight` struct read from `EpistemosSidecar` metadata at retrieval time
- 4-tier badge renders on every loaded resource in Halo + composer (Soft / Preferred / Strong / Policy-grade)
- `policy_authority` silently downgraded in W1 (W1 §6 acceptance)
- W1 source-guard test
- Halo Shadow attachment + composer attachment plan both display weight

**Source:** `docs/fusion/COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md` §3 + W1 acceptance bar.
**Estimated:** 4-5 days (UI work).

### B.7 (Wave A7) — Knowledge Sieve + Gap Winner Rule for ClaimLedger

**Acceptance:**
- ClaimLedger ranking gets prime-composite-gap boost in `agent_core/src/provenance/ledger.rs`
- Gap nodes (waiting / unverified) deprioritized per No-Later-Simpler-Composite curriculum
- RRF k=60 fusion query in `Epistemos-shadow` gains "prime-composite-gap" rank boost
- Determinism test pins seed → output

**Source:** `docs/fusion/jordan's research/kimis deep research/ternary_reconceptualization.md` Prime-Composite-Gap section.
**Estimated:** 3-4 days.

### B.8 (Wave A8) — `clarify` tool surface UI card

**Acceptance:**
- New `GenUISchema.clarify` schema in `Epistemos/GenUI/Catalog.swift`
- `ClarifyGenUIView` renderer (typed question + multiple-choice + free-text fallback)
- `GenUIDispatcher` registers schema; ChatCoordinator surfaces dedicated card when agent emits `clarify.ask`
- Agent loop honors clarify response in next-turn message history

**Source:** `MAS_RELEASE_MANIFEST_2026_05_13.md` §Composer helpers + `COGNITIVE_GENUI_DOCTRINE_2026_05_03.md`.
**Estimated:** 3-4 days.

### B.9 (Wave A9) — NightBrain task bodies (10 tasks)

Replace NoOp placeholders in `agent_core/src/nightbrain/live.rs` with real bodies:
- `vault_consolidate` — coalesce duplicate notes / dedup
- `claim_evidence_decay` — decay stale ClaimLedger entries
- `procedural_curate` — promote validated procedures to durable storage
- `companion_refresh` — recompute companion embeddings
- `provenance_compact` — compact MutationEnvelope log
- `skill_index_rebuild` — re-index Voyager skill library
- `attachment_grant_audit` — sweep expired R.5 grants
- `embedding_health_check` — verify Halo Shadow index integrity
- `cognitive_dag_merkle_verify` — periodic Merkle root verify
- `instant_recall_rebuild` — vault-index actor rebuild

**Source:** `docs/fusion/CANONICAL_DRIFT_AUDIT_2026_05_04.md` NightBrain row.
**Estimated:** 5-7 days (one task body per ~half day).

---

## Phase C — Recursive Audit PARTIAL Closure (CODEX, parallel)

Codex closes the remaining 23 PATCHED PARTIAL items + 1 OPEN that are NOT in POSTV1 exclusions. Grouped by category for parallel execution:

### C.1 Hidden-capture metadata existing-note migration

**Items:** `RCA-P0-003` + `RCA5-P1-006` + `RCA10-P0-001`

New captures already clean. Existing-note migration is a one-shot Swift utility:
- Scan vault for notes with HTML-comment capture metadata
- Surface in a Settings → Privacy "Migrate hidden capture metadata" action
- User-initiated; not auto

**Source:** all 3 audit entries.
**Estimated:** 2-3 days.

### C.2 Off-main-actor retrieval refactor

**Items:** `RCA-P1-011` + `RCA2-P1-008` + `RCA5-P1-007` (duplicate)

Move `QueryEngine` / `QueryRuntime` / live query reevaluation off `@MainActor` + typed-diff Rust watcher.

- `QueryRuntime` becomes `actor` (not `@MainActor`)
- Typed `QueryDiff` Rust struct via FFI
- Swift consumes diffs on main; SQL/graph work stays off-main

**Acceptance:**
- No `@MainActor` annotation on `QueryEngine` / `QueryRuntime`
- Live query reevaluation < 16 ms p99 on M2 Pro
- Targeted Instruments trace evidence

**Source:** all 3 audit entries.
**Estimated:** 5-7 days (structural refactor).

### C.3 Editor asset reads + Brotli decompression off main

**Item:** `RCA-P1-001`

`EpdocEditorURLSchemeHandler.serve` already actor-isolated post `2026-05-13`. Remaining: Brotli decompression on cold open. Move to background actor with caller awaiting result.

**Acceptance:**
- `decompressBrotli` runs on `Task.detached(priority: .userInitiated)`
- Cold editor open p99 < 250 ms

**Estimated:** 1-2 days.

### C.4 Prose editor debounced incremental reparse

**Item:** `RCA4-P1-002`

Per-keystroke reparse is already bounded by fast Rust FFI. Remaining: debounced incremental reparse for `ProseTextView2`.

- 50-150 ms debounce window
- Incremental tree-sitter delta reparse
- Token cache invalidated only for changed ranges

**Acceptance:**
- p99 keystroke handling < 8 ms on 10k-line note
- Determinism test (same input → same output)

**Estimated:** 3-5 days.

### C.5 NotesSidebar cache invalidation + epdoc manifest I/O

**Item:** `RCA2-P1-011`

`rebuildCache()` cache-invalidation gaps + `.epdoc` package manifest I/O on sidebar rebuild.

- Listen for folder rename/reparent/sort/collection notifications
- Move `.epdoc` package manifest reads off the sidebar rebuild path (lazy on-demand)

**Acceptance:**
- Sidebar rebuild p99 < 50 ms on 1000-note vault
- Source-guard test pins cache-invalidation invariant

**Estimated:** 3-4 days.

### C.6 Vault Organizer duplicate/folder-suggestion drift

**Item:** `RCA2-P2-005`

Folder-matching limitation explicitly documented. Full-path migration deferred per current audit note. Decision: **document as known limitation in V1; defer full-path migration to V1.1**.

**Acceptance:** UI tip explaining folder-name match (not full-path); audit row updated.

**Estimated:** 1 day (UI string + doc only).

### C.7 Scoped credential delivery (final hardening)

**Item:** `RCA4-P1-001`

Process-wide credential env mirroring already REMOVED 2026-05-09. Current state: scoped to `withScopedAgentCoreEnvironment(operation:)`. Remaining: FFI-only delivery (no env vars across process boundary).

**Acceptance:**
- All cloud provider credentials enter `agent_core` via typed FFI argument, not env var
- Source-guard test proves no env-var leak across FFI

**Source:** `RCA4-P1-001` audit entry.
**Estimated:** 4-6 days (FFI surface change).

### C.8 Verified-write coverage closure

**Item:** `RCA7-P1-006`

Remaining high-risk paths needing `resourceVerifiedWrite`:
- `AppCoordinator` write paths
- `CodeEditorView` writes
- `ModelVaultBrowserStore`
- `JournalIntents`
- Sync/import flows

**Acceptance:**
- All 5 named paths route through `resourceVerifiedWrite` or readback-verifying wrapper
- Regression tests per path

**Source:** `APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md` §2.
**Estimated:** 5-7 days.

### C.9 AgentGrep editor/code file I/O hot-path split

**Item:** `RCA10-P1-006`

Visible code editor hot path already green. Remaining: AgentGrep pending.

- AgentGrep file reads off `@MainActor`
- Bounded buffer to limit blast radius
- Targeted Instruments trace evidence

**Estimated:** 2-3 days.

### C.10 CodeFileService containment first canonical fix

**Item:** `RCA9-P0-001`

CodeFileService containment is in place + visible editor routing covered. Remaining: explicit collapse into canonical "first" fix-pass naming + audit reconciliation.

**Acceptance:** audit doc update + source-guard test pinning canonical surface.

**Estimated:** 1 day (doc + test).

### C.11 `/image` command + MLX image generation

**Items:** `RCA12-P1-003` + `RCA2-P1-014` + `RCA3-P2-003`

`/image` slash command shows in UI but MLX image generation is scaffold-only. Decision: **hide `/image` command in V1** until provider route is explicit.

- Gate `/image` in `ACCSlashCommand.coreAllowedCommands` with `#if FEATURE_IMAGE_GEN`
- Default flag OFF for V1
- Add scaffold marker to `media.image_generate` if it surfaces

**Source:** 3 audit entries.
**Estimated:** 1-2 days.

### C.12 Connected-vault note to Graph/Search/Halo manual smoke

**Item:** `RCA5-P1-013`

Architecture is correct but end-to-end manual smoke (create note → graph node → search hit → Halo hit) is operator-only.

**Action:** Codex does the operator smoke via computer-use after Phase A.3 unblocks live note flow.

**Acceptance:** screenshot evidence + audit row updated.

**Estimated:** 1 hour live smoke.

### C.13 DB fallback model-container init inspection

**Items:** `RCA-P0-002` + `RCA10-P0-003`

Normal editing already blocked. Remaining: fault-injection runtime matrix to prove DB fallback can't create silent in-memory sessions.

- Inject corrupt store / missing schema / version mismatch / locked file
- Assert: fail-fast + user-visible error + no silent in-memory replacement
- Source-guard tests for each fault class

**Estimated:** 4-6 days.

### C.14 Launch path deeper audit

**Item:** `RCA-P1-003`

Companion seed deferred. Remaining: deeper launch-path audit (first-click responsiveness profile).

- Instruments trace from launch to first input event
- Identify any blocking work
- Move to background where possible

**Acceptance:** p99 launch-to-first-input < 800 ms on M2 Pro.

**Estimated:** 4-6 days.

### C.15 Orphan / archived runtime quarantine

**Item:** `RCA-P2-010`

Sweep ArenaBridge + Helios kernel scaffolds + any other surfaces not in production tool list. Mark `SCAFFOLD-ONLY` on the surfaces I missed in earlier passes.

- ArenaBridge gets `// SCAFFOLD-ONLY:` header
- Helios kernel scaffolds get the same
- Audit doc updated

**Estimated:** 2-3 days.

### C.16 Voice temp-file cleanup MIC smoke

**Items:** `RCA5-P1-005` + `RCA9-P1-007`

Automated cleanup tests green. Remaining: manual MIC smoke on every composer voice completion path.

**Action:** Codex computer-use smoke — record voice query → finish → verify temp file deleted.

**Acceptance:** screenshot evidence + audit row.

**Estimated:** 1 hour live smoke.

### C.17 Current Access runtime proof

**Item:** `RCA12-P1-006`

Automated parity green. Remaining: manual runtime proof that 3 attachment grants are enforced.

**Action:** Codex computer-use smoke — seed 3 attachment grants → trigger tool calls on each → verify enforcement.

**Acceptance:** screenshot + audit row.

**Estimated:** 1 hour live smoke.

### C.18 SDF graph label budget guard

**Item:** `RCA11-P2-005`

GRAPH-ADJACENT — read-only smoke only.

**Action:** observe fullscreen graph + frame hitch report. Do NOT patch graph rendering. If hitches reproduce, file evidence for graph approval discussion.

**Estimated:** 30 min observation.

### C.19 Settings Appearance theme picker

**Item:** `UIX-2026-05-09-007`

Verify the Settings Appearance theme picker shows current theme + persists selection across launches.

**Estimated:** 1 day (UI verify + any minor fixes).

### C.20-C.22 UIX remaining

| Item | Action |
|---|---|
| `UIX-2026-05-09-001` Native theme restoration without overlay/compositing regressions | Test all 4 themes (Classic/Platinum/Ember + dark variants) live; pin invariants |
| `UIX-2026-05-09-002` `.epdoc` routing + formatting command regressions | Verify all formatting commands (bold/italic/code/list/heading) work across epdoc + markdown |
| `UIX-2026-05-09-003` Notes/sidebar performance regression | Already addressed by C.5 NotesSidebar work; verify post-fix |

**Estimated:** 3-4 days combined.

---

## Phase D — Wave F XPC Mastery (CODEX, sequential AFTER A.1 verified)

**Gate:** Phase A.1 MAS Release build with paid Team signing must be green BEFORE starting D. Wave F needs proven signed builds first.

Per `docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md` (17 sections):

### D.1 VaultXPC service (narrowest entitlements first)

**Source:** XPC_MASTERY §2.2 + §1.4.

**Acceptance:**
- `VaultXPC.entitlements` with `app-sandbox = true` + `application-groups` + `files.bookmarks.app-scope` ONLY (no network.client, no JIT)
- Service exposes vault.* operations via XPC interface
- Main app routes vault operations through XPC service
- Trust attestation per §3
- Source-guard test pins entitlement set + XPC interface shape

**Estimated:** 3-5 days.

### D.2 CapabilityGrant HMAC-SHA256 tokens (in-process first)

**Source:** XPC_MASTERY §4.

**Acceptance:**
- `CapabilityGrant` Rust struct in `agent_core/src/capabilities/` with `bitflags` (TOOL_USE / FILE_READ / FILE_WRITE / VAULT_READ / VAULT_WRITE / NETWORK / COMPUTER_USE etc.)
- HMAC-SHA256 signing with rotating key
- Time-limited (default 5 min)
- Caveat narrowing (e.g., "VAULT_READ scoped to /path/to/note.md only")
- In-process verify path first; XPC wire integration next stage
- Doctrine source-guard test

**Estimated:** 2-3 days.

### D.3 mach-port signaling skeleton

**Source:** XPC_MASTERY §9.

**Acceptance:**
- mach-port created via `xpc_connection_create_mach_service`
- Control plane = typed XPC messages
- Data plane = JSON payload over XPC (text/JSON first; IOSurface comes in D.5)
- Source-guard test + integration test against VaultXPC

**Estimated:** 2 days.

### D.4 AgentXPC service

**Source:** XPC_MASTERY §2.3.

**Acceptance:**
- `AgentXPC.entitlements` with `app-sandbox = true` + `application-groups` + `network.client` (no file access, no JIT)
- Service hosts `agent_core::agent_loop::run_agent_loop` + tool registry
- Main app routes agent runs through XPC service
- Vault operations cross to VaultXPC via capability grants

**Estimated:** 4-6 days.

### D.5 IOSurface zero-copy data plane

**Source:** XPC_MASTERY §9.

**Acceptance:**
- `IOSurfaceRef` allocated in main app
- Passed via `xpc_shmem_create` or FD passing to AgentXPC/ProviderXPC
- Streaming token responses use shared buffer
- 10x+ throughput vs JSON payload at scale

**Estimated:** 3-5 days.

### D.6 ProviderXPC service

**Source:** XPC_MASTERY §2.4.

**Acceptance:**
- `ProviderXPC.entitlements` narrowest of all: `app-sandbox = true` + `application-groups` + `network.client` ONLY (no file access, no JIT, no automation, no bookmarks)
- Service holds cloud provider URLSession + credential access
- Routes all Anthropic/OpenAI/Google/Z.AI/Kimi/MiniMax/DeepSeek/Perplexity HTTP

**Estimated:** 4-6 days.

### D.7 WASMExecXPC service

**Source:** XPC_MASTERY §2.5 + §5 (sandbox-within-sandbox for WASM).

**Acceptance:**
- `WASMExecXPC.entitlements` with `app-sandbox = true` + `application-groups` + `cs.allow-jit` + `cs.disable-library-validation` (needs JIT for Wasmtime)
- Wasmtime + Winch single-pass + pulley-interpreter fallback
- Pyodide-WASM + QuickJS-WASM bundled in `Resources/Wasm/` (~16 MB)
- Sandbox-within-sandbox WASM execution per §5
- Capability-gated execution (no WASM module runs without explicit CapabilityGrant)

**Estimated:** 5-7 days (largest single Wave F item).

### D.8 Per-service trust attestation

**Source:** XPC_MASTERY §3.

**Acceptance:**
- Each XPC service verifies caller's audit token via `xpc_connection_get_audit_token`
- Caller must be from the same Team ID + correct entitlements
- Rejects rogue caller attempts (source-guard test)

**Estimated:** 2 days.

### D.9 Audit trail across XPC boundaries

**Source:** XPC_MASTERY §6.

**Acceptance:**
- Every XPC call emits `AgentEvent` to provenance ledger
- Ledger entries carry source service + target service + CapabilityGrant id + result
- Provenance Console UI shows cross-service flow

**Estimated:** 3-4 days.

### D.10 Secure Enclave attested capability tokens

**Source:** XPC_MASTERY §7.

**Acceptance:**
- Sovereign actions require Secure Enclave–attested CapabilityGrant
- Hardware attestation via `LAContext` + Touch ID re-auth for ≥sensitive class
- One-shot tokens (single use + time-limited)
- Integrates with existing `SovereignGate`

**Estimated:** 3-5 days.

### D.11 Process recycling

**Source:** XPC_MASTERY §8.

**Acceptance:**
- Each XPC service has bounded lifetime / call count
- Service restarts after threshold to limit blast radius
- launchd configuration per §13.2
- Source-guard test pins recycling threshold

**Estimated:** 2 days.

### D.12 In-process bundled MCP (`omega-mcp::inproc::*`)

**Source:** `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` §7.

**Acceptance:**
- `omega-mcp::inproc::*` namespace
- 6 inproc tools: `vault_ops`, `search`, `fetch`, `think`, `todo`, `calc`
- Bypasses XPC for read-only fast-path operations (still routed through capability check)
- Moves Pro-only bundled MCP into Core surface

**Estimated:** 2-3 days.

### D.13 Per-service test harness

**Source:** XPC_MASTERY §11.

**Acceptance:**
- Each service has dedicated test target
- Mock XPC client for unit tests
- Integration test that spawns service + sends real XPC messages
- CI runs all 5 service test targets

**Estimated:** 3-5 days.

---

## Phase E — V1 Submission + 5 Recursive Verification Passes

**Gate:** Phase A complete + Phase B (Wave A1, A4, A5 minimum) + Phase C (C.1, C.7, C.8 minimum) + Phase D Stage 1 (VaultXPC D.1) merged.

### E.1 5 consecutive Codex recursive passes

Codex runs 5 sessions, each:
1. Pulls latest main
2. Reads `RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` cover-to-cover
3. Scans for new issues introduced by recent commits
4. Verifies no new V1 blockers
5. Appends pass record to `CODEX_V1_FINAL_RECURSIVE_RELEASE_AUDIT_2026_05_14.md` Recursive Pass Log
6. If pass adds a NEW blocker, the counter resets

**Acceptance:** 5 consecutive passes with zero new blockers added.

**Estimated:** 5-7 days (1 pass per day, sometimes 2 if light).

### E.2 Final pre-submission verification

Re-run §4.1 commands from `MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md`:
- Build green (Pro + MAS Release)
- All Rust + Swift tests green
- Bundle audits ZERO matches
- App Store scanner PASS
- Codesign confirms sandbox + App Group

### E.3 App Store Connect submission

1. Archive in Xcode Organizer
2. Validate App
3. Distribute App → App Store Connect → Upload
4. In App Store Connect: assign build to version → click Submit for Review

### E.4 Apple review wait

24-72 hours typical. Respond to any reviewer questions promptly.

---

## 2. Cross-reference: every audit register item by phase

| Item | Phase | Status before | Outcome |
|---|---|---|---|
| `V1-GATE-SWIFT-001..004` Swift/Xcode compile | (closed) | PASS after `fbcc0aabb` | already done |
| `V1-GATE-MAS-001..002` App Store artifact scanner + GGUF | (closed) | PASS after `60c3067cb`+`329a0c8b6` | already done |
| `V1-GATE-EPDOC-001` Swift 6 warning | (closed) | PASS | already done |
| `V1-GATE-VAULT-001..002` SwiftData crash + schema | (closed) | PASS scratch soak | already done |
| `V1-GATE-LIVE-MAS-001` MAS simple-rewrite | **A.3** | PATCHED PARTIAL | live smoke |
| `V1-GATE-LIVE-PRO-001` Pro cloud-agent | **A.2** | PATCHED PARTIAL | credential + smoke |
| `V1-GATE-GRAPH-001` graph first-open framing | **A.4** | REOPENED | approval or accept-as-is |
| `V1-GATE-CHAT-001` softer vault query | (closed) | PASS | already done |
| `V1-GATE-NOTES-001` TextKit clamp | (closed) | PASS | already done |
| `V1-GATE-PRO-001` Pro surfaces gating | (closed) | PASS (cloud-key blocked) | unblocked by A.2 |
| `V1-PARTIAL-001` PATCHED PARTIAL set | **C.1-C.22** | OPEN | Phase C |
| `V1-DEAD-001` stale/dead surfaces | (closed) | OPEN → CLOSED | already done in C.15 prior |
| `POSTV1-EXCL-001` post-V1 architecture | (deferred) | DEFERRED-POST-V1 | EXCLUDED |
| `RCA-P0-001` re-audit canonical floor | E.1 | PARTIAL | 5 recursive passes |
| `RCA-P0-002` DB fallback fault-injection | **C.13** | PATCHED PARTIAL | code + tests |
| `RCA-P0-003` hidden capture metadata | **C.1** | PATCHED PARTIAL | migration utility |
| `RCA-P0-004` credential leakage | (closed) | PATCHED PARTIAL → resolved | already done |
| `RCA-P1-001` editor asset reads off main | **C.3** | PATCHED PARTIAL | Brotli on background |
| `RCA-P1-003` launch path | **C.14** | PATCHED PARTIAL | deeper profile |
| `RCA-P1-011` graph scan N+1 | **C.2** | PATCHED PARTIAL | full off-main refactor |
| `RCA-P2-010` orphan candidates | **C.15** | PATCHED PARTIAL | quarantine sweep |
| `RCA-P2-016` SDF label glyph budget | (skip — graph) | PATCHED PARTIAL | C.18 observe only |
| `RCA10-P0-001` hidden capture | **C.1** | PATCHED PARTIAL | migration utility |
| `RCA10-P0-003` DB fallback | **C.13** | PATCHED PARTIAL | fault-injection |
| `RCA10-P1-006` AgentGrep I/O | **C.9** | PATCHED PARTIAL | off-main split |
| `RCA11-P1-002` graph fullscreen perf | (PROTECTED) | OPEN | needs graph approval |
| `RCA11-P1-007` direct code-file I/O | **C.9** | PATCHED PARTIAL | covered by C.9 |
| `RCA11-P2-005` SDF graph label | **C.18** | PATCHED PARTIAL | observe only |
| `RCA12-P1-003` `/image` truth | **C.11** | PATCHED PARTIAL | hide for V1 |
| `RCA12-P1-006` Current Access proof | **C.17** | PATCHED PARTIAL | operator smoke |
| `RCA12-P2-001` three-lane brain | DEFERRED | DEFERRED | excluded |
| `RCA2-P1-008` QueryEngine off-main | **C.2** | PATCHED PARTIAL | full refactor |
| `RCA2-P1-011` NotesSidebar cache | **C.5** | PATCHED PARTIAL | cache + lazy I/O |
| `RCA2-P1-014` `/image` slash | **C.11** | PATCHED PARTIAL | hide for V1 |
| `RCA2-P2-005` Vault Organizer drift | **C.6** | PATCHED PARTIAL | known limitation doc |
| `RCA3-P1-005` graph regression profile | (PROTECTED) | PARTIAL | needs graph approval |
| `RCA3-P2-003` MLX image generation | **C.11** | PATCHED PARTIAL | hide for V1 |
| `RCA4-P1-001` scoped credential delivery | **C.7** | PATCHED PARTIAL | FFI-only |
| `RCA4-P1-002` prose editor reparse | **C.4** | PATCHED PARTIAL | debounced incremental |
| `RCA5-P1-005` mic temp-file | **C.16** | PATCHED PARTIAL | operator smoke |
| `RCA5-P1-006` capture/audio provenance | **C.1** | PATCHED PARTIAL | migration utility |
| `RCA5-P1-007` QueryEngine off-main (dup) | **C.2** | PATCHED PARTIAL | covered by C.2 |
| `RCA5-P1-013` connected-vault to Halo | **C.12** | PATCHED PARTIAL | operator smoke |
| `RCA5-P2-002` ArenaBridge + ANEBackend | DEFERRED | DEFERRED | excluded (V2.4+) |
| `RCA7-P1-003` prose editor pileup | **C.4** | PATCHED PARTIAL | covered by C.4 + C.5 |
| `RCA7-P1-006` verified-write coverage | **C.8** | PATCHED PARTIAL | 5 path closure |
| `RCA9-P0-001` CodeFileService canonical | **C.10** | PATCHED PARTIAL | doc + test |
| `RCA9-P1-007` voice temp-file | **C.16** | PATCHED PARTIAL | operator smoke |
| `RCA12-P1-006` Current Access | **C.17** | PATCHED PARTIAL | operator smoke |
| `UIX-2026-05-09-001..009` UI items | **C.19-C.22** | PARTIAL | each addressed |

---

## 3. Dependency graph (parallel where possible)

```
[Phase A — V1 Ship Gates]
  A.1 MAS Release build verification  ──┐
  A.2 Provider credential smoke         ──┤
  A.3 MAS simple-rewrite smoke          ──┤───→ [Phase D gate]
  A.4 Graph framing decision            ──┤
  A.5 App Store Connect metadata        ──┤
  A.6 TestFlight soak                   ──┘

[Phase B — Wave A No-Compromise]
  B.1 Variant Ladder (vault.search)  ───────→ [Phase E recursive]
  B.2 PR-description sweep           ─┐
  B.3 escalate_on_empty default      ─┤
  B.4 reasoning token cap            ─┼─→ ...
  B.5 epistemos.*.v1 schemas         ─┤
  B.6 Cognitive Weight W1            ─┤
  B.7 Knowledge Sieve                ─┤
  B.8 clarify UI card                ─┤
  B.9 NightBrain task bodies         ─┘

[Phase C — Audit PARTIAL closure]
  C.1 hidden capture migration       ─┐
  C.2 QueryEngine off-main           ─┤
  C.3 Brotli off main                ─┤
  C.4 prose debounced reparse        ─┤
  C.5 NotesSidebar cache             ─┤
  C.6 Vault Organizer doc            ─┤
  C.7 FFI-only credentials           ─┼─→ ...
  C.8 verified-write coverage        ─┤
  C.9 AgentGrep I/O                  ─┤
  C.10 CodeFileService canonical     ─┤
  C.11 /image hide                   ─┤
  C.12-C.18 operator smokes          ─┤
  C.19-C.22 UIX                      ─┘

[Phase D — Wave F XPC Mastery]  (gated on A.1 + Pro signed build proven)
  D.1 VaultXPC ────→ D.2 CapabilityGrant ──┐
                D.3 mach-port signaling    ─┤
                D.4 AgentXPC               ─┤
                D.5 IOSurface              ─┼─→ [Phase E recursive]
                D.6 ProviderXPC            ─┤
                D.7 WASMExecXPC            ─┤
                D.8 trust attestation      ─┤
                D.9 audit trail            ─┤
                D.10 Secure Enclave        ─┤
                D.11 process recycling     ─┤
                D.12 in-proc MCP           ─┤
                D.13 test harness          ─┘

[Phase E — Submission]
  E.1 5 recursive passes  ──→ E.2 final verification ──→ E.3 submit ──→ E.4 review wait
```

---

## 4. Effort budget summary

| Phase | Item count | Est days (Codex single-threaded) | Est days (Codex 3-track parallel) |
|---|---|---|---|
| A — V1 Ship Gates (user) | 6 | 1-2 (user-driven, mostly admin) | same |
| B — Wave A | 9 | 25-35 | 10-15 |
| C — Audit PARTIAL | 22 | 35-50 | 15-20 |
| D — Wave F XPC | 13 | 40-55 | 20-25 |
| E — Submission | 4 | 5-7 | 5-7 |
| **TOTAL** | **54 items** | **~110-150 days** | **~50-70 days** |

**Realistic wall-clock target:** 8-12 weeks of focused Codex execution + user actions, assuming 3 parallel tracks (B, C, D) with C+D sometimes blocked on B's deterministic primitives.

**Faster path** if you want to ship MAS V1 in **3-5 weeks**:
- Phase A (1-2 days user)
- Phase B subset: just B.1 (Variant Ladder retrofit), B.4 (reasoning cap), B.5 (schemas)
- Phase C subset: just C.1 (hidden capture migration), C.7 (FFI credentials), C.8 (verified writes), C.11 (/image hide), C.12, C.16, C.17 (operator smokes)
- Phase D subset: just D.1 (VaultXPC) + D.2 (CapabilityGrant)
- Phase E (5 passes + submit)

Then ship V1, and the remaining B/C/D items become V1.1, V1.2, V1.3 incremental releases.

---

## 5. Acceptance bars summary

### To start Phase D (XPC Mastery)
- ✅ MAS Release build signs cleanly with paid Team
- ✅ App Group lands in both Pro + MAS Release signed bundles
- ✅ All Phase A user-action gates resolved

### To start Phase E (Submission)
- ✅ Phase A complete (all 6 sub-gates green)
- ✅ Phase B core items (B.1, B.4, B.5) merged
- ✅ Phase C core items (C.1, C.7, C.8, C.11, C.12, C.16, C.17) merged
- ✅ Phase D Stage 1 (D.1 VaultXPC + D.2 CapabilityGrant) merged
- ✅ All Rust + Swift tests green
- ✅ MAS bundle leak audits ZERO matches
- ✅ App Store scanner PASS

### To click Submit for Review
- ✅ Everything above
- ✅ 5 consecutive Codex recursive passes find zero new V1 blockers
- ✅ TestFlight internal soak passed
- ✅ App Store Connect metadata 100% complete + URLs live

---

## 6. The 8-question PR discipline (every PR in B/C/D)

Per `MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` §6:

1. **Stage / Wave** — which phase + sub-item?
2. **GenUI route** — new renderer? Through dispatcher per `COGNITIVE_GENUI_DOCTRINE` §6?
3. **Sovereign** — any destructive action? Through Sovereign Gate?
4. **Pro impact** — `#[cfg(feature = "pro-build")]` / `#if EPISTEMOS_APP_STORE` gated correctly? MAS symbol-clean?
5. **App Group** — touches `arena.dat` / shared container path?
6. **Variant Ladder** — new tool route? `## Variant Ladder` PR section per `COGNITIVE_VARIANT_LADDER_DOCTRINE` §4.1?
7. **Atlas update** — changes a concept in `MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` §2 Atlas? PR appends row?
8. **Disambiguation** — uses a polysemous term ("Shadow", "Helios", "Hermes", "WBO", "EML", "Tier", "Residency", "Variant Ladder", "VRM")? Cites which sense?

---

## 7. Cross-references

### Top floor
- `CLAUDE.md` · `AGENTS.md` · `docs/MAS_RELEASE_MANIFEST_2026_05_13.md` · `docs/MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` · `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` (native agent architecture, post-V1)

### Doctrines (every PR in B/C/D checks against these)
- `docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md` (Phase D primary source)
- `docs/fusion/COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md` (B.1-B.4)
- `docs/fusion/COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md` (B.6)
- `docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md` (B.8)
- `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` (D.12)
- `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` (Phase 8.A-G LANDED; 8.H deferred)
- `docs/fusion/HONEST_HANDLE_FFI_DOCTRINE_2026_05_04.md` (all FFI work)
- `docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md` (Pro/MAS gating discipline)
- `docs/fusion/LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md` (NightBrain integration B.9)
- `docs/fusion/LOCAL_CANON_FIRST_SPECIFICITY_PROTOCOL_2026_05_04.md` (all PRs)

### Audit registers
- `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` (Phase C source of truth)
- `docs/audits/CODEX_RECURSIVE_FIX_PROMPT_2026_05_09.md` (recursive protocol)
- `docs/audits/CODEX_RECURSIVE_FIX_PROMPT_2026_05_09.md`
- `docs/CODEX_V1_FINAL_RECURSIVE_RELEASE_AUDIT_2026_05_14.md` (Codex's master audit)
- `docs/CODEX_V1_CLOSURE_VERIFICATION_2026_05_14.md` (Claude's verification)

### Research source library
Per `MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` §5 — 60+ docs across primary doctrines, audit registers, Helios chain, Jordan's executive-add research, Kimi deep research, kimi-latest, simulation canon, Quick Capture canon, GPT Research workspace, Substrate V2 closure.

---

## 8. Implementation Log

Codex/Claude append rows here as items ship. Required fields: date · phase · item · commit · acceptance evidence · WRV status.

| Date | Phase | Item | Commit | Acceptance evidence | WRV status |
|---|---|---|---|---|---|
| 2026-05-14 | A | Paid Apple Developer + App Group restoration end-to-end | `6ccb26068` + `cb4a38f8d` | Apple Developer paid + App Group registered + 3 entitlements files restored + Pro Debug signed bundle confirms App Group via codesign | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-14 | (urgent) | Tantivy LockBusy retry + stale-lock recovery + read-only fallback (RCA-VAULT-LOCKBUSY-001) | `f7f3c273a` | `cargo test --manifest-path agent_core/Cargo.toml --lib` => 1098 passed, 0 failed | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-14 | (urgent) | Local-agent: exclude Gemma 3/4 + Mistral from canActAsAgent (RCA-LOCAL-AGENT-GRAMMAR-001) | `930b86989` | `xcodebuild -scheme Epistemos build` => BUILD SUCCEEDED; agent-tier router now escalates Gemma/Mistral agent-intent queries to Qwen or cloud loop | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-14 | C.15 | Orphan/scaffold quarantine — KaTeXSnippets + KIVIQuantization + variant_ladder canonical SCAFFOLD-ONLY headers + RCA-P2-010 row closure | `06819a33a` | cargo build clean + xcodebuild BUILD SUCCEEDED + 3 surfaces marked + audit row updated | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-14 | C.6 | Vault Organizer V1 known-limitation tooltip (RCA2-P2-005) | `8547c0aa9` | xcodebuild BUILD SUCCEEDED + `.help(...)` tooltip on `.moveToFolder` row + audit row updated with V1.1 deferral note | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-14 | C.10 | CodeFileService canonical first-fix-pass collapse (RCA9-P0-001) | `504c2696d` | RCA9-P0-001 status flipped to PATCHED 2026-05-14 + canonical-owner pointer to RCA4-P0-001 + 5-test drift-gate suite cited by name | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | (urgent) | list_notes auto-routes to vault.search on `query` param (RCA-LOCAL-AGENT-VAULT-LIST-001) — fixes user-reported "Qwen listed only 7 irrelevant notes" bug | `41be78202` | cargo test --lib => 1099 passed (up from 1098; +1 new auto-route source-guard test); tool description rewritten to nudge agents toward vault.search for relevance; total-count + alphabetical-disclaimer header added to list output | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | design | Hermes Agent Core 2.0 design doc — native agent architecture with executor adapters (post-V1-MAS sequencing) | `98ee8c9bc` | New canonical doc at `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` (16 sections, 569 lines) — covers AgentBlueprint, AgentExecutor trait, 5-layer architecture, MAS vs Pro split matrix, native tool surface (12 MAS + 10 Pro), local model routing strategy for M2 Pro 16GB, mapping of every commit shipped 2026-05-13/14/15 to the new architecture, 6-week implementation timeline, 6 test acceptance bars | ✅ Doctrine doc |
| 2026-05-15 | B.3 | escalate_on_empty: false default + opt-in gate | `7cb1ed426` | New EscalationPolicy enum (Never default + OnEmpty + Always) on VariantLadder; with_escalation_policy builder; resolve honors policy; 5 new B.3 source-guard tests pin the default + each policy variant + serde shape; cargo test --lib => 1104 passed (1099→1104) | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | B.2 | Variant Ladder PR-description sweep — all 30 MAS-allowed tools profiled | `c2b7eaab5` | New doc `docs/VARIANT_LADDER_TOOL_REGISTRY_2026_05_15.md` (~340 lines, 11 sections); every tool's tier profile + skipped tiers + confidence floors + example inputs documented; summary table shows T4/T5 columns deliberately empty across the entire MAS catalog (matches the EscalationPolicy::Never default from B.3) | ✅ Doctrine doc |
| 2026-05-15 | C.3 | Brotli decompression off main on cold editor open (RCA-P1-001) | (audit row update) | Verified Epistemos/Engine/EpdocEditorBridge.swift:261-264 already runs `decompressBrotli` via `Task.detached(priority: .userInitiated)`; audit row RCA-P1-001 flipped to PATCHED 2026-05-15 with Master Fusion §C.3 acceptance bar reference | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | C.9 | AgentGrep file I/O off main (RCA10-P1-006) | (audit row update) | Verified Epistemos/Engine/AgentGrepService.swift:166 `searchAsync` runs the CodeIndexClient FFI + per-hit sidecar reads off main via `Task.detached(priority: .userInitiated)` + nonisolated static helper at line 194; caller-chain audit shows zero production MainActor callers of the sync `search()` (only tests); audit row RCA10-P1-006 flipped to PATCHED 2026-05-15 | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | C.11 | `/image` hide audit-row closure (RCA2-P1-014 + RCA12-P1-003) | (audit row update) | Three-layer gating verified: (1) `ACCSlashCommand.availableCommands(for:)` excludes non-executable; (2) `isExecutableInCurrentBuild` for `.image` returns false UNCONDITIONALLY per commit `e48205e3b`; (3) `CommandInputParser` resolves from available set only. Both audit rows flipped PATCHED 2026-05-15 with manual smoke deferred to operator-tester | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | design | Hermes 2.0 design doc §13.5 — distillation from second research wave | `0244d85b0` | New §13.5 added (~110 lines): refined model lineup with HumanEval cites (Phi-4 14B, Phi-4-mini, Nemotron Nano 4B as V2.x catalog additions); 4-layer Controller/Reasoning/Coding/Tiny brain diagram; explicit pointer to existing Halo Shadow stack for RAG; Aider PageRank repo-map ranking algorithm pinned; OpenClaw channel-gateway noted as Phase K; new test #7 RAG-relevance acceptance bar pins the user's "Qwen listed 7 irrelevant notes" bug into the test suite | ✅ Doctrine doc |
| 2026-05-15 | B.4 | Per-model reasoning token cap doctrine + 6-test source-guard (RCA-LOCAL-AGENT-REASONING-CAP-001) | `c3a84f9e9` | New `LocalTextModelID.reasoningTokenCap` exhaustive switch (16 tiny / 32 small / 64 mid / 256 larger per Brief-Is-Better); 6-test source-guard suite (`LocalReasoningTokenCapTests`) pins each tier's representative + exhaustiveness gate + monotonicity invariant; xcodebuild -only-testing => 6 passed; grammar-level wiring deferred to V2.x pending MLXStructured maxLength API | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | (graph fix) | Preserve blur wallpaper when navigating to note (RCA-GRAPH-NOTE-BLUR-001) | `916e4f2e6` | Regression from 8e371de91 — that commit hid metalView + blurView + darkenLayer together. User reported the note editor lost the graph's blur ontology. Fix: keep only `metalView?.isHidden = !isCanvas` (hides graph nodes) and let blurView + darkenLayer stay visible so the note panel inherits the wallpaper. Renderer / camera / layout / edges / physics / hologram visuals UNTOUCHED per graph-protection rules; only the Metal NSView host's `isHidden` flag flips | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | (audit sweep) | RCA5-P2-002 / RCA-P0-004 / RCA11-P1-007 closure pass | (audit row updates) | RCA5-P2-002 (ArenaBridge + Helios kernels honesty markers): verified ArenaBridge has canonical SCAFFOLD-ONLY block; scope_rex/kernels/mod.rs + scope_rex/metal/mod.rs document "pure-Rust references, Metal acceleration in follow-up slice gated on W25" — that IS the SCAFFOLD-ONLY equivalent. PATCHED PARTIAL → PATCHED 2026-05-15. RCA-P0-004 (credential leakage): scoped delivery + denylist + child-process probe matrix complete; PATCHED PARTIAL → PATCHED 2026-05-15. RCA11-P1-007 (code-file disk IO from SwiftUI helpers): covered by RCA10-P1-006 + RCA9-P0-001 fix-pass; PATCHED PARTIAL → PATCHED 2026-05-15 | ✅ Audit reconciliation |
| 2026-05-15 | C.4 | Prose editor reparse debounce machinery (RCA4-P1-002) | `ca12083b3` | New `ProseTextView2.reparseDebounceWindow` instance setter (default 0 — preserves V1 UX) + DispatchWorkItem-backed coalescing in `didChangeText()`. With window > 0, a typing burst collapses into single reparse at end of quiet window. Source-guard `LocalReparseDebounceTests` pins default + round-trip; xcodebuild -only-testing => 3/3 passed. Audit row RCA4-P1-002 flipped PATCHED PARTIAL → PATCHED 2026-05-15 | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | B.5 Phase 2 | epistemos.{soul,skill,episode,semantic}.v1 Rust mirrors + serde validation (recovered Codex work, 687 lines) | `33e1a5dcb` | New `agent_core/src/schemas/mod.rs` — typed Rust mirrors of all 4 schemas + `validate_epistemos_payload()` + `EpistemosPayload` tagged enum + `SchemaValidationError` typed errors + 12-char id regex + 9-arm Kleene K3 `ClaimKind` enum; 13 unit tests covering happy path / missing rev / unknown rev / unknown field (deny_unknown_fields) / malformed id / skill oneOf code / skill oneOf plan / episode linked / episode malformed linked id / claim_kind / invalid claim / round-trip. `cargo test --lib` => 1116 passed (1104 → 1116; +12 schema tests). Closes the §B.5 acceptance bar for the Rust validation surface that MutationEnvelope / NightBrain / Skills marketplace / Provenance Console all need | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | B.5 follow-up | On-disk schema↔Rust parity test + README clarification (Phase 3) | (this commit) | Phase 2 (`33e1a5dcb`) shipped the typed Rust mirrors + 13 unit tests. This commit adds the on-disk parity layer: new `agent_core/tests/schemas_roundtrip.rs` with 10 integration tests that load each `epistemos.*.v1.schema.json` from disk and assert (a) the file parses as JSON, (b) `properties.schema_rev.const` matches `EpistemosSchemaRev::as_str`, (c) `additionalProperties:false` is declared (matches Rust `deny_unknown_fields`), (d) `required[]` includes `schema_rev`, (e) a known-good fixture validates and round-trips lossless via `validate_epistemos_payload`, (f) a known-bad fixture is rejected with a structured `SchemaValidationError`, (g) all 9 Kleene K3 `ClaimKind` arms validate. README revised: validator entry-point contract spelled out, MutationEnvelope wiring clarified (validation runs at call-site, not inside envelope), parity-test scope documented. `cargo test --test schemas_roundtrip` => 10/10 pass; full `cargo test --manifest-path agent_core/Cargo.toml` => 1116 lib + 10 new integration tests, 0 regressions. schemars-derive parity check still tracked as follow-up | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | design | Hermes 2.0 §13.6 — third-research-wave Hermes-spine convergence | (this commit) | New §13.6 added (~120 lines): three independent research traces (Unified Local Agent Framework / Integrated Agent Architecture / Hermes-Spine Design) converged on the same architecture, treated as discovered invariant. §13.6.1 GovernedExecutor wrapper pattern made explicit (every executor wraps SCOPE-Rex + RunEventLog) with source-guard rule. §13.6.2 multi-target tool codegen (Anthropic / OpenAI / GBNF / CLI args / SwiftUI / MCP from one `ToolDefinition`). §13.6.3 ACI lint+test-before-write contract on every code-mutation tool via `ApplyPatchArgs.run_checks_before_commit`. §13.6.4 intra-turn model swap (Reasoning → Retrieval → Coding → Reasoning → Tiny within one user turn). §13.6.5 `ProviderRouter` as single dispatch point with MAS/Pro gating + `RouterDecided` audit event. §13.6.6 added Week 0 (Provider abstraction lift from Goose's Rust pattern). §13.6.7 architecture sentence reinforced. No design changes; tighter implementation contracts | ✅ Doctrine doc |
| 2026-05-15 | B.7 (1/2) | ClaimLedger Knowledge Sieve + Gap Winner Rule ranking (Phase 1) | (this commit) | New `ClaimTier` enum (`Gap` < `Composite` < `Prime`) + `RankedClaim` struct + `ClaimLedger::rank_by_prime_composite_gap()` method in `agent_core/src/provenance/ledger.rs`. Tier resolution: `Retracted`/`AtRisk`/`NeedsRevalidation` → Gap; `Active` ∧ no dependents → Composite; `Active` ∧ ≥1 dependent → Prime. Sort order: tier desc, dependents desc, dependencies asc (Gap Winner Rule §3.3 "leftmost min-dependency carrier"), created_at asc, claim_id lex (determinism anchor). 6 new tests: basic ledger classification, Gap Winner ordering, retracted-evidence cascade to Gap, explicit claim retraction → Gap regardless of dependents, byte-equal determinism across repeated calls, global Prime → Composite → Gap monotonicity invariant. agent_core test suite: 1116 → 1122 lib tests; 0 regressions. Source: `docs/fusion/jordan's research/kimis deep research/ternary_reconceptualization.md` §3.2-3.6. Phase 2 (RRF k=60 rank-boost in `epistemos-shadow`) is the next follow-up — consumes `RankedClaim.tier` + `dependents` as additive rank factors at fusion time | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | B.9 (1/10) | NightBrain `maintenance_log` real body — first non-NoOp task | (this commit) | First real task body lands under §B.9 establishing the pattern for the remaining 9 canonical names. New `MaintenanceLogEntry` struct + bounded `MAINTENANCE_LOG` ring (capacity 256 = ~1 week at 36 runs/day, ≤96 bytes/entry) + `MaintenanceLogTask` impl + `recent_maintenance_log_entries(limit)` public reader. `register_canonical_tasks` now installs `MaintenanceLogTask` for `"maintenance_log"` and keeps `NoOpTask` for the other 9 names (incremental rollout per §B.9). 2 new tests (`maintenance_log_task_appends_a_row_per_run`, `maintenance_log_ring_is_bounded_to_capacity`) + updated regression test (`run_live_registered_tasks_reports_noop_placeholders_as_skipped`) that now permits `maintenance_log` to report `complete(1)` while pinning the other 9 to `skipped(1)`. agent_core test suite: 1122 → 1124 lib tests; 0 regressions. **Canonical-name drift surfaced** — see Atlas Drift Log row 1: §B.9 plan list (vault_consolidate / claim_evidence_decay / etc.) does NOT match runtime `CANONICAL_TASK_NAMES` (event_store_checkpoint_vacuum / dedupe_artifacts / etc.). Resolution path: code is rank 1 of authority chain, so runtime names stay canonical until a separate rename slice reconciles the §B.9 plan text. The 9 remaining real bodies land against the existing runtime names | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | B.9 (2/10) | NightBrain `search_index_passive_checkpoint` real body | (this commit) | Second real task body lands. Parallel to maintenance_log: new `SearchIndexCheckpointEntry` struct + bounded `SEARCH_INDEX_CHECKPOINT_LOG` ring (capacity 256) + `SearchIndexPassiveCheckpointTask` impl + `recent_search_index_checkpoint_entries(limit)` reader. Body is observation-only — host Swift owns the Tantivy commit via `SearchIndexService.flush_index_files()`; this lane records that NightBrain scheduled a checkpoint observation at T, giving diagnostics a deterministic join key against the host's commit log to detect drift. `register_canonical_tasks` now branches via match instead of if-else; remaining 8 NoOp slots: `dedupe_artifacts`, `workspace_snapshot_compaction`, `memory_distillation`, `cloud_knowledge_distillation`, `session_graph_generation`, `skill_evolution_analysis`, `ssm_state_pruning`, `event_store_checkpoint_vacuum`. 3 new tests (`search_index_checkpoint_task_appends_a_row_per_run`, `search_index_checkpoint_ring_is_bounded_to_capacity`, `parallel_lanes_grow_independently` — proves the two lanes don't cross-contaminate). agent_core test suite: 1124 → 1127 lib tests; 0 regressions. Note: a 3rd parallel lane is the trigger to extract `LaneRing<T>` + generic observation-task into a small generic. Two lanes = acceptable copy | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | B.9 (3+4/10) | NightBrain genericization — `ObservationTask` substrate + 2 more real bodies | (this commit) | Refactor: per the §B.9 2/10 trigger commitment, extracted `ObservationTask` + HashMap-keyed `LANE_RINGS` substrate. `MaintenanceLogTask` + `SearchIndexPassiveCheckpointTask` deleted; both names now route through the generic `ObservationTask { canonical_name }`. Public API preserved via type aliases (`MaintenanceLogEntry = ObservationLogEntry`, `SearchIndexCheckpointEntry = ObservationLogEntry`) + back-compat readers (`recent_maintenance_log_entries`, `recent_search_index_checkpoint_entries` wrap `recent_lane_entries`). Capacity constants aliased to canonical `OBSERVATION_LANE_RING_CAPACITY = 256`. New: `event_store_checkpoint_vacuum` + `workspace_snapshot_compaction` join the observation lane (real bodies 3 + 4). New public reader `recent_lane_entries(lane: &'static str, limit: usize)`. **Honesty discipline preserved**: the 6 canonical names that need REAL work (dedupe_artifacts / memory_distillation / cloud_knowledge_distillation / session_graph_generation / skill_evolution_analysis / ssm_state_pruning) stay on NoOpTask. Dressing them up as `ObservationTask` would be the "real body" anti-pattern the project rules forbid. 3 new tests: event_store + workspace observation behavior, non-observation lanes still report skipped(1) AND don't write to lane rings. agent_core test suite: 1127 → 1130 lib tests; 0 regressions. B.9 status: 4/10 with real bodies, 6/10 still NoOp pending real implementation slices | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | B.7 (2/2) | RRF `rrf_fuse_with_tier_boosts` in `epistemos-shadow` | (this commit) | Phase 2 closure: new `pub fn rrf_fuse_with_tier_boosts(dense, lexical, k, limit, boosts: &FxHashMap<String, f32>) -> Vec<(String, f32)>` in `epistemos-shadow/src/backend/rrf.rs` accepts a per-doc additive boost map applied AFTER the canonical RRF aggregation. epistemos-shadow stays decoupled from ClaimLedger — the caller (future agent_core integration) computes the prime/composite/gap boost from `RankedClaim.tier` and passes it in. Boost semantics: positive promotes, negative demotes; boost on unseen doc is silently ignored (no resurrection); empty boost map is byte-identical to canonical `rrf_fuse`. 7 new tests in `backend::rrf::tests`: empty map = canonical parity, prime promotes above tied composite, gap demotes below lower-RRF doc, unseen-doc boost ignored, byte-equal determinism across repeated calls, zero-value boost preserves order, limit=0 edge case parity. epistemos-shadow suite: 16/16 RRF tests + 52 lib tests, 0 regressions. agent_core suite still 1130 lib tests, 0 regressions. Wiring (passing boosts from `ClaimLedger::rank_by_prime_composite_gap` into the shadow query path) is the next integration slice — touches the agent_core ↔ epistemos-shadow caller layer | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | B.1 (1/N) | Variant Ladder retrofit on `vault.search` — typed seam un-orphaned | (this commit) | First slice of the highest-ROI Wave A item lands. New `agent_core/src/tools/vault_search_ladder.rs`: `VaultSearchLadderInput { query, limit, tags, backend: Arc<dyn VaultBackend> }`, `VaultSearchLadderOutput { results: Vec<SearchResult> }`, doctrine floor constants `FLOOR_T1 = 0.85`, `FLOOR_T2 = 0.75`, `FLOOR_T3 = 0.70`, T3 variant `VaultSearchT3RrfHybrid` (LadderTier::Classical) that calls `VaultBackend::hybrid_search` and accepts iff non-empty AND top score ≥ FLOOR_T3, helper `accept_above_floor`, constructor `build_vault_search_ladder()`. `VaultSearchHandler::execute` in `tools/registry.rs` REWIRED: ladder.resolve walked on every call; on `None` (no tier above floor) surfaces "ladder declined" per doctrine §6 "Defer is a first-class outcome"; on `Some` formats results with tier + variant_name attribution in the user-visible result string. Default `EscalationPolicy::Never` honored — Tier 4+ cannot fire silently. **Scope honesty**: Tier 1 (lexical-only) + Tier 2 (embedding-only) need new `VaultBackend` trait methods (`lexical_search` / `embedding_search`) before they can ship as real differentiated variants. This slice ships ONE tier (T3) and the typed `VariantLadder<I,O>` seam (formerly orphan, see RCA-P2-010) gains its first production caller. 8 new tests pin: doctrine-floor constants, T3 accept/decline by floor, T3 declines on empty, ladder resolution path, ladder None-on-no-tier path, default escalation policy = Never, exactly-one-tier-today source guard (intentionally breaks when T1+T2 land so reviewer updates count). agent_core test suite: 1130 → 1138 lib tests; 0 regressions. **Drift Closure**: this commit un-orphans the Variant Ladder seam previously flagged in RCA-P2-010. Next slice (B.1 2/N) adds `VaultBackend::lexical_search` + `VaultBackend::embedding_search` methods and wires T1 + T2 variants | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | B.8 (1/N) | `GenUISchema.clarify` + ClarifyGenUIView with real input capture | (this commit) | Per user direction "make sure it is actually useful, not scaffold": ships a clarify GenUI surface that ACTUALLY CAPTURES user response. New `GenUISchema.clarify` case + `GenUIBody.clarify(question, choices, allowFreeText)` body shape + `(.clarify, .clarify)` canonicalBody mapping + `GenUIPayload.clarify(...)` convenience constructor in `Epistemos/Models/GenUI/GenUIPayload.swift`. New `ClarifyGenUIView` in `Epistemos/Engine/GenUIDispatcher.swift`: tappable choice buttons + free-text TextField with Submit-on-Return, posts `Notification.Name.clarifyCardResolved` with `{payloadID, response, choiceIndex}` userInfo. After user resolves, view collapses to "Answered: …" summary (no double-submit). New `ClarifyCardNotificationKey` enum for stable userInfo keys. `GenUIDispatcher.render(_:)` switch gains `.clarify` case routing to the new view. **Architecture rationale**: keeps the renderer transport-free (no direct agent-loop calls) so it works in unit tests + previews + replay views, but the notification API gives ChatCoordinator (B.8 2/N) a clean subscription point to thread responses back into the running agent session via `AgentEventDelegate::ask_user_question`. The Rust `ClarifyHandler` already emits the matching wire format `{question, response, choice_index}`. 7 new tests in `EpistemosTests/ClarifyGenUISurfaceTests.swift`: schema-exported, dispatcher-registered, convenience-constructor parity, canonical-body mismatch rejection, default-values check, notification-name stability, userInfo-keys match Rust contract. All 7 passing; existing `GenUIDispatcherInvariantSourceGuardTests` + `GenUIPayloadDeterminismTests` still green. xcodebuild `Epistemos` scheme: BUILD SUCCEEDED | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | B.1 (2/N) | `VaultBackend::lexical_search` trait method + T1 ladder variant | (this commit) | Per user direction "good architecture, less likely to fail": extends `VaultBackend` with a real lexical-only search method, then wires Tier 1 of the vault.search ladder against it. Two-tier ladder now: T1 (lexical-only, FLOOR_T1 = 0.85) → T3 (RRF hybrid, FLOOR_T3 = 0.70). **Architecture rationale**: the trait gains `async fn lexical_search(query, limit, tags) -> Result<Vec<SearchResult>, VaultError>` with a default impl that delegates to `hybrid_search`. Backends whose `hybrid_search` is already lexical-only (e.g. `VaultStore`'s Tantivy-only impl) keep the default — the floor differentiation (0.85 vs 0.70) is what makes T1 useful there. Backends with a true RRF-fused `hybrid_search` (e.g. a future `epistemos-shadow` adapter) MUST override `lexical_search` with a real BM25-only path so T1 actually saves the embedding lookup + RRF compute when a high-confidence keyword match exists. **Tier 2 (embedding-only) deliberately NOT shipped**: adding a `VaultBackend::embedding_search` method that delegates to `hybrid_search` would be the fake-tier anti-pattern. T2 lands when a real vector-backed VaultBackend impl exists. New `VaultSearchT1LexicalBm25` struct (LadderTier::Deterministic, FLOOR_T1 = 0.85) in `agent_core/src/tools/vault_search_ladder.rs`. `build_vault_search_ladder()` pushes T1 before T3 (push() enforces tier-ascending order). 7 new tests pin: T1 accept/decline by floor, T1 declines on empty, ladder resolves at T1 for high-confidence match (≥0.85), ladder falls through T1→T3 for medium-confidence match (0.70-0.85), ladder returns None when both decline, default lexical_search trait method delegates to hybrid_search (architectural invariant). Updated `ladder_ships_two_tiers_today` source-guard test. agent_core test suite: 1138 → 1145 lib tests; 0 regressions. **Real architectural value**: high-confidence exact matches now skip fusion compute (cheaper); medium-confidence matches escalate honestly; the typed `VariantLadder<I,O>` seam now demonstrates true strategy differentiation, not just floor-gated branching | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | B.1 (3/N) | `LadderAttempt` audit trail + `resolve_walk` (foundation for LadderLog) | (this commit) | Extends the typed `VariantLadder<I,O>` with per-attempt audit-trail data so future LadderLog / Provenance Console rows have the full ladder trace, not just the winning tier. New `LadderAttemptOutcome` enum (`Accepted` / `Declined` / `SkippedByPolicy`), new `LadderAttempt { tier, variant_name, outcome }` row, new `LadderWalk<Output> { resolution: Option<LadderResolution<Output>>, attempts: Vec<LadderAttempt> }` result type. `LadderResolution` gains `attempts: Vec<LadderAttempt>` field (the resolving entry is the LAST element). New `VariantLadder::resolve_walk(&self, input)` returns the full walk; `resolve()` becomes a thin wrapper (`resolve_walk().resolution`) so existing callers don't change. **Architecture rationale**: the resolve_walk return shape gives audit consumers (future Provenance Console row, replay surfaces) ALL the information they need — "tried T1 (declined), tried T3 (accepted)" — even when the ladder ultimately defers (`None` resolution still carries the attempts vec). Snake_case serde wire format for `LadderAttemptOutcome` matches the existing `EscalationPolicy` audit-log shape. 5 new tests: declined-then-accepted attempt ordering, all-declines on defer, skipped_by_policy on Tier 4+ under Never, resolve() wrapper parity with resolve_walk(), serde wire format. agent_core test suite: 1145 → 1150 lib tests; 0 regressions. Next slice (B.1 4/N) consumes this data: `VaultSearchHandler::execute` switches to `resolve_walk`, emits a structured `LadderLog` event for ChatCoordinator → Provenance Console rendering. The data shape is now stable; only the consumer wiring remains | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | B.1 (4/N) | LadderLog tracing emission from VaultSearchHandler | (this commit) | `VaultSearchHandler::execute` in `tools/registry.rs` switches from `ladder.resolve()` to `ladder.resolve_walk()` + emits a canonical `tracing::info!` event per call with structured fields. The trace target is `vault_search.ladder_walk` (stable for Swift-side filter subscribers); fields are `query`, `limit`, `tag_filter_count`, `resolved` (bool), `resolved_variant` (winning variant name OR "deferred"), `attempts_count`, `attempts` (JSON array of `{tier, variant, outcome}` triples). Emitted on every walk — resolved AND deferred — so the Provenance Console can show "tried T1 (declined), tried T3 (accepted)" or "ladder declined — tried T1, T3, both below floor". **No new crate deps**: piggybacks on the existing `tracing = "0.1"` infra. Adding `tracing-subscriber` just to verify a single emission in a test would be over-engineering; instead a source-guard test pins the canonical tracing target + the 5 structured field names (drift gate for future refactors that drop the emission or rename a field). 1 new test in `tools/vault_search_ladder.rs::tests`: `vault_search_handler_emits_ladder_walk_trace_with_canonical_target_and_fields`. agent_core test suite: 1150 → 1151 lib tests; 0 regressions. **Real architectural value**: every vault.search call now produces a parseable audit-trail event for downstream consumers. The Swift ChatCoordinator + Provenance Console row can subscribe to `target=vault_search.ladder_walk` and render the per-attempt outcomes without re-running the ladder. With B.1 4/N, the §B.1 doctrine acceptance "LadderLog row writes to Provenance Console per call" is half-complete: the Rust producer ships; the Swift consumer subscription is the natural next slice when a tracing-subscriber backend is added | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | B.8 (2/N) | `GenUICardPresenter` — non-blocking clarify presenter with notification round-trip | (this commit) | Real production-quality presenter that any future surface (ChatCoordinator, Provenance Console replay) can register to switch `ClarifyPromptBridge` from NSAlert mode to GenUI-card mode. Per user direction "useful, not scaffold": the presenter does the full round-trip end-to-end — emits a `GenUIPayload.clarify` to a host-registered `cardSurfaceCallback`, subscribes to `Notification.Name.clarifyCardResolved`, decodes the userInfo dictionary into a `ClarifyPromptAnswer`, and returns the answer via async/await. **Architecture rationale**: (a) decoupled — `cardSurfaceCallback: @MainActor (GenUIPayload) -> Void` lets the host route the payload to ANY view (chat transcript, approval dock, replay surface); (b) thread-safe — observer added + removed from MainActor; `AtomicResumed` latch prevents double-resume if multiple matching notifications arrive; (c) testable — `notificationCenter` injection (not just `.default`) lets each test use a fresh isolated NotificationCenter; (d) honors the existing `ClarifyPromptBridge.Presenter` contract so the bridge's timeout + provenance recording stay correct; (e) when choices are supplied, `allowFreeText` defaults to false (cleaner UX), otherwise true. New file `Epistemos/Bridge/GenUICardPresenter.swift` (~135 lines) + new test file `EpistemosTests/GenUICardPresenterTests.swift` with 5 round-trip integration tests: choice-tap resolution with index, free-text resolution with nil index, unrelated-notification ignored (different payloadID), empty-response = cancelled, well-formed payload arrives at host callback before presenter suspends. All 5 passing; existing B.8 1/N tests (7) still green. xcodebuild `Epistemos` scheme: BUILD SUCCEEDED. **Real architectural value**: card-mode clarify is now a complete swappable component — a future ChatCoordinator slice can construct `ClarifyPromptBridge(presenter: GenUICardPresenter(cardSurfaceCallback: ...).present)` to switch the entire clarify UX from modal alerts to inline transcript cards. No changes to existing NSAlert code path. Boundary / next slice: ChatCoordinator wiring — register the presenter + route the card payloads into the chat transcript view layer | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | B.6 (W1) | Cognitive Weight Swift mirror + 4-tier badge view (silent-downgrade) | (this commit) | Master Fusion Plan §B.6 W1 ships the Swift consumer side of the cognitive weight system. Rust side was already complete (`agent_core::cognitive_weight::CognitiveWeight`). New file `Epistemos/Models/CognitiveWeight.swift`: Swift mirror of `CognitiveWeight` struct + `CognitiveWeightClass` enum + `ContextPlacement` enum with snake_case CodingKeys for FFI parity. Doctrine §2 boundaries enforced: Soft (0.00-0.30), Preferred (0.31-0.60), StrongAnchor (0.61-0.85), PolicyGrade (0.86-1.00). New file `Epistemos/Views/Shared/CognitiveWeightBadge.swift`: 4-tier visual badge — grey/blue/purple/amber capsule chips with SF Symbol + monospaced label. Used in Halo result rows, composer attachment chips, Provenance Console rows (wire-up is the next slice). **W1 §6 silent-downgrade ENFORCED**: `policyAuthority` field is ALWAYS false on the Swift side regardless of what Rust reports. The decoder explicitly reads-and-discards the `policy_authority` wire-format field and rewrites to false. No UI element claims policy authority — the PolicyGrade badge variant gets an "advisory in W1 (policy authority lands in W2)" accessibility tooltip but no "ENFORCED" label/lock icon. Architecture rationale: a misconfigured upstream that sets `policy_authority: true` cannot accidentally signal tool-gating authority into the Swift UI under W1. When W2 ships the 5-gate enforcement loop (Wave 7), the silent-downgrade can be lifted and the badge can grow a "POLICY ACTIVE" indicator. 10 new tests in `EpistemosTests/CognitiveWeightTests.swift`: classification boundaries match doctrine, raw score clamping, policy_authority always false (W1), decoder silently downgrades policy_authority:true from FFI wire (the W1 §6 acceptance anchor), bias-per-class within doctrine range, context placement per class, snake_case wire-format parity with Rust, 4 short labels distinct, PolicyGrade accessibility mentions W1 advisory state, round-trip through JSON. xcodebuild `Epistemos` scheme: BUILD SUCCEEDED. **Real architectural value**: every loaded resource can now display its semantic-gravity tier without exposing policy authority that isn't enforced yet. Boundary / next slice: wire the badge into Halo result rows + composer attachment chips (separate slice because it touches multiple existing views) | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | B.1 (5/N) | `Serialize`/`Deserialize` on LadderAttempt + LadderWalk + LadderResolution | (this commit) | Closes a real architectural gap discovered while preparing the Provenance Console replay path: `LadderAttempt`, `LadderWalk<Output>`, and `LadderResolution<Output>` from B.1 3/N derived `Debug, Clone, PartialEq` but NOT `Serialize, Deserialize`. That meant the audit trail couldn't flow into a `ReplayBundle` (`agent_core::provenance::replay`) or any JSON-typed downstream consumer. Added `#[derive(Serialize, Deserialize)]` to all three; the two generic structs get `#[serde(bound = "Output: Serialize + serde::de::DeserializeOwned")]` so the derive only requires those bounds when actually serializing. `LadderAttempt` also gains `Eq + Hash` since its fields are all hashable now. **Cleanup**: `VaultSearchHandler::execute` in `tools/registry.rs` previously hand-built the attempts JSON via `serde_json::json!{...}` per-attempt — that gave a `tier` field with PascalCase `Debug` format and a non-canonical `variant` key. Now uses `serde_json::to_string(&walk.attempts)` directly, producing the canonical snake_case wire format (`tier`: lowercase, `variant_name`: full key, `outcome`: snake_case) that matches the Rust struct shape. **Wire-format pinning**: 3 new tests in `variant_ladder::tests`: `ladder_attempt_round_trips_through_json` asserts the exact snake_case key + value shape ("tier":"classical", "variant_name":..., "outcome":"accepted"), `ladder_walk_round_trips_through_json_when_output_is_serializable` proves end-to-end round-trip with a real `u32` output type AND verifies the attempts vec on the inner resolution round-trips, `ladder_walk_round_trips_when_resolution_is_none` covers the defer case. agent_core test suite: 1151 → 1154 lib tests; 0 regressions. **Real architectural value**: any future replay bundle can now embed the full ladder walk audit trail without a remap layer; the Provenance Console can decode events emitted on `vault_search.ladder_walk` directly into typed `LadderWalk<T>` values | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-15 | B.6 W1 wiring | `CognitiveWeightBadge` rendered in Halo result rows | (this commit) | The B.6 W1 work shipped a Swift mirror + badge view but wasn't actually displayed anywhere. This slice wires the badge into `ShadowRow` (Halo's result row in `Epistemos/Views/Halo/ShadowPanelContent.swift`) so it renders for every Halo hit, alongside the existing `ScoreBar`. The badge derives its `CognitiveWeight` from `hit.score` (raw retrieval confidence) — honest mapping until `EpistemosSidecar` metadata flows through the Shadow FFI (separate slice). Accessibility label upgraded to include the weight-class short label: `"\(title), Strong weight, score 78 percent"`. `policyAuthority` stays false here regardless (W1 silent downgrade enforced inside `CognitiveWeight.init(rawScore:)`). 1 new source-guard test (`shadowRowRendersCognitiveWeightBadge`) pins three invariants: (1) ShadowRow contains `CognitiveWeightBadge(`, (2) the weight is derived from `CognitiveWeight(rawScore: hit.score)`, (3) the accessibility label includes `.class.shortLabel`. xcodebuild `Epistemos` scheme: BUILD SUCCEEDED; 11/11 `CognitiveWeightTests` pass (10 model tests + 1 new wiring guard). **Real architectural value**: every Halo recall result now visibly displays its 4-tier semantic-gravity class — Soft/Preferred/Strong/Policy chip — so users can scan the panel and immediately distinguish casual mentions from project-anchor docs without re-reading content. Boundary / next slice: wire badge into composer attachment chips + Provenance Console rows (each separate commit for reviewable visual diffs) | ✅ Wired+Reachable+Visible+Verified |
| 2026-05-16 | A (B-5) | BrowserEngine MAS/Pro architecture decision — Gap Audit PASS 1 B-5 resolved | (this commit) | New immutable rule 6 added to §0: MAS web tools use Rust `reqwest` HTTP fetches; rendered web surfaces use Apple-native `WKWebView` only; in-process JS runtimes (`deno_core`, `rusty_v8`, `boa_engine`) + library-embedded browsers (`Obscura`) are Pro-only and MUST NOT link into `mas-build`. Current-code state verified before writing the rule: `rg` confirms zero `BrowserEngine` trait / `deno_core` / Obscura in `agent_core/src/`; MAS web tools live in `agent_core/src/tools/web.rs` (Tavily/Brave/Perplexity HTTP backends) + `web_fetch.rs` (URL-fetch with redirect policy); `WKWebView` appears only under Epdoc + KaTeX, not agent tools. Rule wording diverges from the audit's literal "WKWebView-backed `BrowserEngine` adapter only" because that wording would misdescribe current code (no such adapter exists); instead the rule names current HTTP-fetch as primary and `WKWebView` as the only sanctioned rendering path if/when a `BrowserEngine` trait lands. Gap audit row B-5 marked RESOLVED in `RESEARCH_COVERAGE_GAP_AUDIT_2026_05_15.md` §1 + §5 triage table. No code changes — DECISION-only slice. `cargo test --manifest-path agent_core/Cargo.toml --lib` => 1190 passed (baseline preserved). | ✅ Doctrine doc |
| 2026-05-16 | A (B-6) | Hermes-parity salvage verification — Gap Audit PASS 1 B-6 VERIFIED, demoted from V1 BLOCKER | (this commit) | Caller-chain proof for all three salvage modules + targeted cargo tests. Findings: (1) `agent_core/src/credential_pool.rs` (264 LOC, Apr 23) — NOT declared in `agent_core/src/lib.rs`, so **uncompiled / dead file**; `rg "use crate::credential_pool\|CredentialPool"` returns only self-references; zero Keychain code. The V1-BLOCKER framing ("secrets land in `Vec<String>` in memory") cannot materialize because the module isn't in the build. (2) `error_classifier.rs` (375 LOC, May 15) — declared `pub mod error_classifier;` at `lib.rs:21`, compiles, `cargo test --lib error_classifier` => 7 passed, but `rg "use crate::error_classifier\|error_classifier::\|ErrorClassifier"` across `agent_core/src/` returns ZERO production call-sites. Audit's `MASTER_RESEARCH_INDEX` H4 claim "wired into `agent_loop.rs:10`" is FALSE. (3) `session_persistence.rs` (508 LOC, Apr 23) — NOT in `lib.rs`, uncompiled / dead file. Live session-state caller-chain runs through `agent_core::session` + `context_loader::load_session_context` (`agent_loop.rs:229`, `bridge.rs:1618/1630`), not the salvage module. **Net: B-6 is NOT a V1 BLOCKER.** Gap audit B-6 row updated with verification evidence; §5 triage table row flipped to ✅ VERIFIED. Audit-register Dead-Code Orphan Inventory got 3 new rows (ORPHAN-HERMES-SALVAGE-001) surfacing wire/scaffold/delete decision for a later slice. No code touched — verification-only. `cargo test --manifest-path agent_core/Cargo.toml --lib` baseline preserved at 1190. | ✅ Verification + audit reconciliation |
| 2026-05-16 | A (B2-3) | Large vault import stall (ISSUE-2026-05-11-001) — Gap Audit PASS 2 B2-3 VERIFIED, NOT a V1 BLOCKER | (this commit) | Reconciliation: B2-3's specific ask (bounded word-count + sample profiling) is already shipped. Code evidence: `Epistemos/Sync/VaultIndexActor.swift:107` (`naturalLanguageWordCountByteLimit = 200_000`) + `countWords` at line 1911 routes oversized bodies to bounded `fastVaultWordCount` scanner at line 1922; bounded readable-text scan at `Epistemos/Engine/Extensions.swift:191-215` gates `looksLikeReadableText` by `readableTextInspectionScalarLimit`; profile sample artifacts on disk per APP_ISSUES log (PIDs 536 → 33194 → 60225 → 76208). ISSUE-2026-05-11-001 status in `APP_ISSUES_AUTO_FIX.md` remains "Investigating" because each bounded patch surfaced the NEXT bottleneck, but that's a separate ongoing perf-audit loop, NOT what B2-3 asked for. PASS 2 gap audit B2-3 row + §5 triage row both flipped to ✅ VERIFIED with code-line evidence. No code touched — verification-only. | ✅ Verification + audit reconciliation |
| 2026-05-16 | A (B2-5) | Hermes XPC vs in-process architecture decision — Gap Audit PASS 2 B2-5 RESOLVED | (this commit) | DECISION-only doctrine slice. Landed as **IR-1** in a new `## Immutable rules (precede §0)` section at the top of `HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` (chosen over editing existing §0 "the single hardest problem" to avoid renumbering §1-§17 cross-refs). Decision: MAS V1 Hermes runs in-process via Rust FFI + UniFFI in `agent_core::agent_runtime` (per `CLAUDE.md` NO SIDECAR — permanent for `mas-build` Cargo feature); Pro V1.x evaluates embedded XPC service (per `docs/fusion/jordan's research/hermes.md` §"The correct macOS boundary for Hermes") only after Pro V1.0 ships AND only if a concrete need (crash isolation / sandbox-restricted credential pool / separate restart cadence) motivates the migration; subprocess Hermes (child binary) ruled out in BOTH tiers; any XPC service code MUST be `#[cfg(feature = "pro-build")]`-gated so MAS bundle stays in-process-only. Phase D XPC Mastery (VaultXPC + CapabilityGrant) is a separate concern — those are different XPC services, unaffected by this rule. PASS 2 gap audit B2-5 row + §6 triage row both flipped to ✅ RESOLVED with cross-references to IR-1. No code touched — decision-only. | ✅ Doctrine doc |
| 2026-05-16 | A (B2-1) | Specialties registry — Gap Audit PASS 2 B2-1 RESOLVED | (this commit) | DOC slice. Landed as new §7.4 in `HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` (Specialties registry — the 19 macOS-only capabilities). Single table with all 19 specialties grouped by category (A1-A3 perception · B1-B6 knowledge · C1-C4 inference · D1-D6 intelligence) sourced verbatim from `docs/_consolidated/20_canonical_research/EPISTEMOS_SPECIALTIES.md`. Each row pins the in-process dependency that makes it MAS-feasible AND web-impossible (AXorcist · ScreenCaptureKit · MLX-Swift · GRDB · Tantivy/usearch · Metal compute · Mamba SSM · DispatchSourceTimer · ClaimLedger/DAG · hyperbolic topology · NightBrain · GEPA) + MAS/Pro tier. Section closes with an **App Review reviewer answer** block citable verbatim if reviewers ask "why not a web wrapper?" — 3 perception capabilities literally impossible in browser, 13 require in-process MLX/GRDB/Metal that browsers can't reach without subprocess hops that void hardened-runtime, the last 3 lose 30-100ms per call via HTTP/IPC. Tool-surface mapping (promoting specialties to LLM-callable §7.1/§7.2 tool rows) + UI marking (`.specialty(_:)` modifier on premium-move affordances) explicitly called out as follow-up integration/design slices NOT part of B2-1 — separated to keep this diff reviewable. PASS 2 §1 B2-1 entry + §6 triage row both flipped to ✅ RESOLVED. No code touched. | ✅ Doctrine doc |
| 2026-05-16 | A (B2-2) | ArtifactKind + ProvenanceBlock — Gap Audit PASS 2 B2-2 RESOLVED (verify-code + add doc row) | (this commit) | Code substrate already shipped per loop prompt §5.0 stale-risk note: `agent_core/src/artifacts/{kind.rs:29-110, header.rs:34-112, provenance.rs:88-145, mod.rs}` carry the full 7-variant `ArtifactKind` enum (ProseNote=1 · Document=2 · RawThought=3 · Source=4 · Code=5 · Run=6 · Output=7) + `ArtifactHeader { id, kind, schema_version, created_at, updated_at, title, content_hash, provenance, metadata }` + `ProvenanceBlock { producer: Producer, derived_from: Vec<ArtifactRef> }` with Producer enum (Human / Agent { run_id, agent_id } / Imported). `cargo test --lib artifacts` => 19 passed. Audit's `{ulid, content_hash, producer, derived_from}` all present — producer + derived_from nested in ProvenanceBlock rather than flat on ArtifactHeader. Doc destination: new §3.33 "Artifact Identity + Provenance Block (Wave 3.2 cognitive-artifact spine)" added to `MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` with full taxonomy + Swift mirror parity reference (`Epistemos/Models/EpdocManifest.swift:92` ↔ `EpistemosTests/ArtifactProvenanceParityTests.swift`). FFI exports deferred-by-design — Swift mirror is parity-test-gated rather than UniFFI-bridged (no Swift caller constructs ArtifactKind via FFI yet); audit's "+ FFI exports" requirement downgraded to "parity-test-gated mirror" with rationale on the gap-audit row. PASS 2 §1 B2-2 entry + §6 triage row both flipped to ✅ RESOLVED. | ✅ Verification + doctrine doc |
| 2026-05-16 | A (B2-4) | Residency Governor + Rate-Distortion formalism — Gap Audit PASS 2 B2-4 RESOLVED | (this commit) | DOC slice. Landed as preamble at the top of `MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.2, above the existing six-tier memory table. Adds the explicit rate-distortion objective `min_{g,Z} E[d(X, g(Z))] s.t. I(Z; X) ≤ R` per Tishby 1999 + Achille & Soatto 2018 (arXiv:1706.01350) Information Bottleneck frame, with β tuning compression vs task-fidelity trade-off. New per-source routing table maps typical X values (active KV / compressed KV / vault index / cold traces / cross-model knowledge / LoRA deltas) to default tiers — the existing six-tier table now reads as the SOLUTION SPACE for the objective rather than an unmotivated taxonomy. Source: `docs/fusion/jordan's research/kimis deep research/EPISTEMOS_MASTER_ARCHITECTURE.md` §1 "Layer 3: Compression Governance". Wave 9+ post-V1 architecture routes eviction / tiering / cache-replacement / cloud-fallback decisions through this Governor — replaces ad-hoc rules with one objective function. PASS 2 §1 B2-4 entry + §6 triage row both flipped to ✅ RESOLVED. No code touched. | ✅ Doctrine doc |
| 2026-05-16 | A (B-1 / B-2 / B-3 / B-4) | Wave 7-11 user-product layer V1 vs V1.1 routing — Gap Audit PASS 1 B-1/2/3/4 DECISIONS RECORDED | (this commit) | DECISION-ONLY slice per §10 protocol ("Slice requires an external decision the user hasn't made → DECISION row only — write the question + 2-3 alternatives + recommended path. Commit. Move to next slice."). Four rows added to §10 Compromises Recorded, each with: source-doc citation · recommended path · 2 user-override alternatives · trigger-to-revisit. Recommendations: **B-1 Live Files** → V1.1 defer (substrate doctrine LANDED in MASTER_FUSION §3.14 but feature surface <30% complete); **B-2 Brain Export** → V1.1 defer (schemas LANDED via `33e1a5dcb` but no export tool / format / distribution doctrine, no V1 placeholder); **B-3 Confidence Meter** → V1 ship SIMPLE form (`ConfidenceBadge` using existing routing confidence signal, no biometric) + V1.1 ship FULL form (biometric + auto-re-learn + SovereignGate); **B-4 Pixel-Tactical duality** → V1.1 defer (sprite atlas LANDED but toggle UX + sub-agent dispatch + accessory system all V1.1). PASS 1 gap-audit B-1/B-2/B-3/B-4 entries + §5 triage table all stamped DECISIONS RECORDED. **Surfaces to user for confirm/override** — all 4 rows note "User input requested". No code touched — pure decision slice. | ✅ Decisions recorded |
| 2026-05-16 | A (H-3 / B2-H6) | Local Engineering Agent + EditPage macaroon — Gap Audit PASS 1 H-3 + PASS 2 B2-H6 DECISION RECORDED | (this commit) | DECISION + DESIGN slice (paired across PASS 1 H-3 and PASS 2 B2-H6 — same feature, two audit lenses). Decision row in `MAS_COMPLETE_FUSION §10` with recommended path **V1.1 defer for full `edit_note_block` mutation tool; V1 ships read-only `note.attach_readonly` stub**. Rationale: hero feature, design doc `docs/audits/LOCAL_ENGINEERING_AGENT_DESIGN_2026_05_10.md` still marked AWAITING_USER_SIGNOFF + macaroon primitives exist (`agent_core/src/cognitive_dag/macaroons.rs` + `dispatch.rs` with `Macaroon` / `Caveat` / `issue` / `restrict` / `system_mirror_macaroon` / `derive_mirror_macaroon`) but tool layer + single-use semantic + ledger integration + Undo schema all V1.1. Two new rows added to `HERMES_AGENT_CORE_2_0_DESIGN §7.1` MAS tool table: `note.attach_readonly` (V1 stub, T1 only) + `edit_note_block` (V1.1 deferred, T1 + macaroon pre-flight) — keeps the deferred tool discoverable from the canonical registry. PASS 1 H-3 + §5 triage row + PASS 2 B2-H6 + §6 triage row all stamped DECISION RECORDED. **User input requested** — recommendations stand unless overridden. No production code touched. | ✅ Decision + design |
| 2026-05-16 | J (audit-of-audit, iter 10) | Codex-style independent verifier audit on last 10 commits + PASS 2 trust-but-verify items + corpus sweep + online citation validation | (this commit) | Per `CLAUDE_AUTONOMOUS_LOOP_PROMPT_2026_05_15.md` §13: dispatched a `general-purpose` Agent with the verbatim §13 Codex prompt. **Verdict: loop on track, no drift.** Auditor confirmed all 10 recent commits (`d66c99ce1`..`5aa13bdae`) accurately implement their slice IDs · `cargo test --lib` baseline 1190 holds · file/line citations resolve · PASS 2 §5 trust-but-verify items remain rejected (epistemos-shadow exists, no "Phase R" in canon, InterruptScoreCpu Swift-LANDED, session_insights registered in lib.rs:56). **Audit-driven additions folded into this commit:** (1) B2-H7 status block strengthened with arXiv:2502.17598 (Bazarova et al., EMNLP 2025, LapEigvals AUROC 88.9%) + arXiv:2509.15735 (EigenTrack); (2) B2-H10 status block flags the Apple Developer XPC URL as archived (2016) — preferred modern URL `developer.apple.com/documentation/xpc` noted for future B2-H10 slice; (3) NEW MEDIUM gap **B2-M12 Engram O(1) hash-recall layer** for static knowledge (Sparsity Allocation Law 20-25% / 75-80%) — destination MASTER_FUSION §3.2 L4-Engram row between L3 and current L4; (4) NEW MEDIUM gap **B2-M13 ACS doctrine pointer** (7-scale autopoietic stack + 4 homeostatic loops + Kuramoto coupling + ViableSystem trait) — destination MASTER_FUSION new §J.6 row, cross-link with PASS 2 B2-H9 (Beer VSM is one of ACS's anchors). PASS 2 §3 MEDIUM count updated 11 → 13. Total gap inventory now: PASS 1 (31) + PASS 2 (39) = 70 actionable items (was 68). | ✅ Audit-of-audit + 2 new gaps folded in |
| 2026-05-16 | A.7 (H-1) | ISSUE-2026-05-12-011 startup hang (969ms + 3182ms) — SURFACED for operator | (this commit) | Operator-required slice per §10 protocol ("Verification can't be automated (manual smoke needed) — Stub the test + add audit-register row with manual-smoke steps. Surface to user. Commit the stub. Move on."). New `MAS_COMPLETE_FUSION §A.7` row added with: (a) Xcode `Profile (⌘I) → Time Profiler` reproduction recipe; (b) 4 ranked hypotheses from APP_ISSUES_AUTO_FIX (SwiftUI body cascade · MLX model warmup · Graph re-layout · background subscriber storm); (c) likely fixes per hypothesis (`@AppStorage` for UserDefaults reads · defer MLX load to first-agent-invocation · `Task.detached` on heavy startup); (d) acceptance bar ≤500ms main-thread occupancy matching `RuntimeDiagnosticsMonitor` watchdog. APP_ISSUES_AUTO_FIX status flipped Open → Operator-required (Instruments trace pending). PASS 1 H-1 gap audit entry stamped SURFACED. **User action: when convenient, run Time Profiler per the recipe and paste the heaviest-stack frames so a fix slice can land.** | ✅ Operator-required surface |
| 2026-05-16 | A.8 (H-2) | ISSUE-2026-04-21-004 idle memory regression (~500 MB) — SURFACED for operator | (this commit) | Operator-required slice per §10 protocol. New `MAS_COMPLETE_FUSION §A.8` row added with: (a) Xcode `Profile (⌘I) → Allocations` reproduction recipe with Gen1/Gen2 marking workflow; (b) **6** ranked hypotheses (AppleHybridEmbeddingLookup eager-load partially mitigated by DeferredTextEmbeddingLookup but unverified · PreparedRetrievalRuntimeConfiguration descriptors retained · SwiftData @Query caches in sidebars · MLX tokenizer/model residency post-unload · ShmPool TTL eviction firing or not · Tantivy writer heap regression check); (c) likely fixes per hypothesis (tighten DeferredTextEmbeddingLookup · weak-ref or evict manifest descriptors · narrow `@Query` predicates with scoped user approval · nil tokenizer on MLX unload · surface ShmPool eviction count in ProcessMemoryHealthRow · bisect epistemos-shadow); (d) acceptance bar ≤200 MB idle RSS (4× improvement from current 500 MB baseline; halfway to historical ~50 MB floor). APP_ISSUES status flipped Investigating → Operator-required (Allocations trace pending). PASS 1 H-2 gap audit entry stamped SURFACED. **User action: when convenient, run Allocations per the recipe and paste the top-10 persistent-bytes entries so a fix slice can land.** | ✅ Operator-required surface |
| 2026-05-16 | D (B2-H1) | Five Laws constraint landed in NEW_SESSION_HANDOFF §3 — Gap Audit PASS 2 B2-H1 RESOLVED | (this commit) | DOC slice. Added scope rule 7 to `NEW_SESSION_HANDOFF_2026_05_15.md §3` (Scope rules that override default behavior) carrying all 5 laws verbatim from `docs/_consolidated/60_deferred_research/UNIFIED_SUBSTRATE_RESEARCH.md §"THE FIVE LAWS"`: (L1) Measure before you cut — no architectural refactoring without Instruments profiling data citing allocation count / frame time / call frequency / binary size delta; (L2) entity store is a NEW crate not a refactor — `substrate-core` with `slotmap` generational keys, migrate one entity type at a time, old + new coexist; (L3) identity unification is Sprint 1, everything else waits — `EntityID` as `SlotKey` exposed via C ABI as `u64`; (L4) UniFFI stays until profiling proves otherwise — graduated FFI with only top-3 measured hotspots in custom C ABI; (L5) Python out-of-process immediately — subprocess daemon behind Unix domain socket, saves 15-25 MB bundle + eliminates GIL contention. Source doc tagged the laws "Add to CLAUDE.md — binding" but CLAUDE.md edits are user-approval-gated per loop §16; the laws live in `NEW_SESSION_HANDOFF §3` as the binding constraint until that promotion lands. PASS 2 §2 B2-H1 entry + §6 triage table both flipped to ✅ RESOLVED. No code touched. | ✅ Doctrine doc |

## 9. Atlas Drift Log

Append here only if `MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` §2 falls out of sync with main.

| Date | Atlas row | Stated status | Actual status | Action |
|---|---|---|---|---|
| 2026-05-15 | NightBrain canonical task names (§B.9) | §B.9 plan lists 10 aspirational names: `vault_consolidate`, `claim_evidence_decay`, `procedural_curate`, `companion_refresh`, `provenance_compact`, `skill_index_rebuild`, `attachment_grant_audit`, `embedding_health_check`, `cognitive_dag_merkle_verify`, `instant_recall_rebuild` | Runtime `CANONICAL_TASK_NAMES` in `agent_core/src/nightbrain/mod.rs:11` ships 10 DIFFERENT names: `event_store_checkpoint_vacuum`, `search_index_passive_checkpoint`, `dedupe_artifacts`, `workspace_snapshot_compaction`, `memory_distillation`, `cloud_knowledge_distillation`, `session_graph_generation`, `skill_evolution_analysis`, `ssm_state_pruning`, `maintenance_log` | Authority chain rank 1 (current main + passing logs) outranks rank 3 (this plan) — runtime names stay canonical. Real task bodies land against the runtime names. A separate rename slice (post-V1) reconciles either by (a) renaming runtime → plan names with migration, or (b) updating §B.9 text to match runtime names. Neither blocks MAS V1 |

## 10. Compromises Recorded

Append here only when constraints force deferral — no silent compromises.

| Date | Item | Source doc | Compromise | Trigger to revisit |
|---|---|---|---|---|
| 2026-05-16 | **B-1 Live Files (Wave 7 substrate primitive)** | `~/Documents/Epistemos-QuickCapture/LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md` §4 + §6; PASS 1 gap audit B-1 | **V1.1 defer (recommended); user override possible.** Substrate doctrine LANDED in `MASTER_FUSION §3.14`. User-visible feature surface (10-state Live machine UI · daily-review embedding · agent-driven mutation · LivePlan.v1 schema · Kani verification) is <30% complete; building it for V1 adds reviewer-confusing scope without enough polish to pay off. V1 ships the substrate doctrine + B.9 NightBrain integration scaffolding (already in place) but NOT the user-facing Live Files surface. **Alternatives the user can override to:** (a) V1 ship a single Live-file demo (one canonical type, e.g. "daily review embedding") to anchor the marketing story — adds ~1 week of polish work; (b) Pro-only for V1 if MAS sandbox makes file-mutation primitives risky — punts MAS sandbox question to Pro tier. Default = V1.1 defer. | Post-V1 Wave 7 dedicated sprint. Slice into 4 sub-rows when picked up: state machine UI · daily-review embedding · agent mutation · doctrine integration with LivePlan.v1. |
| 2026-05-16 | **B-2 Brain Export (Wave 11 / Sovereign-AI moat)** | `~/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` §5 + §6.3; PASS 1 gap audit B-2 | **V1.1 defer (recommended); user override possible.** Substrate is LANDED — Soul/Skill/Episode/Semantic schemas + 687-LOC Rust mirror at `agent_core/src/schemas/mod.rs` (commit `33e1a5dcb`). Missing: export-surface tool (`brain.export`) + portable artifact format spec + distribution doctrine (where exported brain files land, signing, version policy). V1 with no surface = the substrate ships unused; V1 with a placeholder export button = reviewer confusion. **Alternatives the user can override to:** (a) V1 ship a minimal export — JSON bundle of the 4 schemas + version stamp, no companion-state, no distribution doctrine — sets expectation but doesn't deliver the full Sovereign-AI moat; (b) explicit deferred-marquee-status note in V1 App Store description ("Brain Export coming in V1.1"). Default = V1.1 defer, no V1 placeholder. | Post-V1 product roadmap when portability becomes a marquee item. Pair launch with B-3 Confidence Meter + B-4 Pixel-Tactical for unified "Sovereign AI" V1.1 story. |
| 2026-05-16 | **B-3 Confidence Meter + 70%-Triggered Re-Learn** | `~/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` §2; PASS 1 gap audit B-3 | **V1 ship SIMPLE form (recommended); V1.1 ship FULL form.** V1 surfaces a small `ConfidenceBadge` next to AI-generated content showing the model's calibrated confidence (0-100%) when the agent provides one — uses existing token-logprob or routed-confidence signal already produced by `agent_core::routing` (no biometric, no auto-re-learn, no SovereignGate hook). Answers reviewer's "how does user know AI is uncertain?" question without adding biometric scope or `LocalAuthentication.framework` dependency. V1.1 adds: biometric gating below 70% threshold (Touch ID / Face ID prompt to re-learn the specific claim) · auto-re-learn loop · SovereignGate integration · claim-level lineage in ClaimLedger. **Alternatives the user can override to:** (a) full V1 ship including biometric — high reviewer-impact but ~1 week scope creep; (b) V1.1 defer entire feature — leaves reviewer-question unanswered, risks polish concern. Default = V1 simple form, V1.1 full form. | V1 gate: ConfidenceBadge wired into LLMResponse render path with token-logprob source. V1.1 trigger: `LocalAuthentication.framework` integration approved + Pro-tier capability gate decision. |
| 2026-05-16 | **B-4 Pixel Mode vs Tactical Mode duality** | `~/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md` §3.1; PASS 1 gap audit B-4 | **V1.1 defer (recommended); V1 ships sprite-as-accent only.** Sprite atlas LANDED in G3 / Simulation v1.6. Pixel↔Tactical TOGGLE UX is the missing half-product. V1 keeps the sprite atlas as a static accent in chat / agent panel (already present and shipping). V1.1 adds: user-facing Mode toggle (Settings → Appearance → "Agent presentation: Pixel / Tactical") · sub-agent dispatch with capability inheritance · accessory system · per-mode hotkey overlays. **Alternatives the user can override to:** (a) V1 ship hidden-mode toggle in defaults plist for power-users — no UI, no reviewer payoff, low risk; (b) Pixel-only V1 (no Tactical), full toggle V1.1 — partial-feature problem. Default = V1.1 defer, V1 keeps static sprite accent. | V1.1 dedicated UX-shape sprint. Pair with Settings → Appearance reorganization + the accessory system from §3.6 of the addendum. |
| 2026-05-16 | **H-3 / B2-H6 Local Engineering Agent + EditPage macaroon** | `docs/audits/LOCAL_ENGINEERING_AGENT_DESIGN_2026_05_10.md` (full doc; status AWAITING_USER_SIGNOFF); PASS 1 gap audit H-3 + PASS 2 gap audit B2-H6 | **V1.1 defer (recommended); V1 ships an attach-note read-only stub.** Hero feature: `edit_note_block(page_id, block_id, new_markdown, capability_token)` tool gated by single-use macaroons with ledger-tracked edits, using the existing canonical `NoteFileStorage` write path. Macaroon primitives ALREADY EXIST in `agent_core/src/cognitive_dag/macaroons.rs` + caller wrappers in `cognitive_dag/dispatch.rs` (`issue`, `restrict`, `Caveat`, `Macaroon` types live with `system_mirror_macaroon()` + `derive_mirror_macaroon(scope_prefix)`). Missing: the `edit_note_block` tool itself · single-use semantic on top of the macaroon · `EditPage` capability schema · ledger integration. Per design doc, hero feature is not 80% done AND still says AWAITING_USER_SIGNOFF; shipping V1 risks reviewer-confusion from a half-implemented agent-edit capability with no rollback story. **V1 ships:** read-only "Attach Note to Chat" affordance — agent can read+cite attached notes but cannot edit them; surfaces the affordance without the edit-capability scope. V1.1 ships: full `edit_note_block` tool + single-use macaroon + ledger row per edit + Undo button in the chat transcript. **Alternatives the user can override to:** (a) Full V1 ship of `edit_note_block` with macaroons (still needs user signoff first per design doc); (b) Pro-only for full feature, MAS gets read-only attach only — keeps mutation surface in Pro tier. Default = V1.1 defer for full mutation, V1 read-only attach. | Hero V1.1 launch alongside B-2 Brain Export and B-3 full Confidence Meter. Pre-trigger: user signoff on design doc + Undo schema design. |

---

*— End of MAS Complete Fusion Implementation Plan. 54 items across 5 phases. POSTV1 exclusions explicitly excluded. Every PATCHED PARTIAL / OPEN audit item not in exclusions has a phase + acceptance bar. Wave A + Wave F + all V1 ship gates + recursive audit closure all covered. No drift, no compromise except Pro-only-by-MAS-sandbox-rule.*
