# SS-D — Settings integration: one coherent settings model (2026-06-19)

Read-only research (subagent), code-grounded. Feeds the settings-INTEGRATION items. Owner: *"make setup +
persistence in settings more simple + user-friendly; get rid of complexity for equivalent with more simplicity;
one coherent model."* Balance: integrate, never new scattered sections; each setting in exactly one home; shared
state not duplicated. Cross-refs SS-A/B/C/F/AB.

## Headline
The settings model is **HALF-INTEGRATED.** The IA *skeleton* is already coherent + modern — one `SettingsSection`
enum, one `safeDetailSelection` MAS-firewall/deep-link router, a 6-category rollup, three legacy agent rows
already consolidated under `.agent`. But the *content* is scattered: state lives across `EpistemosConfig`
(@AppStorage) + `InferenceState` + `AgentCommandCenterState` + `AgentAuthorityStore` + per-view `@State` with ≥1
confirmed duplicate (Night Brain), Models split across 4 sections, MCP/tools across 3 surfaces, ~46 health rows
across 3 diagnostics homes. **The fix is consolidation INTO the existing skeleton, not new sections.**

## Settings IA / navigation skeleton
- Two enums, one switch: `SettingsCategory` (6) `SettingsView.swift:76-102`; `SettingsSection` (19) `:104-140`;
  sidebar grouping `section.category :223-252`; `visibleSections :146-179` (MAS strips via `#if`).
- Flow: `NavigationSplitView :388-395` → `sidebarSections(in:) :445-447` → `@State selection :50` → `settings
  Detail :458-502`.
- **MAS firewall + deep-link routing = SINGLE chokepoint:** `safeDetailSelection(for:) :181-194` (collapses
  MAS-forbidden → `.general`, agent rows → `.authority`); runs on the switch `:460`, `.onAppear :404`,
  `.onChange(selection) :407-411`, search `:451`. **Everything must pass through this seam.**
- Deep links: notification-driven (`.showIMessageDriverSettings :397-400`); legacy agent deep-links =
  hidden `.agentControl/.authority/.overseer :114-122` → `AgentSectionDetailView` with `initialTab :484-491`.

## State duplication / drift points
- **Night Brain — confirmed double-WRITE (SS-B):** same `config.nightBrainEnabled` key (`EpistemosConfig.swift
  :27`) toggled in TWO detail views — Cognitive `CognitiveSettingsSection.swift:42` + Model Vaults custom binding
  `ModelVaultsSettingsView.swift:153-157`. One key (can't drift) but TWO homes for one concern.
- **Model selection rendered twice (selection vs status):** advertised-model visibility owned by
  `AdvertisedModelStore` (file-backed UserDefaults), read by the picker `InferenceState.swift:4144-4151` AND the
  Settings stack toggle (`ModelStackSettingsView` `store = AdvertisedModelStore()` + local `@State advertisedIDs`
  mirror because UserDefaults isn't `@Observable`). **The `@State` mirror is a DRIFT surface** — two
  `AdvertisedModelStore()` instances, no shared observable.
- **Tool/MCP toggles in 3 state owners:** in-chat `AgentCommandCenterState.toolToggles`/`disabledToolNames`
  (`AgentToolTogglePanel.swift:6-8`); blueprint reads `commandCenter.availableTools` + `MCPBridge`
  (`AgentBlueprintSettingsView.swift:7,196-220`); Agent section hosts Authority. 3 readers of overlapping state.
- **Authority is ALREADY CORRECT (the template to copy):** `AgentAuthorityStore` = `@MainActor @Observable`,
  file-backed, ONE shared instance owned `SettingsView.swift:58-65`, threaded into every agent sub-view
  (`AgentAuthority.swift:232-246`). The only fully-consolidated concern.

## One-home-per-setting violations
1. **Models across 4 sections:** `.cognitive`/`.inference`/`.modelVaults`/`.knowledgeFusion` all map to category
   `.models` (`:228-230`) — "Models" is a category LABEL, not a home. Plus model rows in `GeneralDetailView`
   ("Epistemos AI"/"Recommended Baseline"/"Optional Flagship" `:3216,3379-3406`). **ONE home:** a single Models
   detail backed by `ModelStackSettingsView` + foundation lineup.
2. **MCP & tools across 3 surfaces** (above). **ONE home:** consolidated "MCP & Tools"; in-chat panel = a thin
   projection of the same registry.
3. **Diagnostics across 3 homes (worst):** General "Diagnostics" ~12 rows (`:969-1011`) + `SubstrateHealthPanel`
   26 rows (`:31-143`) + Experimental "Feature Flags"/"Substrate Gates" (`:1398-1461`). ~46 rows, 3 homes.
   **ONE home:** Diagnostics under Advanced.
4. **Flags vs witnesses split (SS-F):** flag toggles (`:1398`) and their witness rows (`SubstrateHealthPanel`)
   in different sections — co-locate.

## The integration target (the coherent model, into the existing enum/switch — NO new sidebar entries)
- **(a) ONE Models home** — fold `.cognitive`(model bits)/`.inference`/`.modelVaults`/General "Epistemos AI" into
  one detail driven by `ModelStackSettingsView` reading the SS-AB `ModelCapabilityProfile` SOT; own + clone models
  render as profile rows. Absorber: `ModelStackSettingsView.swift`.
- **(b) ONE "MCP & Tools" home** absorbing AgentToolTogglePanel/AgentBlueprint tool cards over a single registry;
  in-chat panel = projection.
- **(c) ONE Diagnostics home** = `SubstrateHealthPanel` absorbing General `:969-1011` + Experimental gate rows;
  flags co-located with witnesses.
- **(d) "Engines" section** = per-engine cards (Chat/Act/Work/OpenClaw) via SS-A's curated-front + Advanced.
  **NOTE: no `EngineSettingsSection` type exists today (grep = 0 defs) — it's a PROPOSAL, must be created.**
- **(e) Privacy/Storage** = `.vault`+`.privacy`+`.provenance` already roll to `.privacyStore` (`:244-246`) — keep.
- **(f) Advanced/collapsed** = `.general`/`.substrateHealth`/`.experimentalFeatures`/`.heliosV5` (`:247-250`).
- **Clones + new features resolve INTO (a)-(f):** Osaurus/Goose/OpenClaw → Engine cards (d); MCP-install → (b);
  voice/browser/PDF/skills → feature rows under their owning engine card or Capture — **NEVER new sidebar
  sections** (enforce via the `safeDetailSelection` chokepoint). Existing absorbers: `ModelStackSettingsView`,
  `AuthoritySettingsView`, `SkillsSettingsView` (own `.skills` section — candidate to fold into Tools/Engines).

## Shared-state plumbing (single sources)
| Concern | Single source — exists? | Action |
|---|---|---|
| Permissions/authority | `AgentAuthorityStore` @Observable file-backed, one instance (`SettingsView.swift:58`) | **EXISTS, correct — the TEMPLATE** |
| Model config | `AdvertisedModelStore`+`ModelStackAssembler`+`EpistemosFoundationLineup` | Partial; scattered + `@State` mirror → consolidate into SS-AB `ModelCapabilityProfile` registry as `@Observable` SOT |
| Tool/MCP registry | `AgentCommandCenterState.toolToggles` + `MCPBridge` (3 readers) | Needs ONE `@Observable` MCP/tool registry |
| Skills | `VaultSyncService` + `SkillInventoryEntry` | One skills registry; fold UI into Tools/Engines |
| App settings | `EpistemosConfig` 22 @AppStorage keys (`:14-47`) | SOT exists; stop rendering same key in 2 views (Night Brain) |

## Ordered plan (integrate, never delete/scatter)
1. **[S] De-dupe Night Brain** — remove the toggle from `ModelVaultsSettingsView.swift:153-157`; keep the
   canonical Cognitive one (`:42`). Same key → zero data risk, pure home-collapse.
2. **[S] Single Diagnostics home** — move General `:969-1011` + Experimental gate rows into `SubstrateHealthPanel`;
   General keeps a "Open Diagnostics" link; co-locate flags with witnesses (SS-F).
3. **[M] One Models detail** — merge `.cognitive`(model)/`.inference`/`.modelVaults`/General "Epistemos AI" over
   the SS-AB profile registry; make `AdvertisedModelStore` a shared `@Observable` (kill the `@State advertisedIDs`
   mirror).
4. **[M] One MCP & Tools home** over a single `@Observable` tool/MCP registry; rewire `AgentToolTogglePanel` +
   `AgentBlueprint` `toolsCard` as projections.
5. **[L] Engines section** — build the SS-A `EngineSettingsSection` component (doesn't exist yet) as per-engine
   cards with curated-front + Advanced; route clone + new-feature settings here — never a new sidebar row
   (enforce via `safeDetailSelection`).

## Unverified
SS-A's `EngineSettingsSection` + SS-AB's `ModelCapabilityProfile` registry are PROPOSALS — neither exists as a
single type in code today (must be created). Did not exhaustively read every detail pane.

Key files: `Views/Settings/SettingsView.swift` (IA `:76-140`, `safeDetailSelection :181-194`, switch `:458-502`,
shared `AgentAuthorityStore :58-65`, General diagnostics `:969-1011`, model rows `:3216-3406`, flags `:1398-1461`)
· `SubstrateHealthPanel.swift:31-143` · `ModelStackSettingsView.swift` (AdvertisedModelStore + `@State` mirror) ·
`AuthoritySettingsView.swift` + `AgentHarness/AgentAuthority.swift:232-246` (**the correct template**) ·
`AgentSectionDetailView.swift:10-13` (consolidated rollup) · `Views/Chat/AgentToolTogglePanel.swift` +
`AgentBlueprintSettingsView.swift:7,196-220` (MCP scatter) · `State/EpistemosConfig.swift:14-47` +
`CognitiveSettingsSection.swift:42` + `ModelVaultsSettingsView.swift:153-157` (Night Brain double-home) ·
`SkillsSettingsView.swift`. Cross-refs SS-A/B/C/F/AB.
