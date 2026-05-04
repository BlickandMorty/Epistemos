# CODEX_VERIFIED_STATE_2026_04_25.md — Canonical audit boundary

> **Authored**: 2026-04-27 (post-cutoff capture).
> **Role**: **THE canonical verified-work floor.** This is the line in the sand. Every commit in §1 was verified through one of two strict audit chains (Codex release-audit workflow OR Claude full_session_orchestrator with WRV gates). Every commit AFTER `ac8c6d28` — even if it landed in the repo — **must be called into question and re-audited** before being treated as canonical.
> **Branch state at cutoff**: `feature/landing-liquid-wave`. Two parallel audit chains converged here.
>   - **Codex audit chain** ended at HEAD `a6f0fa99` (S.5 reliability all 5 gates green; final test verification 27/27 passed).
>   - **Claude orchestrator chain** ended at HEAD `ac8c6d28` (AnyView 16-violation cleanup; 6 major commits this session, all green).
>   - **`ac8c6d28` is the final canonical HEAD.** Restart fresh from there.
> **Critical canonical rule**: any code/docs/changes that landed between `ac8c6d28` and the next session — even if claimed "verified" elsewhere — **MUST be audited by both Claude (builder) and Codex (reviewer)** before being treated as canonical. **Do not trust continuity.** The audit chains were actively running when cut off; resuming requires re-establishing them, not assuming work survived in shape.

---

## §1 — Verified accepted commits (TWO audit chains converged here)

These commits passed strict audit through one of two chains:
- **Codex release-audit chain** (~30 commits): independent diff review + raw-log evidence + protected-path checks + WRV gate
- **Claude orchestrator chain** (~6 commits): full_session_orchestrator with file:line citations + WRV proof + tests/build evidence per item

Each carries its evidence trail. **None are tentative.** **`ac8c6d28` is the final canonical HEAD.**

### §1.0 — Claude orchestrator chain (final 6 commits — landed near cutoff)

| Commit | Item | Description | Closes |
|---|---|---|---|
| `4c0c7e17` | **D4** | Hermes 36B → Qwen 3 8B fallback (16 GB Mac OOM safety) | **Blocker resolved**: 16 GB unified-memory budget violation when 36B Hermes loaded; Qwen 3 8B fits within ~10–11 GB realistic budget |
| `9750ad11` | D4 tracker | Status update to V1_5_IMPLEMENTATION_TRACKER for D4 closure | — |
| `fe97e512` | **W9.27 PR3 + D1** | `prev_hash BLOB` column + BLAKE3 Merkle chain on RunEventLog | **2 Blockers resolved**: provenance integrity primitive (the §3.5 four-layer event hierarchy's integrity layer in `MASTER_FUSION.md`) is now real, not aspirational |
| `766b38fe` | W9.27 tracker | Status update for W9.27 closure | — |
| `6cd47481` | **Pass #3** | `docs/architecture/` fusion: Drift A (CommandCenterRequestCompiler) + Drift B (three-router) | Architecture drift resolved per CANONICAL_AUDIT_LOG Pass #3 |
| `ac8c6d28` | **AnyView cleanup** | 16-violation cleanup of Doctrine §6 #6 enforcement | **Top-of-queue Blocker** from `MASTER_FUSION.md §6.10` resolved (Lane A, ~2 hr) |

**Result**: V1_5 execution queue gained meaningful closure on the integrity layer (BLAKE3 Merkle chain proves the §3.5 doctrine is now substrate-real), the OOM Blocker is gone (Qwen 3 8B fallback), and the AnyView violation was the single most-cited Doctrine #6 #6 anti-pattern across the audit logs.

### §1.0a — Stashed work (recoverable but NOT YET verified)

```
stash@{0}: session-stash-2026-04-27:
  W9.21 PR4 (X salvaged) + W9.8 wire-up partial; restart-fresh per user
```

**Status**: ⚠️ **STASHED, NOT VERIFIED.** This work is recoverable but had NOT passed audit at cutoff. When resuming:
- W9.21 PR4 = Swift consumer cutover for honest-FFI handles (~1.5 hr Lane C, top-of-queue per `MASTER_FUSION.md §6.10`)
- W9.8 = NSAlert → ApprovalModalView production wire (~2 hr Lane C, top-of-queue per `MASTER_FUSION.md §6.10`)

To resume: `git stash show -p stash@{0}` to inspect, then either pop and re-audit fresh, or discard and re-implement clean per the master plan. **Do NOT pop and trust the stash without WRV proof + Codex audit.**

### §1.1 — Codex audit chain (Phase S release hardening)

### Phase S — Release Hardening

| Commit | Phase | Description | Evidence |
|---|---|---|---|
| `8633773a` | S.2 | Baseline App Store hardening with file:line citations + 5-test source-text policy guard | MAS build green; AppStoreHardening 5/5 |
| `b971eaa5` | S.2 | Entitlements drift suite (7 tests) — 274s slow case identified as Swift Testing first-test-cold cost | AppStoreHardening 7/7 in 0.091s |
| `b6a4fa12` | S.2 | Process/NSTask audit corrective (Category C with full Process.init coverage) | Source scan; 14 sites classified |
| `d77011d4` | S.2 | Doc corrective: removed stale "no MAS build produced" + dropped wrong "notarization" wording | Independent codesign on Debug MAS app verified `com.epistemos.appstore`, ad-hoc, sandbox=true, 5 entitlements match source |
| `2c41f2cc` | S.4 | Corrected bookmark/write-cycle test: startup validation assertion, removed force unwraps, ASCII-only | 91 tests / 0 failed in full Swift slice |
| `c0acdd7b` | S.5 | Refreshed `perf_diagnostics` gate + standalone graph/search/runtime perf-suite baseline | 59 tests passed in 4.2s; 6 reliability tests / 1200 cases / 47.5s |
| `a3a55d6f` | S.5 | os_signposts on verified-write paths (note save/write timing instrumentation) | MAS green; Pro hardening 16/16 |
| `8430da67` | S.5 | Reliability runner hang analysis (Pro test runner timing out at 382.6s) | Live evidence, no false success |
| `9b6d66ff` | S.5 | §8.9 evidence: TCC `kTCCServiceSystemPolicyAllFiles` + `SystemPolicyDownloadsFolder` AUTHREQ on PID 21860/26228 | macOS unified log evidence per PID |
| `a83162fb` | S.5 | Baseline retry failure docs — runner hung again, kept S.5 explicitly OPEN (no false-green) | Same hang signature reproduced |
| `9c49920a` | S.5 | §8.9 corrective wording: "xcodebuild test with implicit build" (not "test-without-building"); fixed PID 26228 timing claims | Doc-only |
| `d46594c8` | S.5 | Reliability script `DERIVED_DATA_ROOT` env support: defaults outside `~/Downloads`/`~/Desktop`/`~/Documents` to avoid TCC prompts | bash -n + 23-test ReleaseScriptAuditTests guard |
| `a6f0fa99` | S.5 | **CODEX CHAIN CUTOFF COMMIT** — Full reliability gate green evidence: baseline + ASAN + UBSAN + TSAN + soak_repeat all passed | All 5 gates green per /tmp logs |
| `adf67b30` | S.6 | PrivacyInfo manifest drift tests + Settings → Privacy pane + 13-section sidebar update | 94 tests in 3 suites passed; MAS build green |
| `a718e326` | S.3 | S.3 inventory (audit doc) | Doc-only |
| `e0a047d1` | S.3 | S.3 wording correction (overclaim cleanup) | Doc-only |
| `87e5958d` | S.3 | S.3 plan reframe — Section 9 renamed "active implementation work"; ProseEditor pinned as protected surface | Doc-only |
| `d1833d4c` | S.3a | Settings Dynamic Type (AgentControlSettingsView fixed→`.caption.weight(.semibold)`) + bookmark-test SourceMirror refactor | Pro test target rebuild green |
| `0bb13b90` | S.3 | OverseerSettingsView Dynamic Type (11 sites) | MAS+Pro green |
| `74ce6fd8` → `8643b76e` → `814a85ae` | S.3 | SettingsView Dynamic Type + ViewThatFits durationControls correction | MAS green; 16/16 Pro hardening |
| `c8d189e2` | S.3 | First Settings Dynamic Type slice accepted | — |
| `5de5c195` | S.3b | Reduce Motion: Landing wave search + Time Machine dismiss path (delays + animations both gated) | Pro hardening green |
| `aa200eee` | S.3c | Reduce Motion: Chat + Notes 24 files (excluding ProseEditor); LiveActivityStrip already had `if reduceMotion { ... }` branch | MAS green; 24-file diff |
| (S.3d) | S.3d | Graph slice — HologramOverlay AppKit `NSAnimationContext` fade refactored into helpers; Reduce Motion direct path bypasses animation entirely | MAS+Pro green |
| `7e29c051` | S.3 docs | Slice 6 docs cleanup | Doc-only |
| `88dd5724` | S.3 Slice 7 | **ProseEditor no-op** — documented decision: no source edit, deferred coordinated editor typography scaling to its own spike | Doc-only with `if (any) F1/F2/F3/F4 finding requires ProseEditor edit, must be a separate explicit spike` |
| `7e0ab209` | S.4 (Localization) | Localizable.xcstrings catalog + 4 first-batch strings; final wording fix removed `xcrun simctl` (iOS-only) | xcstringstool validation; CompileXCStrings + CopyStringsFile in MAS log |
| 22cda61b | S.2 | VaultChatMutator MAS branch: keeps verified write, drops git audit trail; non-SHA placeholder return | MAS+Pro 16/16 with strengthened test (Process.init + git argv marker) |
| 398a977f | S.2 | KnowledgeFusion 5-file surgical gates (AdapterExporter, KTOTrainer, QLoRATrainer, MoLoRA, PythonEnvironmentManager) — Pro keeps subprocess; MAS gets `#if !EPISTEMOS_APP_STORE` defense-in-depth | MAS green; Pro hardening 15-test slice green |
| 328edaef | S.2 (Category B shim) | C shim for `dlopen`/`dlsym` runtime lookup → static linkage; bridging header + Swift call-site swaps | MAS green; 16/16 Pro hardening |
| 9b6d66ff | S.5 | (above) | — |

### What was verified beyond commits

- **Independent `codesign -d --entitlements -`** on the Debug MAS build: bundle id `com.epistemos.appstore`, ad-hoc signature, App Sandbox enabled, embedded entitlements match `Epistemos/Epistemos-AppStore.entitlements` exactly. **No surprise entitlements.**
- **All 5 reliability gates** ran clean outside `~/Downloads` (in `/tmp/epistemos-reliability/`): baseline 6 tests / 1200 cases / 44.3s; ASAN 6/1200 / 68.5s; UBSAN 6/1200 / 44.6s; TSAN 6/1200 / 103.4s with `-Wl,-no_compact_unwind` linker flag (TSAN-only); soak_repeat 8 explicit shell-loop iterations / 8/8 green.
- **Reliability script** is now hardened in three ways: (a) `DERIVED_DATA_ROOT` env support with smart defaults outside protected folders; (b) TSAN-only `-Wl,-no_compact_unwind` flag for the link-personality issue; (c) bounded soak via explicit shell loop instead of `-run-tests-until-failure` (which spun unbounded on this toolchain).
- **ProseEditor protected surface invariant** held throughout the entire session: zero diff against `Epistemos/Views/Notes/ProseEditorView.swift`, `ProseEditorRepresentable2.swift`, `ProseTextView2.swift`. **Verified bit-clean every audit pass.**
- **Graph engine + Metal renderer + HologramController** also held protected (the in-flight work was on `HologramOverlay.swift` for AppKit fade behavior only, NOT on the renderer or physics).

---

## §2 — Phase S status at cutoff (Codex-verified)

| Phase | Status | Evidence |
|---|---|---|
| **S.1** Launched-app dogfood polish | ⚪ **STILL OPEN** | No launched-app UX dogfood evidence captured |
| **S.2** Runtime entitlements | ✅ **VERIFIED** | codesign output independently captured + entitlement drift tests |
| **S.3** Accessibility | 🟡 **SUBSTANTIAL — NOT DECLARED CLOSED** | Slices 3a/3b/3c/3d/4 (loc)/5/6/7 landed; ProseEditor explicitly deferred as no-op spike |
| **S.4** Hardening tests | ✅ **VERIFIED** | Bookmark/write-cycle proof + AgentQueryEngine + LocalAgentLoop ceiling |
| **S.5** Perf gates | ✅ **ALL 5 GATES GREEN** | baseline + ASAN + UBSAN + TSAN + soak_repeat |
| **S.6** Privacy posture | ✅ **VERIFIED** | 13-section sidebar + Privacy pane + manifest drift tests; 27/27 final pre-cutoff |
| **S.7** App Store Connect metadata | ⚪ **STILL OPEN** | Not started |
| **S.8** TestFlight cycle | ⚪ **STILL OPEN** | Not started |
| **S.9** Submission/review response | ⚪ **STILL OPEN** | Not started |

---

## §3 — Critical invariants verified throughout the audit loop

These held without exception across every Codex pass. They are the **release floor**:

1. **ProseEditor protected surface**: zero diff in `Epistemos/Views/Notes/ProseEditor*.swift` files across all 30+ commits. Codex re-checked this after every accepted slice.
2. **Graph engine / Metal renderer / HologramController protected**: the only graph-adjacent edit was `HologramOverlay.swift` AppKit fade refactor (Reduce Motion direct path), no engine/physics/rendering changes.
3. **Generated `libsyntax_core.rlib` artifact never staged**: every commit's staging set was inspected; this Rust build artifact remained dirty but uncommitted across the entire session.
4. **`git diff --check` clean** on every accepted commit (no whitespace damage).
5. **Source-mirror tests** always pointed to the test bundle's `SourceMirror/` resources (NOT the user's `~/Downloads/Epistemos/` working tree), preventing TCC prompts from breaking hardening tests.
6. **`@MainActor` boundary** held: heavy FFI / vault crawling / model load / embedding all stayed off main thread.
7. **No experimental 3D graph work**: the "3.d" notation throughout was Phase S.3 sub-slice d (graph-adjacent UI motion), NOT a graph rendering rewrite. Codex re-asserted this multiple times when the user asked.
8. **MAS / Pro split honesty**: every gate explicitly tested both targets; no silent cross-contamination.
9. **No notarization wording on MAS path**: `d77011d4` corrected this — Mac App Store submission ≠ Developer ID notarization.
10. **Honest non-claims**: every commit kept S.5 explicitly OPEN (Instruments p99 signposts + ProseEditor typing perf still pending) and never claimed "release-ready."

---

## §4 — THE AUDIT BOUNDARY — every commit after `ac8c6d28` is suspect until re-audited

> ⚠️ **CANONICAL AUDIT BOUNDARY**: `ac8c6d28` is THE last verified canonical HEAD. **Any commit, doc edit, file change, stash pop, or branch operation that happened after `ac8c6d28` — regardless of who did it, when, or how green it looked at the time — must be called into question and re-audited before being treated as canonical.** This is not paranoia; it is the discipline that produced the ~36 verified commits in §1. Continuity is not inherited; it is re-proven.
>
> **Rule of thumb**: if you cannot point to either (a) a Codex release-audit-workflow accepted commit OR (b) a Claude full_session_orchestrator commit with WRV proof + file:line evidence + green tests, then the work is **suspect** and goes through the §4.2 re-audit checklist before being trusted.
>
> **What this means in practice**:
> - "I committed this and it built" → NOT verified. Build green ≠ audit accepted.
> - "Tests pass" → NOT verified. Tests green ≠ all five WRV/protected-path/doc-honesty/build/perf checks pass.
> - "It's in the canonical fusion docs" → NOT verified if it landed after `ac8c6d28` without going through the audit chain.
> - "Codex/Claude already verified this earlier" → ONLY verified if the commit hash is listed in §1 above. Anything else is suspect.

### §4.1 — In-flight work at the moment of cutoff

The Codex auditor was in the middle of:

- **Multi-agent hardening + wiring + product expression audit** — a second, larger plan (the "Master Hardening + Wiring Audit" with 10 specialist agents) had just been kicked off in a fresh Claude session. The user pinned the structure (`docs/audits/USER_WIRING_CAPABILITY_MAP.md`, `docs/audits/CODEBASE_CARTOGRAPHY.md`, etc., 10 specialist docs feeding into `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md` → `docs/audits/PATCH_QUEUE.md`), and Codex injected the addendum to keep this nested *inside* the existing blocker-first canon (NOT as a replacement). Claude was still in **Phase 1 discovery**, reading authority docs.
- **Deterministic Knowledge Runtime v1** plan was fully drafted (Phase 0–7) but **had NOT begun implementation**. Phase 0 preflight doc (`docs/DETERMINISTIC_RUNTIME_V1_PREFLIGHT.md`) was the next required artifact.
- **Cognitive workspace plan** (Raw Thoughts substrate + .epdoc Document artifact + Tiptap-in-WKWebView + native code editor refinement) was drafted in detail but **had NOT begun implementation** beyond the prior typed-artifact patches (Patch 4 + Patch 5 pre-cutoff).
- **Final SettingsCategoryTests + AppStoreHardeningTests verification** had just printed `** TEST SUCCEEDED **` with 27/27 green when the session was cut off. Codex was about to re-pin the older Phase S gates as hard prerequisites for the new audit lane.

### §4.2 — Required re-audit checklist for work done outside this convo

If any code/doc changes happened between `ac8c6d28` (cutoff HEAD) and session resumption, they MUST go through this checklist before being treated as canonical:

```
For each new commit since ac8c6d28:
  1. Codex independent diff review:
     - file scope matches stated intent?
     - protected paths untouched (ProseEditor, graph engine, Metal renderer, HologramController)?
     - generated artifacts (libsyntax_core.rlib) unstaged?
     - whitespace clean (git diff --check)?
  2. Codex independent build verification:
     - MAS build (Epistemos-AppStore scheme) green via raw log
     - Pro hardening tests (AppStoreHardeningTests) green
     - SwiftLint plugin failure tail noise NOT counted as actual failure
  3. Codex independent doc accuracy review:
     - claims match actual evidence (no overclaiming)
     - PHASE_S_AUDIT.md status updates match commit reality
     - no new "release-ready" or "notarization" wording on MAS path
  4. ProseEditor invariant re-check:
     git diff ac8c6d28..HEAD -- Epistemos/Views/Notes/ProseEditor*.swift
     # Must be EMPTY
  5. Graph engine invariant re-check:
     git diff ac8c6d28..HEAD -- graph-engine/ Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Graph/HologramController.swift
     # Must be MOTION-ONLY edits if any (no physics/rendering)
  6. If new audit docs landed (USER_WIRING_CAPABILITY_MAP, etc.):
     - read for accuracy against current code
     - flag any "implemented" claims that aren't yet code-evidenced
     - flag any P0/P1 items that touch protected surfaces
```

### §4.3 — Things explicitly NOT verified at cutoff (still pending)

These were known-open from Codex's own honesty discipline:

| Surface | Why still open | Required next |
|---|---|---|
| ProseEditor performance/instrumentation proof | Protected surface, no source edit; no signpost coverage | Coordinated editor typography spike (gated, separate slice) |
| Instruments p99 signpost proof for non-reliability paths | S.5 reliability gates are green, but Instruments traces for editor/graph/chat hot paths NOT captured | Standalone Instruments slice (S.5 follow-up) |
| Manual launched-app UX dogfood | S.1 is wholly open | Scheduled manual session with checklist |
| Distribution-signed archive | Only Debug MAS build verified, NOT a distribution archive | Phase S.7+ work |
| App Store Connect metadata | S.7 not started | New slice |
| TestFlight cycle | S.8 not started | After S.7 |
| Submission/review response | S.9 not started | After S.8 |
| Coordinated editor typography scaling | Slice 7 deferred | Separate spike when prioritized |
| Multi-agent USER_WIRING_CAPABILITY_MAP | Phase 1 discovery just started in fresh Claude session | Resume with same constraints |
| Deterministic Knowledge Runtime Phase 0 preflight | Plan drafted, Phase 0 not run | Run cargo benchmarks + author preflight doc FIRST |
| Cognitive workspace Raw Thoughts substrate (Patches 4+5) | 80% done per `COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` | Resume per that plan; do NOT redefine ArtifactKind |

### §4.4 — Plans on deck but not started

These plans are **fully written and canonical-ready**, but had NOT begun implementation at cutoff:

1. **Deterministic Knowledge Runtime v1** (Phase 0–7): typed mutation envelopes → query fingerprints/watch plans → production view-model adapter → borrowed row projections → raw thoughts bulk lane → static registries → preview cache + graph-bounded prefetch. **Authored**: `claude opt 2.md`, `compass_artifact_wf-97f869bf...md`, `EPISTEMOS_DETERMINISTIC_PERF_PLAN.md`. **GPT advisor verdict**: deterministic invalidation + reduced Swift materialization is the largest remaining win, NOT another transport rewrite. No FlatBuffers, no UniFFI replacement, no Tree-sitter migration, no Metal binary archives **until measurement proves need**.

2. **Master Hardening + Wiring + Product Expression Audit** (5 phases × 10 specialist agents): Discovery → Multi-agent audit → Synthesis → Patch queue → Implement only safe P0/P1. **Required doc structure**: `docs/audits/USER_WIRING_CAPABILITY_MAP.md`, `CODEBASE_CARTOGRAPHY.md`, `USER_WIRING_GAPS.md`, `AMBIENT_RECALL_WIRING_PLAN.md`, `UI_PRODUCT_EXPRESSION_PLAN.md`, `PERFORMANCE_CONCURRENCY_AUDIT.md`, `STABILITY_ERROR_HANDLING_AUDIT.md`, `DATA_PERSISTENCE_INDEXING_AUDIT.md`, `PRIVACY_APP_STORE_AUDIT.md`, `BUILD_TEST_VERIFICATION_AUDIT.md`, `V1_SHIP_GATE_DECISION.md` → `MASTER_HARDENING_WIRING_AUDIT.md` → `PATCH_QUEUE.md`. **Goal**: convert Epistemos's hidden capabilities into user-visible, user-usable, stable, performant, privacy-safe, release-ready surfaces.

3. **Cognitive Workspace Architecture** (vertical slices per `COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md`): Raw Thoughts substrate (80% done) → typed graph types (30% done) → Search/readable block projection → Code editor refinement → .epdoc package stub → Tiptap/WKWebView Document editor → Agent structured edit tools → Export/polish. **Editor verdict** (from `EDITOR_VERDICT_TIPTAP_VS_APPFLOWY.md`): leave Tiptap-in-WKWebView alone for V1.5; benchmark first; take inspiration from AppFlowy data model NOT UI layer.

---

## §5 — Resumption protocol for the next session

When picking this work back up, the agent MUST:

1. **First read `READ_FIRST.md` + this file + `MASTER_FUSION.md` §0.1 (reference fallback algorithm)**.
2. **Verify HEAD vs `ac8c6d28`** — `git log ac8c6d28..HEAD --oneline`. Every new commit is **suspect** until re-audited per §4.2.
3. **Run the ProseEditor invariant check** — `git diff ac8c6d28..HEAD -- Epistemos/Views/Notes/ProseEditor*.swift`. **Must be empty.**
4. **Verify reliability gate evidence is still on disk**: `/tmp/epistemos-reliability/20260425-073340/` (baseline) + the ASAN/UBSAN/TSAN/soak directories. If `/tmp` was cleared, the gates are no longer demonstrable; re-run before claiming S.5 is closed.
5. **Re-pin Codex audit chain**: every new code change goes through Codex audit-loop (diff review → build verification → doc accuracy → invariant re-check) before being declared accepted.
6. **Continue Phase S** before opening new lanes:
   - S.1 launched-app dogfood polish (still open)
   - S.7 App Store Connect metadata (not started)
   - S.8 TestFlight (not started)
   - S.9 submission (not started)
7. **Only then** start the Master Hardening + Wiring Audit's Phase 1 discovery (per §4.4 #2).
8. **Only then** start the Deterministic Knowledge Runtime Phase 0 preflight (per §4.4 #1).
9. **Cognitive workspace** continues per `COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md`'s current state (80% Raw Thoughts done, 30% typed graph types done; resume from there, don't redefine).

---

## §6 — Cross-references

- `docs/_consolidated/00_canonical_authority/MASTER_FUSION.md` — main canonical fusion (this is N4-equivalent rigor pillar applied to release work)
- `docs/_consolidated/00_canonical_authority/MASTER_FUSION.md §6.1.1` — V1 ship-critical hardening (5 RELEASE_HARDENING canonical findings cross-ref)
- `docs/_consolidated/00_canonical_authority/NEXT_SESSION_BOOTSTRAP.md` — single-prompt session bootstrap (must be updated to reference this state)
- `docs/_consolidated/00_canonical_authority/EDITOR_VERDICT_TIPTAP_VS_APPFLOWY.md` — editor decision (still binding)
- `docs/PHASE_S_AUDIT.md` — the canonical Phase S audit log (where Codex recorded all this)
- `docs/_archive/architecture_handoffs/RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md` — the 5 canonical findings RH.1-RH.5 (now mostly addressed — verify against this state)
- `docs/_archive/architecture_handoffs/PERF_REPAIR_REPORT_2026_04_21.md` — concrete bug list from runtime symptoms
- `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` — typed artifact spine implementation plan (resume here)

---

## §7 — Provenance

| Date | Event |
|---|---|
| 2026-04-25 | Codex audit session ran from initial Halo plan review through Phase S.5 reliability gate closure. ~30 verified commits accepted under strict release-audit workflow. Codex chain cut off mid-loop at `a6f0fa99` after final test verification (27/27 passed). |
| 2026-04-25/27 | Claude orchestrator chain ran in parallel/after, closing 6 major commits: D4 (Hermes→Qwen3 8B OOM fix), W9.27 PR3 + D1 (BLAKE3 Merkle chain), Pass #3 (architecture drift fixes), AnyView cleanup. Final commit `ac8c6d28`. Stash@{0} preserves W9.21 PR4 + W9.8 partial — recoverable but not yet verified. |
| 2026-04-27 | Post-cutoff capture authored. **`ac8c6d28` is THE canonical verified-work floor.** Two audit chains reconciled. Any commit since then is suspect until re-audited. |
| 2026-04-27 | Post-cutoff capture authored. Establishes audit boundary so all subsequent work can be cleanly verified against the last-known-green state. |

---

**END OF CODEX_VERIFIED_STATE_2026_04_25.md**

> **Discipline reminder**: Codex's audit loop produced ~30 verified commits because every claim had file:line evidence, every test had a raw log path, every doc statement was independently checked, and every protected surface was diff-verified after every change. **That discipline must continue.** The next agent does NOT inherit "the work is done" — it inherits "this is the verified floor; everything since must re-prove itself."
