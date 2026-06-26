# Research Clones Inventory - 2026-06-24

This is an inventory, not an implementation plan.

The donor repos were cloned under `.research-clones/` for local study. The
folder is excluded from git through `.git/info/exclude`, so these clones are
available on this machine but are not product source and should not be staged.

For the current Chat / Act / Work surface plan, read
`docs/handoffs/CHAT_ACT_WORK_TRI_SURFACE_ENGINE_PLAN_2026_06_24.md`.

For the rationale, robustness notes, risk ranking, and canon posture for each
clone, read
`docs/handoffs/RESEARCH_CLONES_CANON_RATIONALE_2026_06_24.md`.

Most original rows below were verified as full clones with `shallow=false`
after fetching all remote branches and tags. Goose was added later as a shallow
research clone for the Chat / Act / Work plan and should be deepened only if it
is promoted beyond study/spike use.

Disk after clone:

- `.research-clones`: 4.0G after the Goose and OpenGUI dependency research
  pass
- free disk remaining: about 107GiB

## Work / Coworker Clones

| Path | Repo | Verified | License posture |
|---|---|---:|---|
| `.research-clones/work/opencode` | `https://github.com/sst/opencode.git` | full clone | source-of-truth backend reference; license review before vendoring |
| `.research-clones/work/openwork` | `https://github.com/different-ai/openwork.git` | full clone | mixed posture; root useful, `/ee` needs explicit license review |
| `.research-clones/work/openchamber` | `https://github.com/openchamber/openchamber.git` | full clone | MIT donor candidate |
| `.research-clones/work/opencode-mini-session` | `https://github.com/karamanliev/opencode-mini-session.git` | full clone | mini-session donor; license review before vendoring |
| `.research-clones/work/opengui` | `https://github.com/akemmanuel/OpenGUI.git` | full clone | multi-agent GUI donor; license review before vendoring |
| `.research-clones/work/goose` | `https://github.com/aaif-goose/goose.git` | shallow research clone at `eea6989` | Apache-2.0; Act/Work engine candidate; deepen before vendoring |
| `.research-clones/work/open-cowork` | `https://github.com/OpenCoworkAI/open-cowork.git` | full clone | coworker/sandbox reference; license review before vendoring |
| `.research-clones/work/paseo` | `https://github.com/getpaseo/paseo.git` | full clone | AGPL/study-only unless owner accepts license obligations |

## Agent / Pi / Hermes Clones

| Path | Repo | Verified | License posture |
|---|---|---:|---|
| `.research-clones/agents/pi` | `https://github.com/earendil-works/pi.git` | full clone | MIT donor candidate |
| `.research-clones/agents/oh-my-pi` | `https://github.com/can1357/oh-my-pi.git` | full clone | MIT donor candidate |
| `.research-clones/agents/pi-web` | `https://github.com/ashwin-pc/pi-web.git` | full clone | small UI reference; license review before vendoring |
| `.research-clones/agents/pi-dashboard` | `https://github.com/samfoy/pi-dashboard.git` | full clone | UI/session reference; license review before vendoring |
| `.research-clones/agents/pi-coding-agent` | `https://github.com/dnouri/pi-coding-agent.git` | full clone | GPL/study-only unless owner accepts license obligations |
| `.research-clones/agents/hermes-agent` | `https://github.com/NousResearch/hermes-agent.git` | full clone | MIT donor/reference candidate; review scope before vendoring |

## Swift / MAS Act Clones

| Path | Repo | Verified | License posture |
|---|---|---:|---|
| `.research-clones/swift-act/agent-macos26` | `https://github.com/macos26/Agent.git` | full clone | MIT code; native macOS capability reference |
| `.research-clones/swift-act/swiftagent-1amageek` | `https://github.com/1amageek/SwiftAgent.git` | full clone | no clear license in prior quick study; study-only until verified |
| `.research-clones/swift-act/swiftagent-swiftedmind` | `https://github.com/SwiftedMind/SwiftAgent.git` | full clone | MIT donor candidate |
| `.research-clones/swift-act/swarm` | `https://github.com/christopherkarani/Swarm.git` | full clone | MIT donor candidate |
| `.research-clones/swift-act/agentsdk-swift` | `https://github.com/fumito-ito/AgentSDK-Swift.git` | full clone | MIT donor candidate |
| `.research-clones/swift-act/mcp-swift-sdk` | `https://github.com/modelcontextprotocol/swift-sdk.git` | full clone | official SDK; license/package review before vendoring |
| `.research-clones/swift-act/swiftaia-agent` | `https://github.com/ShenghaiWang/SwiftAIAgent.git` | full clone | no clear license in prior quick study; study-only until verified |
| `.research-clones/swift-act/agentkit` | `https://github.com/sebsto/agentkit.git` | full clone | MIT donor/reference candidate |
| `.research-clones/swift-act/foundation-models-framework-example` | `https://github.com/rudrankriyam/Foundation-Models-Framework-Example.git` | full clone | Apple Foundation Models sample/reference; license review before copying |

## Guardrail

Being cloned here does not mean code is approved for Epistemos product use.
Before vendoring or copying any source:

- check the repo root license,
- check nested package licenses,
- check generated/vendor folders,
- preserve notices where required,
- avoid AGPL/GPL/no-license code unless the owner explicitly accepts the
  obligations or a clean-room rewrite is used.
