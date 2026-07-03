# PLAN_AUDIT.md — Forensic audit of Plans 1–3 (Phase 1)

> Branch feat/goose-surface @ e00edcbd9, 2026-07-02. Method: read the plan docs, then verify each claim against actual code / tests / commits (file:line). Goose (Plan 1) is OUT OF SCOPE per owner — inventoried at doc level only, not audited. Full sweep evidence in HARDENING_AUDIT.md; this is the classification deliverable.

## Verdict summary

- **Plan 1 (Goose)** — OUT-OF-SCOPE. Doc-level only: the reskin-Goose UI plan was formally RETIRED by owner on 2026-07-02 (PROMPT_PLAN_1_GOOSE.md header: "OpenChamber pivot supersedes"). 17 Goose live/staging tests were red in the last full run. Not audited.
- **Plan 2 (Editor / HTML-Workspace / Notes)** — Code deliverables VERIFIED and survived the later bold-cut/deep-clean rewrites; both deferred hard items (#7 theme-flip, #14 custom palette) were later fixed (7f161c3f0). The entire **in-app proof layer was never done**: all 5 HTMLWorkspace capability flags remain `isLive:false` (honest-off), and the capability ledger text is now STALE (describes UI the owner deleted).
- **Plan 3 (Kokoro voice + Browser-Use Pro)** — The most defensible lane: both stacks genuinely code-complete with rigorous honest gating (no fake-flips, no silent AVSpeech fallback, triple MAS compile-gate on browser-use). One hard REGRESSION: KokoroPipeline Float16 broke Release/x86_64 (F-0003 / PLAN-3 HIGH) — fix applied this session, currently uncommitted.
- **Umbrella (HOME_EMBED + deep-clean)** — Home-page embeds are real and animated; the HTML-Workspace bold-cut matches claims byte-for-byte. But the migration is an INCOMPLETE regime change: Browser + browser-use kept parallel utility-window routes, `.meetingNote` window code is dead-but-present, and **the full test suite was RED (62–76 failures) at last measurement with no rerun since** (project "zero test regressions" bar unmet tree-wide).

## Classification table (VERIFIED / PARTIAL / MISSING / REGRESSED)

| Plan | Claim | Verdict | Evidence |
|------|-------|---------|----------|
| 2 | 10 edge-case fix commits landed | VERIFIED | all SHAs f34f80949…404e1e077 exist, subjects match |
| 2 | streaming hardening (.bufferingNewest(256), chunkDropped, 240s timeout) survived rewrite | VERIFIED | HTMLWorkspaceGooseRegenerator.swift:11,33-35,184,263 |
| 2 | LSP hover/def + Outline grafted into live top bar | VERIFIED | CodeEditorView.swift:1729 + "L3-CHROME graft" ~:1783 |
| 2 | blank-editor always-paint + false renderedText==0 validation removed | VERIFIED (code) | MarkEditCoreEditorCoordinator.swift:176-180 (in-app P0 proof NOT done) |
| 2 | crash recorder wired | VERIFIED (code) | AppBootstrap.swift:1694 (runtime crash-recorder-ready.json check never run) |
| 2 | **flip 5 isLive caps after witnessing** | **MISSING** | HTMLWorkspaceCapabilityStatus.swift:30-34 all isLive:false (honest-off; probes wired but never witnessed) |
| 2 | #7 dark/light keystroke-loss → in-place setTheme | VERIFIED (code) | MarkEditCoreEditorView.swift:285; State.swift:99-101 (in-app rapid-flip crash proof pending) |
| 2 | #14 custom palette → closest CodeMirror theme | VERIFIED | MarkEditCoreEditorView.swift:393-419 + full palette; deep-clean extended (Ember/Platinum) |
| 2 | #6 per-section drop | MOOT | owner bold-cut removed drop UI (0 .onDrop) |
| 2 | #5 context fetch off @MainActor | DEFERRED (documented) | HTMLWorkspaceDataFeedPDFContextSource.swift:66-75 (LOW) |
| 3 | Kokoro TTS code-complete, native CoreML, no Python | VERIFIED | VoicePro/ (6) + KokoroPipeline/ (10 src+6 test) |
| 3 | Kokoro gate honest, no AVSpeech fallback | VERIFIED | KokoroVoiceGateStatus.swift:97-165; EpistemosSpeechSynthesizer.swift:258-262 refuses |
| 3 | Kokoro install = external blocker (softened by in-app downloader) | VERIFIED | KokoroModelDownloadService + KokoroVoiceProSettingsSection.swift:70-140 |
| 3 | **KokoroPipeline Float16 broke Release/x86_64** | **REGRESSED** | KokoroSynthesisExecutor.swift:654 + MLMultiArrayHelpers.swift:84 — fix applied this session (F-0003), UNCOMMITTED |
| 3 | Browser-Use Pro vendored + supervised runtime | VERIFIED | BrowserUseRuntimeSupervisor.swift:659-673 python webui on 127.0.0.1:7788; pinned vendors :41-66 |
| 3 | Browser-Use MAS-compatible (compiled out) | VERIFIED | triple #if EPISTEMOS_APP_STORE‖MAS_SANDBOX gate (:63-64,618-620,660-661) + menu gate |
| 3 | Dev-ID notarization = external blocker, not fake-flipped | VERIFIED | BrowserUseSignedBundleStatus.swift:633 + real SecStaticCodeCheckValidity :651-659 |
| 3 | Meeting/STT Apple-native on-device | VERIFIED | EpistemosSpeechAnalyzer.swift:163-178 (macOS-26 SpeechAnalyzer, no cloud) |
| 3 | arXiv P0 PDF fix (%PDF- sniff, .pdf temp) | VERIFIED | ArxivIngestService.swift:85,99 |
| 3 | "honest feature-complete 2026-07-01" | PARTIAL | code+gates support it; ~10 Plan-3 route/doc-parity tests fail (broken by home-embed migration) |
| U | Meeting/arXiv/Browser/Browser-Use embedded home pages | VERIFIED | c2e78edc8,f9eb96c5b; LandingView.swift:176-185; UIState.swift:363-366 |
| U | home-embed leaves no orphan window paths | **PARTIAL (duplicate regime)** | Browser + browser-use keep utility-window routes (EpistemosApp.swift:1504-1513) alongside home pages; .meetingNote window dead |
| U | prose editor crash fixed | PARTIAL | clamp only (ProseTextView2.swift:1841-1847); root cause + note-freeze UNSOLVED |
| U | landing cleanup (C) | MISSING | no commits |
| U | HTML-Workspace bold-cut simplification (D) | VERIFIED | d86cf87bb+e1ce443d5; EditorView 994 / RegenerateSurface 410 lines exact; 2 files deleted |
| U | deep-clean targeted suites green | VERIFIED | 9+ xcresult artifacts in /tmp incl. red/green TDD pairs |
| U | deep-clean "full suite not rerun" | VERIFIED — and last full runs were RED | /tmp/epi_broad_full_20260702_0745 (76 failed/4273); after_parser_0816 (62 failed) |

## Debt left by the plans (tracked → owning phase)

1. Stale honesty ledger — HTMLWorkspaceCapabilityStatus.swift:30,43 enumerate ~15 bold-cut-deleted features (live grep = 0). Ledger's own "not overclaiming" contract violated in reverse. → Phase 4/7.
2. Duplicate surface regimes — EpistemosApp.swift:1504-1513 (utility windows) vs LandingView.swift:182-185 (home pages) for Browser + browser-use; two mount paths → two WKWebView/supervisor instances (browser-use: port-7788 contention). → Phase 5/9 (matches BUP-2, MEET-6).
3. Dead code — UtilityWindowManager.swift:100,135,146,417-418 `.meetingNote` window (no caller). → Phase 7.
4. ~30 stale source-mirror tests encoding the dead window regime (MeetingNoteCaptureServiceTests.swift:573-575, BrowserPlan3Tests.swift:190-204, BrowserUseCodepackPlan3Tests parity ×3) — permanent red until reconciled. → Phase 4 (full-suite triage).
5. Stale handoff line-refs in PLAN_2 handoff (probes moved to HTMLWorkspaceEditorPackageActions.swift:227-256; LandingView call sites shifted). → doc refresh.
6. TODO/FIXME/HACK/XXX across all plan-touched dirs: **0** (genuinely clean).

## Findings routed to HARDENING_AUDIT.md

- PLAN-3 HIGH: Float16 Release fix uncommitted (= F-0003, applied; commit-pending, owner decision — see LESSONS commit policy).
- UMBRELLA HIGH: full suite red (62 failures) never reconciled → Phase 0/4 stop-the-line: rerun + classify (Goose-live = out of scope/environment; stale window mirrors = fix-with-justification; NoteSavingStressTests = real, investigate).
- PLAN/UMBRELLA MED: stale capability ledger; duplicate browser regimes; 5 unproven isLive caps; prose-crash/note-freeze open.
- PLAN-3 LOW-MED: browser-use Gradio 127.0.0.1:7788 no-auth (Dev-ID Pro dev-tool posture — name it in THREAT_MODEL B8/APP_REVIEW_NOTES).

## Exit criteria status
PLAN_AUDIT.md classification table complete with file:line evidence ✅. Obvious breakage patched on sight = F-0003 Float16 (applied). Remaining items are tracked work assigned to owning phases above. Dead code (.meetingNote window) + stale ledger flagged for safe consolidation in Phase 7.
