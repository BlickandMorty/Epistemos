# SS-B — Simplify + harden Epistemos's OWN settings (2026-06-19)

Read-only research (subagent), code-grounded. Feeds SETTINGS_SIMPLIFICATION_HUB. Settings = **70
Swift files, ~23.5K lines; `SettingsView.swift` alone = 5,087 lines.** Balance: simplify presentation +
progressive-disclose, NEVER delete (collapsed-but-reachable ≠ hiding).

## Current IA (where it sprawls)
6 `SettingsCategory` → 19 `SettingsSection` (`SettingsView.swift:76-139`) + 4 hidden/legacy (agentControl/authority/overseer→rolled under .agent; heliosV5 frozen). Sprawl findings:
- **A. THREE diagnostics homes for ~46 health rows (#1 sprawl):** `SubstrateHealthPanel` (24 rows, 3 collapsible sections) + a SECOND parallel "Diagnostics" Section in `GeneralDetailView` (~13 more rows, `:969-1009`) + a 3rd inline cluster in `InferenceDetailView` (RuntimeRouterHealthRow/RuntimeLanesSection/cloud-access, `:1874`). The General comment admits the split is arbitrary. (= S7 D-7 "substrate ×4".)
- **B. Flag toggle ≠ witness row:** `ExperimentalFeaturesSettingsPanel` (`:1384`) toggles Eidos/VaultRecall/SystemG/ACS/FUlp/RRF — the SAME subsystems whose status rows live in `SubstrateHealthPanel`. Toggle and witness in two different sections.
- **C. "Models" is a label not a home:** picker in `InferenceDetailView:1758` but advertise-authority two levels down in `ModelStackSettingsView` nested in a `LocalModelManagerSheet` reachable only via a button; provider set re-rendered for selection (Inference) AND vault status (ModelVaults); **Night Brain toggle appears TWICE** (`CognitiveSettingsSection:42` + `ModelVaultsSettingsView:153`); `.cognitive` caption promises "reasoning/routing/temperature" but contains none (those are in InferenceDetailView).
- **D. MCP scattered across 3 components, NO in-app install form:** `AgentControlSettingsView` "MCP Tool Plane" + JSON Custom-Tools install + `AgentToolTogglePanel` (in Views/Chat, holds per-tool toggles + the only "MCP servers wired" view, reads `~/.config/mcp/url_servers.json` read-only). (Correction: `AgentBlueprintSettingsView` is NOT an MCP-install surface — S3 false positive.)
- **E. Orphans/demo-ish:** 2 orphaned health rows (0 refs): `CognitiveDagHealthRow`, `HyperdynamicLoopHealthRow`; `AgentBlueprintSettingsView` (682-line form) incongruously embedded in General's read-only Diagnostics; heliosV5 dead-but-reachable; FineTuneMarketplace/StructuredSurfaces demo-ish.
- Persistence: 48 `@AppStorage` + 10 raw `UserDefaults.set`; mostly honest but General mixes patterns (`showSaveOnQuit` uses a raw key).

## Simpler IA proposal (6 cats/19 sections → 5 cats/~10; keep the enum, change only visibleSections/category/composition — deep-links depend on `safeDetailSelection`)
- **General** (minus the Diagnostics block) · **Models** (ONE home: replaces Cognitive+Inference+ModelVaults+KnowledgeFusion; reasoning/routing as a "Defaults" group; ModelStack advertise promoted; vaults/fusion/finetune become disclosure groups) · **Engines** (NEW per-engine cards Chat/Act/Work/OpenClaw; absorbs the per-engine HealthRows scattered in Substrate Health) · **Automation/Pro** (Agent already consolidated; ADD ONE "MCP & Tools" home merging the 3 scattered MCP surfaces) · **Privacy & Storage** (unchanged) · **Advanced/collapsed** (Diagnostics + Experimental + Appearance).
- **ONE Diagnostics home for the ~46 rows** (progressive-disclosure ≠ hiding): merge the 2 parallel stacks into a `DiagnosticsPanel`, default-compact (mirror the proven `Section(isExpanded:)` collapsed pattern). Top: 3 at-a-glance rows always expanded (RuntimeTruth = "what's running", DeploymentProfile = MAS/Pro, a rolled-up substrate summary chip). Below: collapsed groups (Retrieval/Agent-Runtime/Substrate-Floor/Memory/KnowledgeCore/Cloud). Witness/WRV chips stay (just nested). Move `AgentBlueprintSettingsView` out → Agent. Mount the 2 orphan rows under a collapsed group (revive, don't delete).

## Robustness / automation / integration
- Route the lone raw `showSaveOnQuit` UserDefaults through typed `@AppStorage`; audit the 10 raw sites.
- **Co-locate each subsystem's TOGGLE with its WITNESS row** (Eidos toggle next to EidosHealthRow) — kills the "two homes for one concern"; chip stays orange until falsifier passes.
- Keep the MAS-honesty firewall (`safeDetailSelection` + `#if !(EPISTEMOS_APP_STORE||MAS_SANDBOX)` gates) intact — re-group via category/visibleSections only, never delete gate logic.
- **Automate/defaults:** make the "Epistemos AI" one-tap foundation install the DEFAULT Models view (catalog/advertise/legacy behind Advanced) — owner sees Fast/Think/Code not 3 catalog reps; advertised-set defaults to canon (status surfaced, toggles under disclosure); Diagnostics default-collapsed (never scroll 46 rows); experimental flags OFF, co-located with witnesses not a peer section.
- **INTEGRATION (one coherent model):** clone settings + new-feature settings resolve into the SAME 5 categories, never new sidebar sections — clone status→Engines cards; ALL model selection (own+clones)→ONE Models home; MCP install (own+OpenClaw+Osaurus+Goose)→ONE "MCP & Tools" home; permissions (own+Goose)→AuthoritySettingsView; skills/recipes/plugins→SkillsSettingsView; voice→a Models/General disclosure; logos/pixel-skin→AppearanceDetailView (reads theme.pixel, no new surface). Anti-muddy: each setting in EXACTLY one home.

## Ordered plan (never delete; collapse/disclose only)
1. Merge the 2 diagnostics homes → one `DiagnosticsPanel` default-compact (+ mount orphans). [M]
2. Co-locate flag toggles with witness rows. [S-M]
3. Collapse Models' 4 sections → 1 Models home; fix `.cognitive` caption mismatch; de-dup Night Brain. [L]
4. Promote the active-model picker + advertise-set out of the nested sheet. [M]
5. Add the "Engines" section; migrate per-engine HealthRows (gated on the Chat/Act/Work axis primitive, MASTER_SYNTHESIS #9). [M]
6. Consolidate MCP-install into one "MCP & Tools" home; move AgentBlueprint out of Diagnostics. [L]
7. Persistence hardening (typed @AppStorage for showSaveOnQuit + audit raw sites). [S]
8. Retire-or-mount orphans honestly (never silent-delete). [S]
Net: sidebar 19+→~10; the ~46 diagnostic rows go from 3 always-on stacks → ONE default-collapsed Diagnostics home, all one click away. Zero functionality removed.

Key files: `Views/Settings/SettingsView.swift` (IA :76-251, detail switch :458-502, General/Diagnostics :805-1018, Inference/Models :1505-2008+:3174-3427, Experimental :1384-1474) · `SubstrateHealthPanel.swift` (the collapsible pattern to generalize) · `ModelVaultsSettingsView.swift` · `ModelStackSettingsView.swift` · `CognitiveSettingsSection.swift` · `AgentSectionDetailView.swift` (consolidation template) · `AgentControlSettingsView.swift` + `Views/Chat/AgentToolTogglePanel.swift` (MCP merge) · orphans `CognitiveDagHealthRow.swift`, `HyperdynamicLoopHealthRow.swift`.
