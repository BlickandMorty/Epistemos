# Act IP Preservation — what Act does, end to end (2026-06-24)

> Owner's **most important** guardrail for the architecture pivot (memory `project_architecture_decision_2026_06_24`):
> before Act is hidden/replaced or Osaurus is removed, EVERYTHING Act does must be saved so the IP is not lost.
> This is the canonical capture of the Act capability + its wiring as of commit `e739bc9bf`. The `NativeSwiftActEngine`
> replacement must reproduce every numbered behavior below. Nothing here is deleted until the native engine matches it.

## 1. UI surface (KEEP — not changing)
- `Epistemos/Views/Chat/ChatView.swift` — ChatView 2, mounted for Act with `actUsesOsaurus: true`,
  `availableOperatingModesOverride: [.agent]`, `composerMode: .osaurusAct`, `showsToolbarControls: false`.
- Toolbar (RootView act ControlGroup): History · **Context-panel toggle** (sidebar.right, `mainChat.showBrainPanel`) · Settings · Mini-chat · Export. Back chevron + principal title gated to act mode (`showingActChatSurface` requires `WorkspaceModeSelection.current()==.act`).
- Right **context/brain panel** (`ChatBrainPanelView`) with in-panel ✕ close; ROUTING/REQUEST/EVIDENCE sections from `latestBrainSnapshot`.
- Composer: `ChatInputBar` (`.osaurusAct`) — Configuration gear, model picker, tool count, stats chip (`ActGenerationStatsChip`).

## 2. Send flow (the engine path to reproduce)
`ChatInputBar.onSubmit` → `ChatView.submitMainChatQuery` → (if `actUsesOsaurus && LocalAgentLoop.shouldRouteActThroughOsaurus()`) → **`ChatState.runActOsaurusTurn(query)`** (ChatState.swift:733). Steps:
1. Appends the user `ChatMessage` directly to `messages` (NOT `submitQuery` — avoids the deprecated ChatCoordinator "Standard Chat" + 38-tool pipeline).
2. Captures an **"Act · Osaurus"** brain snapshot (routeLabel/providerLabel) so the panel reflects the real engine.
3. Sets `isStreaming=true`, clears `streamingText`, cancels any prior `actTurnTask`.
4. Drives **`SharedActInference.actEventStreamIfArmed(prompt, systemPrompt:nil, maxTokens:2048, reasoningMode:.thinking, modelID:)`**.
5. Consumes the event stream via the shared **`ActTurnStreamCore.consume(stream, sinks:)`** (the ONE shared core; mini/graph/note use it too): `.textDelta`→accumulate→`streamingText` (projected via `UserFacingModelOutput.finalVisibleText`), `.thinkingDelta`, `.toolStarted/.toolCompleted`→tool blocks, `.generationStats`→stats chip. Cancellation returns a partial.
6. Appends the final assistant `ChatMessage` via `appendLocalMessage`; persists to unified `SDChat` via `persistActTurn` → `ChatCoordinator.persistChatCompletion` (recent-chats).

## 3. Osaurus engine bridge (the part being REPLACED — capture its behavior)
`actEventStreamIfArmed` → factory → **`EpistemosOsaurusChatSessionBridge.streamTurnEvents(prompt, requestedModel, maxTokens)`** (OsaurusCore):
- **Config:** `ChatConfigurationStore.load()` — tools follow the owner's `ChatConfiguration` (no force-disable).
- **Agent selection (CRITICAL IP):** `Agent.defaultId` is Osaurus's CONFIG-ONLY agent (refuses general chat). Act uses `AgentManager.shared.activeAgentId`, or — if that IS the config default — the first non-default agent (a general assistant). **The native engine must use a GENERAL assistant agent/persona, never a config-only one.**
- **Session:** `ChatSession()` with `agentId = actAgentId`, `selectedModel = requestedModel ?? chatCfg.coreModelIdentifier`, `suppressesPersistence = true` (Epistemos owns persistence).
- **Driver:** `EpistemosOsaurusHeadlessChatSessionDriver.run()`: `await SandboxToolRegistrar.shared.registerTools(for: agentId)` (makes tools runnable) **then** `session.send(prompt)`; polls until `!isRunActive && !isStreaming && promptQueue.current == nil` (the empty-stream-race guard — gate completion on run finalized, not just streaming).
- **Events emitted:** thinking deltas, visible assistant deltas, tool start/complete (with tool-error detection), generation stats (TTFT/tps/token count). Secret-prompt + clarify-prompt presenters (`installNativeSecretPromptPresenter`/`installNativeClarifyPromptPresenter`) for API keys / disambiguation.

## 4. Capabilities the native engine MUST reproduce
- General-assistant chat (not config-only), local MLX + cloud models, `.thinking`/`.agent` modes.
- Tool execution (the owner's ChatConfiguration tool set), registered-before-send so calls actually run (no `tool_not_found`).
- Streaming: token deltas, thinking trace, tool-use/result blocks, generation stats.
- Vault/skills context, permissions (secret/clarify prompts), model selection from config.
- Unified persistence to `SDChat` recent-chats; brain-snapshot routing transparency.

## 5. Model-management capabilities to RE-HOME (keep, not Osaurus-bound)
HF marketplace (model search/download), agent creation, themes/animations — currently via the reskinned Osaurus `ManagementView` (`EpistemosOsaurusManagementBridge.showActSettings()`). Harvest the HF model search/download + `ModelManager` logic into native Epistemos services + native settings before the final Osaurus removal.

## 6. Removal preconditions (do NOT remove Osaurus until ALL true)
- [ ] `NativeSwiftActEngine` reproduces §2–§4 (verified send/stream/tools/persistence).
- [ ] HF marketplace/model-mgmt/agent-creation re-homed natively (§5).
- [ ] This doc reconciled against the final native implementation.
