# SS-C — Setup / onboarding flow (the "it just works" path) (2026-06-19)

Read-only research (subagent), code-grounded. Feeds the settings-simplification + SETUP/ONBOARDING items. Owner:
*"simplify setup + persistence for ALL the things I'm adding; more simple + user-friendly; reduce complexity for
equivalent with more simplicity."* Balance: simplify + automate defaults, NEVER delete/hide. Cross-refs SS-G
(model install), SS-A (clone setup), SS-F (persistence), SS-AB (model profiles), SS-B (settings IA).

## Headline
There IS a coherent first-run wizard (`SetupAssistantView`, 4 steps), honest + persistent. But it stops at
**vault + cloud key**; the **#1 blocker — a local model — is NOT installed in the flow** (the wizard punts to
"Open Settings → Inference"), and the one real auto-default already written (`FirstRunBootstrap.defaultVaultURL`
→ `~/Documents/Epistemos`) **is DEAD CODE, never invoked** (the wizard always asks for a vault via `NSOpenPanel`,
never offers the derived default). Biggest friction = local-model install is manual + off-flow; biggest quick
win = wire the existing one-tap `installEpistemosFoundationPackage()` + `defaultVaultURL` into the wizard.

## First-run flow today
- Gating: `App/EpistemosApp.swift:75-105,268-276`. Key `"epistemos.setupComplete"`; wizard sheet when
  `!setupComplete`; `markSetupComplete()` writes true.
- The wizard: `Views/Onboarding/SetupAssistantView.swift:8`. Steps `:333` — `.welcome→.vault→.model→.agentRuntime
  (cloud)→.done`; every step has **Skip**; persist `:298`.
- A SECOND cosmetic "setup" — `SetupView` (`RootView.swift:2654`, via `ui.needsSetup` overlay `:367`) = just a
  typewriter "Welcome" splash + "press to start" (`:2663,2689`), no config; fires only after a full DB/vault
  reset (`AppBootstrap.swift:3405`). **Two welcome surfaces with overlapping names = IA confusion** (SS-B).
- Post-setup re-prompt: `VaultReprompSheet` once per cold launch when `setupComplete && vaultURL==nil &&
  !hasEverConnectedAVault` (`EpistemosApp.swift:106-163`).

## Manual-config friction points
1. **Vault** — manual `NSOpenPanel` only (`SetupAssistantView.swift:318-328`); no "use default"; skippable → cold
   app + re-prompt loop.
2. **Local model (#1 blocker, SS-G)** — wizard does NOT install; if no model the button is "Open Settings →
   Inference" (`:202-204`). User must leave the wizard, find the foundation package, download. Off-flow.
3. **Cloud API keys** — step 4, `CloudProviderSetupCard` + provider picker (`:236-252`); → Keychain via
   `inference.setAPIKey`. Optional + clearly labeled. Good.
4. **Permissions (Accessibility/Screen/Automation/Speech)** — NOT in the wizard; handled lazily/on-demand in
   `Omega/OmegaPermissions.swift` (`refresh()` checks w/o prompting; `requestAutomationAccess()` prompts only
   when called; `:69 promptIfNeeded:false`). Already the correct lazy pattern — just undocumented to the user.
5. **MCP servers** — manual, Settings only.
6. **Engines (Act/Work/clones/capture)** — off by default, manual toggles (`State/EpistemosConfig.swift:14-43`,
   `capture.enabled=false` etc.). Correct default-off; no one-tap-enable surface.
7. **Voice/skills/browser/PDF** — Settings-only, no onboarding, no readiness status.

## Auto-config opportunities (derive-don't-ask)
- **Vault default ALREADY EXISTS but UNUSED:** `FirstRunBootstrap.defaultVaultURL()` → `~/Documents/Epistemos`
  (fallback `~/Epistemos`) + idempotent scaffold (`_inbox`/`daily`/`notes`) (`Vault/FirstRunBootstrap.swift
  :58-133`). **Zero non-test callers** — the wizard ignores it. [S]: add "Use Default Vault" calling this.
- **Model recommend-by-RAM ALREADY EXISTS:** `installEpistemosFoundationPackage()` installs Fast/Think/Code GGUF
  smallest→largest, SKIPPING models the hardware can't fit (`hardwareCapabilitySnapshot.supports(descriptor:)`,
  `LocalModelInfrastructure.swift:2701-2715`); `installRecommendedBaselineModels() :2683`; live memory gate
  `LocalChatModelMemoryGate` + `LocalInferenceMemoryPressureMonitor.availableMemoryBytes()`. RAM-tiered lineup
  `EpistemosFoundationLineup.candidates(for:)` sorted by `minimumRecommendedMemoryGB` (`:118-123`). **None
  reachable from the wizard.** [M]: wizard model step calls `installEpistemosFoundationPackage()` with progress.
- Router/embedding defaults declared (`defaultRouter` Qwen2.5-1.5B, `defaultEmbedding` BGE-small, `FirstRun
  Bootstrap.swift:212,253`) but download deferred — wire to background install.
- Permissions: lazy machinery already present (`OmegaPermissions`) — keep upfront-free, surface "grant when you
  first use computer-use/voice" inline.

## Per-feature setup pattern (the missing abstraction)
**No generic "feature ready / needs-setup / one-tap-enable" component exists** (no `FeatureReadiness`/
`OneTapEnable`/`SetupStatusRow` type). Closest reusable primitive = `Views/Shared/CloudProviderSetupCard.swift`
+ `CloudProviderSetupAutomation` (clipboard→Keychain→validate). The foundation-package install card
(`SettingsView.swift:3193-3362`) is bespoke. The SS-A pattern (auto-default plumbing + ~3-5 knobs + Advanced) is
realized for the model picker (`RootView.swift:578-603,1490-1505`, `simplifiedLineupActive`) but **not
generalized** into a reusable feature-setup card — that's the missing abstraction.

## Setup-state persistence (SS-F)
Honest + persistent: `"epistemos.setupComplete"` (`SetupAssistantView.swift:298`, `EpistemosApp.swift:274`,
reset `AppBootstrap.swift:3406`); re-prompt guards `"epistemos.hasEverConnectedAVault"` + `"epistemos.vault
Bookmark"`. Per-feature toggles persist via `@AppStorage`. **No silently-non-persisted setup found.** One smell:
`markSetupComplete()` fires even on plain sheet DISMISS (`EpistemosApp.swift:244-247`) — a swipe-away counts as
"done," so a dismissed wizard never re-shows.

## Ordered plan (the "it just works" path)
1. **[S]** Wire `FirstRunBootstrap.defaultVaultURL()` + `.bootstrap()` into `vaultStep` as a primary "Use Default
   Vault (~/Documents/Epistemos)" button; keep "Choose Folder" secondary. (Closes the dead-code gap.)
2. **[S]** In `modelStep`, replace "Open Settings → Inference" with an in-wizard **"Install Recommended AI"**
   button calling `localModelManager.installEpistemosFoundationPackage()` with the existing missing-count/progress
   UI (`SettingsView.swift:3248-3281`). (Pulls the #1 blocker into the flow; SS-G.)
3. **[M]** Extract a reusable `FeatureSetupCard`/`FeatureReadiness` (ready/needs-setup/disabled + one-tap action),
   generalizing `CloudProviderSetupCard`; adopt for model/vault/cloud/voice/MCP/browser/skills/clones (SS-A) —
   one pattern in onboarding AND Settings.
4. **[M]** Add explicit "Skipped" vs "Done" so a dismissed wizard re-offers (not `markSetupComplete()` on
   dismiss).
5. **[L]** Lazy permission prompts at point-of-use (Accessibility/Screen/Speech/Personal-Voice) via
   `OmegaPermissions` + an inline "why we need this" card; never upfront.
6. **[L]** Collapse the two welcome surfaces (`SetupView` splash vs `SetupAssistantView` wizard) into one (SS-B).

## Unverified
Per-feature setup for voice (SS-K/Q)/browser (SS-J)/PDF (SS-T) confirmed only as Settings-resident with no
onboarding/readiness hook; did not exhaustively read each feature's Settings pane.

Key files: `Views/Onboarding/SetupAssistantView.swift` (wizard; vault `:318`, model punt `:202`, persist `:298`)
· `App/EpistemosApp.swift:75-276` · `App/RootView.swift:367,2654` (cosmetic `SetupView`) · `Vault/FirstRun
Bootstrap.swift:58-133` (**unused** default-vault) · `Engine/LocalModelInfrastructure.swift:2683-2728` (one-tap
install, SS-G) · `Engine/EpistemosFoundationLineup.swift:99-160` (RAM-tiered, SS-AB) · `Views/Shared/Cloud
ProviderSetupCard.swift` (closest reusable card) · `Omega/OmegaPermissions.swift` (lazy permissions) ·
`State/EpistemosConfig.swift:14-43` (engine default-off, SS-F).
