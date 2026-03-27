# Epistemos v2 Release Audit — Instructions for Codex

> **Historical snapshot:** This audit prompt predates the later non-agent pruning pass, the TK2-only production editor cutover, and the current V1 scope boundary. Read any deleted editor/dialogue-surface references below as historical context, not current production architecture.

> **Purpose:** Systematic audit of the entire Epistemos codebase to determine readiness for a v2 official release. This document tells you exactly what to check, what the current state is, and what "release-ready" means for each area.

---

## How to Use This Document

1. **Read `docs/codex-memory.md` first** — it gives you full app context, architecture, patterns, and anti-patterns.
2. **Read `CLAUDE.md` at repo root** — engineering bible with all patterns and rules.
3. **Work through each audit section below** in order. Each section has:
   - What to check
   - Where to look (exact file paths)
   - What "pass" looks like
   - Known issues to evaluate
4. **For each section, produce a verdict:** PASS / PASS WITH CAVEATS / FAIL + what needs fixing.
5. **At the end, produce a release recommendation** with a prioritized list of blockers.

---

## Audit Sections

### Section 1: Data Integrity & Persistence

**What to check:**
- Can data be lost under any normal usage scenario?
- Are all SwiftData saves properly guarded?
- Does vault sync reliably round-trip markdown ↔ SwiftData?

**Where to look:**
- `Epistemos/Sync/VaultSyncService.swift` — file ↔ model sync
- `Epistemos/Sync/NoteFileStorage.swift` — raw file I/O
- `Epistemos/Models/SDPage.swift` — core data model
- `Epistemos/Models/SDBlock.swift` — block structure
- `Epistemos/Models/SDPageVersion.swift` — version history
- `docs/bug-fixes/2026-03-03-note-saving-fix.md` — the premature save() bug and its fix

**Known issues to evaluate:**
- **W2.8: savedPapers split-brain** — `ResearchState.swift` uses UserDefaults for savedPapers while everything else is SwiftData. Is this a v2 blocker? Check: does iCloud sync affect it? Can data be permanently lost?
- **Version pruning** — Fixed (10K global limit, commit 79be726). Verify the limit is enforced.
- **Front-matter parsing** — Fixed (BOM + comments, commit f4c223a). Verify edge cases.
- **Filename collision** — Fixed (UUID suffix, commit bb53d95). Verify.
- **Note-saving bug** — Fixed (commit 7db6a00). Verify no regression.

**Pass criteria:** No scenario where user actions cause silent data loss. All saves properly persisted. Vault sync round-trips correctly.

---

### Section 2: Crash Safety

**What to check:**
- Zero force unwraps (`!`) in production paths
- Zero `try!` in production paths
- Zero `fatalError()` in reachable code paths
- All FFI calls guarded with nil engine checks
- `Int(Float)` conversions guard `.isFinite`

**Where to look:**
- Run: `grep -rn 'try!' Epistemos --include="*.swift" | grep -v Tests | grep -v '//'`
- Run: `grep -rn '\.force' Epistemos --include="*.swift" | grep -v Tests`
- Run: `grep -rn 'fatalError' Epistemos --include="*.swift" | grep -v Tests`
- Run: `grep -rn 'as!' Epistemos --include="*.swift" | grep -v Tests`
- `graph-engine-bridge/graph_engine.h` — all 68 FFI functions
- `Epistemos/Views/Graph/MetalGraphView.swift` — FFI call sites

**Known issues to evaluate:**
- **W17.13: Crash creating note** — Full code path traced (handleWikilinkClick → createPage → save → open), no race found. Needs actual crash log. Is this a v2 blocker without a reproduction?
- **Metal shader panics** — Fixed (commit b346609). Verify.
- **FFI string lifetime** — Audited safe, documented (commit b5e9e9a). Verify documentation still accurate.

**Pass criteria:** Zero crashes reachable from normal user actions. All forced operations justified and documented.

---

### Section 3: Concurrency & Race Conditions

**What to check:**
- All state classes properly `@MainActor` isolated
- No data races between SwiftUI views and background tasks
- Task cancellation works correctly (no zombie tasks)
- No deadlocks possible

**Where to look:**
- All files in `Epistemos/State/` — verify `@MainActor @Observable` on every class
- `Epistemos/Engine/PipelineService.swift` — task cancellation (lines 69-70, 101-104, 158)
- `Epistemos/Graph/GraphState.swift` — `pendingNodes`/`pendingEdges` queue + render loop drain
- `Epistemos/State/NoteChatState.swift` — streaming token buffer + accept/discard flow
- `Epistemos/State/DialogueChatState.swift` — dialogue chat state machine
- `Epistemos/Sync/VaultSyncService.swift` — background sync operations

**Known issues to evaluate:**
- **W6.1: graphDataVersion atomicity** — Audited as NOT A BUG (all access @MainActor serialized). Verify this is still true.
- **W6.3: Pipeline task cancellation** — Fixed (commit 21299e5). PipelineService now has proper dual-task tracking with FinishOnce guard. Verify.
- **W6.4: SwiftData context crossing** — Audited as NOT A BUG (@MainActor isolation). Verify.

**Pass criteria:** No observable race conditions. All state mutations serialized. Background tasks properly cancelled on new requests.

---

### Section 4: Security & Privacy

**What to check:**
- API keys stored securely (Keychain, not UserDefaults)
- No sensitive data in logs
- Spotlight doesn't leak note body content
- No iCloud sync of secrets

**Where to look:**
- `Epistemos/Engine/Keychain.swift` — key storage
- `Epistemos/Engine/Log.swift` — logging
- `Epistemos/Engine/SpotlightIndexer.swift` — what gets indexed
- `Epistemos/Views/Settings/SettingsView.swift` — how keys are configured

**Known issues (all fixed, verify):**
- **W10.1: API key iCloud sync** — Fixed (commit 8c17c42). Keys in Keychain with Data Protection.
- **W10.2: Spotlight body exposure** — Fixed (commit f4c223a). Only title + tags indexed.
- **W10.3: Vault path in logs** — Fixed (commit 9b8fc96). Paths redacted.
- **W5.5: FTS5 query injection** — Fixed (commit 8374d49). Sanitization added.

**Pass criteria:** No secret leakage. No PII in logs. Spotlight safe. Keychain properly configured.

---

### Section 5: Error Handling & Resilience

**What to check:**
- AI API failures surface to user (not silently swallowed)
- File I/O errors handled gracefully
- Network failures don't crash the app
- Graph operations fail safely

**Where to look:**
- `Epistemos/Engine/LLMService.swift` — API error handling
- `Epistemos/Engine/PipelineService.swift` — pipeline error propagation
- `Epistemos/Engine/TriageService.swift` — routing failures
- `Epistemos/Graph/GraphBuilder.swift` — graph build errors (commit f3ba40a added error surfacing)
- `Epistemos/State/NoteChatState.swift` — streaming error handling

**Known issues to evaluate:**
- **W11.1: GraphBuilder silent failures** — Fixed (commit f3ba40a). Errors now surfaced. Verify.
- **W11.2: LLM stream errors** — Rated "mostly mitigated." Stream errors surface to UI; enrichment fallbacks by design. Is this sufficient for v2?
- **W11.3: File I/O errors** — Rated NOT A BUG (error details in log object). Is logging sufficient, or should user see errors?

**Pass criteria:** No silent failures that lose user work or confuse the user. Errors either surface to UI or are genuinely safe to ignore.

---

### Section 6: Performance Under Load

**What to check:**
- App responsive with 1000+ notes
- Graph doesn't lag with 5000+ nodes
- Search completes in < 500ms
- Memory usage stays under 500MB for typical vaults
- No per-frame allocations in render loop

**Where to look:**
- `graph-engine/src/physics.rs` — tick performance (120 ticks/sec target)
- `graph-engine/src/renderer.rs` — frame rendering
- `Epistemos/Graph/GraphStore.swift` — in-memory graph (Int-indexed arrays)
- `Epistemos/Graph/GraphBuilder.swift` — build performance
- `Epistemos/Engine/PipelineService.swift` — AI pipeline latency

**Known optimizations already applied:**
- Compact Int-indexed GraphStore (~46MB savings at 50K nodes)
- Trigram index for fuzzy search (O(1) posting list intersection)
- Background graph loading (BackgroundGraphActor)
- Incremental FFI updates (pending queue + render loop drain)
- Search debouncing (150ms all entry points)
- Pre-allocated scratch buffers in physics
- Per-node highlight flag buffer
- Straight-line edges (no Bezier tessellation)
- Motion blur removed
- Render culling and LOD on ECS

**What to stress-test:**
1. Create/import 500+ notes, observe graph load time
2. Rapid search typing (< 150ms between keystrokes)
3. Multiple AI queries in quick succession (cancellation behavior)
4. Large note body (10K+ words) with live markdown highlighting
5. Graph with 3000+ visible nodes — frame rate target 60fps

**Pass criteria:** App feels responsive. No beachball cursor. No jetsam kills. Graph renders at 30+ fps with 3000 nodes.

---

### Section 7: UI/UX Completeness

**What to check:**
- All views have dark mode support
- All keyboard shortcuts work
- Window management is stable
- Empty states are handled

**Where to look:**
- `Epistemos/Theme/` — theme system, modifiers
- `Epistemos/Views/Shell/` — main window shell
- `Epistemos/App/AppBootstrap.swift` — keyboard shortcuts
- `Epistemos/Views/Notes/NoteWindowManager.swift` — window management
- `Epistemos/Views/Graph/HologramController.swift` — graph overlay window

**Known issues to evaluate:**
- **W12.1: Zero-state handling** — Reclassified OUT_OF_SCOPE during audit. For v2, is an empty state view needed when the user has no notes?
- **W17.15: Graph overlay fragility** — Uses NSWindow + manual z-order + Metal reparenting during minimize. Works but fragile. Is this acceptable for v2, or must it be NSPanel?
- **W12.2: Dark mode detection** — Fixed (commit d987851). Verify.
- **W17.10: Launch shortcuts** — Already implemented (1100×720 default, Cmd+H→landing, etc.). Verify.

**Pass criteria:** App looks polished in both light and dark mode. Core keyboard shortcuts work. Window management doesn't glitch on minimize/maximize/full-screen.

---

### Section 8: AI Features Quality

**What to check:**
- TriageService correctly routes to on-device vs cloud
- On-device inference works without API key
- Cloud inference handles missing/invalid API keys gracefully
- Note Chat streaming works end-to-end (query → stream → accept/discard)
- Dialogue mode chat works with persona system
- Daily briefs generate correctly

**Where to look:**
- `Epistemos/Engine/TriageService.swift` — routing logic
- `Epistemos/Engine/AppleIntelligenceService.swift` — on-device
- `Epistemos/Engine/LLMService.swift` — cloud providers
- `Epistemos/State/NoteChatState.swift` — note chat
- `Epistemos/State/DialogueChatState.swift` — dialogue chat
- `Epistemos/State/DailyBriefState.swift` — daily briefs

**Known issues to evaluate:**
- **SignalGenerator fake signals (W2.3)** — Generates polynomial "confidence" from regex. Should these be shown to users in v2? Or should the signal UI be hidden until real SOAR scores exist?
- **SOAR system** — Is it stable enough for v2, or should it be feature-flagged?
- **Enrichment background tasks** — Do they complete reliably or sometimes silently fail?

**Pass criteria:** Core AI features (note chat, dialogue chat, daily briefs) work end-to-end. Routing is correct. Error states are handled. No misleading signals shown to users.

---

### Section 9: Graph Visualization Quality

**What to check:**
- Classic theme renders correctly (SDF circles, smooth lines, proper colors)
- Dialogue theme activates correctly (overlay appears, Metal infrastructure works)
- Node selection/highlighting works
- Search highlighting works in graph
- Cluster detection works
- Physics simulation stabilizes (doesn't endlessly restarts)

**Where to look:**
- `graph-engine/src/renderer.rs` — rendering
- `graph-engine/src/physics.rs` — simulation
- `Epistemos/Graph/GraphState.swift` — state management
- `Epistemos/Views/Graph/MetalGraphView.swift` — view integration
- `Epistemos/Views/Graph/GraphFloatingControls.swift` — UI controls

**What to test:**
1. Switch between classic and dialogue themes
2. Click nodes — verify highlight + neighbor dim
3. Search in graph — verify result highlighting
4. Zoom in/out — verify LOD transitions
5. Let graph settle — verify physics stabilizes
6. Hover nodes — verify field lines appear
7. Open dialogue on a node — verify overlay appears with correct archetype

**Pass criteria:** Graph is visually polished. No rendering glitches. Theme switching works. Physics feels natural.

---

### Section 10: Build & Test Infrastructure

**What to check:**
- Swift tests pass (target: 1404 tests, 194 suites)
- Rust tests pass (target: 549 tests)
- App builds without warnings (or only expected warnings)
- No dead imports or unused variables

**Commands:**
```bash
# Swift tests
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test

# Rust tests
cd graph-engine && cargo test

# Build check
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build

# Clippy (Rust lint)
cd graph-engine && cargo clippy -- -W clippy::all
```

**Pass criteria:** All tests pass. Build succeeds. No new warnings introduced.

---

### Section 11: Code Health & Technical Debt

**What to check:**
- Dead code inventory (what's there intentionally vs accidentally)
- Unused features that should be removed or feature-flagged
- Code duplication that should be extracted
- TODOs that represent real work vs aspirational notes

**Where to look:**
- `graph-engine/src/renderer.rs` — dialogue Metal code (intentionally kept for .dialogue mode)
- All `// TODO:` comments across the codebase
- `Epistemos/Engine/SignalGenerator.swift` — ~500 LOC of fake signals
- `Epistemos/State/EventBus.swift` — only 3 subscribers, overkill pattern
- `Epistemos/Engine/SOAR/` — 12 files, potentially not stable enough for v2

**Known dead/dormant code:**
- Rust dialogue rendering (face geometry, shader, box geometry) — kept for .dialogue mode
- SOAR system — may need feature flag for v2
- SignalGenerator — produces fake numbers, misleading
- EventBus — 3 subscribers, could be direct calls

**Pass criteria:** No accidentally dead code. Unstable features are properly feature-flagged. No misleading UI elements.

---

### Section 12: Documentation & Onboarding

**What to check:**
- CLAUDE.md is accurate and up to date
- Key architectural decisions are documented
- Design docs in `docs/plans/` are current
- Bug fix documentation exists for non-obvious fixes

**Where to look:**
- `CLAUDE.md` — engineering bible
- `docs/future-work-audit.md` — 21 waves, THE BIBLE
- `docs/audit-progress.md` — audit state
- `docs/plans/` — 33 design documents
- `docs/bug-fixes/` — specific fix documentation

**Pass criteria:** A new developer can understand the system by reading CLAUDE.md + the audit docs. No critical architectural knowledge exists only in git history.

---

## Release Recommendation Framework

After completing all 12 sections, produce a release recommendation using this framework:

### Blocker Classification

| Level | Meaning | Example |
|-------|---------|---------|
| **P0 — Release Blocker** | Cannot ship with this issue | Data loss scenario, crash on common action |
| **P1 — Strong Concern** | Should fix before release, but workarounds exist | Fragile window management, fake signals shown |
| **P2 — Known Limitation** | Acceptable for v2 with documentation | SOAR not fully stable, BTK not wired |
| **P3 — Future Work** | Not expected in v2 | Explorer mode, WFC generation |

### Release Readiness Checklist

- [ ] All 12 audit sections evaluated
- [ ] Zero P0 blockers remaining
- [ ] All P1 concerns either fixed or explicitly accepted with justification
- [ ] All P2 limitations documented
- [ ] Swift tests: 1404/1404 passing
- [ ] Rust tests: 549/549 passing
- [ ] Build: clean (no new warnings)
- [ ] App tested end-to-end: create note → edit → search → graph → AI chat → close

### Final Verdict

One of:
- **READY FOR v2** — Ship it. All blockers resolved. Known limitations documented.
- **READY WITH CONDITIONS** — Ship after fixing [specific items]. List them.
- **NOT READY** — [Specific blockers] must be resolved first. Estimated effort: [time].

---

## Appendix: Prior Audit Results

The codebase has already been through a comprehensive audit (Waves 1-13, 53 items). See `docs/audit-progress.md` for the full log. The v2 release audit should build on this work, not repeat it. Focus on:

1. Verifying prior fixes haven't regressed
2. Evaluating new code added since the audit (dialogue system, persona, care state, ECS work)
3. Making release-readiness judgments on deferred items
4. Testing end-to-end user flows

### What Changed Since the Audit (2026-03-02)

**New systems added (need fresh audit):**
- DialogueChatState + persona/archetype system (~370 LOC)
- DialogueCareState (Tamagotchi health/mood)
- DialoguePresentationTheme (tactics/nocturne palettes)
- DialogueOverlayView (full SwiftUI rewrite)
- DialogueNodeProfile (content-derived persona assignment)
- ECS physics adapter
- Cluster cache + edge aggregation
- Render culling + LOD on ECS
- Graph floating controls — dialogue theme toggle
- Explorer mode design doc (not yet implemented)

**Recent commits to verify:**
```
48f5a55 fix: land pending app fixes and startup cleanup
ea40733 docs: finalize Explorer design
c11f973 feat(dialogue): add persona and care state
958ac2b fix(graph): turn dialogue into a boxed overlay
89f7129 fix(dialogue): address code quality review findings
31abeb5 feat(dialogue): wire DialogueChatState into MetalGraphView
7cb3222 feat(dialogue): add DialogueOverlayView with RetroGaming font
68498b1 feat(dialogue): add DialogueChatState for FFT-style graph chat
d94d07d feat(graph): add dialogue FFI functions for Swift bridge
0ed988c feat(graph): add Kirby-style face geometry
bb03d82 feat(graph): add DialogueState and FFT-style box shader
fd12a74 feat(graph): rename VisualTheme::Pixel to Dialogue
b1a3609 feat(graph): delete pixel art rendering infrastructure
5ad63a2 feat(graph): integrate cluster cache and edge aggregation
fc35a82 feat(graph): move render culling and lod onto ecs
```

Each of these commits introduces new code that was NOT covered by the original audit. The v2 audit must review all of them.
