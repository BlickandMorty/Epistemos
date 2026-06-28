# Goose Surface — Missing/Broken Features (2026-06-28 sweep)

Definitive feature-completeness gap list (owner: 100% Goose parity is THE Phase-0 gate). 64 controls assessed, 39 silently-broken/missing. Every fix is GOLDEN-RULE-safe (data live from Goose ACP). Root cause class: upstream UI controls whose REST @/api call (or model capability) was never grafted to ACP vanish silently.


## Model capabilities + Thinking/Reasoning Effort selector (SwitchModelModal)

- **[P1] Thinking Effort selector in SwitchModelModal (the entire `thinkingEffortControl` Select with Off/Low/Medium/High/Max). It is gated by `showThinkingControl = (modelReasoning === true)` and NEVER renders for any model because `modelReasoning` resolves to false/undefined for every model in the ACP build.**
  - depends_on: .research-clones/work/goose/ui/desktop/src/components/settings/models/subcomponents/SwitchModelModal.tsx:312-313 (modelReasoning/showThinkingControl) <- modelInterface.ts:126-140 fetchModelReasoning -> getProviderModelInfo (dead REST, no goose-serve route; see goose config_management.rs:981) and per-option reasoning from fetchModelsForProviders (modelInterface.ts:60-124)
  - acp_equivalent: _goose/unstable/providers/list (provider inventory carries per-model `reasoning` sourced live from the canonical registry: crates/goose/src/acp/server/providers.rs:32 + providers/inventory/mod.rs:1126) and _goose/unstable/providers/catalog/template (capabilities.reasoning: providers.rs:229). is_reasoning_model is computed live at goose-providers/src/model.rs:225.
  - fix: Surface reasoning live from the inventory/template instead of the empty catalog-surface known_models. Root cause is in two grafts below (model-dropdown reasoning + fetchModelReasoning); fix both so `reasoning===true` flows for claude/gemini-3/o-series. No new hardcoding — the reasoning flag is read 100% from Goose ACP.

- **[P1] Per-model `reasoning` capability on every entry in the SwitchModelModal model dropdown (drives auto-show of Thinking Effort and the modelObj.reasoning persisted on submit). Every option is created with reasoning=false.**
  - depends_on: stage-goose-web-ui.sh:761-768 listAcpProviderModels (graft) hardcodes `reasoning: false` because it calls providersSupportedModelsList_unstable; SwitchModelModal.tsx:544-550 maps option.reasoning = m.reasoning
  - acp_equivalent: PARTIAL/WRONG-METHOD: _goose/unstable/providers/supported-models/list returns `models: Vec<String>` only (custom_requests.rs:1350-1352) — no capability fields, so reasoning can never come from it. The correct live source is _goose/unstable/providers/list (ProviderInventoryModelDto.reasoning, providers.rs:27-34) which already carries reasoning + context_limit per model.
  - fix: Change listAcpProviderModels (or the fetchModelsForProviders ACP branch at stage 1798-1814) to read models from the provider INVENTORY (providersList_unstable -> known_models with reasoning) rather than the capability-less supported-models string list, OR merge reasoning from inventory into each option. The merge already exists (`inventoryModels.get(m.name)?.reasoning`) but inventoryModels is empty (see next item).

- **[P1] Persistence of the chosen Thinking Effort (read('GOOSE_THINKING_EFFORT') on open; upsert('GOOSE_THINKING_EFFORT', effort) on submit). The value is written to an in-memory JS Map and never reaches Goose, so it is lost on reload and the agent never applies it.**
  - depends_on: SwitchModelModal.tsx:330 (read) + :421 (upsert) -> ConfigContext read/upsert ACP branch -> stage-goose-web-ui.sh:628-631 GOOSE_THINKING_EFFORT is in localAcpConfigKeys -> stage:712-714 upsert only does localAcpConfigValues.set(); stage:677-678 read returns from the same in-memory map
  - acp_equivalent: _goose/unstable/preferences/save and _goose/unstable/preferences/read — these persist GOOSE_THINKING_EFFORT to the real Goose config (crates/goose/src/acp/server/config.rs:32-47 on_preferences_save, :138-148 PreferenceKey::GooseThinkingEffort -> config_key GOOSE_THINKING_EFFORT). Dispatched at custom_dispatch.rs:267-288.
  - fix: Route GOOSE_THINKING_EFFORT (and GOOSE_AUTO_COMPACT_THRESHOLD, VOICE_* which are in the same dead localAcpConfigKeys set) through preferencesSave_unstable/preferencesRead_unstable instead of the in-memory localAcpConfigValues map. The ThinkingEffort enum value (off/low/medium/high/max) is validated server-side (prepare_thinking_effort, config.rs:193-206), so no client hardcoding of the roster is needed.

- **[P1] Applying the selected Thinking Effort to the live session on model switch (handleSubmit builds modelObj.request_params.thinking_effort and calls changeModel). In the ACP path request_params is dropped — only the model id string is sent — so the agent's reasoning effort is never changed for the session.**
  - depends_on: SwitchModelModal.tsx:415-424 (request_params.thinking_effort + changeModel) -> ModelAndProviderContext changeModel ACP branch stage-goose-web-ui.sh:2166-2186 calls saveAcpSessionModel(sessionId, modelName) = setSessionConfigOption({configId:'model'}) and discards model.request_params (kept only on the dead REST branch :2179)
  - acp_equivalent: setSessionConfigOption with configId:'thinking_effort' -> agent.on_set_thinking_effort (crates/goose/src/acp/server/dispatch.rs:133-137). goose-serve already advertises this as a live ThoughtLevel select option gated on is_reasoning_model (response_builder.rs:296-326).
  - fix: In the changeModel ACP graft, after saveAcpSessionModel, also call setSessionConfigOption({sessionId, configId:'thinking_effort', value: effort}) when request_params.thinking_effort is present (and the model is reasoning-capable). This is the live, golden-rule-safe channel that actually drives the agent's extended thinking.

- **[P2] fetchModelReasoning fallback lookup (resolveSelectedModelReasoning) and the `inventoryModels` reasoning merge — both read getAcpProviders() known_models, which are empty for the configured provider.**
  - depends_on: stage-goose-web-ui.sh:1838-1842 (ACP model reasoning branch reads getAcpProviders().metadata.known_models) and stage:1804-1811 (inventoryModels from p.metadata.known_models) <- getAcpProvidersBase prefers the catalog SURFACE (stage:544-549) where setup-catalog providers are built with `known_models: []` (stage:251)
  - acp_equivalent: _goose/unstable/providers/list (inventory) populates known_models WITH reasoning via providerDetails()/modelInfo() (stage:221-238, 205-211); it is just not the default source returned by getAcpProvidersBase.
  - fix: In getAcpProvidersBase, prefer/merge the provider INVENTORY (which carries per-model reasoning) over the catalog setup-surface for is_configured providers, OR have fetchModelReasoning call listAcpProviders inventory directly. Result: known_models.find(model).reasoning returns the real canonical flag. Still 100% live from Goose.


## Extensions (settings page: list / enable-disable / add / remove / configure, plus per-session extension toggle and deeplink install)

- **[P1] Add/Configure a custom STDIO MCP extension that requires environment-variable secrets (e.g. an API key/token) — the Add Extension and Configure (edit) modal**
  - depends_on: src/components/settings/extensions/modal/ExtensionModal.tsx:247 storeSecret()->upsertConfig (raw @/api, src/api/sdk.gen.ts; NOT the grafted ConfigContext wrapper). Compounded by utils.ts:122 createExtensionConfig emitting only env_keys (drops values) and src/acp/extensions.ts:109 graft hardcoding `env: []`.
  - acp_equivalent: _goose/unstable/config/extensions/add ALREADY persists inline stdio env as secrets (extensions.rs:77 Config::set_secret_values from goose_extension_to_config secret_updates) — but the graft never sends the values
  - fix: GOLDEN-RULE-safe: (a) in stage-goose-web-ui.sh graft ExtensionModal.storeSecret to a success no-op under USE_ACP_CHAT (stop calling dead upsertConfig); (b) graft createExtensionConfig to carry env VALUES (an envs/name-value map) not just env_keys; (c) graft acp/extensions.ts stdio branch (line 109) to emit server.env = the env name/value pairs instead of env:[]. The live goose server then stores the secrets in its own secret store via set_secret_values. No rosters/keys hardcoded. Symptom today: user fills command + API key, clicks Add, nothing appears (onSubmit blocked by results.every(success) since storeSecret returns false), only console.error, no toast.

- **[P1] Add/Configure a custom STREAMABLE_HTTP MCP extension that requires a secret (e.g. Authorization: Bearer ${TOKEN} header backed by an env_key secret)**
  - depends_on: src/components/settings/extensions/modal/ExtensionModal.tsx:247 storeSecret()->upsertConfig (dead @/api). createExtensionConfig utils.ts:137 emits headers + env_keys only.
  - acp_equivalent: NONE — config/extensions/add's McpServer::Http branch (extensions.rs:285) takes only url+headers+env_keys, has no inline-env field, so it cannot persist the secret value; goose serve exposes no generic secret/config-upsert ACP method
  - fix: Two options, both keeping data live: (1) preferred upstream-server change — extend config/extensions/add's Http branch to accept inline env (mirror the Stdio set_secret_values path) so the graft can pass values; (2) if no server change, the streamable_http+secret case must be surfaced as unsupported in the staged modal (disable submit with an explicit message) rather than silently doing nothing. Do NOT hardcode secret storage in Swift/graft.

- **[P2] Deeplink 'Add to Goose' / one-click extension install from a goose://extension/... link (ExtensionInstallModal trust/confirm dialog)**
  - depends_on: src/components/ExtensionInstallModal.tsx:340 window.electron.on('add-extension', handler) — relies on the Electron main process delivering deeplink events; install itself uses ConfigContext addExtension via addExtensionFromDeepLink (ExtensionInstallModal.tsx:313)
  - acp_equivalent: config/extensions/add covers the install action, but the TRIGGER has no ACP equivalent — it is an OS URL-scheme event, not an ACP method. In Epistemos the shim wires `on` to a local in-page emitter (GooseWebBootShim.swift:503 onEvent) that never receives 'add-extension'.
  - fix: Register a goose:// (and Goose web 'Add to Goose') URL-scheme handler in Swift and have it call the page's emitEvent('add-extension', link) bridge so the existing ExtensionInstallModal flow runs (it then routes through the already-grafted addExtension/config-extensions-add). Manual add via the modal still works, so this is a convenience-install gap, not total breakage.


## Tools display (getTools) + agent Mode selector (auto/approve/smart_approve/chat) + tool permission settings. Verdict: the puzzle "8" badge and its dropdown (it is the ENABLED-EXTENSION count, not a tool count) and the runtime "approve this tool call?" prompt are LIVE via ACP and work. Everything else in this domain is dead: the Settings Mode selector writes to a browser-memory map that never reaches Goose and reads from a non-grafted readAllConfig (always shows 'auto'); the per-tool Permission modal cannot load tools (dead /agent/tools) and cannot save (dead /config/permissions); MCP-UI app tool definitions silently come back null. Critically, ALL three have live ACP equivalents the graft simply never wired (toolsList_unstable, setSessionConfigOption configId:'mode'/setSessionMode), except per-tool permission SAVE which goose serve exposes no ACP method for. Upstream UI clone: /Users/jojo/Downloads/Epistemos/.research-clones/work/goose/ui/desktop/src. Graft: /Users/jojo/Downloads/Epistemos/stage-goose-web-ui.sh.

- **[P1] Agent Mode selector (Settings > Chat > Mode: auto / approve / smart_approve / chat radio group). User picks an approval/safety mode; nothing reaches the agent and the radio always shows 'auto'.**
  - depends_on: WRITE: components/settings/mode/ModeSection.tsx:13 `upsert('GOOSE_MODE', newMode, false)` -> ConfigContext upsert -> staging graft upsertAcpProviderConfig -> 'GOOSE_MODE' is in localAcpConfigKeys (stage-goose-web-ui.sh:630) so it is stored ONLY in the in-memory localAcpConfigValues map, never sent to Goose. READ: ModeSection.tsx:22 `config.GOOSE_MODE`, where `config` is populated by the NON-grafted REST readAllConfig() (components/ConfigContext.tsx:59) which dies on goose serve -> config={} -> selector defaults to 'auto'.
  - acp_equivalent: client.setSessionConfigOption({sessionId, configId:'mode', value}) -> dispatch.rs:121 agent.on_set_mode; OR client.setSessionMode({sessionId, modeId}). Server advertises available + current modes via SessionModeState (response_builder.rs:190 build_mode_state). A working ACP path already exists at acp/sessions.ts:258 acpSetSessionMode and is invoked at session create (sessions.ts:86) but ONLY when fed by launcher deeplink (App.tsx:111 routeState.gooseMode); the normal new-chat path (Hub.tsx:97) and the Settings selector never feed it.
  - fix: Remove 'GOOSE_MODE' from localAcpConfigKeys in the graft. Re-point ModeSection read/write at the active ACP session's 'mode' config option: write via setSessionConfigOption({sessionId, configId:'mode', value}) (or acpSetSessionMode), read current mode from the session's advertised config options / SessionModeState.current_mode_id. Also pass the chosen mode from Hub.tsx createSession(sessionOptions) so new chats inherit it. All values stay live from Goose (build_mode_state enumerates GooseMode::VARIANTS); never hardcode the mode list.

- **[P1] Per-tool Permission settings list (PermissionModal): rows of tool name + description with Always allow / Ask before / Never allow dropdowns. Reached via Mode > Approve|Smart Approve gear (ModeSelectionItem.tsx:110 -> PermissionRulesModal) and PermissionSetting. Loading always shows the 'Failed to load tools' error panel.**
  - depends_on: components/settings/permission/PermissionModal.tsx:110 `getTools({query:{extension_name, session_id}})` -> REST GET /agent/tools (api/sdk.gen.ts:115). goose serve does not mount /agent/tools, so response.error sets loadError='fetch_failed' and the tool list never renders.
  - acp_equivalent: client.goose.toolsList_unstable({sessionId}) -> _goose/unstable/tools/list (acp-meta.json:14, server tools.rs:6 on_get_tools). Response tool objects already carry the optional `permission` field (custom_requests.rs:59), so current per-tool permission is readable live. Note: the ACP request takes only sessionId (no extension filter), so filter client-side by the `${extensionName}__` name prefix.
  - fix: Add an acp/tools.ts graft (mirroring acp/extensions.ts) exposing getAcpTools(sessionId) -> client.goose.toolsList_unstable({sessionId}); in stage-goose-web-ui.sh replace PermissionModal getTools (and toolsCache getTools) with it, filtering by extension prefix in JS. Surfaces the live tool roster + current permissions; no hardcoding.

- **[P1] Saving per-tool permission changes (the 'Save Changes' button in PermissionModal). User changes a tool to Always/Never allow and clicks Save; the modal closes as if saved but nothing persists and the agent's approval behavior is unchanged.**
  - depends_on: components/settings/permission/PermissionModal.tsx:159 `upsertPermissions({body})` -> REST POST /config/permissions (api/sdk.gen.ts:208). Not mounted by goose serve; response.error is only console.error'd then onClose() runs, so the failure is invisible. Backing store goose::config::PermissionManager (goose-server config_management.rs:1154) is reachable ONLY through this dead REST route.
  - acp_equivalent: NONE. The custom ACP method set (server/custom_dispatch.rs) exposes tools/list and tools/call but no permission upsert. preferences/provider-config saves exist but are not the PermissionManager store. So the save cannot be grafted today (read works, write does not).
  - fix: Golden-rule-safe options: (a) Preferred long-term: add an upstream custom ACP method e.g. _goose/unstable/permissions/upsert that calls PermissionManager::update_user_permission, then graft upsertPermissions onto it. (b) Until that lands: have the graft render the modal read-only (show live current permission from toolsList_unstable) and replace the Save button with an honest 'Per-tool permission editing is not yet available over ACP' notice, instead of a button that silently no-ops. Do not stub a fake local store.

- **[P2] Interactive MCP-UI app tool rendering (McpAppRenderer widgets from the 'apps'/MCP-UI extensions): the embedded tool UI needs the tool's input schema/description; it silently renders without its tool definition.**
  - depends_on: components/McpApps/toolsCache.ts:31 getCachedTools -> getTools(...) -> REST /agent/tools (sdk.gen.ts:115). On failure the cache returns null and McpAppRenderer.tsx:360 does `if (!tools) return`, leaving mcpTool null (no inputSchema/description).
  - acp_equivalent: client.goose.toolsList_unstable({sessionId}) (same as the Permission list read path).
  - fix: Re-point getCachedTools at the acp/tools.ts getAcpTools(sessionId) graft (toolsList_unstable), filtering to the extension by `${extensionName}__` name prefix. Shares the same graft as the Permission modal fix.


## Settings sections (App / Chat / Models / Auth) — every toggle/field and whether it reads/writes via grafted ACP, dead readAllConfig/upsert, or the in-memory localAcpConfigValues no-op map

- **[P1] Whole shared `config` object is dead. Every control that renders from ConfigContext `config` (the entire Chat→Security section, Chat→Default-Mode current-mode highlight, App→Configuration editor) shows hardcoded defaults forever and never reflects any saved value.**
  - depends_on: .research-clones/work/goose/ui/desktop/src/components/ConfigContext.tsx:59 (reloadConfig -> readAllConfig) and :170-171 (initialize -> readAllConfig) — readAllConfig is dead REST '@/api', NOT grafted by the staging script
  - acp_equivalent: NONE as a single call. goose serve has no read-all-config over ACP. Closest live sources: preferences/read (_goose/unstable/preferences/read), providers/config/read, defaults/read
  - fix: Replace readAllConfig() in reloadConfig()/initialize() with an ACP-backed aggregate: preferences/read for the allowlisted keys + providers/config/read for secret/configured state + defaults/read for provider/model, merged into `config`. Keys with no ACP source must stay ABSENT (not faked) so the GOLDEN RULE holds.

- **[P1] Models → Switch Model → Thinking Effort selector (off/low/medium/high/max). HEADLINE owner complaint. Hidden for most models, and when shown has no effect and does not persist.**
  - depends_on: .research-clones/work/goose/ui/desktop/src/components/settings/models/subcomponents/SwitchModelModal.tsx:313 (showThinkingControl = modelReasoning===true), :318 fetchModelReasoning, :419-421 (effort -> request_params + upsert GOOSE_THINKING_EFFORT). Reasoning capability: acp-schema.json:1391 ProviderInventoryModelDto.reasoning
  - acp_equivalent: providersList_unstable reasoning flag (live, IF inventory refreshed) + preferences/save key `gooseThinkingEffort` (acp-schema.json:2382) for persistence. fetchModelReasoning IS grafted (stage-goose-web-ui.sh:1833-1846), so the dead-REST getProviderModelInfo is no longer the cause.
  - fix: Two faults: (a) VISIBILITY — reasoning is only populated for inventory models from the canonical model DB; providers surfaced via the setup-catalog fallback get known_models:[] (stage:254) so reasoning is unknown and the control is hidden. Trigger providers/inventory/refresh and map reasoning live per model. (b) EFFECT+PERSIST — the chosen effort is written only to the in-memory GOOSE_THINKING_EFFORT map (stage:631) and is NEVER sent to goose: changeModel -> saveAcpProviderDefaults/saveAcpSessionModel transmit only provider/model and drop request_params (stage:849-871). Graft GOOSE_THINKING_EFFORT to preferences/save as `gooseThinkingEffort` (persist) and transmit thinking_effort through the ACP session model config so it reaches the agent.

- **[P2] Chat → Security: Enable Prompt Injection Detection, Detection Threshold, Command Injection ML toggle + endpoint + token, Prompt Injection ML toggle + model + endpoint + token (the entire SecurityToggle card, CONFIGURATION not gated — always shown)**
  - depends_on: .research-clones/work/goose/ui/desktop/src/components/settings/security/SecurityToggle.tsx:230-240 (all SECURITY_* read from dead `config`), :268-314 (8 upsert handlers)
  - acp_equivalent: NONE. All 8 SECURITY_* keys are routed to the in-memory localAcpConfigValues map (stage-goose-web-ui.sh:636-642). goose serve exposes no ACP method to read or persist SECURITY_* and never receives them.
  - fix: Every toggle/field here is doubly dead: display is always default (config={} from readAllConfig) and writes are in-memory-only no-ops with zero agent effect and no persistence. Honest fix: hide the entire Security section when USE_ACP_CHAT (it cannot function), or add a server-side ACP config surface. Do not leave it appearing operational.

- **[P2] Chat → Default Mode selector (auto / approve / chat / smart_approve …) — choosing a mode appears to work but the highlight always snaps back to 'auto' and the agent default never changes**
  - depends_on: .research-clones/work/goose/ui/desktop/src/components/settings/mode/ModeSection.tsx:13 (upsert GOOSE_MODE) and :22 (read config.GOOSE_MODE)
  - acp_equivalent: NONE for a global default. GOOSE_MODE is not in the preference allowlist (acp-schema.json:2379-2387) and is not a provider-config key; it is routed to the in-memory map (stage:630). The schema `mode` at acp-schema.json:511 is SessionSystemPromptMode (append/replace), not agent mode.
  - fix: Pass the chosen mode into ACP session creation per new session so it at least takes effect live per-session; persisting the global default requires goose to add a mode key to the PreferenceKey allowlist. Until then, surface that this is session-scoped rather than implying a persisted default.

- **[P2] Models → Reset Provider and Model button — clicking it reloads the window but does NOT clear the selected provider/model**
  - depends_on: .research-clones/work/goose/ui/desktop/src/components/settings/reset_provider/ResetProviderSection.tsx:28-29 (remove('GOOSE_PROVIDER'), remove('GOOSE_MODEL'))
  - acp_equivalent: defaults/save (_goose/unstable/defaults/save) could clear them
  - fix: removeAcpProviderConfig early-returns a no-op for both GOOSE_PROVIDER and GOOSE_MODEL (stage-goose-web-ui.sh:734-742); only window.location.reload() runs, so defaults persist and the reset does nothing. Route reset to defaultsSave_unstable with empty providerId/modelId (or a dedicated clear) so the defaults actually clear.

- **[P2] Chat → Dictation: Voice Dictation Provider dropdown (only 'Disabled' ever appears) and Preferred Microphone selector, plus the configured/not-configured status badges**
  - depends_on: .research-clones/work/goose/ui/desktop/src/components/settings/dictation/DictationSettings.tsx:97 (getDictationConfig dead REST), :105/:114/:119/:136 (voice_dictation_provider), :124/:142 (voice_dictation_preferred_mic)
  - acp_equivalent: dictation/config (_goose/unstable/dictation/config, acp-meta.json:379) for provider list/status; preferences/save keys voiceDictationProvider + voiceDictationPreferredMic (acp-schema.json:2383-2384) for persistence
  - fix: Two faults: (1) getDictationConfig is dead REST (not grafted) -> providerStatuses={} -> dropdown shows only 'Disabled' and no provider can be picked; graft it to dictation/config. (2) voice_dictation_provider / voice_dictation_preferred_mic are stuffed in the in-memory map (stage:643-644) even though persistent ACP preference keys exist with different names — graft them to preferences/save (voiceDictationProvider, voiceDictationPreferredMic) instead of localAcpConfigValues.

- **[P2] App → Configuration editor (ConfigSettings card, CONFIGURATION_ENABLED=true) — an editable key/value table for arbitrary goose config**
  - depends_on: .research-clones/work/goose/ui/desktop/src/components/settings/config/ConfigSettings.tsx:92 (config from readAllConfig), :140 (upsert(key) for arbitrary keys)
  - acp_equivalent: NONE (no generic config CRUD over ACP)
  - fix: config is always {} (dead readAllConfig) so the editor renders an empty list; and saving any non-provider/non-local key throws via providerForConfigKey. Hide ConfigSettings under USE_ACP_CHAT since goose serve exposes no generic config surface over ACP.

- **[P3] Chat → Default Mode → Conversation Limits → Max Turns input**
  - depends_on: .research-clones/work/goose/ui/desktop/src/components/settings/mode/ModeSection.tsx:30 (read GOOSE_MAX_TURNS) and :41 (upsert GOOSE_MAX_TURNS); UI in mode/ConversationLimitsDropdown.tsx
  - acp_equivalent: NONE. GOOSE_MAX_TURNS is in-memory only (stage:629); no global ACP config-save path. max_turns exists only as a per-recipe/session param (acp-schema.json:3077).
  - fix: Wire max_turns into ACP session-creation params for live effect; there is no global ACP persistence path, so the stored default does not survive restart.

- **[P3] Chat → Dictation: Add / Update / Remove API Key (for non-LLM dictation providers such as ElevenLabs / Deepgram)**
  - depends_on: .research-clones/work/goose/ui/desktop/src/components/settings/dictation/DictationSettings.tsx:154 (upsert(config_key, key, true)) and :166 (remove(config_key, true))
  - acp_equivalent: dictation/secret/save + dictation/secret/delete (acp-meta.json:384, :389)
  - fix: A dictation provider's config_key is not an LLM-provider config key, so upsert -> providerForConfigKey throws 'not available through Goose ACP' (stage:625) and rejects; handleSaveKey has no try/catch, so the Save silently fails with no user feedback. Graft these to dictation/secret/save and dictation/secret/delete.

- **[P3] App → Privacy → 'Anonymous usage data' telemetry toggle**
  - depends_on: .research-clones/work/goose/ui/desktop/src/components/settings/app/TelemetrySettings.tsx:60 (read) and :80 (upsert GOOSE_TELEMETRY_ENABLED)
  - acp_equivalent: NONE
  - fix: GOOSE_TELEMETRY_ENABLED is in-memory only (stage:632) with default 'false' — and because the default is the string 'false', read returns 'false' which Boolean() coerces to true, so the switch mis-displays as ON. No persistence and no agent effect. Either hide under ACP or, if kept, fix the string-default truthiness and accept it as cosmetic.

- **[P3] Auth → Delete stored provider secret (trash button next to each credential)**
  - depends_on: .research-clones/work/goose/ui/desktop/src/components/settings/auth/AuthSettingsSection.tsx:270 (renders only when secret.can_delete) and :159 (deleteProviderSecret dead REST)
  - acp_equivalent: providers/config/delete (acp-meta.json:149) — already grafted as deleteAcpProviderConfig
  - fix: listAcpProviderSecrets hardcodes can_delete:false on every secret (stage-goose-web-ui.sh:784), so the delete button never renders and the feature is unavailable from the Auth tab (the dead deleteProviderSecret is never reached). Derive can_delete from a real capability and route deletion to the already-grafted providers/config/delete.


## New Chat input area / chat composer controls (model+effort badge, directory picker, git worktrees, model-settings gear, attachments, cost/token display, mode toggle)

- **[P1] "Thinking Effort" effort selector in Change Model modal (SwitchModelModal.tsx:710 thinkingEffortControl, gated by showThinkingControl = modelReasoning===true at :313) — HIDDEN for most configured models**
  - depends_on: components/settings/models/subcomponents/SwitchModelModal.tsx:318 fetchModelReasoning -> components/settings/models/modelInterface.ts:126/132 getProviderModelInfo (dead @/api REST). Staging grafts it (stage-goose-web-ui.sh:1834-1845) to read getAcpProviders().known_models.reasoning
  - acp_equivalent: providersList_unstable — ProviderInventoryModelDto.reasoning (boolean|null) in crates/goose/acp-schema.json; live and populated by goose
  - fix: getAcpProviders (acp/providers.ts getAcpProvidersBase) uses the catalog/setup surface as PRIMARY, where setup-catalog providers carry known_models:[] (stage:252) and only the first-8 template providers carry capabilities.reasoning; providersList_unstable (which carries per-model reasoning) is only a catch-fallback that the happy path never reaches. Merge/overlay providersList_unstable inventory onto the configured providers so known_models.reasoning is populated, or make the grafted fetchModelReasoning call providersList_unstable directly for {provider,model}. All data live from goose.

- **[P1] Selecting an effort level (off/low/medium/high/max) in Change Model modal — the chosen effort never reaches goose serve, so it does not affect inference**
  - depends_on: components/settings/models/subcomponents/SwitchModelModal.tsx:421 upsert('GOOSE_THINKING_EFFORT', effort) + :416-419 changeModel request_params.thinking_effort. Staging puts GOOSE_THINKING_EFFORT in localAcpConfigKeys (stage-goose-web-ui.sh:631 -> in-memory JS map only) and saveAcpSessionModel (stage:863-866) sends only {configId:'model'}, dropping request_params
  - acp_equivalent: setSessionConfigOption configId 'thinking_effort' -> agent.on_set_thinking_effort (crates/goose/src/acp/server/dispatch.rs:133-138); EXISTS and is live
  - fix: Add saveAcpSessionThinkingEffort(sessionId,value) calling client.setSessionConfigOption({sessionId, configId:'thinking_effort', value}); remove GOOSE_THINKING_EFFORT from localAcpConfigKeys and route its read/write through that ACP option (read live current value from goose's build_config_update response). Golden-rule safe: live from goose.

- **[P1] Agent Mode toggle (auto / approve / chat / smart_approve) — setting it writes to browser memory only; goose serve never learns the mode and keeps running its default**
  - depends_on: ConfigContext read/upsert('GOOSE_MODE') (used by mode UI). Staging puts GOOSE_MODE in localAcpConfigKeys (stage-goose-web-ui.sh:630 -> in-memory JS map only); never sent to goose, lost on reload
  - acp_equivalent: setSessionConfigOption configId 'mode' -> agent.on_set_mode (crates/goose/src/acp/server/dispatch.rs:121-126), and SetSessionMode; EXISTS and is live
  - fix: Add saveAcpSessionMode(sessionId,value) calling client.setSessionConfigOption({sessionId, configId:'mode', value}); remove GOOSE_MODE from localAcpConfigKeys and route GOOSE_MODE read/write through it. Live from goose.

- **[P2] Context window indicator denominator "{used} / {limit}" + token-pressure alerts (ContextWindowIndicator.tsx via ChatInput tokenLimit) — wrong limit (falls back to hardcoded 128000) for any provider/model not in the first-8 catalog templates**
  - depends_on: components/ChatInput.tsx:611 fetchCanonicalModelInfo (Priority 2, dead @/api getCanonicalModelInfo) then :619-624 known_models.context_limit (Priority 3 via grafted getProviders). Setup-catalog providers have known_models:[] (stage:252) -> Priority 4 TOKEN_LIMIT_DEFAULT=128000 (ChatInput.tsx:84/631)
  - acp_equivalent: providersList_unstable — ProviderInventoryModelDto.contextLimit (crates/goose/acp-schema.json); live but not surfaced (same root cause as the reasoning gap)
  - fix: Same merge fix as the reasoning finding: surface providersList_unstable contextLimit into known_models in acp/providers.ts so ChatInput Priority 3 returns the real limit instead of falling to 128k. Live from goose.

- **[P3] "Local Model Settings" gear in the model dropdown (ModelsBottomBar.tsx:182-186, shown only when provider==='local') -> ModelSettingsPanel (sampling config, chat template, tool-calling mode)**
  - depends_on: components/settings/localInference/ModelSettingsPanel.tsx:6-8 getModelSettings / updateModelSettings / listBuiltinChatTemplates (dead @/api REST, not grafted)
  - acp_equivalent: NONE (no ACP local-inference settings method on goose serve)
  - fix: No ACP backing exists; hide the 'Local Model Settings' entry under USE_ACP_CHAT (the panel renders empty/non-functional today) rather than presenting dead controls. Re-expose only if goose adds an ACP method. Do not fake settings.


## Provider configuration & authentication (provider config modal OAuth/external-setup/model-validation, auth credential add/delete, custom-provider CRUD, getProviderModels)

- **[P1] "Sign in with {provider}" OAuth button in the Provider Configuration modal (the entire OAuth-login path for OAuth/device-code providers e.g. Tetrate, host_with_oauth_fallback, cli_auth)**
  - depends_on: .research-clones/work/goose/ui/desktop/src/components/settings/providers/modal/ProviderConfigurationModal.tsx:182 (hasOAuth = config_keys.some(k => k.oauth_flow))
  - acp_equivalent: providersConfigAuthenticate_unstable (click handler IS grafted via authenticateAcpProviderConfig, but the button never renders because oauth_flow is stripped)
  - fix: In the graft (stage-goose-web-ui.sh setupCatalogProviderDetails ~L240-258 / setupConfigKey ~L193-203) the catalog-surface builders hardcode oauth_flow:false (L199-200) and getAcpProvidersBase (acp/providers.ts ~L536-569) prefers the catalog surface over providersList_unstable inventory, which is the only source that preserves oauthFlow. The live setup-catalog response carries entry.setupMethod (ProviderSetupMethodDto = oauth_browser | oauth_device_code | host_with_oauth_fallback | cli_auth) plus supportsAuth/supportsAuthStatus, which the graft already types but never reads. Fix GOLDEN-RULE-safe: in setupCatalogProviderDetails map setupMethod -> a synthesized oauth_flow (oauth_browser/host_with_oauth_fallback/cli_auth) or device_code_flow (oauth_device_code) config key gated on supportsAuth; or merge oauthFlow/deviceCodeFlow from providersList_unstable inventory onto the catalog roster. Zero hardcoding — all from Goose's setupMethod.

- **[P1] Create custom provider — "Create Provider" submit in Add-custom-provider modal (OpenAI/Anthropic/Ollama-compatible) and onboarding provider selector**
  - depends_on: .research-clones/work/goose/ui/desktop/src/components/settings/providers/ProviderGrid.tsx:231 (createCustomProvider via dynamic import('../../../api')) and components/onboarding/ProviderSelector.tsx:130
  - acp_equivalent: providersCustomCreate_unstable
  - fix: Neither ProviderGrid.tsx nor ProviderSelector.tsx is touched by the staging script; both dynamically import the dead REST createCustomProvider, so the throwOnError reject is caught and surfaces only a generic "Failed to save provider" (CustomProviderForm submitError). Add a graft (USE_ACP_CHAT branch) routing handleCreateCustomProvider to client.goose.providersCustomCreate_unstable with the UpdateCustomProviderRequest body. Live from Goose.

- **[P1] Delete custom provider — "Delete Provider"/"Confirm Delete" in custom-provider modal AND "Remove Configuration" for Custom providers in ProviderConfigurationModal**
  - depends_on: .research-clones/work/goose/ui/desktop/src/components/settings/providers/ProviderGrid.tsx:177 and modal/ProviderConfigurationModal.tsx:329 (removeCustomProvider)
  - acp_equivalent: providersCustomDelete_unstable
  - fix: ProviderConfigurationModal graft early-returns to deleteAcpProviderConfig only for provider_type !== 'Custom' (stage-goose-web-ui.sh:1581); the Custom branch falls through to dead cleanupProviderCache + removeCustomProvider. In the modal removeCustomProvider has no throwOnError, so it silently no-ops and onClose() runs — the provider visually disappears then reappears on refresh (looks deleted but isn't). ProviderGrid.tsx path throws into a caught error. Graft both Custom delete paths to client.goose.providersCustomDelete_unstable. Live from Goose.

- **[P2] Device-code-flow hint ("a browser window will open and the verification code copied to your clipboard") under the sign-in button**
  - depends_on: .research-clones/work/goose/ui/desktop/src/components/settings/providers/modal/ProviderConfigurationModal.tsx:184,410 (hasDeviceCodeFlow = config_keys.some(k => k.device_code_flow))
  - acp_equivalent: providersConfigAuthenticate_unstable (same path; flag-only, no separate method)
  - fix: Same root cause/fix as the OAuth button: map setup-catalog setupMethod 'oauth_device_code' to device_code_flow:true (graft setupConfigKey hardcodes device_code_flow:false at stage-goose-web-ui.sh:200). Lives from Goose setupMethod.

- **[P2] "Sign in" / "Reauthorize" button per credential in Settings -> Provider Credentials (AuthSettingsSection)**
  - depends_on: .research-clones/work/goose/ui/desktop/src/components/settings/auth/AuthSettingsSection.tsx:250 (secret.can_configure && secret.configure_provider)
  - acp_equivalent: providersConfigAuthenticate_unstable (configureProviderOauth IS grafted to authenticateAcpProviderConfig in this file, but unreachable)
  - fix: acpProviderSecret (graft, stage-goose-web-ui.sh:785) sets can_configure = Boolean(key.oauth_flow || key.device_code_flow); both are false because the catalog surface strips them. Same setupMethod-driven oauth-flag fix re-enables this button. All live from Goose.

- **[P2] "Delete credential" (trash) button per credential in Settings -> Provider Credentials — there is NO way to delete an individual stored credential**
  - depends_on: .research-clones/work/goose/ui/desktop/src/components/settings/auth/AuthSettingsSection.tsx:270 (secret.can_delete) and :159 (deleteProviderSecret — still imported from dead REST '../../../api', never grafted)
  - acp_equivalent: providersConfigDelete_unstable (deletes the provider's config/secret); no per-key delete method, but provider-level delete exists
  - fix: Graft acpProviderSecret (stage-goose-web-ui.sh:784) hardcodes can_delete:false so the button never renders, and confirmDelete still calls the dead deleteProviderSecret. Set can_delete:true and graft confirmDelete to deleteAcpProviderConfig(secret.provider) -> client.goose.providersConfigDelete_unstable (secret.id already encodes acp_provider_config:{provider}:{key}, so the provider is recoverable). Live from Goose.

- **[P2] Edit/Update custom provider — "Update Provider" submit when editing an existing custom provider**
  - depends_on: .research-clones/work/goose/ui/desktop/src/components/settings/providers/ProviderGrid.tsx:156 (updateCustomProvider via dynamic import('../../../api'))
  - acp_equivalent: providersCustomUpdate_unstable
  - fix: ProviderGrid.tsx not staged; dead REST updateCustomProvider rejects -> caught as generic submit error. Graft handleUpdateCustomProvider to client.goose.providersCustomUpdate_unstable. Live from Goose.

- **[P2] Hugging Face token-free sign-in ("Sign in to use Hugging Face Inference Providers without manually entering an API token") rendered inside ProviderConfigurationModal**
  - depends_on: .research-clones/work/goose/ui/desktop/src/components/settings/auth/HuggingFaceSignInPrompt.tsx:73 (configureProviderOauth) and :54 (listProviderSecrets) — both dead REST
  - acp_equivalent: providersConfigAuthenticate_unstable (auth) + providersConfigStatus_unstable (signed-in check)
  - fix: HuggingFaceSignInPrompt.tsx is not touched by the staging script and still imports configureProviderOauth + listProviderSecrets from dead '../../../api'; sign-in click and the signed-in poll both fail into catch -> the prompt never confirms. Add a graft routing it to authenticateAcpProviderConfig('huggingface') and listAcpProviderSecrets/readAcpProviderConfigStatuses. Live from Goose.


## Recipes / Skills / Sessions / Scheduler / Apps pages — action buttons (create/run/edit/delete/import/export/schedule/share)

- **[P2] Sessions page: per-session 'Share' (Share2) button + 'Share Session' link modal (publishes an encrypted Nostr deeplink). Shown on every session row and always errors with toast 'Failed to share session'.**
  - depends_on: /Users/jojo/Downloads/Epistemos/.research-clones/work/goose/ui/desktop/src/components/sessions/SessionListView.tsx:621 (shareSessionNostr, import :37) — visibility gated by getTunnelStatus :458 and nostrEnabled default true :323
  - acp_equivalent: NONE — verified crates/goose/src/acp/server/custom_dispatch.rs registers no tunnel/nostr method (grep for nostr|tunnel under crates/goose/src/acp returns empty)
  - fix: Root cause: getTunnelStatus is dead REST; its `.catch(()=>{})` swallows the failure so the 'hide Nostr sharing when disabled' effect never fires, and nostrEnabled stays at its `useState(true)` default — leaving a dead control visible. Golden-rule-safe fix: default `nostrEnabled=false` (or call `setNostrEnabled(false)` in the getTunnelStatus catch). This honestly reflects that goose serve has no tunnel/share capability; no hardcoded data. The live, working session-share path is Export (acpExportSession) which remains.

- **[P2] Sessions page: 'Import Link' button + 'Import Nostr Session' dialog (paste encrypted share link to fetch/decrypt/import). Visible and errors on submit.**
  - depends_on: /Users/jojo/Downloads/Epistemos/.research-clones/work/goose/ui/desktop/src/components/sessions/SessionListView.tsx:673 (importSessionNostr, import :37) — visibility gated by nostrEnabled :323 / render :1006,:1148
  - acp_equivalent: NONE — no nostr/tunnel import method on goose serve (custom_dispatch.rs)
  - fix: Same nostrEnabled=false fix hides this dead control. NOTE the file-based 'Import' button (handleImportClick -> acpImportSession, ACP ImportSession custom_dispatch.rs:331) WORKS and is the live import path — only the Nostr *Link* variant is dead.

- **[P3] Sessions page: read-only session-history / transcript detail view (SessionHistoryView) and its 'Retry' button — loads a full session via getSession.**
  - depends_on: /Users/jojo/Downloads/Epistemos/.research-clones/work/goose/ui/desktop/src/components/sessions/SessionsView.tsx:35 (getSession, import :6) inside loadSessionDetails
  - acp_equivalent: load_session (acp/sessions.ts acpLoadSession) and GetSessionInfo (custom_dispatch.rs:499) — both exist on goose serve
  - fix: Graft loadSessionDetails to acpLoadSession/GetSessionInfo instead of REST getSession (it currently throws -> 'Failed to load' on the detail view). Low priority: largely vestigial because handleSelectSession (SessionsView.tsx:53) routes 'view session' to the 'pair' chat via ACP load_session, so the REST detail path is rarely reached.


---

## VERIFY-THEN-FIX reclassification (2026-06-28, Claude)

The 39-item sweep was source-analysis and **over-flagged**. Verifying each against
the live wiring + the authoritative goose crates + the @aaif/goose-sdk corrected it:

### Already working (do NOT touch — preserve the working path)
- **Extensions add/remove/enable/disable**: `ConfigContext.tsx` already routes these
  through the ACP helpers (`configExtensions{Add,Remove,SetEnabled}_unstable` via
  `acp/extensions.ts`). The live `/extensions` route test passes. NOT broken.

### Fixed + committed this session (live/typecheck-validated, re-staged, gate-tested)
- config-status overlay (+ cache), model capabilities + Thinking Effort visibility/apply,
  mode apply helper, in-chat switch, OAuth sign-in visibility, credential delete,
  Settings config-map reconstruction, Swift PATH/env CLI auto-detect, ready-by-default.

### Genuinely broken AND fixable — the SDK + server expose the methods (next batch)
Confirmed present in `_goose/unstable/*` (crates) AND `@aaif/goose-sdk`:
- **Thinking Effort cross-restart persistence**: route `GOOSE_THINKING_EFFORT` through
  `preferencesSave_unstable`/`preferencesRead_unstable` (PreferenceKey `GooseThinkingEffort`;
  Swift wire shape: `saveGoosePreferences(values:[GooseACPPreferenceValue])`). Same for
  `AutoCompactThreshold`, `VoiceDictationProvider`, `VoiceDictationPreferredMic`.
- **Custom-provider create/edit/delete**: graft `ProviderGrid.tsx` (dead REST
  `createCustomProvider`/`updateCustomProvider`) → `providersCustomCreate/Update/Delete_unstable`.
- **Tools / per-tool Permissions list**: `toolsList_unstable` exists; graft the dead
  `/agent/tools`. (Per-tool permission *save* still has no ACP method — confirm.)
- **Dictation provider/mic**: `dictationConfig_unstable` + `dictationModelsList_unstable`.
- **Agent Mode persistence/apply**: `saveAcpSessionMode` helper exists; wire ModeSection +
  chat toggle (per-session via setSessionConfigOption; pass mode into newSession).

### Likely inherent ACP-vs-Electron limits (document, do not graft away)
- Multi-window recipe launch (single WKWebView host), Nostr session share/import
  (gated off), per-tool permission *save* (no ACP method — verify).

**Method:** for each "fixable" item, graft the UI call to the live SDK method, typecheck,
re-stage, lock behind the strict gate test, and live-verify via the WebRoute/WebPrompt suite.
