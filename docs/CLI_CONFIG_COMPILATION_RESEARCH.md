# Auto-Regenerated AI Coding CLI Configuration Templates for Epistemos

> **Index status**: CANONICAL-RESEARCH — Already canonical (1161 lines authoritative CLI compiler ref); existing banner adequate.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_cli_integration/`.



> **Status**: CANONICAL — implementation reference (NOT plan doctrine; do not confuse with PLAN_V2 / DOCTRINE).
> **Role**: Authoritative compiler-design + per-CLI schema reference for Claude Code, OpenAI Codex CLI, and Google Gemini CLI as of April 2026. Includes drop-in templates (CLAUDE.md, vault-conventions.md, .claude/settings.json, .mcp.json, .codex/config.toml, .gemini/settings.json), full Rust manifest struct, regeneration policy, MCP transport guidance, OAuth/MCP-Apps status, sandbox + security conventions, and authoritative bibliography.
> **Read with**: [`claude-code-codex-parity-options.md`](claude-code-codex-parity-options.md) (runtime path comparison) + [`capability-tunnels.md`](capability-tunnels.md) (4-tunnel strategy) + [`mcp-url-servers.md`](mcp-url-servers.md) (Tunnel B.1 implementation).
> **Last verified**: 2026-04-22.

**Reference document and production-ready templates (current as of April 22, 2026)**

This report is the authoritative reference for compiling a single Epistemos manifest into the canonical on-disk configuration files read by Claude Code, OpenAI Codex CLI, and Google Gemini CLI. Every nontrivial claim is cited to the official vendor documentation, specification, or repository. Where documentation changed since early 2025, or where a field is in beta / deprecated, I flag it explicitly.

---

## 1. Claude Code — CLAUDE.md, settings.json, and the `.claude/` directory

### 1.1 File layout and scope hierarchy (April 2026)

Claude Code resolves configuration through a five-level scope hierarchy, with more specific scopes overriding more general ones. The official precedence order (highest → lowest) is: **Managed → Command-line args → Local → Project → User** ([Claude Code settings](https://code.claude.com/docs/en/settings)).

The canonical locations as documented by Anthropic are:

| Feature | User location | Project location | Local location |
|---|---|---|---|
| Settings | `~/.claude/settings.json` | `.claude/settings.json` | `.claude/settings.local.json` |
| Subagents | `~/.claude/agents/` | `.claude/agents/` | — |
| MCP servers | `~/.claude.json` | `.mcp.json` | `~/.claude.json` (per-project block) |
| Plugins | `~/.claude/settings.json` | `.claude/settings.json` | `.claude/settings.local.json` |
| CLAUDE.md | `~/.claude/CLAUDE.md` | `CLAUDE.md` or `.claude/CLAUDE.md` | `CLAUDE.local.md` |

Source: [code.claude.com/docs/en/settings](https://code.claude.com/docs/en/settings).

**⚠️ Critical caveat (changed since early 2025):** `mcpServers` is **only** read from `~/.claude.json` (user/local scope) and `.mcp.json` (project scope). Placing `mcpServers` in `~/.claude/settings.json`, `.claude/settings.json`, or `.claude/settings.local.json` is **silently ignored** — a well-known and documented source of confusion tracked in [Issue #24477](https://github.com/anthropics/claude-code/issues/24477). Epistemos must write project-scoped MCP to `.mcp.json`, not to `.claude/settings.json`.

**Array merge semantics (clarified since mid-2025):** Array fields such as `permissions.allow[]`, `hooks`, and `enabledMcpjsonServers` are **concatenated and deduplicated** across scope layers, not overridden, so global and project rules coexist ([Vincent's blog — Claude Code Settings](https://blog.vincentqiao.com/en/posts/claude-code-settings-intro/)). Scalar values do override.

### 1.2 CLAUDE.md — memory hierarchy, imports, and what belongs where

Claude Code's memory system is hierarchical; files are loaded in order from lowest to highest priority (enterprise → user → project → local → subdirectory), and later-loaded files take precedence because the model attends more strongly to later context ([Claude Code memory docs](https://code.claude.com/docs/en/memory)).

Key mechanics:

- **Recursive `@path` imports** are supported up to **5 levels deep**. Both relative and absolute paths work (e.g., `@./docs/architecture.md`, `@~/.claude/prefs.md`). Imports inside fenced code blocks or inline spans are ignored. First-time imports from external locations trigger an approval dialog ([Claude Code memory docs](https://code.claude.com/docs/en/memory)).
- **`.claude/rules/*.md`** — all `.md` files in `.claude/rules/` (and subdirectories) are **loaded automatically** at project and user memory levels. Rule files support YAML frontmatter with a `paths:` glob list; when `paths` is set, the rule is only injected when Claude works on a matching file. This is the recommended mechanism for keeping CLAUDE.md lean ([Mintlify memory reference](https://www.mintlify.com/VineeTagarwaL-code/claude-code/concepts/memory-context)).
- **Max recommended length:** any single memory file should stay under ~**40,000 characters** (`MAX_MEMORY_CHARACTER_COUNT`); files beyond that may be truncated. Practitioners widely recommend keeping the root project CLAUDE.md under ~200–300 lines and pushing detail into `.claude/rules/` or `@`-imports ([Vincent's blog](https://blog.vincentqiao.com/en/posts/claude-code-settings-intro/); [Parreo García memory essay](https://joseparreogarcia.substack.com/p/claude-code-memory-explained)).
- **CLAUDE.local.md** is gitignored by convention and is for personal, machine-specific overrides. Anthropic now recommends `@`-imports of an external personal file over CLAUDE.local.md in multi-worktree setups ([Steve Kinney referencing guide](https://stevekinney.com/courses/ai-development/referencing-files-in-claude-code)).
- **`claudeMdExcludes`** — any settings layer can list glob patterns of CLAUDE.md files to exclude; managed-policy CLAUDE.md files cannot be excluded ([memory docs](https://code.claude.com/docs/en/memory)).
- **Auto memory** (Claude Code ≥ v2.1.59) lets Claude write its own notes to a curated memory folder (`autoMemoryDirectory` setting, default `~/.claude/plans` or similar); toggle with `autoMemoryEnabled` or `CLAUDE_CODE_DISABLE_AUTO_MEMORY` ([memory docs](https://code.claude.com/docs/en/memory)).

**What belongs where** (Anthropic's current guidance, distilled):

| Location | Contents |
|---|---|
| `CLAUDE.md` (root) | "Index" + small stable facts: project overview, build commands, invariants ("always prefer Epistemos MCP tools over raw file I/O"), pointers (`@.claude/rules/*`, `@docs/*.md`). **Do not** put procedures, large knowledge, or path-specific details here ([Parreo García](https://joseparreogarcia.substack.com/p/claude-code-memory-explained)). |
| `.claude/rules/*.md` | Modular, optionally path-scoped topic files (vault conventions, note schema, link grammar, graph-walk heuristics). Auto-loaded. |
| `.claude/skills/<name>/SKILL.md` | **Model-invoked workflows** (procedures with steps). Loaded on demand when the description matches the user's intent. Keep SKILL.md < 500 lines; push detail into `references/` and `scripts/` ([Claude Skills docs](https://code.claude.com/docs/en/skills); [Anthropic skill-creator SKILL.md](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md)). |
| `.claude/agents/*.md` | Subagents (specialized assistants with their own prompt, tool allowlist, model) ([settings docs](https://code.claude.com/docs/en/settings)). |
| `.claude/commands/*.md` | Slash commands (still supported, but skills are recommended for new work) ([Skills docs](https://code.claude.com/docs/en/skills)). |
| `.claude/settings.json` | Permissions, hooks, env, plugin, output-style, model, statusLine. **Not** `mcpServers`. |
| `.mcp.json` | Project-scope MCP server definitions. |
| `CLAUDE.local.md` | Personal overrides (gitignored). |

The "nouns vs. verbs" rule of thumb from Anthropic's field-tested guidance: CLAUDE.md for *nouns* (where and what things are), slash commands/skills for *verbs* (how to do things) ([Steve Kinney CLAUDE.md guide](https://stevekinney.com/courses/ai-development/claude-dot-md)).

### 1.3 Claude Skills (SKILL.md) — April 2026 status

Skills are now the recommended extension mechanism, superseding ad-hoc slash commands. A skill is a directory under `.claude/skills/<name>/` containing a `SKILL.md` with YAML frontmatter (`name`, `description`, optional `disable-model-invocation`, `allowed-tools`) followed by Markdown instructions. Skills support supporting files under `scripts/`, `references/`, and `assets/` ([Claude Skills docs](https://code.claude.com/docs/en/skills)).

Important behaviors:

- Skills are discovered at session start and Claude invokes them automatically when the `description` matches intent, or explicitly with `/skill-name` ([Analytics Vidhya Skills guide](https://www.analyticsvidhya.com/blog/2026/03/claude-skills-custom-skills-on-claude-code/)).
- Anthropic recommends making descriptions "pushy" because Claude tends to *undertrigger* skills — e.g., "How to create a note in Epistemos. Use this skill whenever the user mentions notes, daily notes, or wants to write anything into the vault, even if they do not explicitly say 'skill'." ([Anthropic skill-creator SKILL.md](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md)).
- Skills live on the filesystem in Claude Code (no API upload) and are edited live — Claude watches the folder and picks up changes mid-session ([Agent Skills overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)).
- The same SKILL.md format is cross-compatible across Claude Code, Cursor, Gemini CLI, and Codex CLI as of early 2026 ([Must-Have Skills for Coding Agents 2026](https://medium.com/@unicodeveloper/10-must-have-skills-for-claude-and-any-coding-agent-in-2026-b5451b013051)).

### 1.4 `.claude/settings.json` schema — the fields that matter

Complete field list as of April 2026 is documented at [code.claude.com/docs/en/settings](https://code.claude.com/docs/en/settings) and in the [JSON schema](https://json.schemastore.org/claude-code-settings.json). The fields Epistemos needs to emit:

- `permissions`: object with `allow[]`, `ask[]`, `deny[]`, `additionalDirectories[]`, `defaultMode` (one of `"acceptEdits" | "bypassPermissions" | "default" | "plan"`), `disableBypassPermissionsMode`. Rule syntax is `ToolName` or `ToolName(pattern)`, e.g., `Bash(git diff *)`, `Read(./.env)`, `WebFetch(domain:example.com)` ([settings docs](https://code.claude.com/docs/en/settings)).
- `hooks`: keyed by event name (see §5 below), values are arrays of matcher objects, each with a `matcher` regex string and a `hooks[]` array of `{type:"command", command, timeout?, async?}`.
- `env`: object of env vars applied to every session.
- `model`: string (e.g., `"claude-sonnet-4-6"`, `"claude-opus-4-6"`).
- `outputStyle`: string (references a style defined in `~/.claude/output-styles/` or built-ins like `"Explanatory"`).
- `enableAllProjectMcpServers`: boolean to auto-approve all `.mcp.json` servers; `enabledMcpjsonServers[]`/`disabledMcpjsonServers[]` for per-server allowlists.
- `statusLine`: `{type:"command", command, padding?}`.
- `autoMemoryDirectory`, `cleanupPeriodDays`, `includeCoAuthoredBy` / `attribution`, `apiKeyHelper`, `agent` (run main thread as a named subagent).

**Permissions note:** permission rule arrays merge across scopes, but the permission-model documentation acknowledges that `deny` rules are sometimes reported as flaky by users ([eesel AI review](https://www.eesel.ai/blog/settings-json-claude-code)); treat `deny` as defense-in-depth and pair it with a **PreToolUse hook** that returns exit code 2 (which reliably blocks) for anything truly sensitive.

### 1.5 Hooks — full event list (April 2026)

As of the 2026 rework, Claude Code exposes **21 lifecycle events** across three cadences ([Claude Code Hooks reference](https://code.claude.com/docs/en/hooks); [Smartscope hooks guide](https://smartscope.blog/en/generative-ai/claude/claude-code-hooks-guide/); [Pixelmojo hooks post](https://www.pixelmojo.io/blogs/claude-code-hooks-production-quality-ci-cd-patterns)):

- **Once per session:** `SessionStart` (matchers: `startup|resume|clear|compact`), `SessionEnd` (matchers: `clear|resume|logout|prompt_input_exit`).
- **Once per turn:** `UserPromptSubmit`, `UserPromptExpansion`, `Stop`, `StopFailure`, `PreCompact`.
- **Per tool call:** `PreToolUse`, `PermissionRequest`, `PostToolUse`, `PostToolUseFailure`.
- **Subagents / worktrees / teams:** `SubagentStart`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`, `WorktreeCreate`, `WorktreeRemove`, `CwdChanged`.
- **Other:** `Notification`, `ConfigChange`, `FileChanged` (takes a path matcher).

Handler types are `command` (shell), `http` (POST to URL), `prompt` (LLM-based evaluator), and `agent` ([Pixelmojo](https://www.pixelmojo.io/blogs/claude-code-hooks-production-quality-ci-cd-patterns); Anthropic [plugin-dev hook-development SKILL.md](https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/hook-development/SKILL.md)).

**Exit code semantics for command hooks ([hooks docs](https://code.claude.com/docs/en/hooks))**:
- `0`: success; stdout may be parsed as JSON for structured `allow|deny|ask` control or to inject `additionalContext`.
- `2`: blocks the action in `PreToolUse`/`PermissionRequest`; injects stderr as context without blocking on `UserPromptSubmit`.
- Other non-zero: generic failure.

Stdout from `SessionStart` and `UserPromptSubmit` is injected as Claude's context; SessionStart can persist env via `$CLAUDE_ENV_FILE` ([Smartscope](https://smartscope.blog/en/generative-ai/claude/claude-code-hooks-guide/)).

### 1.6 `--bare`, `settingSources`, and the Agent SDK

- The Agent SDK (`@anthropic-ai/claude-agent-sdk`) supports a `settingSources` parameter that controls which scopes load: `["user","project","local"]`. Excluding `"local"` skips `CLAUDE.local.md` and `.claude/settings.local.json` ([memory docs](https://code.claude.com/docs/en/memory)).
- `claude --bare` is specifically for SDK-style invocations and skips the user and project filesystem discovery (no `CLAUDE.md`, no `.claude/`, no `.mcp.json`); the caller supplies context via `--append-system-prompt` and programmatic tool setup. Practical rule: never rely on `--bare` for normal interactive sessions — it's for programmatic orchestration only.
- `--add-dir` grants file access to additional directories but **does not** discover `.claude/` configuration there — except that `.claude/skills/` **is** auto-loaded from added directories. `CLAUDE.md` from added dirs loads only when `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` ([Skills docs](https://code.claude.com/docs/en/skills); [memory docs](https://code.claude.com/docs/en/memory)).

### 1.7 MCP server shapes for Claude Code

Stdio form (in `.mcp.json`):
```json
{ "mcpServers": {
  "epistemos": {
    "type": "stdio",
    "command": "/usr/local/bin/epistemos-mcp",
    "args": ["--vault", "${EPISTEMOS_VAULT}"],
    "env": { "EPISTEMOS_VAULT": "${EPISTEMOS_VAULT}" }
  }
}}
```

HTTP / Streamable HTTP form ([prompt shelf 2026 MCP guide](https://thepromptshelf.dev/blog/claude-code-mcp-setup-guide/)):
```json
{ "mcpServers": {
  "epistemos": {
    "type": "http",
    "url": "http://127.0.0.1:${EPISTEMOS_PORT}/mcp",
    "headers": { "Authorization": "Bearer ${EPISTEMOS_TOKEN}" }
  }
}}
```

`${VAR}` expansions reference shell environment variables. SSE transport is still accepted but Streamable HTTP is now the default remote transport ([2026 MCP roadmap](https://blog.modelcontextprotocol.io/posts/2026-mcp-roadmap/)).

---

## 2. OpenAI Codex CLI — `.codex/config.toml`

### 2.1 File discovery and precedence

Codex CLI (open source at [openai/codex](https://github.com/openai/codex/blob/main/docs/config.md)) reads TOML from four locations, with resolution order (highest first) ([Codex config-basic](https://developers.openai.com/codex/config-basic); [Danielvaughan reference 2026](https://codex.danielvaughan.com/2026/04/08/codex-cli-configuration-reference/)):

1. Requirements (enforced, from `requirements.toml` deployed via MDM / cloud admin)
2. Managed defaults (`managed_config.toml`)
3. CLI flags and `-c` overrides
4. Profile values (from the selected `[profiles.<name>]`)
5. Project config `.codex/config.toml` (only loaded in **trusted projects**; falls back to user-only on untrusted)
6. User `~/.codex/config.toml` (`CODEX_HOME` env var relocates this)
7. System config
8. Built-in defaults

**Project-scope config was formalized in early 2026** — previously only `~/.codex/config.toml` existed. Epistemos must mark the vault as trusted (via first `codex` run or `codex --cd <vault>` / config UI) before the project config applies.

### 2.2 Core keys (from the authoritative [Codex config-reference](https://developers.openai.com/codex/config-reference) and [config-sample](https://developers.openai.com/codex/config-sample))

```toml
model = "gpt-5.4"                    # default model
model_provider = "openai"            # openai | oss (ollama) | custom
model_reasoning_effort = "medium"    # low | medium | high | xhigh
model_reasoning_summary = "auto"
model_verbosity = "medium"

approval_policy = "on-request"       # untrusted | on-request | never | {granular = {...}}
sandbox_mode = "workspace-write"     # read-only | workspace-write | danger-full-access

[sandbox_workspace_write]
writable_roots      = []             # extra dirs beyond cwd
network_access      = false          # default: off
exclude_tmpdir_env_var = false       # keep $TMPDIR writable
exclude_slash_tmp      = false       # keep /tmp writable

[shell_environment_policy]
inherit = "core"                     # core | all | none
include_only = ["PATH","HOME","SHELL","LANG","LC_ALL","USER","TERM"]
exclude      = ["*KEY*","*TOKEN*","*SECRET*","LD_PRELOAD","NODE_OPTIONS"]
ignore_default_excludes = false      # keep KEY/SECRET/TOKEN filtering on

[features]                           # centralized feature flags
web_search_request = true
unified_exec       = true
codex_hooks        = false           # hooks are still under development as of Apr 2026
```

Note `approval_policy = "on-failure"` is **deprecated**; the current replacement for interactive use is `"on-request"`, and for automation it's `"never"` ([CLI reference](https://developers.openai.com/codex/cli/reference)).

**Granular approval policy** (new in 2026):
```toml
approval_policy = { granular = {
    sandbox_approval  = true,
    rules             = true,
    mcp_elicitations  = true,
    request_permissions = false,
    skill_approval    = false
} }
```
This lets you fail closed on certain prompt categories while keeping others interactive ([config-reference](https://developers.openai.com/codex/config-reference)).

### 2.3 Profiles

```toml
[profiles.default]
model = "gpt-5.4"
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[profiles.ci]
model = "o4-mini"
approval_policy = "never"
sandbox_mode = "workspace-write"
features.web_search_request = false
```
Select with `codex --profile ci` ([config-sample](https://developers.openai.com/codex/config-sample)).

### 2.4 MCP servers — current TOML grammar

The **correct** key is top-level `[mcp_servers.<id>]`, not `[mcp.servers.<id>]` (a common misspelling that silently fails — see [openai/codex#3441](https://github.com/openai/codex/issues/3441)).

Stdio:
```toml
[mcp_servers.epistemos]
command = "/usr/local/bin/epistemos-mcp"
args    = ["--vault", "/Users/jojo/vaults/main"]
cwd     = "/Users/jojo/vaults/main"
env     = { EPISTEMOS_VAULT = "/Users/jojo/vaults/main" }
env_vars = ["PATH", "HOME", "LANG"]   # forwarded from parent env
supports_parallel_tool_calls = false
default_tools_approval_mode  = "auto" # auto | prompt | approve
enabled = true

[mcp_servers.epistemos.tools.vault_write]
approval_mode = "approve"             # per-tool override: always ask
```

Streamable HTTP:
```toml
[mcp_servers.epistemos]
url = "http://127.0.0.1:41892/mcp"
bearer_token_env_var = "EPISTEMOS_TOKEN"
```

Key per-server fields documented at [Codex MCP docs](https://developers.openai.com/codex/mcp) and [config-reference](https://developers.openai.com/codex/config-reference): `command`, `args`, `cwd`, `env`, `env_vars`, `url`, `bearer_token_env_var`, `headers` (object populated from env vars), `enabled`, `supports_parallel_tool_calls`, `default_tools_approval_mode`, `enabled_tools[]`, deny list, `experimental_environment = "remote"`.

Management CLI: `codex mcp add|list|get|remove`, plus `codex mcp login|logout` for OAuth-backed HTTP servers ([Codex MCP](https://developers.openai.com/codex/mcp)).

OAuth callback tuning: `mcp_oauth_callback_port` (fixed port), `mcp_oauth_callback_url` (override redirect URI for Devbox/ingress) ([config-reference](https://developers.openai.com/codex/config-reference)).

### 2.5 Other relevant top-level keys

- `[tools]` — toggles for `web_search` (`cached`|`live`|`disabled`; `cached` is default, `live` uses `--search` or `--yolo` presets), `plan_tool`, `view_image`.
- `[notifications]`, `[history]`, `[otel]` (telemetry), `[windows]` (native Windows sandbox: `elevated` recommended, `unelevated` fallback).
- `[[skills.config]]` — per-skill path and `enabled = false` overrides. Codex adopted the same SKILL.md format as Claude Code in late 2025 ([Codex Skills docs](https://developers.openai.com/codex/skills)).
- `[agents.<name>]` and `agents.max_depth` / `agents.max_threads` — Codex subagents ([config-reference](https://developers.openai.com/codex/config-reference)).

### 2.6 `auth.json`

`~/.codex/auth.json` stores OAuth credentials (for `ChatGPT` login) or the API key. OpenAI explicitly warns against copying it across machines because it encodes machine-bound token material; regenerate per-machine via `codex login` ([Codex Authentication](https://developers.openai.com/codex/auth)). Epistemos **must not** generate or touch `auth.json` — auth is the user's responsibility.

### 2.7 Non-interactive mode

`codex exec` (alias `codex e`) is the automation entry point ([CLI reference](https://developers.openai.com/codex/cli/reference)):

- `--full-auto` — low-friction preset: `sandbox_mode = "workspace-write"` + `approval_policy = "on-request"`.
- `--dangerously-bypass-approvals-and-sandbox` / `--yolo` — fully unrestricted; intended only for ephemeral containers.
- `--json` — newline-delimited JSON event stream.
- `--output-schema <file>` — JSON Schema that the final response must validate against.
- `--output-last-message <file>` — write assistant final message to a file.
- `--ephemeral` — don't persist session rollouts.
- `--ignore-user-config` / `--ignore-rules` — skip `$CODEX_HOME/config.toml` and project rule files for deterministic CI ([Toolsbase cheat sheet](https://toolsbase.dev/en/reference/codex-commands)).
- `-a never` — disable all approvals.
- `-c key=value` — arbitrary TOML override (dot notation supported).

### 2.8 Codex **as** an MCP server

`codex mcp serve` starts Codex as a stdio MCP server so other tools can drive it — confirmed as a supported command ([CLI reference](https://developers.openai.com/codex/cli/reference)). This is useful if Epistemos wants to embed Codex as a subagent, but it is orthogonal to registering Epistemos's *own* MCP server with Codex.

---

## 3. Google Gemini CLI — `.gemini/settings.json`

### 3.1 Scope hierarchy and file locations

Gemini CLI discovers settings at two levels ([gemini-cli MCP docs](https://google-gemini.github.io/gemini-cli/docs/tools/mcp-server.html); [geminicli.com MCP guide](https://geminicli.com/docs/tools/mcp-server/)):

- User/global: `~/.gemini/settings.json`
- Project: `.gemini/settings.json` in the vault root

Extensions can also contribute mcpServers, but local settings always have final veto via `excludeTools` ([gemini-cli MCP docs](https://google-gemini.github.io/gemini-cli/docs/tools/mcp-server.html)).

### 3.2 Canonical schema

The authoritative JSON schema lives at [`schemas/settings.schema.json`](https://fossies.org/linux/gemini-cli/schemas/settings.schema.json) in the `google-gemini/gemini-cli` repo. Key top-level sections as of April 2026:

```jsonc
{
  "$schema": "https://raw.githubusercontent.com/google-gemini/gemini-cli/main/schemas/settings.schema.json",

  "model": {
    "name": "gemini-2.5-pro",
    "maxSessionTurns": 200,
    "temperature": 0.2,
    "topP": 0.95
  },

  "mcpServers": {                 // object map, key = server id
    "epistemos": {
      "command": "/usr/local/bin/epistemos-mcp",
      "args": ["--vault","${EPISTEMOS_VAULT}"],
      "env": { "EPISTEMOS_VAULT": "$EPISTEMOS_VAULT" },
      "cwd": "${EPISTEMOS_VAULT}",
      "timeout": 30000,
      "trust": false              // if true, skips confirmation dialogs
    }
  },

  "mcp": {                        // global MCP settings
    "allowed": ["epistemos","github"],
    "excluded": []
  },

  "coreTools":   ["ReadFile","WriteFile","Edit","Grep","Glob","Shell"],
  "excludeTools":["Shell(rm *)","Shell(curl *)"],
  "includeTools":[],              // if set, intersection with extension tools

  "sandbox": "docker",            // true | "docker" | "podman" | false
  "sandboxImage": "gcr.io/gemini-cli/sandbox:stable",

  "contextFileName": "GEMINI.md", // file Gemini CLI reads as memory (analogue of CLAUDE.md)

  "autoAccept": false,            // if true, --yolo-equivalent by default
  "policyPaths": [".gemini/policies"],
  "adminPolicyPaths": [],

  "telemetry": { "enabled": false },
  "ui": { "hideBanner": true, "compactToolOutput": true, "inlineThinkingMode": "off" },

  "auth": { "type": "oauth-personal" }  // oauth-personal | gemini-api-key | vertex-ai
}
```

**MCPServerConfig** per-server properties ([gemini-cli MCP reference](https://github.com/google-gemini/gemini-cli/blob/main/docs/tools/mcp-server.md)):
- Stdio: `command`, `args`, `env`, `cwd`, `timeout` (ms), `trust` (bool)
- Streamable HTTP / SSE: `httpUrl` (HTTP) **or** `url` (SSE) + `headers` object
- `includeTools[]` / `excludeTools[]` per-server tool filtering

### 3.3 GEMINI.md — Gemini CLI's equivalent of CLAUDE.md

Gemini CLI's memory file is **`GEMINI.md`** by default (path configurable via `contextFileName` in settings) ([gemini-cli docs](https://google-gemini.github.io/gemini-cli/)). It loads GEMINI.md hierarchically just like Claude does (walks from cwd up). For Epistemos, the practical approach is to write `GEMINI.md` as a thin file that **`@`-imports** the same `.claude/rules/*.md` rule files — maximizing reuse and keeping a single source of truth for vault conventions.

### 3.4 Tool restriction semantics (the "most restrictive wins" rule)

When an extension contributes tools and the user overrides, Gemini merges as follows ([gemini-cli MCP docs](https://github.com/google-gemini/gemini-cli/blob/main/docs/tools/mcp-server.md)):

- `excludeTools`: **unioned** across sources (any block sticks).
- `includeTools`: **intersected** (a tool must be in both lists to be enabled).
- `excludeTools` always wins over `includeTools`.
- `mcp.allowed`: if set, only listed server IDs connect; `mcp.excluded` blocks listed ones.

**Env sanitization** (security-important; stable as of 2026): Gemini CLI automatically redacts variables matching `*TOKEN*`, `*SECRET*`, `*PASSWORD*`, `*KEY*`, `*AUTH*`, `*CREDENTIAL*`, plus certificate/private-key patterns, from the env inherited by MCP subprocesses — **unless** you explicitly list them in a server's `env` block (which counts as informed consent) ([geminicli.com MCP doc](https://geminicli.com/docs/tools/mcp-server/)).

### 3.5 Non-interactive / CI flags

- `gemini -p "<prompt>"` or `--prompt` — one-shot execution.
- `--output-format json` — structured stdout.
- `--yolo` — auto-accept all tool calls (equivalent to `autoAccept: true`).
- `--non-interactive` — suppress TUI.
- `--sandbox` — force Docker sandbox on.

---

## 4. MCP server configuration conventions (unified April 2026 view)

The MCP spec published its November 2025 release (current stable) and has not cut a new version since, though SEPs continue to land ([2026 MCP Roadmap](https://blog.modelcontextprotocol.io/posts/2026-mcp-roadmap/)). Three transports are current:

1. **stdio** — local subprocess; most common for local, trusted servers like Epistemos.
2. **Streamable HTTP** — the current remote standard; replaces older SSE patterns. The 2026 roadmap prioritizes making Streamable HTTP stateless-friendly for horizontal scaling ([roadmap](https://blog.modelcontextprotocol.io/posts/2026-mcp-roadmap/)).
3. **SSE** — still accepted by all three CLIs but discouraged for new deployments.

**Recommendation for Epistemos:** ship an embedded **stdio** MCP server — a small Rust binary `epistemos-mcp` bundled with the macOS app and symlinked to `/usr/local/bin/epistemos-mcp` (or referenced by its absolute bundle path). Stdio is simpler, does not expose a network port, sidesteps CORS/OAuth, and all three CLIs configure it the same way (command + args + env). If a user launches Epistemos and wants the CLI to connect *to the running Epistemos process* (rather than spawn a new helper), a **Streamable HTTP** endpoint on `127.0.0.1:<ephemeral-port>` is the secondary option, with a Bearer token stored in the macOS Keychain and exported to `EPISTEMOS_TOKEN` via a launchd plist or shell integration.

### 4.1 OAuth 2.1 for MCP (April 2026 status)

MCP OAuth 2.1 support shipped and is production-stable. Codex implements it natively with `codex mcp login` ([Codex MCP](https://developers.openai.com/codex/mcp)). Gemini CLI supports OAuth 2.0 for remote SSE/HTTP servers ([geminicli.com MCP](https://geminicli.com/docs/tools/mcp-server/)). Claude Code handles OAuth via its HTTP MCP flow with `type: "http"` and either `headers.Authorization: "Bearer ${TOKEN}"` or browser-initiated OAuth when the server advertises `oauth2`. Both scopes-advertisement-from-server and client-fallback scopes are supported ([Codex MCP](https://developers.openai.com/codex/mcp)). For a local-only Epistemos stdio server, **skip OAuth** and rely on process isolation + a per-session-generated shared secret (if HTTP is used).

### 4.2 MCP Apps (SEP-1865) — status as of April 2026

MCP Apps shipped as the **first official MCP extension** on January 26, 2026 ([MCP Apps launch blog](https://blog.modelcontextprotocol.io/posts/2026-01-26-mcp-apps/); [SEP-1865](https://modelcontextprotocol.io/community/seps/1865-mcp-apps-interactive-user-interfaces-for-mcp)). Specification stable at [`specification/2026-01-26/apps.mdx`](https://github.com/modelcontextprotocol/ext-apps/blob/main/specification/2026-01-26/apps.mdx).

Key points:
- Extension ID: `io.modelcontextprotocol/ui`.
- Optional and backwards compatible; negotiated via capability handshake.
- UI resources are predeclared via the `ui://` URI scheme and referenced from tools via metadata.
- Content type for v1: `text/html;profile=mcp-app`, rendered in **sandboxed iframes** with JSON-RPC-based bidirectional communication.
- Client support: ChatGPT, Claude, Goose, Visual Studio Code shipped support; other hosts landing through 2026.

**For Epistemos,** this is an opportunity: the Epistemos MCP server could expose a `graph_walk` tool that returns a UI resource rendering an interactive D3 graph visualization of the walked subgraph. Deferred beyond v1 of Epistemos's shipping template; stay backward compatible (always include a text fallback in `tools/call` responses, per the spec guidance).

---

## 5. Sandbox and security conventions across the three CLIs

### 5.1 Sandbox models side-by-side

| CLI | Modes | "Can only write under this dir" expression |
|---|---|---|
| **Claude Code** | `defaultMode ∈ {default, acceptEdits, plan, bypassPermissions}` + `permissions.deny` patterns + `permissions.additionalDirectories[]` + OS-level sandbox (`sandboxing` docs) | `permissions.additionalDirectories: ["./vault"]` and `deny: ["Write(!./vault/**)", "Read(./.env)"]` |
| **Codex** | `sandbox_mode ∈ {read-only, workspace-write, danger-full-access}` + `[sandbox_workspace_write].writable_roots[]` | `sandbox_mode = "workspace-write"` plus `writable_roots = ["/Users/jojo/vaults/main"]` |
| **Gemini** | `sandbox: true | "docker" | "podman" | false` (runs Node container); `coreTools`/`excludeTools` for tool allow-lists | Docker sandbox mounts only the project dir by default; use `excludeTools: ["Shell(rm *)", "WriteFile(/etc/**)"]` for pattern-based denial |

Source: [Codex sandboxing](https://developers.openai.com/codex/concepts/sandboxing); [Claude sandboxing](https://code.claude.com/docs/en/sandboxing); [Gemini CLI docs](https://google-gemini.github.io/gemini-cli/).

### 5.2 Claude permission-mode semantics (current)

- `default` — prompt on each new tool use that isn't pre-allowed.
- `acceptEdits` — skip prompts for edits within allowed directories.
- `plan` — read-only planning mode; no write/execute.
- `bypassPermissions` — no prompts at all; use only in sandboxed envs. Can be disabled at managed policy with `disableBypassPermissionsMode: "disable"`.

### 5.3 Environment variable deny-list (recommended baseline for Epistemos to emit)

Both Codex's `shell_environment_policy.exclude` and Gemini's auto-sanitization already strip `*KEY*`/`*TOKEN*`/etc., but Epistemos should additionally deny these in the Codex emission and instruct users via CLAUDE.md to keep them out of the session:

```
LD_PRELOAD
LD_LIBRARY_PATH
DYLD_INSERT_LIBRARIES
DYLD_LIBRARY_PATH
NODE_OPTIONS
PYTHONSTARTUP
PYTHONPATH
DEBUG
RUBYOPT
PERL5OPT
GEM_PATH
```
These are well-known pre-execution injection vectors used by the broader container-security literature. Codex's `include_only` allowlist approach is even safer: list exactly `["PATH","HOME","SHELL","LANG","LC_ALL","USER","TERM","EPISTEMOS_VAULT","EPISTEMOS_TOKEN"]` ([Codex shell_environment_policy](https://developers.openai.com/codex/config-reference)).

### 5.4 Codex protected paths

Codex treats `.git/` and `.codex/` inside writable roots as protected — writes are still prompted even in workspace-write ([Codex sandbox doc](https://developers.openai.com/codex/concepts/sandboxing)). Epistemos should emit a similar convention: add an Epistemos-specific Codex rule in `.codex/config.toml`:

```toml
[permissions.workspace.filesystem]
":project_roots" = { "." = "write", "**/.epistemos/**" = "none", "**/*.env" = "none" }
glob_scan_max_depth = 3
default_permissions = "workspace"
```
per [Codex agent-approvals-security](https://developers.openai.com/codex/agent-approvals-security).

---

## 6. The manifest-to-config compilation pattern

### 6.1 Prior art

- **AGENTS.md** (vendor-neutral memory-file format) is cross-read by most 2026 CLIs and is the closest thing to a standard. It's a single markdown document; compilers exist (e.g., [agents-md](https://github.com/openai/codex/blob/main/docs/agents.md) convention is shared across Codex, Cursor, Aider).
- **Antigravity Awesome Skills** ships cross-CLI `SKILL.md` installers (`npx antigravity-awesome-skills — claude|codex|gemini`), demonstrating a one-manifest-to-many-tools pattern for skills ([Medium 2026](https://medium.com/@unicodeveloper/10-must-have-skills-for-claude-and-any-coding-agent-in-2026-b5451b013051)).
- No widely-used OSS tool yet compiles a single project descriptor into the **full** CLAUDE.md + `.claude/settings.json` + `.codex/config.toml` + `.gemini/settings.json` quadruple. Epistemos is early here; the design below leans on the commonalities (mcpServers, env, permission rules) and fills per-CLI gaps.

### 6.2 Minimum manifest fields to deterministically produce all three configs

```
project_name        # → comments in each file, headers in CLAUDE.md
vault_root          # → writable_roots, additionalDirectories, cwd
preferred_models    # per role: planner, writer, fast → model fields
allowed_tools       # canonical tool names (internal, translated per-CLI)
denied_tools        # → permissions.deny, excludeTools
bash_allow[]        # → Bash(pattern) allow rules; translated to Shell() for Gemini
bash_deny[]         # → Bash/Shell deny rules
approval_policy     # mapped: untrusted|on-request|never (Codex) / permission modes (Claude)
sandbox_profile     # read-only | workspace-write | full-access
budget_cap_usd      # → hints injected into CLAUDE.md
mcp_servers[]       # list of {id, transport: stdio|http, command|url, args, env, oauth?}
skills[]            # paths to SKILL.md dirs
rules[]             # paths to .claude/rules md files
hooks{}             # map of event -> command list
env_allowlist[]     # Codex include_only list
env_denylist[]      # Codex exclude list
output_style        # Claude outputStyle name
personal_notes_import # path for CLAUDE.local.md @-import
```

### 6.3 Canonical Rust struct (with `schemars::JsonSchema`)

```rust
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::path::PathBuf;

#[derive(Debug, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub struct EpistemosManifest {
    /// Human-readable project name; used in file headers and banner.
    pub project_name: String,

    /// Absolute path to the vault root. Must exist.
    pub vault_root: PathBuf,

    /// Model routing by task role. Keys: "planner", "writer", "fast",
    /// "reasoning_heavy", "summary".
    pub models: BTreeMap<String, ModelRef>,

    /// Approval policy — translated per-CLI.
    pub approval: ApprovalPolicy,

    /// Sandbox profile — translated per-CLI.
    pub sandbox: SandboxProfile,

    /// Tool permissions (internal canonical vocabulary).
    pub permissions: Permissions,

    /// MCP servers to register in every CLI.
    pub mcp_servers: Vec<McpServer>,

    /// Skill directories (each containing SKILL.md). Written to .claude/skills/
    /// and .codex/skills/ symlinks; referenced from GEMINI.md.
    pub skills: Vec<PathBuf>,

    /// Modular rule files. Written to .claude/rules/ and @-imported from
    /// GEMINI.md and AGENTS.md.
    pub rules: Vec<RuleFile>,

    /// Lifecycle hooks. Keys use Claude Code event names; mapped to
    /// Codex hook events where supported.
    pub hooks: BTreeMap<String, Vec<HookCommand>>,

    /// Env vars passed to child tool processes (allowlist).
    #[serde(default)]
    pub env_allow: Vec<String>,

    /// Env vars explicitly stripped (denylist).
    #[serde(default)]
    pub env_deny: Vec<String>,

    /// Claude outputStyle name ("Epistemos" to use the bundled style).
    #[serde(default)]
    pub output_style: Option<String>,

    /// Optional soft budget reminder, surfaced in CLAUDE.md prose.
    #[serde(default)]
    pub budget_cap_usd: Option<f64>,

    /// Path for CLAUDE.local.md → @-imports for personal notes.
    #[serde(default)]
    pub personal_notes: Option<PathBuf>,
}

#[derive(Debug, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub struct ModelRef {
    /// Provider-agnostic model identifier (translated per-CLI).
    pub id: String,
    /// Optional reasoning effort (Codex only): low | medium | high | xhigh.
    #[serde(default)]
    pub reasoning_effort: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "kebab-case")]
pub enum ApprovalPolicy {
    /// Prompt before every tool use.
    Untrusted,
    /// Prompt only when escaping the sandbox or running risky commands.
    OnRequest,
    /// No prompts (use with caution; only for CI).
    Never,
}

#[derive(Debug, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "kebab-case")]
pub enum SandboxProfile {
    /// Read-only access; no writes, no shell execution that mutates.
    ReadOnly,
    /// Writes confined to vault_root; no network.
    WorkspaceWrite,
    /// Writes confined to vault_root; outbound network allowed.
    WorkspaceWriteNet,
    /// No sandbox. For containerized runs only.
    DangerFullAccess,
}

#[derive(Debug, Serialize, Deserialize, JsonSchema)]
pub struct Permissions {
    /// Pre-approved tool invocations, e.g. "Bash(git diff *)".
    #[serde(default)]
    pub allow: Vec<String>,
    /// Require confirmation, e.g. "Bash(git push *)".
    #[serde(default)]
    pub ask: Vec<String>,
    /// Hard-deny patterns, e.g. "Read(./.env)".
    #[serde(default)]
    pub deny: Vec<String>,
    /// Extra directories readable beyond vault_root.
    #[serde(default)]
    pub additional_dirs: Vec<PathBuf>,
}

#[derive(Debug, Serialize, Deserialize, JsonSchema)]
#[serde(tag = "transport", rename_all = "kebab-case")]
pub enum McpServer {
    Stdio {
        id: String,
        command: PathBuf,
        #[serde(default)] args: Vec<String>,
        #[serde(default)] env: BTreeMap<String, String>,
        #[serde(default)] cwd: Option<PathBuf>,
        /// Pre-trust this server (skips Gemini `trust` dialogs).
        #[serde(default)] trust: bool,
    },
    Http {
        id: String,
        url: String,
        #[serde(default)] headers: BTreeMap<String, String>,
        /// Env var name holding the bearer token.
        #[serde(default)] bearer_token_env_var: Option<String>,
        #[serde(default)] trust: bool,
    },
}

#[derive(Debug, Serialize, Deserialize, JsonSchema)]
pub struct RuleFile {
    /// File name under .claude/rules/, e.g. "vault-conventions.md".
    pub name: String,
    /// Path globs this rule applies to (null = always apply).
    #[serde(default)]
    pub paths: Option<Vec<String>>,
    /// Rule body (markdown).
    pub body: String,
}

#[derive(Debug, Serialize, Deserialize, JsonSchema)]
pub struct HookCommand {
    /// Regex matcher against tool name (event-dependent).
    #[serde(default)]
    pub matcher: Option<String>,
    /// Shell command to run.
    pub command: String,
    #[serde(default)] pub timeout: Option<u32>,
    #[serde(default)] pub async_: Option<bool>,
}
```

The compiler function signature:

```rust
pub fn compile(manifest: &EpistemosManifest) -> Result<CompiledFiles, CompileError>;

pub struct CompiledFiles {
    pub claude_md:        String,            // → ./CLAUDE.md
    pub claude_local_md:  Option<String>,    // → ./CLAUDE.local.md (if personal_notes)
    pub claude_settings:  serde_json::Value, // → ./.claude/settings.json
    pub mcp_json:         serde_json::Value, // → ./.mcp.json
    pub codex_config:     String,            // TOML → ./.codex/config.toml
    pub gemini_settings:  serde_json::Value, // → ./.gemini/settings.json
    pub gemini_md:        String,            // → ./GEMINI.md
    pub rule_files:       Vec<(PathBuf, String)>, // → ./.claude/rules/*.md
}
```

### 6.4 Regeneration policy — when to rewrite

| File | Regenerate on… | Rationale |
|---|---|---|
| `CLAUDE.md`, `GEMINI.md` | Session start **and** manifest change | They're mostly stable; session start ensures no drift from user edits since Epistemos is source of truth. If the user has local edits, Epistemos should detect via checksum and prompt. |
| `.claude/rules/*.md` | Manifest change only | Stable across sessions; preserve user additions that don't conflict with manifest-owned names. |
| `.claude/settings.json` | Session start | MCP server port may change on each launch (if using HTTP); hook paths may change if app bundle moves. |
| `.mcp.json` | Session start | Same as above — this holds the live port/command line for the Epistemos MCP helper. |
| `.codex/config.toml` | Session start | Same. |
| `.gemini/settings.json` | Session start | Same. |
| `CLAUDE.local.md` | **Never** overwrite if it exists; create on first run only | User-owned file. |

The session-start regeneration should write *atomically* (write to `.tmp`, `fsync`, `rename`) and should preserve a user-editable region. Convention: wrap Epistemos-owned blocks with markers:

```
<!-- BEGIN EPISTEMOS AUTOGEN — DO NOT EDIT BY HAND -->
…generated content…
<!-- END EPISTEMOS AUTOGEN -->
```
Anything outside these markers is preserved.

---

## 7. Epistemos-specific content

### 7.1 Epistemos MCP tool surface (recommended v1)

Vault I/O:
- `vault_read(path)` — read a note by path.
- `vault_write(path, content, create_if_missing?)` — write a note; creates directory tree.
- `vault_list(glob?)` — list notes matching a glob.
- `vault_search(query, filters?)` — full-text + metadata search (GRDB FTS5).

Note primitives (higher-level; the model should prefer these over raw file ops):
- `note_create(title, frontmatter, body, folder?)` — creates a Markdown note with YAML frontmatter, assigns an Epistemos ID, generates the filename from the title.
- `note_update(id, patch)` — structured patch (title, body, frontmatter merge, tags).
- `note_delete(id, hard?)` — soft-archive by default.
- `note_link(from_id, to_id, kind?)` — creates/updates a wiki-link, supports typed links (`kind: "supports" | "contradicts" | "cites"`).
- `daily_note(date?)` — idempotent; returns today's daily note, creating if needed.

Graph:
- `backlinks(id)` / `frontlinks(id)` — neighbors in each direction.
- `graph_walk(start_id, depth, filter?)` — BFS walk; returns subgraph.
- `graph_query(cypher_like)` — structured query (optional v2).

Embeddings (MLX-Swift):
- `embed_search(query, top_k)` — semantic search over notes.
- `similar_notes(id, top_k)` — "more like this".

Each tool should advertise MCP Apps UI resources where they add value: `graph_walk` → interactive graph, `embed_search` → ranked card list. Include a text fallback per SEP-1865.

### 7.2 CLAUDE.md — Epistemos vault template (drop-in)

```markdown
<!-- BEGIN EPISTEMOS AUTOGEN — DO NOT EDIT BY HAND -->
# Epistemos Vault — {{PROJECT_NAME}}

You are working inside an **Epistemos vault** — a personal knowledge
management graph managed by the Epistemos macOS app. Notes are Markdown
files with YAML frontmatter; links are wiki-style `[[Note Title]]`;
the graph is backed by GRDB and an MLX-Swift embedding index.

## Golden rules
1. **Prefer Epistemos MCP tools over raw file operations.**
   Use `note_create`, `note_update`, `note_link`, `daily_note`,
   `vault_search`, `graph_walk`, `backlinks`, `frontlinks`,
   `embed_search` when the task is about notes or the graph.
   Only fall back to `Read`/`Write`/`Edit` for non-note files
   (scripts, README, config).
2. **Never write outside the vault root** (`{{VAULT_ROOT}}`) without
   explicit user instruction.
3. **Never read secrets** — `.env`, `.env.*`, anything under `secrets/`,
   anything with `*.key`, `*.pem`, `id_rsa*`. These are denied at the
   permission layer; treat a denial as a signal to stop, not retry.
4. **Every new note gets frontmatter.** See
   @.claude/rules/vault-conventions.md for the schema.

## Quick orientation
- Vault root: `{{VAULT_ROOT}}`
- Inbox: `./inbox/` — capture-first, unprocessed notes
- Daily notes: `./daily/YYYY-MM-DD.md`
- Projects: `./projects/<slug>/`
- References: `./refs/`
- Archive (soft-deleted): `./.epistemos/archive/`
- App data (do not edit): `./.epistemos/**`

## Commands
- Open the Epistemos MCP tool explorer: `/mcp`
- Skills available in this vault: see `/skills`

## Modular instructions (loaded automatically)
@.claude/rules/vault-conventions.md
@.claude/rules/note-schema.md
@.claude/rules/link-grammar.md
@.claude/rules/tagging.md
@.claude/rules/citation.md

## When unsure
- For graph traversal questions, call `graph_walk` before guessing.
- For "find me notes about X", call `embed_search` and then
  `vault_search` as a fallback.
- For new knowledge capture, always `note_create` with explicit
  frontmatter rather than `Write`.

## Budget
{{#BUDGET}}Soft session budget: ${{BUDGET}}. If you are about to exceed
this on reasoning-heavy calls, summarize progress and ask before
continuing.{{/BUDGET}}
<!-- END EPISTEMOS AUTOGEN -->
```

### 7.3 `.claude/rules/vault-conventions.md` (path-scoped)

```markdown
---
paths:
  - "**/*.md"
  - "!.epistemos/**"
---
## Epistemos vault conventions

Every note is a Markdown file with a YAML frontmatter block. Required
fields:

```yaml
---
id:        01JXYZ…            # ULID; generated by note_create
title:     Clear human title
created:   2026-04-22T10:15:00Z
updated:   2026-04-22T10:15:00Z
tags:      [topic-a, topic-b]  # kebab-case
source:    { kind: "web" | "book" | "paper" | "conversation" | "self",
             url?: "…",
             citation?: "…" }
status:    draft | seedling | budding | evergreen | archived
---
```

- **One idea per note.** If a note grows past ~400 words of new content,
  ask whether to split it.
- **Link liberally but typedly.** Prefer `note_link(from, to, kind)`
  over inline `[[ ]]` where the relation has a name
  ("supports", "contradicts", "cites", "generalizes", "example-of").
- **Daily notes** live in `./daily/YYYY-MM-DD.md` and are created via
  `daily_note()`. Do not `Write` them directly.
- **Filenames** are slugified titles; never edit filenames by hand —
  use `note_update(id, {title})`, which renames atomically.
```

### 7.4 `CLAUDE.local.md` — personal overrides template

```markdown
# Personal overrides for {{PROJECT_NAME}}
# This file is gitignored. Edit freely.

## Me
- Name: Jordan ("Jojo")
- Preferred reply style: terse, code-first, no hedging.

## Tool preferences (override project defaults)
- Use `claude-opus-4-6` for planning; `claude-sonnet-4-6` for edits.
- Skip the "explain the change" preamble unless the diff is >50 lines.

## Imports
@~/.claude/personal/writing-style.md
@~/.claude/personal/code-style.md

## Scratch
<!-- your running notes here -->
```

### 7.5 `.claude/settings.json` — Epistemos template

```jsonc
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "model": "claude-sonnet-4-6",
  "outputStyle": "Epistemos",
  "permissions": {
    "defaultMode": "default",
    "additionalDirectories": [],
    "allow": [
      "mcp__epistemos__vault_read",
      "mcp__epistemos__vault_list",
      "mcp__epistemos__vault_search",
      "mcp__epistemos__backlinks",
      "mcp__epistemos__frontlinks",
      "mcp__epistemos__graph_walk",
      "mcp__epistemos__embed_search",
      "mcp__epistemos__similar_notes",
      "mcp__epistemos__daily_note",
      "Read",
      "Glob",
      "Grep",
      "Bash(git diff *)",
      "Bash(git log *)",
      "Bash(git status)",
      "Bash(git branch *)"
    ],
    "ask": [
      "mcp__epistemos__note_create",
      "mcp__epistemos__note_update",
      "mcp__epistemos__note_link",
      "mcp__epistemos__vault_write",
      "Write",
      "Edit",
      "Bash(git commit *)",
      "Bash(git push *)"
    ],
    "deny": [
      "mcp__epistemos__note_delete",
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)",
      "Read(**/*.key)",
      "Read(**/*.pem)",
      "Read(**/id_rsa*)",
      "Read(./.epistemos/**)",
      "Write(./.epistemos/**)",
      "Edit(./.epistemos/**)",
      "WebFetch",
      "Bash(curl *)",
      "Bash(wget *)",
      "Bash(rm -rf *)"
    ]
  },
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": ["epistemos"],
  "env": {
    "EPISTEMOS_VAULT": "{{VAULT_ROOT}}",
    "EPISTEMOS_PORT":  "{{EPISTEMOS_PORT}}"
  },
  "hooks": {
    "SessionStart": [{
      "matcher": "startup|resume",
      "hooks": [{
        "type": "command",
        "command": "{{APP_BUNDLE}}/Contents/Resources/hooks/session-start.sh",
        "timeout": 5
      }]
    }],
    "PreToolUse": [{
      "matcher": "Write|Edit|MultiEdit",
      "hooks": [{
        "type": "command",
        "command": "{{APP_BUNDLE}}/Contents/Resources/hooks/deny-outside-vault.sh",
        "timeout": 2
      }]
    }, {
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "{{APP_BUNDLE}}/Contents/Resources/hooks/scrub-dangerous.sh",
        "timeout": 2
      }]
    }],
    "PostToolUse": [{
      "matcher": "mcp__epistemos__note_(create|update|delete|link)",
      "hooks": [{
        "type": "command",
        "command": "{{APP_BUNDLE}}/Contents/Resources/hooks/reindex-graph.sh",
        "timeout": 10,
        "async": true
      }]
    }]
  },
  "statusLine": {
    "type": "command",
    "command": "{{APP_BUNDLE}}/Contents/Resources/hooks/statusline.sh"
  },
  "cleanupPeriodDays": 30
}
```

And the companion `.mcp.json` (the file that **actually** holds the MCP server definition, per §1.1's caveat):

```jsonc
{
  "mcpServers": {
    "epistemos": {
      "type": "stdio",
      "command": "{{APP_BUNDLE}}/Contents/MacOS/epistemos-mcp",
      "args": ["--vault", "{{VAULT_ROOT}}"],
      "env": {
        "EPISTEMOS_VAULT": "{{VAULT_ROOT}}",
        "EPISTEMOS_LOG_LEVEL": "info"
      }
    }
  }
}
```

### 7.6 `.codex/config.toml` — Epistemos template

```toml
# Generated by Epistemos on session start. Do not edit by hand.
# Project-scoped config; loaded only when the vault is trusted
# (run `codex --trust .` once in this directory).

model = "gpt-5.4"
model_reasoning_effort = "medium"

approval_policy = "on-request"
sandbox_mode    = "workspace-write"
allow_login_shell = false

[sandbox_workspace_write]
writable_roots = ["{{VAULT_ROOT}}"]
network_access = false
exclude_slash_tmp       = false
exclude_tmpdir_env_var  = false

[shell_environment_policy]
inherit      = "core"
include_only = [
  "PATH", "HOME", "SHELL", "LANG", "LC_ALL", "USER", "TERM",
  "EPISTEMOS_VAULT", "EPISTEMOS_PORT"
]
exclude = [
  "*KEY*", "*TOKEN*", "*SECRET*", "*PASSWORD*", "*CREDENTIAL*",
  "LD_PRELOAD", "LD_LIBRARY_PATH",
  "DYLD_INSERT_LIBRARIES", "DYLD_LIBRARY_PATH",
  "NODE_OPTIONS", "PYTHONSTARTUP", "PYTHONPATH",
  "DEBUG", "RUBYOPT", "PERL5OPT"
]
ignore_default_excludes = false

# Protect Epistemos internal state and secrets even inside writable roots.
default_permissions = "workspace"
[permissions.workspace.filesystem]
":project_roots" = { ".", "write", "**/.epistemos/**" = "none",
                     "**/*.env" = "none", "**/*.key" = "none",
                     "**/*.pem" = "none" }
glob_scan_max_depth = 3

[features]
web_search_request = false
unified_exec       = true
codex_hooks        = false   # Codex hooks still under development Apr 2026

# --- Profiles ---------------------------------------------------------

[profiles.default]
model = "gpt-5.4"
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[profiles.planning]
model = "gpt-5.4"
model_reasoning_effort = "high"
approval_policy = "on-request"
sandbox_mode = "read-only"

[profiles.ci]
model = "o4-mini"
approval_policy = "never"
sandbox_mode    = "workspace-write"
features.web_search_request = false

# --- MCP servers ------------------------------------------------------

[mcp_servers.epistemos]
command = "{{APP_BUNDLE}}/Contents/MacOS/epistemos-mcp"
args    = ["--vault", "{{VAULT_ROOT}}"]
cwd     = "{{VAULT_ROOT}}"
env     = { EPISTEMOS_VAULT = "{{VAULT_ROOT}}",
            EPISTEMOS_LOG_LEVEL = "info" }
env_vars = ["PATH", "HOME", "LANG"]
supports_parallel_tool_calls = false
default_tools_approval_mode  = "auto"
enabled = true

# Ask before destructive writes.
[mcp_servers.epistemos.tools.vault_write]
approval_mode = "approve"
[mcp_servers.epistemos.tools.note_update]
approval_mode = "approve"
[mcp_servers.epistemos.tools.note_delete]
approval_mode = "approve"

[history]
# Keep sessions discoverable by the Epistemos app.
persistence = "save"

[notifications]
# desktop notification integration (optional)
# notify = ["osascript", "-e", "display notification \"Codex ready\""]
```

### 7.7 `.gemini/settings.json` — Epistemos template

```jsonc
{
  "$schema": "https://raw.githubusercontent.com/google-gemini/gemini-cli/main/schemas/settings.schema.json",
  "model": { "name": "gemini-2.5-pro", "maxSessionTurns": 200 },
  "contextFileName": "GEMINI.md",
  "mcpServers": {
    "epistemos": {
      "command": "{{APP_BUNDLE}}/Contents/MacOS/epistemos-mcp",
      "args": ["--vault", "{{VAULT_ROOT}}"],
      "env": {
        "EPISTEMOS_VAULT": "$EPISTEMOS_VAULT",
        "EPISTEMOS_LOG_LEVEL": "info"
      },
      "cwd": "{{VAULT_ROOT}}",
      "timeout": 30000,
      "trust": false,
      "includeTools": [
        "vault_read","vault_list","vault_search","vault_write",
        "note_create","note_update","note_link","daily_note",
        "backlinks","frontlinks","graph_walk",
        "embed_search","similar_notes"
      ],
      "excludeTools": ["note_delete"]
    }
  },
  "mcp": { "allowed": ["epistemos"] },
  "coreTools":    ["ReadFile","WriteFile","Edit","Grep","Glob","Shell"],
  "excludeTools": [
    "Shell(rm *)",
    "Shell(curl *)",
    "Shell(wget *)",
    "ReadFile(./.env)",
    "ReadFile(./.env.*)",
    "ReadFile(./secrets/**)",
    "ReadFile(./.epistemos/**)",
    "WriteFile(./.epistemos/**)"
  ],
  "sandbox": "docker",
  "sandboxImage": "gcr.io/gemini-cli/sandbox:stable",
  "autoAccept": false,
  "ui": { "compactToolOutput": true, "inlineThinkingMode": "off" },
  "telemetry": { "enabled": false }
}
```

`GEMINI.md` in the vault root mirrors CLAUDE.md (same content, with `@.claude/rules/*.md` rewritten as direct copies or `@`-imports depending on the CLI's support for imports — Gemini CLI's import support is limited compared to Claude's; safest is to include the rule bodies inline for Gemini and keep Claude's version as imports).

---

## 8. Change log vs. early 2025 — what moved

| Change | Early 2025 | April 2026 |
|---|---|---|
| Claude MCP project scope | `.mcp.json` existed but poorly documented | **Canonical** location for project MCP; `settings.json` silently ignores `mcpServers` ([issue #24477](https://github.com/anthropics/claude-code/issues/24477)) |
| Claude Skills | "Custom commands" via `.claude/commands/*.md` | **Skills** (`.claude/skills/<name>/SKILL.md`) preferred; commands still work. Skills cross-compatible with Codex, Gemini, Cursor ([Skills docs](https://code.claude.com/docs/en/skills)) |
| Claude permission modes | `acceptEdits`/`default`/`plan`/`bypassPermissions` | Same modes + new **auto mode** classifier (`autoMode` setting) introduced in 2026 ([settings](https://code.claude.com/docs/en/settings)) |
| Claude hooks | ~8 events | **21 events** + `prompt` and `agent` handler types added ([Smartscope 2026](https://smartscope.blog/en/generative-ai/claude/claude-code-hooks-guide/)) |
| Codex project config | Only `~/.codex/config.toml` | **`.codex/config.toml`** project-scope added; trusted-project gate |
| Codex approval policy | `untrusted`/`on-failure`/`on-request`/`never` | `on-failure` **deprecated**; `granular` variant added |
| Codex feature flags | ad-hoc booleans | Centralized `[features]` table + `codex features` inspector |
| MCP spec | 2024-11/2025-03/2025-06 revisions | **November 2025** current stable; no new version cut in 2026 yet; Streamable HTTP dominant transport |
| MCP Apps (UI) | MCP-UI / OpenAI Apps SDK fragmented | **SEP-1865 finalized 2026-01-26**; single open standard ([MCP Apps blog](https://blog.modelcontextprotocol.io/posts/2026-01-26-mcp-apps/)) |
| Gemini CLI auth | `oauth-personal` only in early 2025 | `oauth-personal` + `gemini-api-key` + `vertex-ai` + Workspace SSO |
| AGENTS.md | Niche | Widely read by Codex, Cursor, Aider, and as a secondary file by Claude Code |

---

## 9. Practical notes for Epistemos implementation

1. **Regenerate atomically and idempotently.** Write to `.tmp`, `fsync`, `rename`. Diff before rewriting and skip if unchanged — avoids cache-busting file watchers in Claude Code and Codex.
2. **Guard user edits.** Use `<!-- BEGIN EPISTEMOS AUTOGEN -->` markers in Markdown; use separate `managed-*.toml`/`managed-*.json` sidecars for JSON/TOML if you want a cleaner split. Preferred: keep all three CLI configs fully machine-owned, and put user custom rules in `.claude/rules/user-*.md` which Epistemos never touches.
3. **Mark the vault as trusted in Codex on first run.** Either emit instructions in Epistemos's first-run UI, or shell out `codex config trust-project .` equivalent if/when it's available.
4. **Stdio over HTTP for v1.** Simpler, no port management, no Keychain round-trip. Move to HTTP + per-session Bearer token when you need multi-client access or remote MCP.
5. **Keep the skill list small.** Ship 3-5 high-leverage skills (`/daily-note`, `/capture-to-inbox`, `/promote-seedling`, `/synthesize-notes`, `/graph-report`) and let users add their own under `~/.claude/skills/`.
6. **Test the deny list.** Write an integration test that launches each CLI in a scratch vault and attempts to `Read(./.env)`, `Write(./.epistemos/db.sqlite)`, and `Bash(curl evil.com)` — assert all three are blocked. This is the single most valuable unit of CI for this subsystem.
7. **Respect the `auth.json` warning.** Never generate or copy `auth.json`/`~/.claude.json` user-scope content; Epistemos only writes *project*-scoped files.
8. **Watch for MCP spec revisions.** The 2026 roadmap signals Streamable HTTP evolution and Tasks primitive lifecycle changes ([2026 roadmap](https://blog.modelcontextprotocol.io/posts/2026-mcp-roadmap/)); keep the compiler's transport emitters behind a `TransportCodec` trait so you can swap without touching the manifest schema.

---

## 10. Authoritative sources (one-stop bibliography)

- Claude Code settings: <https://code.claude.com/docs/en/settings>
- Claude Code memory (CLAUDE.md): <https://code.claude.com/docs/en/memory>
- Claude Code hooks: <https://code.claude.com/docs/en/hooks>
- Claude Code skills: <https://code.claude.com/docs/en/skills>
- Claude Code sandboxing: <https://code.claude.com/docs/en/sandboxing>
- Claude Agent Skills overview: <https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview>
- Claude Code settings schema (canonical): <https://json.schemastore.org/claude-code-settings.json>
- Claude Code repo (plugin-dev & hook-development SKILL): <https://github.com/anthropics/claude-code>
- Codex config basics: <https://developers.openai.com/codex/config-basic>
- Codex config reference (full): <https://developers.openai.com/codex/config-reference>
- Codex sample config: <https://developers.openai.com/codex/config-sample>
- Codex CLI reference: <https://developers.openai.com/codex/cli/reference>
- Codex MCP: <https://developers.openai.com/codex/mcp>
- Codex sandboxing: <https://developers.openai.com/codex/concepts/sandboxing>
- Codex agent approvals & security: <https://developers.openai.com/codex/agent-approvals-security>
- Codex managed configuration (enterprise): <https://developers.openai.com/codex/enterprise/managed-configuration>
- Codex source: <https://github.com/openai/codex/blob/main/docs/config.md>
- Gemini CLI MCP docs: <https://google-gemini.github.io/gemini-cli/docs/tools/mcp-server.html>
- Gemini CLI repo MCP docs: <https://github.com/google-gemini/gemini-cli/blob/main/docs/tools/mcp-server.md>
- Gemini CLI settings schema: <https://fossies.org/linux/gemini-cli/schemas/settings.schema.json>
- MCP 2026 roadmap: <https://blog.modelcontextprotocol.io/posts/2026-mcp-roadmap/>
- MCP Apps launch (SEP-1865): <https://blog.modelcontextprotocol.io/posts/2026-01-26-mcp-apps/>
- MCP Apps spec: <https://github.com/modelcontextprotocol/ext-apps/blob/main/specification/2026-01-26/apps.mdx>
- MCP Apps SEP: <https://modelcontextprotocol.io/community/seps/1865-mcp-apps-interactive-user-interfaces-for-mcp>
- Claude Code MCP "silent ignore" issue: <https://github.com/anthropics/claude-code/issues/24477>
- Codex misspelled-key issue: <https://github.com/openai/codex/issues/3441>

This should be enough to generate correct templates, write the Rust compiler, and ship with confidence. The most important safety rail to add to the implementation test suite is the permission/deny assertion described in §9.6 — it catches the majority of regressions when any of the three upstream schemas shifts.
