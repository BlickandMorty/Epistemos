# Research Clones Canon Rationale - 2026-06-24

This is research canon, not an implementation plan.

Purpose: preserve why each donor was cloned, what role it should play in
Epistemos research, what is robust about it, and what license or architecture
risk future agents must keep in mind.

The actual full clones live under `.research-clones/` and are inventoried in
`docs/handoffs/RESEARCH_CLONES_INVENTORY_2026_06_24.md`.

Current superseding plan:
`docs/handoffs/CHAT_ACT_WORK_TRI_SURFACE_ENGINE_PLAN_2026_06_24.md`.
That plan changes the current donor priority to:

- **Chat**: Swarm-first native Swift substrate.
- **Act**: Goose-powered native action surface, process/API/ACP first.
- **Work**: OpenGUI-style multi-engine workbench, OpenWork retained as
  fallback/reference.

For the WebKit/process/native integration-shape decision, read
`docs/handoffs/WORK_INTEGRATION_SHAPE_RESEARCH_2026_06_24.md`.

## Canon Summary

The donor field split into three lanes:

- **Work / Coworker lane**: heavy desktop/web/CLI agent workspaces, OpenCode
  integrations, sessions, panes, MCP, skills, persistence, and GUI shells.
- **Agent / Pi / Hermes lane**: coding-agent engines, terminal-grade agent
  loops, personal coworker platforms, memory, tool harnesses, and dashboards.
- **Swift / MAS Act lane**: native Swift agent substrate, Foundation Models,
  MCP Swift, permissions, sandboxing, streaming, and App Store-friendlier
  architecture.

Owner preference remains practical full-clone research because it reduces the
risk that agents miss hidden surfaces. The guardrail is that **full clone for
study does not mean code is approved to vendor**.

## Highest-Attention Donors

These should remain top of mind:

- **OpenGUI**: current preferred Work adapter/workbench substrate because its
  ADR explicitly separates Runtime, Backend, Frontend, and Shell.
- **Goose**: current preferred Act engine candidate and a Work engine
  candidate. Use process/API/ACP first because the current UniFFI surface is
  only a stub.
- **OpenWork**: current fallback/reference for Work because it already thinks
  in OpenCode, MCP, skills, plugins, sessions, permissions, persistence, and
  workers.
- **Paseo**: strongest north-star ontology for a multi-agent coworker command
  center, even though its AGPL posture makes it study/clean-room unless the
  owner accepts obligations.
- **OpenChamber**: strongest visible session/mini-chat/session-switching GUI
  donor.
- **oh-my-pi / OMP**: strongest OpenCode-replacement candidate to audit because
  it is a fork/extension of Pi with a serious coding-agent harness, inherited
  skills/MCP/rules, LSP, browser, subagents, and terminal power.
- **Hermes Agent**: strongest broad coworker/personal-agent donor for memory,
  toolsets, approval/sandbox patterns, desktop/TUI ideas, and gateway/platform
  breadth.
- **Swarm**: strongest Swift-native hardening donor for durable workflows,
  memory, fallback, guardrails, provider abstraction, and observability.
- **SwiftedMind SwiftAgent**: compact Swift streaming/session/tool-call donor.
- **MCP Swift SDK + Foundation Models sample**: most important MAS-native
  substrate references for Act.

## Work / Coworker Lane

### OpenCode

Path: `.research-clones/work/opencode`

Rationale:

- Behavioral source of truth for the current Work backend.
- Important for sessions, prompts, tools, permissions, config, model/provider
  routing, TUI fallback, and server/API behavior.
- Useful to compare against OpenWork/OpenChamber/Paseo/OMP so Epistemos does
  not accidentally implement a distorted OpenCode contract.

Risk:

- Huge branch/tag surface.
- Should be treated as protocol/behavior source before product code is copied.
- License and nested dependency review still required before vendoring.

Canon posture: **source-of-truth backend reference**.

### OpenWork

Path: `.research-clones/work/openwork`

Rationale:

- Best practical current full-clone donor for the Work implementation Claude
  is already pursuing.
- Directly targets OpenCode-backed work and already covers the pain points that
  triggered the research: MCP persistence, skills discovery, plugins, runtime
  config, permissions, sessions, workers, templates, and app-owned OpenCode
  setup.
- Existing research found concrete valuable files:
  `apps/server/src/runtime-opencode-config-store.ts`,
  `apps/server/src/mcp.ts`, `apps/server/src/skills.ts`,
  `apps/server/src/plugins.ts`, `apps/server/src/managed-opencode.ts`, and
  `apps/app/src/react-app/domains/settings/pages/mcp-view.tsx`.

Risk:

- Mixed license posture. Root is useful, but `/ee` was flagged as requiring
  explicit review.
- Electron/web app ontology can leak if pasted instead of rehomed into
  Epistemos shell/recents/settings/permissions.

Canon posture: **fallback/reference Work donor under the Chat / Act / Work
plan; do not delete until OpenGUI/OpenCode proof passes**.

### OpenChamber

Path: `.research-clones/work/openchamber`

Rationale:

- Strongest visible session GUI donor.
- Prior research found useful pieces for OpenCode client behavior, runtime
  fetch coalescing, bootstrap, session actions, streaming, permission store,
  MCP store, skills store, Electron mini chat, and mini chat layout.
- Especially valuable for mini sessions, session switching, startup
  robustness, streaming status, permission/question routing, and worktree/GUI
  ergonomics.

Risk:

- Narrower backend capability surface than OpenWork.
- Should not become the whole architecture if OpenWork/Paseo/OMP are better at
  engines and persistence.

Canon posture: **secondary GUI/session robustness donor**.

### opencode-mini-session

Path: `.research-clones/work/opencode-mini-session`

Rationale:

- Specific donor for the mini-session model the owner wanted: floating compact
  session, attach/open-main relationship, and mini session as a real child of a
  main session.
- Maps naturally to Epistemos MiniChat and the new Work main-session /
  attached-mini-session ontology.

Risk:

- No license file found in the local maxdepth sweep. Study-only until license
  is verified.

Canon posture: **mini-session mechanics donor, license-gated**.

### OpenGUI

Path: `.research-clones/work/opengui`

Rationale:

- Strong challenger donor for a multi-agent GUI because it supports multiple
  agent backends rather than only OpenCode.
- Useful for model/provider switching, sessions, prompt queue, MCP tools, and
  GUI patterns for routing among agents like OpenCode, Codex, Claude, and Pi.

Risk:

- Needs deeper source and license review before treating it as a product donor.
- May overlap with the future Agents section more than current Work.

Canon posture: **current preferred Work adapter/workbench substrate; visible UI
must still be Epistemos-owned**.

### Goose

Path: `.research-clones/work/goose`

Rationale:

- Strong Act engine candidate because it is a serious Rust agent with desktop,
  CLI, API/server, ACP, MCP, providers, recipes, sessions, permissions, and
  security/tool-inspection code.
- Strong Work engine candidate because it can sit beside OpenCode, Codex,
  Claude Code, Pi/OMP, and Hermes behind the same Epistemos Work engine picker.
- Apache-2.0 posture is friendlier than AGPL for direct reuse, subject to
  normal NOTICE/license review.

Risk:

- The current research clone is shallow at `eea6989`; deepen before vendoring
  or making source-level claims.
- Local size is about 661 MB even shallow, so this is not a tiny dependency.
- `crates/goose-sdk` has a UniFFI feature, but the current published UniFFI
  surface is only a `ping -> pong` scaffold. Do not start with Rust-Swift FFI.
  Start with process/API/ACP, then explore UniFFI only for stable core pieces.
- Goose Desktop is Electron/React and should not become Epistemos visible
  chrome.

Canon posture: **primary Act engine candidate and Work engine candidate;
process/API/ACP first, UniFFI later**.

### Open Cowork

Path: `.research-clones/work/open-cowork`

Rationale:

- Good coworker/sandbox/skills/desktop automation reference.
- Useful for studying desktop coworker UX, isolation, messaging, integrations,
  and broader assistant platform behavior.

Risk:

- Less directly OpenCode-native than OpenWork/OpenChamber.
- Could pull Work away from the current OpenCode hardening path if treated as
  the immediate foundation.

Canon posture: **coworker/sandbox/platform reference**.

### Paseo

Path: `.research-clones/work/paseo`

Rationale:

- Strongest north-star ontology for the larger multi-agent coworker idea.
- Useful because it treats agents as a broader command center instead of making
  OpenCode the entire app ontology.
- Deserves attention for multi-agent sessions, panes, providers, local daemon
  thinking, desktop/web/mobile/CLI surfaces, PR/review/check flows, and
  provider-agnostic work.

Risk:

- License-risk donor: AGPL. Copying/reskinning into Epistemos is not safe
  without owner accepting obligations or using clean-room reimplementation.
- Canon value is high even when code-copy value is gated.

Canon posture: **highest-value study-only architecture donor unless license
strategy changes**.

## Agent / Pi / Hermes Lane

### Pi

Path: `.research-clones/agents/pi`

Rationale:

- Base coding-agent toolkit with unified LLM API, agent loop, TUI, and coding
  CLI patterns.
- Useful as a baseline for understanding OMP and Pi-family engine choices.

Risk:

- Needs Epistemos-owned permission/sandbox hardening if used as an engine.
- More engine/TUI than polished Work GUI.

Canon posture: **Pi-family baseline engine donor**.

### oh-my-pi / OMP

Path: `.research-clones/agents/oh-my-pi`

Rationale:

- Most serious OpenCode alternative candidate found in the research.
- High-attention because it advertises or exposes terminal-grade coding-agent
  features: subagents, slash commands, extensions, inherited rules/skills/MCP
  from `.codex`, `.claude`, `.cursor`, LSP, browser, and stronger editing/tool
  harness behavior.
- Potentially useful as the future engine behind the Agents section or as a
  competitor to OpenCode for Work.

Risk:

- Very large branch/tag surface.
- Powerful terminal agent behavior must be hardened through Epistemos
  permissions, sandboxing, recents, and model picker before product use.

Canon posture: **top engine challenger to OpenCode**.

### pi-web

Path: `.research-clones/agents/pi-web`

Rationale:

- Small Pi-related web UI/reference.
- Useful for quick UI/session ideas around Pi, not as the architecture.

Risk:

- Small scope, low evidence of robustness.

Canon posture: **minor UI reference**.

### pi-dashboard

Path: `.research-clones/agents/pi-dashboard`

Rationale:

- Pi dashboard reference for multi-session chat, file browser, document
  collaboration, terminal, and possible compact agent dashboard patterns.

Risk:

- Small project compared with OMP/Hermes/OpenWork/Paseo.
- Study for surfaces, not engine authority.

Canon posture: **small visual/session reference**.

### pi-coding-agent

Path: `.research-clones/agents/pi-coding-agent`

Rationale:

- Pi coding-agent frontend/reference, useful for seeing how another UI maps to
  Pi agent capabilities.

Risk:

- GPL license posture from prior metadata. Study-only unless owner accepts GPL
  obligations or behavior is clean-room reimplemented.

Canon posture: **GPL study-only frontend/reference**.

### Hermes Agent

Path: `.research-clones/agents/hermes-agent`

Rationale:

- Strong broad coworker/personal-agent donor.
- Deserves attention for memory, toolsets, approvals, sandbox/container ideas,
  desktop/TUI surfaces, model routing, integrations, gateway/platform breadth,
  and OpenClaw/Hermes migration lines.
- It may be better for the future Agents section than for the immediate
  OpenWork clone.

Risk:

- Very large surface and branch history.
- Platform breadth can swamp the current Work implementation if treated as an
  immediate replacement.
- Needs scope review before copying or vendoring even when license is permissive.

Canon posture: **major coworker/platform donor for Agents section**.

## Swift / MAS Act Lane

### Agent! / macos26 Agent

Path: `.research-clones/swift-act/agent-macos26`

Rationale:

- Best full native macOS app reference among the Swift agent repos.
- Useful for macOS automation surfaces, accessibility, AppleScript,
  ScriptingBridge, Safari/Xcode helpers, run/stop/task behavior, settings
  popovers, tool loops, possible XPC/helper ideas, and native app affordances.

Risk:

- Visual style is not Epistemos.
- Should not replace the owner Act chat visually.
- Use as a capability checklist and native macOS patterns donor, not a shell to
  paste over Epistemos.

Canon posture: **native macOS capability reference**.

### 1amageek SwiftAgent

Path: `.research-clones/swift-act/swiftagent-1amageek`

Rationale:

- Prior study found it technically promising for Swift-native permissions,
  sandbox execution, MCP, skills discovery, turn execution, timeout,
  cancellation, and approval bridging.
- It may be one of the strongest MAS-friendly hardening donors if license is
  resolved.

Risk:

- No license file found locally in the clone sweep. Study-only until verified.

Canon posture: **high-value Swift hardening donor, license-gated**.

### SwiftedMind SwiftAgent

Path: `.research-clones/swift-act/swiftagent-swiftedmind`

Rationale:

- Compact native Swift SDK for agent sessions, transcripts, typed tools,
  streaming, and structured output.
- Useful for clean Act transcript and stream adapter design.

Risk:

- Smaller scope than Swarm for workflows/memory/fallback.

Canon posture: **Swift streaming/session/tool-call donor**.

### Swarm

Path: `.research-clones/swift-act/swarm`

Rationale:

- Strongest broad Swift-native hardening donor.
- Prior research identified valuable runtime concepts: lifecycle/tool/output/
  handoff/observation events, provider abstraction, durable workflow
  checkpoint/resume, fallback chains, circuit breakers, rate limiting, memory,
  MCP, guardrails, and observability.
- Useful for the MAS Act substrate once the Epistemos UI contract is stable.

Risk:

- Too broad to blindly vendor into Act without a surface/parity ledger.
- More runtime framework than visual app.

Canon posture: **top Swift-native robustness donor**.

### AgentSDK-Swift

Path: `.research-clones/swift-act/agentsdk-swift`

Rationale:

- Swift implementation of an agents SDK shape.
- Useful for studying typed agent abstractions and OpenAI-style agent
  interfaces in Swift.

Risk:

- Smaller and less proven than Swarm/SwiftedMind/Agent!.

Canon posture: **small Swift agents SDK reference**.

### MCP Swift SDK

Path: `.research-clones/swift-act/mcp-swift-sdk`

Rationale:

- Official Swift SDK for MCP clients and servers.
- Critical for MAS-native Act/Work tool/resource/prompt plumbing, cancellation,
  progress, auth, sampling, and elicitation without shelling out to fragile
  JavaScript/Python bridges.

Risk:

- Official SDK does not automatically make every MCP server App Store-safe.
- Package/license and sandbox behavior must be reviewed before product
  integration.

Canon posture: **canonical Swift MCP substrate reference**.

### SwiftAIAgent

Path: `.research-clones/swift-act/swiftaia-agent`

Rationale:

- Additional Swift agent reference, including model-selection and tools branch
  history.
- Useful for motif mining if Swarm/SwiftedMind/1amageek leave gaps.

Risk:

- No license file found locally. Study-only until verified.

Canon posture: **secondary Swift study-only donor**.

### AgentKit

Path: `.research-clones/swift-act/agentkit`

Rationale:

- Mini Swift library for model-centric agents.
- Useful as a lightweight contrast to Swarm and SwiftedMind.

Risk:

- Smaller scope; likely not enough alone for Act.

Canon posture: **lightweight Swift reference**.

### Foundation Models Framework Example

Path: `.research-clones/swift-act/foundation-models-framework-example`

Rationale:

- Sample/reference for Apple Foundation Models usage.
- Important because the MAS-friendly Act direction should lean on Apple-native
  Foundation Models where possible: offline/private local model, streaming,
  guided/structured generation, tool calling, and stateful sessions.

Risk:

- Sample code only. License and API freshness must be reviewed before copying.
- Foundation Models does not replace external model/provider lanes by itself.

Canon posture: **Apple-native MAS substrate reference**.

## License / Copying Canon

Current rough posture:

- **Safer donor candidates after review**: OpenChamber, Pi, OMP, Hermes,
  Agent!, SwiftedMind SwiftAgent, Swarm, AgentSDK-Swift, AgentKit.
- **Official/canonical but still review before vendoring**: MCP Swift SDK,
  OpenCode behavior/API, Foundation Models samples.
- **Study-only unless obligations accepted or clean-room rewrite used**: Paseo
  (AGPL), pi-coding-agent (GPL), no-license repos such as
  1amageek SwiftAgent and SwiftAIAgent until license is verified.
- **Mixed posture**: OpenWork, because root is useful but `/ee` needs explicit
  review.
- **Unknown until checked**: opencode-mini-session and any nested packages or
  generated/vendor folders.

## Ranking Canon

For immediate practical implementation:

1. OpenWork as the current full-clone Work path.
2. OpenChamber for GUI/session/mini-chat hardening.
3. opencode-mini-session for attached/floating mini-session mechanics.

For future multi-agent/coworker ontology:

1. Paseo as the best north-star architecture, study-only unless license changes.
2. Hermes Agent as the broad coworker/platform donor.
3. OpenGUI as the multi-agent GUI challenger.
4. OMP/Pi as engine candidates.

For native Swift/MAS Act:

1. Foundation Models + MCP Swift SDK as canonical substrate references.
2. Swarm for robustness/durable runtime ideas.
3. SwiftedMind SwiftAgent for streaming/session/tool design.
4. Agent! for native macOS capability surfaces.
5. 1amageek SwiftAgent if license is resolved.

## Standing Rule

Future agents should not flatten this research into "use OpenWork" or "use
Paseo." The canon is:

- full clones exist so no hidden donor surface is missed,
- risky repos still matter as architecture canon,
- license-risk repos are study-only unless the owner explicitly accepts the
  obligations,
- Epistemos owns the final UI, recents, settings, permissions, model picker,
  and session ontology.
