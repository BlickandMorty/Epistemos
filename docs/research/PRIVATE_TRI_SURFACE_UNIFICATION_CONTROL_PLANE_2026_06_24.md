> ⛔ SUPERSEDED 2026-06-26 — Goose is the SINGLE surface. The 3-engine federation (Chat=AgentClone / Work=OpenGUI) described here is RETIRED. Canonical plan: `docs/research/SURFACE_EMBEDDING_WEBVIEW_VS_NATIVE_DECISION_2026_06_25.md` (§0, §15). Do not follow the federation / OpenGUI directives below.

# Private Tri-Surface Unification Control Plane - 2026-06-24

Status: private research ledger, not an agent handoff yet.

## Active Owner Correction - Isolation First

Newest correction, after the V3 fusion/package mapping:

- Do **not** fuse Goose into OpenGUI right now.
- Do **not** automatically make Goose/OpenGUI/Swift donor settings part of
  Epistemos Settings right now.
- Keep each donor's settings, runtime config, provider pages, extension pages,
  and advanced controls isolated in its own respective shell for now.
- Epistemos may still provide outer chrome, landing toggles, theme tokens,
  launch routing, window framing, visual reskinning, and health links, but it
  should not become the master settings database for these donors until the
  owner explicitly re-opens that work.
- Any future control-plane fusion must be staged as an optional bridge with
  read-back probes, not as the default implementation direction.
- Active sequencing: first recode/reskin each donor's own isolated UI into
  OpenCode-like minimalism, embed those isolated surfaces into the Epistemos
  home window, then later harden by selectively connecting individual settings
  and features back to Epistemos with explicit probes.

Literal owner shorthand:

```text
Current owner correction: each individual isolated UI should be coded to
OpenCode minimalism, then embedded in the Epistemos home window. The first
phase is not settings fusion and not a single merged app internals pass.
```

This overrides older "fuse settings into Epistemos" language in this document.
The older sections remain useful as research maps for a possible future
unification pass, but they are **not** current implementation instructions.
The current implementation bias is: full-clone/reskin/isolate first; embed in
the home window; connect later through explicit seams; avoid hidden capability
loss; postpone deep settings fusion.

Purpose: preserve the useful capability of Chat, Work, and Act as
full-donor-derived surfaces while pruning donor product identity, setup
clutter, duplicate settings, and foreign naming until they feel and behave like
one minimal Epistemos app. This doc is intentionally separate from the
implementation prompts so the strategy can mature before it is handed to other
agents.

## Current Owner Premise

Newest intent:

- Keep all three surfaces: Chat, Work, Act.
- Keep full clone/fork/reskin strategy for the major donors.
- Do not accidentally lose donor usefulness, hidden runtime hooks, or features
  that still matter to Epistemos.
- Do not make the app feel like a pile of separate products, but keep donor
  settings isolated for now. The current pass is not allowed to collapse Goose,
  OpenGUI, or Swift donor settings into one Epistemos Settings truth.
- Prune aggressively, but by classification: remove what Epistemos does not
  want, rebrand visible clone identity, simplify presentation, and preserve
  compatibility adapters where the donor runtime needs them. Do not prune by
  hiding a donor control before an equivalent isolated or advanced control
  still exists.
- Make Epistemos own the app shell, route choice, landing grammar, visual
  theme, and health/witness framing. Deeper ownership of settings, providers,
  sessions, permissions, marketplace, and tools is future research unless the
  owner explicitly asks to begin that fusion.
- Make first-run setup as automatic as possible: auto-detect, auto-install,
  auto-download, and preconfigure dependencies, tools, skills, MCP endpoints,
  and local runtimes where policy and user consent allow.
- Change user-facing MCP, endpoint, marketplace, tool, and provider language to
  Epistemos vocabulary. Keep donor/internal protocol names only behind
  compatibility aliases when renaming would break runtime behavior.
- All three surfaces should aim for the same Epistemos-native bar: minimal,
  flat, "code UI" inspired, deeply branded, and eventually connectable through
  selective bridges. For now, settings stay isolated inside each donor shell.
  Goose/Act keeps internal compatibility where its runtime requires it; it
  does not get a more conservative visual or product-identity exception.

Important drift note:

`docs/handoffs/CHAT_ACT_WORK_TRI_SURFACE_ENGINE_PLAN_2026_06_24.md` currently
contains older deletion-oriented language from a previous decision point. This
private research ledger treats the newer owner premise as the active research
target: preserve capability, not donor product identity. The eventual shared
plan update should replace vague "delete old surfaces" language with an
inventory-backed pruning policy: canonicalize, rebrand, fuse, automate, move to
advanced/debug, compatibility-alias, or remove with evidence.

Second drift note:

Sections V2 and V3 below explore a stronger future unification/control-plane
strategy. After the latest owner correction, they should be read as **later
architecture research**, not the current build directive. The current directive
is isolation-first: reskin and frame donors in Epistemos style while preserving
their own settings/configuration shells.

## Research Inputs Read In This Pass

Epistemos/canon:

- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- `docs/handoffs/CHAT_ACT_WORK_TRI_SURFACE_ENGINE_PLAN_2026_06_24.md`
- `docs/handoffs/RESEARCH_CLONES_CANON_RATIONALE_2026_06_24.md`
- `docs/handoffs/RESEARCH_CLONES_INVENTORY_2026_06_24.md`
- `docs/handoffs/WORK_INTEGRATION_SHAPE_RECOMMENDATION_2026_06_24.md`
- `docs/research/SETTINGS_SIMPLIFICATION_HUB_2026_06_19.md`
- `docs/research/SS-D_SETTINGS_INTEGRATION_2026_06_19.md`
- `docs/audits/SETTINGS_TRUTH_FLOOR_2026_05_25.md`
- `docs/research/ARCHITECTURE_UNIFICATION_SYSTEMG_2026_06_22.md`

Current Epistemos code anchors sampled:

- `Epistemos/Views/Settings/WorkCloneSettingsView.swift`
- `Epistemos/State/ThreadState.swift`
- `Epistemos/Models/ChatTypes.swift`
- `Epistemos/Work/WorkSessionRegistry.swift`
- `Epistemos/Work/WorkOpenGUIProvisioner.swift`
- `Epistemos/Work/WorkOpenWorkProvisioner.swift`
- `Epistemos/Engine/CloudProviderAuthService.swift`
- `Epistemos/Engine/Keychain.swift`
- `Epistemos/State/ModelProfileManager.swift`
- `Epistemos/Vault/AgentApprovalPolicyStore.swift`
- `Epistemos/Vault/AgentSessionLineageStore.swift`
- `Epistemos/Vault/SkillDiscoveryCatalog.swift`
- `Epistemos/Theme/EpistemosTheme.swift`

OpenGUI anchors sampled:

- `.research-clones/work/opengui/README.md`
- `.research-clones/work/opengui/docs/adr/0005-opengui-runtime-backend-split-and-sdk.md`
- `.research-clones/work/opengui/packages/runtime/README.md`
- `.research-clones/work/opengui/packages/protocol/src/harness-id.ts`
- `.research-clones/work/opengui/packages/protocol/src/capabilities.ts`
- `.research-clones/work/opengui/packages/protocol/src/queue.ts`
- `.research-clones/work/opengui/src/components/settings/SettingsView.tsx`
- `.research-clones/work/opengui/src/runtime/settings.ts`
- `.research-clones/work/opengui/src/hooks/agent-model-selection.ts`
- `.research-clones/work/opengui/src/lib/session-identity.ts`
- `.research-clones/work/opengui/server/harness-inventory.ts`
- `.research-clones/work/opengui/server/services/prompt-queue-service.ts`

Goose anchors sampled:

- `.research-clones/work/goose/README.md`
- `.research-clones/work/goose/ui/desktop/README.md`
- `.research-clones/work/goose/ui/sdk/README.md`
- `.research-clones/work/goose/ui/desktop/src/components/ConfigContext.tsx`
- `.research-clones/work/goose/ui/desktop/src/components/ModelAndProviderContext.tsx`
- `.research-clones/work/goose/ui/desktop/src/components/settings/SettingsView.tsx`
- `.research-clones/work/goose/ui/desktop/src/acp/*`
- `.research-clones/work/goose/crates/goose/src/config/*`
- `.research-clones/work/goose/crates/goose/src/providers/*`
- `.research-clones/work/goose/crates/goose/src/permission/*`
- `.research-clones/work/goose/crates/goose/src/recipe/*`
- `.research-clones/work/goose/crates/goose/src/session/*`

Swift Chat anchors sampled:

- `.research-clones/swift-act/agent-macos26/README.md`
- `.research-clones/swift-act/agent-macos26/Agent/Views/Settings/SettingsView.swift`
- `.research-clones/swift-act/agent-macos26/Agent/Services/LLMProviderSetup.swift`
- `.research-clones/swift-act/agent-macos26/Agent/MCP/*`
- `.research-clones/swift-act/swarm/README.md`
- `.research-clones/swift-act/swarm/Sources/Swarm/Core/SwarmConfiguration.swift`
- `.research-clones/swift-act/swarm/Sources/Swarm/Providers/DefaultInferenceProviderFactory.swift`
- `.research-clones/swift-act/mcp-swift-sdk/Sources/MCP/*`

## Central Finding

The right abstraction is not "one app shell with three embedded apps" and not
"rewrite every donor into one native codebase." It is also not "keep every
donor screen intact forever." The stable middle path is:

```text
Epistemos owns control planes.
Donors donate engines, protocols, workflows, and UI affordances.
Donor product identity gets removed, renamed, fused, or hidden.
Every donor feature becomes one of:
  1. a canonical Epistemos setting,
  2. a rebranded Epistemos UI/control,
  3. an automated first-run/default behavior,
  4. an advanced/debug control,
  5. a compatibility alias written through an Epistemos adapter, or
  6. a deliberately pruned feature with replacement/retirement evidence.
```

The failure mode to avoid is clone-local truth. If OpenGUI, Goose, and Chat
each own separate provider accounts, model defaults, recents, permissions,
MCP installs, and theme tokens, the app becomes three products. If Epistemos
owns those as typed control planes and the donors consume them through
adapters, the app can keep donor usefulness without feeling fragmented.

Equally important: do not let "native-feeling" drift into a full SwiftUI
rewrite of working donor systems. The owner wants these to remain their donor
apps/engines where that preserves reliability, but fused so deeply into
Epistemos identity, setup, settings, routing, and chrome that they no longer
feel like separate apps. Replace visible shells and duplicate control layers
only at proven seams; keep runtime protocols, event streams, worker processes,
ACP/REST bridges, config formats, and donor session mechanics intact unless a
specific replacement is verified end to end.

## Target Shape

```text
Landing
  Chat  -> Swift full-clone/fusion surface
  Work  -> OpenGUI full-clone/fusion surface
  Act   -> Goose full-clone/fusion surface

Shared Epistemos control planes
  Brand / vocabulary / naming
  First-run setup / installers / dependency health
  Identity / accounts / auth
  Provider and model registry
  Session and recents registry
  MCP / extension / skill marketplace registry
  Tool and permission policy
  Theme and visual language tokens
  Diagnostics / health / witness rows
  Sync / import / export / storage
```

Capability is preserved by default. Donor product identity is not. What changes
is authority: Epistemos becomes the source of truth and donor pages become
projections, mirrors, advanced/debug editors, or implementation details. The
normal user path should be minimal, preconfigured, Epistemos-branded, and ready
to use.

## Control Plane 0A - Brand, Vocabulary, And Endpoint Identity

Problem:

Each donor imports its own product ontology: OpenGUI harness language, Goose
provider/config language, Agent!/Swarm labels, donor MCP names, donor
marketplaces, donor setup words, and donor-specific endpoint names. If those
ship directly, the app reads as a bundle of projects instead of Epistemos.

Unification rule:

- Epistemos owns user-facing names.
- Donor/internal names survive only as compatibility aliases, protocol
  identifiers, import metadata, or debug labels.
- Renaming must be reversible and witnessed so runtime configs do not break.

Proposed shape:

```swift
struct EpistemosNameBinding: Codable, Identifiable {
    var id: String
    var epistemosName: String
    var userFacingKind: String      // provider, model, mcp, skill, tool, harness
    var donorNames: [String]
    var compatibilityAliases: [String]
    var rewritePolicy: RewritePolicy
    var runtimeSensitive: Bool
}
```

Required behavior:

- UI labels say Epistemos/Act/Work/Chat vocabulary, not donor product names,
  unless the donor name is itself a user-selected engine, provider, or source.
- MCP endpoints should appear as Epistemos MCP/tools/skills in the app.
- Compatibility config files may still contain donor keys if required, but the
  user should not manage those as the primary truth.
- Every rename has a fallback alias path and a health row proving the donor
  runtime still resolves it.

## Control Plane 0B - First-Run Setup, Installers, And Dependency Health

Problem:

Full clones often assume separate install flows: Node/pnpm, Rust binaries,
Goose extensions, OpenGUI harnesses, MCP servers, provider auth, local model
downloads, helper tools, and permissions. If each donor owns setup, users have
to initialize several apps inside one app.

Unification rule:

- Epistemos owns setup orchestration.
- Donor setup scripts become implementation steps behind one first-run flow.
- The app should start useful with minimal user action, then disclose missing
  dependencies only when needed.

Proposed shape:

```swift
struct EpistemosSetupUnit: Codable, Identifiable {
    var id: String
    var title: String
    var surfaces: Set<String>
    var dependencyKind: String      // binary, npmPackage, mcpServer, model, helper, permission
    var requiredForBasicUse: Bool
    var installPolicy: InstallPolicy
    var status: SetupStatus
    var repairActionID: String?
    var witnessID: String?
}
```

Required behavior:

- One setup hub verifies Node/pnpm/runtime assets, Goose binaries, OpenGUI
  assets, Swift helper capabilities, MCP servers, skills, tools, and local
  model paths.
- Auto-install/auto-download runs only where safe and owner-approved; otherwise
  it shows one Epistemos repair action.
- Donor-native installers are not exposed as separate setup journeys unless
  the owner opens Advanced/Debug.
- "Ready" means the capability can actually be invoked by Epistemos, not just
  that donor files exist on disk.

## Pruning Classifier

Every donor feature, file, screen, setting, endpoint, and label should be put
into one of these buckets before implementation agents cut code:

```text
Canonicalize:
  Make this an Epistemos control plane field or first-class UI.

Rebrand:
  Keep the behavior, replace donor-facing language with Epistemos language.

Fuse:
  Merge duplicate donor controls into one Epistemos setting or registry row.

Automate:
  Remove from default UI because Epistemos can preconfigure or repair it.

Advanced:
  Keep reachable for expert/runtime-specific control, but not in the main path.

Debug/Witness:
  Keep read-only or diagnostic because it proves integration health.

Compatibility Alias:
  Keep donor config/protocol keys internally, but wrap them behind Epistemos.

Remove:
  Delete from the product only after documenting why Epistemos does not want it,
  what replaces it, and how runtime compatibility is protected.
```

This is the practical meaning of "minimal but intact": not everything remains
visible, and not every donor product concept survives, but no useful capability
disappears by accident.

## Initial Evidence Map From Donor Code

This pass found concrete levers that make the Epistemos-branded/full-clone
strategy more practical than a pure rewrite.

### Goose / Act Evidence

`CUSTOM_DISTROS.md` is especially important. Goose explicitly documents custom
distributions/white-labeling, including:

- preconfigured providers through `config.yaml`, `init-config.yaml`, and
  environment variables;
- bundled MCP extensions through config and built-in extension catalogs;
- desktop branding through `ui/desktop`, package metadata, product names,
  colors, and release artifact naming;
- `GOOSE_BUNDLE_NAME`, `GITHUB_OWNER`, and `GITHUB_REPO` for rebranded builds
  and updater lookup;
- REST API and ACP integration modes for custom frontends;
- declarative provider JSON for custom OpenAI/Anthropic/Ollama-compatible
  endpoints;
- recipes and sub-recipes for standardized workflows with minimal user setup.

Implication:

Goose is not just a black-box donor. It has documented distribution hooks that
fit Epistemos pruning:

```text
Goose capability -> keep
Goose app identity -> rebrand/prune
Goose config keys -> compatibility aliases
Goose extension catalog -> Epistemos capability packages
Goose recipes -> Epistemos workflows/skills
Goose REST/ACP -> Act bridge options
```

The owner correction fits this perfectly: Goose's custom distribution hooks
should be used to make Act feel as Epistemos-native as Work and Chat. Goose may
retain internal runtime structure, config keys, REST/ACP, and extension ids
behind the bridge, but the visible shell should be a rebranded, minimal
Epistemos Act surface, not stock Goose embedded inside Epistemos.

### OpenGUI / Work Evidence

OpenGUI's settings surface currently exposes `General`, `Providers`,
`Plugins`, and `Tools/MCP` tabs through its own React UI. Its ADR 0005 makes a
cleaner integration point: Runtime, Backend, and Frontend are separated.

Key ADR facts sampled:

- Runtime is the in-process engine for harness adapters, normalized harness
  events, harness inventory, and directory-scoped sends.
- Backend adds queue, HTTP/WebSocket/SSE, token auth, and shared-session
  concerns.
- Frontend owns presentation metadata.
- Backend project/workspace CRUD is being removed in favor of harness scope and
  directory on each operation.
- SDK v1 is `@opengui/runtime` and intentionally in-process.

Implication:

Work should not simply iframe stock OpenGUI forever. The strong path is:

```text
OpenGUI Runtime/Backend -> keep as Work engine
OpenGUI Frontend -> full-clone/reskin only where it gives useful Work UX
OpenGUI settings tabs -> fuse into Epistemos Settings
OpenGUI provider/plugin/MCP state -> canonical Epistemos registries
OpenGUI queue/harness events -> Epistemos session/runtime witness rows
```

OpenGUI is therefore the best Work donor when the goal is multiple coding
harnesses and queue/workspace behavior, but its UI/state cannot be allowed to
remain the authority.

### Swift Chat / Agent! + Swarm Evidence

Agent!'s `SettingsView.swift` shows exactly why Chat needs deep fusion: it has
many provider-specific fields, keys, models, fetch buttons, temperatures, and
provider-specific instructions. `LLMProviderSetup.swift` centralizes provider
configs, endpoints, and capability flags for Claude, Codex, OpenAI, Gemini,
Grok, Mistral, Codestral, DeepSeek, Hugging Face, MiniMax, Z.ai, BigModel,
Qwen, OpenRouter, Ollama, vLLM, LM Studio, and Apple Intelligence.

Swarm gives a cleaner unification point:

- one default provider;
- one higher-priority cloud provider for tool-calling flows;
- one web-search configuration;
- a provider resolution order that can be fed from Epistemos.

Implication:

Chat should be the deepest Epistemos-native fusion:

```text
Agent! provider catalog -> harvest capability metadata
Agent! Settings UI -> prune/wrap/reskin into Epistemos-native Settings
Swarm.configure(...) -> receive Epistemos-selected provider/model/web config
Agent!/Swarm names -> source/debug only
Chat UI -> Epistemos owns the whole visible surface
```

This is the place where "as native as possible" should be strongest, because
the donor is Swift-native enough for visible controls to be simplified in the
Epistemos style without crossing a Web/Electron bridge. That still does not
mean rewriting working provider, streaming, MCP, or agent runtime internals
unless the replacement seam is proven.

### First Classification Pass

```text
Surface       Keep                              Fuse/Rebrand                         Prune/Hide
Chat          Agent!/Swarm provider/tool logic  Epistemos Settings + model picker     Agent! app identity, duplicate setup
Work          OpenGUI runtime/harness/queue     Epistemos Work settings/capabilities  stock OpenGUI settings as primary UI
Act           Goose engine/extensions/recipes   Epistemos Act shell + aliases         Goose brand chrome/default onboarding
All           donor runtime-compatible configs  Epistemos names/setup/recents/theme   duplicate provider/MCP/session truth
```

### Native Target Calibration

The native target is the same for all three surfaces:

```text
Epistemos visual standard first.
Donor runtime compatibility underneath.
No donor gets a lower native-feel bar.
No blanket SwiftUI rewrite.
```

OpenGUI and Goose already look comparatively minimal, so their integration
should not be treated as a heavy visual rescue. The likely hard parts are
truth-ownership and setup, not making them visually quiet. The Swift Chat donor
set appears more cluttered, so it likely needs the most aggressive
Epistemos-native simplification of provider/settings/tool UI. That does not
mean rewriting the working agent core; it means replacing or wrapping only the
visible/control surfaces that cause clutter or separate-app feeling. Goose is
not exempt; Goose/OpenGUI may simply be faster to reskin because their starting
point is already closer to the desired minimal grammar.

### Anti-Rewrite Guardrail

Implementation agents should prefer this order:

1. Theme/token injection and copy/branding rewrite.
2. Epistemos chrome, routing, recents, setup, and settings adapters.
3. Donor UI component reskin in the donor's own stack.
4. Native Epistemos replacement for a donor control only when the bridge seam,
   state ownership, and runtime write-through are already proven.
5. Full subsystem rewrite only with explicit owner approval and a rollback path.

This keeps the app from repeating the Osaurus failure mode where a working
engine became visually or architecturally foreign, then attempts to "make it
native" broke feature coverage. Native feeling should be achieved by
unification, adapters, theme, copy, state authority, and shell discipline
before any risky rewrite.

### Scene-Safe Native Strategy

"Reskin/replace by seam" means visual scenes may be replaced much more
aggressively than runtime machinery. The safe target is:

```text
Replace the scene, chrome, copy, layout, route, and settings presentation.
Do not replace the donor state machine, stream parser, worker, protocol,
session store, permission channel, or config loader unless the seam is proven.
```

Practical examples:

- Safe first: Epistemos titlebar/window chrome, landing route, command palette,
  sidebar/rail, settings card layout, pixel typography, flat colors, icon
  grammar, loading/empty/error scenes, onboarding copy, model-picker
  presentation, and permission sheet presentation.
- Safe through adapter: provider/model selection that writes Epistemos truth
  first and donor config second; MCP install rows that write donor config
  through a compatibility alias; recents entries that store donor session ids
  as foreign keys.
- Risky unless proven: replacing OpenGUI's harness runtime, Goose ACP/REST
  session flow, Goose config loader, donor event stream adapters, tool-call
  permission protocol, streaming parser, or donor-owned session persistence.

This is how the app can feel native without pretending every surface is
SwiftUI. Epistemos should own the visible scene and the product grammar; the
donor may still own the runtime spine underneath.

### Settings Fusion Without Settings Soup

Settings fusion should not mean mixing every donor option into one cluttered
global screen. Use a layered settings model:

```text
Primary:
  one Epistemos setting for the user's normal mental model.

Surface card:
  compact Chat / Work / Act summary with readiness, selected engine/model,
  key toggles, and repair actions.

Advanced:
  donor-specific controls that still matter and cannot yet be safely
  canonicalized.

Debug/Witness:
  raw donor config, protocol ids, health probes, logs, and bridge proofs.
```

Rules:

- Fuse truth, not clutter. If three donors have "OpenAI API key", expose one
  Epistemos account row; do not paste three forms into one page.
- Keep donor advanced panes available, but do not make them the normal path.
- Do not canonicalize a setting until its read path, write path, compatibility
  alias, and witness are known.
- Do not remove a donor setting until its useful effect is either automated,
  represented by an Epistemos control, or explicitly retired.
- Prefer progressive disclosure over giant panels. The user should start with
  a quiet app and only descend into raw donor mechanics when needed.

## First-Pass Control Plane Maps

These maps are intentionally private research, not agent instructions yet. They
translate the goal into concrete "what owns truth" tables so the later prompts
can be short, non-drifty, and testable.

### Map 1 - Brand, Vocabulary, And Endpoint Rewrite

| Concept | Epistemos-facing truth | Current app anchor | OpenGUI source/destination | Goose source/destination | Chat source/destination | Classification | Witness needed |
|---|---|---|---|---|---|---|---|
| App identity | `Epistemos` owns app/surface names: Chat, Work, Act | `EpistemosTheme`, Settings chrome | Replace stock Settings titles/copy with Work vocabulary; keep `opengui` as source/debug | Rebrand desktop metadata/UI; use custom distribution knobs; keep Goose as engine label only | Hide Agent!/Swarm app identity; source/debug only | Rebrand / prune | Screenshot of each surface showing Epistemos chrome and no stock donor landing/settings title in normal path |
| Engine labels | Engines are selectable sources, not app identity | Work/Settings engine rows | Harness ids `opencode`, `claude-code`, `pi`, `codex`, `grok-build` stay as engine ids | Goose may appear as Act engine/source label | Agent!/Swarm may appear only in diagnostics/source attribution | Compatibility alias | Engine picker shows source labels without making donor the app shell |
| MCP endpoint names | Epistemos package id is primary; donor ids are aliases | `WorkOpenGUIProvisioner`, `WorkOpenWorkProvisioner`, `SkillDiscoveryCatalog` | Write OpenCode/OpenGUI config as needed; expose as Epistemos tools | Goose extension ids remain internally; surfaced as Epistemos capability packages | Agent MCP ids remain internally; surfaced as Epistemos tools/skills | Fuse / alias | Installed package row maps to donor config and runtime connects |
| Provider endpoint names | Provider/model rows use Epistemos model registry vocabulary | `CloudProviderAuthService`, `ModelProfileManager`, `Keychain` | Provider/model catalog becomes Work projection | `GOOSE_PROVIDER` / `GOOSE_MODEL` become compatibility outputs | `LLMProviderSetup` configs become catalog seed, not separate UI | Canonicalize / alias | Changing one Epistemos model updates donor runtime selection |
| Donor onboarding/update copy | Not part of normal Epistemos UX | Settings and app chrome | Hide stock OpenGUI onboarding/settings copy where duplicated | Prune Goose product onboarding/update prompts unless needed in Advanced | Remove Agent! onboarding language from Chat normal path | Prune | Normal first run shows one Epistemos setup flow |

Rule: do not mass-rename runtime protocol keys blindly. User-facing strings and
config generation should be Epistemos-owned; protocol literals survive behind
aliases where the donor runtime requires exact names.

### Map 2 - Setup, Dependency, Auto-Install, And First-Run

| Setup unit | Epistemos default behavior | Current app anchor | Donor dependency | Classification | Failure UI | Witness needed |
|---|---|---|---|---|---|---|
| Work runtime assets | Verify bundled/linked OpenGUI assets before opening Work | `WorkWebSurfaceView`, Work shell/provisioners | OpenGUI frontend/backend/runtime build assets | Automate / repair | One Work repair row, not stock donor setup | Work launches or reports exact missing asset |
| Work harness CLIs | Detect harness availability and auth | OpenGUI `harness-inventory.ts`, protocol harness ids | OpenCode, Claude Code, Pi, Codex, Grok Build CLIs | Canonicalize / diagnostic | Epistemos Work Engines health list | Each harness row has found/executable/auth status |
| Native MCP bridge | Start and register `epistemos-native` automatically | `WorkOpenGUIProvisioner`, `WorkOpenWorkProvisioner`, `WorkNativeMCPHost` | OpenCode/OpenGUI/worker MCP config | Automate / alias | Warning: native tools unavailable; donor defaults still work | Runtime can call a native Epistemos tool or health row says why not |
| Goose binary/server | Verify Goose executable/server/ACP path | Goose custom distro docs, `goosed`, ACP | Rust Goose binary, REST/ACP | Automate / advanced | Act repair row with install/build action | Act can start session or expose exact missing binary |
| Goose bundled extensions | Ship Epistemos curated extension catalog | Goose built-in extension catalogs/config | Goose MCP extensions | Fuse / rebrand | Capability package row says not installed/reachable | Enabling package writes Goose config and extension appears active |
| Swift Chat providers | Register provider catalog and configure Swarm | `LLMProviderSetup`, `Swarm.configure` | Agent!/Swarm provider/runtime setup | Canonicalize | Chat model picker shows unavailable reason | Selected profile produces a provider or honest unavailable state |
| Skills/tools | Discover and expose once | `SkillDiscoveryCatalog`, Settings skills/tool rows | Agent MCP, Goose extensions, OpenGUI plugins | Fuse | Single Epistemos marketplace repair row | Skill/tool appears in relevant surface without duplicate install |
| Local models | Detect/download only with policy and consent | `ModelProfileManager`, local model settings | Ollama/vLLM/LM Studio/Goose local providers | Automate / owner-consent | One model repair/download row | Model file/server is reachable and selected row is truthful |

Rule: "ready" means invokable from Epistemos. File presence, package install,
or a donor green check is insufficient without an Epistemos bridge witness.

### Map 3 - Providers, Models, Accounts, And Auth

| Provider/model field | Epistemos authority | Current app anchor | OpenGUI | Goose | Chat | Classification | Witness needed |
|---|---|---|---|---|---|---|---|
| Secret storage | `Keychain` + OAuth credential store | `Keychain`, `CloudProviderOAuthCredential` | Consume generated env/config only if needed | Secret config/keyring only if runtime requires | Locked fields become projections | Canonicalize / alias | Secret saved once; donor runtime can authenticate |
| Provider identity | Unified provider account row | `CloudProviderAuthService`, Settings cloud rows | Provider resources/harness model catalog | `GOOSE_PROVIDER`, declarative providers | `LLMProviderSetup` static provider configs | Canonicalize | One row can drive all compatible surfaces |
| Model identity | Unified model profile row with donor aliases | `ModelProfileManager`, model picker | selected provider/model/harness model catalog | `GOOSE_MODEL`, session model override | Swarm default/cloud provider config | Canonicalize / alias | One model selection resolves to each donor's expected id |
| OAuth flows | Epistemos account connection owns user flow | `CloudProviderAuthService` | Work auth health only unless harness requires own OAuth | Goose OAuth/sign-in should be fused into Epistemos account state; raw flow only in Advanced/Debug if required | Agent provider OAuth fields become Settings projections | Fuse | Account status shown once with surface compatibility |
| Per-session model override | Epistemos session ref stores override | Work session/store future row | OpenGUI has session model/harness state | Goose has session model/provider bottom bar | Chat should store in UnifiedSessionRef | Canonicalize | Opening recent restores the right model per surface |

Provider registry seed order:

1. Start with Epistemos `CloudProviderAuthService`, `Keychain`, and existing
   Settings cloud/local rows because they already own user trust and secrets.
2. Import Agent!/Swarm `LLMProviderSetup` as provider capability metadata.
3. Import Goose provider/declarative-provider metadata as Act compatibility.
4. Import OpenGUI harness model catalogs as Work availability, not authority.

### Map 4 - Sessions, Recents, Mini-Sessions, And Lineage

| Session concept | Epistemos authority | Current app anchor | OpenGUI | Goose | Chat | Classification | Witness needed |
|---|---|---|---|---|---|---|---|
| Canonical session id | `UnifiedSessionRef` future registry | `ThreadState`, `ChatThread`, `WorkSessionRegistry` | `composeFrontendSessionId(harnessId, rawId)` and directory scope | Goose session id/import/export | Agent session id + lineage metadata | Canonicalize / alias | Recent opens exact donor session and surface |
| Work main/mini sessions | Work registry then unified registry | `WorkSessionRegistry` | harness id + directory + raw session id | n/a | n/a | Canonicalize | Mini session remains attached until explicit promote/detach |
| Parent/child lineage | Unified parent relation | `AgentSessionLineageStore`, Work registry parent id | queue/session fork/revert metadata | Goose import/session metadata | Chat thread id to session id mapping | Fuse | Parent and child show in one recents/lineage UI |
| Directory/workspace scope | Epistemos workspace/vault scope | Work shell/provisioners, workspace services | directory-first scope in OpenGUI ADR/protocol | Goose cwd/session cwd | Chat vault/workspace path | Canonicalize | Session send uses intended cwd/vault |
| Recents UI | One Epistemos recent list/filter | Existing thread/session browser + future surface refs | Donor session browser becomes Advanced/Debug | Goose history browser becomes Advanced/Debug | Old chat recents replaced by unified entries | Fuse / prune | Chat/Work/Act all appear in same recents model |

Rule: donor session ids are foreign keys. Epistemos recents should never be a
copy of three donor browsers stitched together visually.

### Map 5 - MCP, Extensions, Plugins, Skills, Recipes, And Marketplace

| Capability kind | Epistemos authority | Current app anchor | OpenGUI | Goose | Chat | Classification | Witness needed |
|---|---|---|---|---|---|---|---|
| Native tools MCP | Epistemos native tool package | `WorkNativeMCPHost`, Work provisioners | `opencode.json` / worker `POST /workspace/:id/mcp` | Goose MCP extension / ACP dynamic MCP | Agent MCP server config | Canonicalize / alias | Tool call reaches native app function |
| Skills | Epistemos skill catalog | `SkillDiscoveryCatalog` | Work can project skills into harness workspace | Goose recipes/sub-recipes can mirror high-value skills | Agent tools/MCP bridge can expose skills | Fuse | One skill row enables compatible surfaces |
| Goose extensions | Epistemos capability package with Goose alias | Future capability registry | n/a | built-in extension catalog/config | n/a | Rebrand / alias | Enabling row writes Goose extension config |
| OpenGUI plugins/MCP | Epistemos capability package with OpenGUI alias | Work provisioners/settings future | Settings plugins/MCP tabs | n/a | n/a | Fuse / advanced | Enabling row affects Work runtime |
| Recipes/workflows | Epistemos workflows/skills | Skills/workflow future | Prompt templates/queued workflows | Goose recipes/sub-recipes | Swarm workflows/handoffs | Rebrand / fuse | Workflow appears in command palette and invokes donor path |

Rule: marketplaces become source catalogs. The product-facing marketplace is
Epistemos, with source/donor provenance available in details.

### Map 6 - Permissions, Approvals, Tool Risk, And Audit

| Permission concept | Epistemos authority | Current app anchor | OpenGUI | Goose | Chat | Classification | Witness needed |
|---|---|---|---|---|---|---|---|
| Allow/block policy | Epistemos approval store | `AgentApprovalPolicyStore` | Harness/tool events map to policy request | Goose action-required/tool approval maps to policy request | Agent helper/tool approval maps to policy request | Canonicalize | Decision is stored once and affects next compatible request |
| Permission prompt UI | Epistemos visual/policy language | Settings truth floor, approval sheets | Work tool-call cards reskinned | Act action-required UI reskinned | Native Swift sheets | Rebrand / fuse | Prompt uses Epistemos risk words and writes audit row |
| Native OS permissions | Epistemos setup/permission hub | Settings microphone/accessibility/helper rows | Browser/computer-use/workspace access as setup units | Goose shell/browser/network access as setup units | Agent helper/accessibility/root as setup units | Canonicalize | OS permission health row matches real TCC/helper state |
| Audit history | Epistemos audit/witness log | `AgentApprovalPolicyStore.loadHistory`, session traces | normalized harness events | Goose notifications/tool updates | Agent traces/session metadata | Fuse | One diagnostics view shows surface, tool, decision, outcome |

Rule: donor runtime approval hooks stay alive, but the user should learn one
Epistemos permission vocabulary, not three.

## Control Plane 1 - Surface Identity And Routing

Problem:

Each donor has its own entry assumptions: OpenGUI workspaces/projects, Goose
hub/session navigation, Agent! tabs/task view, existing Epistemos threads and
mini chat routes.

Unification rule:

- Epistemos Landing owns top-level routing.
- Surfaces register a manifest with id, display name, icon, primary route,
  capabilities, and advanced routes.
- Donor internal routes remain, but are nested below the Epistemos surface id.

Proposed manifest:

```swift
struct EpistemosSurfaceManifest: Codable, Identifiable {
    var id: String              // chat, work, act
    var donor: String           // agent-swift, opengui, goose
    var displayName: String
    var capabilities: [SurfaceCapability]
    var defaultSessionKind: String
    var advancedRoutes: [SurfaceRoute]
    var settingsNamespaces: [String]
}
```

Minimum bridge behavior:

- Landing opens `surfaceID`.
- Recents entries include `surfaceID`.
- Deep links never jump directly into donor-global state without resolving
  through Epistemos surface identity.

## Control Plane 2 - Unified Sessions And Recents

Problem:

Epistemos has `ThreadState` and `ChatThread`; OpenGUI has harness-scoped
sessions and prompt queue; Goose has sessions/history/import/export; Agent!
has tabs/task history/session stores. If these stay independent, recents feel
wrong and mini surfaces strand state.

Unification rule:

- Epistemos owns a `UnifiedSessionRef`.
- Donor session ids are foreign keys, not the main identity.
- Donor session stores remain intact for compatibility, but Epistemos records
  a canonical shadow row that maps every donor session to one app-level entry.

Proposed shape:

```swift
struct UnifiedSessionRef: Codable, Identifiable, Hashable {
    var id: String
    var surfaceID: String       // chat, work, act
    var donorSessionID: String
    var donorHarnessID: String?
    var workspaceURL: URL?
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var status: SessionStatus
    var parentSessionID: String?
    var miniSessionIDs: [String]
}
```

Integration pattern:

- OpenGUI list/create/open session writes `UnifiedSessionRef`.
- Goose session create/load/import writes `UnifiedSessionRef`.
- Chat/Agent!/Swarm session create writes `UnifiedSessionRef`.
- Mini Chat, Graph Chat, Note Chat point at `UnifiedSessionRef`, not private
  old implementations.
- Donor original session browsers remain accessible under Advanced, but the
  default recents UI reads Epistemos refs.

Risk:

If the donor session id is copied without a watcher/reconcile path, recents go
stale. Each donor needs a `syncSessions()` adapter and a "last reconciled"
health row.

## Control Plane 3 - Providers, Models, Accounts, And Auth

Problem:

OpenGUI resolves model defaults from provider/model resources. Goose has
`GOOSE_PROVIDER`, `GOOSE_MODEL`, provider inventory, declarative provider
stores, OAuth/sign-in, and secret config. Agent! has `LLMProviderSetup`,
per-provider keys, OpenRouter catalog, local Ollama/vLLM/LM Studio, and
Apple Intelligence. Epistemos already has provider logos, model profiles,
Keychain, cloud auth, local model installers, and model picker work.

Unification rule:

- Epistemos owns provider accounts and model profiles.
- Donor config remains as compatibility output.
- All provider setup screens read/write the same Epistemos account registry.
- Donor-specific config keys are generated from canonical provider rows.

Proposed shape:

```swift
struct UnifiedProviderAccount: Codable, Identifiable {
    var id: String              // openai, anthropic, openrouter, ollama, etc.
    var displayName: String
    var authKind: AuthKind      // apiKey, oauth, localServer, subscription, none
    var secretKeychainRef: String?
    var baseURL: URL?
    var sourceSurfaces: Set<String>
    var capabilities: ProviderCapabilities
    var donorCompatibilityKeys: [DonorConfigKey]
}

struct UnifiedModelProfile: Codable, Identifiable {
    var id: String              // provider/model or local id
    var providerAccountID: String
    var displayName: String
    var contextWindow: Int?
    var supportsTools: Bool
    var supportsVision: Bool
    var supportsStreaming: Bool
    var supportsLocal: Bool
    var pickerUseCase: String
    var donorModelAliases: [String: String]
}
```

Write-through examples:

- Changing default model in Epistemos writes:
  - Goose `GOOSE_PROVIDER` / `GOOSE_MODEL`
  - OpenGUI selected model defaults where applicable
  - Agent!/Swarm active provider configuration
- Setting an API key in Epistemos writes:
  - Epistemos Keychain secret
  - donor secret config only if the donor requires it for runtime
  - never plaintext duplicate storage unless unavoidable and witnessed

Do not:

- Keep three separate "OpenAI API key" fields as default surfaces.
- Blindly delete donor runtime fields. First classify them. Canonical provider
  rows should be the normal UI; donor fields become compatibility outputs,
  Advanced raw config, or removable only after a witness proves the runtime no
  longer depends on them.

## Control Plane 4 - MCP, Extensions, Plugins, Skills, And Marketplace

Problem:

OpenGUI has Settings tabs for MCP/plugins and harness resources. Goose has
configured extensions, bundled extension sync, session extensions, MCP apps,
and extension warnings. Agent! has MCP server UI and presets. Epistemos has
skills, FineTunePack marketplace, ToolTierBridge, and vault skill discovery.

Unification rule:

- Epistemos owns a marketplace/registry that can expose different item types:
  MCP servers, Goose extensions, OpenGUI plugins, Agent! tools, Epistemos
  skills, recipes, fine-tune packs.
- User-facing language becomes Epistemos language: tools, skills, MCP
  endpoints, recipes, and capability packs belong to Epistemos first.
- Donor marketplaces become source catalogs or Advanced browsers; install
  state is reflected in one Epistemos registry.
- Dependency install/repair status is part of the same registry, not a hidden
  donor-local setup screen.

Proposed shape:

```swift
struct UnifiedCapabilityPackage: Codable, Identifiable {
    var id: String
    var kind: CapabilityKind    // mcpServer, skill, gooseExtension, openguiPlugin, recipe, toolPack
    var displayName: String
    var source: CapabilitySource
    var installState: InstallState
    var enabledSurfaces: Set<String>
    var requiredPermissions: [PermissionDescriptor]
    var donorConfig: [String: JSONValue]
}
```

Bridge behavior:

- Installing from Epistemos writes donor config entries:
  - Goose `addConfigExtension` / extension enablement.
  - OpenGUI MCP/plugin settings.
  - Agent! MCPConfig.
- Installing from donor UI notifies Epistemos and creates/updates the
  canonical package row.
- Each surface can filter packages by compatibility, but the owner sees one
  marketplace and one enabled-state vocabulary.
- If a donor requires a literal MCP/server/extension id, store it as a
  compatibility alias behind the Epistemos package id.
- Package health must answer: installed, enabled, reachable, permitted, and
  surfaced in the relevant Chat/Work/Act UI.

## Control Plane 5 - Permissions, Approvals, And Security

Problem:

Goose has tool approval and permission store. OpenGUI/harnesses have their own
permissions and tool/event states. Agent! has helper, accessibility,
AppleScript, shell, rollback, web automation, MCP and tool preferences.
Epistemos has `AgentApprovalPolicyStore`, ToolTierBridge, TCC status, and
settings truth rows.

Unification rule:

- Epistemos owns the policy vocabulary and audit log.
- Donors retain their runtime approval hooks.
- Permission prompts render in surface-native UI but write decisions into the
  same Epistemos policy/audit model.

Proposed shape:

```swift
struct UnifiedPermissionRequest: Codable, Identifiable {
    var id: String
    var surfaceID: String
    var donorRequestID: String
    var toolName: String
    var riskTier: PermissionRiskTier
    var requestedScope: PermissionScope
    var proposedCommandSummary: String?
    var resourceRefs: [String]
    var decision: PermissionDecision?
}
```

Rendering rule:

- Goose action-required UI can keep its functionality, but gets Epistemos
  visual treatment and Epistemos policy semantics.
- OpenGUI tool-call cards map to the same permission decision states.
- Agent! helper/root/accessibility prompts remain native Swift/macOS where
  possible.

No hidden success:

- Settings Truth Floor rules still apply: a permission row cannot go green
  unless production wiring and a matching witness are present.

## Control Plane 6 - Theme, Native Feel, And "Code UI"

Problem:

Each donor has its own styling system: SwiftUI/AppKit in Chat, React/Tailwind
in OpenGUI, React/Electron in Goose. The owner wants OpenCode-minimal
Epistemos visual language everywhere.

Unification rule:

- Epistemos theme tokens are the source.
- Donor UIs consume generated theme tokens, not hand-picked approximations.
- Every donor keeps function, but receives a common visual grammar.

Token export:

```json
{
  "font.mono": "EpistemosMono",
  "font.pixel": "VTFMisterPixel",
  "surface.base": "#...",
  "surface.raised": "#...",
  "text.primary": "#...",
  "text.muted": "#...",
  "accent.green": "#...",
  "accent.warning": "#...",
  "border.subtle": "#...",
  "radius.panel": 6,
  "motion.typewriter": true
}
```

Application:

- Swift Chat consumes tokens directly from `EpistemosTheme`.
- OpenGUI gets generated CSS variables and component overrides.
- Goose gets generated CSS variables and component overrides.
- WKWebView/Electron surfaces receive tokens through preload/postMessage or
  a generated CSS file.

Visual invariant:

- No donor surface may ship as stock Goose, stock OpenGUI, or stock Agent!.
- No donor surface may hide major controls just to look minimal.
- Minimal means "dense and legible," not "capabilities removed."
- Donor product names, landing copy, badges, update prompts, onboarding
  funnels, and brand-specific marketing language should be pruned or rewritten
  unless they are needed for licensing/source attribution or an explicit engine
  picker.

## Control Plane 7 - Diagnostics, Health, And Witness Rows

Problem:

The owner wants "it actually connects to my app." That cannot be proven by
visual reskin alone.

Unification rule:

- Each surface registers a health bundle:
  - setup/dependency readiness
  - session sync
  - provider sync
  - model sync
  - MCP/extension sync
  - permission bridge
  - theme bridge
  - runtime/event bridge
  - last successful send/stream if credentials allow
- Epistemos Settings shows compact rows; donor diagnostic pages remain
  accessible under Advanced.

Proposed shape:

```swift
struct SurfaceHealthSnapshot: Codable {
    var surfaceID: String
    var bridgeVersion: String
    var setupReady: Bool
    var lastSessionSync: Date?
    var lastProviderSync: Date?
    var lastCapabilitySync: Date?
    var runtimeReachable: Bool
    var themeApplied: Bool
    var permissionBridgeReachable: Bool
    var warnings: [String]
}
```

This avoids "looks integrated" without actually integrating.

## Top-Down Strategy

1. Define the Epistemos control planes first:
   - brand/name bindings
   - setup/dependency units
   - pruning classifier
   - surface manifest
   - unified session refs
   - provider account registry
   - model profile registry
   - capability marketplace registry
   - permission/audit registry
   - theme token export
   - health snapshot contract

2. Build the smallest bridge for each donor:
   - `EpistemosOpenGUIBridge`
   - `EpistemosGooseBridge`
   - `EpistemosChatBridge`

3. Require every donor surface to support:
   - read canonical settings
   - write canonical setting intents
   - mirror donor-specific state back to Epistemos
   - apply Epistemos theme tokens
   - emit session/runtime events
   - emit permission/capability events

4. Classify, reskin, and simplify with capability witnesses:
   - simple front panel first
   - donor advanced panel reachable only where it still earns its place
   - no lost settings
   - no orphaned donor UI
   - no stock donor product identity in the normal path

## Bottom-Up Strategy

### Work / OpenGUI

Keep:

- runtime/backend/harness split
- OpenCode/Codex/Claude Code/Pi/Grok Build harness shape
- prompt queue
- model/backend/agent selection
- MCP/plugins/settings
- streaming transcript/event normalizers
- directory-scoped sessions

Fuse:

- OpenGUI harness/session ids into `UnifiedSessionRef`.
- OpenGUI model selection into `UnifiedModelProfile`.
- OpenGUI MCP/plugins into `UnifiedCapabilityPackage`.
- OpenGUI settings tabs become Work Advanced settings, with canonical
  Epistemos controls up front.
- OpenGUI first-run/runtime dependency checks become `EpistemosSetupUnit` rows.

Prune/rebrand:

- OpenGUI product naming, standalone onboarding, donor-specific settings copy,
  and duplicate provider/MCP setup should not be the default Work experience.
- Keep harness and runtime language only where it helps expert users pick an
  engine or debug an adapter.

High-risk seam:

- OpenGUI has its own settings bridge and state. If left authoritative, it
  will create ghost provider/session state. Use write-through adapters.

### Act / Goose

Keep:

- Goose sessions
- provider/model setup
- OAuth/sign-in and secret config
- MCP/extensions and MCP UI apps
- recipes
- action-required permissions
- schedules/memory/config
- local inference settings
- API/server/ACP plumbing

Fuse:

- Goose `GOOSE_PROVIDER` / `GOOSE_MODEL` mirror Epistemos provider/model.
- Goose configured extensions mirror Epistemos capability packages.
- Goose session/history rows mirror `UnifiedSessionRef`.
- Goose permission requests mirror `UnifiedPermissionRequest`.
- Goose settings should be fused as far as practical into Epistemos settings,
  just like Work and Chat. Only runtime-sensitive Goose-specific controls stay
  under Act Advanced/Debug, and even there they use Epistemos vocabulary,
  theme, recents, provider/model identity, and permission semantics.

Prune/rebrand:

- Goose's internal runtime shell can remain as an implementation scaffold, and
  the visible Act experience should be reskinned, wrapped, or selectively
  replaced at proven seams to reach the same native Epistemos standard as the
  other surfaces.
- Donor update prompts, brand chrome, duplicate setup, and standalone product
  flows should be hidden, rewritten, or moved to Advanced/Debug.
- Engine names like Goose may appear only as source/engine labels where useful,
  not as the app identity.

High-risk seam:

- Goose `ConfigContext` and `ModelAndProviderContext` currently assume Goose
  config is the truth. For the normal path, the fusion must invert that:
  Epistemos is truth; Goose config is compatibility state. If a Goose-specific
  setting cannot be safely fused yet, it stays inside Act Advanced/Debug with a
  health warning and a TODO to canonicalize, rather than becoming a parallel
  Epistemos-wide truth.

### Chat / Agent! + Swarm

Keep:

- Agent! full app/capability surfaces where useful:
  - provider picker
  - MCP settings
  - tools
  - coding preferences
  - fallback chain
  - token usage
  - rollback/history
  - shell/Xcode/web automation
  - memory/skills/session store
  - native helper/accessibility/system prompts
- Swarm framework capabilities:
  - typed tools
  - streaming
  - workflows/handoffs
  - memory
  - guardrails
  - provider selection
  - durable checkpoint/resume
  - observability
  - MCP bridge

Fuse:

- Agent! provider settings map to `UnifiedProviderAccount`.
- Swarm default provider resolves from Epistemos model/profile selection.
- Agent!/Swarm sessions map to `UnifiedSessionRef`.
- Agent! MCP and tools map to `UnifiedCapabilityPackage`.
- Agent! permission/helper state maps to Epistemos permission/health rows.

Prune/rebrand:

- Chat should be the most Epistemos-native surface. It should not expose Agent!
  as a visible separate app.
- Provider setup, MCP, helper permissions, model picker, and skill/tool controls
  should be simplified into Epistemos-native controls where the state bridge is
  proven; otherwise wrap/reskin the donor control and keep the runtime path
  intact.
- Agent!/Swarm names survive as source attribution, debug metadata, or engine
  labels only when needed.

High-risk seam:

- Agent! is strong as an app, but has many provider-specific fields. If
  copied literally, Chat becomes another settings universe. The correct move
  is provider registry first, Agent! fields as projections.

## Settings IA Recommendation

Use the existing SS-D doctrine:

- presentation simplified;
- functionality preserved;
- one home per setting;
- Advanced disclosure for full donor settings;
- no new scattered settings sidebar entries.

Suggested homes:

```text
Setup & Dependencies
  one first-run/repair hub for runtimes, binaries, MCP servers, skills, tools,
  local models, helpers, and permissions

Models & Providers
  canonical accounts, keys, OAuth, base URLs, model profiles
  Advanced: donor raw provider config per surface

MCP, Extensions & Skills
  unified Epistemos marketplace/install/enable state
  Advanced: OpenGUI plugins, Goose extensions, Agent! MCP raw editors

Surfaces
  Chat card
  Work card
  Act card
  each with simple front; Advanced only for still-needed donor technical panels

Permissions & Tools
  tool tiers, approvals, TCC, helper/root/accessibility, policy history

Sessions & Sync
  recents, imports, export, sharing/gateway, donor session reconciliation

Diagnostics
  health rows and witness status for every bridge
```

## Do Not Lose Capability Rule

For every donor screen, classify it:

```text
Canonicalized:
  default Epistemos UI owns it; donor UI becomes mirror.

Advanced:
  donor UI remains reachable because it has too much detail to flatten safely.

Read-only diagnostic:
  donor UI/state remains visible for debugging but not normal control.

Deferred:
  visible as coming-soon/unsupported only if runtime is truly unavailable.

Removed:
  omitted from product only after a rationale, replacement/retirement note, and
  compatibility check prove Epistemos is not losing useful capability.
```

No capability may be silently dropped. A donor product screen can disappear
from the app if its useful parts were canonicalized, rebranded, automated,
moved to Advanced/Debug, compatibility-aliased, or explicitly removed with
evidence.

## Native-As-Possible Without Losing Full Clone Benefits

Native feel should come from ownership of:

- brand vocabulary and names
- window chrome
- landing/routing
- first-run setup
- command palette
- settings IA
- model picker grammar
- permission sheets
- recents/session identity
- theme tokens
- keyboard shortcuts
- diagnostics language

It does not require rewriting every donor surface into Swift. For OpenGUI and
Goose, Web/Electron surfaces can remain if they obey the Epistemos control
planes and theme bridge. "Native enough" means:

- user sees one app model;
- user configures providers once;
- user sees sessions once;
- user installs MCP/extensions once;
- user grants permissions once per policy;
- donor advanced panes are reachable but not the default mental model.

## Integration Invariants

1. One provider account row per provider identity.
2. One model profile row per model identity, with donor aliases.
3. One session/recents row per conversation/work session.
4. One capability package row per MCP/extension/skill/recipe/tool pack.
5. One permission decision model, even if prompts render in different
   surfaces.
6. One setup/dependency readiness model.
7. One Epistemos naming layer, with donor aliases only where runtime-sensitive.
8. One theme token export, consumed by Swift, OpenGUI, and Goose.
9. Donor raw settings stay reachable under Advanced when still needed, not duplicated as
   primary settings.
10. Every write from a donor UI either:
   - writes the canonical Epistemos registry first, then donor config, or
   - emits a reconciliation event that Epistemos ingests immediately.
11. Every bridge has a health snapshot and last-sync timestamp.
12. No "green" health state without production wiring and matching witness.
13. No stock donor product identity in the normal user path.

## Proposed Iteration Loop

Repeat until the map is complete:

1. Pick one control plane.
2. Inventory Epistemos existing owner state.
3. Inventory OpenGUI state.
4. Inventory Goose state.
5. Inventory Chat/Agent!/Swarm state.
6. Build a mapping table:
   - canonical Epistemos field
   - OpenGUI source/destination
   - Goose source/destination
   - Chat source/destination
   - conflict
   - classification bucket
   - Epistemos-facing name
   - donor compatibility alias
   - migration rule
   - setup/dependency rule
   - verification evidence
7. Decide whether each donor screen is canonicalized, rebranded, fused,
   automated, advanced, diagnostic, compatibility-aliased, deferred, or removed.
8. Add witness requirement.

First six maps now exist as v0 research tables above. The next loop should
deepen them row by row:

1. Add exact donor read/write API, file, IPC, or config paths.
2. Add exact Epistemos destination type or missing type to create.
3. Add migration direction: Epistemos-to-donor, donor-to-Epistemos, or
   bidirectional reconcile.
4. Add classification: canonicalize, rebrand, fuse, automate, advanced,
   debug/witness, compatibility alias, or remove.
5. Add verification command/runtime probe.
6. Add owner-visible UI placement.

## Open Questions For Next Pass

- Should Work and Act have separate top-level doors if both are heavy
  Web/Electron-derived surfaces, or should Act be a mode inside Work after the
  control planes exist?
- Which provider registry should seed first: Epistemos current
  `ModelProfileManager`, Agent! `LLMProviderSetup`, Goose provider inventory,
  or OpenGUI harness resources?
- How much donor secret storage is unavoidable for runtime compatibility?
- Can Goose and OpenGUI both consume a shared local MCP server registry without
  writing duplicate config files?
- Which donor screens must remain Advanced/Debug because their internal
  assumptions are too detailed to safely flatten, and which can be removed
  after their useful controls are fused?
- Should Epistemos generate CSS/theme packages checked into each donor fork, or
  inject theme variables at runtime?
- Which dependencies can be auto-installed silently, which need owner consent,
  and which must be manual because of security/licensing/runtime risk?
- What donor endpoint names can be rewritten at config-generation time, and
  which must remain literal protocol identifiers behind Epistemos aliases?

## Current Recommendation

Keep all three surfaces, but do not let implementation agents independently
solve identity, settings, setup, or branding. Before feeding them a new prompt,
create the shared control-plane artifacts and mapping tables. Otherwise each
agent will faithfully full-clone its donor and accidentally preserve three
separate app ontologies.

## Candidate Architecture - Goose + OpenGUI Fusion First

Owner hypothesis added 2026-06-24:

> Fuse Goose with OpenGUI first. Goose may become the main driver of the
> combined Work/Act-style agent surface, with OpenGUI added as the multi-agent
> work capability. Then embed that combined scene into the Epistemos home
> window, mini chat, graph chat, and related surfaces with Epistemos theme,
> landing transitions, model-space, fonts, ASCII/typewriter/blur animations,
> and flat code-like chrome.

This is viable, but the safe version is not "Goose owns OpenGUI runtime state."
The safe version is:

1. Epistemos owns the scene, routing, settings/control plane, landing toggle,
   recents, mini-session lineage, theme, and diagnostics.
2. Goose donates ACP sessions, agent behavior, recipes/extensions, permission
   callbacks, elicitation/approval surfaces, and its agent runtime contract.
3. OpenGUI donates the multi-harness work command center: harness adapters,
   normalized event stream, harness inventory, queue, directory-scoped work,
   and cross-agent session visibility.
4. The fusion point is an adapter/control-plane seam, not a shared mutable
   session store.

Source evidence:

- OpenGUI explicitly separates Runtime, Backend, Frontend, and Shell. Runtime
  owns harness adapters, normalized `HarnessEvent`, harness inventory, and
  sends on `harnessId + directory + harness session id`; session/transcript
  truth stays in the harness.
- OpenGUI's own docs say adding a harness means registry metadata, a bridge,
  bridge registration, inventory entry, and session-id codec. This is the
  natural place to add Goose as a first-class Work harness if Work is the
  combined surface.
- Goose's desktop code creates an ACP client with permission, elicitation,
  recipe-parameter, and session-update callbacks, then exposes ACP session
  list/load/create/delete/rename/fork/export/import helpers. This is a strong
  agent runtime contract, but it is not itself a generic multi-harness work
  control plane.

Therefore the best fusion order is:

1. Build a Goose harness adapter for OpenGUI or an Epistemos-side bridge that
   maps Goose ACP sessions/events into the same normalized shape used by Work.
2. Keep OpenGUI's harness/backend queue semantics intact for Work.
3. Keep Goose's ACP client/session/permission semantics intact for Act and for
   the Goose row inside Work.
4. Replace scenes, chrome, settings presentation, and model/agent picker UI
   with Epistemos-native surfaces.
5. Do not merge their internal stores directly. Store cross-links in Epistemos:
   `epistemosSessionId -> { surface, donor, donorSessionId, harnessId, cwd,
   model, capabilityPackageId }`.

### What This Looks Like In The App

The home window remains the Epistemos landing page. It gets a deliberate,
native-feeling toggle/segmented route:

- Chat: Swift-heavy chat donor fusion.
- Work: OpenGUI multi-harness surface, with Goose/OpenCode/Codex/Claude/Pi/
  Hermes available as engines where proven.
- Act: Goose-first agent surface, or a focused Goose mode using the same
  Goose bridge as Work.

The toggle is not a superficial tab strip. It should perform the Epistemos
transition: blur reveal, typewriter/ASCII title, pixel-flat model-space, and
theme-aware minimal chrome. When a donor scene becomes visible, the donor's
own stock titlebar/sidebar/settings shell should not appear in the normal
path; Epistemos presents the scene and writes through adapters.

Mini chat, graph chat, and note/chat attachments should use the same scene
bridge contract, not separate chat implementations:

```text
EpistemosSceneBridge
  listSessions(surface, scope)
  openSession(epistemosSessionId)
  createSession(surface, scope, initialPrompt?)
  send(sessionId, text, model?, attachments?)
  streamEvents(sessionId)
  cancel(sessionId)
  requestPermission(request)
  setModel(surface, provider, model)
  health(surface)
```

This keeps the visual target unified while preventing the old failure mode:
three separate apps each believing it owns sessions, settings, provider state,
permissions, and recents.

### Goose-First Variant Verdict

Use "Goose-first" for the Act experience and for Goose-specific capabilities.
Do not use "Goose-first" to make Goose the owner of OpenGUI's Work runtime.
That would recreate the bundled-app problem: two product ontologies inside one
window, with duplicated settings, duplicated session recents, and ambiguous
permission routing.

Important clarification: "I like Goose's UI" should be treated as a scene and
interaction donor preference, not as proof that Goose should own the combined
runtime. Goose can donate the look of the chat surface: compact layout,
minimal controls, session rhythm, permission affordances, and agent-focused
flow. OpenGUI can still donate the Work control plane. The target is not
"OpenGUI must visually win over Goose"; the target is "Epistemos scenes may
use Goose-like interaction where it feels better, while OpenGUI keeps the
multi-harness runtime where it is stronger."

Do not claim that putting Goose "inside OpenGUI" automatically gives Work all
Goose capabilities. It only preserves Goose capabilities if the bridge exposes
the capability surface, not merely the send-message surface. The minimum
Goose-complete adapter must cover:

- ACP prompt, cancel, and steer.
- ACP session list/load/create/delete/rename/fork/export/import.
- Permission requests and permission resolution.
- Elicitation and recipe parameter requests.
- Configured extensions, including builtin, platform, stdio MCP, and
  streamable HTTP MCP entries.
- Enabled extension selection at session creation.
- Provider/model state, current model display, and model switching.
- Session update notifications and streaming/chat updates.

If any of those are omitted, Goose becomes "a Goose-looking chat that lost
Goose's powers." That is the failure mode the owner is explicitly trying to
avoid.

The safer wording is therefore:

```text
Use Goose as a visual/interaction donor where its UI is better, and as a real
runtime donor through an ACP-complete adapter. Use OpenGUI as the Work
multi-harness control plane. Do not hide Goose behind a simple OpenGUI
send-only harness. A Goose row in Work must surface Goose sessions, extensions,
MCPs, permissions, recipes, model/provider state, prompt/cancel/steer, and
session lifecycle, or it is not accepted.
```

Better wording for implementation agents:

```text
Make the combined agent scene feel Goose-capable and Epistemos-native, but keep
OpenGUI as the Work harness/control-plane runtime. Add Goose to the Work engine
set through a bridge/adapter. Do not make Goose's React session store own
OpenGUI sessions, and do not make OpenGUI's frontend own Goose-specific
permission/recipe flows. Epistemos owns the unified shell and maps both into
one session/settings/permission/control plane.
```

### Validation Probes For This Fusion

Before any "Goose + OpenGUI fused" claim can be marked true, prove:

1. A Goose session can be listed through the unified Epistemos scene bridge.
2. A Goose session can be created from the home landing toggle and opened from
   the same recents popover as Work sessions.
3. A Goose prompt streams through the Epistemos transcript renderer without
   stock Goose chrome.
4. A Goose permission request appears in an Epistemos-native permission sheet,
   resolves through the Goose ACP callback, and the agent continues.
5. OpenGUI Work sessions still list/create/send/stream/cancel independently
   after Goose is present.
6. The model/agent picker can switch between OpenGUI harnesses and Goose model
   state without writing conflicting donor configs.
7. Mini chat can attach to either a Goose session or an OpenGUI Work session by
   Epistemos session id.
8. Relaunch preserves recents and reopens the correct donor session.
9. Screenshots show one Epistemos scene language: same fonts, flat code-like
   chrome, theme tokens, blur/typewriter/ASCII transition, and no stock donor
   titlebar/settings shell in the normal path.

## V1 Seam Inventory - Source, Destination, Probe

This section converts the research into implementation-control rows. A future
agent may reskin or scene-replace only after the destination and probe are
defined. Anything without a probe remains donor-owned or Advanced/Debug-only.

### Work / OpenGUI

| Seam | Source Evidence | Epistemos Destination | Required Probe |
| --- | --- | --- | --- |
| Runtime process | `Epistemos/Work/WorkOpenGUISupervisor.swift` spawns `bun og-sidecar.mjs`, sends NDJSON, parses reply/event frames, and exposes `initRuntime`, `connect`, `createSession`, `openSession`, `send`, `abort`, `messages`, `loadResources`, `diagnose`. | Epistemos `WorkSceneBridge` wraps the supervisor; no UI code talks directly to donor process APIs. | Start supervisor, diagnose engines, create session, send prompt, receive event, abort/cancel, load resources, stop without orphaning owned process tree. |
| Donor sidecar contract | `.research-clones/work/opengui/og-sidecar.mjs` implements `init`, lazy `connect`, `sessions.list/create/open`, `send`, `waitIdle`, `abort`, `messages`, `loadResources`, `close`, and forwards de-duped events. | Keep sidecar as Work runtime seam until a native equivalent has full command parity. | NDJSON fixture proves every command round-trips and error frames map to native diagnostics. |
| Harness registry | OpenGUI registry currently has `opencode`, `claude-code`, `pi`, `codex`, `grok-build`; bridge table must match `HARNESS_ID_VALUES`. | Epistemos agent picker derives Work engines from OpenGUI registry plus Epistemos capability overlays, not hardcoded UI rows. | Inventory row for each engine includes installed/path/version/auth/resource status; missing engine is visible but inert, not fake-ready. |
| Harness event model | OpenGUI `HarnessCapabilities` includes sessions, streaming, models, agents, commands, compact, fork, revert, permissions, questions, provider auth, MCP, config, local server. | Work feature matrix is generated from capabilities. Controls are disabled/explained when capability is false. | For every visible control, a harness capability or Epistemos overlay proves it is callable; no dead controls. |
| Session identity | OpenGUI `composeFrontendSessionId(harnessId, rawId)` prefixes harness ids; Epistemos `WorkSessionMapper` maps OpenGUI listed sessions to main roots because OpenGUI summaries lack parent lineage. | Epistemos owns `epistemosSessionId` and mini-session lineage; donor session id is a foreign key. | Relaunch recents reopen the same harness session; mini-session parent survives even though donor list cannot express it. |
| Mini sessions | `WorkSession`, `WorkSessionRegistry`, `WorkSessionStore` already encode main/mini, parent id, attached/detached presentation, cascade remove, explicit promote. | One shared mini-session model for Work, mini chat, graph chat attachment, and future Goose-in-Work rows. | Create main, attach mini, detach mini, promote mini, remove main; donor session foreign keys remain stable. |
| Visual Work scene | `WorkWebSurfaceView` already separates native header/curved box from runtime WebView and SPA server. | Use this shell pattern for embedded Work scenes, but replace donor chrome/copy with Epistemos theme and code-like minimalism. | Screenshot has Epistemos landing transition + header/chrome only; no stock donor titlebar/settings shell in normal path. |
| Settings risk | `WorkCloneSettingsView` still says "Work = OpenCode shell", "real terminal TUI", and "Goose/Hermes/OpenClaw fused beneath" while newer code has OpenGUI sidecar and WebView/runtime seams. | Rewrite settings copy/IA only after the control map is stable; label it Work / OpenGUI multi-engine, with terminal TUI as optional Advanced/Debug if retained. | Settings rows match actual runtime seams; no stale architecture terms imply an old implementation path. |

### Act / Goose

| Seam | Source Evidence | Epistemos Destination | Required Probe |
| --- | --- | --- | --- |
| ACP connection | Goose `acpConnection.ts` creates a `GooseClient` over WebSocket, registers permission, elicitation, recipe-param, session-update callbacks, and initializes with Goose MCP host capabilities. | Epistemos Goose bridge keeps ACP as the runtime protocol; Epistemos owns sheets/scenes that respond to callbacks. | Client connects, callback fires for permission/elicitation/recipe, native sheet resolves it, and Goose continues the run. |
| Session lifecycle | Goose `acp/sessions.ts` lists recent sessions, loads sessions, creates sessions with enabled extensions and recipes, deletes/renames/updates cwd/truncates/forks/exports/imports sessions. | Epistemos Act session adapter must expose full lifecycle, not just start/send. Recents store Goose ids as foreign keys. | List/create/load/rename/fork/delete/export/import all round-trip through Epistemos UI or Advanced/Debug control. |
| Prompt control | Goose `acp/prompt.ts` exposes prompt, cancel, and steer. `chatSessionController.ts` handles active attempts, stop/cancel, edit/fork, recipe params, extension load results, and credits-exhausted messages. | Epistemos transcript renderer must carry active-run state, cancel state, edit/fork state, system notifications, and local steer/edit behaviors. | Send, stop, edit-as-fork, edit-truncate-resend, and credit/error/system notification all render in Epistemos scenes. |
| Permissions | Goose `permissionRequests.ts` tracks pending permission by `sessionId + toolCallId`, maps allow/deny/cancel actions to ACP option ids. | Native Epistemos permission sheet owns presentation; Goose pending map owns ACP response. | Allow once, always allow, deny once, always deny, cancel all produce correct ACP response and unblock/stop the agent. |
| Elicitation | Goose `elicitationRequests.ts` supports form-mode elicitation with timeout/cancel/submit. | Epistemos form sheet uses same request id/session id and returns accepted/cancelled response. | A form request appears natively, validates fields, submits, times out/cancels correctly. |
| Recipes | Goose `recipeParamRequests.ts` tracks pending recipe parameter requests and configured defaults. | Epistemos capability/package setup can prefill recipe params; Advanced can expose raw recipe params. | Recipe session creation requests params, Epistemos sheet submits values, session proceeds and saves user recipe values. |
| Extensions / MCP | Goose `extensions.ts` converts builtin/platform/MCP stdio/MCP HTTP extension configs to Goose extensions and uses ACP config extension list/add/remove/enable APIs. | Epistemos capability packages write Goose extension config via compatibility adapter; normal UI uses Epistemos names, Advanced shows raw Goose extension rows. | Enable builtin, platform, stdio MCP, and HTTP MCP; Goose lists them, session starts with selected enabled extensions, tool call works. |
| Provider/model | Goose `ModelAndProviderContext` reads/writes `GOOSE_MODEL` and `GOOSE_PROVIDER`, supports per-session provider update and global config default. | Epistemos model-space writes canonical selected model first, then compatibility-writes Goose config or session provider. | Model switch reflects in Goose current model, survives relaunch, and does not conflict with OpenGUI selected model. |
| Visual donor | Goose UI can donate compact agent interaction rhythm, but not ownership of Work runtime. | Use Goose-like interaction where better: compact chat flow, permission affordance, minimal controls, session rhythm, theme-aware scene. | Screenshot proves Goose scene has Epistemos chrome/theme/animations and no stock Goose shell in normal path. |

### Chat / Swift Donors

| Seam | Source Evidence | Epistemos Destination | Required Probe |
| --- | --- | --- | --- |
| Native provider registry | Agent-macos26 `LLMProviderSetup.swift` registers cloud, local, self-hosted, Codex, Ollama, vLLM, LM Studio, Apple Intelligence providers with capabilities. | Epistemos Chat model/provider registry imports useful provider definitions but owns names, auth rows, defaults, and visibility. | Provider list appears once in Epistemos settings/model-space; selecting a provider configures the donor runtime and can stream a test message. |
| Swift MCP config | Agent `MCPServerConfig` handles stdio and HTTP configs, headers, env, endpoints, unsupported-field roundtrip; `MCPService` connects, discovers tools/resources, toggles disabled tools, calls tools/resources, resolves PATH. | Epistemos MCP settings become the single normal path; Swift donor MCP config is a compatibility format and tool runtime. | Add stdio/HTTP MCP in Epistemos, donor discovers tools/resources, disabled-tool toggle works, tool call succeeds. |
| Swift MCP libraries | AgentKit includes MCP client/server kits, tool/resource/prompt registration, stdio and HTTP transports, streamable HTTP session manager. | Use as native MCP implementation motifs where useful, especially for app-hosted native tools and MAS-friendly local features. | App-hosted MCP exposes Epistemos tools; client can call one tool; HTTP session cleanup works. |
| Skills | Agent `SkillsService` loads Markdown skills from `Documents/AgentScript/skills`, installs starter skills when empty. | Move skill root under Epistemos vault/app support and rename surfaces to Epistemos Skills; preserve markdown format if useful. | Fresh install seeds Epistemos skills once; user-created skill persists; donor path is not used unless imported. |
| Session store | Agent `SessionStore` stores JSONL sessions in `Documents/AgentScript/sessions`, tracks token state, resumes/latest/deletes, and cleans old sessions after seven days. | Epistemos owns session store path and recents; donor JSONL is either imported/migrated or used as an internal transcript codec only. | New Chat session appears in Epistemos recents, reloads transcript, token state restores, cleanup policy is owner-controlled. |
| Swarm config | Swarm exposes global provider, cloud provider, and web-search configuration with fallback order. | Epistemos Chat runtime can use Swarm as one native agent substrate, but Epistemos writes provider/cloud/web config deliberately. | Configure provider/cloud/web from Epistemos settings; Swarm task uses selected provider; reset does not orphan UI state. |
| Visual/native shell | Swift donors may donate native controls and state patterns, but the old Epistemos chat/act/chat-v1/v2 surfaces should be pruned/replaced by the new Chat scene. | Chat is rebuilt as Epistemos landing-toggle scene using code-like flat minimalism, not stock Swift donor UI and not old broken chat UI. | Home toggle opens Chat; message sends/streams; model picker works; recents work; mini/graph/note attachments use the shared scene bridge. |

### Unified Control Plane Objects To Create

These are not implementation files yet; they are the minimum concepts future
implementation should converge on.

```text
EpistemosEngineId
  chat.swift.agent
  chat.swift.swarm
  work.opengui.opencode
  work.opengui.codex
  work.opengui.claude-code
  work.opengui.pi
  work.opengui.goose
  act.goose

EpistemosSessionRecord
  id
  surface: chat | work | act
  donor: swift-agent | swarm | opengui | goose
  donorSessionId
  harnessId?
  parentSessionId?
  presentation: main | attached-mini | detached-mini
  workspace
  title
  modelSelectionId?
  capabilityPackageIds[]

EpistemosCapabilityPackage
  id
  displayName
  donorMappings[]
  mcpServers[]
  skills[]
  permissions[]
  setupSteps[]
  healthProbes[]

EpistemosCompatibilityWrite
  target: goose-config | opengui-settings | swift-mcp-config | swift-session-store
  sourceEpistemosKey
  donorKey
  readBackProbe
```

### Probe Ladder For Any Scene Replacement

Every donor surface reskin or scene replacement must climb this ladder:

1. Read donor state through the donor's real API/config path.
2. Write the same state through Epistemos control plane.
3. Read back through the donor path and prove it changed.
4. Exercise the runtime feature: send/stream/cancel, tool call, permission,
   model switch, or session operation.
5. Exercise relaunch/reopen and prove recents/session identity survive.
6. Screenshot the Epistemos scene and prove no stock donor shell appears in
   the normal path.
7. Keep the donor raw control in Advanced/Debug until the above is green for
   all normal controls.

## V2 Settings, Setup, And Pruning Control Plane

The owner's latest clarification matters: "pruning" is real, but it does not
mean amputating useful runtime capability. It means removing donor product
identity, duplicate setup burden, dead/irrelevant surfaces, stale names, and
manual wiring that Epistemos can own automatically. Capability stays; the
normal-path ontology changes.

### Settings Source Evidence

| Area | Source Evidence | Implication |
| --- | --- | --- |
| Epistemos settings shell | `SettingsView.SettingsSection` already has visible sections, MAS-safe `safeDetailSelection`, and per-clone rows `actClone`, `workClone`, `beyondClone`. | Do not add another donor settings sidebar. Fold clone settings into the existing settings skeleton with curated cards and Advanced/Debug disclosures. |
| OpenGUI settings | `settings-store.ts` stores versioned `settings.json` string values; `main.ts` exposes sync IPC get/set/remove/merge and backend config/status; frontend also uses `localStorage` for theme migration. | OpenGUI settings are a compatibility mirror, not the source of truth. Epistemos can write string keys and read back, but normal UI should not expose raw OpenGUI settings unless Advanced/Debug. |
| OpenGUI runtime setup | `WorkOpenGUISupervisor` resolves `bun`, sidecar root, data dir, bundled resources path, and fails inert when missing; OpenGUI `harness-inventory.ts` probes CLI path/version without launching project cwd. | First-run Work setup should be a readiness card: runtime available, sidecar available, engine CLIs installed/authenticated, resources loaded. Missing pieces are visible and repairable, never silently fake. |
| Goose custom distro | `CUSTOM_DISTROS.md` explicitly supports preconfigured provider/model through `init-config.yaml`, environment variables, bundled MCP extensions, UI branding, telemetry disable, recipes, REST API, and ACP. | Goose should be Epistemos-ified through intended distribution seams where possible: config/env/default extension bundle/ACP/custom UI, not random code surgery. |
| Goose settings | `utils/settings.ts` has typed desktop settings; `preload.ts` lazy-migrates localStorage and exposes `getSetting/setSetting`; `ConfigContext` reads/writes runtime config and extensions; `ModelAndProviderContext` reads/writes `GOOSE_MODEL`/`GOOSE_PROVIDER`. | Epistemos normal settings write canonical values, then compatibility-write Goose typed settings/config. Raw Goose settings remain Advanced/Debug until every normal row has read-back proof. |
| Goose setup defaults | Bundled extension JSON includes developer, computer controller, auto visualiser, memory, tutorial; custom distro docs support telemetry disabling and path isolation via environment. | Epistemos first-run can seed capability packages and disable telemetry without hiding Goose extension capability. |
| Swift donor setup | Agent `DependencyChecker` checks Xcode tools, clang, Apple Intelligence; `KeychainService` stores many provider keys under `Agent!`; `ToolPreferencesService` seeds default disabled groups/tools; `RecentFoldersService` uses UserDefaults. | Chat fusion must move service names and storage keys to Epistemos before shipping; keep donor logic but change keychain service names, defaults, and paths through adapters/migration. |
| Swift skills/session paths | Agent `SkillsService` uses `Documents/AgentScript/skills`; `SessionStore` uses `Documents/AgentScript/sessions` JSONL and token meta. | Import or repoint these paths under Epistemos vault/app support. Do not leave normal-path user data under AgentScript once Chat becomes Epistemos Chat. |

### Settings Ownership Tiers

Every donor setting must be classified into exactly one tier before UI work:

1. **Canonical Epistemos Setting**  
   User-facing normal path. Example: selected model, theme, default workspace,
   MCP capability package enabled state, permission risk profile.

2. **Compatibility Write**  
   Donor still needs a specific key/file/API. Epistemos writes it after the
   canonical setting changes and reads back to verify. Example:
   `GOOSE_MODEL`, `GOOSE_PROVIDER`, OpenGUI `settings.json` string keys,
   Swift MCP config JSON.

3. **Advanced Donor Control**  
   Real donor control that remains useful but is too donor-specific for the
   normal mental model. Example: raw Goose extension rows, OpenGUI detached
   window/debug transport, provider-specific request parameters.

4. **Debug/Witness Row**  
   Not a product control. Shows runtime path, config path, bridge health, last
   compatibility write, last read-back, logs, versions, and failure reasons.

5. **Pruned / Rebranded / Replaced Scene**  
   Donor UI/copy/branding/setup screen is removed from normal path because
   Epistemos owns an equivalent or intentionally excludes it. Must include a
   reason and a regression probe.

No setting may remain "floating." Floating settings are how the app becomes
three products with shared wallpaper.

### Compatibility Write Protocol

When Epistemos changes a fused setting, the write path should be explicit:

```text
canonicalWrite(Epistemos key)
  -> derive donor writes
  -> write donor config/API
  -> read donor config/API
  -> compare normalized values
  -> write witness row
  -> update UI health
```

Minimum fields for a compatibility write:

```text
EpistemosCompatibilityWrite
  id
  canonicalKey
  donor
  donorTarget
  donorKeyOrEndpoint
  serializedValueDigest
  readBackValueDigest
  status: pending | matched | drifted | failed
  lastAttemptAt
  lastError
  repairAction?
```

Examples:

- `models.selected.work.opengui.opencode` writes selected OpenGUI model through
  sidecar `send` options / resources-aware picker and verifies transcript
  metadata or resource selection.
- `models.selected.act.goose` writes `GOOSE_PROVIDER` and `GOOSE_MODEL` through
  Goose config APIs and verifies `ModelAndProviderContext` / ACP session state.
- `capability.epistemos.computer-control.enabled` writes Goose builtin
  `computercontroller` extension enabled state and verifies
  `configExtensionsList_unstable`.
- `mcp.epistemos.native-tools` writes OpenGUI/OpenCode MCP registration and
  Goose MCP extension config separately, then verifies both tool catalogs.
- `chat.skills.root` migrates/imports AgentScript skills into Epistemos Skills
  and verifies the donor skill manifest no longer requires the AgentScript
  path in normal operation.

### First-Run Readiness Model

The app should not show three setup wizards. It should show one Epistemos
readiness model with per-surface cards:

```text
Epistemos Readiness
  Chat
    provider ready
    local/native provider ready
    MCP ready
    skills ready
    session store ready
  Work
    OpenGUI sidecar ready
    runtime dependency ready
    harness inventory ready
    selected engine authenticated
    native MCP registered
  Act
    Goose ACP ready
    provider/model ready
    extension catalog ready
    permission bridge ready
    recipe params ready
```

Normal first-run behavior:

1. Seed Epistemos defaults.
2. Create Epistemos app support/vault roots.
3. Install or expose bundled skills/capability packages.
4. Probe dependencies without launching expensive runtimes.
5. Auto-write donor compatibility config for safe defaults.
6. Show only failed/missing actions to the user.
7. Keep donor setup screens accessible in Advanced/Debug until parity proves
   they are redundant.

### Pruning Classifier V2

Use this before deleting or hiding anything from a donor:

| Class | Keep? | Normal Path? | Example |
| --- | --- | --- | --- |
| Runtime substrate | Keep | Hidden behind Epistemos bridge | Goose ACP, OpenGUI sidecar, Swift MCP client/server |
| Capability surface | Keep | Rebranded as Epistemos capability package | Goose extensions, Swift skills, OpenGUI harnesses |
| User setting with broad meaning | Keep as canonical | Yes | model, provider, permission policy, theme, workspace |
| Donor-specific tuning | Keep | Advanced | raw provider request params, external backend, detached debug windows |
| Donor branding/copy/trademark | Remove/rebrand | No | Goose/OpenGUI/AgentScript visible names in normal path |
| Duplicate setup screen | Replace | No, unless Advanced/Debug | donor onboarding after Epistemos readiness owns setup |
| Dead or unsupported feature | Prune after evidence | No | updater/telemetry/store flows not relevant to Epistemos distribution |
| Legal/license attribution | Keep | About/Debug | upstream notices, source attribution |

### Immediate Control-Plane Fixes To Avoid Drift

These are not implementation instructions yet, but they should become the
first hardening cards before agent prompts are updated:

1. Rename settings ontology from per-clone `Act (Osaurus)` / `Work (OpenCode)`
   to surface-first `Chat`, `Work`, `Act`, with donor engines inside cards.
2. Replace stale Work settings copy that still says terminal TUI / OpenCode
   shell as the main path. Current research points to OpenGUI sidecar/WebView
   plus optional terminal/debug fallback.
3. Define one `EpistemosCapabilityPackage` schema before importing more
   donor extensions/skills/tools.
4. Define compatibility-write witness rows before hiding donor settings.
5. Move Swift donor user data/service names away from `Agent!` and
   `Documents/AgentScript/*` through migration/import adapters.
6. Use Goose custom-distro seams for branding/defaults/extension bundles,
   while preserving ACP and extension capability.
7. Treat OpenGUI string settings as compatibility state; do not make them the
   master settings database for Epistemos.

## V3 Capability Packages, Marketplace, And Alias Strategy

Current status after owner correction: **research-only / future option**.
Do not implement this as the active path yet. The active path keeps Goose,
OpenGUI, and Swift donor settings isolated and uses Epistemos for shell,
theme, routing, health, and explicit bridge links only. V3 is retained because
it explains what would be required if the owner later chooses deep settings or
marketplace fusion.

This pass answers the owner's newest uncertainty:

> If Goose becomes part of OpenGUI, do we actually keep Goose's powers, or do
> those powers disappear behind a larger UI?

The source-grounded answer is strict:

```text
Embedding a donor does not preserve capability.
Only a capability-complete adapter preserves capability.
```

OpenGUI can host multiple engines because its Work model already has a
capability matrix. Its `HarnessCapabilities` includes sessions, streaming,
message paging, models, agents, commands, compact, fork, revert, permissions,
questions, provider auth, MCP, config, and local server. The current Epistemos
OpenGUI sidecar already exposes `sessions.list`, `sessions.create`,
`sessions.open`, `send`, `waitIdle`, `abort`, `messages`, `loadResources`,
`connect`, `diagnose`, and `close`. That is good Work substrate.

Goose has a different richness profile. Its custom distro guide explicitly
supports preconfigured providers/models, bundled MCP extensions, branding,
recipes, REST, and ACP. Its desktop ACP client registers callbacks for
permission requests, elicitation forms, recipe-parameter requests, and session
updates. Its ACP session helpers list/load/create sessions, carry provider and
model metadata, load recipe metadata and extension results, and its prompt
helper supports prompt, cancel, and steer.

Therefore a Goose row inside Work is only truthful if it is a Goose-complete
adapter, not a prompt-only bridge.

### V3 Source Evidence

| Source | Evidence | Fusion implication |
| --- | --- | --- |
| OpenGUI capabilities | `HarnessCapabilities` names sessions, streaming, message paging, models, agents, commands, compact, fork, revert, permissions, questions, provider auth, MCP, config, and local server. | Work can show controls based on real feature flags. Add Goose as a first-class engine only if Goose-backed flags are backed by adapter calls. |
| OpenGUI sidecar | `og-sidecar.mjs` exposes init/connect/diagnose/session list/create/open/send/wait/abort/messages/loadResources/close over NDJSON. | Epistemos can safely supervise Work through a narrow process bridge, but the bridge must grow deliberately when new engine capabilities are added. |
| Goose custom distro | `CUSTOM_DISTROS.md` lists preconfigured provider/model, MCP extension bundles, UI branding, recipes/sub-recipes/subagents, REST, and ACP. | Goose should be Epistemos-ified through supported distro seams before invasive changes: config/env, extension bundles, recipes, ACP, and custom UI. |
| Goose ACP connection | `acpConnection.ts` initializes ACP with MCP host capabilities and callbacks for permission, elicitation, recipe params, and session updates. | These callbacks are mandatory normal-path or native-sheet surfaces. Hiding them breaks Goose. |
| Goose sessions/prompt | `acp/sessions.ts` lists/loads sessions with working dir, provider/model, recipe, extension results; `acp/prompt.ts` prompts, cancels, and steers. | Recents, model picker, recipe state, extension state, cancel, and steer must be visible or available in Epistemos UI/Advanced. |
| Epistemos native tools MCP | `WorkToolMCPCore` implements `initialize`, `tools/list`, and `tools/call` over the full native Omega tool catalog through `LocalAgentToolExecutor`. | The app already has the right pattern: keep native capability in Epistemos, expose it to donors through MCP compatibility surfaces. |
| Epistemos Work skills | `WorkSkillsProvisioner` copies vault/bundled skills into `.opencode/skills` without clobbering user skills. | Capability package installs should write donor-compatible files while Epistemos remains the owner of the catalog. |
| Epistemos Work resources | `WorkEngineResources` decodes OpenGUI provider/model, agent, command, and default-model resources into native picker-safe value types. | Donor raw JSON should not reach UI. Convert into typed Epistemos state, then render in the shared minimal scene. |

### Capability Package Schema V3

The package is the unit that lets the app stay minimal without losing donor
features. A package is not "an extension in Goose" or "an MCP in OpenGUI." It
is an Epistemos-owned capability that may write to several donor runtimes.

```text
EpistemosCapabilityPackage
  id
  displayName
  shortDescription
  surfaces: chat | work | act | mini | graph | note
  packageKind:
    nativeToolPack
    mcpServer
    skillBundle
    workflowRecipe
    modelProvider
    workHarness
    gooseExtension
    swiftToolGroup
    permissionPolicy
    setupBundle
  epistemosAuthority:
    settingsKey
    permissionProfileKey?
    modelProfileKey?
    sessionScopePolicy?
  donorMappings:
    opengui:
      harnessIds[]
      mcpEntries[]
      pluginKeys[]
      commands[]
      resourceProbe
    goose:
      extensionNames[]
      builtinNames[]
      mcpServers[]
      recipeIds[]
      configKeys[]
      acpProbe
    swiftChat:
      mcpServers[]
      toolGroupIds[]
      skillPaths[]
      providerIds[]
      keychainAliases[]
  setup:
    dependencies[]
    autoInstallPolicy
    ownerConsentRequired
    repairActionId?
  compatibilityWrites[]
  readBackProbes[]
  runtimeProbes[]
  normalControls[]
  advancedControls[]
  debugWitnesses[]
  pruneRules[]
  attribution
```

V3 invariant:

```text
No normal UI row may claim a capability package is enabled until every required
compatibility write and read-back probe for the selected surface has passed.
```

If a package only works for one surface, the UI must say that. Example:
`Epistemos Native Tools` may be green for Work after OpenGUI/OpenCode MCP
registration succeeds, yellow for Act until Goose MCP extension registration
succeeds, and green for Chat only after the Swift MCP client/server path
discovers the same tools.

### Goose-In-OpenGUI Capability Rule

If Goose is added to OpenGUI, the Work engine picker may show a Goose row only
after the bridge covers the following minimum set:

```text
Goose Work Adapter Minimum
  connect/status
  list sessions
  create session
  load session
  send prompt
  stream updates
  cancel prompt
  steer prompt
  read messages/history
  expose provider/model metadata
  update provider/model where supported
  expose enabled extensions for the session
  create session with selected extensions
  create/load recipe session
  surface recipe-param requests
  surface permission requests
  surface elicitation requests
  resolve permission/elicitation/recipe callbacks
  fork/truncate/edit/resend if enabled
  export/import/delete/rename where enabled
  report unsupported features as disabled, not hidden
```

This list is intentionally longer than OpenGUI's current sidecar shape because
Goose's value is not just "answer a prompt." Goose's value includes its
extension, recipe, permission, and session machinery. A Goose adapter that only
implements `send`/`cancel` should be labeled `experimental prompt bridge`, not
`Goose engine`.

### Epistemos Capabilities Browser

The owner wants minimal setup, Epistemos naming, and no scattered donor
marketplaces. The normal path should therefore be one Epistemos Capabilities
browser.

Normal browser groups:

```text
Capabilities
  Native Tools
  MCP Servers
  Skills
  Work Engines
  Act Extensions
  Chat Tool Groups
  Recipes / Workflows
  Providers / Models
  Permissions
```

The browser is not allowed to simply hide donor stores. It must import them:

- Goose extension catalog becomes Epistemos capability packages with Goose
  aliases and extension write/read-back probes.
- OpenGUI harnesses, commands, and MCP/plugin settings become Work capability
  packages.
- Swift Chat MCP servers, skills, provider definitions, and tool groups become
  Chat capability packages.
- Epistemos native tools remain first-class packages and can be projected into
  OpenGUI/OpenCode, Goose, and Swift Chat through donor adapters.

Advanced/Debug should still expose donor raw state until parity is proven:

```text
Advanced
  Raw OpenGUI settings/resources
  Raw Goose extensions/config
  Raw Swift MCP config/provider keys
  Compatibility writes
  Read-back probes
  Runtime logs
  Upstream attribution/licenses
```

### Name And Alias Strategy

The app should aggressively remove donor product identity from the normal path,
but it should not rename protocol keys blindly. The correct pattern is display
alias first, compatibility key second.

```text
Display name: Epistemos Native Tools
Canonical package id: capability.epistemos.native-tools
Donor aliases:
  OpenCode/OpenGUI MCP: epistemos-native
  Goose extension: epistemos-native-tools
  Swift MCP config id: epistemos-native-tools
Debug/source labels:
  WorkToolMCPCore
  Goose MCP extension
  Agent/AgentKit MCP client
```

Rule:

- User-facing labels become Epistemos.
- Canonical package ids become Epistemos.
- Wire IDs stay donor-stable until an adapter proves renaming is safe.
- Raw donor names may appear in Diagnostics/Advanced/source attribution, not as
  the app's product ontology.

Do not replace every donor key with `Epistemos` at once. Some runtimes rely on
exact keys such as `GOOSE_MODEL`, `GOOSE_PROVIDER`, harness ids, session ids,
or config file names. These are compatibility keys, not user-facing product
truth. Changing them without read-back probes will recreate the old Act
failure: pretty UI, missing engine power.

### Provider And Auth Fusion

Provider/auth has to be unified gently because donor runtimes often own secret
stores or auth flows.

Future-only V3 strategy, not the active implementation path:

1. In that future plan, Epistemos Settings would own the visible provider
   account list.
2. Each provider row shows surface compatibility: Chat, Work, Act.
3. Compatibility adapters write donor-specific provider/model state:
   `GOOSE_PROVIDER`, `GOOSE_MODEL`, OpenGUI selected model objects, Swift
   provider configs/keychain aliases.
4. Donor-specific auth flows stay in Advanced until Epistemos can launch and
   observe them safely.
5. A provider row is green only if the selected surfaces can actually use it.

Important distinction:

```text
One provider account surface does not mean one secret store immediately.
It means one visible control plane with donor-specific compatibility stores
under it, each with read-back and runtime probes.
```

This avoids over-fusing secrets early and breaking the donor runtime.

### Setup And Auto-Install Package Flow

First-run setup should be package-driven:

```text
for each default package:
  check dependency probes
  create app-support roots
  copy/import Epistemos skills
  write canonical Epistemos setting
  write donor compatibility config
  read back donor config
  run cheap runtime probe
  mark ready / repairable / unavailable
```

Examples:

```text
Package: Epistemos Native Tools
  Work:
    start WorkNativeMCPServer
    register OpenGUI/OpenCode MCP entry
    call tools/list
  Act:
    register Goose MCP extension
    list Goose extensions/config
    start a session with extension enabled
  Chat:
    add Swift MCP config entry
    discover tools/resources
```

```text
Package: Epistemos Computer Control
  Work:
    native MCP exposes see/click/type/scroll/keys/screenshot
  Act:
    Goose computercontroller or Epistemos native-tools extension enabled
  Chat:
    Swift tool group enabled
  Permissions:
    Accessibility/screen capture/microphone rows report real OS state
```

```text
Package: Epistemos Skills
  Work:
    WorkSkillsProvisioner writes `.opencode/skills`
  Act:
    matching recipes/sub-recipes or skills docs are exposed through Goose
  Chat:
    Swift skill root is imported/repointed under Epistemos, not AgentScript
```

The setup flow should be optimistic but honest: auto-configure what can be
configured safely, and show exact missing pieces for everything else.

### Pruning Under V3

V3 pruning means four different actions, not one:

1. **Prune product identity**  
   Remove donor-branded normal-path labels, onboarding, update prompts, and
   duplicate app-shell language.

2. **Prune duplicate setup**  
   Replace donor setup pages with Epistemos readiness cards once equivalent
   write/read/probe coverage exists.

3. **Prune dead or unwanted capability**  
   Remove only after source/license/policy/user-intent evidence says the app
   should not carry it.

4. **Prune visible clutter but keep runtime control**  
   Move donor-specific controls to Advanced/Debug, with searchable witness
   rows and exact compatibility keys.

Do not use "prune" to mean "hide the donor page while leaving no Epistemos
replacement." That is capability loss.

### Minimal UI Without Capability Loss

The app can look extremely small if the control plane is strong. The normal UI
does not need every donor knob visible at once. It needs:

- one model/provider picker that accurately reflects the selected surface;
- one capability/package browser;
- one permission sheet language;
- one session/recents model;
- one setup/health model;
- one Advanced escape hatch for raw donor state;
- one Diagnostics/witness view proving the fused state.

Everything else can be collapsed, searched, deferred, or hidden behind mode
context. Minimalism is safe only when the hidden state has probes.

### V3 Non-Drift Tests

Before declaring any surface "Epistemos-ified," prove these:

1. The normal scene contains Epistemos chrome and no stock donor shell.
2. The donor runtime can still perform its strongest native flow:
   - Work: selected harness list/create/send/stream/cancel/resources.
   - Act: Goose ACP session + extension + permission/elicitation/recipe flow.
   - Chat: Swift streaming/tool/MCP/provider flow.
3. A capability package toggled in Epistemos writes to the donor, reads back,
   and survives relaunch.
4. Recents reopen the exact donor session through the unified session id.
5. Model/provider selection changes the actual donor runtime, not only the UI
   pill.
6. A missing dependency produces a repairable Epistemos row, not a dead button
   or stock donor setup screen.
7. Advanced/Debug still exposes enough raw donor state to debug drift.

### V3 Decision

Future-only option: use OpenGUI as the Work control plane, Goose as a full
engine and scene donor, and Epistemos as the owner of final naming, settings,
packages, setup, permissions, theme, and session identity.

This does not make Goose subordinate in capability. It makes Goose subordinate
in product identity. The bridge must be ACP-complete enough that Goose's
capabilities remain reachable from Epistemos surfaces. If a future
implementation cannot expose Goose permissions, extensions, recipes, session
lifecycle, model state, and callbacks, then Goose should remain a separate Act
surface until the adapter is complete, rather than being hidden inside Work and
quietly weakened.

## V4 Active Path - Isolated Donor Shells, Epistemos Outer Scene

This is the active path after the owner correction.

Owner's intended build order:

```text
Phase 1 - Isolated visual recode
  Full clone each donor.
  Keep each donor's runtime/settings/config in its own shell.
  Recode/reskin each visible donor UI into OpenCode-like minimalism:
    flat
    sparse
    model-space aware
    theme-aware
    no gradients
    no stock donor chrome in the normal scene where safe

Phase 2 - Home-window embedding
  Embed Chat, Work, and Act as switchable surfaces inside the Epistemos home
  window.
  The home window owns navigation and framing, not donor settings truth.
  Each surface keeps its own settings/config panels reachable from inside that
  surface.

Phase 3 - Selective hardening/fusion
  Later, choose one setting or feature at a time to connect to Epistemos.
  Add a bridge, write/read-back probe, runtime probe, and relaunch probe.
  Only then may that specific setting/feature appear as Epistemos-owned.
```

Do this now:

```text
Epistemos landing / outer chrome
  owns navigation, theme, top-level mode toggle, window framing, launch state,
  screenshots/visual coherence, and health links.

Chat donor
  remains its own cloned/forked Swift-derived surface with its own settings
  until fusion is explicitly reopened.

Work donor
  remains its own OpenGUI-derived surface with its own settings/runtime config.
  Epistemos may reskin/frame it and link to its settings, but should not absorb
  those settings into Epistemos Settings yet.

Act donor
  remains its own Goose-derived surface with its own Goose settings,
  extensions, provider/model pages, recipe pages, permission machinery, and
  runtime config. Epistemos may reskin/frame it, but should not merge Goose
  into OpenGUI or make Goose settings part of Epistemos Settings yet.
```

The safe current architecture is:

```text
Epistemos shell
  Chat scene adapter -> cloned Swift Chat app/surface
  Work scene adapter -> cloned OpenGUI app/surface
  Act scene adapter  -> cloned Goose app/surface
```

Where "adapter" means:

- launch the donor cleanly;
- pass theme tokens if safe;
- pass workspace/vault path if safe;
- expose health/status;
- deep-link into donor settings instead of absorbing them;
- preserve donor runtime behavior;
- avoid stock donor branding where a shallow reskin is safe;
- keep donor settings accessible in their original/isolated shell.

Where "adapter" does **not** mean:

- rewrite donor settings into Epistemos Settings;
- rename runtime config keys globally;
- force one provider store;
- fuse Goose into OpenGUI;
- hide donor settings before equivalent controls exist;
- invent a shared marketplace as the active implementation target.

### V4 Visual Coherence Contract

The user-facing target is still one coherent Epistemos app. Isolation-first
does not mean "ship three visually unrelated apps." It means visual and routing
coherence without deep state fusion.

Current allowed changes:

- shared launch/home toggle for Chat, Work, Act;
- shared Epistemos window chrome or framed scene container;
- shared flat/code-like theme tokens;
- shared font and block/pixel motif where easy;
- shallow copy/label rebrand where it does not touch runtime semantics;
- donor-specific settings reachable from each surface;
- top-level status badges that say whether each donor is ready.

Current disallowed changes:

- moving Goose settings into Epistemos Settings;
- moving OpenGUI settings into Epistemos Settings;
- pretending a global Epistemos setting has updated donor config without a
  donor read-back probe;
- adding Goose as an OpenGUI row and calling it complete with only send/cancel;
- hiding a donor provider/extension/MCP/settings page because Epistemos has a
  future plan to replace it.

### V4 Completion Tests

For the current isolated-shell phase, the proof target is simpler:

1. Chat, Work, and Act each launch from the Epistemos landing toggle.
2. Each surface visibly follows the Epistemos visual theme enough to feel
   intentional.
3. Each surface still exposes its own settings/configuration path.
4. Each surface can run its donor's baseline runtime flow without relying on a
   fused Epistemos settings database.
5. Health/status rows link to the donor's own repair/setup/settings location.
6. No surface falsely claims that a global Epistemos setting controls donor
   behavior unless that write/read-back bridge is actually implemented.

This phase is allowed to look like three Epistemos-framed engines. It is not
allowed to become three broken engines hidden behind a fake unified settings
story.

## V5 Home Embedding And OpenCode-Minimal Visual Recode

This section grounds V4 in the current worktree.

### Current Code Reality

The current app still has a two-mode home route:

- `WorkspaceModeKind` is only `act` and `work`.
- `WorkspaceModeSelection` persists a single `epistemos.workspace.mode`.
- `HomeRouter` switches between `LandingView` / `ChatView` / Act chat /
  `WorkTerminalHostView`.
- `LandingView` has an Act-specific `onSubmitActPrompt` path.
- `ChatRouteView` exists as a new compact Swarm-backed Chat surface, but the
  root route still falls back to the older `ChatView` in several branches.
- Work has multiple competing hosts: `WorkTerminalHostView`,
  `WorkWebSurfaceView`, and `WorkEngineSurfaceView`.
- `WorkWebSurfaceView` already has a WebView/loopback style for donor UI
  embedding and CSS token injection.
- `WorkEngineSurfaceView` is useful as native proof of OpenGUI sidecar control,
  but it is a native reimplementation, not the full isolated donor UI.

Implication:

```text
The current home route is not yet the owner's corrected three-surface model.
It must become Chat / Work / Act, not Act / Work with Chat collapsed into Act.
```

### Required Active Route Model

Do not keep overloading `act` to mean "general chat-like thing." The landing
mode model should become three explicit choices:

```text
EpistemosHomeSurface
  chat
  work
  act
```

Each choice launches an isolated donor shell:

```text
chat -> Swift Chat full clone / selected Swift donor fusion
work -> OpenGUI full clone / selected Work donor fusion
act  -> Goose full clone / selected Act donor fusion

Equivalent explicit labels:
Chat -> Swift Chat full clone
Work -> OpenGUI full clone
Act -> Goose full clone
```

The home window owns:

- which surface is selected;
- the entry transition;
- outer background/window identity;
- shared route animation;
- high-level health status;
- optional "open donor settings" affordance.

The home window does not own:

- donor provider pages;
- donor extension pages;
- donor recipe pages;
- donor raw settings;
- donor session stores;
- donor marketplace/internal installers.

### Embedding Topology

Use the least invasive embedding method that preserves each donor's real UI
and settings.

```text
Chat embedding
  Preferred: native Swift surface in the same home window.
  Keep: Swift donor settings and provider/tool state isolated.
  Avoid: old ChatView/Act duality unless that code is deliberately chosen as
  the Chat donor shell.

Work embedding
  Preferred: WebView/loopback full OpenGUI surface, reskinned at the donor CSS
  layer, mounted inside the Epistemos home window.
  Keep: OpenGUI settings/config/runtime inside OpenGUI.
  Avoid: replacing Work with a native Swift sidecar-only surface if that drops
  OpenGUI's own settings, pages, and workbench features.

Act embedding
  Preferred: Goose full UI/distro surface reskinned inside Goose's React/CSS
  layer, mounted as an Epistemos-framed surface.
  Keep: Goose settings, extensions, recipes, provider pages, permission flow,
  ACP/session machinery, and runtime config inside Goose.
  Avoid: fusing Goose into OpenGUI, or exposing only prompt/send/cancel.
```

Fallback order for web/electron donors:

1. Native WebView/loopback if the donor can run as a local web surface.
2. Embedded web app with app-managed local server and isolated app-support data.
3. Child process/window with Epistemos-framed launch and visual coherence if a
   true in-window embed is not yet reliable.
4. Only later, selective native bridge for individual settings/features.

### Visual Recode Contract

"Native as possible" in this phase means **visual and interaction native to
Epistemos**, not "rewrite every donor in Swift."

Every donor surface should be recoded/reskinned toward this shared grammar:

```text
OpenCode-minimal grammar
  flat backgrounds
  sparse information density
  strong monospace/pixel accent layer
  no decorative gradients
  no generic SaaS card gloss
  no over-rounded AI chat bubbles
  small model-space controls
  clear keyboard/input affordances
  block or code-like caret where possible
  restrained icons
  donor settings retained but visually simplified
```

Surface-specific current seams:

- Work native code already has `WorkPixelFont` and `WorkSPAReskin`. These show
  the correct visual direction: monospace, pixel accents, square corners,
  shadow removal, and CSS variable override.
- OpenGUI itself already has Tailwind/theme variables in `styles/globals.css`;
  those should be the donor-native place to impose OpenCode minimalism when
  using the full OpenGUI UI.
- Goose has `theme/theme-tokens.ts`, `ThemeContext`, and a React route shell in
  `App.tsx`; those are the donor-native places to recode Goose's UI while
  keeping Goose settings isolated.
- Swift Chat donors can be recoded directly in SwiftUI because they are already
  native enough; however, their own settings/provider/tool state should remain
  isolated in the Chat shell during this phase.

### Anti-Regression Rules

Do not repeat the Osaurus failure mode:

- Do not mount a donor backend under an Epistemos-looking input while leaving
  donor capability unreachable.
- Do not fuse Goose into OpenGUI in Phase 1.
- Do not restore the old Epistemos chat as the Act surface.
- Do not replace a full donor UI with a minimal native surface if that drops
  donor settings, provider pages, extensions, recipes, or runtime controls.
- Do not hide donor settings because a future Epistemos Settings bridge is
  planned.
- Do not make a single global picker pretend to control donor runtimes in this
  phase.
- Do not keep the home route as only two choices once the target is explicitly
  Chat / Work / Act.

### V5 Implementation Queue Shape

This is the safe task shape for agents later:

```text
1. Route inventory
   Identify every current branch from Landing/Home into Chat, Work, and Act.
   Mark whether it opens old ChatView, new ChatRouteView, terminal Work,
   OpenGUI/Web Work, or Goose/Act.

2. Three-surface selector
   Add an explicit Chat / Work / Act home selection model.
   Do not wire global settings fusion.

3. Isolated donor hosts
   For each surface, pick the donor host that preserves the most donor UI and
   settings.

4. Visual recode inside donor
   Apply OpenCode-minimal theme inside that donor's own UI layer.

5. Home embedding
   Mount the donor host inside the Epistemos home window.

6. Settings escape hatch
   Each embedded surface must still have a working path to its own settings.

7. Baseline runtime proof
   Each surface must run one donor-native baseline flow.

8. Later hardening
   Only after the above is visually stable, connect individual settings/features
   back to Epistemos one at a time.
```

### V5 Completion Tests

The active phase is complete only when:

1. The landing/home window shows three first-class choices: Chat, Work, Act.
2. Selecting each choice embeds that surface in the home window.
3. Each surface uses OpenCode-minimal Epistemos visual grammar.
4. Each surface keeps a reachable donor-specific settings/configuration path.
5. Work opens the full Work donor UI or an explicitly owner-approved full
   feature-preserving host, not only a reduced native prompt surface.
6. Act opens the full Goose donor UI or an explicitly owner-approved full
   feature-preserving host, not only a prompt bridge.
7. Chat opens the selected Swift Chat donor surface, not the accidental old
   Act/Chat hybrid.
8. No global Epistemos Settings row claims ownership of a donor setting without
   a later selective bridge and read-back probe.

Near-term action:

1. Continue private mapping research.
2. Keep V2/V3 as future fusion research only.
3. If public agent prompts are updated, tell them the current path is
   isolation-first: reskin/frame full clones and keep donor settings inside
   their own donor shells for now.
4. When ready, update each agent prompt with one shared rule:

```text
Full clone currently means isolated donor settings with Epistemos outer chrome.
Preserve useful donor capability and donor settings/runtime config. Make the
surface look and feel Epistemos-framed, but do not absorb Goose/OpenGUI/Swift
settings into Epistemos Settings unless a later explicit directive reopens that
fusion work.
```
