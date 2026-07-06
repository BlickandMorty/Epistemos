# June Skills Index

Date: 2026-07-06

This index tracks reusable MAS June build skills. Skills are load-bearing methods for future app work, not changelog trophies.

## Active Skills

### `june-agent-core-cloud-loop`

Use when connecting, auditing, hardening, or extending the MAS June cloud agent loop through in-process `agent_core`, June event frames, approval gating, and selected-vault routing.

Source: `.claude/skills/june-agent-core-cloud-loop/SKILL.md`

Next required use: the next June cycle must use this skill to capture the missing running MAS proof: selected vault, cloud agent, approval prompt, vault read/write, transcript/screenshot/log evidence, no fake local tools, and a clean App Store bundle scan with no flattened Pro/runtime executables.

### `june-prompt-forge`

Use when adding, auditing, hardening, or extending MAS June submit-time prompt upgrades, System Prompt Forge, Pattern Library composition, visible review/diff UX, active-vault grounding, or any pre-engine transformation that must preserve intent and stay honest about local/cloud capability.

Source: `.claude/skills/june-prompt-forge/SKILL.md`

Next required use: the next Prompt Forge/System Prompt Forge slice must use this skill to keep upgrades visible, bounded, off-main, vault-honest, and reviewable before any `prompt.submit` or system-prompt application path.

### `june-system-prompt-forge`

Use when adding, auditing, hardening, or extending MAS June system-prompt upgrades, behavior-layer composition, Pattern Library settings, visible system-prompt diff/review UX, native persistence, active-vault grounding, or local/cloud lane-guarded instruction assembly.

Source: `.claude/skills/june-system-prompt-forge/SKILL.md`

Next required use: the next June behavior-layer or Pattern Library slice must use this skill before changing `JuneSystemPromptForge`, `system_prompt_forge_*` bridge commands, Agent settings Behavior UI, or runtime instruction composition.

### `june-runtime-route-verdict`

Use when materializing, auditing, or extending MAS June deterministic route witnesses, RuntimeRouter policy tables, RouteVerdict diagnostics, cloud-first/local-second model routing, lane toggles, or local chat-only capability gates without executing models or faking local tools.

Source: `.claude/skills/june-runtime-route-verdict/SKILL.md`

Next required use: the next deterministic substrate routing slice must use this skill before changing `RuntimeRouter`, route profiles, lane toggles, model preference tables, or local/cloud capability admission.

### `june-replay-bundle-export`

Use when adding, auditing, or hardening MAS June ReplayBundle or `.epbundle` export paths, AnswerPacket-to-bundle evidence, provenance artifact actions, or deterministic substrate export FFI that must return bounded bytes without sidecars, subprocess verifiers, webview file authority, or fabricated verification claims.

Source: `.claude/skills/june-replay-bundle-export/SKILL.md`

Next required use: the next June provenance/export slice must use this skill before changing `export_replay_bundle_epbundle_bytes`, any `run.export-bundle` capability, June transcript export actions, or user-visible ReplayBundle save flows.

### `june-deterministic-vault-safety`

Use when adding, auditing, or hardening MAS June vault grounding, `vault.search` confidence floors, deterministic retrieval gates, `vault.write` mutations, reversible effect routing, or any June agent vault action that must be honest, reversible, bounded, and source/test guarded without loading local models.

Source: `.claude/skills/june-deterministic-vault-safety/SKILL.md`

Next required use: the next June vault-grounding or vault-mutation slice must use this skill before changing `vault_search_ladder`, EML/schema gate defaults, `VaultWriteHandler`, `VaultIntentApplier`, or any web/native UI that surfaces effect/retrieval evidence.

### `june-streaming-thinking-boundary`

Use when adding, auditing, or hardening MAS June streaming paths, token/event buffers, thinking/reasoning deltas, model thinking labels, or local/cloud stream bridges that must remain bounded and honest.

Source: `.claude/skills/june-streaming-thinking-boundary/SKILL.md`

Next required use: the next June streaming/thinking slice must use this skill before changing `AsyncStream`/`AsyncThrowingStream`, `thinking.delta`, `modelSupportsThinking`, or model capability metadata.

### `june-provider-native-thinking`

Use when adding, auditing, or hardening MAS June provider-native thinking/reasoning support across Swift model rows, `agent_core` provider slugs, provider request controls, stream parsers, and capability labels.

Source: `.claude/skills/june-provider-native-thinking/SKILL.md`

Next required use: the next provider/model-thinking slice must use this skill before changing `CloudTextModelID`, `GooseMASAgentCoreRunner.agentCoreSlug`, `agent_core/src/bridge.rs` provider arms, or provider-specific reasoning request/stream code.

### `june-local-context-budgeting`

Use when changing MAS June local prompt assembly, Prompt Forge profiles, conversation history folding, GGUF reply budgets, local model catalog context windows, or any local-lane behavior that must adapt to smaller context models without loading model bytes or faking local tools.

Source: `.claude/skills/june-local-context-budgeting/SKILL.md`

Next required use: the next local Prompt Forge, local history, GGUF reply-budget, or context-window slice must use this skill before changing `JunePromptForge`, `JuneAgentGateway` local history composition, `GGUFModelCatalog` context windows, or `LocalGGUFQuickChatBackend` prompt preflight.

### `june-durable-event-replay`

Use when adding, auditing, or hardening MAS June durable replay for streamed agent events, including reasoning deltas, tool calls/results, Hermes-compatible session messages, and relaunch/all-chats parity.

Source: `.claude/skills/june-durable-event-replay/SKILL.md`

Next required use: the next June session-history or transcript-replay slice must use this skill before changing `JuneSessionStore`, `hermes_bridge_session_messages`, streamed tool/reasoning persistence, or reload/relaunch transcript reconstruction.

### `june-native-capability-bridge`

Use when exposing an existing MAS-safe native, vault, agent_core, or deterministic substrate capability to the June webview through the Tauri shim/bridge without making webview JavaScript the authority or weakening capability truth.

Source: `.claude/skills/june-native-capability-bridge/SKILL.md`

Next required use: the next June substrate/user-skill/AnswerPacket/ReplayBundle bridge must use this skill before adding or changing `JuneAgentBridge` invoke commands, especially any path that reads vault data, lists skills, exports artifacts, or toggles capability visibility.

### `june-webview-typography-boundary`

Use when changing MAS June webview typography, native host CSS overlays, vendored June font tokens, landing/page-header display fonts, or any style rule that could make sidebar, body, composer, settings, or note text inherit a pixel/display face.

Source: `.claude/skills/june-webview-typography-boundary/SKILL.md`

Next required use: the next June visual/typography slice must use this skill before changing `JuneAgentSurfaceView.workspaceOverlayScript`, vendored June font tokens, or page-title/landing/header typography.

### `june-source-decomposition`

Use when decomposing oversized MAS June Swift files, source-guard tests, gateway helpers, bridge helpers, model catalogs, prompt/context builders, approval registries, or any June source-quality pass that must reduce file size and spaghetti without changing behavior, capability truth, or App Store boundaries.

Source: `.claude/skills/june-source-decomposition/SKILL.md`

Next required use: the next June source-quality slice must use this skill before extracting gateway/bridge/test code, moving source guards, or adding new helper files that affect MAS June ownership boundaries.

### `june-skill-learning-loop`

Use when adding, auditing, or hardening MAS June user-skill learning: observing successful agent tool compositions, wiring `observe_composition`, drafting proposed skills through deterministic gates, synthesizing NightBrain review queues, and exposing only gate-passed read-only skills in June without auto-promotion or webview mutation authority.

Source: `.claude/skills/june-skill-learning-loop/SKILL.md`

Next required use: the next June user-skill or self-evolution slice must use this skill before changing `observe_composition`, `SkillDiscovery`, `skill_evolution_analysis`, `SkillEvolutionService`, `hermes_bridge_skills`, slash-skill invocation, or promotion-gate UI.

### `june-local-model-oom-guard`

Use when changing MAS June local model loading, GGUF/llama.cpp execution, Apple Foundation Models fallback, local prompt budgets, model picker behavior, or memory-pressure handling on constrained Macs.

Source: `.claude/skills/june-local-model-oom-guard/SKILL.md`

Next required use: the next local-lane or Prompt Forge context-budget slice must use this skill before touching local model selection, GGUF loading, memory-pressure unload, local thinking labels, or lower-context prompt assembly.
