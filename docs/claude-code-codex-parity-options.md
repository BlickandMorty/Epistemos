# How Epistemos gets *real* Claude-Code / Codex parity inside the app

> **Index status**: CANONICAL-RESEARCH — Runtime path comparison; already in _consolidated.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_cli_integration/`.



The user's ask: "I want Claude and Codex to truly have the capabilities
that the desktop apps do and I want it to be a part of my app
literally." This note is the research comparing every technically
viable way to make that happen, with a recommendation at the bottom.

None of these options require re-implementing the agent loops of the
Claude Code CLI or the Codex CLI. Every option reuses the upstream
binary's own agent loop — the differences are how the Epistemos chat
surface composes with it.

---

## Option 1 — Subprocess passthrough (Tunnel C)

**What it is:** Spawn `claude -p` or `codex exec` as a child process
of Epistemos, feed the task, stream stdout/stderr back as the tool
result. This is what Pass 7's `claude_code` and `codex` tools do
already (`agent_core/src/tools/cli_passthrough.rs`).

**Shape:**
- Requires: user has the binary on disk (PATH or well-known location).
- Epistemos discovers the binary, runs it in a fresh process, waits.
- Output appears as a large tool-result block in the Epistemos chat.
- Each invocation is a fresh session (no persistent state between
  invocations unless the child CLI itself persists).
- Every capability the CLI supports (bash, git, file ops, its own
  MCP servers, its own skills, its own sandbox, its own approval UI)
  is available in the delegated run.

**Strengths:**
- Zero per-capability code on Epistemos. If Anthropic ships a new
  Claude Code feature tomorrow, it works in Epistemos tomorrow.
- Honest about what's happening: the user can see the tool call and
  the tool result.
- Survives CLI version updates without Epistemos redeploying.
- Already shipped in Pass 7.

**Weaknesses:**
- The delegated CLI's interactive features (permission dialogs,
  `/commands`, resume) aren't directly usable mid-run. `--print`
  mode is non-interactive by design.
- No streaming token-level feedback — the user sees the result all
  at once when the CLI finishes.
- Long tasks block the tool call; default timeout is 5 min, max 30
  min in the current handler.

**Best for:** multi-step coding work where the user wants the CLI's
own loop to own the turn.

---

## Option 2 — Desktop-app URL scheme handoff

**What it is:** Fire a macOS URL like
`claude://task?prompt=...&workingDir=...` or
`codex://exec?prompt=...`. The desktop app opens with the task
pre-loaded. User finishes the work in the desktop app, optionally
exports results back to Epistemos.

**Shape:**
- Requires: user has the desktop app installed.
- Epistemos opens the URL; no subprocess, no streaming.
- The answer lives in the desktop app's session, not in the Epistemos
  chat.

**Strengths:**
- Zero permission / sandbox complexity. The desktop app runs in its
  own sandbox.
- Gets the user *literally* the desktop-app experience.

**Weaknesses:**
- Output doesn't flow back into the Epistemos chat automatically.
  The user has to copy/paste or use another integration.
- Needs a Claude / Codex URL scheme to actually exist. Neither
  desktop app ships a publicly documented URL scheme for programmatic
  task delegation today.
- Breaks the "one unified chat" feel the user asked for ("it should
  be as if I was using the code app or the clot desktop app" from
  *inside* Epistemos).

**Best for:** nothing right now, because the URL scheme isn't
advertised by either app. Keep on the radar — if Anthropic or OpenAI
ships one, wire a `handoff_to_claude_app` tool.

---

## Option 3 — Codex CLI as an MCP server (Tunnel B.2 + `codex mcp-server`)

**What it is:** `codex mcp-server` is a first-class subcommand on the
Codex CLI — it runs Codex as a stdio MCP server exposing Codex's
tool surface. Drop one line in `~/.config/mcp/servers.json` and
Epistemos' Tunnel B.2 discovery picks it up, connects on agent bootstrap,
and registers every Codex tool natively into the in-chat agent.

Example `~/.config/mcp/servers.json` entry:

```json
{
  "codex": {
    "command": "/Applications/Codex.app/Contents/Resources/codex",
    "args": ["mcp-server"],
    "env": {}
  }
}
```

**Shape:**
- Requires: Codex desktop app installed (user already has it).
- Epistemos spawns `codex mcp-server` once per registry build.
- The Codex server advertises its tools via MCP `tools/list`.
- Each tool becomes a regular Epistemos tool — appears in the catalog,
  goes through the Agent tier gate, streams results back.
- The in-chat agent can call Codex tools directly, interleaved with
  Epistemos' own tools.

**Strengths:**
- Tools appear *natively* to the model — not behind a "delegate a
  task" wrapper. The model can pick "use the Codex git_apply tool"
  the same way it picks `write_file`.
- Streaming + proper MCP `content` blocks, not a big stdout dump.
- Survives CLI updates: whatever Codex's MCP server advertises is
  what we use.
- Already wired in Pass 8 via Tunnel B.2.

**Weaknesses:**
- Claude Code CLI does NOT currently ship an `mcp-server` subcommand
  (check `claude --help`; it has `--mcp-config` to *consume* MCP
  servers but not to *be* one). So this option is Codex-only until
  Anthropic ships an `mcp-server` mode on Claude Code.
- A long-lived background process per registered server. 1–2 idle
  stdio children per session is fine; dozens would not be.

**Best for:** Codex parity. Best-in-class for that specific flow.

---

## Option 4 — Statically bundle the binaries inside Epistemos.app

**What it is:** Ship `claude` and `codex` binaries inside the
Epistemos `.app/Contents/Resources` directory so they're always
available, no user install needed.

**Weaknesses:**
- Both binaries are proprietary, so redistribution is a license
  question. Anthropic's Claude Code is under a custom license that
  allows use but not always redistribution in a different app's
  bundle. Codex is similar.
- Version drift: our bundle goes stale the moment Anthropic / OpenAI
  ship a new CLI.
- Code-signing / notarization / stapling complications.
- Violates the "Epistemos stays small" UX promise.

**Best for:** nothing on a direct-distribution build. Skip.

---

## Recommendation

**Do all three of Option 1 + Option 3 + the "install on demand"
fallback.** Epistemos already has the code for 1 and 3 after Pass 7
and Pass 8. What remains is user-facing surfacing:

1. **Keep Tunnel C (Option 1)** as the default for *task delegation*.
   When the model says "I want Claude Code to audit this file," it
   fires the `claude_code` tool and gets a complete answer back. Zero
   configuration. Works if `claude` is anywhere reasonable on PATH.

2. **Advertise Tunnel B.2 (Option 3) for Codex.** Write a one-command
   setup step in `docs/capability-tunnels.md` that drops the
   `codex mcp-server` entry into `~/.config/mcp/servers.json`. After
   restart, every Codex tool appears natively to the model. This is
   the cleanest "part of the app" integration because the model doesn't
   need to think "delegate to codex" — it just calls Codex's tools
   alongside its own.

3. **Add an "install CLI" convenience inside Epistemos** that, when
   the tool can't find `claude` or `codex` on disk, prompts the user
   to run a pre-canned `bash_execute` invocation to install them
   (e.g., `npm install -g @anthropic-ai/claude-code`, or directs the
   user to the Codex app download page). The `install_hint` JSON
   payload the missing-binary path already returns is half of this
   UI surface; the other half is a small composer chip that reads
   the hint and offers "Install Claude Code CLI" as a one-click.

4. **Defer Option 4 (static bundle) indefinitely.** Licensing is not
   worth the paperwork until you have a paying business.

This gets you "as if I was using the Claude app or the Codex app,
from inside Epistemos" without re-implementing a single agent loop,
without bundle-size growth, without licensing risk, and without
giving up the safety of subprocess isolation.

---

## What's actually shipped today

| Tunnel | What it does | Requires | Status |
|---|---|---|---|
| A | Universal `bash_execute` / `terminal` tool | nothing | shipped pre-Pass-1 |
| B.1 | URL MCP server passthrough to Anthropic | `~/.config/mcp/url_servers.json` | Pass 5 (2026-04-22) |
| B.2 | Stdio MCP server discovery + auto-register tools | `~/.config/mcp/servers.json` | Pass 8 (2026-04-22) |
| C | `claude_code` + `codex` tool wrappers | CLI on disk | Pass 7 (2026-04-22) |

On the specific "Claude Code / Codex parity" question, the recipe is:

```bash
# One-time setup — Codex desktop app must be installed (user has it).
mkdir -p ~/.config/mcp
cat > ~/.config/mcp/servers.json <<'JSON'
{
  "codex": {
    "command": "/Applications/Codex.app/Contents/Resources/codex",
    "args": ["mcp-server"],
    "env": {}
  }
}
JSON

# Claude Code CLI already installed at ~/.local/bin/claude — no setup needed.
# The `claude_code` tool discovers it automatically on every Agent turn.
```

That's it. Restart the app; next Agent-mode turn gets both.

---

## Why this is better than any single option alone

- You can delegate ENTIRE tasks to Claude Code via `claude_code {task}`
  (Option 1) — the CLI owns a whole multi-turn loop, we just wait for
  the answer.
- You can use INDIVIDUAL Codex tools inline via Tunnel B.2 — the model
  composes `codex.git_apply` with `write_file` in a single turn, no
  delegation wrapper.
- You can also use `bash_execute` to install whatever else you want
  on demand. The in-chat agent can literally type "brew install
  ripgrep" and it runs.

Combined, the Epistemos Agent mode has every capability the Claude
Code / Codex desktop apps expose, plus everything a shell can do,
plus everything any installed MCP server exposes — with nothing to
engineer per-capability on our side.
