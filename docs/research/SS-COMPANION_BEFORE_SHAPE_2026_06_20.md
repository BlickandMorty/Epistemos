# SS-COMPANION — BEFORE-shape inventory (IP-preservation baseline for the Osaurus refactor) (2026-06-20)

Owner (verbatim, voice): *"every feature… needs a before and after shape, so things like the companion — because I
am refactoring that by using fully [Osaurus] and then having a lot of my IP copy to Osa[urus] or move to our service.
I wanna make sure that none of it is lost."* This is the **BEFORE** baseline of the current Companion/agent system —
tick every item AFTER the refactor to confirm nothing was lost. The build-loop is SCOPE-BOUNDED OUT of these files
while the owner refactors them (see ledger). All file:line under `/Users/jojo/Downloads/Epistemos/`.

## Key files (the refactor surface)
- `Epistemos/Models/Companion/CompanionModel.swift` (SwiftData `@Model`, the persisted IP) + `CompanionAnimationState.swift`
- `Epistemos/State/Companion/CompanionState.swift` (CRUD/activate/projection) + `CompanionOutputSchemaValidation.swift`
- `Epistemos/Views/Landing/Farm/*` (CompanionCreationFlow, LandingFarmView, CompanionRoamingField, CompanionView,
  CompanionAvatarGlyph, CompanionDelete/RestoreSheet, NotesSidebarSkin, CompanionAdapterView=deferred scaffold)
- `Epistemos/LocalAgent/AgentBlueprint.swift` (routing contract)
- `Epistemos/ActOsaurus/{ActOsaurusBridge,ActOsaurusGateStatus}.swift` + `Views/Settings/ActOsaurusHealthRow.swift`
- `Epistemos/Engine/LocalModelServer.swift` (loopback :1337 OpenAI/Ollama server) + `Vendor/Osaurus/*` (MIT vendored)
- `agent_core/src/cognitive_dag/companions.rs` + `node.rs`/`edge.rs`/`migration.rs` (Rust DAG companion lifecycle)
- Wiring: `App/AppBootstrap.swift:1000,1762,2146-2164`, `App/ChatCoordinator.swift:169-176`,
  `Views/Landing/LandingView.swift:1949-1975`, `Engine/MLXInferenceService.swift:29-32,2028-2110`,
  `Models/EpistemosSchema.swift:15`

## IP-PRESERVATION CHECKLIST — tick each AFTER the Osaurus refactor (nothing may be lost)
**A. `CompanionModel` stored fields (23):** id(unique); name; tagline; bodyKindRaw (+ full `CompanionBodyKind` raw
codec incl. legacy/dotted/5-/9-part parsing); accentHex; identityHash (+FNV-1a `computeIdentityHash`); **loraAdapterPath**;
createdAt; lastInteractedAt; archivedAt (soft-delete); personaPrompt; agentModelRoutingID (+routingID codec);
agentModelDisplayName; agentToolNamesRaw (+dedupe/sort codec); agentScopeRaw; agentApprovalModeRaw;
customSystemPromptTemplate (full-override semantics); outputStructureJSON; mcpServerConfigJSON; memoryPinPattern;
toolSelectionModeRaw; autonomousExecConfigJSON; + `effectiveAgentSystemInstruction` precedence (custom override >
persona augment).
**B. Cosmetic body-grammar IP (Invariant I-10, functionally significant):** CompanionBodyFamily(block/sage/orb) +
creationPresets + 7 named presets; BlockAspect/LegStyle/AntennaStyle/EyeTreatment; HeadStyle/ArmStyle/EyeShape/
AccessoryStyle; ToolSelectionMode(manual/auto); per-bodyKind displayName + hint; CompanionAvatarGlyph renderer.
**C. `CompanionState` API + behavior:** attachModelContext; createCompanion(+activateOnCreate); updateCompanion(+identityHash
recompute); archive/restore/purge (soft→restore→hard); activate/deactivate/activeCompanionID; fetch(by:)/reloadRoster
(active+trashed recency sort); seedDefaultIfEmpty (Sage/Scout/Brick/Scribe presets); activeAgentSystemInstruction
(pipeline seam); activeAgentBrainSection; static agentSystemInstruction(for:) composition (output-contract + preferred-
tools + scope/approval binding); boundedPromptField caps (80/160/800/2000/600); CompanionRosterEntry full 20-field
projection.
**D. Creation/edit UI:** 5-step wizard (body / name+role+persona / model / contract / confirm); body grammar picker +
cosmetic chip rows + 8 color presets; model/runtime picker (Auto+brains, badges+footnotes); scope+approval segmented
pickers; tools grid (confirm/destructive markers); advancedConfigSection (system-prompt override + output-structure
JSON); CompanionOutputSchemaValidation save-gating; hydrateFromEditingEntryIfNeeded (edit round-trip); LandingFarmView
dock + CompanionRoamingField + delete/restore sheets + NotesSidebarSkin + deferred CompanionAdapterView.
**E. AgentBlueprint routing contract:** ModelChoice(auto/local/cloud/apple) + routingID + badges + executionPolicy +
cloudEscalation + strictGrammarStatus + grammarProfile; Scope(+missionInstruction); ApprovalMode(+missionInstruction);
AgentBlueprintBrainResolver.
**F. Inference wiring:** persona/custom-template → pipeline via `activeCompanionInstructionProvider` (AppBootstrap) +
`ChatCoordinator.appendActiveLandingAgentSystemInstruction`; agentModelChoice → `applyLandingAgentRuntimePreference`
(LandingView); loraAdapterPathOverride request field + applyActiveAdapterIfPresent + resolveActiveAdapterDirectory
(companion-precedence-over-registry) + reloadIfActiveAdapterChanged. **⚠ KNOWN GAP to preserve+complete, not drop:**
the producer hop `Companion.loraAdapterPath → request.loraAdapterPathOverride` is NOT connected (override only ever
nil); engine side is built+tested, live "tokens differ" is PENDING OWNER.
**G. Osaurus / Act seam (currently INERT, Pro-only `#if !EPISTEMOS_APP_STORE`, honest no-fallback — preserve seam +
gating):** ActOsaurusBridge protocol + ActOsaurusError; InertActOsaurusBridge (honest refuse); OsaurusActBridge (real
growth point: localServerEnabled/openAICompatibleEndpoint/runTurn, no silent cloud fallback); ActOsaurusBridgeFactory
flag resolve; ActOsaurusGateStatus (`EPISTEMOS_ACT_OSAURUS_V0`) + ActOsaurusHealthRow; LocalModelServer (loopback :1337,
/health//v1/models//api/tags//v1/chat/completions JSON+SSE, flag `EPISTEMOS_LOCAL_MODEL_SERVER_V0`); Vendored Osaurus
(ServerHealth, OsaurusChatMessage/OsaurusVendor, OsaurusVendorProvenance [osaurus-ai/osaurus, MIT, direct_import,
2026-06-19], OsaurusVendorLocalization).
**H. Rust cognitive-DAG companion lifecycle:** NodeKind::Companion{uas,anchor,plane,residency,profile,identity,persona};
ModelProfile/IdentityHash/PersonaBlob; EdgeKind::Deforms{lora_path,weight_alpha}+OwnedBy; CompanionRegistry(register/
lineage_for/companions_for_base/farm_memory_estimate_bytes)+CompanionLineage+CompanionError; make_base/lora_model_node;
budgets CREATE_BUDGET_MS=100/SWAP_BUDGET_MS=200; Companion DagMirror+CompanionMutation (migration.rs). NOTE: Swift
CompanionModel and Rust DAG Companion are NOT bridged over FFI today (separate IP tracks).
**I. Persistence:** EpistemosSchema.models includes CompanionModel.self; LIGHTWEIGHT additive-Optional migration posture
(no VersionedSchema — keep new fields Optional); LoRA blob layout `vault/.adapters/<companion-id>/lora.safetensors`;
activeCompanionID is in-memory only.

**Dormant-but-present (do NOT erase just because unwired):** loraAdapterPath not editable via updateCompanion + not fed
to inference; mcpServerConfigJSON / memoryPinPattern / toolSelectionMode / autonomousExecConfigJSON schema-present but
not consumed/settable; Swift↔Rust companion FFI bridge absent. These are baseline facts the refactor must carry forward.

## AFTER-shape (to fill in after the refactor)
After moving IP to Osaurus/the service, produce the matching AFTER inventory and diff against A–I above; every ticked
item must map to a surviving home (Osaurus, the service, or retained Swift). Flag any item with no after-home = LOST.
