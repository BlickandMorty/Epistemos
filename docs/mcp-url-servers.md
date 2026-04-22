# MCP URL-server passthrough (Tunnel B.1)

Epistemos forwards a configured list of URL-based MCP servers to
Anthropic's `mcp_servers` API parameter on every Agent-mode turn. Every
tool those servers expose becomes available to the model with zero
per-tool Swift or Rust code — the kind of "capability tunnel" the user
asked for on April 22.

## Quickstart — add a server

Global (applies to every vault):

```bash
mkdir -p ~/.config/mcp
cat > ~/.config/mcp/url_servers.json <<'JSON'
[
  { "name": "example", "url": "https://mcp.example.com/example" }
]
JSON
```

Per-vault (overrides global, appended to the list):

```bash
mkdir -p .epistemos
cat > .epistemos/mcp_url_servers.json <<'JSON'
[
  { "name": "example-project", "url": "https://mcp.example.com/project" }
]
JSON
```

Each entry is `{ "name": "...", "url": "..." }`. Duplicate names are
deduplicated with per-vault winning.

## What happens on the next Agent turn

1. `agent_core::mcp::url_servers::discover_url_mcp_servers` reads both
   files (ignores missing/malformed files silently).
2. The list is attached to the Rust `AgentConfig.mcp_servers` in
   `bridge.rs`.
3. `providers::claude` forwards the list as Anthropic's `mcp_servers`
   field in the Messages API request body.
4. Anthropic's servers connect to the MCP endpoints, load their tool
   schemas, and expose those tools to the active Claude model.
5. The model calls the tools directly through Anthropic's runtime. No
   Epistemos-side tool registry entries, no approval UI for them today.

## Limitations right now

- **Anthropic only.** OpenAI's Responses API has an equivalent
  `tools: [{ type: "mcp", ... }]` parameter but isn't wired on Epistemos
  yet. Add that the same way: populate the provider's request builder.
- **No per-server authentication yet.** Headers / bearer tokens aren't
  surfaced in the config format. If you need an authenticated endpoint,
  proxy it locally or wait for the config to grow a `headers` field.
- **Tools are not visible in Epistemos UI.** The model sees them; the
  user doesn't get a composer-side preview of "this server exposes X, Y,
  Z." That's a UI follow-up — the plumbing is done.
- **STDIO MCP servers are separate.** Those get discovered by
  `agent_core::mcp::client::McpClient::discover_servers` from
  `~/.config/mcp/servers.json` (`{ name, command, args, env }` shape)
  and are NOT yet wired into the tool registry. That's Tunnel B.2, a
  future pass.

## Example config — popular public MCP servers

These are illustrative, not endorsed; check the operator before using
anything with sensitive workflows.

```json
[
  { "name": "github",    "url": "https://mcp.github.com/mcp" },
  { "name": "linear",    "url": "https://mcp.linear.app/mcp" },
  { "name": "cloudflare", "url": "https://mcp.cloudflare.com/mcp" }
]
```

## Related docs

- `docs/handoffs/2026-04-22-claude-to-codex-live-runtime-and-tunnel-findings.md`
  §6 — the research that led to this feature.
- `agent_core/src/mcp/url_servers.rs` — implementation.
- `agent_core/src/providers/claude.rs` — the Anthropic request builder.
