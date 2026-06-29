# Claude Implementation Prompt - Full Clone Infusion And Pruning Overhaul - 2026-06-24

> 🛑 **SUPERSEDED 2026-06-29 — DO NOT PASTE THIS.** This is a stale 2026-06-24 paste-prompt; its authority chain
> (full-clone infusion / Osaurus Act engine / native-shell-with-donor-engines) is entirely 06-24 docs and has been
> overtaken by later canon: the **2026-06-28 Goose-only scope lock** and the **2026-06-29 Option 1** (no native chat)
> + **editor lens model**. The ONLY prompts to paste are `docs/prompts/PROMPT_PLAN_{1_GOOSE,2_EDITOR,3_CAPABILITIES}.md`.
> Canon that wins on conflict: `docs/handoffs/GOOSE_NATIVE_UI_DECISION_2026_06_29.md` +
> `docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`. Everything below is HISTORICAL — kept for nuance, do not act on it.

Use this prompt to start the actual implementation cycle.

```text
You are working in /Users/jojo/Downloads/Epistemos on main.

Do not continue the old assumption that Epistemos should keep a tiny native shell
with donor engines hidden underneath. That was rejected. The current authority is:

1. docs/handoffs/AUTHORITATIVE_FULL_CLONE_NATIVE_INFUSION_PLAN_2026_06_24.md
2. docs/ACT_IP_PRESERVATION_2026_06_24.md
3. docs/handoffs/OPENWORK_OPENCHAMBER_CODE_STUDY_HANDOFF_2026_06_24.md
4. docs/handoffs/ACT_OSAURUS_SWIFT_AGENT_CODE_STUDY_HANDOFF_2026_06_24.md
5. docs/handoffs/PRACTICAL_FULL_PORT_AND_HARDENING_PLAN_2026_06_24.md only where it does not conflict with #1.

Treat #1 as the newest architectural authority. If older files say "Osaurus is
the future Act engine" or "keep the native shell and hide donor capabilities,"
that is stale.

Core owner intent:

- Full clone / full port / full surface inventory first.
- Then Epistemos-native or Epistemos-themed simplification and reskin.
- Preserve Epistemos IP: model picker, click-anywhere search, search page,
  click-to-start-conversation, optional compact landing entry toggles,
  blur reveal, typewriter/ASCII reveal, recents, settings, permissions, tools,
  skills, MCP, mini sessions, graph/note/main routing, and native OS/security
  feel. Read docs/handoffs/TRANSITION_AND_MODEL_PICKER_IP_LEDGER_2026_06_24.md
  before changing landing/search/chat transitions or model selection.
- Prune duplicate donor chrome, Osaurus UI/ontology, dead native shell stubs,
  hidden controls, and surfaces that only exist because two apps were mounted
  side by side.
- Do not delete Osaurus until docs/ACT_IP_PRESERVATION_2026_06_24.md removal
  preconditions are truly satisfied.

Phase 0 - Safety and grounding:

- Run git status first. Do not revert or touch unrelated dirty files.
- Read every file before modifying it.
- Use rg for search.
- Make narrowly scoped commits only if requested. Never git add -A.
- Do not mark work complete without code evidence and runtime evidence.
- Save any new research or ledgers under docs/handoffs or docs/architecture so
  the next agent can continue.

Phase 1 - One hardening cycle before the large clone cycle:

1. Repair and prove OpenCode integration:
   - MCP installs persist.
   - MCP tools are discoverable after app restart.
   - active vault selection is honest and visible.
   - skills/vault resources are exposed to Work.
   - permissions are visible and actionable.
   - session persistence and recents work.
   - hidden TUI fallback remains available as advanced/debug, not default.

2. Repair visible Work/Act regressions caused by the previous bundle-style
   integration:
   - Loading/model/run state is visible and honest.
   - OpenCode sidebar-close and surface-close actions work.
   - mini chat, graph chat, and note chat are not stranded on old chat
     implementations.
   - main/mini/graph/note routing is explicit.

3. Preserve Act IP:
   - Keep docs/ACT_IP_PRESERVATION_2026_06_24.md updated.
   - Before hiding/replacing/removing any Act or Osaurus path, prove the new
     native Swift-agent path reproduces send, stream, tools, permissions,
     model selection, persistence, brain/routing transparency, and model/HF
     marketplace equivalents.

Phase 2 - Work full clone / full port / reskin:

Primary Work donor: OpenWork.
Behavior source-of-truth: official OpenCode.
Secondary visible-session donors: OpenChamber and opencode-mini-session.
TUI: hidden advanced/fallback only.

Implementation strategy:

- Clone/vendor/read OpenWork deeply enough that all sessions, skills, plugins,
  MCP setup, templates, permissions, workers, persistence, and OpenCode
  integration surfaces are inventoried.
- Clone/read OpenChamber for visible session GUI behavior, worktree/diff/review
  layouts, mini chat/window behavior, stream status, bootstrap, and permission
  routing.
- Clone/read https://github.com/karamanliev/opencode-mini-session for
  mini-session mechanics.
- Build a Work parity ledger before pruning any donor surface.
- Rehost/reskin the Work GUI with Epistemos flat/pixel/OpenCode-like language:
  minimal model-space, quiet shielded colors, no gradients, compact visible
  controls, monospace where useful, strong model picker, clear tools/settings.
- Do not merely mount raw OpenWork/OpenChamber UI. If embedded in WKWebView,
  Epistemos owns shell, recents, vault, permissions, settings, theme, and
  lifecycle.

Mini session product model:

- Main Work session = tab/root session. It owns workspace, vault/project,
  branch/worktree context, OpenCode/OpenWork session identity, recents entry,
  model/tool state, permission state, and optional hidden TUI attach point.
- Attached mini session = first-class child session created from a main Work
  session. It stores parentSessionID, inherits or references parent workspace
  and OpenCode context, and can run compact agent turns without replacing the
  main transcript.
- Detached mini session = the same mini session shown in a floating
  MiniChat-style window. Detach changes presentation, not identity.
- From main Work, the user can open a mini session inside the main UI.
- From the same mini session, the user can detach, reattach, or open/focus the
  parent main session.
- From Epistemos MiniChat, the user can create/resume a Work mini session
  attached to a main Work session.
- Main GUI tabs are main sessions. Mini sessions live under parents and should
  not masquerade as independent main tabs unless explicitly promoted.
- Recents must show main sessions and attached mini sessions clearly.
- Opening the same mini session from main and MiniChat must focus the existing
  surface, not create duplicate ghost windows.
- Mini sessions preserve MCP/vault/skills visibility, permissions prompts,
  model/tool state, busy/stop status, streaming status, persistence, and
  recovery.

Phase 3 - Act full Swift-agent infusion:

Osaurus is not the future Act architecture. It is temporary compatibility,
feature/IP checklist, model marketplace/model-manager reference, and proof
source while the native replacement catches up.

Build NativeSwiftActEngine from full Swift-agent donor study:

- Agent! (macos26/Agent): native macOS automation/app-agent surfaces,
  settings/popovers, run/stop/task behavior, helper/XPC ideas, accessibility
  and app control.
- 1amageek SwiftAgent: permission/sandbox/MCP/skills architecture.
- Swarm: multi-agent workflows, memory, fallback, guardrails, providers,
  durable flows.
- SwiftedMind SwiftAgent: transcript/streaming/cloud adapter design.
- MCP Swift SDK: canonical transport/client/tool bridge.

This is not a tiny UI wrapper. Use the same full-clone discipline:

1. clone/read,
2. inventory every surface and capability,
3. decide port/re-home/simplify/prune,
4. rebuild/reskin into Epistemos Act language,
5. verify nothing important disappeared.

Act must keep the Epistemos look:

- flat/pixel,
- click-anywhere-to-search,
- click-to-start-conversation rebuilt as a new landing entry primitive,
- optional compact landing toggles for Search / Act / Work / Mini-style entry,
- search page as a real mode,
- strong model picker,
- blur reveal,
- typewriter/ASCII reveal,
- quiet native settings,
- visible permissions,
- visible tools/model/session controls,
- no raw Osaurus UI.

Phase 4 - Pruning loop:

Use this recursive simplification loop for every surface:

1. Pick one donor surface or Epistemos surface.
2. Inventory visible controls, hidden commands, popovers, permissions,
   settings, persistence effects, streaming states, error states, and failure
   modes.
3. Port or re-home behavior.
4. Reskin into Epistemos flat/pixel/OpenCode-like language.
5. Verify with code evidence and fresh runtime evidence.
6. Prune the old duplicate only after the replacement is visible and proven.
7. Repeat until no donor capability remains hidden in raw donor UI and no
   Epistemos IP surface remains stranded in old stubs.

Phase 5 - Verification requirements:

- Build/launch where relevant.
- Use fresh screenshots for UI claims.
- Prove no-vault state vs real MCP failure separately.
- Prove MCP tool count and skills/vault visibility after restart.
- Prove mini-session create, detach, reattach, open-main/focus-parent, recents,
  and duplicate-window prevention.
- Prove Work main session and mini session can both use the OpenCode backend.
- Prove main chat, mini chat, graph chat, and note chat route through the new
  intended surfaces, not old stranded chat implementations.
- Do not claim [x] without evidence.

Start now by reading the five authority files above, then run git status, then
begin with the first small hardening implementation slice that unblocks the
full clone cycle. Save a brief implementation ledger as you go.
```
