# Full-Session Handoff to Codex: End-to-End Audit & Regression Hunt

> **Index status**: CANONICAL-HISTORICAL — Session handoff; kept for state recovery (30-day minimum). No copy to _consolidated.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



**Date:** 2026-04-18
**Branch:** `codex/runtime-input-audit`
**Audience:** Codex
**Purpose:** A single document that covers BOTH the Claude thread (initial 13 commits) AND the subsequent Codex thread (~22 commits of fuse + audit + model stack work) so a fresh auditor can walk the entire branch, surface regressions, and decide what still needs hardening before release.

> **Read this first before touching anything.** The user has repeatedly lost work to history-rewriting commands — never run `git reset --hard`, `git checkout .`, `git restore`, or `git stash drop` across this branch. Every concern below can be verified read-only.

---

## 1. Executive Summary

Two agents worked the branch in sequence:

- **Claude (thread 1)** — 13 commits, mostly ANE wiring, UI polish, Apple-Intelligence fallback, and one late hard regression (landing page hit-testing) that Claude caught and fixed in the same session.
- **Codex (thread 2)** — ~22 commits, architectural: note skills, graph route hygiene, capability roles, AgentHarness scaffolding (QueryEngine / handoffs / BackendRegistry / Authority), agent-correctness fixes, Gemma 4 registry work, chat-surface fusion into one chat with a ChatCapability pill, thinking popover, model-stack refresh (Hermes 4.3 / Qwen 3 / Qwen 3 Coder / Qwen 3.6 Unsloth), Overseer transparency panel, settings-sidebar consolidation, slash-command menu restoration, and a code-editor theme fix.

Total changed surface is wide: main chat composer, landing popover, agent page (now orphaned/deprecated), graph overlay, note editor, all settings panels, Rust agent_core, and the local-model catalog. Tests stay broadly green (3339 suite passed before Codex's last runs; a small count of Knowledge Core Bridge failures are pre-existing).

The user explicitly called out two classes of concern you need to hunt for:
1. **Regressions in graph performance and graph-mode note editing** (stutter, panels not hiding).
2. **UI quality / theme inconsistency** (they feel certain surfaces look "two themes attacking each other" — code editor canvas specifically flagged, now patched).

Assume nothing is release-ready until you've walked the app live.

---

## 2. Commit Ledger — Both Threads

### 2.1 Claude thread (`a56d97ab` → `938bfe70`)

| SHA | Subject | Why it matters |
|---|---|---|
| `a56d97ab` | Wire ANE acceleration into EmbeddingService and VisualVerifyLoop | **Large sweep — 973 files.** Absorbed pre-staged session work. Diff against `31214a4d` to see true scope. |
| `6742e9f4` | Brain 2 ANE: contextual action resolver + Core ML backend slot | Adds `AppleContextualActionResolver` + `CoreMLActionBackendLoader`; DeviceAgentService fast path. |
| `56c2ad99` | Auto-install Brain 2 ANE + Overseer log + iMessage/ModelVaults doctor | `AppBootstrap` calls `installContextualResolver()` unconditionally; `ChatCoordinator` logs Overseer route each turn; settings doctor rewrites. |
| `da3282e1` | Settings sweep: guided doctor on DriverRouteEditorSheet + ChannelsSettingsView | Replaces raw-error labels with guided hint + DisclosureGroup. |
| `1ab04d4e` | Fix chat_lite registry test after web_search backend-gating | agent_core fixture: seed TAVILY env for test run. |
| `4a8ba607` | Agent page: main-chat sibling layout (compact shell) | **Major UI rewrite** — body of AgentCommandCenterView replaced; old helpers dormant not deleted. |
| `5c8d7de2` | UI polish + Apple Intelligence fallback | MiniChat glass, landing popover native NSPopover, sidebar auto-hide on note open, `localStreamOrFallback` → Apple AI. |
| `f6ed65e0` | OLED dark mode + collapsed plan default + friendly chat error copy | ChatView + AgentCommandCenterView dark-mode → Color.black; `inspectorState` default `.collapsed`; `UserFacingChatError` helper. |
| `f8589622` | Kill idle-CPU lag + graph route hygiene + MiniChat/landing/download polish | **Performance** — `HomeWindowInputDiagnostics` gated `#if DEBUG`; `LiveNoteScheduler` opt-in; `RootView` pre-paints OLED bg; graph route observer in `HologramOverlay` hides notes sidebar + pauses physics. |
| `da713afd` | Restore chat model picker + popover expansion + Apple Speech voice capture | New `ChatBrainPickerMenu` (later heavily evolved by Codex), `AppKitPopover.updateNSView` re-measures `sizeThatFits` so popover expands; `SFSpeechRecognizer` backend in `AudioTranscriber`. |
| `5d72a15a` | Agent right-rail: liquid-glass native panel with shadow + stroke | `ultraThinMaterial` + 28pt rounded corners + stroke + shadow. (Now orphaned — agent page no longer routes.) |
| `f2d918b0` | Fix landing-tap regression | **Urgent hotfix** — merged two overlapping Color.clear layers in LandingView; added `allowsHitTesting(false)` to the RootView Color.black pre-paint; forced `HomeWindowInputDiagnostics.isEnabled` to compile-time `false`. |
| `938bfe70` | Claude → Codex final-walkthrough handoff doc | See `docs/handoffs/2026-04-17-claude-to-codex-final-walkthrough.md` for per-commit verification + the 186-file uncommitted triage plan. |

### 2.2 Codex thread (post-`938bfe70`)

| SHA | Subject | Why it matters |
|---|---|---|
| `72d631e4` | Note CRUD skills (create/read/write/delete) | New skills file — check bundle inclusion. |
| `2405cce6` | Graph panel + inspector no longer leak onto note/folder routes | Panel hiding logic expanded. |
| `e5295ff8` | `ModelCapabilityRole` enum + role-tagged catalog | Adds `.functionCallingLocal` role; tags key models. |
| `217a886c` | AgentHarness: QueryEngine + handoffs + AgentBackend + Authority | **Clean-room port** — new `AgentHarness/` directory with QueryEngine actor, typed handoffs, BackendRegistry, UsageLedger, Authority categories. |
| `ab7b5e40` | AgentHarness Swift 6 isolation fixes | Renames `QueryEngine` → `AgentQueryEngine` to avoid collision. |
| `850cc36d` | Gemma 4 type registration in MLX | Aliases `gemma4` + `gemma4_text` → `Gemma3nTextConfiguration`. **User still reports Gemma 4 broken** (expected — alias gets past factory; decoder fails on MatFormer fields). |
| `6233b45d` | Authority & Installs reachable in Settings | Sidebar entry under Automation. |
| `9fe4db3f` | Pause Metal render + physics on non-canvas routes | `metalView.pauseEngine()` on route entry; `resumeEngine()` on return. |
| `a78decdf` | P1: panic-safe tool execution + cloud-only agent-loop gate | `AssertUnwindSafe.catch_unwind()` around tool futures; `ProviderRuntime { Cloud, Local }`; `AgentError::LocalProviderNotAllowed`. |
| `ba07e260` | Cloud-only gate regression tests | Locks new agent_core contract. |
| `5f70f44e` | `ChatCapability` + `ChatCapabilityPill` foundation | `.local` / `.cloud` / `.thinking` / `.research` / `.agent` enum. |
| `2fa2b578` | Pill live in main chat composer | Shown on `ChatInputBar` control row; updates on provider/agent-exec changes. |
| `3d83f377` | **Fuse**: Landing Chat/Agent picker removed | Landing submissions all go through a single path. |
| `236f7748` | Intent classifier pre-submit | `ChatCapability.predictIntent(text:isCloudProvider:)` lights pill as user types. |
| `30bffaea` | Live tool detail + needs-cloud banner | Pill reads `Agent • tool_name` mid-turn; orange banner when local + agent-intent. |
| `c543e3fb` | Tappable "switch to OpenAI" banner | One-tap provider switch. |
| `1197b995` | Auto-promote + `supportsAgentTier` gate | Only OpenAI + Anthropic can auto-promote to agent loop. |
| `d0165947` | Pill in MiniChat / NoteChat / GraphChat | Same pill shipped to all four chat surfaces. |
| `5c67bf6c` | Canvas stutter fix | `MetalGraphView.needsRender` no longer forced true by `\|\| hasPinnedPanels`. |
| `f19cda7e` | Mark orphaned ACC code as DEPRECATED | Comment-only pass; nothing deleted. |
| `f3e9c6d4` | **Gemma 4 exclusion + pill honesty** | Triage filters Gemma 4 from preferred-order + shipped-fallback; pill reads `preferredChatModelSelection` not `activeAIProvider`. |
| `8b0416ba` | Model stack refresh + `MASTER_MODEL_STACK_PLAN.md` | Hermes 4.3 (36B 4bit + 3bit), Qwen 3 official, Qwen 3 Coder Next, Qwen 3 Coder 30B A3B, Unsloth + DWQ Qwen 3.6 variants. |
| `1b7611f8` | Thinking popover + revision pins + ACC test isolation | ChatGPT-style thinking panel; wires `thinkingDelta` on ChatState; test UserDefaults isolation. |
| `b4cd616b` | Overseer transparency panel + agent-not-on-startup | Settings → Agent → Overseer tab; `homeSurfaceRoute` forced to `.home`. |
| `9ccd135d` | Picker simplification | **Single cloud row** (preferred provider's model), all locals, no duplicate routing toggle. |
| `5815f440` | 3 agent settings sections → 1 tabbed section | "Agent" sidebar entry with Overview · Authority · Overseer tabs. |
| `ac78efc8` | `/` slash menu restored on fused chat | Native SwiftUI popover, regularMaterial, keyboard-first filter. |
| `f9b6ea26` | Code editor canvas + Codex handoff doc | Outer SwiftUI wrapper + inner CodeEditSourceEditor use same `textBackgroundColor`. |

**Total session commits: ~35 on `codex/runtime-input-audit` since main.**

---

## 3. What changed, grouped by subsystem

Use this section to decide where to focus the regression sweep.

### Main chat & composer
- **Picker completely rebuilt.** Now shows one cloud row (preferred provider's model), all installed locals, Apple Intelligence. `CloudTextModelID.allCases` iteration removed from picker.
- **`ChatBrainPickerMenu`** — Claude originally created it as a direct menu; the file was later heavily refactored by Codex into a thin wrapper over `LocalModelToolbarMenu` plus a new `MainChatOperatingModePreference` helper. **The user-linter edit pinned `releaseSelectableInstalledLocalTextModelIDs` as the source — preserve that.**
- **`ChatCapabilityPill`** rendered in all four chat composers (main / mini / note / graph).
- **Pre-submit intent classifier** lights the pill as the user types.
- **Auto-promote to agent loop** when provider supports it (OpenAI / Anthropic only).
- **Needs-cloud banner** — tappable, switches to OpenAI.
- **`/` slash command menu** — native SwiftUI popover on main chat.
- **Thinking popover** — `thinkingDelta` plumbed through ChatState, rendered as a ChatGPT-style collapsible panel above the streaming response.
- **`mainChatOperatingMode`** — no longer a hardcoded `.fast`; now driven by per-model support lists (`inference.availableOperatingModes`).

### Landing page
- **Popover** went: custom scrim+card overlay → SwiftUI `.popover()` → native `NSPopover` via `AppKitPopover` anchored at tap location → final form merged with tap-area to kill hit-swallow regression.
- **Chat/Agent segmented picker removed** — one submission path only.

### Agent page / Agent Command Center
- Body rewritten in `4a8ba607` (chat-sibling layout). Old dashboard helpers (`pageHeader`, `commandArea`, `transcriptArea`, `emptyTranscript`, `agentLandingHeroCard`, `agentLandingBriefingCard`, `agentStatsPanel`, `agentWorkspaceControlsCard`) still in file but unreferenced.
- Right-rail inspector: default collapsed, liquid-glass material, absolute-position overlay.
- **Entire page is now unreachable.** `homeSurfaceRoute` hard-wired to `.home` in `b4cd616b`. `AgentChatView` + `AgentCommandCenterView` marked `DEPRECATED (fused chat, 2026-04-18)`.
- **Deletion is NOT done** — deprecation is comment-only. Plan (per `MASTER_MODEL_STACK_PLAN`): delete after one stable release.

### Graph
- `HologramOverlay` route observer hides Notes utility panel + cancels physics on non-canvas routes. Resumes on return to canvas.
- `MetalGraphView.pauseEngine()` / `resumeEngine()` added; called on route transitions.
- `needsRender = result != 0 || hasPinnedPanels` → reverted to `result != 0` (canvas stutter fix).
- Pinned-inspector position-update loop no longer un-hides panels.

### MiniChat
- 22pt rounded ultraThinMaterial background that extends behind traffic lights.
- Pill in composer.

### Note editor
- When a note opens via `NoteWindowManager.open(pageId:)`: Notes utility panel hides, Hologram overlay hides (if visible).
- Pill in `AssistantToolbarAskBar`.

### Settings
- **Sidebar consolidation:** 14 sections → 12. Agent Control / Authority / Overseer merged into one tabbed "Agent" section.
- **Model install errors** translate HF unreachable / gated / 404 / disk / timeout to actionable copy.
- **iMessage Driver:** top-level + DriverRouteEditorSheet now use guided `DoctorGuidance` blocks.
- **Channels + ModelVaults:** same guided-error pattern.
- **Authority & Installs panel** under Agent.
- **Overseer audit panel** under Agent — shows per-turn route / depth budget / mask plan / tool permissions. Read-only.

### Local model catalog
- **New cases** on `LocalTextModelID`: Hermes 4.3 (36B 4bit + 3bit), Qwen 3 official, Qwen 3 Coder Next, Qwen 3 Coder 30B A3B, Qwen 3.6 Unsloth UD-MLX-4bit, Qwen 3.6 DWQ.
- **Gemma 4 cases** remain defined but **excluded from triage preferred-order and shipped-fallback lists** (`TriageService`).
- **Role tagging:** `ModelCapabilityRole` enum with `.functionCallingLocal` assigned to models that declare tool calling.
- **Revision SHA pinning** — 5 new models have real SHAs; Hermes uses `"main"` with a test exemption + TODO.

### Rust agent_core
- **Panic safety:** tool handler futures wrapped in `AssertUnwindSafe.catch_unwind()`.
- **Cloud-only agent gate:** `AgentProvider::runtime() -> ProviderRuntime`; `run_agent_loop` refuses `Local` with `AgentError::LocalProviderNotAllowed`.
- **Error classifier** surfaces the "switch to a cloud provider" hint.
- **511 tests** passing (509 baseline + 2 new gate regressions).

### AgentHarness (new clean-room scaffold in `Epistemos/AgentHarness/`)
- `AgentQueryEngine` actor (session-per-engine, turn-per-`submitMessage`).
- Typed handoffs (`HandoffContextType { pipeline, task, direct }`, `sanitizeAgentName`, input filters).
- `AgentBackend` protocol + `BackendRegistry` actor.
- `UsageLedger` + `TokenUsage`.
- `Authority` categories for tool gating.
- Test file: `AgentHarnessTests.swift`.
- **Not wired into chat path yet.** This is infrastructure, not a live surface.

### Code editor
- Outer SwiftUI wrapper + inner `CodeEditSourceEditor` now use the same `NSColor.textBackgroundColor` across all theme modes. This is the fix for the "two themes attacking each other" seam the user reported.

---

## 4. Regression Hunt — Where to Look First

These are the highest-probability failure points given the scale of the surface area touched. Walk each one before claiming the branch is ship-ready.

### 4.1 Graph (user-flagged as regressed)

**Claim:** The user says graph performance has regressed since before the agent work, with stutter on canvas and lag when editing notes on the graph route.

**What to check:**
1. **Canvas idle with no pinned panels.** After `5c67bf6c` the `|| hasPinnedPanels` fallback is gone. If canvas is still stuttery, the regression is deeper than this one fix.
2. **Pinned-inspector 30fps timer.** `HologramOverlay.updatePinnedInspectorPositions` runs at 30fps. Confirm it's not forcing layout of the full overlay per tick.
3. **Route transition hygiene.** Open a note → physics must actually stop (no CVDisplayLink tick, Rust physics loop paused, `drawableSize` zeroed per `9fe4db3f`). Return to canvas → physics resumes cleanly.
4. **Sidebar/panel hiding.** When on `.note` or `.folder` route, these must all be hidden: `routeHostView` contents, Notes utility panel (`UtilityWindowManager.shared.hide(.notes)`), pinned inspectors, mini-mode companion panel.
5. **`a56d97ab`'s EmbeddingService init cost** — `AppleHybridEmbeddingLookup()` triggers `NLContextualEmbedding(language:)` setup. Confirm it's not blocking the main thread at graph init.
6. **`68a93eb1` BoltFFI typed-buffer prototype** — gated behind `bolt-graph` feature flag. Confirm the flag is OFF in Release.

**Verification command:**
```bash
# Profile canvas render with Instruments "Time Profiler" for 30 seconds.
# Look for samples in HologramOverlay / MetalGraphView / the Rust physics FFI.
```

### 4.2 Chat surface fusion (user-critical)

**Claim:** User wants one chat that auto-routes cleanly. Fuse landed but there are many edge cases.

**What to check:**
1. **Agent page truly unreachable.** `homeSurfaceRoute` returns `.home` always. Confirm no deep link, no workspace-restore, no `AppBootstrap.presentAgentCommandCenter()` caller surfaces `AgentChatView`.
2. **Pill honesty.** Pill reads `inference.preferredChatModelSelection`, not `activeAIProvider`. Verify on all four surfaces: main / mini / note / graph.
3. **Auto-promote to agent loop.** With OpenAI selected + "create a note about X" prompt, the turn should actually invoke the agent loop, not fall through to plain chat. With Gemini selected, same prompt should stay on plain chat (agent tier gated).
4. **Needs-cloud banner.** With a local model + agent-intent prompt, banner appears → tap switches to OpenAI → banner clears.
5. **Intent classifier false positives.** Prompts like "the latest research on X shows" should not auto-promote to Agent just because the word "research" appears. Test benign phrasings.
6. **Slash menu.** `/` at start of composer opens native popover. Whitespace closes. Escape closes. Tap fills. Keyboard filter works.
7. **Thinking popover.** With a Claude/o-series model doing extended thinking, the thinking delta stream renders a collapsible panel above the response. Turn boundary resets correctly.

### 4.3 Settings sidebar consolidation

**What to check:**
1. **14 → 12 sections correct.** Test `SettingsCategoryTests` pass (was updated to expect 13 then 12 after the merge).
2. **Agent section tabs:** Overview / Authority / Overseer all render; deep links to old `.agentControl` / `.authority` / `.overseer` route to the unified view.
3. **No dead settings links.** Audit for stale `.agentControl` references in notifications or workspace restore data.

### 4.4 Model catalog + triage

**What to check:**
1. **Gemma 4 still picked?** Submit a lightweight prompt with only Gemma 4 + one other model installed. Triage must pick the other model. Check all 4 Gemma 4 tiers: `gemma4_E2B4Bit`, `gemma4_E4B4Bit`, `gemma4_27B4Bit_A4B`, `gemma4_30B4Bit`.
2. **Bonsai request path.** User reported "gemma4 warning" when submitting to Bonsai. With Bonsai explicitly selected, verify the actual inference path. No silent override to Gemma 4.
3. **Hermes 4.3 loads.** Both 4bit and 3bit variants decode correctly via the alias path.
4. **Qwen 3 / Qwen 3 Coder load.** Same verification.
5. **Qwen 3.6 Unsloth vs DWQ.** Both variants should coexist without collision.
6. **Revision pin test.** Confirm `RevisionPinTests` or equivalent is green despite Hermes using `"main"`.

### 4.5 Agent correctness (Rust)

**What to check:**
1. Full `cargo test` in `agent_core` — should be 511 passing.
2. `AgentError::LocalProviderNotAllowed` fires before any model invocation when a `Local` provider is passed to `run_agent_loop`.
3. Panic in a tool handler → produces `ToolError::ExecutionFailed` with message, does not kill the session.

### 4.6 Note editor on graph route

**Claim:** User reported typing lag when editing a note reached via the graph.

**What to check:**
1. Navigate graph → tap a note → physics must stop (per `9fe4db3f` + the route observer).
2. Type rapidly in the note — confirm no per-keystroke rendering of the graph behind.
3. Confirm `metalView.pauseEngine()` was called and `CVDisplayLink` is actually stopped.

### 4.7 Code editor theme
`f9b6ea26` makes outer + inner use the same `textBackgroundColor`. Confirm in both dark and light mode, and when theme follows system appearance (dark-light transition test).

### 4.8 Claude's first commit (`a56d97ab`) sweep scope
Because this commit touched ~973 files and the message doesn't fully describe them, anything "missing" that the user reports may trace here. The diff is available via `git show a56d97ab`. Look for view-level edits that might have overwritten pre-session work.

---

## 5. Verification Commands

### 5.1 Rust
```bash
cd /Users/jojo/Downloads/Epistemos/agent_core && cargo test --quiet 2>&1 | tail -5
cd /Users/jojo/Downloads/Epistemos/graph-engine && cargo test --quiet 2>&1 | tail -5
cd /Users/jojo/Downloads/Epistemos/omega-mcp && cargo test --quiet 2>&1 | tail -5
cd /Users/jojo/Downloads/Epistemos/omega-ax && cargo test --quiet 2>&1 | tail -5
cd /Users/jojo/Downloads/Epistemos/epistemos-core && cargo test --quiet 2>&1 | tail -5
```
Expected: all green. agent_core = 511 tests.

### 5.2 Swift focused matrix
```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/epistemos-codex-audit test \
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
  -only-testing:EpistemosTests/AgentCommandCenterStateTests \
  -only-testing:EpistemosTests/SettingsCategoryTests \
  -only-testing:EpistemosTests/AgentHarnessTests
```

### 5.3 Full suite
```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/epistemos-codex-audit-full test
```
Expected: ~3339 total. Known failures to triage: 3 `KnowledgeCoreBridgeTests` (shadow runtime / projected strings) were flagged by Codex as pre-existing. Confirm they are not newly introduced by this session.

### 5.4 Release preflight
```bash
bash /Users/jojo/Downloads/Epistemos/scripts/audit/release_preflight.sh /tmp/epistemos-codex-release
```
Expected: `PASS: release preflight complete`.

### 5.5 Runtime log capture (for perf hunt)
```bash
unset EPI_HOME_WINDOW_INPUT_DIAGNOSTICS  # critical — user's shell may still have it
log stream --predicate 'subsystem CONTAINS "com.epistemos"' --level debug --style compact \
  > /tmp/epistemos-codex-runtime.log 2>&1 &
open /Users/jojo/Downloads/Epistemos/build/release-derived-data/Build/Products/Release/Epistemos.app
# Walk app — reproduce user complaints
kill %1
```
Then check:
```bash
grep -cE 'InputAudit|home_window_alpha_write' /tmp/epistemos-codex-runtime.log  # expect 0 in Release
grep -cE 'LiveNoteScanner: found' /tmp/epistemos-codex-runtime.log  # expect 0 unless opt-in
awk -F'\\[|\\]' '{print $4}' /tmp/epistemos-codex-runtime.log | sort | uniq -c | sort -rn | head -15
```

---

## 6. Manual Walkthrough Checklist

Mark PASS / FAIL / SKIP.

### Startup + landing
- [ ] App launches directly into landing (not agent page). `homeSurfaceRoute == .home`.
- [ ] Tap on landing background — popover opens at tap location.
- [ ] Popover expands as you type a long prompt.
- [ ] No Chat/Agent segmented picker visible.
- [ ] Model picker visible inside popover.
- [ ] Typing feels fluid — zero lag, zero stutter.

### Main chat
- [ ] OLED black in dark mode, theme bg in light mode. No title-bar color flash on landing → chat transition.
- [ ] `ChatBrainPickerMenu` visible on composer control row.
- [ ] Pill reads the actual selected model family (Local when local is picked, Cloud when cloud is picked, Apple Intelligence when it is).
- [ ] Type "hey what's up" on local model → pill = Local.
- [ ] Type "hey what's up" on OpenAI → pill = Cloud.
- [ ] Type "create a note about today" on OpenAI → pill previews Agent; submit → agent loop fires.
- [ ] Type "create a note about today" on local → orange banner appears → tap → switches to OpenAI → banner clears.
- [ ] `/` at start of composer opens native slash menu. Type filter (`/not` → `/notes`). Enter fills. Esc closes.
- [ ] Submit with Claude / o-series → thinking panel collapsible above response. Contents update live.
- [ ] Trigger a failure (unplug wifi, submit cloud query). Error bubble uses friendly copy — not raw NSError.
- [ ] Scroll long chat — no stutter.

### MiniChat (⌘3)
- [ ] Rounded ultraThinMaterial background extends behind traffic lights.
- [ ] Pill in composer.
- [ ] Model picker in composer.

### Note editor
- [ ] Opening a note from graph: Notes utility sidebar dismisses, physics stops.
- [ ] Typing in the note feels native (no graph-render-driven stutter).
- [ ] `AssistantToolbarAskBar` shows pill.

### Graph
- [ ] Canvas idle is smooth. No stutter without pinned panels.
- [ ] Open note → physics stops, panels hide.
- [ ] Return to canvas → physics resumes smoothly.
- [ ] Open folder → same.
- [ ] No leftover pinned inspectors visible on note/folder route.

### Settings
- [ ] Sidebar shows 12 sections (down from 14).
- [ ] "Agent" sidebar entry → Overview / Authority / Overseer tabs.
- [ ] Overseer tab shows per-turn route / budgets / tool permissions after sending a message.
- [ ] Authority panel shows tool categories with allow / ask / deny.
- [ ] iMessage Driver: raw errors replaced by guided hint + Open FDA / Relaunch buttons.
- [ ] Local model install error → friendly copy (HF unreachable, gated, disk, timeout).

### Model catalog
- [ ] Gemma 4 tiers NOT auto-picked by triage.
- [ ] Explicit Bonsai selection actually runs Bonsai (no silent Gemma 4 substitution).
- [ ] Hermes 4.3 (4bit + 3bit) loads cleanly.
- [ ] Qwen 3 official / Qwen 3 Coder Next / Qwen 3 Coder 30B A3B load cleanly.
- [ ] Qwen 3.6 Unsloth + DWQ variants coexist.

### Code editor
- [ ] Outer + inner editor canvas match in dark mode.
- [ ] Same in light mode.
- [ ] Same when theme follows system appearance (dark ↔ light transition).

### Agents (Rust correctness)
- [ ] Panic in a tool handler → surfaces `Tool failed:` error, session continues.
- [ ] `run_agent_loop` with `Local` provider → immediate `LocalProviderNotAllowed` error before any model invocation.

### Quick Capture (⌘⇧N)
- [ ] Voice capture works on first use (Apple Speech prompts for Speech Recognition permission).
- [ ] Transcription produces real text without any Python / whisper install.
- [ ] No "Capture Trace Inspector" clock button in Release.

---

## 7. Uncommitted Work + .gitignore Hygiene

At handoff time: ~186+ uncommitted files in the working tree.

**Breakdown to expect:**
- Modified `.swift` from pre-session staged work.
- Build artifacts from `syntax-core/target/`, `LocalPackages/*/target/`, `build-rust/swift-bindings/` that should be gitignored.
- `.xcuserstate` / `xcuserdata/` files — user-local Xcode state; do not commit.
- Rust dylib + rlib files under `agent_core/target/*` and similar.

**Recommended workflow:**
```bash
git status --short > /tmp/epistemos-dirty.txt
# 1. Identify build artifacts and add to .gitignore.
# 2. Group real edits by subsystem (Epistemos/App/, Engine/, Views/, etc).
# 3. Read each diff: git diff --cached <paths> | head -200
# 4. Commit coherent batches with descriptive messages.
# 5. Rebuild after every 3-4 batches to catch accumulated regressions.
```

**`.gitignore` entries likely missing:**
```
syntax-core/target/
agent_core/target/
graph-engine/target/
omega-mcp/target/
omega-ax/target/
epistemos-core/target/
build-rust/
*.xcuserstate
*.xcuserdatad
```

After updating, `git rm --cached` the entries that are currently tracked but should not be, commit, then rebuild.

---

## 8. Known Open Items / Next-Session Backlog

### 8.1 Gemma 4 Swift loader (hard blocker for the model family)
- Alias at `850cc36d` gets past "Unsupported model type" but the decoder fails on MatFormer fields.
- Real config.json samples for E4B (dense, 42 layers, GQA + KV-shared) and 26B A4B (MoE, 128 experts) are on disk — find them at the user's model download paths.
- Plan: write `Gemma4TextConfiguration` first (~100 lines, deterministic JSON→struct), then stub `Gemma4TextModel` that throws `"Gemma 4 MLX forward pass not yet implemented"`. This alone makes the error honest and stops Gemma 4 from corrupting unrelated triage paths.
- Full forward pass port is a multi-session workstream — needs cross-checking against `mlx-lm` Python reference. Land E4B first, MoE second.
- Catalog should show Gemma 4 tiers with a ⚠ Preview badge.

### 8.2 OpenThinker3-7B
- Better reasoning than DeepSeek-R1-Distill-Qwen-7B (33% reported).
- Needs MLX 4bit conversion — no community upload yet. Either convert locally via `mlx_lm.convert` or wait.

### 8.3 QwQ-32B
- R1-class reasoning at 32B. Straightforward add to catalog once OpenThinker3 is stable.

### 8.4 DFlash speculative decoding
- Python-only today. Draft models exist only for Qwen3-4B / Qwen3.5-4B.
- Wait for a Swift MLX speculative-decoding library before integrating.

### 8.5 DDTree-MLX
- Tree-based speculative decoding, 10-15% faster than DFlash on code. Also Python. Same deferral.

### 8.6 Deprecation sweep for orphaned Agent Command Center code
- Files marked `DEPRECATED (fused chat, 2026-04-18)`:
  - `AgentChatView.swift`
  - `AgentCommandCenterView.swift`
  - `AppBootstrap.presentAgentCommandCenter` + `submitAgentWorkspacePrompt`
  - `LandingView.submitLandingAgentPrompt` + `landingAgentSpecificControls` + `landingPromptSurfacePicker`
  - `LandingPromptSurface.agent` case
  - `HomeSurfaceRoute.agent`
- Plan: let fused chat bake for one release, then delete in a surgical PR.

### 8.7 Authority panel wiring
- UI exists; actual per-category enforcement hooks into tool dispatch are partially scaffolded. Confirm: when a user denies a category, the next tool call in that category actually gets blocked.

### 8.8 AgentHarness integration
- Clean-room scaffold (`QueryEngine`, handoffs, `BackendRegistry`, `UsageLedger`, `Authority`) is in the branch.
- **NOT wired into chat path yet.** Next integration phase: backend adapters for current providers, then migrate `ChatCoordinator.handleQuery` to use `AgentQueryEngine`.

### 8.9 Per-model modes in main chat
- `mainChatOperatingMode` now reads `inference.availableOperatingModes`. Each new model must declare its supported modes (Fast / Thinking / Pro / Agent).
- Spot-check: Claude Opus 4.x declares Thinking; o-series declare reasoning effort; Gemma 4 declares (nothing yet — it's excluded from triage).

### 8.10 Theme regression spot-check
The user flagged "the theme of it regressed" multiple times. Claude verified no theme files were touched. Possible sources:
- Codex's uncommitted work may include theme tweaks.
- `RootView.rootContent` Color.black pre-paint (now with `allowsHitTesting(false)`) — confirm it doesn't tint surfaces unexpectedly.
- Agent page restructure left dark surfaces that may read inconsistently with main chat.

Verify side-by-side: launch in dark mode, switch between landing → chat → mini → note and eyeball color continuity.

### 8.11 Intentional edit to ChatBrainPickerMenu.swift
The file was edited by the user/linter after Codex's work. Do NOT revert it. Current shape: thin wrapper over `LocalModelToolbarMenu` with `MainChatOperatingModePreference` helper. This is the authoritative version.

---

## 9. Things Codex Must NOT Do

- **Do not `git reset --hard`, `git checkout .`, `git restore`, or `git stash drop`** across the worktree. The user has repeatedly asked that destructive history operations never happen. They have lost work this way before.
- **Do not re-enable `EPI_HOME_WINDOW_INPUT_DIAGNOSTICS`** in any script, env file, or scheme.
- **Do not revert the `isEnabled` literal in `HomeWindowInputDiagnostics.swift`** — it's compile-time `false` on purpose to block the swizzle storm that was the dominant idle-lag source.
- **Do not commit `target/`, `.build/`, or any Rust build artifacts.** Fix `.gitignore` first.
- **Do not delete the DEPRECATED ACC code** until at least one stable release has shipped with the fused chat.
- **Do not revert the user's ChatBrainPickerMenu.swift linter edit.**
- **Do not skip hooks** (`--no-verify`) on commits. If a hook fails, fix the underlying issue.
- **Do not re-add Gemma 4 to triage preferred-order or shipped-fallback lists** until a real Gemma 4 loader lands.

---

## 10. Success Criteria

Codex considers this audit complete when:

1. All Rust tests green (agent_core = 511).
2. Full Swift test suite within expected pass count (~3336/3339 with 3 known `KnowledgeCoreBridgeTests` failures documented and confirmed pre-existing).
3. Manual walkthrough (§6) complete with PASS/FAIL per item.
4. Runtime log shows zero `InputAudit` events and zero `LiveNoteScanner: found` lines without explicit opt-ins.
5. `/tmp/epistemos-dirty.txt` triaged:
   - Build artifacts added to `.gitignore`.
   - Real edits committed in coherent subsystem batches OR stashed with a WIP message for user review.
6. Next-session backlog (§8) documented in a follow-up handoff with exact file paths and expected edits.
7. Graph performance regression either resolved or traced to an exact commit + documented next-step fix plan.

---

## 11. One-line TL;DR

Two agents worked this branch; together they shipped ~35 commits covering ANE wiring, UI polish, chat-surface fusion, a full thinking popover, a model-stack refresh, Overseer transparency, and settings consolidation — now audit for regressions in graph performance, chat fusion edge cases, and theme continuity, triage the 186+ uncommitted files, and document Gemma 4 + next-gen model ports as follow-up workstreams.
