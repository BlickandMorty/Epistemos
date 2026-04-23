# Audit Reflection — 2026-04-23

**Purpose:** reconcile the prior Codex audit + conversation Q&A with verified ground truth from live-code spot checks + three dedicated Explore-agent passes. Produces issue-status updates, drift corrections, and the canonical "start from here" set for execution.

**User constraint (respected):** the plan file at `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md` was NOT modified. This doc is the separate audit-reflection deliverable the user requested.

**User's 3-part execution vision:** (1) Fixes + hardening → (2) App Store polish + legitimization → (3) Pro version. Everything below is organized to serve that sequencing.

---

## Executive summary

The Epistemos codebase is **further along than the Codex audit suggested** but **behind the plan in one specific area** (Phase R UniFFI exposure). Specifically:

1. ✅ **Rust cloud agent IS wired to Swift via UniFFI** (`ChatCoordinator.swift` L564, L2005 call `runAgentSession`). The Codex audit's claim "agent_coreFFI is not linked" is wrong — `project.yml` explicitly links `-lagent_core` and includes `agent_coreFFI` in Swift paths.
2. ✅ **Swift-native `LocalAgentLoop.swift`** (1,968 lines) is production local-agent runtime with Hermes-style tool calling, reflex mode, repair loops.
3. ✅ **Omega orchestrator DEMOLITION already done** — `Epistemos/Omega/Orchestrator/OrchestratorState.swift` L4 comment: *"The full Omega orchestrator has been retired in favor of the Rust agent_core. This stub preserves the public API surface that other files reference."* I-015 can be marked FIXED.
4. ✅ **Build + test green baseline**: `xcodebuild` → BUILD SUCCEEDED; `cargo test` → 577/577 pass.
5. 🔴 **Phase R Rust module is ORPHANED**: `agent_core/src/resources/` has 1,854 lines of canonical-ID + `AliasRegistry` + `ResourceService` + `AttachmentMode` + `PermissionService` + `verified_write()`. The Codex audit was right: **zero Swift callers; not `#[uniffi::export]`'d; not in the generated FFI header.**
6. 🔴 **Key bugs CONFIRMED OPEN** by live-code verification: I-001 (model ID split-brain), I-002/003 (6+ note lookup codepaths), I-004/5/6 (snapshot-vs-live attachments), I-007/008 (7 unverified Swift write paths), I-009/010 (no Swift PermissionService bridge).

**Net:** the plan is still good. The work list is shorter than feared (Omega debt gone, agent runtime working) but more specific than previously framed (Phase R is UniFFI-export + Swift-wrapper work, not greenfield Rust).

---

## 1. Corrections against the Codex audit (with evidence)

| Codex claim | Reality (verified) | Verdict |
|---|---|---|
| "`agent_coreFFI` is not linked into production" | `project.yml` L~60 contains `-lagent_core` in `OTHER_LDFLAGS` AND `agent_coreFFI` in `SWIFT_INCLUDE_PATHS`. `/build-rust/libagent_core.dylib` exists. `/build-rust/swift-bindings/agent_coreFFI/agent_coreFFI.h` is 1,353 lines of generated bindings. `ChatCoordinator.swift` L564 + L2005 call `runAgentSession`. | **Codex was wrong.** |
| "Cloud agent loop is dead code" | See above. Cloud path via `runAgentSession` is production. | **Codex was wrong.** |
| "Swift-native `LocalAgentLoop` is the only production runtime" | Partially right — local IS Swift-native, but cloud is Rust. Hybrid runtime is the actual production state. | **Codex was partially right.** |
| "Phase R Rust code is compiled but zero Swift callers" | CONFIRMED. `grep "ResourceService\|AliasRegistry\|PermissionService\|ResourceId" Epistemos/` returns zero. `grep "ResourceService\|resources" build-rust/swift-bindings/agent_coreFFI/agent_coreFFI.h` returns zero. | **Codex was right.** |
| "R.8 model picker is more sophisticated than the plan proposes" | Partially — `LocalModelToolbarMenu` is a 5-popover system. BUT user explicitly wants it rebuilt as an NSMenu-style dropdown with real toggles, default-collapsed, compact. So R.8 is NOT complete; it's "rebuild pending mock." | **Both partially right.** |
| "Omega orchestrator still drives orchestration" | WRONG per evidence: `OrchestratorState.swift` L4 explicit comment says retired; `submitTask()` is a no-op; agent tasks route through `ChatCoordinator` → Rust. | **Codex was wrong.** |
| "Phase 1-7 bridges are completed infrastructure" | CONFIRMED. `StreamingDelegate.swift` has all 8 bridges (`perceiveApp`, `interactWithApp`, `startScreenWatch`, `manageSsmState`, `generateConstrained`, `generateImage`, `triggerNightbrainJob`, `getPartnerContext`). | **Codex was right.** |
| "B (3-mode toggle) already shipped via `EpistemosOperatingMode`" | CONFIRMED. BUT user wants profile-aware build gating (some modes Pro-only). So Phase B is "complete for shared codebase; needs per-profile gates for App Store vs Pro." | **Codex was right; plan needs gate annotation.** |

---

## 2. Known Issues Register — status update

Verified status for every issue in `docs/KNOWN_ISSUES_REGISTER.md`:

| ID | Issue | Status | Evidence |
|---|---|---|---|
| **I-001** | `gpt-5.4` vs `openai:gpt-5.4` model ID split | **CONFIRMED-OPEN** | `InferenceState.swift` L1282 stores `"openai:gpt-5.4"`; L1338-1340 returns bare `"gpt-5.4"`. `ModelInvolvementSheet.swift` L780 uses exact-match predicate. `ModelVaultsSidebarSection.swift` L972-975 uses defensive substring match (hides bug, doesn't fix it). |
| **I-002** | Multiple note lookup codepaths | **CONFIRMED-OPEN** | 6+ distinct codepaths: `agent_core/src/resources/service.rs` (Rust), `Epistemos/Sync/VaultIndexActor.swift`, `Epistemos/Sync/SearchIndexService.swift`, `Epistemos/Sync/VaultSyncService.swift`, `Epistemos/Views/Notes/NotesSidebar.swift`, raw `#Predicate` queries in `SDPage.swift`. |
| **I-003** | Duplicate read/edit/find across AI tools, sidebar, attachments, popovers | **CONFIRMED-OPEN** | Same evidence as I-002 — every UI surface has its own lookup path. |
| **I-004** | Attached notes ambiguous snapshot/live | **CONFIRMED-OPEN** | Rust `AttachmentMode::{Snapshot,Live}` exists in `agent_core/src/resources/attachments.rs`. Swift `AttachedContextResolution` struct in `ChatCoordinator.swift` has no mode field. |
| **I-005** | Popover attachments don't grant live capabilities | **CONFIRMED-OPEN** | Same root cause as I-004. |
| **I-006** | AI can't code/edit attached code files | **CONFIRMED-OPEN** | User dogfood answer: "AI claims edit but nothing changes." Root cause: no capability manifest from popover attachment to tool layer. |
| **I-007** | AI "lies" about writes (`vault_graph.json` class) | **CONFIRMED-OPEN in Swift** | Rust `verified_write()` at `agent_core/src/runtime/write_pipeline.rs` L161 works. Swift has 7 unverified write paths: `NoteFileStorage.writeBody`, `writeBodyAsync`, `saveBody`, etc. — all return `Bool`, no post-write readback. |
| **I-008** | Writes report success before durable commit | **CONFIRMED-OPEN in Swift** | Same evidence as I-007. |
| **I-009** | "You have my permission" evaporates as chat text | **CONFIRMED-OPEN** | Rust `PermissionService` + SQLite store fully present. Swift has zero bridge. Tool-level allowlist in `AgentControlSettingsView.swift` is separate from resource-level grants. |
| **I-010** | Note content could affect permissions (prompt injection latent) | **CONFIRMED-OPEN** (latent, not yet observed) | Rust `PermissionService::check()` doesn't inspect note content by design. Swift doesn't use it at all, so the protection isn't applied. |
| **I-011** | Model picker not native-compact | **OPEN — REBUILD PENDING** | Current `LocalModelToolbarMenu` is sophisticated but user wants NSMenu-style dropdown. Needs mock first. |
| **I-012** | Flat lists styled as trees | **OPEN — part of R.8 rebuild** | User wants every tree section to use real `DisclosureGroup` with default-collapsed behavior. |
| **I-013** | Model vault UI uses sheet instead of inline expand | **OPEN — part of R.8 rebuild** | Same scope as R.8 redesign. |
| **I-014** | No UI showing active grants | **PARTIAL** | `ChatCapabilityPill` shows chat mode. `AgentControlSettingsView.activeGrantsSection` exists but shows tool-level allowlist, NOT resource-level grants. No composer chip for resource capabilities. |
| **I-015** | Omega orchestrator debt | **✅ CONFIRMED-FIXED** | `OrchestratorState.swift` L4 comment: *"The full Omega orchestrator has been retired in favor of the Rust agent_core."* `submitTask()` is no-op. **I-015 closes.** |
| **I-016** | Editor doc-truth drift | **UNVERIFIED** | Not yet reconciled. Reconciliation pass deferred until Phase R kick-off. Related: `CODE_EDITOR_POLISH_SCOPE.md` (today) supersedes prior editor planning docs. |
| **I-017** | Swift 6 concurrency violations | **UNVERIFIED** | Clean build succeeds, but `swiftc -strict-concurrency=complete` not yet run. Grep for `try!` + `Int(float)` without `isFinite` not yet run. |
| **I-019** | macOS 26 global event monitor bug | **UNVERIFIED** | Not tested. Fix is a 1-line deferral per memory `project_macos26_global_event_monitor_bug`. |

---

## 3. NEW issues surfaced during this session

| ID | Issue | Source |
|---|---|---|
| **I-020** | Tool-call cards don't always render live — "sometimes / inconsistent" | User dogfood answer |
| **I-021** | Code editor "still very alpha state" — no line numbers; full-file rescan on every keystroke; `Binding<String>` O(n) sync | User flag + `CODE_EDITOR_POLISH_SCOPE.md` audit |
| **I-022** | Provider badge partial — model name shown, latency + cost missing | User dogfood answer |
| **I-023** | Attachment edit CONFIRMED BROKEN — "AI claims edit but nothing changes" | User dogfood answer (already covered by I-007/008 root cause) |

These should be added to `docs/KNOWN_ISSUES_REGISTER.md` next time it's updated.

---

## 4. Plan correction recommendations (refined per user's no-cut-corners constraint)

User said explicitly: *"I want to keep whatever plan I had that may require more work but is better architecturally … don't want to change the specific research."* These recommendations are **reflections of reality into the plan**, not scope reductions.

1. **Phase B status annotation.** Mark as "completed for shared codebase via `EpistemosOperatingMode`; per-profile gates for App Store vs Pro pending." Still architecturally intact; just notes the current level of completion.
2. **R.8 scope extension.** NOT mark complete. User explicitly wants a rebuild: NSMenu-style dropdown with toggles, default-collapsed, compact. Add "design mock first" as R.8 pre-step.
3. **Phase A scope refinement.** Event-streaming pipeline EXISTS via `runAgentSession` + `AgentStreamEventDelegate`. Real remaining work: audit UI card rendering, close gaps where tool-call cards/thinking traces/terminal-output-cards/provider badges render inconsistently (I-020, I-022). This is polish + completeness, not rebuild.
4. **Phase R scope refinement.** Preserve the full architectural spec. BUT the Rust code already exists (1,854 lines), so R.2–R.6 becomes: `#[uniffi::export]` + regenerate bindings + write Swift callers + migrate legacy code paths behind compat adapters. Still extensive work; just starts from a head start.
5. **Phase 1-7 "shipped" callout in §3.** Add the 8 bridges (`perceiveApp`, `interactWithApp`, etc.) to §3 "What is Already Built." Purely additive documentation.
6. **I-015 close.** Omega orchestrator demolition is done per OrchestratorState.swift L4. Phase Ω can close in the plan.
7. **Model-ID edge canonicalization — urgent.** Before Phase R.2 ships broadly, fix the ONE write site (`ChatCoordinator.swift` L4423-4424) that uses unknown `authorship.modelID` format. This is the data edge that creates new split-brain records. Simple patch: assert canonical form at the write site.

All of these are **reflections of current reality**, not cuts to the plan's architectural vision.

---

## 5. Restructured execution plan (user's 3-part vision)

### PART 1 — Fixes + Hardening (foundation pass)

**Goal:** every item in KNOWN_ISSUES_REGISTER.md closed; green regression baseline on a clean branch.

Ordered execution:

1. **Commit current dirty branch state** (35 modified files + 2 untracked). Preserves in-progress session work.
2. **Cleanup pass** (`docs/DEAD_CODE_CLEANUP_ANALYSIS.md` script) — archive MOHAWK/jojo/tmp + superseded docs. Commit separately.
3. **Phase 0 truth audit** — reconcile `CODE_EDITOR_FEATURE_AUDIT.md` with live code (I-016). One-day read-only pass.
4. **Warm-up debt fixes** — I-019 (macOS 26 monitor, 10-line fix) + I-017 (Swift 6 concurrency sweep).
5. **Phase R.2 — canonical ID + AliasRegistry** (2 days). UniFFI-export `ResourceId`, `AliasRegistry`. Fix I-001 at `ChatCoordinator.swift` L4423 write edge.
6. **Phase R.3 — unified ResourceService** (2-3 days). UniFFI-export `ResourceService`. Swift wrapper. Compat adapters over 6+ Swift note-lookup paths.
7. **Phase R.4 — live vs snapshot attachments** (2 days). `AttachmentMode` + `Capability` UniFFI-exported. ChatCoordinator emits `AttachedResource` with explicit mode.
8. **Phase R.5 — permission grant store** (1 day). UniFFI-export `PermissionService`. Parse "you have my permission" into stored grants.
9. **Phase R.6 — verified writes** (2 days). Wrap all 7 Swift write paths with `verified_write()`. Audit log populated.
10. **Phase R.7 — grant UI** (1 day). Composer chip + Settings → Permissions pane.
11. **Phase R.8 — model picker rebuild** (2-3 days, mock first). NSMenu-style dropdown; real toggles; default-collapsed; `DisclosureGroup` everywhere.
12. **Phase R.9 — regression test suite** (1 day). 8 split-brain scenarios.

**Phase Ω — Omega demolition:** ✅ already done (I-015 closed). Optional further work: remove the stub in `OrchestratorState.swift` once all view callers migrate to `AgentViewModel`.

**Total Part 1 duration:** ~15–18 engineering days (wall clock varies with other priorities).

**Exit criteria:** all register issues closed; `cargo test` + `xcodebuild test` green on clean branch; 8 regression tests pass; no re-drift per Appendix B drift alarms.

### PART 2 — App Store polish + legitimization (Phase S)

**Goal:** MAS build ships with positive signal. 100% accuracy testing across the board.

Per plan §Phase S (9 sub-phases):

1. **S.1 UX polish** (1-2 weeks dogfood). Every edge case, empty/error/loading state, approval modal, onboarding flow. Includes I-020 tool-card rendering fixes + I-022 provider badge completeness.
2. **S.2 Review-guideline compliance audit** — App Sandbox entitlements verified, privacy manifest correct, no downloaded code path enabled.
3. **S.3 Accessibility + localization** — VoiceOver, Dynamic Type, RTL, first-tier locales.
4. **S.4 App-Store-specific test expansion** — bounded-agent bounds, sandbox-container filesystem, security-scoped bookmarks, compile-time profile gates.
5. **S.5 Performance + memory tuning** — launch <2s, 10-min session <4GB RSS, MLX pressure handling. Includes code editor polish from `CODE_EDITOR_POLISH_SCOPE.md` (gutter + debounce + outline cache + viewport scoping).
6. **S.6 Privacy posture + ASC App Privacy section.**
7. **S.7 ASC setup — screenshots, description, keywords, privacy policy URL.**
8. **S.8 TestFlight beta — ≥10 external testers, ≥2 full cycles, zero critical open bugs.**
9. **S.9 Submit + respond to review feedback.**

**Exit criteria (per plan §1.7):**
1. All 19+ KNOWN_ISSUES_REGISTER issues closed.
2. Full test suite (2,679 + S.4 additions) green in CI.
3. MAS entitlements verified via `codesign -d --entitlements -`.
4. TestFlight ≥2 full cycles, zero critical bugs.
5. ASC submission accepted, app live.
6. First 48 hours post-launch: no crash spike, rating positive.

**All 6 must ✅ before Part 3 begins.**

### PART 3 — Pro version (two builds, one codebase)

**Goal:** ship `Epistemos Pro` via Developer ID direct download with full autonomy.

Per plan §1.6 + Appendix F:

1. **F.5 packaging execution** — add `Epistemos-Pro` Xcode target; shared Swift sources; different entitlements.plist + Info.plist + bundle IDs. Recommended Approach A (two targets, one project).
2. **Phase D+ Power Mode activation** — CLI subprocess (claude/codex/gemini) via `cli_passthrough.rs`.
3. **Phase K iMessage channel** — `iMessageChannel` actor + workspace-scoped dispatch profiles.
4. **Phase H Docker sandbox** — opt-in; Bash tool only.
5. **Phase G+ full CLI config compiler** — `.claude/`, `.codex/`, `.gemini/` projects files per CLI_CONFIG_COMPILATION_RESEARCH.md.
6. **Pro-only tools** — Bash (destructive), MultiEdit, WebFetch, long-horizon background agents, stdio MCP.
7. **Pro UI polish** — inspector panel, minimap (Metal overlay), semantic sidebar, etc. (per CODE_EDITOR_POLISH_SCOPE §5-8).

**Exit criteria:** Pro build passes full autonomy regression tests; no behavioral difference from App Store build except where explicitly gated by `PolicyProfile`.

---

## 6. Safely manageable two-build architecture — user's ask

User asked: *"I really want the best way to take care of this safely and easily manageable."*

The plan already addresses this in Appendix F §F.4-F.5. Concrete rules:

1. **One runtime, two profiles.** `PolicyProfile::{AppStore,Pro}` enum in `agent_core/src/policy/profile.rs`. Compile-time selection via Cargo feature `mas-sandbox`. Runtime gating via `PolicyProfile::current().allows(capability)`.
2. **Two Xcode targets, one project** (Approach A, recommended in §F.5).
    - `Epistemos-MAS` — App Sandbox YES, Hardened Runtime YES, com.epistemos.Epistemos.MAS bundle ID.
    - `Epistemos-Pro` — App Sandbox NO, Hardened Runtime YES, com.epistemos.Epistemos.Pro bundle ID.
    - Shared Swift source folder.
    - Shared Rust xcframework.
    - Minimal `#if EPISTEMOS_MAS` / `#if !EPISTEMOS_MAS` in Swift — most gating is runtime via `PolicyProfile`.
3. **Every PR declares profile impact** in its description (§F.6 four-line block).
4. **CI matrix** — `cargo build --features mas-sandbox` AND default; both must pass before merge.
5. **Drift alarms** — Appendix B §B.4c — 6 rules. Feature without profile declaration = violation. Parallel implementation = violation. PolicyProfile::AppStore allowing Apple hard-limit capability = violation. Missing CI for either build = violation. Pro artificially constrained for App Store parity = violation.
6. **Packaging split lands at the very end** — not before Phase R closes, not before App Store ships. First three parts of execution build on the SHARED runtime; the target split is a release-prep task, not a mid-stream refactor.

**That's the clean answer to "safely and easily manageable":** don't split the app now. Build Parts 1 + 2 on the shared runtime. When Part 3 begins, add the Pro Xcode target alongside the existing one.

---

## 7. Deliverables produced today (2026-04-23)

All in `docs/`:

1. **`AUDIT_REFLECTION_2026_04_23.md`** (THIS FILE) — the user-requested separate reflection doc. Plan file untouched.
2. **`DEAD_CODE_CLEANUP_ANALYSIS.md`** — decision table for ARCHIVE/DELETE/KEEP; executable cleanup script.
3. **`RESOURCE_INVENTORY.md`** — pre-existing from earlier today (01:21), comprehensive. Kept as-is; this reflection doc references it.
4. **`BUILD_TEST_GREEN_BASELINE.md`** — cargo 577/577 pass; xcodebuild BUILD SUCCEEDED; branch state documented.
5. **`CODE_EDITOR_POLISH_SCOPE.md`** — Phase S polish scope (4 items ≈2 days) + Pro deferred items.

**Zero edits** to `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md`, per user constraint.

---

## 8. Recommended next actions

**Immediate (today/tomorrow):**

1. **Review this reflection doc + the 4 companion deliverables.** Accept or push back on each recommendation.
2. **Commit current dirty branch** (35 modified files + 2 untracked). Do this before any cleanup or Phase R work.
3. **Decide cleanup.** The `DEAD_CODE_CLEANUP_ANALYSIS.md` script is reversible (`git mv`). Run it, or edit to tailor, then commit.
4. **Update `KNOWN_ISSUES_REGISTER.md`** with status changes: I-015 CLOSED. Add I-020 (tool-card rendering), I-021 (editor alpha), I-022 (provider badge partial). I-023 is a duplicate of I-007/008 root cause.

**Part 1 kickoff (next week):**

1. **Run Phase 0 truth audit** (I-016 editor doc-truth reconciliation, ~1 day read-only).
2. **Land I-019 macOS 26 monitor bug fix** (10 lines).
3. **Land I-017 Swift 6 concurrency sweep** (targeted grep + fix).
4. **Start Phase R.2** — UniFFI-export `ResourceId` + `AliasRegistry`; fix I-001 at write edge.

**Before any Pro work:** Phase S exit criteria all ✅. Not before.

---

## 9. What the plan got right (no corrections needed)

To balance the critique: several plan choices survived audit unchanged:

- **App Store first, harden infinitely, then Pro** (§1.7) — holds up.
- **Phase R's architectural spec** — the 1,854 Rust lines implement what the plan prescribes; what's missing is only UniFFI exposure.
- **Hybrid runtime doctrine** (§2 runtime arch) — validated; cloud=Rust, local=Swift is the actual production state and the right architecture.
- **Regression-safety rules for Phase J/K** — they haven't started yet, but the rules are sound.
- **§4.6 AgentEvent primitive + §D.2 ReAct template** — inlined in the plan; match the actual shape `StreamingDelegate.swift` uses (`AgentStreamEventDelegate` → `AgentEventDelegate`).
- **Appendix F deployment profiles** — the `PolicyProfile` + two-Xcode-target architecture is the right answer; cleanup waits for Part 3.

---

**End of audit reflection. Ground truth is captured. Plan is intact. Execution can start with confidence.**
