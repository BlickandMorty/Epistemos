# Claude → Codex Handoff: Final Walkthrough + Uncommitted Work Sweep

**Date:** 2026-04-17
**Branch:** `codex/runtime-input-audit`
**Base for diff:** `main` (commit 31214a4d)
**Audience:** Codex
**Goal:** Verify every commit Claude landed in this session, walk through the app manually, triage the 186 uncommitted files, and commit everything worth keeping.

---

## 1. Commits to verify (oldest → newest)

All on `codex/runtime-input-audit`, diverged from `main`:

| SHA | Subject | Files |
|---|---|---|
| `a56d97ab` | Wire ANE acceleration into EmbeddingService and VisualVerifyLoop | EmbeddingService, SemanticClusterService, GraphState, VisualVerifyLoop |
| `6742e9f4` | Brain 2 ANE: contextual action resolver + Core ML backend slot | DeviceAgentService, GraphState |
| `56c2ad99` | Auto-install Brain 2 ANE + Overseer log + iMessage/ModelVaults doctor | AppBootstrap, ChatCoordinator, IMessageDriverSettingsView, ModelVaultsSettingsView |
| `da3282e1` | Settings sweep: guided doctor on DriverRouteEditorSheet + ChannelsSettingsView | IMessageDriverSettingsView, ChannelsSettingsView |
| `1ab04d4e` | Fix chat_lite registry test after web_search backend-gating change | agent_core/src/tools/registry.rs |
| `4a8ba607` | Agent page: main-chat sibling layout (compact shell) | AgentCommandCenterView |
| `5c8d7de2` | UI polish + Apple Intelligence fallback | MiniChatView, NoteWindowManager, LandingView, TriageService |
| `f6ed65e0` | OLED dark mode + collapsed plan default + friendly chat error copy | ChatView, AgentCommandCenterView, AgentCommandCenterState, PipelineService |
| `f8589622` | Kill idle-CPU lag + graph route hygiene + MiniChat/landing/download polish | HologramOverlay, MiniChatView, LandingView, RootView, SettingsView, HomeWindowInputDiagnostics, LiveNoteExecutor, AppBootstrap |
| `da713afd` | Restore chat model picker + popover expansion + Apple Speech voice capture | QuickCaptureView, AppKitPopover, LandingView, ChatBrainPickerMenu (new), ChatInputBar, AudioTranscriber |
| `5d72a15a` | Agent right-rail: liquid-glass native panel with shadow + stroke | AgentCommandCenterView |
| `f2d918b0` | Fix landing-tap regression (popover anchor + bg hit-swallow + diag force-off) | RootView, HomeWindowInputDiagnostics, LandingView |

### What each commit intends to ship

1. **ANE / Core ML wiring** (`a56d97ab`, `6742e9f4`, `56c2ad99`):
   - `AppleContextualEmbeddingLookup` + `AppleHybridEmbeddingLookup` in `EmbeddingService` — graph + semantic-cluster embeddings route through NLContextualEmbedding when assets are present (ANE on Apple Silicon) with word-lookup fallback.
   - `VNGenerateImageFeaturePrintRequest` semantic fingerprint in `VisualVerifyLoop` — pixel-hash no longer the only screenshot signal.
   - `AppleContextualActionResolver` + `CoreMLActionBackendLoader` in `DeviceAgentService` — Brain 2 fast path for UI action resolution on ANE; drop an `.mlpackage` into `~/Library/Application Support/Epistemos/Models/brain2_action/` and it becomes the device backend.
   - `AppBootstrap` now calls `deviceAgent.installContextualResolver()` unconditionally and checks for a Core ML `.mlpackage` before falling through to Apple on-device / shared GPU.
   - `ChatCoordinator` logs `Overseer: route=... mode=... turns=... tools=...` per turn so the plan is finally visible.
2. **Chat transitions + error copy** (`f6ed65e0`, `5c8d7de2`):
   - `TriageService.localStreamOrFallback` now falls back to Apple Intelligence when no local model + no cloud.
   - `UserFacingChatError` helper maps infrastructure errors (network, auth, rate-limit, timeout, modelRequired, runtimeUnavailable) to readable copy; `PipelineService` emits that instead of raw NSError strings.
3. **UI restructure** (`4a8ba607`, `f6ed65e0`, `5d72a15a`):
   - Agent page rewritten to mirror `ChatView` (compact toolbar + centered transcript + bottom composer), right-rail inspector floats as overlay.
   - `AgentCommandCenterState.inspectorState` defaults to `.collapsed` — plan panel only appears on user toggle.
   - Agent right-rail now uses `.ultraThinMaterial` + 28pt continuous rounded rect + stroke + shadow (macOS 26 liquid-glass target).
4. **Settings doctors** (`56c2ad99`, `da3282e1`, `f8589622`):
   - iMessage driver top-level + DriverRouteEditorSheet + ChannelsSettingsView + ModelVaultsSettingsView now show guided error blocks (titled, with hint + action buttons + DisclosureGroup for raw error) instead of raw red labels.
   - Local-model install errors translate HF unreachable / gated / 404 / disk / timeout into actionable guidance.
5. **Landing + MiniChat polish** (`5c8d7de2`, `f8589622`, `da713afd`):
   - Landing popover uses native `NSPopover` via `AppKitPopover`, anchored at the user's actual tap location (tracked with `onTapGesture(coordinateSpace: .local)`).
   - `AppKitPopover.updateNSView` re-measures `sizeThatFits(in:)` on every state change so the popover grows as the composer content grows.
   - `ChatBrainPickerMenu` added — compact model picker for Apple Intelligence / installed local / all cloud, bound to `InferenceState.preferredChatModelSelection`. Dropped into `landingChatSpecificControls` and `ChatInputBar`.
   - MiniChat has 22pt rounded `.ultraThinMaterial` that extends behind the traffic-light area.
   - Graph route observer in `HologramOverlay` dismisses the Notes utility sidebar and pauses physics when the route leaves `.canvas`; resumes on return.
   - `NoteWindowManager.open(pageId:)` hides the notes utility panel + pauses graph physics when a note opens.
6. **Voice capture** (`da713afd`):
   - `AudioTranscriber` now tries `SFSpeechRecognizer` (Apple Speech) first. No Python / whisper dependency required for the Quick Capture mic button.
7. **Performance fixes** (`f8589622`, hardened in `f2d918b0`):
   - `HomeWindowInputDiagnostics.isEnabled` forced to a compile-time `false` (was briefly `#if DEBUG + env var`, but that still tripped in Xcode Runs where the shell env var is inherited). To re-enable for a specific audit, flip the literal in `HomeWindowInputDiagnostics.swift` and rebuild. Release + Debug + CI all ship with swizzles uninstalled.
   - `LiveNoteSchedulerService` made opt-in via `UserDefaults["epistemos.liveNotes.enabled"]` (default off). Adaptive cadence: 120s idle, 15s active. Users without live-note task blocks no longer burn idle CPU scanning 800+ pages every 15s.
   - `RootView.rootContent` pre-paints the window background (OLED black in dark, theme bg in light) so transitions landing → chat don't flash the old color at the title bar.

### Urgent regression the last commit fixes

User reported late in the session: "I can't press any more, it's back to not working… it's what you did to popover because I can't tap landing page, happened very recently." Landing page was swallowing clicks. Root cause: the earlier landing-popover refactor left two overlapping Color.clear layers in the ZStack — the tap-area at zIndex 0 AND a full-size `Color.clear.allowsHitTesting(false)` wrapping `.appKitPopover` at zIndex 2. Even with `allowsHitTesting(false)`, the `NSViewRepresentable` inside `AppKitPopover` grabbed hit-testing at the AppKit layer and ate clicks.

`f2d918b0` collapses those into a single tap-area layer that both handles the tap gesture AND hosts `.appKitPopover`. The anchor still uses `landingTapLocation` so the popover opens under the cursor. The layer is gated by `allowsHitTesting(!showingOverlay && !showingSearchPopover)` so it does not intercept events while the popover is up.

Same commit also:
- Adds `allowsHitTesting(false)` to the `Color.black` OLED pre-paint in `RootView.rootContent` (it was swallowing clicks across the whole window).
- Forces `HomeWindowInputDiagnostics.isEnabled` to a compile-time `false` so the shell env var `EPI_HOME_WINDOW_INPUT_DIAGNOSTICS=1` can never re-install the swizzles (was still tripping in Xcode Runs after the earlier `#if DEBUG` gate because Xcode inherits the shell env).

### Known scope creep

- Commit `a56d97ab` absorbed ~70 files of pre-staged session work from before this session started. Nothing was lost; the ANE changes are the commit's headline but the patch touches AppCoordinator, AgentChatState, LandingView, MessageBubble, and more. Re-diff against `31214a4d` to see the exact scope.

---

## 2. Codex verification workflow

### 2.1 Rust sanity (fast)

```bash
cd /Users/jojo/Downloads/Epistemos/agent_core && cargo test --quiet 2>&1 | tail -5
cd /Users/jojo/Downloads/Epistemos/graph-engine && cargo test --quiet 2>&1 | tail -5
cd /Users/jojo/Downloads/Epistemos/omega-mcp && cargo test --quiet 2>&1 | tail -5
cd /Users/jojo/Downloads/Epistemos/omega-ax && cargo test --quiet 2>&1 | tail -5
```

Expected: all green. `agent_core` specifically fixed by `1ab04d4e` (chat_lite registry test env var seed).

### 2.2 Swift focused matrix

Rerun the mode matrix Claude re-ran after each commit:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/epistemos-codex-final test \
  -only-testing:EpistemosTests/TriageServiceTests \
  -only-testing:EpistemosTests/LocalAgentLoopTests \
  -only-testing:EpistemosTests/DeviceAgentServiceTests \
  -only-testing:EpistemosTests/ResearchModeTests \
  -only-testing:EpistemosTests/ConfidenceRouterTests \
  -only-testing:EpistemosTests/LocalModelInfrastructureTests \
  -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests \
  -only-testing:EpistemosTests/BlockEmbeddingTests \
  -only-testing:EpistemosTests/VisualVerifyLoopTests \
  -only-testing:EpistemosTests/CloudStreamingParserTests \
  -only-testing:EpistemosTests/AgentCommandCenterStateTests
```

Expected: **172 tests in 11 suites pass**. Reference log: `/tmp/epistemos-final-audit-2026-04-17.log`.

### 2.3 Full release preflight

```bash
bash /Users/jojo/Downloads/Epistemos/scripts/audit/release_preflight.sh /tmp/epistemos-codex-release
```

Expected: `PASS: release preflight complete`. Reference log: `/tmp/epistemos-release-preflight-final.log` (earlier run, 21/21 bundle checks + 1 warning — ad-hoc sign only).

### 2.4 Release app + DMG artifact check

Both still on disk from the previous pass:

```bash
ls -lah /Users/jojo/Downloads/Epistemos/build/release-derived-data/Build/Products/Release/Epistemos.app
ls -lah /Users/jojo/Downloads/Epistemos/build/release-artifacts/
```

Expected:
- `Epistemos.app` (~356MB, Universal arm64+x86_64, Release, ad-hoc)
- `Epistemos.dmg` (~84MB, unsigned)
- `Epistemos.dmg.sha256` = `bc72adba79f2428fc1b66408333a85f8ef1cf14dd2838ee5888f0b9b9e19ee6f`

If you want a fresh Release build after the new commits, re-run `bash scripts/release/build_release_app.sh` then `bash scripts/release/create_release_dmg.sh`.

---

## 3. Manual walkthrough checklist

Launch the Release app:

```bash
open /Users/jojo/Downloads/Epistemos/build/release-derived-data/Build/Products/Release/Epistemos.app
```

Before launching, **unset** the input-audit env var in your shell if it's still there (it was the cause of the landing lag per `/tmp/epistemos-runtime.log`):

```bash
unset EPI_HOME_WINDOW_INPUT_DIAGNOSTICS
```

While the app runs, start the log capture in a second terminal:

```bash
log stream --predicate 'subsystem CONTAINS "com.epistemos"' --level debug --style compact \
  > /tmp/epistemos-codex-walkthrough.log 2>&1 &
```

Then walk through each item and mark PASS/FAIL in a markdown table at the end:

### Landing

- [ ] **Landing is clickable at all.** Tap anywhere on landing background — greeting shortcuts and the popover open correctly. This is the regression `f2d918b0` fixes; verify it's actually fixed before continuing.
- [ ] **Landing popover opens at tap location.** Tap background — popover arrow should point at tap point, not center. (Commit `5c8d7de2` + `da713afd`.)
- [ ] **Popover expands with content.** Type a long prompt that would overflow; popover should grow, not clip. (Commit `da713afd`.)
- [ ] **Model picker visible on landing popover.** In the Chat tab of the popover, the `ChatBrainPickerMenu` should show the current chat model and open a menu listing Apple Intelligence / installed local / all cloud. Switch it; returning to the popover should remember the switch. (Commit `da713afd`.)
- [ ] **Chat/Agent toggle switches popover content.** Flipping to Agent shows the dedicated-workspace blurb + BrainPickerMenu + quick-start chips. (Existing, regression-check only.)
- [ ] **No title-bar color flash on landing → chat.** Submit a prompt and transition — title-bar area should stay dark (OLED) through the transition. (Commit `f8589622`.)
- [ ] **Typing in landing is fluid.** Input should not lag or drop frames. If it still lags, check `log stream` for `InputAudit` / `home_window_alpha_write` events — those should be **zero** in Release after `f8589622`.

### Main chat

- [ ] **Background is OLED pure black in dark mode.** (Commit `f6ed65e0`.)
- [ ] **Background is theme-colored in light mode.** Flip appearance.
- [ ] **ChatBrainPickerMenu visible above send button.** User can see the active model at a glance and switch from the input bar. (Commit `da713afd`.)
- [ ] **Scrolling is fluid.** Long chat history scroll should not stutter.
- [ ] **Error bubble copy is user-friendly when you trigger a failure.** Example: unplug wifi, submit a cloud query — error should say "Couldn't reach the provider…" not raw NSError. (Commit `f6ed65e0`.)
- [ ] **Apple Intelligence fallback.** With no local model installed and no cloud credentials, submit a query — should still produce a reply on macOS 26+ from Apple Intelligence. (Commit `5c8d7de2`.)

### Agent page

- [ ] **Layout mirrors main chat.** Compact top toolbar, centered transcript, bottom input bar, no giant header card. (Commit `4a8ba607`.)
- [ ] **Plan panel starts collapsed.** Tap Plan in the toolbar — panel animates in from the right; tap again — it collapses. (Commit `f6ed65e0`.)
- [ ] **Plan panel uses liquid glass.** When expanded, the rail has ultraThinMaterial + 28pt rounded corners + subtle stroke + drop shadow. (Commit `5d72a15a`.)
- [ ] **BrainPickerMenu + runtime chip + turns/messages/tools counter visible in the top toolbar.** (Existing inside `4a8ba607`.)

### Graph

- [ ] **Opening a note from the graph dismisses the Notes utility panel.** (Commit `5c8d7de2` — `NoteWindowManager.open`.)
- [ ] **Opening a note OR folder pauses physics.** Watch CPU drop when you navigate into a node. (Commit `f8589622` — `HologramOverlay` route observer.)
- [ ] **Returning to canvas resumes physics.** (Same.)

### MiniChat (⌘3)

- [ ] **Rounded ultraThinMaterial glass visible behind traffic lights.** No flat transparent cutoff at the top. (Commit `f8589622`.)
- [ ] **22pt rounded corners with stroke + shadow.** Panel reads as a floating glass sheet.

### Quick Capture (⌘⇧N)

- [ ] **Mic button actually transcribes.** Tap mic → speak → tap stop — text appears in the composer without any Python / whisper install. First use will prompt for microphone + speech recognition permission. (Commit `da713afd`.)
- [ ] **No "Capture Trace Inspector" button visible in Release.** Only the X close button. (Commit `da713afd`.) In DEBUG builds, the clock button still exists for internal use.
- [ ] **Capture form → note conversion works.** Type text, hit Submit — confirmation card shows with title + entity/task counts.

### Settings

- [ ] **iMessage Driver shows doctor guidance when something fails.** Try polling without Full Disk Access → should show "Messages database can't be opened" with Open Full Disk Access / Relaunch buttons, not a red stack trace. (Commit `56c2ad99`.)
- [ ] **Local model install error shows friendly copy.** Fake a bad install (rename a staged directory); retry should say "Couldn't reach Hugging Face" / "ran out of space" / etc., not a raw URL error. (Commit `f8589622`.)
- [ ] **ModelVaults shows status block with DisclosureGroup for raw error.** (Commit `56c2ad99`.)
- [ ] **ChannelsSettingsView shows guided 'Sender routes couldn't load' block.** (Commit `da3282e1`.)

### Log audit (after walkthrough)

```bash
wc -l /tmp/epistemos-codex-walkthrough.log
grep -cE 'InputAudit|home_window_alpha_write' /tmp/epistemos-codex-walkthrough.log  # expect 0 in Release
grep -cE 'LiveNoteScanner: found' /tmp/epistemos-codex-walkthrough.log  # expect 0 unless user flipped the enable flag
awk -F'\\[|\\]' '{print $4}' /tmp/epistemos-codex-walkthrough.log | sort | uniq -c | sort -rn | head -15
```

Expected:
- Zero `InputAudit` events in Release.
- Zero `LiveNoteScanner: found` lines unless `defaults write com.epistemos.Epistemos epistemos.liveNotes.enabled -bool YES` is set.
- Diagnostics subsystem dominant → **no**. Used to be 9.7k/8min; should now be a handful of lifecycle events per session.

---

## 4. Uncommitted work sweep (186 files)

At handoff time, `git status --short | wc -l` → **186**. Breakdown:

- **161** modified (`M `) — from pre-existing session work the first commit (`a56d97ab`) didn't capture.
- **25** untracked (`??`) — likely log / derived-data / misc artifacts.

### Recommended workflow for Codex

1. **Snapshot first:**
   ```bash
   git status --short > /tmp/epistemos-pre-sweep-status.txt
   git diff --stat > /tmp/epistemos-pre-sweep-diffstat.txt
   ```

2. **Separate real code changes from noise.** Filter categories:
   - `syntax-core/target/**` — Rust build artifacts. Add to `.gitignore`; do not commit.
   - `LocalPackages/*/target/**` or `.build/**` — same.
   - `*.log` in repo root — delete or move to `/tmp`.
   - `*.xcscheme` / `xcuserdata/**` — commit only if the user's scheme actually changed intentionally.
   - Actual `.swift` / `.rs` / `.sh` / docs — keep and triage.

3. **Triage by subsystem.** Group the remaining real edits by top-level directory and commit in coherent batches:
   - `Epistemos/App/**` → app-bootstrap + window lifecycle
   - `Epistemos/Engine/**` → runtime
   - `Epistemos/Graph/**` → graph + embeddings
   - `Epistemos/Harness/**` → benchmarks + harness
   - `Epistemos/State/**` → observable state
   - `Epistemos/Views/**` → UI
   - `Epistemos/Intents/**` → Shortcuts
   - `Epistemos/KnowledgeFusion/**` → training + data ingestion
   - `Epistemos/Omega/**` → agent runtime
   - `Epistemos/Sync/**` → vault sync
   - `agent_core/**` → Rust agent
   - `graph-engine/**` → Rust graph
   - `scripts/**` → build/release scripts
   - `docs/**` → docs

4. **For each batch:**
   - `git add <paths>`
   - Read the diff: `git diff --cached <paths> | head -200`
   - If the change is coherent + not destructive, commit with a descriptive message.
   - If the diff looks risky / unrelated, stash separately: `git stash push --message "WIP: <area>" <paths>`.

5. **Build after each batch** to ensure nothing broke:
   ```bash
   xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' \
     -derivedDataPath /tmp/epistemos-codex-final build-for-testing 2>&1 | grep -E 'error:|BUILD FAILED' | head -5
   ```

6. **Run the mode matrix + preflight after every 3-4 batches** to catch accumulated regressions.

### .gitignore update

Audit `.gitignore` for missing entries and add them before the sweep:

```
syntax-core/target/
agent_core/target/
graph-engine/target/
omega-mcp/target/
omega-ax/target/
epistemos-core/target/
*.xcuserstate
build-rust/
/tmp/
```

Commit the `.gitignore` update first, then `git rm --cached` the entries that are currently tracked but shouldn't be.

---

## 5. Still open from the user's list

These were called out but not yet landed. Codex should either implement or explicitly defer with rationale.

### 5.1 Per-model mode capability surface

**What the user wants:** each chat model (local + cloud) exposes its native modes. Fast / Thinking / Pro / Agent should only appear for models that actually support them. Claude → extended thinking. OpenAI o-series → reasoning effort. Gemma → vision. Qwen → reasoning.

**Where to start:**
- `ChatView.mainChatOperatingMode = .fast` (hardcoded) → needs to become selectable.
- `ChatModelSelection` (in `InferenceState.swift`) already has capability introspection (`activeMaxContextTokens`, `activeSupportsVision`, `activeSupportedFileTypes`). Add `supportedOperatingModes: Set<EpistemosOperatingMode>` next to those.
- `LocalTextModelID` enum values should declare their supported modes; same for `CloudTextModelID`.
- `ChatBrainPickerMenu` should show a second sub-menu for the chosen model's supported modes.
- `ChatCoordinator.submitMainChatQuery(_:operatingMode:)` already threads mode through — just need to pass the user-chosen mode instead of `.fast`.

**Ask the user first:** should main chat get the full Fast/Thinking/Pro/Agent picker, or should modes stay agent-only and main chat just show the model name?

### 5.2 Lost buttons audit

User mentioned "buttons that disappeared." They didn't enumerate. Things Claude restored this session:
- Landing popover model picker ✅ (commit `da713afd`)
- Agent plan panel toggle default-collapsed ✅ (commit `f6ed65e0`)
- Apple Intelligence fallback in triage ✅ (commit `5c8d7de2`)

Ask the user for a concrete list (screenshot pointing at the missing button works best). Likely candidates to check:
- Recent-chats list on landing (does `onTapGesture` on background still let it reach this?)
- Incognito toggle (was it moved/hidden?)
- Note-chat "Insert as draft" buttons
- Agent-inspector "Export transcript"
- Capture voice button — should work now but first-use permission prompt may look broken.

### 5.3 Release signing / notarization

Already documented in the previous handoff but restate briefly for Codex:
- User has only **Apple Development** cert installed; needs **Developer ID Application** cert (Apple Developer Program, $99/yr).
- `notarytool-password` keychain profile not stored yet. When set up, `bash scripts/release/notarize.sh build/release-artifacts/Epistemos.dmg` handles end-to-end.
- Until then, the DMG at `build/release-artifacts/Epistemos.dmg` is ad-hoc-signed — runs locally (right-click Open) but Gatekeeper-rejected elsewhere.

---

## 6. Things Codex must NOT do

- **Do not `git reset --hard`** or `git checkout .` across the worktree. The user has repeatedly asked that this never happen (there's a memory entry about lost work).
- **Do not delete unfamiliar branches or files** without understanding what they are. The worktrees under `.claude/worktrees/` are prior session snapshots.
- **Do not revert the `#if DEBUG` gate** on `HomeWindowInputDiagnostics`. That was the root cause of the idle-lag storm.
- **Do not re-enable `EPI_HOME_WINDOW_INPUT_DIAGNOSTICS`** in any shell config, build script, or `.env`. It's meant to be a local-only flag for specific audits.
- **Do not commit build artifacts** (`target/`, `.build/`, etc.). Fix `.gitignore` first.
- **Do not skip hooks** (`--no-verify`) on commits. If a pre-commit hook fails, fix the underlying issue.

---

## 7. Success criteria for this handoff

Codex considers this handoff complete when:

1. All 11 Claude commits verified green (`cargo test` + mode matrix + preflight).
2. Manual walkthrough checklist has been completed with PASS/FAIL for every item.
3. 186 uncommitted files triaged into either:
   - Committed in coherent subsystem batches.
   - Added to `.gitignore` and removed from tracking.
   - Stashed with a WIP message for the user to review.
4. `/tmp/epistemos-codex-walkthrough.log` shows zero `InputAudit` events and zero `LiveNoteScanner` noise (without manual toggles).
5. The user's explicit asks that this session didn't land (per-model modes, full button audit) are documented with exact next steps in a follow-up handoff.

---

## 8. Key log files to preserve

Do not overwrite without reading first:

- `/tmp/epistemos-runtime.log` — user's runtime capture showing the InputAudit storm.
- `/tmp/epistemos-final-audit-2026-04-17.log` — 172/11 test matrix green after last commit.
- `/tmp/epistemos-release-preflight-final.log` — full release preflight pass log.
- `/tmp/epistemos-release-build.log` — Universal Release build log.
- `/tmp/epistemos-dmg-create.log` — DMG creation log.

---

## 9. Summary

- **12 commits shipped** on `codex/runtime-input-audit`.
- **172/11 test matrix green** after the final commit.
- **Release app + unsigned DMG** built and on disk.
- **Major idle lag root cause** found and fixed (`HomeWindowInputDiagnostics` swizzle + `LiveNoteScanner` 15s polling).
- **Still open:** per-model mode capabilities, full lost-button audit, release-grade signing + notarization (needs user credentials).

Your job, Codex: walk the app, verify everything holds, commit the 186-file uncommitted pile in coherent batches, and hand the user back a branch that only contains intentional work.
