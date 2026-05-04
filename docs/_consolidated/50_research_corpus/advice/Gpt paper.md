# Episdemo can do this, but only if you treat the agent runtime as the product

The short answer is **yes**: you can make Episdemo feel “plug and play,” where a fresh session can open on a user’s project and immediately act like a serious coding or note-operating agent that can read files, write files, run commands, use MCP tools, and inherit project instructions. But the clean path is **not** to automate consumer desktop apps by scraping their UI or reverse-engineering their private state. The durable path is to make **Episdemo itself** the host runtime and then plug in officially supported agent backends. Officially, entity["company","Anthropic","ai company"], entity["company","OpenAI","ai company"], entity["company","Google","technology company"], and entity["company","Alibaba Cloud","cloud company"] all expose supported agent/tool surfaces that are much better foundations than “driving the desktop app from the outside.” citeturn33view0turn33view1turn16view0turn16view3turn31view0turn31view1turn31view2turn34view0turn34view1

That means the right mental model is:

**Episdemo owns the workspace, approvals, sandbox, session state, vaults, and UI.**  
**Provider runtimes plug into that.**  
**MCP is the common tool layer.**  

If you build it that way, users do **not** need to live inside Claude Desktop, Codex App, or Gemini CLI to get the core value. Those products become optional runtimes or compatibility modes, not the center of your system. citeturn10view2turn3search0turn8view1turn31view4turn31view6turn34view0

## What is actually possible with each provider

For **Claude**, the strongest official path is the **Claude Agent SDK**, not trying to embed the consumer desktop app. Anthropic’s SDK explicitly says it gives you the **same tools, agent loop, and context management that power Claude Code**, and it can load the same filesystem-based features that Claude Code uses: `CLAUDE.md`, rules, skills, hooks, and `.claude/` settings. Claude also has first-class hooks, skills, subagents, memory, and initialization flags like `claude --init` and `claude --init-only`, which is exactly the kind of bootstrap surface you want for automatic project setup. citeturn33view0turn33view1turn12search7turn12search0turn12search1turn10view1turn10view3

Claude also gives you a partial answer to your “can I just text it from somewhere else and still have local power?” question. **Remote Control** lets a local Claude Code session keep running on the user’s machine while the user continues it from `claude.ai/code` or the mobile app, and **Channels** let external events or chat bridges push messages into a running local session. The catch is important: those modes still require a **live local Claude process** and supported Claude login, and the local machine remains the execution environment. So this is real, but it is **session continuation over a local runtime**, not “the cloud chat magically has local shell powers by itself.” citeturn18search0turn19search1turn19search0turn18search5

For **OpenAI**, I’m assuming your “Kodex” means **Codex**. If that is right, this is the most compelling officially documented “embed this into my own app” story right now. OpenAI exposes **Codex app-server**, which it describes as the interface Codex itself uses to power rich clients, and specifically says to use it for **authentication, conversation history, approvals, and streamed agent events** inside your own product. Separately, Codex app, CLI, and IDE surfaces share configuration, and the CLI/extension share cached auth. So if a user already has Codex set up, Episdemo can realistically reuse that environment in an official way. This is a much better foundation than trying to puppet the ChatGPT desktop app. citeturn16view0turn32view2turn32view0turn32view1turn16view3turn16view4turn16view2

For **Gemini**, the official story is more API- and CLI-centered. Gemini’s API supports **function calling**, **structured outputs**, and built-in tools like **Google Search, URL Context, Maps, Code Execution, and Computer Use**. Their docs are explicit that function calling and Computer Use still require **your client code** to execute the actions and continue the loop. Google also has the open-source **Gemini CLI**, which supports user and project settings, MCP server configuration, allowlists, tool restrictions, sandboxing via Docker, and enterprise controls. If you want runtime parity, you can either launch Gemini CLI as an adapter or integrate at the API/ADK layer and keep the orchestration inside your own app. citeturn31view0turn31view1turn31view2turn31view3turn8view0turn8view1turn8view2turn31view4turn31view5

## The architecture that best fits Episdemo

The winning architecture for Episdemo is a **host-orchestrator pattern**:

- A **Rust core** owns session state, approvals, audit trail, tool policy, filesystem mapping, and container lifecycle.
- A **provider adapter layer** exposes Claude, Codex, Gemini, and local Qwen through one internal contract.
- An **MCP-first tool plane** becomes the common interface for your vault ops, search, note CRUD, planner/todo mutations, external integrations, and provider-specific extras.
- The **UI layer** becomes a renderer of structured state and streamed events, not the place where capability logic lives.

That design lines up with the official direction of the major runtimes. Claude’s Agent SDK is explicitly embeddable and reads the same `.claude` feature set as Claude Code. Codex app-server is explicitly meant for embedding rich Codex clients. Gemini’s API and ADK make the client responsible for tool execution and orchestration. MCP is supported across Claude Code, Codex, Gemini tooling guidance, ADK, and Qwen-Agent. citeturn33view0turn33view1turn16view0turn31view1turn31view4turn31view6turn10view2turn4search0turn34view0

For execution, use entity["company","Docker","container software company"] as the **sandbox substrate**, not as the orchestration brain. Docker’s docs are clear on the basic primitives you need: bind mounts are for sharing host project directories into containers, volumes are the preferred way to persist Docker-managed data, `docker run` creates the sandbox, and `docker exec` lets you run commands inside a running container. In practice, that means: bind-mount the user’s vault/project into the container, keep provider caches and ephemeral runtime data in named volumes, and let your Rust core decide what commands are allowed and when approvals are required. citeturn14search0turn14search6turn14search11turn14search1turn14search2

The most important product decision is this:

**Prefer native provider integrations first.**  
**Use installed CLI/app reuse second.**  
**Use desktop piggybacking last, and only where officially supported.**

Concretely, your settings screen can expose exactly the toggle idea you described:

- **Native runtime mode**: Claude Agent SDK, Codex app-server, Gemini API/ADK.
- **Reuse installed runtime mode**: read and honor `.claude`, `.codex`, `.gemini` homes/configs where the provider officially supports shared config or auth reuse.
- **Local model mode**: Qwen served locally through an OpenAI-compatible endpoint plus a wrapper that provides tool use and agent control.

That gives users flexibility without making your product depend on unstable reverse-engineering. citeturn33view0turn16view0turn16view3turn16view4turn8view1turn8view2turn34view1

## How to make new sessions boot themselves

This is where you can make Episdemo feel magical.

The core move is to define a single **Episdemo project manifest** and compile it into provider-specific artifacts at session start. Instead of manually wiring UI affordances to capabilities, you write one canonical manifest that says:

- what the project root is,
- what tools are available,
- what the policy is,
- what instructions should persist,
- what MCP servers should load,
- what the workspace sandbox looks like,
- and what provider-specific defaults should exist.

From that one manifest, Episdemo materializes:

- `CLAUDE.md`, `.claude/settings.json`, optional hooks/skills/rules,
- `.codex/config.toml`,
- `.gemini/settings.json`,
- local-model tool manifests,
- and your own internal vault/session metadata.

This is exactly the right abstraction because the providers themselves are already file- and config-driven. Claude has hierarchical settings, project/user/local scopes, `CLAUDE.md`, hooks, skills, and init hooks. Codex has user and project `config.toml`, shared MCP settings, shared auth/config across surfaces, and non-interactive execution. Gemini CLI has user/project `settings.json`, `mcpServers`, allowlists, include/exclude tool controls, and Docker sandbox configuration. citeturn10view0turn10view1turn12search0turn12search1turn16view3turn3search2turn3search16turn8view1turn8view2

For Claude specifically, automatic bootstrap is unusually strong. `CLAUDE.md` is designed to carry project instructions across sessions, hooks are deterministic automation points, and Anthropic explicitly distinguishes advisory instructions from deterministic hooks. If you want files auto-formatted after edits, protected paths blocked, context re-injected, or environment reloaded on directory change, hooks are the official mechanism—not prompt hacks. That matters because it is the difference between “the agent usually remembers” and “the runtime always does the thing.” citeturn10view1turn12search1turn12search3turn11search12

For Codex, the most powerful thing you can do is not just spawn the CLI but support the **app-server** path wherever possible. It already models approvals, conversation items, streamed events, skills, auth modes, and even external ChatGPT token ownership in an experimental mode for host apps. If you only need CI-style automation, `codex exec` is enough. If you want Episdemo to feel like a real first-party client, app-server is the better target. citeturn16view0turn32view0turn32view1turn16view5

For trusted local automation, OpenAI’s docs even describe copying Codex auth into a Docker container, but they are equally clear that **API keys are the recommended default for automation** and that `auth.json` should be treated like a password. So for a consumer-friendly product, the cleaner pattern is: use API keys for programmatic sessions, allow app/CLI auth reuse only on trusted local machines, and never blur that boundary. citeturn16view4turn16view5

## How to make Qwen3-4B truly agentic

Yes, you can make your local Qwen tier agentic. But there’s a trap here.

The trap is thinking “tool calling exists” means “this small local model can replace your strongest cloud planner.”  
That is not the same thing.

What the docs say is encouraging: Qwen3 supports tool calling and multi-turn tool use, Qwen-Agent is the canonical framework for Qwen3 function calling, it can wrap OpenAI-compatible APIs that do not natively support function calling, and Qwen’s own docs recommend vLLM for deployment because it can expose an OpenAI-compatible server. Qwen also documents local runs through llama.cpp, and Qwen3-Coder introduced a dedicated agentic coding CLI. citeturn34view2turn34view1turn34view0turn34view3turn23search0turn23search10turn34view4turn34view5

So the right design is a **three-tier local-model strategy**:

A **fast local tier** for bounded PKM work.  
Use Qwen3-4B for note drafting, reformatting, link suggestions, summarization, tagging, extracting action items, low-risk vault CRUD, and tightly allowlisted tool calls. This is where low latency and low cost matter more than long-horizon reasoning. This recommendation is an engineering inference, but it is strongly supported by the fact that Qwen’s local stack is built around tool wrappers and OpenAI-compatible serving rather than “drop this tiny model in and expect full autonomous coding parity.” citeturn34view1turn34view0turn34view3

A **bounded local agent tier** for short command chains.  
Give the local model a small tool belt: read, write, search, run a handful of shell commands, maybe run tests or lint with strict allowlists and budget caps. Let it operate in a container and retry within a small horizon. Qwen’s docs explicitly support MCP, code-interpreter extras, and multi-step tool calling, so this tier is realistic. citeturn34view0turn34view2turn34view1

A **cloud escalation tier** for long-horizon or high-ambiguity work.  
This is the escape hatch you asked for. When the task hits repo-scale reasoning, multi-file refactors, fragile debugging, or high-stakes agent loops, hand off to Claude/Codex/Gemini. That is not a failure of the local tier; it is good routing. The strongest Qwen agentic results publicly emphasized in the Qwen3-Coder announcement are on a **much larger** model family and specifically on agentic coding, tool use, and browser use benchmarks. That is strong evidence that your local 4B lane should be a **smart edge worker**, not the king of the system. citeturn34view5

## The UI should be generated from schemas, not improvised every time

This is the place where your past attempts probably got jammed.

If scratchpad, todo, planner, and related PKM surfaces are all variations on the same few interaction patterns, then manually engineering every micro-UI around every model is the wrong level of abstraction. The better way is:

**Have models generate structured intent.**  
**Have Episdemo render trusted components.**

All three major cloud stacks now support structured outputs or schema-constrained tool inputs. Claude has structured outputs and strict schemas for tool use. Gemini supports structured outputs against JSON Schema. OpenAI supports structured outputs in the API and structured agent/tool workflows in the Responses and Agents layers. That makes a schema-first UI architecture far more reliable than asking a model to free-write production UI code on every turn. citeturn25search2turn25search20turn31view3turn4search6turn4search8turn25search3

So for Episdemo, I would split UI generation into three levels:

**Production default: schema-driven UI.**  
The model returns JSON like `note_card`, `task_list`, `plan_board`, `timeline`, `relation_graph`, `review_queue`, with typed fields and actions. Your app has a component registry that knows how to render those safely and consistently. This is the best fit for your scratchpad/todo/planner vision because those surfaces are structurally similar. citeturn25search2turn31view3turn4search8

**Advanced mode: DSL-to-components.**  
If you want more flexibility, let the model output a constrained layout DSL or design schema that compiles to your own components. The model describes the arrangement; your runtime still owns rendering. This gives you far more expressive power than static forms without the security and maintainability mess of arbitrary codegen. The ecosystem trend supports this direction: Google’s ADK integrations catalog explicitly lists **A2UI** and **AG-UI**, which signals real momentum toward structured agent-to-UI protocols. citeturn20search4turn28search0

**Experimental only: free-form codegen UI.**  
You *can* let a strong model write UI code, but only in a preview sandbox or isolated webview/iframe with human review. Do not make this the core runtime path for your planner/scratchpad surfaces. It is too brittle, too hard to secure, and too hard to keep visually coherent at scale. The fact that all the major platforms are investing in structured tool and UI-like protocols is the tell here: the industry is moving away from raw “LLM writes the whole frontend live” as the default runtime pattern. citeturn25search20turn20search4turn28search0

## Security is not optional because the whole point is command execution

Your app only becomes “big” if it is powerful.  
And it is only safe if the power is bounded.

The clean pattern, echoed across these systems, is **trusted harness outside, generated execution inside**. OpenAI’s sandbox-agent guidance explicitly separates orchestration from execution: the host harness keeps tools, credentials, audit, and policy, while the sandbox handles files, commands, and task-local state. Codex’s sandbox docs say the sandbox is the boundary that lets Codex act autonomously without unrestricted access, and approval policy sits on top of that. Gemini’s Computer Use docs explicitly caution that you should run the agent in a secure controlled environment, supervise closely, and keep client-side action execution under your control. Claude’s hook and permission stack gives you deterministic enforcement points before tool execution. citeturn29search0turn29search2turn29search4turn31view2turn12search1turn33view2

Practically, Episdemo should enforce at least these guardrails:

- **Per-tool approval policy**, with session-grant and single-use options. Both Claude and Codex expose approval mechanisms designed for this. citeturn33view2turn32view0
- **Sandbox profiles**, such as read-only, workspace-write, and elevated/full-access. Codex and Gemini both document this shape clearly. citeturn16view3turn29search4turn8view2
- **MCP allowlists**, include/exclude tool controls, and trust flags. Gemini CLI explicitly documents `mcp.allowed`, `includeTools`, and `excludeTools`; Claude warns that third-party MCP servers are unverified and can create prompt-injection risk; Codex exposes MCP configuration and approval modes. citeturn8view1turn8view2turn10view2turn3search0turn3search12
- **Credential separation**, where host secrets stay outside task sandboxes. OpenAI’s sandbox guidance and Codex auth guidance both point in that direction. citeturn29search2turn16view4
- **Audit/event logging**, because these agents produce multi-step side effects. Codex app-server and ADK both expose the event-oriented architecture you want to mirror. citeturn32view2turn16view0turn31view5

If you skip this layer, the app may look magical for a week and then become unshippable the moment users start trusting it with real vaults, repos, and credentials.

## The best stack-specific recommendation for Episdemo

If the goal is to make this the **core of the app**, not a gimmick, I would build Episdemo in this order.

First, build a **Rust orchestration core** that owns:

- session ledger,
- policy and approvals,
- event stream,
- Docker workspace lifecycle,
- provider manifest compilation,
- MCP server registry,
- and the normalized tool/result schema that every provider adapter must obey.

That gives your FFI boundary a clean job: Rust handles truth and side effects; the TypeScript or desktop UI layer renders state, approvals, and artifacts. This is a synthesis recommendation based on the fact that the provider stacks are all event-, config-, and tool-driven rather than UI-driven. citeturn33view0turn16view0turn31view1turn31view6

Second, ship two premium adapters first:

- **Claude adapter = Claude Agent SDK.** This is the best way to make Claude inside Episdemo feel like Claude Code while still loading `CLAUDE.md`, skills, hooks, and `.claude` project conventions. citeturn33view0turn33view1
- **OpenAI adapter = Codex app-server.** This is the best way to get “full Codex-style capabilities” inside your own app with official support for auth, streamed events, approvals, skills, and rich client behavior. citeturn16view0turn32view0turn32view1

Third, ship a **local-model adapter** based on **vLLM + Qwen-Agent**. That gives you one OpenAI-compatible local endpoint, one agent wrapper, one MCP/tool strategy, and a clean way to escalate upward when the local model hits its ceiling. Qwen’s own docs practically describe this route for you. citeturn34view3turn34view1turn34view0

Fourth, add the **Gemini adapter** either as:

- a direct Gemini API / ADK integration for structured, product-owned orchestration, or
- an optional Gemini CLI compatibility adapter for users who want to reuse an installed local setup.

That keeps Gemini in the system without forcing your product to depend on a shell wrapper when you do not need one. citeturn31view0turn31view1turn31view2turn8view0turn8view1turn8view2turn31view5

Fifth, make the UI **schema-first** from day one. Let the models generate note/task/planner structures, not uncontrolled runtime code. If you want AI-generated component creation, do it in an **admin/dev studio** that creates new reusable templates for Episdemo—not in the live user path on every request. citeturn25search2turn31view3turn4search8turn20search4

If you do those five things, the “court of the app” becomes clear:

**Episdemo is the workspace OS.**  
**Claude, Codex, Gemini, and Qwen are runtimes inside it.**  
**MCP is the universal tool cable.**  
**Docker is the execution boundary.**  
**The UI is generated from trusted schemas and rendered by your app.**  

That is the version of your idea that can actually scale.

## Open questions and limitations

I assumed **“Kodex” means Codex**. If you meant a different product, only the OpenAI/Codex section would need to change.

I did **not** find an official, documented equivalent of “embed the consumer Claude desktop app itself into my app” or “turn ordinary ChatGPT consumer chat into a local shell agent inside my app.” The official paths I found are Claude Agent SDK / Claude Code runtime surfaces, and Codex app-server / Agents SDK / Responses API / Codex CLI. That is why the report recommends official runtime integration rather than desktop-app parasitism. citeturn33view0turn16view0turn29search1turn4search8

I also cannot map your exact “Rust FFI in the middle three-stack” wording to a concrete codebase layout from the prompt alone, so the stack-specific recommendation is architectural rather than codebase-specific. But the core advice still holds: put orchestration and side effects in the Rust core, keep provider adapters boundary-clean, and make the UI a renderer of structured state rather than the place where agent capability is invented ad hoc.