# Tool Migration Status — Tools V2 Recovery Anchor — 2026-05-04

This file preserves the Quick Capture Tools V2 substrate from
`.claude/worktrees/vigorous-goldberg-3a2d35/` without bulk-copying the donor
registry. The donor branch contains the richer `Tool` trait, `ToolMeta`,
variant ladder, `legacy_adapter`, and `v2_catalog/`. Current main keeps the
legacy `ToolHandler` registry as the shipping runtime.

The recovery slice now anchored in main is the compatibility layer:

- `LEGACY_TO_V2_ALIASES`
- `v2_name_for_legacy(_:)`
- `legacy_name_for_v2(_:)`
- `ToolRegistry::execute_v2(_:_:)`

Full native `Tool` trait migration remains staged. Do not port the whole
`v2_catalog/` raw; migrate tools by family after tests prove parity.

## Alias Table

| Legacy name | V2 name | Current main status |
|---|---|---|
| `vault_search` | `vault.search` | alias dispatch to legacy handler |
| `vault_read` | `vault.read` | alias dispatch to legacy handler |
| `vault_write` | `vault.write` | alias dispatch to legacy handler |
| `bash_execute` | `action.bash` | alias dispatch; MAS-gated |
| `chunk_reduce` | `chunk.reduce` | alias dispatch |
| `pkm_graph_neighbors` | `graph.neighbors` | alias dispatch |
| `read_file` | `file.read` | alias dispatch |
| `write_file` | `file.write` | alias dispatch |
| `patch` | `file.patch` | alias dispatch |
| `search_files` | `file.search` | alias dispatch |
| `terminal` | `action.terminal` | alias dispatch; Pro-only |
| `process` | `system.process` | alias dispatch; Pro-only |
| `todo` | `system.todo` | alias dispatch |
| `cronjob` | `system.cron` | alias dispatch; Pro-only |
| `skills_list` | `skills.list` | alias dispatch |
| `skill_view` | `skills.view` | alias dispatch |
| `skill_manage` | `skills.manage` | alias dispatch; Pro-only |
| `vault_recall` | `knowledge.recall` | alias dispatch |
| `contradiction_check` | `knowledge.contradiction_check` | alias dispatch |
| `neural_recall` | `knowledge.neural_recall` | alias dispatch |
| `session_search` | `knowledge.session_search` | alias dispatch |
| `graph_query` | `graph.query` | alias dispatch |
| `vault_navigate` | `graph.vault_navigate` | alias dispatch |
| `memory` | `memory.curated` | alias dispatch |
| `web_search` | `web.search` | alias dispatch |
| `web_extract` | `web.extract` | alias dispatch |
| `web_crawl` | `web.crawl` | alias dispatch |
| `apple_notes` | `apple.notes` | alias dispatch; Pro-only |
| `apple_reminders` | `apple.reminders` | alias dispatch; Pro-only |
| `apple_calendar` | `apple.calendar` | alias dispatch; Pro-only |
| `apple_mail` | `apple.mail` | alias dispatch; Pro-only |
| `send_message` | `communication.send_message` | alias dispatch; Pro-only |
| `vision_analyze` | `media.vision_analyze` | alias dispatch |
| `image_generate` | `media.image_generate` | hidden from user catalog until shipped |
| `text_to_speech` | `media.text_to_speech` | alias dispatch |
| `imessage` | `communication.imessage` | alias dispatch; Pro-only |
| `imessage_contacts` | `communication.imessage_contacts` | alias dispatch; Pro-only |
| `channel_contacts` | `communication.channel_contacts` | alias dispatch; Pro-only |
| `route_private` | `inference.route_private` | alias dispatch |
| `mcp_discover` | `discovery.mcp_discover` | alias dispatch |
| `model_catalog` | `discovery.model_catalog` | alias dispatch |
| `trajectory_export` | `trajectory.export` | alias dispatch |
| `self_evolve` | `intelligence.self_evolve` | alias dispatch |
| `mixture_of_minds` | `intelligence.mixture_of_minds` | alias dispatch |
| `find_symbol` | `workspace.find_symbol` | alias dispatch |
| `get_function_source` | `workspace.get_function_source` | alias dispatch |
| `get_dependencies` | `workspace.get_dependencies` | alias dispatch |
| `get_dependents` | `workspace.get_dependents` | alias dispatch |
| `get_change_impact` | `workspace.get_change_impact` | alias dispatch |
| `clarify` | `clarify.ask` | delegate-bound alias |
| `perceive` | `macos.perceive` | delegate-bound alias |
| `interact` | `macos.interact` | delegate-bound alias |
| `screen_watch` | `macos.screen_watch` | delegate-bound alias |
| `ssm_resume` | `inference.ssm_resume` | delegate-bound alias |
| `constrained_generate` | `inference.constrained_generate` | delegate-bound alias |
| `nightbrain_trigger` | `intelligence.nightbrain_trigger` | delegate-bound alias |
| `inline_partner` | `intelligence.inline_partner` | delegate-bound alias |
| `capture_screenshot` | `capture.screenshot` | donor-only until native capture slice |
| `capture_voice` | `capture.voice` | donor-only until native capture slice |
| `capture_clipboard` | `capture.clipboard` | donor-only until native capture slice |

`think` is intentionally not aliased to `reason.think`. The legacy handler
returns the thought text verbatim; the native V2 canary returns a structured
object. Alias would silently change model-visible output.

## Migration Order

1. Keep `execute_v2` as a compatibility dispatch surface.
2. Port native `Tool` trait support behind the current MAS/Pro gates.
3. Convert read-only vault and file tools first.
4. Convert knowledge and graph tools after result-shape parity tests exist.
5. Convert mutating and delegate-bound tools only after Sovereign Gate resource
   grants and MAS/Pro policy checks are represented in the V2 metadata path.
6. Remove legacy `ToolHandler` only after every alias has a native V2 handler
   or an explicitly documented permanent legacy exemption.

## Verification

Focused guards:

```bash
cargo test --manifest-path agent_core/Cargo.toml --no-default-features --features mas-build tools_v2_alias_table_preserves_quick_capture_contract
cargo test --manifest-path agent_core/Cargo.toml --no-default-features --features mas-build execute_v2_accepts_canonical_dotted_names
```
