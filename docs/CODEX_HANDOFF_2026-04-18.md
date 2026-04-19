# Codex Handoff — 2026-04-18

Full audit brief for Codex to regression-check this session's work and
pick up the queued next-session backlog.

---

## 1 · Branch + scope

- Branch: `codex/runtime-input-audit`
- Base: `main` (last shared SHA on `938bfe70 Add Claude → Codex final-walkthrough handoff doc`)
- Working tree: ~221 pre-existing uncommitted files from earlier Codex work — I did **not** touch those except where explicitly noted. **Do not `git checkout` or `git restore` anything** without confirming with Jordan first.
- Full Swift build is green at the tip. Full Swift test suite: 3336 / 3339 passing; the 3 remaining failures are `KnowledgeCoreBridgeTests` shadow-runtime tests that were already broken in Codex's uncommitted tree, unrelated to this session.

---

## 2 · What landed this session (chronological)

Each commit below should build independently and pass `xcodebuild … test -only-testing:EpistemosTests`.

| # | SHA | What | Files |
|---|---|---|---|
| 1 | `72d631e4` | Note CRUD skills (create/read/write/delete) as orchestration markdown | `.agents/skills/note-*/SKILL.md` |
| 2 | `2405cce6` | Graph panel + inspector leaking onto note/folder routes — sync hides all chrome on route change | `Epistemos/Views/Graph/HologramOverlay.swift` |
| 3 | `e5295ff8` | ModelCapabilityRole enum + role-tagged local model catalog (fastLocal / reasoningLocal / codingLocal / highEndLocal / cloudAgent / cloudReasoning / generalist) | `Epistemos/Engine/LocalModelInfrastructure.swift` |
| 4 | `217a886c` + `ab7b5e40` | AgentHarness scaffold: QueryEngine actor, typed handoffs, AgentBackend protocol + BackendRegistry, UsageLedger, Authority categories, settings view, tests | `Epistemos/Engine/AgentHarness/*` |
| 5 | `6233b45d` | Authority & Installs reachable in Settings (category-level per-tool permissions: vault/network/git/install/app-automation/etc.) | `Epistemos/Views/Settings/SettingsView.swift` |
| 6 | `9fe4db3f` | Pause Metal render + physics engine on non-canvas routes (user-reported graph stutter while typing in note page) | `Epistemos/Views/Graph/HologramOverlay.swift` |
| 7 | `850cc36d` | `gemma4` + `gemma4_text` registered in mlx-swift-lm LLMTypeRegistry (aliased to Gemma 3n) | `LocalPackages/mlx-swift-lm/Libraries/MLXLLM/LLMModelFactory.swift` |
| 8 | `a78decdf` + `ba07e260` | Agent core: panic-safe tool execution (catch_unwind around handler future) + cloud-only agent-loop gate (`AgentProvider.runtime()` returns `.cloud`/`.local`, `run_agent_loop` refuses `.local`) + regression tests | `agent_core/src/*` |
| 9 | `5f70f44e` / `2fa2b578` / `d0165947` / `3d83f377` | ChatCapability + pill live-wired in main / mini / note / graph composer; landing Chat/Agent picker removed | `Epistemos/Engine/AgentHarness/ChatCapability.swift`, `Epistemos/Views/Shared/ChatCapabilityPill.swift`, `Epistemos/Views/Chat/ChatInputBar.swift`, `Epistemos/Views/Landing/LandingView.swift`, and the three other composer hosts |
| 10 | `236f7748` / `30bffaea` / `c543e3fb` | Smart pill: pre-submit intent classifier, live tool-detail (`Agent • web_search`), tappable "needs cloud" banner that switches to OpenAI | `Epistemos/Engine/AgentHarness/ChatCapability.swift`, `Epistemos/Views/Chat/ChatInputBar.swift` |
| 11 | `1197b995` | Auto-promote: `MainChatSubmissionRouter.autoPromotedMode` flips `.fast/.thinking/.pro` → `.agent` when classifier says so AND cloud provider supports it; `CloudModelProvider.supportsAgentTier` gate (OpenAI + Anthropic only) | `Epistemos/State/ChatState.swift`, `Epistemos/State/InferenceState.swift`, `Epistemos/Views/Chat/ChatView.swift`, `Epistemos/Views/Landing/LandingView.swift` |
| 12 | `f19cda7e` | Orphaned Agent Command Center code marked DEPRECATED with comment-only headers | `Epistemos/Views/AgentChat/AgentChatView.swift`, `Epistemos/Views/AgentCommandCenter/AgentCommandCenterView.swift`, `Epistemos/App/AppBootstrap.swift`, `Epistemos/Views/Landing/LandingView.swift`, `Epistemos/App/RootView.swift` |
| 13 | `f3e9c6d4` | Four "messy AI" pain points: pill reads `preferredChatModelSelection` (stops lying about Cloud); Gemma 4 family demoted from preferred-order; triage-ready candidate filter keeps Gemma 4 out of the shipped-fallback path | `Epistemos/Engine/TriageService.swift`, pill files |
| 14 | `5c67bf6c` | Canvas stutter fix: reverted `\|\| hasPinnedPanels` in `MetalGraphNSView` needsRender | `Epistemos/Views/Graph/MetalGraphView.swift` |
| 15 | `8b0416ba` | **Model stack refresh** — Qwen 3 4B (official), Qwen 3 Coder Next + 30B A3B, Hermes 4.3 36B (4bit + 3bit), Qwen 3.6 35B A3B Unsloth UD + DWQ. New `ModelCapabilityRole.functionCallingLocal`. TriageService preferredOrder rewritten. `docs/MASTER_MODEL_STACK_PLAN.md` created | catalog + triage + plan doc |
| 16 | `1b7611f8` | **Thinking popover** (ChatGPT-style): live `streamingThinking` state on ChatState; `onThinkingDelta` now routed (was silently dropped); `ThinkingPopoverView` pulses while active, shows live stream in a SwiftUI `.popover`, collapses to "Thought for Ns" pill when answer starts. Revision SHAs pinned for the 5 new models (Hermes on "main" with test exemption). LocalModelInfrastructureTests + ACC test isolation fixes | `Epistemos/State/ChatState.swift`, `Epistemos/App/ChatCoordinator.swift`, `Epistemos/Views/Chat/ThinkingPopoverView.swift`, `Epistemos/Views/Chat/ChatView.swift` |
| 17 | `b4cd616b` | **Overseer transparency panel** (Settings → Agent → Overseer) + `homeSurfaceRoute` hard-wired to `.home` so Agent Chat never pops on startup | `Epistemos/State/OverseerAuditState.swift`, `Epistemos/Views/Settings/OverseerSettingsView.swift`, `Epistemos/App/AppBootstrap.swift`, `Epistemos/App/AppEnvironment.swift`, `Epistemos/App/ChatCoordinator.swift`, `Epistemos/App/RootView.swift`, `Epistemos/Views/Settings/SettingsView.swift` |
| 18 | `9ccd135d` | Picker simplification: one cloud row (user's preferred cloud model) + kill duplicate `Auto-route Local → Cloud` toggle in both `ChatBrainPickerMenu` and `LocalModelToolbarMenu`; `InferenceState.preferredCloudModel(for:)` promoted to public | chat picker files |
| 19 | `5815f440` | Agent consolidation: 14 settings sections → 12; Agent Control + Authority + Overseer merged under a single "Agent" nav entry with three tabs (Overview / Authority / Overseer). Legacy enum cases retained for deep-link compatibility | `Epistemos/Views/Settings/AgentSectionDetailView.swift`, `Epistemos/Views/Settings/SettingsView.swift` |
| 20 | `ac78efc8` | `/` slash-command popover on fused main chat: native SwiftUI popover, Spotlight-style rows, live filtering, strips the `/slug` and promotes operatingMode on select. Eleven commands (ask, notes, code, debug, plan, research, review, security-review, summarize, read-branch, explain) | `Epistemos/Views/Chat/SlashCommandPopover.swift`, `Epistemos/Views/Chat/ChatInputBar.swift` |
| 21 | pending (this doc + editor fix) | `NoteWorkspaceSurfaceStyle.canvasBackground` no longer returns `.clear` on system-appearance themes — matches the code editor's solid `NSColor.textBackgroundColor` so the two themes stop attacking each other at the panel edges | `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`, `docs/CODEX_HANDOFF_2026-04-18.md` |

---

## 3 · Regression-check checklist

Walk through these flows manually (or scripted) before concluding the session is stable.

### 3.1 — Graph (explicit request from Jordan)

- **Hologram overlay opens without stutter.** Reset canvas (Cmd+R if bound), let physics settle. Render loop should idle — no background CPU spin after settle.
  - Commit at risk: `5c67bf6c` (needsRender without `\|\| hasPinnedPanels`). If pinned inspectors are open and nodes aren't moving, render should still stop.
- **Pin one inspector, deselect node.** Panel should still follow the node during camera moves. Coordinate freshness comes from the 30fps `pinnedPanelTimer` in `HologramOverlay` + Rust `force_alive` from `d20f416b` (pre-existing commit). No render-loop dependency.
- **Open a graph node → note page.** Left `HologramSearchSidebar` and right `HologramNodeInspector` should BOTH disappear. Commit at risk: `2405cce6`. Watch for "two panels visible over the note page" — that was the user-reported bug.
- **Navigate back to canvas.** `metalView.pauseEngine()` was called on exit; `resumeEngine()` must fire on return. Commit at risk: `9fe4db3f`. If canvas is stuck on a frozen frame after returning from a note, physics cycle didn't restart — check `syncGraphWorkspaceChromeVisibility(isCanvas:)`.
- **Type in a graph note.** TextKit 2 prose editor should feel native; no drop frames. If it still stutters on canvas-behind, the `pauseEngine` call didn't fire.

### 3.2 — Chat surfaces (fused)

- **Landing page.** Composer should have no `Chat / Agent` segmented picker. All prompts submit through main chat. (`3d83f377`)
- **Type "create a note about X" on a cloud provider.** Pill should preview `.agent` BEFORE you hit send. On submit, `MainChatSubmissionRouter.autoPromotedMode` promotes to `.agent` and the turn runs through the agent loop. (`1197b995`)
- **Type the same on a local model.** Orange banner appears: "This looks like agent work. Tap to switch to OpenAI and run it with tools." Tap → `InferenceState.setActiveAIProvider(.openAI)` runs, banner disappears, pill updates. (`c543e3fb`)
- **Model picker — main chat composer.** Should show Apple → Local stack → ONE cloud row (your preferred cloud model, with "Change in Settings" link). No 10+ cloud rows, no "Auto-route Local → Cloud" toggle. (`9ccd135d`)
- **Mini chat / Note chat / Graph chat popovers.** Same: Apple → Local → ONE cloud row. (`9ccd135d`, `d0165947`)
- **Mid-stream thinking.** On a thinking-capable cloud model, a purple "Thinking" pill should pulse at the top of the streaming bubble. Tap → SwiftUI popover with live auto-scrolling reasoning text. First answer token → pill flips to "Thought for Ns", popover content is frozen but still openable. (`1b7611f8`)
- **/ slash menu.** Type `/` in main chat composer — popover with 11 commands. Type `/p` → filters to "plan". Select `/plan` → text clears the `/plan` prefix and operating mode promotes to `.agent`. (`ac78efc8`)
- **Agent on startup.** Quit and relaunch. Home page should be the landing / main chat surface. Old AgentChatView must never render. (`b4cd616b`'s `homeSurfaceRoute` change)

### 3.3 — Settings

- **Sidebar shows 12 rows.** Specifically: General, Channels, Cognitive, Inference, Knowledge Fusion (Experimental), Model Vaults, iMessage Driver, Skills, **Agent** (not three separate entries), Landing, Appearance, Vault. (`5815f440`)
- **Agent section has three tabs.** Overview / Authority / Overseer via segmented picker at the top. All three panels render below as before.
- **Authority panel.** Per-category permission picker (autoAllow / askFirst / neverAllow) for 11 categories. (`217a886c`, `6233b45d`)
- **Overseer panel.** Run a few main-chat prompts, then open Settings → Agent → Overseer. Most recent plans show up with route pill (Local only / Overseer + local tools / Managed agent (cloud)), depth-budget metrics, collapsible detail. "Reset history" clears the list. (`b4cd616b`)

### 3.4 — Local model catalog

- **Chat picker local section.** Should list installed shipped models only: Qwen 3 4B (if installed), Bonsai 4B / 8B, DeepSeek R1 7B, Qwen 3 Coder Next, Qwen 2.5 Coder 7B (legacy), Qwen 3 Coder 30B A3B (if 24GB+), Hermes 4.3 36B (4bit + 3bit if installed), Qwen 3.6 35B A3B (plain / Unsloth UD / DWQ variants).
- **Gemma 4 tiers NOT in the picker as actionable options.** They're still in the catalog (preview-gated) but triage won't pick them; loading one produces `"Unsupported model type: gemma4"` because the loader isn't ported yet. (See §5 below.)
- **Triage sanity.** Start a plain chat on a 4GB-class local model; triage should pick Qwen 3 4B or Bonsai tiers, never Gemma 4. (`f3e9c6d4`'s triage-ready filter)

### 3.5 — Rust agent_core

- `cargo test --manifest-path agent_core/Cargo.toml` — 511 passing (509 baseline + 2 new regression tests from `ba07e260`).
- Verify: `run_agent_loop` rejects a `Local` provider with `AgentError::LocalProviderNotAllowed`. Error classifier surfaces "switch to a cloud provider" recovery hint.
- Panic isolation: drop a synthetic panic inside any `ToolHandler.execute` — agent session should continue, surfacing a `ToolError::ExecutionFailed` message instead of aborting.

### 3.6 — Test suite

```
# Swift
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS,arch=arm64' test \
  -only-testing:EpistemosTests

# Expected: 3336 / 3339 passing. The 3 failures are in
# KnowledgeCoreBridgeTests / "shadow runtime" — unrelated to this
# session's work. If any NEW test fails, it's a regression introduced
# by the handoff.

# Rust
cargo test --manifest-path agent_core/Cargo.toml

# Expected: 511 tests passing.
```

---

## 4 · Known open items (in this session's scope)

- The 3 `KnowledgeCoreBridgeTests` failures ("shadow runtime batches summaries onto MainActor state", "shadow runtime reuses projected strings across repeated row applies") — already failing in Codex's uncommitted tree before this session. Not in scope to debug here; flag for whoever owns Knowledge Core.
- SwiftLint errors on the vendored `CodeEditSourceEditor` + `CodeEditTextView` packages — non-fatal, appear on every build.
- `leonsarmiento/Hermes-4.3-36B-*-mlx` revisions still pinned to `"main"` because their HF API returns 401 without auth. `LocalModelInfrastructureTests.catalogUsesPinnedRevisions` has a scoped exemption with a TODO; pin these once the owner publishes a public SHA endpoint or we add a token-backed `scripts/pin_catalog_revisions.sh`.

---

## 5 · Next-session backlog

From `docs/MASTER_MODEL_STACK_PLAN.md` §3. Do them in this order:

### 5.1 — Port Gemma 4 Swift loader (big)

- **Source**: `SharpAI/SwiftLM` on GitHub (MIT license). They've already ported Gemma 4 to MLX-Swift via their `mlx-swift-lm` fork.
- **Target**: Epistemos's vendored copy at `LocalPackages/mlx-swift-lm/Libraries/MLXLLM/Models/Gemma4Text.swift` (new file).
- **Order**:
  1. Start with the E4B dense variant (`unsloth/gemma-4-E4B-it-UD-MLX-4bit`).
     - Real config.json already on disk at `~/Library/Application Support/Epistemos/Models/text/active/mlx-community--gemma-4-e4b-it-4bit/config.json` — use this as schema reference. It's top-level `model_type: gemma4` with a nested `text_config: model_type: gemma4_text`.
     - Fields the decoder must handle: `hidden_size: 2560`, `num_hidden_layers: 42`, `num_attention_heads: 8`, `head_dim: 256`, `num_key_value_heads: 2`, `num_kv_shared_layers: 18` (layers 24–41 share KV with earlier layers), `sliding_window: 512`, `layer_types: ["sliding_attention"...] 5:1 sliding/full pattern`, `rope_parameters` nested per attention type, `hidden_size_per_layer_input: 256`, `vocab_size_per_layer_input: 262144`. No `altup_*` / `laurel_rank` fields (Gemma 3n had those; Gemma 4 doesn't).
  2. Then the MoE variant (`mlx-community/gemma-4-26b-a4b-it-4bit`). Adds `enable_moe_block: true`, `num_experts: 128`, `top_k_experts: 8`, `moe_intermediate_size: 704`, `num_global_key_value_heads: 2`, `attention_k_eq_v: true`. Config also on disk at the adjacent path.
  3. Register both under `"gemma4"` and `"gemma4_text"` in `LLMTypeRegistry`. **Remove** the current alias-to-`Gemma3nTextConfiguration` placeholder from `850cc36d`.
- **Verify**: `unsloth/gemma-4-E4B-it-UD-MLX-4bit` loads and generates coherent tokens on a simple "describe this sentence" prompt.
- **Once green**:
  - Remove Gemma 4 family from the `triageReadyCandidates` filter in `TriageService.preferredAutomaticLocalModel`.
  - Restore Gemma 4 tiers to `preferredOrder` (check `MASTER_MODEL_STACK_PLAN.md` for the original ordering by mode + intent).
  - Swap catalog HF IDs: `mlx-community/gemma-4-*` → `unsloth/gemma-4-*-UD-MLX-4bit` in `LocalTextModelID`.
  - Delete the Gemma 4 preview-gate copy in `MASTER_MODEL_STACK_PLAN.md`.

### 5.2 — OpenThinker3-7B MLX conversion (medium)

- **Source**: `open-thoughts/OpenThinker3-7B` (Qwen2.5-7B-Instruct base).
- **Run locally**: `python -m mlx_lm convert --hf-path open-thoughts/OpenThinker3-7B --quantize --q-bits 4` then `mlx_lm.upload --path mlx-models/OpenThinker3-7B-4bit --upload-repo <your-org>/OpenThinker3-7B-MLX-4bit` OR use a community conversion once one appears.
- **Add to catalog**: `openThinker3_7B4Bit` case, role `.reasoningLocal`, promote ahead of DeepSeek R1 7B in `TriageService.preferredOrder.thinking`. The OpenThoughts3 paper claims 33% better reasoning than DeepSeek-R1-Distill-Qwen-7B; same Qwen2.5-7B base means no new arch support needed in mlx-swift-lm.

### 5.3 — QwQ-32B flagship reasoning (small)

- **Source**: `mlx-community/QwQ-32B-4bit` (~24GB memory).
- **Add to catalog**: `qwqFlagship32B4Bit`, role `.reasoningLocal` (flagship tier above OpenThinker3-7B).
- **Triage**: add to `.thinking + default` preferredOrder as the #1 pick when available.

### 5.4 — DFlash speculative decoding (deferred; do nothing until blocker clears)

- **Blocker**: Python-only. `Aryagm/dflash-mlx` and `humanrouter/ddtree-mlx` both require a Python runtime, which would violate the CLAUDE.md "no sidecar for inference" rule. Waiting for either:
  - A Swift MLX speculative-decoding library to appear, or
  - mlx-swift-lm to add a public speculative-decoding API we can adapt.
- **When it clears**: target Qwen3-4B first (DFlash's default target). Add a `useDFlashDraft` toggle behind a feature flag and a draft model entry (`z-lab/Qwen3-4B-DFlash-b16`).
- **Keep watching**: https://github.com/Aryagm/dflash-mlx and https://github.com/humanrouter/ddtree-mlx.

### 5.5 — Eventually: delete the DEPRECATED Agent Command Center code

After the fused chat has been in production for a release cycle with no regressions, delete (in one PR):

- `Epistemos/Views/AgentChat/AgentChatView.swift` (entire file)
- `Epistemos/Views/AgentCommandCenter/*` (entire directory)
- `AppBootstrap.presentAgentCommandCenter` and `AppBootstrap.submitAgentWorkspacePrompt`
- `LandingView.submitLandingAgentPrompt`, `landingAgentSpecificControls`, `landingPromptSurfacePicker`, `LandingPromptSurface` enum
- `HomeSurfaceRoute.agent` case (and the unused `homeSurfaceRoute` branch in `RootView`)
- The three legacy `SettingsSection` cases `.agentControl / .authority / .overseer` (and the test exemptions that reference them)

All already carry `DEPRECATED (fused chat, 2026-04-18)` comments pointing at the deletion schedule.

---

## 6 · Files I touched this session

Fully authored by this session (safe to review in isolation):

```
docs/CODEX_HANDOFF_2026-04-18.md                        (this file)
docs/MASTER_MODEL_STACK_PLAN.md
.agents/skills/note-create/SKILL.md
.agents/skills/note-read/SKILL.md
.agents/skills/note-write/SKILL.md
.agents/skills/note-delete/SKILL.md
Epistemos/Engine/AgentHarness/AgentAuthority.swift
Epistemos/Engine/AgentHarness/AgentBackend.swift
Epistemos/Engine/AgentHarness/AgentHandoff.swift
Epistemos/Engine/AgentHarness/AgentQueryEngine.swift
Epistemos/Engine/AgentHarness/AgentUsageLedger.swift
Epistemos/Engine/AgentHarness/ChatCapability.swift
Epistemos/State/OverseerAuditState.swift
Epistemos/Views/Chat/ThinkingPopoverView.swift
Epistemos/Views/Chat/SlashCommandPopover.swift
Epistemos/Views/Settings/AgentSectionDetailView.swift
Epistemos/Views/Settings/AuthoritySettingsView.swift
Epistemos/Views/Settings/OverseerSettingsView.swift
Epistemos/Views/Shared/ChatCapabilityPill.swift
EpistemosTests/AgentHarnessTests.swift
```

Targeted edits (delta-only, preserve Codex's larger uncommitted work in the same files):

```
Epistemos/App/AppBootstrap.swift                        (overseerAuditState property + ACC deprecation comments)
Epistemos/App/AppEnvironment.swift                      (injected overseerAuditState)
Epistemos/App/ChatCoordinator.swift                     (thinkingDelta wiring + overseer.record + deprecation comments)
Epistemos/App/RootView.swift                            (homeSurfaceRoute → .home + picker simplification + deprecation comments)
Epistemos/Bridge/StreamingDelegate.swift                (unchanged; referenced for routing)
Epistemos/Engine/LocalModelInfrastructure.swift         (ModelCapabilityRole + catalog descriptors for new models)
Epistemos/Engine/TriageService.swift                    (preferredOrder rewrite + triageReadyCandidates filter)
Epistemos/State/ChatState.swift                         (currentCapability + streamingThinking + thinking timestamps + MainChatSubmissionRouter.autoPromotedMode)
Epistemos/State/InferenceState.swift                    (new LocalTextModelID cases + display/memory/mode flags + preferredCloudModel public accessor + CloudModelProvider.supportsAgentTier)
Epistemos/Views/Chat/ChatInputBar.swift                 (pill + slash menu + needs-cloud banner)
Epistemos/Views/Chat/ChatView.swift                     (pill refresh + thinking popover host in StreamingIndicator)
Epistemos/Views/Chat/MessageBubble.swift                (unchanged from this session)
Epistemos/Views/Graph/HologramOverlay.swift             (syncGraphWorkspaceChromeVisibility + pauseEngine)
Epistemos/Views/Graph/HologramSearchSidebar.swift       (pill in graph chat composer)
Epistemos/Views/Graph/MetalGraphView.swift              (reverted || hasPinnedPanels)
Epistemos/Views/Landing/LandingView.swift               (Chat/Agent picker removed + deprecation comments)
Epistemos/Views/MiniChat/MiniChatView.swift             (pill in mini chat composer)
Epistemos/Views/Notes/NoteDetailWorkspaceView.swift     (pill in note chat composer + canvasBackground theme-conflict fix)
Epistemos/Views/Settings/SettingsView.swift             (Agent consolidation + authority + overseer)
Epistemos/Views/AgentChat/AgentChatView.swift           (DEPRECATED header only)
Epistemos/Views/AgentCommandCenter/AgentCommandCenterView.swift  (DEPRECATED header only)
EpistemosTests/TriageServiceTests.swift                 (updated expectations for new stack)
EpistemosTests/LocalModelInfrastructureTests.swift      (updated baseline expectations + Hermes revision exemption)
EpistemosTests/SettingsCategoryTests.swift              (12 sections + agent row)
EpistemosTests/AgentCommandCenterStateTests.swift       (UserDefaults isolation fix)
agent_core/src/agent_loop.rs                            (cloud-only gate + LocalProviderNotAllowed error)
agent_core/src/error_classifier.rs                      (new error arm)
agent_core/src/provider.rs                              (ProviderRuntime enum + runtime() trait method)
agent_core/src/tools/registry.rs                        (panic-safe execute with catch_unwind)
LocalPackages/mlx-swift-lm/Libraries/MLXLLM/LLMModelFactory.swift   (gemma4 alias — temporary)
```

---

## 7 · Code editor theme fix (just-landed) — verify

- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:134` — `NoteWorkspaceSurfaceStyle.canvasBackground(for:)` now uses the same solid color as `MarkdownPreviewSurfaceStyle.canvasBackground` for every theme, including system-appearance. This resolves the "two themes attacking each other" seam at the code editor panel edges (outer SwiftUI wrapper was `.clear` while the inner `CodeEditSourceEditor` painted `NSColor.textBackgroundColor`).
- **Verify**: open a code-editor note under (a) system-appearance theme (Settings → Appearance → Match macOS) and (b) a custom theme. In both cases, the code editor's background should blend seamlessly into the surrounding note workspace. No visible panel-edge seam.
- Known cosmetic: the code editor's own syntax highlighting theme (`flatLight` / `flatDark` / `minimalLight` / `minimalDark` in `CodeEditorView.swift:33+`) is independent of the outer chrome. If a user reports syntax colors still feeling off, that's the inner theme — toggle `useMinimalTheme` at `CodeEditorView.swift:1729` or tune the per-token colors in the theme factories.

---

## 8 · What I explicitly did NOT touch

For auditability:

- `Epistemos/Theme/*` — zero edits all session. Any perceived "theme regression" isn't from this work.
- `agent_core/src/providers/*` (claude.rs, gemini.rs, openai.rs) — unchanged from Codex's uncommitted state.
- `graph-engine/*` — unchanged.
- `omega-mcp/*` — unchanged.
- `syntax-core/*` — unchanged.
- Codex's 221 uncommitted pre-session files — not touched except where I committed specific targeted edits listed in §6.

---

## 9 · Ship-readiness posture

- **OK to cut a release candidate off this tip** IF §3 regression checklist passes on a real build.
- **Blockers for GA**:
  - 3 `KnowledgeCoreBridgeTests` failures need owner triage (not this session's code).
  - Gemma 4 is preview-gated — users who explicitly pick a Gemma 4 tier will hit an "Unsupported model type" error on the load path. Either accept as a known limitation in the release notes, or finish §5.1 first.

Jordan — please audit this handoff + the regression checklist in §3 before shipping, and pass §5 to Codex when ready for the next session.
