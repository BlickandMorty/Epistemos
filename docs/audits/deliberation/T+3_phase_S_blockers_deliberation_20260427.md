# T+3 Deliberation Brief: Phase S Blockers

**Date**: 2026-04-27
**Phase**: T+3 — Close Phase S blockers (S.1 launched-app dogfood, S.7 ASC metadata, S.8 TestFlight, S.9 submission/review) + standalone gates (Instruments p99 signpost, ProseEditor instrumentation deferred spike, distribution-signed archive)
**Author**: Claude builder
**Auditor**: deferred (user adjudicating; Codex unavailable)

---

## §A — Disk research synthesis

### A.1 — Per-slice contracts (RELEASE_HARDENING_CANONICAL_PLAN, PERF_REPAIR_REPORT, EXTENDED_PROGRAM_PLAN, SESSION_SUMMARY 2026-04-25)

**S.1 launched-app dogfood** (RELEASE_HARDENING_CANONICAL_PLAN §6.2:343–348)
- Entry: focused-test signal trustworthy (§6.1 codesign + rebuild green); current blocker batch committed alone.
- Exit: cloud reasoning turn yields real final answer; local reasoning turn yields answer without freezing UI; oversized local refuses or degrades honestly; thinking kept out of main answer lane.
- Evidence required: build green via `xcodebuild -scheme Epistemos`; live-app screenshots/logs from `./scripts/launch_audit_app.sh --minimal-home --root-shell-minimal`; tool-execution rows in `omega_executions.db`; final-answer text in chat bubble; Tool Progress cards showing `Finished`; no synthetic repair loops visible.
- Status: PERF_REPAIR_REPORT confirms 7 user-visible bugs FIXED (tool_call parser, cloud manifest gating, semantic note lookup, Mini Chat Tools/Thinking pill, Metal working-set leak, eager embedding load, dangling fence markers). All landed pre-cutoff. Manual run on real Release-mode bundle still pending.
- **CLAUDE-DOABLE? Partially.** Build verification + grep-gate verification yes. Manual launched-app dogfood requires user at machine.

**S.7 App Store Connect metadata** (EXTENDED_PROGRAM_PLAN W1.2:41-43)
- Entry: release candidate ready (S.1 green); App Review notes drafted at `docs/release/MAS_APP_REVIEW_NOTES.md`; privacy form filled.
- Exit: screenshots uploaded (5–6 standard sizes); App Privacy form complete; App Review notes include JIT entitlement rationale + `allowed_paths.txt` scope.
- **CLAUDE-DOABLE? Partial.** Can draft `MAS_APP_REVIEW_NOTES.md` content. Cannot fill ASC web form, upload screenshots, or set support URLs. **USER-BLOCKED.**

**S.8 TestFlight** (EXTENDED_PROGRAM_PLAN W1:48 + W1.4:45-46)
- Entry: ASC metadata complete; build archived signed for TestFlight (`Epistemos-AppStore` scheme); beta review notes prepared.
- Exit: TestFlight build uploaded + reviewer notes attached; smoke test passed (15 user flows per W1.4); CI green.
- Required: distribution-signed `.xcarchive` from `xcodebuild -scheme Epistemos-AppStore -configuration Release archive` (see §B); incremented build number; smoke test evidence.
- **CLAUDE-DOABLE? No.** Apple Developer signing + TestFlight upload + manual smoke require user.

**S.9 submission/review** (SESSION_SUMMARY §107-114)
- Entry: TestFlight cycle ≥1 with feedback addressed.
- Exit: App Review decision (approved/rejected/needs info).
- **CLAUDE-DOABLE? No. USER-BLOCKED + Apple-blocked.**

### A.2 — Standalone gates

**Instruments p99 signpost proof** (EXTENDED_PROGRAM_PLAN W2.1-W2.5:55-61)
- Paths needing signposts: render frame (Metal graph + SwiftUI), MCP tool invoke, GRDB query, every UniFFI call site, MLX inference token gen + matmul.
- Budget (`perf-budgets.toml`): `frame_ms_p99=8.3`, `mcp_invoke_ms_p99=2.0`, `ffi_hot_path_us_p99=5.0`, `cold_start_ms_p99=800`, `binary_size_mb_max=12`.
- Capture: wire `OSSignposter` via `Sources/Telemetry/Sig.swift`; build `Tools/Performance.instrpkg` (subsystem `io.epistemos.core`, categories render/mcp/graph/ffi/storage/inference); run Instruments, export `.trace`.
- Proof: archived `.trace` + CI step parsing `perf-budgets.toml`.
- Status: NOT YET DONE. Deferred to Wave 2 (post-V1) per `EXTENDED_PROGRAM_PLAN`. Not a T+3 ship blocker.
- **CLAUDE-DOABLE? Yes (the wiring + budget file).** Recording requires Instruments.app run.

**ProseEditor instrumentation deferred spike** (RELEASE_HARDENING_CANONICAL_PLAN §2.3:179-188)
- Why deferred: ProseEditor is protected surface (CLAUDE.md DO NOT). Instrumentation = optimization, not blocker fix.
- Unblock: concrete perf symptom (typing latency >50ms p99, jank). Not currently reported.
- **CLAUDE-DOABLE? Don't touch (protected surface, no unblock signal).**

**Distribution-signed archive evidence** (RELEASE_HARDENING_CANONICAL_PLAN §6.3:350-354)
```bash
xcodebuild archive \
  -scheme "Epistemos-AppStore" \
  -destination 'generic/platform=macOS' \
  -configuration Release \
  -archivePath "./build/Epistemos.xcarchive" \
  -allowProvisioningUpdates
xcodebuild -exportArchive \
  -archivePath "./build/Epistemos.xcarchive" \
  -exportOptionsPlist "./ExportOptions-AppStore.plist" \
  -exportPath "./build/distribution"
```
- Scheme: `Epistemos-AppStore` (not `Epistemos-Pro`).
- Profile: `Apple Distribution: Epistemos AppStore`.
- Verify: `codesign --verify --deep --verbose Epistemos.app` clean.
- **CLAUDE-DOABLE? Can prepare ExportOptions plist + dry-run script. Actual archive needs Apple Developer signing identity → user.**

### A.3 — V1_SHIP_GATE_DECISION P0 list (from PHASE_S_AUDIT, V1_SHIP_GATE_DECISION:86-99)

| # | Criterion | Status | Owner |
|---|---|---|---|
| 1 | P0 items 1-5 closed (G1, A4/O1, A1, G2, code-editor 4k bench) | PARTIAL | mostly Claude |
| 2 | Reliability gate green on fresh run | PENDING re-run | Claude+CI |
| 3 | Bundle <600 MB CI gate | OPEN — no CI gate exists | Claude (wire CI step) |
| 4 | JIT entitlement justification doc | OPEN | Claude (draft) |
| 5 | AppStoreHardeningTests + Phase R green | PARTIAL — 16/16 design green; full suite pending | Claude+CI |
| 6 | Manual smoke test 15 flows | OPEN | USER |
| 7 | No `try!`/`as!` regression | PENDING grep verify | Claude |
| 8 | No `unbounded` AsyncStream | PENDING grep verify | Claude |
| 9 | No `DispatchQueue.main.sync` | PENDING grep verify | Claude |
| 10 | PrivacyInfo.xcprivacy drift test | PASS (AppStoreHardeningTests:74-85) | done |

### A.4 — Five P0 ship-gate items (V1_SHIP_GATE_DECISION:52-59)

1. **G1** — Pro+Cloud tool path must route through Rust agent loop. Files: `Epistemos/Engine/PipelineService.swift:308-330`, `Epistemos/App/ChatCoordinator.swift:361`. Claude-doable.
2. **A4 / Gap O1** — `omega-mcp` lacks `mas-sandbox` Cargo feature; PTY/osascript primitives compile unconditionally into `libomega_mcp.dylib` shipping in MAS. Static-analysis App Review risk despite zero call-graph reach. Fix: add `mas-sandbox = []` to `omega-mcp/Cargo.toml`; module-gate `pub mod osascript; pub mod pty;` in `lib.rs`; gate UniFFI exports (`uniffi_exports.rs:120-218` + `omega_mcp.udl:47-83`); thread feature through MAS build script. Claude-doable.
3. **A1** — JIT entitlement App Review justification doc at `docs/release/MAS_APP_REVIEW_NOTES.md`. Claude-doable.
4. **G2** — Raw Thoughts V0 under feature flag. ~80% substrate done per COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN. Need flag wiring + UI gating. Claude-doable.
5. **Code editor 4k benchmark gate** — wire SyntaxCoreService into main `CodeEditorView` (currently only graph inspector preview at `:2286`). Per SESSION_SUMMARY §51: BLOCKED — "CodeEditSourceEditor does NOT consume SyntaxCoreService in main editor". Multi-day; defer to V1.5 per session summary. **Defer T+3.**

### A.5 — Reliability gates (5 of 5)

Per APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24:45-56, all green at cutoff:
- Full Swift suite: 4264/4264 PASS
- graph-engine: 2458/2458 PASS
- omega-mcp: 126/126 PASS, omega-ax: 12/12 PASS
- agent_core default: 630 + 2 + 5 + doctests PASS
- agent_core `--features mas-sandbox`: 499 + 2 + 5 + doctests PASS
- Phase R.4-R.6: 43/43 + 32/32 + 14/14 + 25/25 PASS

These already prove reliability gate baseline + ASAN/UBSAN/TSAN/soak_repeat green (per PERF_REPAIR_REPORT:419-425). T+3 needs fresh re-run on current tip (which is canonical floor itself, so should be deterministic).

### A.6 — V1_RELEASE_AUDIT blockers

- mlx-swift fails upstream in `Cmlx` format.cc during full xcodebuild — **need to verify currentstate** (audit doc may pre-date final fixes in canonical chain).
- First-run messaging clarity: rewording of `SetupAssistantView.swift` + `SettingsView.swift`. Not a hard blocker.
- Manual release smoke test: USER.
- Clean V1 branch: current branch `feature/landing-liquid-wave` mixes scopes; release-management cleanup recommended.

---

## §B — Web research findings (primary sources, accessed 2026-04-27)

### B.1 — App Store Connect submission flow
- https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review/ — single-portal review across iOS+macOS; up to 2 parallel submissions allowed.
- https://developer.apple.com/news/upcoming-requirements/ — **HARD DEADLINE 2026-04-28: all new submissions must build with Xcode 26 + macOS Tahoe 26 SDK**. No legacy SDK accepted.
- **Implication**: T+3 submission path is gated on Xcode 26 toolchain.

### B.2 — TestFlight macOS
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/ — internal testers up to 100, builds available 90 days; TestFlight re-signs builds (embedded profile not used at runtime).
- https://developer.apple.com/videos/play/wwdc2021/10170/ — feature stable since WWDC21.
- TestFlight 3.6+ tester criteria filtering, public link metrics.

### B.3 — Distribution-signed archive
- https://help.apple.com/xcode/mac/current/en.lproj/deva1f2ab5a2.html — `xcodebuild archive` + `-exportArchive` with ExportOptions plist; `method=app-store`, `signingStyle=automatic`, `generateAppStoreInformation=true` (new 2026 key).
- https://developer.apple.com/videos/play/wwdc2023/10224/ — cloud signing now default in Xcode 26; `-allowProvisioningUpdates` auto-fetches certs.
- Two-scheme pattern recommended: `Epistemos-AppStore` (sandbox + JIT) and `Epistemos-Pro` (Developer ID + relaxed entitlements).

### B.4 — PrivacyInfo.xcprivacy required-reason API codes (relevant for notes app)
- https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons
- https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest
- Codes: `CA92.1` (UserDefaults), `C617.1` (FileTimestamp), `35F9.1` (SystemBootTime), `E174.1` (DiskSpace).
- Mandatory since 2024-05-01; still enforced 2026. App Review gates submissions with missing/mismatched codes (ITMS-91053).
- **Status in repo**: Already declared per PRIVACY_APP_STORE_AUDIT — drift-tested via `AppStoreHardeningTests:74-85`. ✅

### B.5 — os_signpost / OSSignposter
- https://developer.apple.com/documentation/os/ossignposter — modern Swift 6 API: `OSSignposter.beginInterval(_:)` / `endInterval(_:_:)`, `.pointsOfInterest` category default in Instruments.
- https://developer.apple.com/videos/play/wwdc2025/308/ — message parameter on `endInterval()` displays in Instruments timeline.
- Pattern: `let interval = signposter.beginInterval("DataProcessing"); defer { signposter.endInterval("DataProcessing", interval, "\(count) items") }` — overhead ~1-2 ns.

### B.6 — App Store Review Guidelines binding paragraphs
- §2.4.5(i) Sandboxing: "**For apps distributed on the Mac App Store, they must be appropriately sandboxed**, and follow macOS File System Documentation. Apps must be single app installation bundles and cannot install code or resources in shared locations."
- §2.5.2 Downloaded code: "**Apps should be self-contained in their bundles, and may not... download, install, or execute code which introduces or changes features or functionality of the app**, including other apps."
- 2026 enforcement: Replit + Vibecode blocked March 2026 for executing user-generated code. LLM inference is fine; LLM codegen-then-execute is not.

### B.7 — Security-scoped bookmarks
- https://developer.apple.com/documentation/foundation/nsurl/startaccessingsecurityscopedresource() — balanced start/stop required; `defer { stop }` mandatory.
- Staleness: when user revokes access or file moves, `bookmarkDataIsStale = true` → recreate.
- Swift 6 concurrency: serialize start calls or hold one start for lifetime of all tasks; concurrent start can deadlock sandbox.

### B.8 — Notarization vs MAS entitlement diff
| Aspect | MAS (Sandbox) | Developer ID (Notarized) |
|---|---|---|
| Sandbox | mandatory | optional |
| Hardened Runtime | optional | required for notarization |
| `cs.allow-jit` | permitted; needs justification | permitted |
| Signing identity | Apple Distribution | Developer ID Application |

---

## §C — Conjugation (disk × web × doctrine)

**Q1: Is mlx-swift upstream blocker still real?**
- Disk: V1_RELEASE_AUDIT flags it as P0 BLOCKED. APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24:45-56 shows "Release build: `Epistemos-AppStore` + `Release` profile + `CODE_SIGNING_ALLOWED=NO` — BUILD SUCCEEDED" — meaning code signing was disabled. So unclear whether mlx-swift fully builds with Distribution-signed flow.
- Web: no specific Apple guidance on mlx-swift.
- Doctrine: per CLAUDE.md, MLX-Swift is in-process inference path; cannot punt.
- **Synthesis**: must verify by attempting fresh build. Action: T+3 verification slice.

**Q2: Should Claude execute the 4 doable P0 items in T+3 or split into 4 separate phases?**
- Disk: prompt's chronological queue treats T+3 as one phase with multiple slices, gated by deliberation brief.
- Web: no constraint.
- Doctrine (MASTER_BUILD_PLAN §10): each slice gets own commit + WRV proof. Multiple slices in one phase is normal.
- **Synthesis**: execute as 4 slice commits within T+3, each with its own WRV proof.

**Q3: Is the omega-mcp gap O1 fix safe to land without invalidating shipped agent_core?**
- Disk: MAS_SANDBOX_FEATURE_AUDIT flags zero call-graph reach today; UniFFI emits subprocess primitives but Swift never calls them. Fix is structural (gate visibility), not behavioral.
- Web: nothing relevant.
- Doctrine: MAS hard rule "MAS target NEVER spawns user-installed coding CLIs" — gating is alignment with doctrine, not departure.
- **Synthesis**: safe. Add feature, gate modules, regen UniFFI bindings, verify omega-mcp tests still pass.

**Q4: Can JIT entitlement justification doc be drafted purely from current docs + Apple Developer guidance?**
- Disk: PRIVACY_APP_STORE_AUDIT names A1 as "submission-process item, not code"; PHASE_S_AUDIT confirms entitlement is present in MAS plist.
- Web: Apple's stance (§2.5.2) — JIT permitted with justification. MLX-Swift uses Metal Shading Language compilation; doc must explain.
- **Synthesis**: yes, draft is pure prose work. Reference Apple Intelligence + on-device compute precedent.

**Q5: Is Raw Thoughts V0 flag wiring T+3-scoped or should it move to T+4?**
- Disk: COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN says ~80% substrate done. T+4.3 is "Complete Raw Thoughts substrate to 100%". G2 is V1_SHIP_GATE blocker.
- **Synthesis**: G2 = "Raw Thoughts V0 under flag" = make existing 80% gate-able by flag, not finish to 100%. Different scope. T+3 OK if flag wiring is small (1-2 day).

---

## §D — Trade-off matrix

### D.1 Sequencing of T+3 Claude-doable slices

| Option | Pros | Cons | Risk | Reversibility | Recommendation |
|---|---|---|---|---|---|
| A: Verify-then-fix in 4 strict commits (G1 → A4/O1 → A1 → G2) | clean WRV per commit; matches canonical order | slower wall-clock | low | high (per-commit revert) | **CHOSEN** |
| B: Bundle into one mega-commit | fewer commits | breaks WRV-per-commit doctrine; rollback expensive | medium | low | reject |
| C: Defer all to user (do nothing) | zero risk | Apr 28 deadline missed; user-blocked items still pile up | high | n/a | reject — abdicates the work |

### D.2 omega-mcp gap O1 implementation approach

| Option | Pros | Cons | Risk | Reversibility | Recommendation |
|---|---|---|---|---|---|
| A: Add `mas-sandbox` Cargo feature + module gates + regen UniFFI | doctrinally clean; static-analysis safe; matches agent_core pattern | touches lib.rs + Cargo.toml + UDL + regen pipeline | low (zero call-graph reach today, so behavior change = nil) | high (one-commit revert) | **CHOSEN** |
| B: Post-build scrub script | minimal source change | brittle; runs at MAS build time only; future devs may miss | medium | medium | reject — last resort |
| C: Reuse existing | no work | leaves the static-analysis risk for App Review; Apr 28 is tomorrow | high (rejection) | — | reject — do nothing not viable |

### D.3 mlx-swift verification approach

| Option | Pros | Cons | Risk | Reversibility | Recommendation |
|---|---|---|---|---|---|
| A: Try fresh full build first; only investigate if it fails | fast; cheap; the audit doc may already be stale | uses build cycles | low | n/a | **CHOSEN** |
| B: Read mlx-swift source for format.cc state up-front | no build needed | high cost; format.cc may not even be the current bug | medium | n/a | reject |
| C: Pin mlx-swift to known-working SHA preemptively | guarantees build green | masks real status | medium | medium | reject — cargo-cult fix |

---

## §E — Decision

**Chosen path** (T+3 Claude execution plan):

1. **Verification slice** (combined): fresh build attempt + grep gates (try!/as!/unbounded/main.sync) + AppStoreHardeningTests run + omega-mcp + omega-ax test + PrivacyInfo drift test. Surface mlx-swift state.
2. **Slice G1** — Pro+Cloud tool routing fix at `PipelineService.swift:308-330` + `ChatCoordinator.swift:361`.
3. **Slice A4/O1** — omega-mcp `mas-sandbox` Cargo feature + module gate + UniFFI regen. Verify both default and `--features mas-sandbox` compile + tests pass.
4. **Slice A1** — Draft `docs/release/MAS_APP_REVIEW_NOTES.md` JIT entitlement justification + scoped allowed_paths rationale.
5. **Slice G2** — Raw Thoughts V0 flag wiring (gate existing 80% under flag; minimal-impact UI gating).
6. **Defer to V1.5**: Code editor 4k benchmark gate (BLOCKED per SESSION_SUMMARY §51; multi-day re-architect).
7. **Surface to user** (USER-BLOCKED): S.1 launched-app dogfood manual run, S.7 ASC metadata + screenshots + privacy form, S.8 TestFlight cycle, S.9 submission, manual workflow matrix QA, Distribution-signed Archive (Apple signing identity).

**Rationale**: Apr 28 Apple deadline is tomorrow; canonical floor + 5-gate-green baseline + AppStoreHardeningTests already give us a strong release candidate posture. The 4 Claude-doable P0 slices close the V1_SHIP_GATE_DECISION code-side blockers so the user can complete ASC submission paths in parallel.

**Risks accepted**:
- mlx-swift may still be broken; verification slice catches it. Reversal trigger: if format.cc fails on fresh build → escalate, defer T+3 ship attempt, surface upstream investigation as separate slice.
- §3.5 doctrine drift remains until T+4.8 (per user decision).
- §6 status drifts remain until T+13 (per user decision).

**Risks deferred**:
- ProseEditor instrumentation (no perf signal triggers it).
- Pro tunneling work (T+6).
- Bundle-size CI gate (criterion 3 of V1_SHIP_GATE_DECISION) — wire as small CI patch separately if time.

**Success metric**:
- 4 Claude-doable P0 slices land with WRV proof + green tests.
- Verification slice produces fresh `artifacts/reliability/` evidence.
- User receives clear handoff list for S.1/S.7/S.8/S.9 work + Apple Developer signing.

**Reversal trigger**:
- mlx-swift upstream blocker on fresh build → halt T+3 ship sequence, surface as bigger problem.
- Any commit fails AppStoreHardeningTests or PrivacyInfo drift test → revert + reassess.
- Stash@{0} surfaces unexpected dependency on G1/A4/A1/G2 surfaces → escalate.

**Citations**:

Disk:
- `/Users/jojo/Downloads/Epistemos/docs/architecture/RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md` (§§2.3, 4.1-4.5, 5, 6.1-6.3)
- `/Users/jojo/Downloads/Epistemos/docs/architecture/PERF_REPAIR_REPORT_2026_04_21.md` (§0-7, follow-up)
- `/Users/jojo/Downloads/Epistemos/docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` (W1.1-W1.4, W2.1-W2.5, W7.17)
- `/Users/jojo/Downloads/Epistemos/docs/audits/SESSION_SUMMARY_2026_04_25.md` (§51, §90-114, §131-137)
- `/Users/jojo/Downloads/Epistemos/docs/PHASE_S_AUDIT.md` (§1a/1b, §3, §5, §6)
- `/Users/jojo/Downloads/Epistemos/docs/architecture/CHAT_TRANSPARENCY_PLAN_2026-04-19.md`
- `/Users/jojo/Downloads/Epistemos/docs/V1_RELEASE_AUDIT.md` (§4, §10)
- `/Users/jojo/Downloads/Epistemos/docs/audits/PRIVACY_APP_STORE_AUDIT.md`
- `/Users/jojo/Downloads/Epistemos/docs/audits/V1_SHIP_GATE_DECISION.md` (gate criteria 86-99)
- `/Users/jojo/Downloads/Epistemos/docs/audits/MAS_SANDBOX_FEATURE_AUDIT_2026_04_25.md` (gap O1, table 96-144)
- `/Users/jojo/Downloads/Epistemos/docs/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md`

Web (all accessed 2026-04-27):
- https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review/
- https://developer.apple.com/news/upcoming-requirements/
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/
- https://developer.apple.com/videos/play/wwdc2021/10170/
- https://help.apple.com/xcode/mac/current/en.lproj/deva1f2ab5a2.html
- https://developer.apple.com/videos/play/wwdc2023/10224/
- https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons
- https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest
- https://developer.apple.com/documentation/os/ossignposter
- https://developer.apple.com/videos/play/wwdc2025/308/
- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/documentation/foundation/nsurl/startaccessingsecurityscopedresource()
- https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- https://developer.apple.com/documentation/xcode/configuring-the-hardened-runtime
