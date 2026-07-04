# Epistemos — MASTER remaining-work list, ALL lanes (2026-07-04)

Consolidated from: the live task list, the SS-FOLLOWON ledger, every recent handoff doc, and the
loop-state memories. **Confidence note:** the Front & Feel items are verified by me this session; the
OTHER-lane items are summarized from those lanes' own handoff docs and may have progressed since (the
Pro / MAS / Graph agents are actively working). Doc paths are given so an agent can get the detail.

---
## A. FRONT & FEEL lane (verified this session)

**Genuinely blocked / owner-gated queue (the 3 you see):**
- **#40 Recall "Open Chat" no-op** (NoteDetailWorkspaceView:950 `case .chat: break`) — opening a chat
  needs a chat-view-by-id that only exists in the **mas-agent's** lane. Can't wire without their surface.
- **#42 EpdocBlockTemplateStore → slash menu** — the Epdoc slash insert is a JS `blockType` contract;
  needs a NEW Tiptap JS node/handler + `build-tiptap-bundle.sh` rebuild (npm) + WKWebView runtime verify.
- **#46 VaultIndexActor FTS-delete ordering restructure** (MED) — app's most-critical data path; the
  TEST TARGET is Goose-blocked (see §E), so a restructure ships build-verified but NOT test-verified.
  Needs a test unblock + owner sign-off.

**Deferred with a documented reason (SS-FOLLOWON ledger):**
- **Editor content-process-crash AUTO-recovery** — all 3 WKWebView editors now LOG crashes (telemetry);
  full auto-recovery deferred because a naive reload autosave-overwrites the note with empty content;
  correct fix = re-push live `latestMarkdownSnapshot` before re-enabling input, runtime-tested.
- **DATA-IMPORT-1** — arXiv import child-ModelContext race needs an IN-APP import spot-check (headless
  can't verify).
- **SS-2S Prose inline-image default-ON flip** — code is READY; owner verify-then-flip
  `EPISTEMOS_PROSE_INLINE_IMAGE_V0` (needs seeing the render on-device).
- **SS-2S async/remote image load** — remote http(s) increment (currently file-URL only).

**Owner decisions (not code):**
- `com.apple.security.network.server` shipping entitlement = guaranteed App Store reviewer question
  (backs the Goose/Work local web surface — drop if not in the submitted build).
- Stale `allow-jit` + `disable-library-validation` in the DEFAULT/Debug entitlements (dead MLX stack;
  AppStore build already clean) — removable from Developer-ID builds, runtime-JIT need unverifiable headless.

**Cross-lane follow-ups I found but can't touch:**
- **Agent-C Sync lane** — VaultIndexActor + VaultSyncService log `lastPathComponent` (note filenames →
  titles) `.public` at ~10 sites (same class as the Notes-lane redaction I fixed).
- Prior-loop items: SS-VIS (Epdoc mini-chat panel — agent lane), SS-GE(A) (document-node inline edit in
  both graphs — graph+editor), SS-GE(C) (Metal appearance control — graph lane), SS-LT (local multi-tool
  — agent lane), SUBSTRATE RuntimeRouter LIVE flip (agent lane).

**NEWLY FOUND (deep-check 2026-07-04 — were MISSING from the first compile):**
- **BUG B — Note editor main-thread FREEZE (HIGH, likely STILL OPEN)** — notes display content but the
  editor FREEZES on open. Last-known-unfixed in `GOOSE_HANG_AND_NOTE_FREEZE_HANDOFF_2026_07_01.md` (the
  empty-seed "blank" attempt was reverted `3e33eb271`; the freeze itself remains, and no freeze-fix
  commit has landed since). Prescribed fix = **load-before-mount** in `Epistemos/Views/Notes/ProseEditorView.swift`
  (it currently loads the body in `onAppear` / `.task(id: page.id)` AFTER mount). MEASURE with a spindump
  during the freeze — don't guess.
- **Startup DATA-INTEGRITY toast false-positive (NEW, investigated this session)** — see the separate
  diagnosis; the "found N notes with no body file or vault source" warning can fire when the vault is
  temporarily inaccessible at check time. `AppBootstrap.performStartupIntegrityCheck`.
- **Plan-2 editor deferrals** (`PLAN_2_FINALIZATION_HANDOFF_2026_07_01.md`, app-gated on a green tree):
  **#7** dark/light theme-flip keystroke-loss (MED); **#6** per-section native `.onDrop` target (MED);
  **#5** context fetch off @MainActor (perf, LOW); **#14** CoreEditor custom/accent theme (LOW).
- **HOME_EMBED plan** (`HOME_EMBED_AND_FIXES_PLAN_2026_07_01.md`) — §B bugs/broken features, §C landing
  cleanup, §D HTML-Workspace messiness (partly Front & Feel; cross-check which are still open).

---
## B. GRAPH agent lane
- **Hologram content-alignment UNRESOLVED** — the overlay graph's node content still misaligns; prime
  suspects listed in `docs/handoffs/GRAPH_HOLOGRAM_ALIGNMENT_HANDOFF_2026_07_04.md`.
- DONE recently (from commits): overlay node-click "halfway" split fixed (`23d3f881a`), one shared
  MTLDevice for graph views (`1b45cd057`).

---
## C. MAS / June agent lane
- **June vendor + adapter compiled but NOT exercised in-app** — BLOCKED on an in-app run + owner confirm.
- **Phase-4 proxy wiring** + a MED-deferred **proxy circuit breaker**.
- Detail: `docs/handoffs/PLAN_1_MAS_JUNE_PROGRESS_2026_07_04.md` + `PLAN_1_MAS_JUNE_HANDOFF_2026_07_04.md`,
  `PLAN_1_MAS_FINALIZATION_2026_07_03.md` (minor v1-deferred polish).

---
## D. PRO / OpenChamber agent lane
- OpenChamber + dual-engine surface build (vendored fork `~/dev/openchamber-epistemos`). Live phase
  checklist in the `plan1-pro-openchamber-loop-state` memory. (Pro just fixed the ProAgentRuntimeSupervisor
  Swift-6 break that had the app red — app is GREEN again.)

---
## E. CROSS-CUTTING BLOCKERS (affect everyone)
- **TEST TARGET won't compile** — `WorkSPAServerTests.swift:227` + 5 more test files reference the
  REMOVED Goose `GooseWebSurfaceView` (Pro renamed it to ProAgentSurfaceView). Blocks ALL ~2,679 tests.
  Goose/Pro/MAS builders own the fix. Detail: `TEST_SUITE_BLOCKED_GOOSE_SYMBOL_2026_07_04.md`.
- **App target: GREEN** (was red from ProAgentRuntimeSupervisor actor-isolation; Pro fixed it).
- **Sanctioned external (not bugs):** Kokoro voice-model install (read-aloud disabled until the user
  downloads it via Settings → Voice); Developer-ID notarization.

---
## F. OTHER handoffs with parked items
- **Agent-B hardening** — deferred micro-items (§D of `AGENT_B_HARDENING_HANDOFF_2026_07_04.md`) +
  ARX-NET-1 (search-transfer only has a post-hoc 5 MiB cap; parked, low value).
- **Non-Goose UI deep-clean** — next structural cleanup = the largest remaining SwiftUI files by line
  count (`NON_GOOSE_UI_DEEP_CLEAN_HANDOFF_2026_07_02.md`).
- **Note/MarkEdit audit** — a Remaining Work Queue at §434 of `NOTE_GOOSE_MARKEDIT_AUDIT_PROGRESS_2026_07_02.md`.

---
## Reference: App Store review notes
`docs/handoffs/APP_STORE_REVIEW_NOTES_2026_07_04.md` — verified trust posture + entitlement/manifest
justifications + reviewer-question pre-answers.
