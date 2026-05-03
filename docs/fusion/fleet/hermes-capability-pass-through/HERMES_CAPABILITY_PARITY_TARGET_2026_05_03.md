# Hermes Capability Parity Target - 2026-05-03

Purpose: preserve the user's Hermes command-reference screenshot and turn it into an Epistemos build target.

User intent: Epistemos should feel unified and direct, but the Pro/Research Hermes gateway should be able to pass through or faithfully expose the same practical capabilities Hermes Agent offers. If Hermes can do it, Epistemos should either:

1. expose it natively in Core when it is local, deterministic, and App Store safe;
2. route it through the Pro/Research Hermes gateway with structured evidence provenance; or
3. mark it explicitly out-of-scope with a reason.

This doc is a target map, not an implementation claim.

## Source Packet

- Screenshot captured from `/Users/jojo/Library/Mobile Documents/com~apple~CloudDocs/IMG_2330.jpeg`.
- Local canon: `/Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/hermes_cloud_gateway_architecture_decision_2026_05_02.md`.
- Local canon: `/Users/jojo/Downloads/Epistemos/docs/research/hermes-tool-catalog.md`.
- Local canon: `/Users/jojo/Downloads/Epistemos/docs/research/hermes-expert-mode-implementation-spec.md`.
- Official Hermes docs, checked 2026-05-03: [Slash Commands Reference](https://hermes-agent.nousresearch.com/docs/reference/slash-commands).
- Official Hermes docs, checked 2026-05-03: [CLI Commands Reference](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/reference/cli-commands.md).
- Official Hermes docs, checked 2026-05-03: [Tools & Toolsets](https://hermes-agent.nousresearch.com/docs/user-guide/features/tools/).
- Official Hermes docs, checked 2026-05-03: [Built-in Tools Reference](https://hermes-agent.nousresearch.com/docs/reference/tools-reference/).
- Official Hermes docs, checked 2026-05-03: [Toolsets Reference](https://hermes-agent.nousresearch.com/docs/reference/toolsets-reference).

Official-doc anchor: Hermes documents two command surfaces, CLI and messaging gateway, both sourced from a shared registry. Epistemos should mirror that product shape as one unified app command surface backed by tier-aware routing.

## Non-Negotiable Interpretation

- Hermes is the Pro/Research external-intelligence gateway and orchestration surface.
- Hermes is not the graph, Rex, residency governor, ledger, verification ladder, or deterministic substrate.
- Core/MAS must not expose Hermes subprocess, CLI delegation, MCP, Docker, browser/computer-use, shell, or external side-effect controls.
- Local prompt formatting and local Hermes-family model usage can be Core-safe only when in-process, offline/local, and policy-gated.
- All cloud, CLI, MCP, browser, Docker, remote terminal, messaging, and external side-effect surfaces must return structured evidence provenance into Epistemos.

## Screenshot Command Inventory

The screenshot groups slash commands into the categories below. This inventory is preserved so future builders do not lose the user's reference.

### Agent And Tasks

| Screenshot command | Capability | Epistemos target |
| --- | --- | --- |
| `/ask <question>` | Ask directly | Core native chat/query; Pro can route to Hermes for external evidence |
| `/think <prompt>` | Think step by step | Core local reasoning display only when safe; no hidden authority over graph |
| `/plan <task>` | Create a plan | Native workcard/deliberation planner plus Hermes plan skill bridge |
| `/execute <task>` | Execute task | Pro/Research gateway with approval and provenance |
| `/todo` | Show todos | Native task substrate or Hermes session todo passthrough |
| `/todo add <task>` | Add todo | Native/Hermes session todo bridge |
| `/todo done <id>` | Mark todo done | Native/Hermes session todo bridge |
| `/todo clear` | Clear todos | Requires local confirmation if deleting user-visible state |
| `/run <command>` | Run shell command | Pro/Research only; never Core/MAS |
| `/shell` | Open interactive shell | Pro/Research only; approval-gated |
| `/kill <pid>` | Kill process | Pro/Research only; destructive/local-system action policy applies |

### Session

| Screenshot command | Capability | Epistemos target |
| --- | --- | --- |
| `/new` | Start new session | Native session reset/new Hermes task |
| `/clear` | Clear screen/session | Native UI action; session data deletion requires confirmation if persistent |
| `/status` | Current session status | Native status panel with Hermes subprocess state |
| `/compact` | Compact context | Native context compaction plus Hermes `/compress` bridge |
| `/summary` | Summarize conversation | Native summary artifact plus Hermes summary bridge |
| `/save` | Save session | Native SwiftData/session ledger plus Hermes session export |
| `/load` | Load prior session | Native session browser plus Hermes resume |
| `/export` | Export conversation | User-approved file export |
| `/tokens` | Token stats | Native cost/context dashboard |
| `/cost` | API cost usage | Native usage/cost panel |
| `/model` | Current model details | Native model picker plus Hermes provider status |
| `/help` | Available commands | Unified command palette/help surface |

### Configuration

| Screenshot command | Capability | Epistemos target |
| --- | --- | --- |
| `/model <name>` | Switch model | Native model routing policy; Hermes provider switch in Pro |
| `/model list` | List models | Native provider registry + Hermes model list |
| `/temperature <0-2>` | Set temperature | Native per-session model config |
| `/max-tokens <num>` | Set max tokens | Native per-session model config |
| `/top-p <0-1>` | Set top-p | Native per-session model config |
| `/top-k <num>` | Set top-k | Native per-session model config |
| `/system <prompt>` | Set system prompt | Native prompt profile with audit trail |
| `/persona <name>` | Switch persona | Native profile/persona bridge |
| `/persona list` | List personas | Native profile/persona browser |
| `/memory on/off` | Toggle memory | Native memory gate and Hermes memory toggle |
| `/memory clear` | Clear memory | Requires explicit confirmation; destructive |
| `/tools on/off` | Toggle tools | Native tier/tool policy toggle |
| `/config show` | Show config | Native diagnostics panel |

### File And Data

| Screenshot command | Capability | Epistemos target |
| --- | --- | --- |
| `/read <file>` | Read file contents | Core-safe only inside user-approved vault/bookmarks; otherwise Pro gate |
| `/write <file> <content>` | Write file | Confirmation required outside Hermes workspace/vault-safe surfaces |
| `/append <file> <content>` | Append file | Same as write, append semantics |
| `/ls [path]` | List directory | Core vault/bookmark only; Pro external file browsing via Hermes |
| `/search <query>` | Search files | Native search index and Hermes file tool |
| `/grep <pattern>` | Pattern search | Native search/file bridge |
| `/notebook` | Open notebook | Map to Epistemos note/vault surface |
| `/notebook list` | List notebooks | Map to vault/notebook browser |
| `/notebook clear` | Clear notebook | Destructive confirmation required |

### Tools And Integrations

| Screenshot command | Capability | Epistemos target |
| --- | --- | --- |
| `/tools` | List tools | Native tier-aware tool catalog |
| `/tool use <name>` | Use tool | Native tool invocation with policy gate |
| `/tool add <name> <cmd>` | Add custom tool | Pro/Research only; plugin/tool approval |
| `/tool remove <name>` | Remove custom tool | Confirmation required |
| `/tool edit <name>` | Edit custom tool | Pro/Research only |
| `/mcp list` | List MCP servers | Pro/Research gateway |
| `/mcp connect <url>` | Connect MCP server | Pro/Research, persistent access confirmation |
| `/mcp disconnect <url>` | Disconnect MCP | Pro/Research, confirmation if removing saved config |
| `/mcp info` | MCP server info | Pro/Research diagnostics |
| `/web search <query>` | Web search | Pro/Research Hermes gateway; Core only if policy permits explicit web feature |
| `/web page <url>` | Fetch web page | Pro/Research Hermes gateway |
| `/calc <expression>` | Calculate expression | Core native deterministic calculator |

### UI And Display

| Screenshot command | Capability | Epistemos target |
| --- | --- | --- |
| `/theme <name>` | Change theme | Native UI settings |
| `/theme list` | List themes | Native UI settings |
| `/mode <simple|rich>` | Display mode | Native conversation mode/presentation |
| `/markdown <on/off>` | Toggle markdown | Native render setting |
| `/image <on/off>` | Toggle image display | Native multimodal setting |
| `/pager <on/off>` | Toggle pagination | Native output paging |
| `/width <num>` | Display width | Native layout setting |
| `/font <name>` | Font family | Native typography setting |
| `/fontsize <size>` | Font size | Native typography setting |
| `/colors` | Show color palette | Native theme diagnostics |

### Personas

| Screenshot command | Capability | Epistemos target |
| --- | --- | --- |
| `/persona list` | List personas | Native persona/profile browser |
| `/persona <name>` | Switch persona | Native persona switch |
| `/persona create <name>` | Create persona | Native profile create |
| `/persona edit <name>` | Edit persona | Native profile editor |
| `/persona delete <name>` | Delete persona | Confirmation required |
| `/persona export <name>` | Export persona | User-approved export |
| `/persona import <file>` | Import persona | User-approved import |
| `/persona share <name>` | Share persona | Outbound transmission confirmation |
| `/persona info <name>` | Persona details | Native profile details |
| `/persona default <name>` | Set default | Native profile preference |
| `/persona reset` | Reset persona | Confirmation if destructive |

### Messaging

| Screenshot command | Capability | Epistemos target |
| --- | --- | --- |
| `/reply` | Reply to last message | Messaging gateway action, representational communication confirmation |
| `/forward` | Forward last response | Messaging gateway action, confirmation |
| `/copy` | Copy last response | Native clipboard action |
| `/share` | Share last response | Outbound transmission confirmation |
| `/pin` | Pin important message | Native/Hermes message state |
| `/unpin` | Unpin message | Native/Hermes message state |
| `/history` | Show message history | Native/Hermes session history |
| `/stats` | Usage statistics | Native usage panel |

### Advanced

| Screenshot command | Capability | Epistemos target |
| --- | --- | --- |
| `/debug on/off` | Toggle debug | Native diagnostics |
| `/verbose <on/off>` | Verbose output | Native/Hermes progress display |
| `/trace` | Execution trace | Native trace viewer |
| `/profile` | Profile performance | Native profiling diagnostics |
| `/benchmark` | Run benchmark | Research/Pro benchmark harness; never surprise-run heavy workloads |
| `/metrics` | Show metrics | Native telemetry/metrics panel |
| `/log <level>` | Set log level | Native diagnostics |
| `/log show` | Show logs | Native log viewer |
| `/config edit` | Edit configuration | Native config UI; direct file edit only with approval |
| `/reload` | Reload configuration | Native reload action |
| `/version` | Show version | Native about/version panel |

## Official Hermes Additions Not Fully Visible In Screenshot

These are from the official docs checked on 2026-05-03 and should be included in parity planning.

### CLI Session Control

- `/retry`, `/undo`, `/title`, `/rollback`, `/snapshot`, `/queue`, `/steer`, `/goal`, `/resume`, `/redraw`, `/agents` or `/tasks`, `/background` or `/bg`, `/btw`, `/branch` or `/fork`, `/quit`.
- Epistemos target: native session browser, checkpoint restore, background-task registry, goal loop, and branch/forked deliberation surfaces.
- Safety note: rollback/snapshot restore can affect filesystem or persistent state and needs the same confirmation model as local file restoration.

### CLI Configuration And Runtime Controls

- `/config`, `/model`, `/personality`, `/verbose`, `/fast`, `/reasoning`, `/skin`, `/statusbar`, `/voice`, `/yolo`, `/footer`, `/busy`, `/indicator`.
- Epistemos target: one command palette entry per control where Core-safe; Pro/Research only for `/yolo` and external-agent behavior.
- Safety note: `/yolo` should not be mirrored literally. Epistemos can expose a Pro "reduced confirmations" mode only within explicit policy bounds, never as a global bypass.

### Tools, Skills, Toolsets, Plugins

- `/tools`, `/toolsets`, `/browser connect|disconnect|status`, `/skills`, `/cron`, `/curator`, `/reload-mcp`, `/reload`, `/plugins`.
- Epistemos target: tool catalog, toolset presets, browser status, skill manager, scheduled-task manager, skill curator, MCP reload, plugin registry.
- Tier note: browser, MCP, plugins, and cron delivery are Pro/Research unless a specific Core-safe local equivalent is implemented.

### Messaging Gateway Commands

- `/sethome`, `/commands`, `/approve`, `/deny`, `/update`, `/restart` plus messaging versions of model, personality, fast, retry, undo, compress, title, resume, usage, insights, reasoning, voice, rollback, background, queue, steer, goal, footer, curator, reload-mcp, yolo, debug, help, and dynamic skill invocations.
- Epistemos target: gateway command surface for Telegram/Discord/Slack/WhatsApp/Signal/Email/Home Assistant where configured.
- Safety note: `/approve`, `/deny`, `/reply`, `/forward`, `/share`, `/send_message`, and any messaging action are third-party communication surfaces and need action-time confirmation unless already specifically approved.

### Terminal-Level Hermes Commands

Official CLI command families to plan against:

- `hermes chat`, `model`, `fallback`, `gateway`, `setup`, `whatsapp`, `slack`, `auth`, `status`, `cron`, `kanban`, `webhook`, `hooks`, `doctor`, `dump`, `debug`, `backup`, `import`, `logs`, `config`, `pairing`, `skills`, `curator`, `memory`, `acp`, `mcp`, `plugins`, `tools`, `sessions`, `insights`, `claw`, `dashboard`, `profile`, `completion`, `version`, `update`, `uninstall`.
- Important global flags and modes: `--profile`, `--resume`, `--continue`, `--worktree`, `--yolo`, `--ignore-user-config`, `--ignore-rules`, `--tui`, `--query`, `--model`, `--toolsets`, `--provider`, `--skills`, `--image`.
- Epistemos target: expose these through native settings/task surfaces when they are user-facing, and keep lower-level terminal operations behind Pro/Research diagnostics.

## Official Tool/Toolset Parity Target

Official docs currently describe 47 built-in tools grouped by toolset, plus dynamic MCP tools. The minimum Epistemos parity categories are:

| Hermes category/toolset | Examples | Epistemos target |
| --- | --- | --- |
| Web | `web_search`, `web_extract` | Pro/Research web evidence gateway |
| Terminal/process | `terminal`, `process` | Pro/Research shell/process manager with approvals |
| File | `read_file`, `write_file`, `patch`, `search_files` | Core vault/bookmark file surface; Pro external workspace surface |
| Browser | `browser_navigate`, `browser_snapshot`, `browser_click`, `browser_type`, `browser_vision` | Pro/Research browser-use bridge |
| Media | `vision_analyze`, `image_generate`, `text_to_speech` | Native multimodal panel plus gateway providers |
| Agent orchestration | `todo`, `clarify`, `execute_code`, `delegate_task` | Native task/clarification UI; Pro code execution/delegation |
| Memory and recall | `memory`, `session_search` | Native memory substrate plus Hermes memory bridge |
| Automation and delivery | `cronjob`, `send_message` | Native automations; messaging requires confirmation |
| Home Assistant | `ha_*` | Optional Pro integration |
| MCP | dynamic `mcp-<server>` toolsets | Pro/Research MCP bridge with filtering |
| Skills | `skills_list`, `skill_view`, `skill_manage` | Native skills/plugin system bridge |
| RL/research | `rl_*` and research toolsets | Research tier only |

Terminal backends from the official docs include local, docker, ssh, singularity, modal, and daytona. Epistemos should treat all non-local or containerized execution as Pro/Research, never Core/MAS.

## Product Requirements For Epistemos

1. Unified command palette: the user should not need to remember whether a command is native, Rex, or Hermes. The UI should route it.
2. Capability registry: every command/tool maps to `Core | Pro | Research`, an authority owner, and a policy gate.
3. Structured evidence return: Hermes returns task events, tool calls, artifacts, files touched, citations, logs, and side-effect receipts.
4. Native transcript rendering: Hermes task steps appear in Epistemos as first-class activity, not raw terminal noise.
5. Persistent task records: Hermes tasks map to SwiftData records, task artifacts, and the graph/ledger only after verification.
6. Approval shim: file writes, shell, process kill, messaging, API key/auth changes, MCP config, browser/computer-use, and destructive operations pause for native approval.
7. Core/MAS separation: Core sees only local deterministic capabilities and safe vault/bookmark tools.
8. Fast path preserved: in-process Rex/provider paths remain allowed where faster and safer than forcing tokens through a subprocess.
9. Help parity: `/help` and command discovery must show the same functional surface as Hermes, but filtered by tier/distribution.
10. Provider churn containment: cloud providers and coding CLIs are registered behind the Hermes gateway/control surface, not scattered through UI code.

## Suggested Build Slices

### HERMES-PARITY-1 - Capability Registry Mirror

- Create a typed registry that enumerates screenshot commands, official slash commands, terminal command families, and toolset categories.
- Fields: `command`, `surface`, `tier`, `owner`, `requiresNetwork`, `requiresSubprocess`, `requiresApproval`, `structuredEvidence`, `nativeEquivalent`, `hermesPassthrough`.
- Acceptance: source guard test proves every command in this doc has a registry row.

### HERMES-PARITY-2 - Native Help/Command Palette Projection

- Render registry rows in an Epistemos command palette filtered by current distribution.
- Acceptance: Core build hides Pro/Research commands; Pro build shows Hermes gateway commands with clear badges.

### HERMES-PARITY-3 - Hermes Task Event Schema

- Define events for session start/end, model change, tool call, approval required, artifact produced, message sent, file touched, browser action, process action, error, and completion.
- Acceptance: schema round-trip tests and sample transcript fixtures.

### HERMES-PARITY-4 - Approval Shim Coverage

- Add policy rows for file write/append/delete, shell/run/kill, MCP connect/disconnect, plugin install/remove, messaging send/share/forward/reply, auth/API key, backup/import/rollback, and update/restart.
- Acceptance: source guard test proves no Pro/Research command bypasses approval policy.

### HERMES-PARITY-5 - Toolset Bridge

- Map Hermes toolsets to Epistemos tool policy names and MCPBridge exposure.
- Acceptance: every official toolset category resolves to either native Core, Hermes Pro/Research, Research-only, or explicit out-of-scope.

### HERMES-PARITY-6 - Messaging Gateway Projection

- Map messaging commands and send_message actions into native notification/transcript UI.
- Acceptance: no third-party communication leaves the machine without action-time confirmation.

## Immediate Follow-Up Checklist

- Add this file to `MASTER_RESEARCH_INDEX_2026_05_02.md` in the next canon merge as "Hermes capability parity target".
- When building Hermes gateway UI or command palette, start from this file plus official docs.
- Do not implement `/yolo` as a literal global bypass.
- Do not put Hermes subprocess or external tool controls into Core/MAS.
- For every new Hermes command exposed in app, add a source guard or registry completeness test.
