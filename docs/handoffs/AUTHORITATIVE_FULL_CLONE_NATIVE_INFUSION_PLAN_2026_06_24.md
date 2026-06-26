# Authoritative Full-Clone Native Infusion Plan - 2026-06-24

## Supersedes

This supersedes the older "native shell + donor engine" interpretation in
`PRACTICAL_FULL_PORT_AND_HARDENING_PLAN_2026_06_24.md` wherever it implies a
thin native Epistemos shell with hidden donor capabilities.

The owner rejected that as an old assumption. The current direction is:

> Full clones / full ports first, then Epistemos-native or Epistemos-themed
> simplification. Do not keep the hyper-minimal native shell if it hides
> usability. Use the donor apps' complete surface area so features do not
> disappear.

## Core Intent

The app should still feel like Epistemos:

- flat/pixel,
- minimalist model-space,
- shielded/quiet colors,
- no decorative gradients,
- no noisy card stacks,
- monospace where it helps,
- blur reveal,
- typewriter/ASCII reveal,
- combined blur + typewriter/ASCII transition from landing/search into chat,
- combined blur + typewriter/ASCII transition between chat surfaces where the
  owner UI had it,
- click-anywhere-to-search,
- click-to-start-conversation as a new landing entry primitive, not the old
  chat implementation restored,
- optional compact landing toggles for Search / Act / Work / Mini-style entry
  modes if they make the new architecture clearer,
- search page as a real visible mode,
- strong model picker,
- native recents/settings/session ownership.

But the implementation should not be a tiny native chrome with everything
hidden. That is too easy to break and too hard to audit. The donor applications
must be cloned/ported deeply enough that all real surfaces remain visible in a
parity ledger, then simplified into Epistemos' visual language.

Transition and model-picker IP is locked by
`docs/handoffs/TRANSITION_AND_MODEL_PICKER_IP_LEDGER_2026_06_24.md`. Preserve
the combined blur reveal + typewriter/ASCII transition from landing/search into
chat and between chat surfaces, preserve click-anywhere/click-to-start landing
entry as a rebuilt interaction primitive, and preserve the useful owner-style
model picker as visible runtime selection UI.

## The New Rule

Do not summarize this plan as:

> Keep Epistemos native shell and wire donors underneath.

That is the old failed path.

Summarize it as:

> Full clone / full port / full surface inventory, then Epistemos-native
> simplification and reskin.

## Work Direction

### Main Work Foundation

Use OpenCode as the behavioral foundation and visual reference:

- OpenCode-style flatness,
- model-space clarity,
- terminal/TUI minimalism as inspiration,
- no gradients,
- explicit sessions,
- visible model/tool/status affordances,
- TUI kept hidden as advanced/fallback, not default.

Use OpenWork as the primary full-clone/full-port donor for the Work app because
it has the closest capability surface:

- sessions,
- skills,
- plugins,
- MCP setup,
- templates,
- permissions,
- local/remote workers,
- persistence,
- OpenCode integration.

Use OpenChamber as a secondary donor, especially for:

- visible session GUI behavior,
- mini sessions,
- same-session floating mini windows,
- worktree/diff/review layouts,
- startup/bootstrap robustness,
- streaming status,
- permission/question routing.

Use `opencode-mini-session` as an additional mini-session donor:

- floating mini work sessions,
- attach/open-main behavior,
- tab/session relationship,
- compact input surfaces.

### Mini Session Model For Work

Mini sessions are not a cosmetic mini-chat. They are first-class Work sessions
with explicit parentage.

The intended session ontology is:

- **Main Work session**: the tab/root session. It owns the workspace, selected
  vault/project, branch/worktree context, OpenCode/OpenWork session identity,
  recents entry, model/tool state, permissions state, and optional hidden TUI
  attach point.
- **Attached mini session**: a child session created from a main Work session.
  It stores `parentSessionID`, inherits or references the parent workspace and
  OpenCode context, and can run a compact agent turn without replacing the main
  transcript.
- **Detached mini session**: the same attached mini session shown in a floating
  MiniChat-style window. Detach changes presentation, not identity.

Required behavior:

- From a main Work session, the user can open a mini session inside the main UI
  as a compact pane/card/rail.
- From that same mini session, the user can detach into the floating MiniChat
  surface, reattach, or open/focus the parent main session.
- From the existing Epistemos MiniChat, the user can create or resume a Work
  mini session attached to a main Work session.
- Main GUI tabs are main sessions. Mini sessions live under their parent main
  session and must never masquerade as independent main tabs unless the user
  explicitly promotes them.
- Recents must show both main sessions and attached mini sessions clearly, with
  parent relationship visible.
- Duplicate-window bugs are failures: opening the same mini session from main
  and MiniChat should focus the existing surface, not fork ghost state.
- The OpenCode TUI is hidden advanced/fallback. Mini sessions default to the
  compact GUI surface. If a TUI attach exists for a mini session, it is an
  advanced/debug action, not the normal UI.
- Mini sessions must preserve MCP/vault/skills visibility, permissions prompts,
  model/tool state, busy/stop status, streaming status, persistence, and
  session recovery.

Donor mapping:

- OpenWork supplies OpenCode integration, MCP/skills/plugins, persistence, and
  permission/session primitives.
- OpenChamber supplies visible session switching, mini chat/window behavior,
  stream/status presentation, and worktree/review surface patterns.
- `opencode-mini-session` supplies focused mini-session mechanics and the
  attach/open-main relationship.
- Epistemos MiniChat supplies the owner visual language and the floating
  presentation target.

The final Work UI should not look like raw OpenWork, OpenChamber, or OpenCode.
It should look like Epistemos' flat Act/chat language, but with OpenCode's
clarity and explicit use surfaces.

## Act Direction

### Do Not Keep Osaurus As The Future Act Architecture

Osaurus is no longer the target Act engine or ontology.

Osaurus can remain only as:

- temporary working compatibility,
- feature/IP checklist,
- source for capabilities to re-home,
- model marketplace/model-manager reference,
- proof source while native replacement catches up.

End state:

- Osaurus removed.
- Osaurus UI removed.
- Osaurus chat ontology removed.
- useful Osaurus capabilities re-homed into Epistemos-native services before
  removal.

Do not delete it until the IP preservation preconditions are met in
`docs/ACT_IP_PRESERVATION_2026_06_24.md`.

### Native Act Should Be A Full Swift-Agent Infusion, Not A Tiny Shell

Act should become robust by using the best Swift agent repos deeply enough to
preserve their capabilities:

- Agent! (`macos26/Agent`) for native macOS automation/app-agent surfaces,
  visible settings/popovers, run/stop/task behavior, XPC/helper ideas,
  accessibility and app control patterns.
- 1amageek SwiftAgent for permission/sandbox/MCP/skills architecture.
- Swarm for multi-agent workflows, memory, fallback, guardrails, provider
  abstraction, durable flows.
- SwiftedMind SwiftAgent for clean transcript/streaming/cloud adapter design.
- MCP Swift SDK where it is the canonical transport/client/tool bridge.

This does not mean blindly shipping all their UI. It means the same full-clone
discipline as Work:

1. clone/read the source,
2. inventory every surface and capability,
3. decide whether to port, re-home, simplify, or prune,
4. rebuild/reskin into Epistemos' Act visual language,
5. verify nothing important disappeared.

## UI Replacement Clarification

The old hyper-minimal native shell is not enough. It hides usability. Replace
that approach with an explicit but quiet interface:

- keep the beautiful native motion and pixel/ASCII identity,
- keep search reveal and typewriter/blur moments,
- expose model/tool/session/settings surfaces clearly,
- make the search page a real mode, not a hidden trick,
- keep the model picker visible and useful,
- make command/tools/settings accessible without burying them,
- prefer compact visible controls over invisible functionality.

The goal is not maximal decoration. The goal is maximal clarity with Epistemos
restraint.

## Pruning Direction

Pruning should remove:

- duplicate donor chrome,
- Osaurus UI/ontology,
- dead native minimal shell stubs,
- hidden controls that make capability discovery impossible,
- surfaces that only exist because two apps were mounted side by side,
- gradients/decorative visual noise,
- repeated chat implementations that drift.

Pruning must preserve or re-home:

- Epistemos IP,
- model picker behavior,
- visible model picker as the runtime selector for Work/Act, not donor-only
  settings or slash-command-only switching,
- HF/model marketplace and download flows,
- Act search/reveal/typewriter/ASCII identity,
- landing/search-to-chat blur + typewriter/ASCII transition,
- recents,
- settings,
- permissions,
- tool panels,
- skills/MCP,
- mini sessions,
- graph/note/main session routing,
- native OS/security affordances.

## Single Hardening Cycle

Before the large clone/infusion cycle, run one hardening cycle:

1. Verify OpenCode integration:
   - MCP tools,
   - vault root,
   - skills discovery,
   - permissions,
   - session persistence,
   - hidden TUI fallback.

2. Define and prove the Work session schema:
   - main sessions,
   - attached mini sessions,
   - detached mini-session windows,
   - parent/child persistence,
   - open-main/focus behavior,
   - recents entries,
   - duplicate-window prevention,
   - mini-session MCP/vault/skills/permissions propagation.

3. Preserve Act IP:
   - keep `docs/ACT_IP_PRESERVATION_2026_06_24.md` current,
   - do not remove Osaurus until its useful behaviors are reproduced or
     explicitly pruned.

4. Stabilize visible entry points:
   - landing search,
   - click-anywhere-to-search,
   - main Act chat,
   - mini chat,
   - graph chat,
   - note chat.

5. Make the no-vault state honest:
   - Work must say when no active vault is selected,
   - do not diagnose it as MCP failure when the app has no vault.

## Full Clone / Infusion Cycle

After hardening:

1. Clone/vendor OpenWork as main Work donor.
2. Clone/read OpenChamber and `opencode-mini-session` as session/mini-session
   donors.
3. Clone/read the Swift agent repos as Act donors.
4. Build Work parity ledger.
5. Build Act parity ledger.
6. Start Work WebKit/native hybrid reskin using Epistemos theme tokens.
7. Start Native Act full-infusion prototype behind a feature flag.
8. Re-home Osaurus marketplace/model-management before removal.
9. Prune old duplicate surfaces only after parity/proof.

The clone/infusion loop is recursive and surface-led:

1. Pick one donor surface or one Epistemos surface.
2. Inventory every visible control, hidden command, popover, permission prompt,
   status state, settings state, persistence effect, and failure mode.
3. Port or re-home the behavior.
4. Reskin into Epistemos flat/pixel/OpenCode-like language.
5. Verify the surface with code evidence and fresh runtime evidence.
6. Prune the old duplicate only after the replacement is visible and proven.
7. Repeat until no donor capability remains hidden in raw donor UI and no
   Epistemos IP surface remains stranded in old stubs.

## Visual Target

Use this as the visual north star:

- OpenCode-like flat model space,
- Epistemos Act/chat simplicity,
- visible but compact controls,
- no gradients,
- no decorative blobs,
- quiet shielded colors,
- monospace where it clarifies status/code/model/tool labels,
- blur reveal/typewriter/ASCII for identity moments,
- search reveal as a first-class mode,
- pixel-art simplicity makeover,
- all donor capability surfaces accounted for.

## Claude / Agent Prompt

For the full copy-paste implementation prompt, use:

`docs/handoffs/CLAUDE_IMPLEMENTATION_PROMPT_FULL_CLONE_INFUSION_2026_06_24.md`

```text
The prior "native shell + donor engine" plan is superseded.

Implement the full-clone native infusion plan:

- Work: harden OpenCode first, then full clone/port OpenWork as the main donor,
  with OpenChamber and opencode-mini-session as secondary session/mini-session
  donors. Reskin/rehost into Epistemos flat/pixel/OpenCode-like model-space UI.
  Keep TUI as hidden advanced fallback.

- Act: Osaurus is not the future architecture. Preserve its IP/capabilities
  only until replaced. Build native Act from full Swift-agent repo infusion:
  Agent!, SwiftAgent, Swarm, SwiftedMind SwiftAgent, and MCP Swift SDK as
  full source/capability donors. Do not keep a tiny native shell that hides
  usability.

- Preserve Epistemos IP: model picker, search reveal, click-anywhere search,
  blur reveal, typewriter/ASCII, recents, settings, permissions, tools, skills,
  MCP, mini sessions, graph/note/main routing.

- Prune duplicate/old Osaurus/native-stub surfaces only after the donor
  capability ledger proves the replacement exists.
```
