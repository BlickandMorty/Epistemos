# Practical Full-Port And Hardening Plan - 2026-06-24

> 🟡 **PARTIAL-SUPERSEDE 2026-07-02 (OpenChamber pivot).** Hardening discipline durable; the "full-port of Goose as the reskin surface" framing is DEAD. Agent surface = OpenChamber (Pro, vendored fork+overlay) / June+goose-in-process (MAS); goose = one engine. Canon: memory `project_ui_base_pivot_openchamber_2026_07_02`.

> 🛑 **SUPERSEDED 2026-06-29 — NOT a current paste-prompt.** This 06-24 full-port/clone-infusion plan (Osaurus Act,
> OpenChamber/OpenWork, "full clones first") is overtaken by the **2026-06-25 surface lock** (Act = Goose, Work =
> OpenGUI/OpenCode), the **2026-06-28 Goose-only scope lock**, and the **2026-06-29 Option 1** canon. The only prompts
> to paste are `docs/prompts/PROMPT_PLAN_{1_GOOSE,2_EDITOR,3_CAPABILITIES}.md`; canon that wins:
> `docs/handoffs/GOOSE_NATIVE_UI_DECISION_2026_06_29.md` + `docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`.
> The older intra-06-24 "Supersession note" below is kept for nuance — its target is itself a stale 06-24 doc.

> Supersession note: the owner's latest correction supersedes any language in
> this file that sounds like "thin native shell + hidden donor engine." Read
> `docs/handoffs/AUTHORITATIVE_FULL_CLONE_NATIVE_INFUSION_PLAN_2026_06_24.md`
> first. The current plan is full clones/full ports first, then Epistemos-native
> or Epistemos-themed simplification/reskin; Osaurus is not the future Act
> architecture.

## Why This Exists

This consolidates the Codex research on:

- OpenCode / OpenWork / OpenChamber for Work.
- Osaurus / Epistemos Act / new Swift agent repos for Act.
- The owner clarification that a thin "native shell over donor engine" has
  repeatedly failed because agents miss hidden donor surfaces.

Use this as the Claude handoff when the API recovers.

## Owner Decision

Optimize for practical completeness first, native purity second.

The ideal final app is still Epistemos-native/pixel-flat in feeling, but the
implementation path should be fail-safe:

- full donor clone / port / inventory,
- then Epistemos-native or Epistemos-themed reskin,
- with every donor feature tracked in a parity ledger.

The previous "just keep my app shell and wire the backend" direction was too
easy for agents to misread. They kept the shell but dropped donor features:
MCP, skills, plugin persistence, permissions, popovers, settings, streaming
states, model pickers, sandbox/dependency flows, and session behavior.

So the rule is now:

> Full donor capability port first. Epistemos-native/pixel reskin second. No
> final donor UI leakage. No hidden omissions.

## Existing Saved Research

Read these before coding:

- `docs/handoffs/OPENWORK_OPENCHAMBER_CODE_STUDY_HANDOFF_2026_06_24.md`
- `docs/handoffs/ACT_OSAURUS_SWIFT_AGENT_CODE_STUDY_HANDOFF_2026_06_24.md`

Temporary source-study clones already used:

- `/tmp/epistemos-opencode-donor-audit/openwork`
- `/tmp/epistemos-opencode-donor-audit/openchamber`
- `/tmp/epistemos-swift-agent-donor-audit/agent`
- `/tmp/epistemos-swift-agent-donor-audit/1amageek-SwiftAgent`
- `/tmp/epistemos-swift-agent-donor-audit/SwiftedMind-SwiftAgent`
- `/tmp/epistemos-swift-agent-donor-audit/Swarm`
- `/tmp/epistemos-swift-agent-donor-audit/SwiftAIAgent`
- `/tmp/epistemos-swift-agent-donor-audit/AgentSDK-Swift`

If those `/tmp` clones are gone, reclone and record commit hashes before using
anything.

## Global Strategy

There are two separate but similar tracks:

1. Work / OpenCode:
   - Harden current hidden OpenCode integration first.
   - Then clone/port OpenWork as the primary capability donor.
   - Use WebKit or native shell pragmatically for the GUI, styled as Epistemos
     flat/pixel UI.
   - Fuse selected OpenChamber pieces where they solve real robustness gaps.

2. Act / Osaurus:
   - Keep Osaurus complete as the current Act capability donor/engine.
   - Build a complete Osaurus surface inventory.
   - Re-express every Osaurus feature in Epistemos ChatView/Landing/InputBar
     and settings.
   - Use the Swift agent repos as hardening donors and possible future lanes,
     not immediate visual replacements.

## Work: Best Path

### Phase 0 - Harden Current OpenCode Seam Before Large GUI Work

Goal: stop the known regressions before adding another full UI layer.

Repair/harden:

- OpenCode runtime discovery and launch.
- OPENCODE_CONFIG persistence.
- MCP install/list/toggle persistence.
- Epistemos vault/root exposure.
- Epistemos skills discovery.
- recent Work sessions.
- permissions and working-directory selection.
- launch health/restart behavior.
- hidden TUI escape hatch.

Relevant current Epistemos files:

- `Epistemos/Work/WorkOpenCodeRuntime.swift`
- `Epistemos/Work/WorkOpenCodeShell.swift`
- `Epistemos/Work/WorkTerminalView.swift`
- `Epistemos/Work/WorkOpenCodeShellGateStatus.swift`

Do not build a large new GUI until this seam can reliably launch, persist
config, and expose Epistemos context.

### Phase 1 - Full OpenWork Port / Reskin

After the hidden OpenCode seam is hardened, clone/vendor OpenWork as the primary
Work donor.

Why OpenWork first:

- It directly addresses the current pain:
  MCP installs do not persist, skills are not discoverable, plugins/providers
  are not app-owned, OpenCode config is not durable enough, and Work does not
  feel connected to Epistemos.

Source findings:

- OpenWork has app-owned runtime OpenCode config stored per workspace.
- It persists MCP/provider/plugin/default-agent/external-directory state.
- It scans skill roots that overlap with the owner needs.
- It manages `opencode serve` with loopback credentials.

Implementation style:

- A full port is allowed and preferred for completeness.
- Final visible UI must be Epistemos flat/pixel art, not OpenWork branding.
- WebKit is acceptable if it keeps feature topology intact and is faster than
  reimplementing everything natively.
- Native Swift should own privileged/security-adjacent flows where practical:
  file access, keychain, permissions, app settings, vault roots, biometrics,
  and OS prompts.

The correct phrasing for Claude:

> Clone OpenWork verbatim enough to preserve every feature and state model, then
> reskin/rehost it as Epistemos Work with WebKit/native wrappers and flat pixel
> chrome. Do not cherry-pick only the obvious UI.

### Phase 2 - Fuse OpenChamber Selectively

OpenChamber is not useless. It should not lead the architecture, but it has
specific parts worth harvesting:

- phased bootstrap,
- runtime fetch URL/auth/header repair,
- in-flight GET coalescing,
- directory-scoped clients,
- streaming state throttling,
- reconnect grace before send failures,
- permission/question routing,
- mini-chat same-session switching,
- duplicate-window prevention,
- focus/open-main behavior,
- session/diff/worktree/review layout ideas.

Use OpenChamber if and only if a parity ledger item needs one of those behaviors.
Do not clone Chamber wholesale before OpenWork unless the active task is purely
visual/session GUI research.

Short answer:

- OpenWork is the main clone.
- OpenChamber is a robustness and UX parts donor.
- Official OpenCode stays the behavior/source-of-truth underneath.

## Act: Best Path

### Phase 0 - Freeze Osaurus Surface Inventory

Before further visual changes, inventory every Osaurus surface:

- chat events,
- streaming/progress/prefill/stats states,
- model picker,
- toolbar buttons,
- slash commands,
- tools,
- skills,
- plugins,
- agents,
- MCP providers,
- computer use,
- macOS permissions,
- tool approval prompts,
- secret prompts,
- clarify prompts,
- privacy review prompts,
- sandbox/dependency setup,
- provider/runtime settings,
- memory,
- identity/storage,
- voice,
- recent/saved sessions.

Each item needs:

- donor source file/line,
- Epistemos target component,
- engine hook,
- visual status,
- verification proof requirement.

### Phase 1 - Keep Epistemos Chat As Final Visual Baseline

Unlike Work, the owner already has a strong Act visual target:

- `Epistemos/Views/Chat/ChatView.swift`
- `Epistemos/Views/Chat/ChatInputBar.swift`
- `Epistemos/Views/Landing/LandingView.swift`

But the practical lesson still applies: do not make a thin adapter. Keep
Osaurus complete as donor inventory while re-expressing every visible/control
surface inside Epistemos UI.

### Phase 2 - Use Existing Osaurus Headless Bridge

Osaurus already exposes useful headless APIs:

- `EpistemosOsaurusChatSessionBridge.streamTurnEvents`
- `EpistemosOsaurusChatSessionEvent.textDelta`
- `thinkingDelta`
- `toolStarted`
- `toolCompleted`
- `generationStats`
- native secret prompt presenter
- native clarify prompt presenter

The job is to render these as Epistemos-native surfaces:

- visible text in Epistemos bubbles,
- hidden/collapsible thinking,
- tool chips or native activity rows,
- stats as metadata, not transcript text,
- permission/secret/clarify/privacy prompts as native sheets/popovers.

### Phase 3 - Finish Settings and Capability Surfaces

Use `EpistemosOsaurusManagementPresenter` as the exhaustive native management
API:

- `actSettingsSnapshot`
- `modelPicks`
- `setCurrentModel`
- `providerRuntimeSnapshot`
- `connectMCPProviders`
- `systemPermissionRows`
- `toolPermissionRows`
- `skillRows`
- `pluginRows`
- `agentRows`
- `computerUsePolicySnapshot`
- `privacyFilterSnapshot`
- `dependencySnapshot`
- `repairSandboxPluginDependencies`

Do not create an Osaurus settings island. The final settings surface is
Epistemos Settings with Act tabs/sections.

### Phase 4 - Swift Agent Repos Are Donors, Not Immediate UI Replacements

Swift repos studied:

- Agent! (`macos26/Agent`): best native app/capability checklist, but not
  visually Epistemos.
- 1amageek SwiftAgent: strongest permission/sandbox/MCP/skills donor and
  possible future Act engine lane.
- Swarm: strongest durable workflow/memory/fallback/guardrails donor.
- SwiftedMind SwiftAgent: clean streaming/transcript/cloud adapter reference.
- SwiftAIAgent and AgentSDK-Swift: tertiary study-only references.

Do not replace Act with these visually. Use them after Osaurus parity is
inventoried, or as future engine lanes behind the same Act contract.

## Nativeness Vs Practicality

The correct optimization is:

1. Practical completeness.
2. Hardened behavior.
3. Epistemos visual fit.
4. Native implementation where it does not destroy parity.

Native Swift is best for:

- app chrome,
- settings,
- permissions,
- file/folder grants,
- keychain/biometric approvals,
- system popovers,
- model picker wrappers,
- recents/session ownership,
- security-sensitive flows.

WebKit is acceptable for:

- large donor GUI surfaces that would otherwise be reimplemented incompletely,
- OpenWork-style workspaces,
- complex diff/session/review surfaces,
- fast reskinning with pixel-flat CSS,
- parity-first visual inventory.

The final app can still feel native if WebKit is used as a contained Work
surface with Epistemos chrome around it and native OS/security flows outside it.

## What Chamber Has That May Matter

OpenChamber likely matters for:

- mini chat/session switching,
- streaming status correctness,
- workspace/session routing,
- diff/worktree/review layouts,
- startup/fetch robustness,
- permission/question routing.

OpenChamber likely does not replace:

- OpenWork runtime config persistence,
- MCP/skill/plugin app-owned config,
- OpenCode lifecycle hardening,
- Epistemos recents/settings/permissions,
- the overall Work architecture.

So "OpenWork then selected Chamber" is good.

## Immediate Next Queue

1. Preserve this plan and the two research handoffs.
2. Harden current OpenCode seam before adding GUI weight.
3. Create Work donor parity ledger from OpenWork.
4. Create Act donor parity ledger from Osaurus.
5. Only then start full OpenWork port/reskin.
6. Fuse OpenChamber only for named ledger gaps.
7. Use SwiftAgent/Swarm as Act hardening donors after Osaurus parity is visible.

## Claude Prompt

Use this prompt directly:

```text
You are continuing Epistemos on main. Read:

- docs/handoffs/PRACTICAL_FULL_PORT_AND_HARDENING_PLAN_2026_06_24.md
- docs/handoffs/OPENWORK_OPENCHAMBER_CODE_STUDY_HANDOFF_2026_06_24.md
- docs/handoffs/ACT_OSAURUS_SWIFT_AGENT_CODE_STUDY_HANDOFF_2026_06_24.md
- /Users/jojo/.codex/attachments/6b80a1ff-41ce-471b-9106-7db75c8260c3/goal-objective.md

Owner clarification: optimize for practical completeness, not maximum native
purity. Past thin-native-shell attempts failed because agents missed donor
features. Use full donor clone/port/reskin with parity ledgers.

Work path:
1. Harden current hidden OpenCode seam first.
2. Clone/vendor OpenWork as the primary Work capability donor.
3. Preserve every OpenWork capability in a parity ledger.
4. Rehost/reskin it as Epistemos Work using WebKit/native wrappers and
   flat/pixel Epistemos chrome.
5. Fuse OpenChamber only for concrete gaps: mini-chat/session switching,
   streaming, bootstrap, fetch coalescing, permission routing, diffs/worktrees.

Act path:
1. Keep Osaurus complete as the current Act donor/engine.
2. Inventory every Osaurus surface and capability.
3. Render all of it through Epistemos ChatView/ChatInputBar/LandingView and
   Epistemos Settings.
4. Use SwiftAgent/Swarm/Agent! as hardening donors or future engine lanes only
   after Osaurus parity is explicit.

Do not claim done without code evidence and visual proof. Do not turn donor UI
into final product chrome. Do not do a thin adapter that drops hidden surfaces.
```
