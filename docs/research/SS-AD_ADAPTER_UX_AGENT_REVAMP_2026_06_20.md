# SS-AD — Adapter UX: select→apply→test, per-model + per-agent, with explanations (2026-06-20)

Owner (verbatim): *"as simple as you go to the settings and you could just select an adapter and place it on any
model or on the chat or safer since you want to interact with an agent… after I create the new agent revamp, you
can look at an agent, you can browse to adapters and you can apply adapters and you can test adapters out. Adapter
is gonna have explanations."* Builds DIRECTLY on SS-LS (the just-landed apply-gap). Cross-ref SS-XR (which adapter
types to surface), SS-AB (capability profiles).

## Key finding — Companions ARE the "agents," and the adapter field already exists but is DEAD-WIRED
- **`CompanionModel`** (`Models/Companion/CompanionModel.swift:20`) already declares **`var loraAdapterPath: String?`**
  (`:39`) + `personaPrompt` (`:50`), `agentModelRoutingID` (`:53`), tools/scope, meta-config (`:64-90`). Plumbed
  through `CompanionState` create API (`State/Companion/CompanionState.swift:59,78`) + `CompanionRosterEntry`
  (`:410,433`). **But `grep loraAdapterPath` shows it is NEVER read by the inference path** — `MLXInferenceService
  .applyActiveAdapterIfPresent` (`Engine/MLXInferenceService.swift:2041`) consults ONLY the global
  `AdapterRegistry.activeAdapterDirectoryOnDisk`. So a Companion's adapter never reaches generation today.
  → **Wiring `loraAdapterPath` into the apply step is the smallest change that delivers "apply an adapter to the
  agent"** on top of the SS-LS apply-gap.
- Agent builder = **`CompanionCreationFlow`** (`Views/Landing/Farm/CompanionCreationFlow.swift:9`): `modelStep`
  (`:354`, runtime picker `:361`), persona editor (`:344`), `advancedConfigSection` (`:476`). **No adapter step yet.**
  Roster surface = `LandingFarmView`.

## Adapter model + explanations (none today)
`AdapterRecord` (`KnowledgeFusion/Adapters/AdapterRegistry.swift:20-38`): id/name/type(`AdapterType` knowledge|style|
tool|kto `:13-18`)/adapterPath/metadataPath/sourceVault/createdAt/qualityScore/isActive/baseModel/loraRank/
parameterCount/trainingExamples. **No description/explanation field.** Richer source = `AdapterMetadata`
(`QLoRATrainer.swift:13`: type/rank/alpha/targetModules/lr/examples/iters/duration/base/quality). Registry has
`updateQualityScore` (`:151`) as the mutator template; atomic JSON (`:99-121`) → adding an optional field is a clean
additive migration. For HF/imported adapters, parse `adapter_config.json` per SS-XR's explanation-card schema
(method/rank/effective-scale/target_modules/base_model/task/license; GGUF degrades gracefully).

## Existing adapter UI + Settings seam
- `AdapterSelectorView` (`KnowledgeFusion/UI/AdapterSelectorView.swift:7`): a `Menu` over `vm.installedAdapters`,
  tap = `vm.activateAdapter`/`deactivateAdapter` (GLOBAL active-adapter toggle = the "apply to chat (safer)" path,
  ALREADY wired through to reload-on-activate via `.epistemosActiveAdaptersDidChange`).
- `TrainingHistoryView` (`KnowledgeFusion/UI/TrainingHistoryView.swift:6`): richest list; expandable details `:99-111`
  (Rank/Base/Source/Examples), context menu `:73-83`. **Natural home for the explanation block + "Apply to…/Test"
  actions.**
- Host: `Views/Settings/SettingsView.swift` `KnowledgeFusionDetailView` `:4967`; "Adapters" Section `:4988-4998`
  embeds `AdapterSelectorView()` `:4995` + `TrainingHistoryView()` `:4997`; VM = `KnowledgeFusionViewModel.shared`.

## Per-model binding ("apply this adapter to THIS model") — net-new
Today there is only ONE global active adapter; no `modelID→adapterID` map. Add one (mirror
`Engine/AdvertisedModelStore.swift` UserDefaults pattern); surface a per-row control in
`Views/Settings/ModelStackSettingsView.stackRow` (`:84`, keyed by model id); make `applyActiveAdapterIfPresent`
(`MLXInferenceService.swift:2041`) PREFER the per-model binding for the loading `modelID` (`:1958`) before the global
fallback.

## Test-adapter A/B (the pieces exist)
`generate(request:)` (`MLXInferenceService.swift:1608`), apply at cold load (`:2024/2041`) + reload-on-activate
(`reloadIfActiveAdapterChanged :2071`, `shouldReloadForAdapterChange :2060`, signal `.epistemosActiveAdaptersDidChange`
posted in `AdapterRegistry.setActive :147`). **Test flow:** generate(prompt) with no active adapter → `vm.activateAdapter`
→ reload → generate same prompt → show both side-by-side (Msty split-compare pattern, SS-XR). Keep the in-code
PENDING-OWNER-VERIFICATION caveat (`:2038`) in the UI until an on-device A/B is witnessed.

## Ordered build steps (builds on SS-LS; each test-backed, cargo --lib + single swift build; NO vault writes)
1. **[S] Explanations:** add `description: String?` to `AdapterRecord` (`AdapterRegistry.swift:20`) + `updateDescription`
   mutator (mirror `:151`); auto-seed at registration (`KnowledgeFusionViewModel.swift:363`) from `AdapterMetadata`;
   render in `TrainingHistoryView` expanded details (`:99`). + an `adapter_config.json` parser for imported adapters
   (SS-XR card schema).
2. **[S] Settings "apply to chat (safer)":** relabel/expose the existing `AdapterSelectorView`→`activateAdapter` path
   as the safe global apply in the Adapters section (`SettingsView.swift:4988`). (Already wired end-to-end.)
3. **[M] Per-agent adapter (highest leverage):** add an adapter picker to `CompanionCreationFlow.advancedConfigSection`
   (`:476`) writing `CompanionModel.loraAdapterPath` (`:39`); then WIRE that field into `applyActiveAdapterIfPresent`
   (`:2041`) so the foregrounded Companion's adapter is applied (today it's unread). Validate adapter↔base match in
   the picker (SS-XR: must match training base). Guarded so no-companion/no-adapter = unchanged path.
4. **[M] Per-model binding:** `modelID→adapterID` store + `ModelStackSettingsView.stackRow` control + prefer-per-model
   in the apply step.
5. **[M] Test-adapter A/B:** a "Test adapter" affordance (TrainingHistoryView + agent detail) running generate twice
   across activate/deactivate, side-by-side; PENDING-OWNER copy until witnessed.
6. **[S→M] Agent-revamp browse/apply/test panel:** per-agent detail surface in `LandingFarmView` + a scale slider
   (SS-XR llama.cpp/MLX hot-swap pattern) + the explanation card. Pixel-art native.

**Differentiator (SS-XR):** almost NO local desktop GUI lets a user attach a LoRA to a base model in-UI — doing this
(declarative base+adapter binding à la Ollama Modelfile + live scale slider + test-before-save) is a real edge.
Key files: `Models/Companion/CompanionModel.swift:39` · `Views/Landing/Farm/CompanionCreationFlow.swift:476` ·
`KnowledgeFusion/Adapters/AdapterRegistry.swift:20,151` · `KnowledgeFusion/UI/{AdapterSelectorView,TrainingHistoryView}.swift`
· `Views/Settings/{SettingsView.swift:4988,ModelStackSettingsView.swift:84}` · `Engine/MLXInferenceService.swift:2041`
· `Engine/AdvertisedModelStore.swift`. Cross-ref SS-LS, SS-XR, SS-AB.
