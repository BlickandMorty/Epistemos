# Owner Return Checklist — Work = OpenGUI Engine Workbench — 2026-06-24 (updated 2026-06-25)

Canon first: `docs/WORK_CANON_STATUS_2026_06_25.md` is the compact current state and file inventory. This checklist is the
owner live-proof path; the ledger is the detailed evidence trail.

Restart prompt: `docs/handoffs/WORK_OPENGUI_MASTER_GOAL_PROMPT_2026_06_25.md` is the copy/paste goal prompt for continuing
the full Work/OpenGUI integration loop without losing the safe-renaming and verification rules.

One-page handoff after an autonomous run. Full detail + per-fire log: `WORK_OPENWORK_PARITY_LEDGER_2026_06_24.md`.
All work is IN THE TREE, UNCOMMITTED (owner away → no commits per guardrail).

NOTE: Work PIVOTED to a native **OpenGUI engine workbench** (multi-engine, OpenCode-first). The older **OpenWork WebView**
surface is now FALLBACK-ONLY (kept until this proof passes). Verify the OpenGUI surface below — NOT the OpenWork preview.

Latest Codex checkpoint (2026-06-25): full app build passed, then the focused Work contract slice passed 63 Swift Testing
tests across native MCP, OpenGUI sidecar frames, OpenWork worker helpers, SPA serving/reskin, and Tool MCP Core. The native
MCP catalog now advertises Epistemos app-native note/vault tools. The Work WebView host was flattened to a full-window,
theme-derived shell with details behind a side toggle; controls were moved, not removed. Runtime/API/storage/protocol names
were intentionally preserved where renaming could break integration.

Follow-up guard pass (2026-06-25): corrected stale permission/question source comments to the live
`harness.on("event")` bridge, guarded against the dead `subscribeHarnessEvents` request-model wording returning, and guarded
the Epistemos-facing launch button labels. Focused Xcode run: `** TEST SUCCEEDED **`, 12 tests in 3 suites, result bundle
`/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_08-47-16--0500.xcresult`.

## 1. DO THIS FIRST — verify the OpenGUI Work surface (debug build)
1. Rebuild: **⌘R** (Debug; `com.epistemos.app`, sandbox OFF → the sidecar can spawn). Uncommitted source → rebuild required.
2. Open it: **Settings → Advanced → "Epistemos Work" tab → button "Open Epistemos Work"**.
   (The other button, "Open Epistemos Work preview", is the OpenWork fallback — not this proof.)
3. EXPECT (all whole-app compile-verified + logic-runtime-proven; your ⌘R is the live visual/stream witness I can't do):
   - The window auto-starts → spawns the og-sidecar (bun, from the research clone) → connects OpenCode. Empty state:
     "connecting…" then "Type to start an OpenCode session". On failure it shows the REASON (not a blank screen).
   - An **engine picker** offers the diagnosed-ready engines (OpenCode + others), a compact **model/agent picker**, a
     native **recents rail**, slash-commands.
   - Type a prompt + **Enter** → a new session is created (appears in the rail) → the assistant answer **streams natively**
     (flat/TUI, NO raw JSON/log debris); your prompt shows as a distinct user line.
4. VERIFY the fixes/features: pick a **non-default model** → it takes effect; queue a 2nd prompt while busy → it **drains**
   on idle; **"Interrupt"** on a queued prompt aborts the turn + sends it next; reopen a recent from the rail → its
   **history replays**, with **file diffs** shown in edit/write **tool cards**. (Permission/question cards: see §3 — they
   stay quiet until you opt tools into "ask".)
5. ✅ opencode PREREQUISITE — already handled by the app; NO symlink/install needed (re-verified rigorously 2026-06-25,
   correcting two earlier over-stated notes). The app VENDORS a real opencode (`build-opencode-runtime.sh` → built .app
   `Contents/Resources/opencode`, Mach-O arm64; I ran it → **opencode 1.17.9**) AND the supervisor PREPENDS the app's
   `Contents/Resources` to the sidecar's PATH on spawn (WorkOpenGUISupervisor.processEnvironment:444-455, comment "so
   `opencode` is found"). The OpenGUI resolver finds opencode via a login-shell probe `$SHELL -lc 'command -v opencode'`,
   which INHERITS that injected PATH — I replicated the EXACT scenario (PATH=<built .app>/Contents/Resources → zsh AND bash
   `command -v opencode` → resolves to `…/Contents/Resources/opencode`). ⇒ at ⌘R the bundled opencode resolves automatically.
   (My earlier "opencode missing → must symlink/install" notes tested the bare login shell WITHOUT the app's PATH injection —
   that was wrong; retracted. There is nothing for you to install or symlink.)
   • Only IF ⌘R ever shows "Could not find the opencode binary" (e.g., a build where the vendor step didn't run): re-run the
     build so `build-opencode-runtime.sh` vendors it, or as a last resort
     `ln -s "<Epistemos.app>/Contents/Resources/opencode" ~/.local/bin/opencode`. Not expected to be needed.

## 2. WHAT'S DONE (whole-app compile-verified — `** TEST BUILD SUCCEEDED **` ×; only your live ⌘R remains)
- **Core proof path**: native input → createSession/send/stream an OpenCode session via the OpenGUI runtime/NDJSON sidecar
  bridge, preserving native recents/session identity (WorkSession ontology). Engine/model/agent pickers, recents rail,
  slash-command popover, prompt queue (queue + interrupt).
- **4 native bug fixes** (each compile-verified + logic-runtime-proven): multi-engine picker (was single-engine); model
  selection must send opencode's `{providerID,modelID}` OBJECT (was a bare string → silently ignored; proven 4 ways incl.
  the opencode v2 SDK type contract); transcript mislabeled the LIVE user prompt as an assistant answer; queue-interrupt +
  rail "+New mini" were no-op fake controls.
- **MCP origin-check security hardening** (substring → host-exact; the native-tools loopback server).
- **Native permission cards** (allow once/always/deny) + **native question cards** (single/multi/custom) — harness-event
  channel: sidecar forwards via **`harness.on("event")`** → `{type:"harnessEvent"}` → supervisor decode (digs to `.request`)
  → cards → respond (`og.service.*`, runtime-verified). (⚠️ The forwarding had TWO dead-API bugs found this run: first
  `og.on(...)` crashed init, then per-session `s.subscribeHarnessEvents` was silently a no-op — the session handle never
  exposes it. The adversarial audit caught the 2nd; both fixed → it now subscribes at the harness handle, the one public
  surface that actually exists, runtime-verified. Swift card UI + decode + respond were always correct. A card actually
  FIRING still needs the "ask" opt-in (§3) + your ⌘R — it can't be proven headlessly.)
- **Native diffs** (edit/write file diffs rendered flat/TUI in the tool card, from session history).
- **Tool-call summary line**: each tool card shows a compact one-line of WHAT it's doing (the command / file / pattern /
  url) on both the live stream and replay — debris-safe (file content / edit strings never surface).
- **Theme-token Work reskin pass**: the OpenGUI Work shell, recents rail, slash-command popover, OpenWork fallback chrome,
  and diff add/remove/hunk colors now go through `WorkSurfaceStyle` instead of hardcoded warm RGB values. The surface keeps
  its flat OpenCode-like density, but follows the active Epistemos theme palette. Verified by `WorkSurfaceStyleTests`
  (`xcodebuild test ... -only-testing:EpistemosTests/WorkSurfaceStyleTests` → `** TEST SUCCEEDED **`).
- **Flat host + app-native MCP continuation**: the fallback WebView host is now full-window/flat with a side details panel
  instead of an inset rounded preview box, and `WorkToolMCPCore` now lists real Epistemos vault/note tools from the active
  vault-backed Rust catalog. Verified 2026-06-25 with full app build `** BUILD SUCCEEDED **` and the focused Work contract
  slice `** TEST SUCCEEDED **` (63 tests in 6 suites; result bundle
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_08-30-58--0500.xcresult`).
- **Branding boundary**: visible Work/OpenGUI/OpenWork copy is being Epistemos-ified where safe. Names that are runtime
  contracts were deliberately not changed: OpenCode/OpenGUI/OpenWork command names, sidecar protocol frames, env vars,
  localStorage keys, import/protocol names, bundle/TCC/Keychain surfaces, tool names, and Agent!/automation hotwords.
- **Runtime PROVEN headlessly under the EXACT ⌘R env** (PATH=built-app `Contents/Resources` → bundled bun+opencode): the
  ENTIRE auth-free sidecar surface is verified with the bundled binary + the fixed sidecar (no rebuild needed; sidecar loads
  fresh each ⌘R): connect (`init connected: ["opencode"]`) · create (`opencode:ses_…`) · list (created session appears) ·
  loadResources (providers + 7 agents + 3 commands → the pickers) · permission/question forward+respond APIs · messages —
  all EXIT 0. Send/stream proven earlier by epistemos-opengui-spike + og-sidecar-drive (needs your model auth at ⌘R).
  Scripts in `.research-clones/work/opengui`.
- **Adversarial audit (8-dimension multi-agent) — 8 defects found + FIXED + whole-app green this run**: (1) permission/
  question forwarding was silently dead (wrong harness-event API, now `harness.on`); (2) reopen routed to the *selected*
  engine not the recent's *owning* engine (identity broke — now derives owning engine from the namespaced id); (3) store-vs-
  view active-session-id desync (rail highlight lagged — now `sessions.focus` on create); (4) reopen errors were swallowed →
  stale transcript (now honest reset+error); (5) empty-state said "connecting…" for stopped/failed (now status-derived); (6)
  the sidecar's opencode reap wasn't truly spawn-scoped (port hardcoded 4096 → now a unique per-launch `OPENGUI_OPENCODE_PORT`,
  so reap can never hit your other opencode). All verified (builds brcw3gskc + bxkyrkkgr ** BUILD SUCCEEDED **).

## 3. NEEDS YOUR DECISION / GATED (I did NOT do these autonomously)
- **Permission/question "ask" flip** (1-line): opencode DEFAULTS to auto-approve, so the permission cards stay
  ready-but-quiet. To make them fire, opt sensitive tools (bash/edit/write/webfetch) into `"ask"` in the provisioner's
  `opencode.json` — do this ONLY AFTER you confirm (§1) a card renders + allow/deny works, because flipping it blind would
  HANG the agent on the first gated tool if any wiring is off. The forward (`harness.on`) + decode + respond paths are now on
  the correct, runtime-verified APIs (two dead-API bugs were fixed this run), but a card actually FIRING is the one thing that
  can't be proven without a real gated tool call — so your live confirm is the gate.
- **Goose adapter**: post-proof (build after you witness OpenGUI/OpenCode live), per engine order.
- **Mini-session creation**: owner-gated (mini parity ledger sub-step 3a "AWAITING OWNER") + entangled with
  `MiniChatWindowController` (a Chat/Act deletion target, out of OpenGUI scope). The rail's "+New mini" is hidden until wired.
- **Live-diff threading** (diffs during a live turn, not just on replay): no LiveSessionEvent carries file diffs → needs a
  `messages()`-refresh-on-tool.finished approach (non-clean) — deferred.
- **OpenWork fallback removal**: keep until you pass the OpenGUI proof; then it can be deleted.

## 4. FLAGS
- ⚠️ The 2 `Localizable.xcstrings` are build-extraction-touched (NOT hand-edited by me; pre-existing dirty + build output).
  Review / `git checkout` when ready. I build via `swiftc -typecheck`/`-parse` fast gates + occasional background
  xcodebuild checkpoints to minimize extraction churn.
- Everything is uncommitted on `main` (shared checkout with parallel Chat/Act agents — `git status` commingles their work
  too). My footprint: new `Epistemos/Work/Work*.swift` + `EpistemosTests/Work*` + these `docs/handoffs/` + the
  `.research-clones/work/opengui/og-sidecar.mjs`. Authority for everything: `WORK_OPENWORK_PARITY_LEDGER_2026_06_24.md`.

## 5. FOLLOW-UP GUARD PASS (2026-06-25)
- The fallback WebView shell copy was appified without touching engine contracts: the visible fallback label now reads as
  Epistemos Work, while OpenCode/OpenGUI/OpenWork identifiers remain preserved where they are runtime/API names.
- `WorkSPAReskinTests` now guard the fallback copy boundary. Focused verification completed `** TEST SUCCEEDED **` with
  5 Swift Testing tests. Result bundle:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_08-56-38--0500.xcresult`.
