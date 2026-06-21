# Osaurus Act Build — Living Progress (started 2026-06-21)

Single source of "done / next" for the Osaurus-first walk. Each loop iteration:
read this, pick the next `[ ]`, build to the real-state done bar, commit, update this.
Grounded in real files only (anti-hallucination). Authority: `OSAURUS_P3_IMPORT_PLAN_2026_06_19.md`
+ `_2026_06_21_addendum.md` + `CHAT_BACKEND_QUARANTINE_NEVER_DELETE_2026_06_21.md`.

## Slice status (per import plan §"Sequenced slices")
- [x] **S1 — Seam A** (pre-existing, verified by file-read this session):
  - `Epistemos/ActOsaurus/ActOsaurusBridge.swift` — protocol + `InertActOsaurusBridge`
    (honest inert default) + `OsaurusActBridge` growth point + `ActOsaurusBridgeFactory`.
  - `Epistemos/ActOsaurus/ActOsaurusGateStatus.swift` — flag `EPISTEMOS_ACT_OSAURUS_V0`,
    always-compiled, honest "Pro only" on MAS.
  - `Epistemos/Views/Settings/ActOsaurusHealthRow.swift` — visible, registered in
    `SubstrateHealthPanel` → `SettingsView.swift:501` (`.substrateHealth`).
  - `EpistemosTests/ActOsaurusSeamTests.swift` — 6 @Test incl. MAS/Pro boundary guard.
  - Adapter stubs: `Epistemos/Vendor/Osaurus/{OsaurusChatMessage,ServerHealth,OsaurusVendorProvenance,OsaurusVendorLocalization}.swift`.
- [x] **S2 — vendor the full repo** (DONE 2026-06-21, commit `ae911ea5e`):
  `LocalPackages/osaurus/` full clone @`ae3a3c5d`, MIT direct_import, `.git` stripped,
  `VENDOR.md` + `scripts/update-osaurus.sh`. **Source-on-disk only — NOT xcodegen-linked.**
- [!] **S3 — link the FULL `OsaurusCore` (owner 2026-06-21: full Osaurus, MAS no longer a hard
  constraint).** Deep entitlements research done → `docs/research/OSAURUS_MAS_ENTITLEMENTS_RESEARCH_2026_06_21.md`.
  FINDINGS: ~95% of Osaurus fits MAS by standard entitlements (server=`network.server`,
  relay=`network.client`, MLX/MCP/SQLCipher/plugins/telemetry); the ONLY MAS blocker is the
  **Linux-VM sandbox** (`com.apple.security.virtualization` — a RESTRICTED entitlement Apple grants
  only to virtualization-software vendors). Per owner's rule (can't fit all → don't be strict):
  **main app = direct-distribution (notarized, non-sandboxed) carrying the FULL Osaurus incl. the VM
  sandbox** — no feature cut, no MAS-struct excuse. REMAINING WORK (in order):
  1. **Resolve the dual-MLX clash** — consolidate Epistemos onto Osaurus's `vmlx-swift` (drop
     `mlx-swift-lm`; both define `MLX*` modules → can't coexist). This is the real "no clashes" task.
  2. Add OsaurusCore SPM dep to project.yml + adjust signing/entitlements (drop the MAS-only sandbox
     constraint for the main build). 3. Build-verify. 4. Reskin to pixel-art (the video experience).
  Gating note: the old `#if !EPISTEMOS_APP_STORE` Pro-gate on the seam stays (a MAS build can still
  omit ONLY the VM sandbox), but it no longer constrains the main app.
- [ ] **S4 — Act agent-turn through OsaurusCore** + reskin composer to pixel-art chrome.
  (Partial: `OsaurusActBridge.runTurn` already POSTs to the osaurus-PATTERN `LocalModelServer`,
  but not yet through linked OsaurusCore.)
- [ ] **S5 — Containerization Linux-VM sandbox** (Pro/dev, virtualization entitlement, no-hidden-fallback).
- [ ] **S6+ — server endpoints, MCP, plugins, privacy filter, identity/relay** (each gated/logged/MAS-excluded).

## Cross-cutting (post-clone, per addendum)
- [ ] **Surface-wiring:** ALL chat surfaces (main ChatView, MiniChat, NoteChatSidebar,
  Graph/Hologram*, + sweep) → ONE shared act composer. Map each surface → real proven
  front-end BEFORE wiring; prove (real-state/launch-smoke). No dead surfaces.
  - [x] First surface wired (DONE 2026-06-21, real-state verified): **Epistemos Picks VIEW** —
    `Epistemos/Views/Settings/EpistemosPicksSectionView.swift` renders the curated provider in
    pixel-art (reuses `InlineRuntimePickerPanel`'s exact live-state→Environment mapping + honest
    selection), mounted as a leading "Epistemos Picks" Section in the existing proven
    `ModelStackSettingsView` (visible in the model-manager sheet). The same component the act
    composer mounts in S4. **VERIFIED:** app target compiles clean (0 errors) + 12/12 tests green.
- [x] **"Epistemos Picks"** — DONE 2026-06-21 (real-state verified, commit `519aed305`).
  `Epistemos/Engine/EpistemosPicks.swift` = pure `nonisolated enum` curating the owner's hardened
  models (Gemma QAT ladder via `EpistemosFoundationLineup` + explicit Qwen extras + curated
  Apple-Intelligence) into a top-billed "Epistemos Picks" section, separated from generic
  "Installed Models". Reuses the proven `EpistemosRuntimePicker` (no new model layer); honest
  selection inherited verbatim (`Option.isSelectable`/`blockedReason` via `LocalChatModelMemoryGate`)
  → NO silent Qwen, too-large stays visible with reason. **VERIFIED:** compiles into the app module
  (0 errors) + all 4 @Test pass (curated-first, installed-separated, honest-too-large, nothing-lost)
  via `xcodebuild test` ("** TEST SUCCEEDED **", 12/12). REMAINS: render it in the act model-stack
  view (S4, minimal pixel-art) — that UI wiring is the not-yet-done part.
- [x] **Discovery sweep** (DONE 2026-06-21 — `docs/research/OSAURUS_SURFACE_DISCOVERY_SWEEP_2026_06_21.md`):
  enumerated 7 distinct chat surfaces (main/MiniChat/Note/Graph/Landing + verify HTMLWorkspace/Shadow),
  the shared backend consumers (`InferenceState`/`EpistemosRuntimePicker`/`ChatCoordinator`/`Composer*`),
  work-mode seam, settings model surfaces, OUT list, ripple effects. **Verdict: ONE shared act composer
  over `ChatCoordinator` + `InferenceState` + `Composer*`/`ChatInputBar`.** Re-run critic each cycle.
- [ ] **Port owner IP** (system prompts + hidden pieces) onto Osaurus engine; **WORK mode**
  (Goose/OpenCode) clone/port too.

## Standing rules in force
- **MAS is NOT a hard constraint (owner 2026-06-21).** Never cut an Osaurus feature or "lose its
  osaurus-ness" to stay MAS-sandbox-compliant. Main app = direct-distribution (notarized) carrying
  the full Osaurus incl. the VM sandbox. MAS-fit was researched by ENTITLEMENT (see entitlements
  doc); only the restricted virtualization entitlement genuinely can't fit MAS. Do NOT use "MAS
  structure" as an excuse to cut corners — resolve clashes properly.
- **Conflict → favor Osaurus**; cherry-pick only the owner's *compatible* IP; front-end =
  minimal Epistemos pixel-art. (addendum, owner 2026-06-21)
- **NEVER delete chat** — quarantine only; port IP first; retire only after IP-ported +
  act-parity-proven + data-migrated + OWNER-OK.
- No fake-done (real-state test, not build-green); flag-OFF = staged. main-only;
  `git add` own files only; commits Co-Authored-By Claude.

## Verified build baseline (2026-06-21)
`xcodebuild test -scheme Epistemos -destination 'platform=macOS'` (warm) → **0 errors,
** TEST SUCCEEDED **, 12/12** (8 Osaurus-seam + 4 Epistemos-Picks). This means:
- The full **app module compiles clean** — including the flagged **chat-picker enumeration
  commit** (build-state was UNVERIFIED per the continuation prompt) → **now VERIFIED OK, no
  fix/revert needed**; flag cleared.
- `EpistemosPicks` + `ActOsaurus` seam are real-state green.
The vendored `LocalPackages/osaurus` is NOT in this build (S3 not yet linked) — expected.

## Session log
- 2026-06-21: triaged + dropped 24 forgotten stashes (`44f7e07df`, archive in
  `docs/stash-triage-2026-06-21/`). Vendored full Osaurus (`ae911ea5e`, S2). Discovery
  sweep (`e84fd4110`). Epistemos Picks provider+tests (`519aed305`). Verified build pass:
  12/12 tests green, app module clean, chat-picker commit verified.
