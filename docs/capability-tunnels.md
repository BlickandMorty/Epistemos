# Capability tunnels — how Epistemos gets Claude Code / Codex parity without per-tool engineering

> **Index status**: CANONICAL-RESEARCH — 4-tunnel strategy; already in _consolidated.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_cli_integration/`.



Epistemos answers the question "can the cloud API's real capabilities
flow through without me building each tool" with three tunnels that
together deliver parity with the Claude Code and Codex desktop apps.

All three are on in Agent mode today (`EpistemosOperatingMode.agent`,
displayed as "Tools"). None of them require you to add Rust or Swift
code to pick up new capabilities.

---

## Tunnel A — universal shell / terminal (already built)

**What it is:** One tool named `bash_execute` plus a richer `terminal`
tool with background-process support. The model issues a shell command
and we run it.

**What it gets you:** Every capability a shell has. `git`, `ssh`, `curl`,
`npm`, `brew`, `pip`, `uv`, `make`, `pytest`, `cargo`, `sqlite3`, `docker`,
`ffmpeg`, etc. No per-command code on our side.

**Files:** `agent_core/src/tools/terminal.rs`,
`agent_core/src/tools/registry.rs:register_bash_execute` (and
`register_phase_one_terminal`).

**Safety:** `agent_core/src/approval.rs` pattern-matches destructive
commands (`rm -rf /`, `mkfs`, raw disk writes, etc.) and escalates.
Environment sanitizer strips `*KEY*`, `*TOKEN*`, `*SECRET*`,
`*PASSWORD*`, `*PASSWD*`, `*CREDENTIAL*`, `*AUTH*` env vars before
spawning the child so API keys don't leak into child processes.

**Caveat on sandbox:** Epistemos' direct-distribution build is
unsandboxed (hardened runtime only), so arbitrary subprocesses work.
A Mac App Store build would need extra entitlements or it would block
subprocess execution.

---

## Tunnel B.1 — URL MCP server passthrough (Anthropic)

**What it is:** Anthropic's `mcp_servers` API parameter. Epistemos
forwards a configured list of `{name, url}` MCP servers into every
Agent-mode Claude turn. Anthropic's runtime connects to those servers
and lets the active Claude model call their tools natively.

**What it gets you:** Every MCP-server-exposed tool (community-built
servers for GitHub, Linear, Cloudflare, Slack, anything else) becomes
usable by the model with zero Swift/Rust code per capability.

**How to add a server:**

```bash
mkdir -p ~/.config/mcp
cat > ~/.config/mcp/url_servers.json <<'JSON'
[
  { "name": "github",    "url": "https://mcp.github.com/mcp" },
  { "name": "linear",    "url": "https://mcp.linear.app/mcp" },
  { "name": "cloudflare", "url": "https://mcp.cloudflare.com/mcp",
    "authorization_token_env": "CLOUDFLARE_MCP_TOKEN" }
]
JSON
```

Per-vault override: `.epistemos/mcp_url_servers.json` in the current
working directory. Per-vault entries win on name collision.

**Files:** `agent_core/src/mcp/url_servers.rs`,
`agent_core/src/bridge.rs` (AgentConfig::from_ffi wiring),
`agent_core/src/providers/claude.rs:287` (request payload).

**Limits today:**
- Anthropic only. OpenAI's Responses API has an equivalent `tools: [{
  type: "mcp", ... }]` shape; wire on demand.
- OAuth bearer tokens are supported through `authorization_token_env`
  (preferred) or `authorization_token`, matching Anthropic's
  `mcp_servers[].authorization_token` field. Arbitrary custom headers are
  not surfaced in this config format.
- Tools aren't visible in the Epistemos composer. The model sees them;
  the user doesn't get a preview. UI follow-up.

---

## Tunnel B.2 — stdio MCP server registration (local)

**Status:** Discovery exists
(`agent_core/src/mcp/client.rs:McpClient::discover_servers` reads
`~/.config/mcp/servers.json` with the `{name, command, args, env}`
shape). NOT yet wired into the in-process `ToolRegistry`, so tools
these servers expose aren't auto-registered with the agent loop today.

**What it would give you:** Local MCP processes (filesystem, git,
fetch, sequential-thinking, etc.) spawn at startup, their tool schemas
register into the Epistemos registry, and they go through the normal
approval flow. Same pattern Claude Code uses.

**Next-session task.** Not shipped yet.

---

## Tunnel C — Claude Code / Codex CLI passthrough

**What it is:** Two tools — `claude_code` and `codex` — that spawn the
respective CLI in non-interactive mode and forward the task. The
delegated agent runs its own full tool loop (shell, file edits, git,
its own MCP servers, its own approval UI in the case of Codex sandbox),
and Epistemos just streams the combined stdout/stderr back.

**What it gets you:** Full Claude-Code / Codex behavior from inside
Epistemos. If you can do it in the Claude Code desktop app or the
Codex app, you can ask the in-chat agent to do it for you and the
delegated CLI will run it.

**Install:**

```bash
# Claude Code
npm install -g @anthropic-ai/claude-code

# Codex — already bundled at /Applications/Codex.app/Contents/Resources/codex
# when you install the Codex desktop app. No extra step needed.
```

Epistemos looks in these locations automatically (PATH first, then these
absolute paths):

- `~/.local/bin/claude`, `~/.claude/local/claude`, `~/.npm-global/bin/claude`,
  `/opt/homebrew/bin/claude`, `/usr/local/bin/claude` → `claude_code`
- `~/.local/bin/codex`, `/Applications/Codex.app/Contents/Resources/codex`,
  `/opt/homebrew/bin/codex`, `/usr/local/bin/codex` → `codex`

**How the model calls them:**

```json
{
  "task": "Audit the authentication flow in Epistemos/Engine/ for subtle bugs. Return a bulleted list of concerns.",
  "working_dir": "/Users/jojo/Downloads/Epistemos",
  "model": "opus",
  "bypass_permissions": true,
  "timeout_seconds": 600
}
```

(That's a `claude_code` call. `codex` is the same shape minus `model`
plus an optional `sandbox: true` to run under `codex sandbox`.)

**Defaults:** `bypass_permissions: true` on Claude Code so the
delegated agent doesn't re-prompt (the Epistemos-side approval has
already happened). `sandbox: false` on Codex; set `true` for an extra
command-sandbox layer.

**Timeouts:** 5 minutes default, 30 minutes max. Long Claude Code
sessions can blow through 5 minutes; set `timeout_seconds` explicitly
for big tasks.

**Files:** `agent_core/src/tools/cli_passthrough.rs`,
`agent_core/src/tools/registry.rs` (`register_claude_code_passthrough`,
`register_codex_passthrough`).

**Install-hint behavior:** If the CLI isn't found, the tool returns a
JSON payload with `install_hint` instead of failing — the in-chat agent
can read that hint and either install the CLI via `bash_execute` or
tell the user how to install it manually.

---

## Gates, tiers, approval

All three tunnels are gated behind `ToolTier::Agent`, so they only
appear when the chat is in Agent / Tools mode. Fast / Thinking / Pro
modes don't see them.

All three go through `agent_core::approval::ApprovalSystem` with
pattern-level pre-filtering and per-session allowlists. Common safe
commands auto-approve after the first allow; destructive patterns
(`rm -rf /`, `mkfs`, etc.) are hard-blocked.

---

## What each tunnel is NOT

- Not an MCP proxy server of our own. We don't host the protocol.
- Not an ACC replacement. ACC (Agent Command Center) is still the
  per-tool toggle UI; these tunnels just mean ACC can toggle tunnel
  *tools* instead of having to toggle each sub-capability.
- Not a sandboxed execution environment on its own. `bash_execute`
  runs with your normal user privileges. Use `codex sandbox=true` for
  the extra sandbox layer when the delegated task comes from an
  untrusted prompt.

---

## Combining tunnels — what "full Claude-Code parity" looks like

The in-chat Agent can today:

1. Use `bash_execute` to `brew install ripgrep` or `pip install ...` — so
   the model can install dependencies it needs mid-session.
2. Use `bash_execute` or `git` MCP (via Tunnel B.1) to commit / push /
   open a PR.
3. Delegate a coding task to Claude Code via `claude_code` and wait
   for it to finish.
4. Delegate a sandboxed run to Codex via `codex sandbox=true`.
5. Combine all of those in a single turn: "Install the MCP filesystem
   server globally, add it to ~/.config/mcp/url_servers.json, then hand
   the next task to Claude Code to verify it works."

That's the parity surface. Zero per-capability code on Epistemos' side
for any of those additions.

---

## Related docs

- `docs/mcp-url-servers.md` — Tunnel B.1 deep-dive.
- `docs/handoffs/2026-04-22-claude-to-codex-live-runtime-and-tunnel-findings.md` — original research + session addenda.
- `docs/APP_ISSUES_AUTO_FIX.md` — known-open runtime issues to watch.
