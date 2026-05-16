# Tool Inventory Truth Table — 2026-05-13

Single normalized table reconciling the four parallel tool surfaces.
Closes RCA-P1-004 ("Reconcile all command and tool inventories").

The four surfaces are NOT contradictory inventories; they each
serve a different purpose:

1. **Slash commands** (`ACCSlashCommand`) — user-facing mode +
   capability shortcuts in the composer
2. **MAS allow-list** (`ToolSurfacePolicy.coreAppStoreAllowedToolNames`) —
   tools surfaced to models on the sandboxed MAS build
3. **Rust `agent_core` registry** — full server-side tool catalog
   (gated by ToolTier + Cargo features)
4. **Local-agent grammar** (`LocalAgentCapabilityRegistry`) —
   tools the local MLX model can call via JSON-grammar

## 1. Slash commands — `ACCSlashCommand` (14 commands)

Source: `Epistemos/State/AgentCommandCenterState.swift:676`.

| Slash command | Routes to mode | MAS? | Pro? | Visible UI surface |
|---|---|---|---|---|
| `/ask` | fast | ✅ | ✅ | composer popover + landing card |
| `/notes` | agent | ✅ | ✅ | composer popover + landing card |
| `/code` | agent | ✅ | ✅ | composer popover + landing card |
| `/debug` | thinking | ✅ | ✅ | composer popover + landing card |
| `/plan` | thinking | ✅ | ✅ | composer popover + landing card |
| `/research` | agent | ✅ | ✅ | composer popover + landing card |
| `/review` | agent | ✅ | ✅ | composer popover + landing card |
| `/security-review` | agent | ✅ | ✅ | composer popover + landing card |
| `/summarize` | fast | ✅ | ✅ | composer popover |
| `/read-branch` | agent | ✅ | ✅ | composer popover |
| `/explain` | fast | ✅ | ✅ | composer popover |
| `/todo` | fast | ✅ | ✅ | composer popover |
| `/image` | agent | ⚠️ gated on `media.image_generate` resolution | ✅ | composer popover, hidden if backend cannot satisfy |

Gate check: `availableCommands(for:)` filters by
`isAvailable(for:)` AND `isExecutableInCurrentBuild`.

## 2. MAS tool allow-list — `coreAppStoreAllowedToolNames` (32 tools)

Source: `Epistemos/Bridge/ToolTierBridge.swift:192`.

| Canonical name | Category | Sandbox-safe? | Approval class |
|---|---|---|---|
| `vault.search` | vault | ✅ | auto |
| `vault.read` | vault | ✅ | auto |
| `vault.write` | vault | ✅ | medium |
| `vault.list` | vault | ✅ | auto |
| `file.read` | filesystem (vault root) | ✅ | auto |
| `file.write` | filesystem | ✅ | medium |
| `file.patch` | filesystem | ✅ | medium |
| `file.search` | filesystem | ✅ | auto |
| `system.todo` | system | ✅ | auto |
| `graph.query` | graph | ✅ | auto |
| `graph.neighbors` | graph | ✅ | auto |
| `graph.vault_navigate` | graph | ✅ | auto |
| `memory.curated` | memory | ✅ | auto |
| `web.search` | web (URLSession) | ✅ | ask/native approval |
| `web.extract` | web (URLSession) | ✅ | ask/native approval |
| `web.crawl` | web (URLSession) | ✅ | ask/native approval |
| `web.fetch` | web (URLSession) | ✅ | ask/native approval |
| `knowledge.recall` | knowledge | ✅ | auto |
| `knowledge.contradiction_check` | knowledge | ✅ | auto |
| `knowledge.evidence_score` | knowledge | ✅ | auto |
| `knowledge.session_search` | knowledge | ✅ | auto |
| `knowledge.neural_recall` | knowledge | ✅ | auto |
| `note.create` | note | ✅ | medium |
| `note.edit` | note | ✅ | medium |
| `note.research_digest` | note | ✅ | auto |
| `note.template` | note | ✅ | medium |
| `note.linker` | note | ✅ | auto |
| `clarify.ask` | composer | ✅ | auto |
| `research.collect_snippet` | research | ✅ | medium |
| `research.search_papers` | research | ✅ | ask/native approval |
| `citation.save` | research | ✅ | medium |
| `chunk.reduce` | composer | ✅ | auto |

Filter logic: `isSurfacedToolName(canonicalName, distribution:)`
returns false unless `canonicalName ∈ coreAppStoreAllowedToolNames`
on MAS. Additionally `think` is hidden everywhere and
`media.image_generate` requires a backend that supports it.

## 3. Rust `agent_core` registry — Pro tools NOT on MAS

Source: `agent_core/src/tools/registry.rs` (~60 tool registrations).
The full Pro catalog is the MAS list above PLUS:

| Pro-only canonical name | Why MAS-denied | Cargo gate |
|---|---|---|
| `bash_execute` | subprocess | `#[cfg(feature="pro-build")]` |
| `cli_passthrough` | subprocess | `#[cfg(feature="pro-build")]` |
| `terminal` | subprocess | `#[cfg(feature="pro-build")]` |
| `git.status` / `git.diff` / `git.log` | read-only Git subprocess through `omega-mcp::git`; no mutating Git verbs exposed | `omega-mcp` excludes executor under `mas-sandbox` |
| `cli_claude` / `cli_codex` / `cli_gemini` / `cli_kimi` / `goose` / `aider` | subprocess to locally installed CLI agents | `#[cfg(feature="pro-build")]` |
| `cronjob` | subprocess + persistent scheduler | `#[cfg(feature="pro-build")]` |
| `imessage_send` / `imessage_contacts` / `channel_contacts` | AppleScript subprocess | `#[cfg(feature="pro-build")]` |
| `apple_notes` / `apple_reminders` / `apple_calendar` / `apple_mail` | osascript subprocess | `#[cfg(feature="pro-build")]` |
| `computer` / `perceive` / `interact` / `screen_watch` | CGEvent + ScreenCaptureKit | Swift host-intercept; MAS stubs return denial |
| `browser_navigate` / `browser_click` / `browser_screenshot` | Chrome extension subprocess shim | Pro-only |
| `stdio_mcp` / user MCP clients | subprocess to user-provided MCP servers | `#[cfg(feature="pro-build")]` |
| `code_execution` (Python / Node / Ruby / Perl / shell) | subprocess + interpreter | Pro-only |
| `execute_code` | subprocess + sandbox | requires approval; Pro-only |
| `delegate_task` | subagent spawning is Pro/runtime-gated | `#[cfg(feature="pro-build")]` |
| `intelligence.mixture_of_minds` | multi-model loop requires Pro provider/API-key policy | `#[cfg(feature="pro-build")]` |
| `skills.list` / `skills.view` / `skills.manage` | progressive skill management is Pro-only today | `#[cfg(feature="pro-build")]` |

MAS reality check: `mas-build` Cargo feature `#[cfg]`-gates the
entire `cli_passthrough.rs`, `terminal.rs`, and stdio MCP client modules out of the
Rust dylib. Symbol scan (`nm -gU libagent_core.dylib`) on MAS
build returns ZERO matches for all of the above (verified
2026-05-13 in RCA4-P0-002 fix-pass; stdio MCP module gate source-guard added
2026-05-16 in D.1.2).

Tunnel C receipt contract: `agent_core/src/tools/cli_passthrough.rs`
backs `claude_code`, `codex`, `gemini`, `kimi`, `goose`, and `aider` with the same
`harden_cli_subprocess` runner. D.2.4 reconciled 2026-05-16: every
completed CLI call returns JSON with `tool`, `binary`, `success`,
`exit_code`, `stdout`, `stderr`, `stdout_truncated`,
`stderr_truncated`, and `mode = "cli_passthrough"`. Output pipes are
read with a 10 MiB cap per stream; nonzero exits stay structured
instead of disappearing into free-form text.

D.4 extended Tunnel C on 2026-05-16 with the Pro-only `aider` tool.
It invokes Aider's official `--message` single-shot scripting path,
keeps `--yes-always` as the non-interactive default, and forces
`--no-auto-commits --no-dirty-commits` unless the caller explicitly
opts back into Aider commits. The same hardened runner scrubs inherited
provider secrets before spawn and returns the shared JSON receipt shape.

D.4 also extended Tunnel C on 2026-05-16 with the Pro-only `goose` tool.
It invokes Goose's official headless `goose run --no-session -t <task>`
path, supports optional provider/model overrides plus built-in extensions,
requests `--output-format json` by default, and returns the same hardened
receipt shape.

The legacy `skills` facade remains registered in Rust for backward
compatibility, but it is not in `coreAppStoreAllowedToolNames`; MAS-visible
planning/tool surfaces hide it with the same policy that hides the progressive
`skills.*` tools.

Git MCP D.3 contract: `omega-mcp/src/git.rs` exposes only read-only
`git.status`, `git.diff`, and `git.log`; `execute_git_tool` validates that
`repo_root` is a Git worktree, runs `/usr/bin/git -C <repo> --no-pager`, clamps
output retention to 1 MiB, rejects absolute/traversing/option-like pathspecs,
and uses the shared omega subprocess hardener that scrubs provider API secrets
from child environments. The executor is compiled out of `mas-sandbox`; the
UniFFI wrapper returns an unavailable sentinel there.

GitHub MCP D.3 contract: `omega-mcp/src/github.rs` exposes only read-only
HTTPS GET surfaces: `github.repo`, `github.issues`, `github.pulls`, and
`github.releases`. `execute_github_tool` validates owner/repo identifiers
before constructing API paths, rejects credentials in tool arguments, uses
GitHub's versioned REST headers, accepts optional host-injected `GITHUB_TOKEN`
or `GH_TOKEN`, filters pull requests out of the issue listing, and returns
normalized JSON `ToolResult` receipts. Transport is MAS-compatible HTTPS, but
Swift allow-list surfacing is Terminal A scope and was not changed here.

Memory MCP D.3 contract: `omega-mcp/src/memory.rs` exposes
`memory.put`, `memory.get`, `memory.search`, and `memory.list` over the
four canonical `epistemos.{soul,skill,episode,semantic}.v1` schemas.
`execute_memory_tool` stores JSONL under the selected vault's
`.epistemos/memory/` directory, rejects unknown `schema_rev` values,
enforces required top-level keys, denies unknown top-level fields, enforces
12-character lowercase alphanumeric ids, caps each payload at 256 KiB, and
keeps episode/semantic stores append-only. This is a schema-guarded MCP
persistence surface; full `MutationEnvelope` call-site validation remains
in `agent_core`.

Filesystem MCP D.3 contract: `omega-mcp/src/vault.rs` exposes canonical
vault-scoped `file.read`, `file.write`, `file.list`, and `file.search` through
`execute_vault_tool`, while retaining `read_file` / `write_file` / `list_files`
and `vault.*` aliases for archived callers. `file.search` routes to the
existing mmap-backed markdown search. The executor is scoped to the selected
vault root, rejects traversal/out-of-root paths, skips hidden directories during
recursive search, and performs no subprocess or network work.

Web search MCP D.3 contract: `omega-mcp/src/web_search.rs` exposes canonical
HTTPS-only `web.search` through Brave Search and Kagi Search backends. Queue
wording named a Bing backend, but Microsoft officially retired Bing Search APIs
on 2025-08-11
(`https://learn.microsoft.com/en-us/lifecycle/announcements/bing-search-api-retirement`),
so Terminal D did not wire a fake Bing backend. `execute_web_search_tool`
accepts `provider: "brave" | "kagi"` or `WEB_SEARCH_PROVIDER`; if both backend
credentials are configured, an explicit provider is required. API keys come only
from host-injected environment (`BRAVE_SEARCH_API_KEY` / `BRAVE_API_KEY` or
`KAGI_API_KEY` / `KAGI_SEARCH_API_KEY`); credentials in tool arguments are
rejected before execution. Query, limit, offset, and backend filters are
bounded; provider results normalize to `title`, `url`, `snippet`, and
`published` in a JSON `ToolResult` receipt.

## 4. Local-agent grammar — `LocalAgentCapabilityRegistry`

Source: `Epistemos/LocalAgent/` + `Epistemos/Engine/StructuredOutput.swift`.

Tools the local MLX model can call directly via grammar:
- `vault_search` → routes to `vault.search`
- `vault_read` → routes to `vault.read`
- `vault_write` → routes to `vault.write` (approval gated)
- `file_read` → routes to `file.read`
- `file_search` → routes to `file.search`
- (More — see `LocalAgentCapabilityRegistry.swift`)

Note: `FileEditSchema` (file_replace / file_insert_at_line /
file_delete_lines) in `StructuredOutput.swift:122-181` is currently
ORPHAN dead code — defined but not consumed by any
capability dispatcher. Documented in RCA-P2-005 fix-pass.

## Mode × Capability × Build matrix

| Mode | Tools per turn | Turns | MAS | Pro |
|---|---|---|---|---|
| Fast | 0 | 1 | ✅ | ✅ |
| Thinking | 0 | 1 (with reasoning) | ✅ | ✅ |
| Pro | 8 | 3 | ✅ (MAS tools only) | ✅ (full surface) |
| Agent | 32 | 8 | ✅ (32 MAS tools only) | ✅ (full surface) |

Loop depth budget: `OverseerDepthBudget` (Swift) bounds turn × tool
escalation. In Pro builds, `delegate_task` adds a separate
child-spawn depth cap of 2 (`delegate_task::MAX_DEPTH`).

## Alias normalization table

Source: `agent_core/src/tools/registry.rs:340-380` TOOL_ALIASES.

All of these alias-routes resolve to the canonical name below.
`AgentToolNameAliases.canonical(_:)` (Swift) mirrors the same map.

| Advertised | Canonical |
|---|---|
| `read_file` | `file.read` |
| `write_file` | `file.write` |
| `edit_file` | `file.patch` |
| `delete_file` | `file.delete` |
| `patch` | `file.patch` |
| `search_files` | `file.search` |
| `list_files` | `file.list` |
| `move_file` | `file.move` |
| `todo` | `system.todo` |
| `vault_recall` | `knowledge.recall` |
| `contradiction_check` | `knowledge.contradiction_check` |
| `analyzecontradiction` | `knowledge.contradiction_check` |
| `scoreevidence` | `knowledge.evidence_score` |
| `neural_recall` | `knowledge.neural_recall` |
| `session_search` | `knowledge.session_search` |
| `create_note` | `note.create` |
| `edit_note` | `note.edit` |
| `search_notes` | `vault.search` |
| `list_notes` | `vault.list` |
| `note_template` | `note.template` |
| `note_linker` | `note.linker` |
| `research_digest` | `note.research_digest` |
| `collectsnippet` | `research.collect_snippet` |
| `createresearchnote` | `note.research_digest` |
| `citation_extractor` | `citation.extract` |
| `markdown_table` | `markdown.table` |
| `clarify` | `clarify.ask` |

## Approval classes

Source: `agent_core/src/approval.rs:540-562` plus Swift native approval
overrides in `Epistemos/Bridge/StreamingDelegate.swift`.

| Risk | Tools | UX |
|---|---|---|
| auto-approve | local read/search/list/knowledge tools | tool result inline; no modal |
| ask/native approval | read-only network tools such as `web.search` / `web.fetch` / `web.extract` / `web.crawl` | ApprovalModalView with 120s deadline |
| medium | `file.write` / `file.patch` / `vault.write` / `note.create` / `note.edit` / `note.template` / `research.collect_snippet` / `citation.save`; Pro also includes `skills.manage` | ApprovalModalView with 120s deadline |
| high | `execute_code` (Pro-only); `subprocess` aliases (Pro-only) | ApprovalModalView; risk badge; always requires explicit click |

## Provider Tool-Call Wire Compatibility

Source: `agent_core/src/providers/openai_compatible.rs`.

| Provider | Tool schema wire format | Thinking stream handling | D-scope state |
|---|---|---|---|
| Gemini | Gemini `tools: [{ functionDeclarations: [...] }]` with names normalized by `providers::tool_names` | `generationConfig.thinkingConfig.includeThoughts = true` lets streamed `thought: true` parts map to `StreamEvent::ThinkingDelta`; no-thinking turns write `thinkingBudget: 0` for Gemini 2.5 defaults | D.2.1 reconciled 2026-05-16; docs at `docs/providers/gemini.md` |
| Kimi / Moonshot | OpenAI-compatible `tools` array with function names normalized by `providers::tool_names` | `delta.reasoning_content` maps to `StreamEvent::ThinkingDelta`; `AgentConfig.enable_thinking` writes Kimi's `thinking` extension for K2.6/K2.5 | D.2.2 wired 2026-05-16; docs at `docs/providers/kimi.md` |
| Codestral | OpenAI-compatible `tools` array with function names normalized by `providers::tool_names` | No provider-specific thinking extension; streamed text/tool deltas use the shared OpenAI-compatible parser | D.2.5 wired 2026-05-16; docs at `docs/providers/codestral.md` |
| OpenRouter | OpenAI-compatible `tools` array with function names normalized by `providers::tool_names`; OpenRouter may transform schemas for provider-specific upstreams | `AgentConfig.enable_thinking` writes OpenRouter's `reasoning` object; plaintext `delta.reasoning` and `delta.reasoning_content` map to `StreamEvent::ThinkingDelta` | D.2.6 wired 2026-05-16; docs at `docs/providers/openrouter.md` |
| xAI Grok | OpenAI-compatible `tools` array with function names normalized by `providers::tool_names`; server-side xAI tools are not auto-enabled | `delta.reasoning_content` maps to `StreamEvent::ThinkingDelta`; `grok-4.3` is the explicit default after the May 15, 2026 `grok-3` retirement/redirect | D.2.3 wired 2026-05-16; docs at `docs/providers/grok.md` |
| Together AI | OpenAI-compatible `tools` array with function names normalized by `providers::tool_names`; Together's serverless catalog marks the default Llama 3.3 70B Turbo route as function-calling capable | Default route does not advertise thinking; known Together reasoning model ids can stream `delta.reasoning`, which the shared OpenAI-compatible parser maps to `StreamEvent::ThinkingDelta` | D.2.7 wired 2026-05-16; docs at `docs/providers/together.md` |

## Cross-references

- `Epistemos/Bridge/ToolTierBridge.swift` — MAS allow-list
  (authoritative)
- `Epistemos/State/AgentCommandCenterState.swift` — slash command
  enum
- `agent_core/src/tools/registry.rs` — server-side registry
- `agent_core/src/approval.rs` — approval policy
- `agent_core/Cargo.toml` — `mas-build` vs `pro-build` features
- `docs/MAS_RELEASE_MANIFEST_2026_05_13.md` — what ships in MAS
- Audit register: RCA-P1-004 (this doc), RCA-P2-005 (file-edit
  approval loop), RCA4-P0-002 (MAS symbol scan)
