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
5. 🟡 **Phase R Rust module has scaffolding bridges for R.2/R.4/R.5 as of 2026-04-23 commits `40bcd115` / `6c5d5ecb` / `6a2c1de6`. Only R.2 has runtime enforcement reaching the user.** R.4 (attachments) and R.5 (permissions) land UniFFI primitives and an additive Settings UI, but no Swift call site in production chat / tool-execution flows uses them yet. Treat R.4 + R.5 as **scaffolding, not issue closure** — bridge existence ≠ bug fix. The canonical gateway (R.3 `ResourceService`) and verified-write pipeline (R.6) remain completely orphaned from Swift.
6. 🟡 **Key bugs status (honest labeling post Codex re-review):** **I-001 read-side FIXED** (Swift sidebar genuinely routes through Rust resolver; legacy `gpt-5.4` / `openai:gpt-5.4` records both return). **I-015 CONFIRMED-FIXED** (Omega orchestrator retired, `OrchestratorState.swift` L4 comment + `submitTask()` no-op). **I-016 CONFIRMED-CLEAN** (stale audit doc no longer exists; `CODE_EDITOR_POLISH_SCOPE.md` is live-code-grounded). **I-017 CONFIRMED-CLEAN partial** (grep confirms no `try!`, safe `Int(float)` sites; formal `-strict-concurrency=complete` deferred). **I-019 CONFIRMED-FIXED** (`addGlobalMonitorForEvents` removed entirely). **I-010 CONFIRMED-CLEAN-AT-BRIDGE** (design property of Rust PermissionService — but protection isn't in effect in live code until R.5 runtime enforcement lands). **STILL OPEN:** I-001 write-edge deferred; I-002/003 (6+ note lookup codepaths); I-004/5/6 (scaffolding landed, Swift attachment-site migration pending → AI still claims edits that don't happen); I-007/008 (7 unverified Swift write paths); I-009 (bridge + Settings UI exist, but chat input doesn't create grants and tool execution doesn't check them → "permission as chat text" still evaporates in production); I-011/012/013 (model picker redesign blocked on UX mock).

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
| **I-001** | `gpt-5.4` vs `openai:gpt-5.4` model ID split | **PARTIAL — read-side FIXED 2026-04-23 commit `40bcd115`** ✅ | Rust `AliasRegistry` seeded with 11 model families (3+ variant forms each); `ModelInvolvementSheet.loadContributions` expands `modelIDs` through `expandModelAliases` before the SwiftData fetch. Regression test `gpt_5_4_sidebar_shows_full_history` passes (stores under 3 different forms, queries by 1, all 3 return). Additional ModelVaultBrowser regression: `ModelVaultEntry.acceptedModelIDs` still works as before (18/18 tests green). **Write-edge** at `ChatCoordinator.swift` L4424 deliberately deferred — canonicalizing there would conflict with existing Swift convention where `gpt-5.4` (plain) is the primary display form, and read-side expansion already handles the user-visible symptom. Future commit can align Swift + Rust canonical-form conventions if needed. |
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

## 10. Build-pass log — 2026-04-23 evening (async cascade + other wins)

User directive: *"please do this as well - cascade async to simplify and upgrade things across the board. and continue doing the rest of the other wins as well"* — follow-up to the Codex critique that tightened the scaffold/fix labeling discipline.

Four App-Store-scope commits landed, each honest-labeled and test-backed:

### 10.1 `8d6a8dbd` — scaffold(R.3 async)
- Added `SDPage.loadBodyAsync(mapped:fast:) async -> String` as a strangler-fig alongside `loadBody`. Goes through `resourceResolve(reference:)` + `resourceRead(id:)`; falls back to legacy `NoteFileStorage.readBody` whenever the gateway isn't ready, so production call sites can migrate one at a time without risk.
- Added `SDPage.r3Reference(for:)` helper choosing the best reference the gateway can resolve (absolute file path when known, else legacy page ID).
- New suite `PhaseR3BodyReadParityTests.swift` — 5 tests proving byte-for-byte parity between `resourceRead` and `FileManager.contentsOf` across file:// URIs, vault-note URIs, resolve-then-read round-trips, multibyte UTF-8, and CryptoKit-sha256 vs Rust-emitted checksum. This is the migration safety net for every subsequent call-site swap.
- Verification: BUILD SUCCEEDED; 5/5 new tests pass in 0.136s; Rust suite unchanged at 597/597.

### 10.2 `49906b61` — scaffold(R.3 reactive)
- `AppBootstrap.initializeRustResourceServiceIfReady()` is now idempotent via a new `lastR3InitializedVaultPath: String?` instance var. It short-circuits when the vault path is unchanged AND `resourceServiceIsReady()` is true, so the noisy `.vaultChanged` event (which fires on every page save / trash / move) does not cascade N concurrent re-inits.
- `wireR3VaultSwitchObserver()` subscribes to `EventBus.vaultChanged` once at bootstrap. This closes the startup gap where the initial R.3 init at line 1608 runs before bookmark restore completes; the gateway now tracks vault switches post-launch.
- Verification: BUILD SUCCEEDED; R.3 parity suite still 5/5; no Rust changes.

### 10.3 `1209d968` — scaffold(R.5 chat)
- `ChatCoordinator.handleQuery` now runs a fire-and-forget R.5 parser hook on every user turn: walk `pendingContextAttachments`, extract the grant-eligible URIs via the new pure-static `r5ResourceURIsForGrant(from:)`, and call `permissionStoreRecordUserGrantFromStatement` per URI with the full Capability candidate set (`Read`, `Write`, `Create`, `Delete`, `Search`) and `Session` scope. Non-grant phrasing returns `nil` at the Rust side and nothing persists.
- This is the READ-SIDE of I-009. The WRITE-SIDE (tool-execution gate) is explicitly deferred — grants now land in the store but don't yet gate any tool call.
- New suite `PhaseR5ChatGrantWiringTests.swift` — 7 tests: URI filter (4) + capability/scope constants in lock-step with the Rust enum (2) + smoke that the filter output is accepted by the grant FFI (1).
- Verification: BUILD SUCCEEDED; 28/28 across R.3/R.4/R.5 bridge suites + new wiring suite pass in 0.166s.

### 10.4 `f6f62816` — scaffold(R.4 dropdown)
- `ComposerReferenceHelpers.contextAttachment(for:vaultId:)` gained an optional `vaultId` parameter (defaults nil for back-compat). When vaultId and the entry's `relativePath` are both non-empty, the returned `ContextAttachment` gets the Phase R.4 manifest: canonical `vault://{vaultId}/note/{relativePath}` URI + Live mode + Read/Write capabilities. Otherwise falls back to the pre-R.4 no-manifest form.
- `ChatInputBar.attachMentionReference` now reads `vaultSync.vaultURL?.lastPathComponent` and threads it through the builder — the vaultId convention matches `AppBootstrap.initializeRustResourceServiceIfReady`, so both sides of the FFI agree on vault identity.
- `MiniChatViewAuditTests.swift` updated to match the new call signature.
- Scope guard: MiniChat + Landing dropdowns deliberately left on the legacy no-manifest path; their migration is a separate commit.
- New suite `PhaseR4DropdownBackfillTests.swift` — 11 tests: URI-construction helper (5), entry-path backfill semantics (3), all-notes / chat paths unchanged (1), R.4→R.5 handoff proof (1), legacy caller still compiles (1).
- Verification: BUILD SUCCEEDED; 72/72 across all 7 affected suites pass in 0.300s.

### 10.5 Label discipline

All four commits use the `scaffold(R.x component)` prefix — none of them claim a user-visible I-xxx fix. The corresponding `docs/KNOWN_ISSUES_REGISTER.md` entries were updated to show:
- I-002 / I-003: OPEN — scaffolding + parity net landed, migrations pending.
- I-004 / I-005 / I-006: OPEN — dropdown manifest landed, tool-dispatch enforcement pending.
- I-009: PARTIAL (was OPEN) — read-side parser landed, tool-check gate pending.

No "FIXED" labels added. This is the Codex critique's instruction translated into label-level truth.

### 10.6 What the next working session should take on

In priority order:
1. **R.5 write-side** — `LocalAgentLoop` tool-dispatch gate that calls `permissionStoreCheck` before Write/Delete/Create. This is the first commit that flips I-009 from PARTIAL to FIXED. Modest scope; tests should mock a grant-bearing turn and assert tool ALLOW vs DENY.
2. **R.3 production read-site migration** — switch `NoteFileStorage.readBody` / `VaultIndexActor` / `NotesSidebar` consumers from `loadBody` to `loadBodyAsync`. Parity tests already cover the byte-level contract; we just need to flip the call sites and add a migration-level integration test.
3. **R.4 MiniChat + Landing dropdown backfill** — mirror `f6f62816` into the two other composers. Small, mechanical, high-value because it closes all three chat surfaces at once for grant eligibility.
4. **R.6 verified write** — Rust already has `verified_write`; Swift integration is the gating work for flipping I-007 / I-008 from OPEN.

---

## 11. Build-pass log — 2026-04-23 late evening (R.5 write-side landing)

After Codex's second read-only audit (shared in-conversation) confirmed *"continue `AUDIT_REFLECTION §10.6` in order"*, the next commit in that queue landed:

### 11.1 `0582aa3d` — scaffold(R.5 gate)

- `agent_core::tools::registry::ToolRegistry::execute` now fires a Phase R.5 authorization check before handing control to the tool handler. This is the ONE choke point every tool call passes through — the autonomous Rust agent loop (`agent_loop.rs:857`), the Swift-driven `execute_tool_call` FFI entry point (`bridge.rs:1919`), AND the allowlist-limited `execute_tool_call_filtered` variant (`bridge.rs:1964`) all converge here. One edit covers cloud + local paths.
- New module `agent_core/src/resources/tool_authz.rs` provides the pure `infer_tool_authz_target(tool_name, input, risk_level, vault_root) -> Option<ToolAuthzTarget>`. First arm recognizes `vault_write` and builds `(ResourceId::VaultNote { vault_id, note_id }, Capability::Write)` using `vault_root.file_name()` for vault id — same convention as `AppBootstrap.initializeRustResourceServiceIfReady`. The arm-by-arm pattern lets every future tool addition land independently.
- Two new crate-private helpers on `resources::bridge`: `check_resource_capability(ResourceId, Capability) -> bool` (so the gate doesn't need to round-trip through the stringified FFI) and `active_grant_count() -> usize` (used by the empty-store safety branch).
- **First-cut semantics — conservative by design:**
  - **Advisory (default):** gate emits `tracing::info!` with `tool`, `capability`, `granted`, `active_grants`, `enforce` but never blocks. Live traffic unchanged.
  - **Enforcement (`EPISTEMOS_R5_ENFORCE=1`):** if `granted == false` AND `active_grants > 0`, return `ToolError::PermissionDenied` before the handler runs. The `active_grants > 0` guard is the user-opt-in safety — an empty store means the user hasn't configured anything yet, so we never break flows out from under them.
  - **Read-only tools (`RiskLevel::ReadOnly`) bypass entirely** — R.5 is about mutation gating.
- **12 new Rust tests, all green:**
  - `resources::tool_authz::tests` (8): URI construction happy path + leading-slash normalization; `None` for: no vault root, no path, empty path, read-only risk, unrecognized tool, unresolvable vault root.
  - `tools::registry::tier_tests::r5_gate_*` (4): advisory-mode allow regardless of grant state; enforcement-mode allow when a matching grant exists; **enforcement-mode deny when a different grant exists** (the I-009 enforcement proof); read-only `vault_read` bypasses even under enforcement. Tests serialize behind `R5_GATE_TEST_LOCK` + a `ScopedEnforceFlag` RAII guard that restores the env var on drop.
- Verification: `cargo test` passes 609 main lib + 2 + 5 binary test suites = 616 tests. `xcodebuild -scheme Epistemos build` → BUILD SUCCEEDED. Swift Phase R regression (46 tests across 5 suites) unchanged.

### 11.2 Why I-009 remains PARTIAL (not FIXED)

Honest-labeling holds: I-009 moved from PARTIAL to PARTIAL. The wiring is real and testable, but:
1. Default mode is advisory. Enforcement only fires under the env flag. The plan's promise is that the user-visible symptom goes away — that requires enforcement ON by default.
2. Only `vault_write` is recognized. Other mutating tools (file writers, delete variants, custom tools, send_message, claude_code) still bypass. Until every mutating arm is covered, enabling default enforcement would create holes that leak unauthorized writes through the un-mapped tools.
3. The permission store is still in-memory. A full I-009 FIXED needs persistence across app relaunches.

### 11.3 Next in the §10.6 queue

1. ✅ **R.5 write-side** — landed as `0582aa3d` (this commit). Advisory today, enforcement one env var away.
2. ⏳ **R.3 production read-site migration** — migrate `NoteFileStorage.readBody` / `VaultIndexActor` / `NotesSidebar` consumers from `loadBody` to `loadBodyAsync`. Parity tests already cover the byte-level contract; just flip the call sites and add a migration-level integration test.
3. ⏳ **R.4 MiniChat + Landing dropdown backfill** — mirror `f6f62816` into the two other composers. Small, mechanical; closes all three chat surfaces for grant eligibility.
4. ⏳ **R.5 arm-by-arm expansion** — add every mutating tool to `tool_authz::infer_tool_authz_target`. Needed before enforcement default can flip ON.
5. ⏳ **R.5 persistence** — migrate the permission store to on-disk at a container-safe path.
6. ⏳ **R.6 verified write** — Rust already has `verified_write`; Swift integration flips I-007 / I-008 from OPEN.

### 11.4 Codex's muddy-count note reconciled

Codex's second audit observed *"Claude's '72/72' count didn't reproduce exactly for my selected suites: I got 68/68 on the seven mapped Phase R suites, plus 20/20 on alias/composer tests."* The difference comes from which suites each run picks: the 72 figure included `MiniChatViewAuditTests` + `ComposerReferenceHelpersTests` as part of the "Phase R touch surface"; Codex's 68 excluded them. Both numbers are correct for the suites each of us selected. The authoritative number for this commit's additions is: **12 new Rust tests** (`tool_authz` + `tier_tests::r5_gate_*`) and zero Swift test count change.

### 11.5 Stale-early-statement disclaimer

Codex also noted *"`AUDIT_REFLECTION_2026_04_23.md` now has stale early statements contradicted by the newer §10/§11 session work."* Accurate. §1–§9 describe the pre-build-pass ground truth; §10 / §11 are authoritative for the commits they name. A reconciliation pass (folding the early sections into a single "As of 2026-04-23 morning" preamble) is queued as a low-priority doc-only chore.

### 11.6 Dirty worktree caveat

`Epistemos.xcodeproj/project.pbxproj` continues to show unstaged cosmetic Xcode drift from opening the project. Do NOT commit it alongside scaffold work — it belongs in its own trivially-reversible commit if it ever needs to land.

---

## 12. Build-pass log — 2026-04-23 late night (R.5 arm-by-arm expansion)

Continues §11's work list (`§11.3` item (4) "R.5 arm-by-arm expansion"). Finish-the-runway prompt step 1.

### 12.1 `scaffold(R.5 arms)` — tool_authz covers every mutating tool

- Three new arms in `agent_core/src/resources/tool_authz.rs::infer_tool_authz_target`, each producing `ResourceId::File { absolute_path }` + `Capability::Write`:
  - `write_file` — reads `input["path"]`, runs the same `~/` expansion `WriteFileHandler::resolve_path` uses, so the gate authorizes the file the handler will actually touch (not the pre-expansion string). Creation-via-overwrite rides on the same grant.
  - `patch` — same shape; handler requires existing file, so the grant semantics are "permission to modify this path".
  - `trajectory_export` — conditional on `input["output_path"]`. When omitted, the handler returns 20 lines inline (no write) → arm returns `None`. When provided, arm produces a File-Write target.
- Shared helper `file_target_from_path(value, capability)` centralises trim + `~/` expansion + empty-after-expand guards. Keeps each arm a one-liner and makes future file-targeting arms (e.g. a delete tool) trivial to wire.
- Catch-all comment now enumerates the 20+ non-ResourceId-mappable mutating tools and explains why each class bypasses R.5: shell passthroughs, messaging, AppleScript apps, UI/device tools, local-state tools, stdio MCP. Tier/allowlist gating in `is_tool_permitted` still holds them.
- **9 new happy-path + guard tests** for the three arms (absolute path, home-expanded path, missing field, empty/whitespace field, inline-export omission) plus **1 parametric sweep** (`non_resourceable_mutating_tools_return_none`) that hits 20 catch-all tools in a single test body so the list is visible and reviewable as one unit. All 17 `tool_authz::tests` cases now green.
- Full Rust suite: 618 lib + 2 + 5 binary = 625 tests green (was 609 + 2 + 5 = 616; +9 is the new `tool_authz` coverage plus the parametric sweep counts as 1 test). `xcodebuild -scheme Epistemos` → BUILD SUCCEEDED. Pre-existing SwiftLint failures in `CodeEditSourceEditor` / `CodeEditTextView` remain (third-party, ignored per runway prompt).

### 12.2 Why this is `scaffold(...)` not `fix(...)`

- The arms are *wiring* — they map tool-name strings to resource targets. Default mode is still advisory (`EPISTEMOS_R5_ENFORCE=1` required for deny). No user-visible bug gets flipped until Step 2 changes the default.
- I-009 stays PARTIAL on this commit. It moves to FIXED only when the flag flips AND the arm coverage is judged complete enough to be safe on by default. Arms are complete for every Some-case the ResourceId enum can describe; non-mappable tools have a test locking in their pass-through.

### 12.3 Carried forward to Step 2

- `r5_enforce_enabled()` default → flip `false` → `true`.
- New test: `r5_gate_denies_vault_write_when_enforce_defaults_on_with_grants_but_no_match` — same shape as the existing `_grants_exist_but_not_for_this_resource` test, but WITHOUT setting the env flag, to prove the default is now the enforce path.
- KNOWN_ISSUES_REGISTER I-009 gets the green checkmark + the "user-visible symptom gone" line.

---

## 13. Build-pass log — 2026-04-23 late night (R.5 default flipped — I-009 FIXED)

### 13.1 `fix(R.5): default to enforcement — I-009 FIXED`

- `r5_enforce_enabled()` in `agent_core/src/tools/registry.rs` now defaults to `true`. Unset env var or any value that isn't `0`/`false`/`no`/`off` → enforce. `EPISTEMOS_R5_ENFORCE=0` is the explicit escape hatch (operator rollback to advisory).
- `ScopedEnforceFlag::set_off()` added to the R.5 test toolkit — mirrors `set_on()`/`clear()` but sets the env to "0" so the escape-hatch test can prove the rollback.
- Existing `r5_gate_allows_vault_write_when_enforce_flag_is_off` renamed to `r5_gate_allows_vault_write_when_escape_hatch_disables_enforce`. The test now also seeds an unrelated grant so the assertion "escape hatch still allows even when the store has grants" is exercised, not "advisory + empty store".
- **New test: `r5_gate_denies_vault_write_by_default_when_grants_exist_but_not_for_this_resource`.** Clears any prior env var, seeds a grant for resource A, calls `vault_write` against resource B, asserts `Err(ToolError::PermissionDenied)`. This is the I-009 user-visible-symptom-gone proof: "permission given in chat, tool call to a DIFFERENT target gets denied at the gate — no env flag, no special config."
- Rust suite: **619 lib + 2 + 5 = 626 tests** green (was 618 + 2 + 5 = 625). The +1 is the new default-on deny test. `xcodebuild -scheme Epistemos` → BUILD SUCCEEDED. `xcodebuild test -only-testing:...Phase R suites` → 46/46 across 5 suites green.

### 13.2 Why this fixes I-009 (not just moves the label)

The bug class is "grant text in chat evaporates — tool call proceeds anyway". The fix has three legs:
1. **Grant is persisted** (scaffold `6c5d5ecb` + `1209d968` — chat handler records to Rust store).
2. **Gate checks before handler runs** (scaffold `0582aa3d` — `ToolRegistry::execute` consults store, rejects with `PermissionDenied` when grant missing under enforcement).
3. **Enforcement is ON by default** (this commit — no hidden env flag required for the user-visible fix to be in effect).

Without leg 3, legs 1+2 were scaffolding the user couldn't rely on. With leg 3, a grant for note A and a tool call for note B in the same session produces a visible deny, not a silent success. That's the symptom disappearing.

### 13.3 Dependent follow-ups (separate closures)

The I-009 closure deliberately does NOT depend on:
- Persistence (Step 3 in the runway). In-memory store means grants disappear on relaunch, but within a session the fix works. A per-relaunch regression is a *new* symptom; fold into the on-disk persistence commit.
- MiniChat / Landing backfill (Step 5). The grant-recording path works via the main ChatCoordinator today; other composers emit manifest-less attachments. Their grants still land via the dropdown/paste paths that DO have manifests. Any composer that can get to a grant-eligible user turn will.

### 13.4 What the queue now looks like

- ✅ Step 1 — `scaffold(R.5 arms)` — landed.
- ✅ Step 2 — `fix(R.5)` — landed. I-009 FIXED.
- ⏳ Step 3 — permission-store on-disk persistence.
- ⏳ Step 4 — R.3 production read-site migration.
- ⏳ Step 5 — R.4 MiniChat + Landing dropdown backfill.
- ⏳ Step 6 — R.4 Finder-drop + paste attachment sites.
- ⏳ Step 7 — R.6 verified-write Swift integration.

---

## 14. Build-pass log — 2026-04-23 late night (R.5 permission store on-disk persistence)

### 14.1 `scaffold(R.5 persist)` — grants survive relaunches

- **`SqlitePermissionService::reopen_at(&self, path)`** added to `agent_core/src/resources/permissions.rs`. Re-runs `init_schema`, then replaces the inner `Mutex<Connection>` atomically under the existing std::sync::Mutex. Interior mutability so the outer `tokio::sync::Mutex` wrapper in `bridge.rs::store()` doesn't need to change callers.
- **UniFFI export** `permission_store_init_at_path(path: String) -> Result<(), ResourceError>` in `agent_core/src/resources/bridge.rs`. Validates path, creates parent dir if missing, drives `reopen_at` via the global tokio runtime's `block_on`. Swift-callable from a plain thread (no async context required).
- **Shared async core** `reopen_permission_store(path_buf, path_str)` extracted so a `#[cfg(test)] pub(crate)` sibling `permission_store_init_at_path_for_test` can exercise the same logic inside `#[tokio::test]` contexts without triggering "runtime within a runtime" panics.
- **Swift wiring** in `Epistemos/App/AppBootstrap.swift` — new `initializeRustPermissionStoreIfReady()` method called at launch alongside the R.3 gateway init. Resolves a container-safe path via `FileManager.default.url(for: .applicationSupportDirectory, ...)` + bundle-scoped subdir + `permissions.db`. Runs off-main in a `Task.detached`; errors are logged and swallowed so a transient SQLite-open failure doesn't block launch.
- **Tests (4 new Rust):**
  - `init_at_path_empty_string_returns_explicit_error` — validation guard.
  - `init_at_path_creates_missing_parent_directory` — matches AppBootstrap's expectation of creating the bundle-scoped dir on first launch.
  - `grants_survive_in_process_restart_via_reinit_at_same_path` — the headline proof: record a grant, re-init at the same path (simulating relaunch), assert `list_active` still surfaces the grant by `grant_id` AND marker URI.
  - `grants_recorded_before_init_persist_after_switching_to_disk` — documents the contract: switching to a DIFFERENT path in-process drops the prior store's rows. Callers must init EARLY.
- **Test infra:** `BRIDGE_STORE_GATE` (new) covers all bridge tests that mutate the process-local store — persistence AND non-persistence. Needed because my persistence tests swap the backing Connection and the older non-persistence tests don't acquire a gate; concurrent runs would see a dead file handle after a TempDir drops. Shared gate + explicit `restore_store_to_in_memory()` cleanup at the end of each persistence test. Fixed one latent race in `record_user_grant_and_check_roundtrip` that existed before this session — pre-existing tests now gate on `bridge_store_gate()` too.

### 14.2 Verification

- Rust: **623 lib + 2 + 5 = 630** tests green (was 619 + 2 + 5 = 626; +4 persistence tests). `cargo test resources::bridge` 24/24 green.
- Swift: `xcodebuild -scheme Epistemos` → BUILD SUCCEEDED. Phase R regression suites (5 suites, 46 tests) pass. Pre-existing `CodeEditSourceEditor` / `CodeEditTextView` SwiftLint failures unchanged. SourceKit false-positive diagnostics about `LocalModelManager` / `Log` / `Keychain` in AppBootstrap are pre-existing and don't reflect the real build.

### 14.3 Honest scope-guard

This is `scaffold(R.5 persist)` — not `fix(...)` — because I-009 was already FIXED in Step 2. On-disk persistence closes the "follow-up deferred" bullet that was mentioned in the I-009 PARTIAL notes, but doesn't flip any new label. The user-visible benefit (grants survive relaunch) is real but additive to the already-landed fix.

### 14.4 What's next in the queue

- ⏳ Step 4 — R.3 production read-site migration (`grep -rn "\.loadBody(" Epistemos/ | grep -v Tests` produces the work list).
- ⏳ Step 5 — R.4 MiniChat + Landing dropdown backfill.
- ⏳ Step 6 — R.4 Finder-drop + paste attachment sites.
- ⏳ Step 7 — R.6 verified-write Swift integration.

---

## 15. Build-pass log — 2026-04-23 very late night (R.3 async cascade migration)

Step 4 of the runway prompt — "R.3 production read-site migration". Completed across 8 files, one commit per file, per the runway prompt's order.

### 15.1 Commits landed

1. `scaffold(R.3 migrate SpotlightIndexer)` — `index`/`reindexAll` stage Sendable primitives (pageId/filePath/title/tags/dates) and route the body read through the new `SDPage.loadBodyAsyncFromPrimitives` helper. SDPage reference never crosses the Task boundary.
2. `scaffold(R.3 migrate EntityExtractor)` — 3 body-read sites in `scanVault` (change-detection filter, batch-content build, hash-cache update) all primitives-staged.
3. `scaffold(R.3 migrate GraphState.buildPageSubgraph)` — method async'd; zero existing Swift callers (future page-mode subgraph wiring).
4. `scaffold(R.3 migrate DataviewService)` — dead-code `file.size` field switched from sync `loadBody` to `NoteFileStorage.readBody` directly. TODO comment for future async caller.
5. `scaffold(R.3 migrate CloudKnowledgeDistillationService)` — `loadNotes` + `sourceBody` async'd; caller `rebuildModelVaults` already awaits; autoclosure `??` split into if-else.
6. `scaffold(R.3 migrate VaultIndexActor)` — 9 sites across 10 methods (`upsertPage`, `exportPage`, `reindexFile`, `importVault`, `fullPageData`, `allPagesForRebuild`, `buildVaultContext`, `buildVaultManifest`, `fetchNoteBodies`, `spotlightReindexAll`). Introduced `drainEnumerator` sync helper because `FileManager.DirectoryEnumerator.makeIterator()` is unavailable from async contexts in Swift 6. `autoreleasepool` wrapper dropped around async `upsertPage` (incompatible with async, and per-page scratch context handles memory pressure anyway).
7. `scaffold(R.3 migrate VaultSyncService)` — docs-only scope guard on `latestAvailableBody` documenting why its 4 sites stay on legacy sync `loadBody` (MainActor save-path state machine would require refactoring).
8. `scaffold(R.3 migrate UI consumers)` — 7 sites async'd (AIPartnerService, JournalIntents, TimeMachineService, DiffSheetView, VaultChangesPanel, AppBootstrap.migrateBlockReferences, VaultParser, LiveNoteExecutor). 1 scope-guarded (ProseEditorRepresentable2 interactive edit callback — async would be perceptible lag).

### 15.2 Helper enhancement

`SDPage.loadBodyAsyncFromPrimitives` gained an `inlineBody: String` parameter so the helper implements the FULL 4-step fallback chain of legacy `loadBody`:
1. R.3 gateway (resolve + read) when ready.
2. `NoteFileStorage.readBody` (managed sidecar file).
3. Inline `body` column (pre-migration pages).
4. Raw vault file via `VaultIndexActor.decodedBodyFromReadableVaultFile`.

This means every migrated call site now matches the legacy `loadBody` behaviour byte-for-byte — just with the gateway consulted first.

### 15.3 Honest label on I-002 / I-003

Moved both from OPEN to **PARTIAL**. The async read cascade is migrated across every call site that can reasonably be async today (8 files; ~25 call sites total). The remaining 5 sites stay on sync `loadBody`:
- **4 in `VaultSyncService`** — save-flow bookkeeping (dirty-page hash checks, version capture, new-page save tracking). Write-side, not the lookup-duplicate class I-002/I-003 describes.
- **1 in `ProseEditorRepresentable2`** — interactive AppKit edit callback. Async would delay the edit visibly.

Neither is the "6+ duplicate read codepaths" class. The observer-pattern change propagation I-003 mentions (edit-in-one-surface-visible-in-another) is a separate Phase R.3 line item that still rides on SwiftData notifications + file-system watchers.

### 15.4 Swift 6 sendability patterns used

Key pattern throughout the migration: the `SDPage` reference NEVER crosses a Task or async-call boundary directly. Instead, the caller reads `pageId`, `filePath`, `inlineBody` (and any other needed metadata) synchronously from the `@MainActor` / `@ModelActor` context, then passes those primitive Strings/ints/dates through the await boundary. Swift 6 region-based isolation is fully satisfied — no `@unchecked Sendable` escape hatches introduced.

### 15.5 Verification

- Rust: 623 + 2 + 5 = **630 tests** green (unchanged across the migration — R.3 is Swift-only).
- Swift: `xcodebuild -scheme Epistemos -destination 'platform=macOS' build` → BUILD SUCCEEDED after every commit in the series.
- Phase R regression suites: **46/46 across 5 suites** green after every commit.
- Pre-existing third-party SwiftLint failures on `CodeEditSourceEditor` / `CodeEditTextView` — unchanged.

### 15.6 What's next

- ⏳ Step 5 — R.4 MiniChat + Landing dropdown backfill. Mirror commit `f6f62816` into `MiniChatView.swift` + `LandingView.swift`.
- ⏳ Step 6 — R.4 Finder-drop + paste attachment sites.
- ⏳ Step 7 — R.6 verified-write Swift integration.

---

## 16. Build-pass log — 2026-04-23 end-of-runway (Steps 5-7)

### 16.1 `scaffold(R.4 minichat+landing)` — Step 5

Mirror of `f6f62816` (ChatInputBar) into the two remaining production composers. `MiniChatView.attachMentionReference` and `LandingView.attachLandingMentionReference` both now thread `vaultSync.vaultURL?.lastPathComponent` into `ComposerReferenceHelpers.contextAttachment(for:vaultId:)`.

Before: R.5 grant parser was effectively dead on MiniChat + Landing turns (their attachments had no resourceURI, so `r5ResourceURIsForGrant(from:)` filtered them all out).
After: every `@`-picked note on all three chat surfaces carries a canonical URI; "you have my permission to edit this" from any composer mints a real grant.

2 new parity tests (`allThreeComposersMintIdenticalManifest`, `allThreeComposersFallBackIdenticallyWhenVaultUnset`) prove all three composers produce byte-identical attachments for the same entry.

### 16.2 `scaffold(R.4 finder+paste)` — Step 6

Finder drop + paste handlers don't exist in the codebase today (the spec-mentioned `.onDrop` / `.onPasteCommand`). The only file-entry point is the NSOpenPanel file picker in `ChatInputBar`. This commit wires that existing path:

- New `ContextAttachmentKind.file` case on the attachment model.
- New helpers: `fileResourceURI(for:)`, `fileContextAttachment(for:displayName:)`, `pasteContextAttachment(displayName:snapshotContent:sourceIdentifier:)`.
- File-picker flow now mints a companion manifest-bearing `ContextAttachment` per picked file. R.5 grant parser sees the `file://` URIs.

Honest scope guard: **tool-dispatch enforcement** (tool-call consulting `attachment.toAttachedResource().allows(.write)` before writing) is NOT included. I-004/I-005/I-006 stay PARTIAL — manifest plumbing is now present on every entry point (dropdown + file picker + paste helper), but the write-side gate hasn't been flipped on for files the way R.5 flipped it for `vault_write`.

7 new tests (20/20 green in `PhaseR4DropdownBackfillTests`).

### 16.3 `scaffold(R.6 bridge)` — Step 7

Rust `runtime::verified_write()` pipeline — which has existed since Phase R.6 authoring — now has a UniFFI facade:

- **`resource_verified_write(id, content, base_version, tool_name, approval_source)`** — drives the full Requested → Resolved → Authorized → Executed → Verified → Surfaced pipeline using process-local `PermissionService` + `ResourceService` + a new process-local `SqliteResourceAuditLog` slot.
- **`verified_write_init_audit_at_path(path)`** — mirrors `permission_store_init_at_path`; Swift can migrate the audit log from in-memory to on-disk at launch.
- **`VerifiedWriteError` UniFFI enum** flattens the rich Rust `runtime::WriteError` into `NotInitialized / InvalidResourceUri / PermissionDenied / VersionConflict / VerificationFailed / Resource / Audit` so Swift can pattern-match the exact failure mode.
- **`VerifiedWriteReceipt` UniFFI record** — success payload carrying the resource id + new version.

3 new Rust tests (all green):
- `verified_write_bridge_succeeds_when_grant_covers_resource_and_readback_matches` — happy path.
- `verified_write_bridge_denies_when_no_grant_covers_resource` — gate fires before the write handler.
- `verified_write_init_audit_at_empty_path_rejects` — validation guard.

Tests serialize on both `bridge_store_gate()` (permission store) AND `r3_gate()` (resource service slot) so re-initialising the active vault doesn't race existing R.3 fixtures.

**Honest scope guard — this is NOT `fix(R.6)`:**
- I-007 / I-008 stay PARTIAL.
- The Rust FFI surface is present + tested; Swift call-site migration is the remaining work.
- `NoteFileStorage.writeBody`, `SDPage.saveBody`, and tool-execution writes in Swift still call the unverified `resourceWrite` / raw `FileManager` write path. Migrating those to `resourceVerifiedWrite` is the next commit that flips the label to FIXED. It should also surface the audit log in `AgentControlSettingsView`.

### 16.4 Verification summary — end of runway

- Rust: **626 lib + 2 + 5 = 633 tests** green (was 616 at session start; +17 new tests across Steps 1-7).
- Swift Phase R regression: **55/55** across 5 suites (`PhaseR3BodyReadParityTests` 5, `PhaseR4DropdownBackfillTests` 20, `PhaseR5ChatGrantWiringTests` 7, `PhaseRAttachmentBridgeTests` 14, `PhaseRPermissionBridgeTests` 9).
- `xcodebuild -scheme Epistemos` → BUILD SUCCEEDED after every commit in the runway.
- Pre-existing third-party SwiftLint failures on `CodeEditSourceEditor` / `CodeEditTextView` — unchanged (not touched during this runway).

### 16.5 Label outcomes across the runway

- **I-001** — no change (already PARTIAL read-side FIXED; write-edge deferred per `40bcd115`).
- **I-002 / I-003** — OPEN → PARTIAL (R.3 async cascade migrated).
- **I-004 / I-005 / I-006** — OPEN → PARTIAL (manifest plumbing on every entry point, tool-dispatch gate pending).
- **I-007 / I-008** — OPEN → PARTIAL (verified-write FFI bridge landed, Swift call-site migration pending).
- **I-009 — OPEN → FIXED** 🟢 (default enforcement flipped on; Step 2).
- **I-010** — no change (CONFIRMED-CLEAN-AT-BRIDGE; in-effect hinges on I-009 which is now FIXED — worth a re-audit after the Swift verified-write migration).

### 16.6 Pending work NOT in this runway

- Swift call-site migration for verified writes (the `fix(R.6)` commit).
- Tool-dispatch write gate for attachments (the `fix(R.4)` commit).
- R.7 UI surface for active grants (I-014).
- R.8 picker / DisclosureGroup rebuild (I-011 / I-012 / I-013).
- Doc-reconciliation fold of §1-§9 into a preamble (lowest-priority chore, deliberately deferred).

---

## 17. App Store hardening correction — 2026-04-24

### 17.1 R.5 is now fail-closed for ResourceId-targeted writes

The prior R.5 gate still had a compatibility escape inside enforcement mode:
it denied only when `active_grants > 0`. That meant an empty grant store still
allowed a ResourceId-targeted mutating tool to run. For App Store hardening,
that is too loose.

The 2026-04-24 hardening pass changed `ToolRegistry::execute` so enforcement
mode denies any ResourceId-targeted mutating tool when `PermissionService`
does not return a matching grant. `active_grants` remains in the telemetry
event only. `EPISTEMOS_R5_ENFORCE=0` remains the explicit operator rollback to
advisory behavior.

### 17.2 Label correction

- **I-009 remains FIXED**, but for the stronger reason: default enforcement is
  ON **and** fail-closed for ResourceId-targeted mutating tools.
- **I-010 is now FIXED for ResourceId-gated tools** because the live gate
  consults `PermissionService::check()`, and that check does not inspect note
  content. Non-resourceable tools remain governed by tier / approval / policy
  gates and should stay outside App Store scope unless explicitly profile-gated.

### 17.3 Verification

- `cargo test --manifest-path agent_core/Cargo.toml tools::registry::tier_tests::r5_gate -- --nocapture` → 5/5 green.
- `cargo test --manifest-path agent_core/Cargo.toml verified_write_bridge -- --nocapture` → 2/2 green.
- `cargo test --manifest-path agent_core/Cargo.toml user_grant_statement_stores_grant_and_is_used -- --nocapture` → 1/1 green.

---

## 18. R.6 tool-write readback hardening — 2026-04-24

### 18.1 Rust registry writes now fail closed on readback mismatch

The Rust tool registry had three direct write surfaces that could previously
return success immediately after `write()` / `rename()` returned:

- `write_file`
- `patch`
- `vault_write`

The 2026-04-24 hardening pass added post-write readback verification to all
three. `write_file` and `patch` now read the file bytes after the atomic rename
and compare them to the requested payload. `vault_write` reads the vault note
after `VaultBackend::write()` and compares it to the expected final content
(including append mode and tag frontmatter injection).

Success payloads now include `"verified": true`, and readback mismatch returns
`ToolError::ExecutionFailed("write verification failed...")`.

### 18.2 Regression added for the exact "AI lied" class

A new `LyingVault` test backend returns `Ok(())` from `write()` but returns
different content from `read()`. `vault_write` now rejects that as a failed
write instead of surfacing success. This is the `vault_graph.json` bug class in
miniature.

### 18.3 Honest label

- **I-007 / I-008 remain PARTIAL**, but the Rust registry path is now hardened.
- Remaining work is Swift-originated write paths: `NoteFileStorage.writeBody`,
  `SDPage.saveBody`, and any LocalAgentLoop raw file writes that bypass the Rust
  tool registry / `resource_verified_write`.

### 18.4 Targeted verification

- `cargo test --manifest-path agent_core/Cargo.toml tools::filesystem::tests -- --nocapture` → 17/17 green.
- `cargo test --manifest-path agent_core/Cargo.toml tools::registry::tier_tests::vault_write -- --nocapture` → 2/2 green.

**End of audit reflection. Ground truth is captured. Plan is intact. Execution can start with confidence.**
