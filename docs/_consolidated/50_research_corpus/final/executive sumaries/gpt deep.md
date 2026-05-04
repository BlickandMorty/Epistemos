# Episdemo Pro Implementation Doctrine

## Executive summary

Yes, this is possible.

But the **best implementation is not** “scrape whatever the desktop apps are doing and hope it stays compatible.” The best implementation is to make Episdemo Pro its **own host runtime** with a clear provider abstraction, then add **compatibility adapters** for installed CLIs when that gives you better fidelity or lets you reuse existing auth and user setup. That is the difference between a durable product and a brittle wrapper. Claude now exposes an official Agent SDK and a headless CLI mode with structured JSON output; Codex exposes an official **app-server** specifically for rich client integrations; Gemini CLI is open source, scriptable, MCP-aware, and supports Docker-based sandboxing; Kimi exposes both OpenAI-compatible and Anthropic-compatible endpoints plus a CLI/config path; Hermes exposes a documented CLI, MCP server mode, plugin system, and multiple API modes, but it is best treated as a distinct runtime/faculty rather than as the foundation of your whole host. citeturn15view4turn15view5turn15view6turn20view9turn21view9turn24view0turn22view5turn17view12turn18view2turn18view7

My strongest recommendation is this:

Build Episdemo Pro around **three runtime paths** behind one UI: **Native provider path** for official APIs/app-servers, **Installed CLI path** for compatibility mode, and **Local runtime path** for Qwen and other offline models. Then expose only **two user modes**: **Chat** and **Agent**. Chat can still use bounded safe tools. Agent gets a sandbox, approvals, worktrees, shell, MCP, and long-horizon execution. Do **not** keep a separate “tools chat” as a third conceptual lane. It complicates the mental model and duplicates policy logic. citeturn15view4turn15view6turn15view8turn24view5turn22view4

For Pro, **Docker should be mandatory for Agent mode** and optional for Chat mode. That is the clean line. Codex’s local model-generated commands are guarded by an OS-enforced sandbox and approval policy; Gemini CLI supports Docker-based sandboxing and even custom project Dockerfiles; Docker’s own sandbox product now supports Claude Code, Codex, and Gemini as separate agents in isolated environments. If you want shelling out, NPM, NPX, builds, package installs, codegen, and multi-step autonomy in Episdemo Pro, you need a hard execution boundary. citeturn20view7turn21view4turn21view5turn29search1turn29search5turn29search13

For UI, do **not** let models generate raw SwiftUI source code at runtime as your main product strategy. Use **schema-driven native rendering**. OpenAI Structured Outputs, Gemini Structured Outputs, MCP Apps, and the Apps SDK / ADK direction all point the same way: the model should emit **strict structured data or UI resources**, and the host should render that through a **native component registry**. In Episdemo, that means the model produces a JSON schema or Episdemo DSL, and SwiftUI renders it. Metal should be used where GPU-native views matter, like graph views, embedding maps, timeline heatmaps, or high-density note canvases—not for your entire app shell. citeturn9search3turn0search6turn16view12turn16view13turn7search6turn7search17turn22view4turn16view16turn16view15turn16view14

On macOS distribution, because this is **Pro-only** and you want full host-level capability, the correct path is **Developer ID signing + Hardened Runtime + notarization**, not a heavily sandboxed Mac App Store architecture. Apple’s sandbox model deliberately removes most capabilities and adds them back through entitlements; child processes inherit sandbox constraints; notarization requires Hardened Runtime and applies to hosted code and plug-ins as well. Given your requirements—launching CLIs, managing Docker, spawning helpers, and hosting multiple agent runtimes—the practical answer is to keep the **main app outside App Sandbox**, sign and notarize all nested executables, and move risky autonomy into your own Docker sandbox rather than Apple’s App Sandbox. That is an inference from Apple’s distribution and sandbox model, and it is the right one for this product class. citeturn27view1turn1search4turn1search10turn27view2turn1search0turn1search6

## Core architectural stance

The architecture I would ship is this:

```text
SwiftUI 6.2 App Shell
├─ Chat mode
│  ├─ bounded tools
│  ├─ note editing / recall / search
│  └─ no shell unless explicitly elevated
├─ Agent mode
│  ├─ sandbox session
│  ├─ approvals + policy engine
│  ├─ shell/worktree/MCP/subagents
│  └─ long-running orchestration
├─ Native Renderer
│  ├─ SwiftUI component registry
│  ├─ Metal graph/canvas views
│  └─ schema-driven UI decoder
└─ Rust Core
   ├─ session orchestrator
   ├─ provider adapters
   │  ├─ Claude adapter
   │  ├─ Codex adapter
   │  ├─ Gemini adapter
   │  ├─ Kimi adapter
   │  ├─ Hermes adapter
   │  └─ Local Qwen adapter
   ├─ sandbox manager
   ├─ MCP server/client plane
   ├─ manifest compiler
   ├─ policy + approvals engine
   ├─ audit/telemetry log
   └─ FFI bridge
```

The key design choice is to make **provider protocol** and **execution substrate** two different things. Provider protocol is how you talk to the model or agent runtime. Execution substrate is where commands and writes happen. That separation matters because Claude, Codex, Gemini, Kimi, Hermes, and Qwen do **not** share the same official control surfaces. Codex has a formal app-server for rich clients; Claude has an Agent SDK and structured headless CLI; Gemini has an open-source CLI with settings, MCP, and sandbox knobs; Kimi is compatible with multiple protocols; Hermes has its own plugin and MCP ecology; Qwen is a model family, not a finished autonomy runtime. Episdemo should unify them at the host level instead of pretending they are the same product under the hood. citeturn15view6turn15view4turn15view5turn15view9turn24view0turn22view5turn17view12turn18view2turn25view1

That gives you four internal execution lanes, even though the **user** only sees two modes:

| Internal lane | What it is | When to use it | Recommendation |
|---|---|---|---|
| Native provider | Official SDK/API/app-server integration | Clean installs, production stability, full host control | **Primary** |
| Installed CLI adapter | Spawn installed CLI in PTY/subprocess and parse structured stream | Power users who already trust and use `claude`, `codex`, `gemini`, `kimi` | **Compatibility mode** |
| Local runtime | MLX/vLLM/Qwen-Agent/Ollama-style local serving | Offline, private, cheap tasks, fast note ops | **Mandatory for local-first moat** |
| Faculty runtime | Hermes or other agent runtimes as distinct engines | Experimental/advanced autonomy and research workflows | **Secondary but valuable** |

The reason for this stance is simple. Installed tooling is great for **inheritance** of auth, local conventions, and “what the user already knows,” but weak for long-term product control. Official APIs and app-servers are the reverse. So Episdemo should support both, but it should **own the host orchestration**. citeturn15view4turn15view6turn20view9turn21view9turn22view5turn17view12turn18view7

## Provider integration model

Here is the provider-specific stance I would take.

### Claude

If you want **the same agent loop and tools philosophy as Claude Code**, the official paths are the **Claude Agent SDK** and the structured/hardening-friendly **headless CLI**. Anthropic explicitly documents that the Agent SDK gives you the same tools, agent loop, and context management that power Claude Code, and the headless CLI exposes `text`, `json`, and `stream-json` output modes. Claude Code also has first-class configuration surfaces for `CLAUDE.md`, hooks, MCP, settings, and project/user scope. That means Episdemo can either embed Claude at the library/process level or treat the installed `claude` CLI as a subprocess/PTY adapter without scraping the desktop app’s internals. citeturn15view4turn15view5turn15view0turn15view1turn17view9turn17view10turn17view11turn23search0turn23search1turn23search5

The right implementation is:

- **Primary path:** Claude Adapter using `claude -p ... --output-format stream-json` or the Agent SDK.
- **Config reuse:** read/write `.claude/settings.json`, `.mcp.json`, and `CLAUDE.md`.
- **Do not** depend on private desktop app storage.
- **Do** support project-level Claude memory and skills generation.

### Codex

For Codex, the strongest official integration surface is **app-server**. OpenAI explicitly says the app-server is what powers rich clients and exists for products that need authentication, conversation history, approvals, and streamed agent events. Codex also documents project- and user-level `config.toml`, shared config layering between the CLI and IDE, shared cached login details, approval policies, sandbox modes, MCP servers, and telemetry surfaces. So for Codex, you should not stop at shelling out to `codex` unless you need a simple fallback. If you want **full-fidelity Episdemo integration**, Codex app-server should be your primary integration. citeturn15view6turn20view0turn20view1turn20view2turn15view7turn20view3turn20view6turn20view7turn20view8turn20view9

The right implementation is:

- **Primary path:** Codex app-server adapter.
- **Fallback:** Spawn installed `codex` CLI for simpler environments.
- **Config reuse:** emit `.codex/config.toml`; respect auth/cache reuse when using the CLI.
- **Security:** map Codex’s approval and sandbox concepts into your host policy engine rather than inventing a separate policy ontology.

### Gemini

Gemini gives you two very different assets: the **Gemini API**, which already supports built-in tools, function calling, code execution, file search, URL context, and computer use patterns, and the **Gemini CLI**, which is open source, MCP-aware, JSON/stream-JSON friendly, and sandboxable with Docker. That makes Gemini unusually flexible. It is a good fit for both direct API tool orchestration and installed-CLI reuse. citeturn22view0turn22view2turn22view3turn21view9turn21view0turn21view3turn24view0turn24view1turn24view5

The right implementation is:

- **Primary path:** Gemini API adapter for cloud workflows that benefit from Google-managed tools.
- **Secondary path:** Gemini CLI adapter for parity with developer workflows and MCP-heavy local usage.
- **Config reuse:** `.gemini/settings.json`, project `.gemini/`, MCP allowlists, Docker sandbox knobs.

### Kimi

Kimi is best treated as a **compatible provider**, not a special runtime that dictates your architecture. Kimi Code documents a CLI, `~/.kimi/config.toml`, `--config-file` and `--config`, stable model ID `kimi-for-coding`, and both **OpenAI-compatible** and **Anthropic-compatible** endpoints. That is exactly what you want in a unified host: Kimi can slot into your existing OpenAI-ish or Anthropic-ish transport with minimal special casing, and the CLI can be reused when the user already has it installed. citeturn15view10turn15view11turn22view5turn22view6turn22view7

The right implementation is:

- **Primary path:** OpenAI-compatible or Anthropic-compatible API adapter.
- **Fallback:** installed Kimi CLI with session-specific `--config-file`.
- **Do not** make Kimi the center of the host runtime.
- **Do** use it as a high-capability cloud fallback and coding model.

### Hermes

Hermes is different. It is not just “another API model.” Its own repo frames it as a self-improving agent with plugins, memory providers, context engines, MCP, sessions, tools, analytics, and multiple API modes. Its architecture docs describe one platform-agnostic agent core serving CLI, gateway, ACP, batch, and API server entry points, with plugin discovery from user/project directories and pip entry points. That is real power, but it also means Hermes is **its own runtime ecology**. citeturn18view0turn18view1turn18view2turn17view12turn17view13turn17view14turn17view15

My recommendation is decisive:

**Do not make Hermes your universal host substrate.**  
Make Hermes a **faculty runtime** inside Episdemo.

That means:

- Hermes can be selected as a provider/runtime in advanced settings.
- Hermes can expose or consume MCP.
- Hermes can be launched as a local or remote worker.
- But Episdemo’s own session model, policy engine, audit log, manifest compiler, and UI shell remain in control.

That preserves your moat.

## Local models and Docker sandboxing

### Local Qwen should be agentic in tiers, not all at once

Qwen3 and Qwen-Agent are strong enough to justify a real local path. Qwen’s docs explicitly recommend **Qwen-Agent** to make best use of Qwen3’s agentic ability and document MCP/function-calling routes; Qwen also documents OpenAI-compatible deployment via **vLLM** and notes Apple Silicon local paths through **MLX LM**. MLX Swift and MLX Swift LM give you an Apple-Silicon-native path if you want local inference tighter in the app stack. citeturn25view0turn25view1turn25view2turn25view3turn26search0turn26search3turn16view17

The right way to implement Qwen3-4B is this:

| Tier | Capability ceiling | Execution model | Recommended use |
|---|---|---|---|
| Tier 1 | Function calling only | No shell. Read/search/write note tools only | Fast, cheap PKM tasks |
| Tier 2 | Bounded planner + deterministic executor | Can plan multi-step tasks, but only against a pre-approved tool graph | Default local “agent-lite” |
| Tier 3 | Full agent in sandbox | Shell, file ops, subprocesses, worktree, retries, escalation | Only after benchmark and guardrail gates |

The escape hatch is simple: when the local model’s confidence is low, the task requires long context, or a Tier 3 policy would fire repeatedly, **escalate to cloud**. That is not a failure. That is a professional product behavior. citeturn25view0turn25view1turn22view3turn17view8

### Docker is not optional for real Agent mode

Docker’s own reference docs distinguish **named volumes** for persisted container data and **bind mounts** for host↔container sharing, and their Dockerfile docs explain the `ENTRYPOINT`/`CMD` contract. Docker’s build best practices also stress small trusted base images. Gemini CLI already defaults to a pre-built sandbox image for sandbox mode, and Docker Sandboxes now supports Claude Code, Codex, and Gemini as separate agent sandboxes. citeturn16view10turn16view9turn16view8turn16view11turn24view1turn21view5turn29search1turn29search5

So the implementation rule should be:

- **Chat mode:** Docker optional.
- **Agent mode:** Docker required.
- **No host-shell full autonomy** outside a compatibility lane the user explicitly enables.

For Pro, I would use these defaults:

| Setting | Default |
|---|---|
| Workspace mount | bind mount, read-write, session-scoped |
| Dependency cache | named volume |
| Temp secrets / scratch | tmpfs |
| Root filesystem | read-only where possible |
| Network | off by default; setup-only allowlist when required |
| User in container | non-root |
| File sync back | explicit or controlled teardown only |

This is also the clean answer to your earlier product question: **Codex local is not “Docker-native” by default; it uses a local OS-enforced sandbox. Gemini CLI can use Docker directly. Claude has official managed-agent sandboxing on the API side and can also run inside Docker Sandboxes, but that is a separate deployment layer.** You should adopt Docker in Episdemo because **your app** needs a stable execution boundary, not because every upstream desktop app is Docker-first. citeturn20view7turn24view1turn29search0turn29search3turn29search15

Here is the Docker pattern I would actually start with:

```dockerfile
FROM node:22-bookworm-slim

RUN apt-get update && apt-get install -y \
    git curl ca-certificates bash python3 python3-pip \
 && rm -rf /var/lib/apt/lists/*

# Non-root execution
RUN useradd -m -u 1000 agent
USER agent
WORKDIR /workspace

ENV HOME=/home/agent \
    NPM_CONFIG_CACHE=/home/agent/.npm \
    PNPM_HOME=/home/agent/.local/share/pnpm \
    PATH=/home/agent/.local/bin:$PATH

COPY --chown=agent:agent entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
```

```bash
#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.npm" "$HOME/.cache" /workspace
cd /workspace

# Optional: one-time project bootstrap
if [[ -f ".episdemo/bootstrap.sh" ]]; then
  bash .episdemo/bootstrap.sh
fi

exec "$@"
```

The important idea is not this exact image. The important idea is the **boundary**: the agent lands in a prepared workspace with bounded mounts and a known user, and your Rust core decides when the network is available. That follows Docker’s documented mount model and the broader agent-sandbox guidance from OpenAI and Google. citeturn16view8turn16view9turn16view10turn16view11turn17view7turn22view1

## Native stack and schema-driven UI

### Rust core, Swift shell, split FFI by purpose

The most robust design here is **control plane vs data plane**.

Use **UniFFI** for the **stable control plane**: session lifecycle, manifest compiler calls, policy checks, note CRUD, routing decisions, provider selection, and high-level orchestration. UniFFI explicitly supports production-quality Swift bindings and documents the Xcode integration flow. citeturn28view1turn28view0

Use **BoltFFI or a thin C ABI** for the **hot data plane**: token streaming, event streams, low-overhead structs, binary blobs, and high-frequency UI updates. BoltFFI’s own docs emphasize cross-platform packaging, Swift bindings, and a zero-copy approach where possible. Rust’s own FFI docs remain the baseline truth for the C ABI boundary. citeturn28view2turn28view3turn28view4turn28view6turn28view8

That gives you this split:

```rust
// crates/core-api/src/lib.rs
use uniffi::export;

#[derive(Clone, Debug)]
pub enum Mode {
    Chat,
    Agent,
}

#[derive(Clone, Debug)]
pub struct SessionConfig {
    pub mode: Mode,
    pub provider: String,
    pub enable_sandbox: bool,
    pub vault_root: String,
}

#[derive(Clone, Debug)]
pub struct SessionHandle {
    pub id: String,
}

#[export]
pub async fn start_session(cfg: SessionConfig) -> Result<SessionHandle, String> {
    // validate config, compile manifest, allocate routing lane,
    // create sandbox if needed, then start provider adapter
    todo!()
}

#[export]
pub async fn stop_session(id: String) -> Result<(), String> {
    todo!()
}
```

```rust
// crates/stream-bridge/src/lib.rs
#[repr(C)]
pub struct StreamEvent {
    kind: u32,        // token, tool_call, approval_request, etc.
    len: usize,
    ptr: *const u8,
}

pub type EventCallback = extern "C" fn(ctx: *mut core::ffi::c_void, ev: StreamEvent);

#[unsafe(no_mangle)]
pub extern "C" fn episdemo_subscribe(
    session_id_ptr: *const u8,
    session_id_len: usize,
    ctx: *mut core::ffi::c_void,
    cb: EventCallback,
) -> i32 {
    // store callback and push encoded events
    0
}
```

That is the right engineering compromise. UniFFI is excellent for ergonomic coarse APIs. A lower-level bridge is better for event-heavy streams. citeturn28view1turn28view0turn28view2turn28view6turn28view8

### Swift 6.2 and Metal patterns

Swift 6.2’s “Approachable Concurrency” and the recent SwiftUI concurrency guidance make it much easier to keep app state sane. Apple’s recent guidance also points to default actor isolation improvements, and SwiftUI’s Observation system is the right state model for modern app architecture. On the GPU side, Apple’s own Metal guidance still points toward **triple buffering**, **limited command buffer count**, and deliberate storage/resource choices. citeturn16view0turn16view2turn2search1turn2search15turn16view16turn16view15turn16view14

So the pattern is:

- Use **SwiftUI + Observation** for the whole shell.
- Use **actors** for session state, routing state, audit pipelines, and model stream ingestion.
- Use **Metal** only for graph/canvas-heavy surfaces.
- Prefer **one command buffer per frame** and **triple-buffered dynamic resources** in those views.

A good Swift-side renderer foundation looks like this:

```swift
import SwiftUI
import Observation

@Observable
final class UISessionStore {
    var tree: UINode = .empty
    var values: [String: UIValue] = [:]
    var loading = false
    var status = "Ready"
}

enum UINode: Decodable, Equatable {
    case vstack(children: [UINode], spacing: Double?)
    case hstack(children: [UINode], spacing: Double?)
    case text(id: String?, value: String, role: String?)
    case editor(id: String, placeholder: String?)
    case todoList(id: String, items: [TodoItem])
    case planner(id: String, sections: [PlannerSection])
    case graph(id: String, query: String)
    case empty
}

struct DynamicRenderer: View {
    @Bindable var store: UISessionStore

    var body: some View {
        render(store.tree)
    }

    @ViewBuilder
    private func render(_ node: UINode) -> some View {
        switch node {
        case let .vstack(children, spacing):
            VStack(spacing: spacing) {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    render(child)
                }
            }
        case let .text(_, value, _):
            Text(value)
        case let .editor(id, placeholder):
            TextEditor(text: Binding(
                get: { store.values[id]?.stringValue ?? "" },
                set: { store.values[id] = .string($0) }
            ))
            .overlay {
                if (store.values[id]?.stringValue ?? "").isEmpty, let placeholder {
                    Text(placeholder).foregroundStyle(.secondary)
                }
            }
        case let .todoList(id, items):
            TodoListView(id: id, items: items)
        case let .planner(id, sections):
            PlannerView(id: id, sections: sections)
        case let .graph(id, query):
            GraphMetalView(viewModel: .init(id: id, query: query))
        case .hstack(let children, let spacing):
            HStack(spacing: spacing) {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    render(child)
                }
            }
        case .empty:
            EmptyView()
        }
    }
}
```

That is how you make the UI feel native **without** turning the product into a runtime Swift code compiler.

### The UI should be schema-driven

OpenAI’s Structured Outputs guarantees JSON that adheres to your schema. Gemini explicitly distinguishes structured outputs from function calling and recommends structured outputs when the final response needs to drive a custom UI. MCP Apps standardizes UI resources through `ui://` plus auditable host↔UI messaging, and the Apps SDK / ADK ecosystem is pushing in the same direction. citeturn9search3turn22view3turn16view13turn7search6turn7search17turn7search3turn7search1

So the Episdemo UI contract should look like this:

```json
{
  "type": "object",
  "required": ["screen"],
  "properties": {
    "screen": {
      "type": "object",
      "required": ["kind", "nodes"],
      "properties": {
        "kind": { "type": "string", "enum": ["scratchpad", "todo", "planner", "review"] },
        "title": { "type": "string" },
        "nodes": {
          "type": "array",
          "items": { "$ref": "#/$defs/node" }
        }
      }
    }
  },
  "$defs": {
    "node": {
      "type": "object",
      "required": ["type"],
      "properties": {
        "type": { "type": "string", "enum": ["text", "editor", "todoList", "planner", "graph"] },
        "id": { "type": "string" },
        "label": { "type": "string" },
        "value": {},
        "children": {
          "type": "array",
          "items": { "$ref": "#/$defs/node" }
        }
      }
    }
  }
}
```

My recommendation is to let models generate:

- **UI schema**
- **UI state**
- **tool intents**
- **layout variants**

But **not** raw executable UI code at runtime.

If you want “AI-generated UI,” the real product move is this:

**Model generates schema. Host renders natively. Human-curated components keep the app coherent.**

## Manifest compiler and Pro settings

### Build a single project manifest compiler

You need one internal source of truth. Not five drifting config writers.

The compiler should take a single project/session manifest and emit:

- `CLAUDE.md`
- `.claude/settings.json`
- `.mcp.json`
- `.codex/config.toml`
- `.gemini/settings.json`
- optional `GEMINI.md`
- session-scoped Kimi config file
- optional Hermes profile/config
- `AGENTS.md` as a neutral cross-tool fallback

This is the right abstraction because Claude, Codex, Gemini, and Kimi all document project/user configuration surfaces, but they differ in file names, hierarchy, auth behavior, and transport details. A compiler lets Episdemo own one policy model and project identity while still speaking each tool’s native dialect. citeturn15view0turn23search0turn15view7turn20view6turn21view0turn21view3turn15view10turn15view11

A minimal manifest might look like this:

```toml
project_id = "episdemo-vault"
vault_root = "/Users/jojo/Vault"
default_mode = "chat"
default_provider = "auto"

[policy]
allow_network_setup = true
allow_shell_in_chat = false
allow_shell_in_agent = true
read_secrets = false
write_internal_state = false

[providers.claude]
path = "installed-cli"
model = "claude-sonnet-4-6"

[providers.codex]
path = "app-server"
model = "gpt-5.4"

[providers.gemini]
path = "native-api"
model = "gemini-3.1-pro-preview"

[providers.kimi]
path = "openai-compatible"
model = "kimi-for-coding"

[providers.qwen]
path = "local"
tier = 2
endpoint = "mlx"
model = "Qwen3-4B"

[providers.hermes]
path = "faculty"
enabled = true
```

And the compiler shape in Rust should be roughly:

```rust
pub fn compile_project(manifest: &ProjectManifest) -> anyhow::Result<()> {
    let artifacts = vec![
        emit_claude_md(manifest)?,
        emit_claude_settings(manifest)?,
        emit_mcp_json(manifest)?,
        emit_codex_toml(manifest)?,
        emit_gemini_settings(manifest)?,
        emit_gemini_md(manifest)?,
        emit_kimi_session_config(manifest)?,
        emit_agents_md(manifest)?,
    ];

    for artifact in artifacts {
        atomic_write_if_changed(&artifact.path, &artifact.contents)?;
    }

    Ok(())
}
```

The key point is **atomic, idempotent writes**. Your manifest compiler should never spray partial state into the workspace.

### Pro settings UI that actually works

Here is the settings model I would ship.

#### Primary controls

| Control | Default | Why |
|---|---|---|
| Mode | **Chat** | Safe default |
| Thinking effort | **Balanced** | Separate from mode |
| Provider runtime | **Auto** | Host chooses best path |
| Agent sandbox | **Required** | Hard rule for Agent mode |
| Network policy | **Setup only** | Install/build allowed, then clamp |
| Approval policy | **Ask on writes and shell risk** | Keeps trust high |
| Local model tier | **Tier 2** | Best local default |
| Cloud escalation | **On** | Reliability over heroics |
| Telemetry export | **Off** | Local-first default |
| Audit log | **On** | Mandatory for autonomy |

#### Advanced controls

| Control | Default |
|---|---|
| Claude path | Auto: Agent SDK/headless if available, else API |
| Codex path | App-server if available, else CLI |
| Gemini path | API for tool-heavy cloud, CLI for MCP-heavy local |
| Kimi path | Compatible API |
| Hermes path | Off by default, faculty-only |
| Session worktree | On in Agent mode |
| MCP server transport | stdio |
| UI generation policy | Schema-only |
| Metal graph rendering | On for graph/canvas views |
| Allow installed runtime auth reuse | Ask once per provider |

This is the right UI simplification:

- **Mode** is only **Chat** or **Agent**.
- **Thinking effort** is a separate popover.
- **Tools are not a mode.**
- In Chat mode, safe tools still work.
- In Agent mode, shell/subagents/worktrees/sandbox unlock.

That maps far better to how modern tools actually behave. Codex, Claude, and Gemini all already blur “chat” and “tools”; the real distinction is whether the system is allowed to operate **autonomously over time** with an execution substrate and approval model. citeturn15view8turn20view8turn24view5turn22view3

### Project bootstrap and auto-init flow

Your bootstrap should do this:

1. Detect installed runtimes on `PATH`.
2. Detect whether Docker is available.
3. Ask once whether the user wants to reuse existing provider auth/config where supported.
4. Create or load the project manifest.
5. Emit provider-native config files.
6. Start `epistemos-mcp` for vault tools.
7. Warm local model/cache if enabled.
8. Create the first session with audit logging enabled.

For Claude, project memory belongs in `CLAUDE.md`; for Codex, project config belongs in `.codex/config.toml`; for Gemini, project config belongs in `.gemini/settings.json`; for Kimi, because CLI config can be passed at runtime, I would prefer **session-scoped config files** generated into Episdemo state rather than mutating the user’s global `~/.kimi/config.toml` unless they explicitly opt in. citeturn23search0turn15view7turn21view0turn15view10

## Security, testing, and delivery

### Security hardening checklist

These are the non-negotiables.

| Area | Requirement |
|---|---|
| macOS distribution | Developer ID sign, Hardened Runtime, notarize app and all nested executables |
| Main app privileges | No App Sandbox for Pro main binary; isolate risky actions in Docker |
| Shell execution | Deny by default outside Agent mode |
| Agent mode | Docker required |
| Secrets | Never mount host secret directories into container |
| File writes | Workspace-scoped allowlist only |
| Network | Off by default; allowlist or setup-only phases |
| Policy engine | Effect classes: read, write, shell, network, external, destructive |
| Audit | Append-only local event log plus optional OTel export |
| Recovery | Every session resumable from audited state |

Apple’s docs make the distribution part clear: outside the App Store you should sign with Developer ID, enable Hardened Runtime, and notarize; nested hosted code matters for notarization. Apple’s sandbox docs also make clear that App Sandbox removes capabilities and adds them back by entitlement, and child processes inherit the parent sandbox. Docker, OpenAI, and Google all reinforce the same product lesson: if the agent is going to execute commands, isolation is not optional. citeturn27view2turn1search0turn27view1turn1search4turn16view9turn17view7turn22view1

### Testing and CI

Your CI should be designed around **contracts**, not just unit tests.

| Test class | What it proves |
|---|---|
| Manifest golden tests | Correct config emission for Claude/Codex/Gemini/Kimi |
| Provider adapter fixtures | Your parser survives stream-json / app-server / CLI changes |
| Policy tests | Dangerous reads/writes/shell/network are blocked |
| Sandbox escape tests | Prompt injection cannot leave workspace boundary |
| FFI tests | Rust↔Swift ABI and streaming stability |
| Schema renderer snapshots | UI DSL renders deterministically |
| Local model benchmark gate | Tier 3 only unlocks on measured quality |
| Notarization pipeline | The distributed artifact is actually publishable |

For telemetry, use a normalized internal event schema and map vendor-specific events into it. Claude already supports OTel export guidance; Codex documents telemetry events and approval/sandbox metadata; Gemini documents telemetry fields in CLI config. That lets Episdemo log once and optionally export later. citeturn29search16turn20view8turn24view3

### Phased implementation plan

#### MVP

Ship the host runtime.

- Two modes: Chat / Agent
- Claude headless/SDK adapter
- Codex app-server adapter
- Gemini API + CLI adapter
- Kimi compatible API adapter
- Qwen Tier 1 and Tier 2
- Docker sandbox manager
- Manifest compiler
- Schema-driven renderer v1
- Local audit log
- Basic approvals engine

#### V1

Ship the moat.

- Hermes faculty runtime
- Worktrees for Agent mode
- unified MCP server/client layer
- richer provider routing
- cloud escalation from local failure
- OTel exporter
- graph Metal views
- component registry expansion

#### V2

Ship the “grand” experience.

- Qwen Tier 3 full local agent
- multi-agent councils / deliberation teams
- MCP Apps-compatible UI resources
- richer remote execution targets
- learned policy suggestions
- session memory distillation
- design-time AI codegen for new native components

The decision rationale is straightforward: the MVP gives you a stable host. V1 makes it differentiated. V2 makes it category-defining.

## Open questions and limitations

A few details are still genuinely moving and should be treated as version-pinned implementation choices, not eternal truths.

Hermes is powerful, but its public surface is still best understood through the repo’s CLI, architecture docs, and release notes rather than a single stable external SDK. Pin Hermes integration to a specific release or git SHA. citeturn17view12turn18view0turn18view1turn17view15

Kimi’s compatibility story is strong, but “100% parity” with Kimi Code CLI or future Kimi desktop behavior is not something any third-party host can guarantee. What you can guarantee is robust support for its compatible APIs and CLI configuration model. citeturn22view5turn15view10turn15view11

Claude, Codex, and Gemini desktop/IDE products will continue to evolve. The way to stay close to “full functionality” is **not** to chase every private UI behavior. It is to anchor Episdemo to their **documented integration surfaces** and keep installed-CLI compatibility as a separate lane. citeturn15view4turn15view6turn21view9

The bottom line is this:

**Build Episdemo Pro as the host runtime.**  
**Use official provider integrations as the backbone.**  
**Use installed CLIs as compatibility adapters, not the foundation.**  
**Require Docker for Agent mode.**  
**Render AI-generated UI from schemas, not raw runtime Swift code.**

That is the best path to something grand, durable, and actually shippable.