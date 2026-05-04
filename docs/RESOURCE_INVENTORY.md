# Resource Inventory

> **Index status**: CANONICAL-RESEARCH — Phase R live-resource accounting; already in _consolidated.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/`.



Date: 2026-04-23
Phase: Appendix E Step 2 / Phase R.1

This inventory traces the live resource identifiers and duplicated runtime paths that back the issues in `docs/KNOWN_ISSUES_REGISTER.md`.

No new `I-xxx` issue was discovered during this pass. Two existing issues are partially mitigated in isolated UI surfaces, but they remain valid register items because the runtime is still split:
- `I-001`: `ModelVaultsSidebarSection` already carries a local alias-normalization helper, but that normalization is sidebar-local and not the canonical write/read path.
- `I-012` / `I-013`: parts of the current picker/sidebar already use `DisclosureGroup`, but the model picker shell is still custom and model-vault file operations still bypass a unified resource runtime.

## Model Identity And Alias Handling

| File:line | Resource type | ID format observed | Canonical? | Notes |
| --- | --- | --- | --- | --- |
| `Epistemos/State/InferenceState.swift:1281` | Cloud model ID enum | Provider-qualified string IDs like `openai:gpt-5.4` | No | `CloudTextModelID` persists provider-qualified IDs as raw strings. |
| `Epistemos/App/ChatCoordinator.swift:4415` | Assistant message authorship write | `authoredByProviderID` + `authoredByModelID` freeform strings | No | Persistence writes whatever `inferAuthorship(...)` returns; no shared canonical layer. |
| `Epistemos/Vault/ChatTranscriptVaultWriter.swift:182` | Transcript export attribution | Joins provider and model into human-readable text | No | Export surface reconstructs attribution from two separate string fields. |
| `Epistemos/Views/Notes/ModelInvolvementSheet.swift:133` | Contribution lookup | Exact `authoredByModelID` string match | No | Reads history by exact `modelIDs` set membership, which causes split-brain if callers disagree on ID shape. |
| `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift:823` | Sidebar-only alias bridge | `canonicalModelID(...)` plus `acceptedModelIDs(...)` alias set | Partial / local-only | This is the only observed alias reconciler, but it lives inside the sidebar model-vault UI instead of the data layer. |

## Note Resolution, Read, Search, And Write Paths

| File:line | Resource type | ID format observed | Canonical? | Notes |
| --- | --- | --- | --- | --- |
| `Epistemos/Views/Chat/NotesMentionDropdown.swift:57` | UI note attachment creation | `pageId` + title + folder subtitle | No | Composer attaches notes by `ContextAttachment(kind: .note, targetId: pageId, ...)`; no mode/capability metadata. |
| `Epistemos/Models/ChatTypes.swift:98` | Context attachment payload | `kind`, `targetId`, `title`, `subtitle` | No | Attachment struct has no attachment mode, resource selector, capability list, or version field. |
| `Epistemos/App/ChatCoordinator.swift:3071` | Chat attachment resolution gateway | Query text + attachment list + closures for title/ID/FTS/chat lookup | No | Chat runtime fans out through separate injected closures rather than one resource service. |
| `Epistemos/App/ChatCoordinator.swift:3212` | Natural-language note lookup | Regex-extracted note titles / phrases from chat text | No | Query parsing synthesizes note search phrases before hitting storage. |
| `Epistemos/App/ChatCoordinator.swift:3460` | Attached-note body fetch | Direct `targetId`, then fallback title lookup | No | Read path first fetches by page ID, then falls back to title resolution if body lookup misses. |
| `Epistemos/Sync/VaultSyncService.swift:2127` | Vault note lookup APIs | Separate `ids: [String]`, title query string, FTS query string | No | Distinct helpers for body-by-ID, title search, and full-text page ID search expose duplicate read surfaces. |
| `Epistemos/Vault/LiveNoteScanner.swift:145` | Live-note body resolution | `page.id`, managed body, inline body, `filePath` | No | Scanner loads from multiple authorities and synthesizes a vault-relative note path separately. |
| `Epistemos/Vault/LiveNoteScanner.swift:163` | Live-note path synthesis | `subfolder/fileName` or fallback title | No | Note path is derived ad hoc from `filePath`, `subfolder`, and title. |
| `Epistemos/Vault/LiveNoteExecutor.swift:76` | Live-note edit target | `task.noteId` + `task.notePath` | No | Executor needs both SwiftData page ID and vault-relative path, showing the lack of a single resource identity. |
| `Epistemos/Vault/VaultChatMutator.swift:250` | Swift-side staged file mutation | Absolute `fileURL` + repo-relative path | No | Mutation pipeline prepares/commits diffs from file URLs, outside a shared resource abstraction. |
| `Epistemos/Vault/VaultChatMutator.swift:361` | Swift-side direct file mutation prep | `repositoryRootURL` + `fileURL` + relative path | No | File mutations are shaped directly as filesystem operations, not canonical resource writes. |
| `agent_core/src/storage/vault.rs:408` | Rust vault backend read/write/delete | Vault-relative path strings | No | Rust tools read/write/delete by raw path strings. |
| `agent_core/src/tools/note_tools.rs:31` | Rust note tools | `template`, `output_path`, `note_path` | No | Tool inputs talk directly in legacy vault paths and bypass any alias/capability layer. |

## Attachments And Context Semantics

| File:line | Resource type | ID format observed | Canonical? | Notes |
| --- | --- | --- | --- | --- |
| `Epistemos/State/ChatState.swift:1294` | Pending context attachments | Append/remove raw `ContextAttachment` values | No | Chat state stores attachments as plain values with no grant/capability semantics. |
| `Epistemos/App/ChatCoordinator.swift:3152` | Attached-note prompt expansion | Attached note bodies become inline prompt text | No | UI attachments are materialized into text context, not live runtime resources. |
| `Epistemos/App/ChatCoordinator.swift:3498` | Attached-note rendering | Markdown section with `Content:` body dump | No | Output format does not distinguish live vs snapshot attachment mode. |

## Permissions And Approval Storage

| File:line | Resource type | ID format observed | Canonical? | Notes |
| --- | --- | --- | --- | --- |
| `Epistemos/Vault/AgentApprovalPolicyStore.swift:49` | Swift persistent allow/block lists | Pattern strings in `.epistemos/approval_lists.json` | No | UI persists allow/block patterns, not resource-scoped capability grants. |
| `Epistemos/Vault/AgentApprovalPolicyStore.swift:165` | Swift approval list storage path | Vault-root-relative JSON file | No | Storage format is shared with Rust, but only for pattern allow/block lists. |
| `agent_core/src/approval.rs:285` | Rust persistent allow/block lists | Pattern strings in `.epistemos/approval_lists.json` | No | Duplicate persistence layer mirrors the Swift file format. |
| `agent_core/src/approval.rs:327` | Rust session approvals | In-memory `approved_this_session` / `denied_this_session` sets | No | Session approvals are ephemeral and not modeled as grants over resources/capabilities. |
| `agent_core/src/agent_loop.rs:744` | Tool approval decision key | `approval_key(name,input_json)` | No | Approval is bound to tool/input JSON, not a canonical resource selector or capability set. |
| `agent_core/src/bridge.rs:83` | Swift/Rust approval bridge | Permission callback with tool name, input JSON, risk level | No | Bridge exposes per-call approval prompts only. |
| `Epistemos/Views/Settings/AgentControlSettingsView.swift:77` | Settings approval UI | Counts, allowlist, blocklist, recent decisions | No | UI shows pattern lists and decision history, not active grants by resource/capability. |

## Write Verification And Auditability

| File:line | Resource type | ID format observed | Canonical? | Notes |
| --- | --- | --- | --- | --- |
| `agent_core/src/agent_loop.rs:857` | Tool success surfacing | `ToolResult::text(..., false)` on tool return | No | Success trace/result is emitted immediately after tool execution; no verified-readback stage exists here. |
| `Epistemos/Vault/VaultChatMutator.swift:411` | Swift file commit path | `diff.after.write(...)` + git add/commit | No | Mutation commits directly to disk/git without post-write checksum verification or audit-row creation. |
| `Epistemos/Views/Notes/ModelVaultBrowserSheet.swift:103` | Model-vault direct text read | Absolute file URL | No | Browser helper reads raw text files directly. |
| `Epistemos/Views/Notes/ModelVaultBrowserSheet.swift:113` | Model-vault direct text write | Absolute file URL | No | Browser helper writes files directly, outside any verified write pipeline. |
| `Epistemos/Views/Notes/ModelVaultBrowserSheet.swift:157` | Model-vault direct delete | Absolute file URL | No | Browser helper deletes items directly with `FileManager.removeItem`. |

## UI Picker / Disclosure State Surfaces

| File:line | Resource type | ID format observed | Canonical? | Notes |
| --- | --- | --- | --- | --- |
| `Epistemos/App/RootView.swift:701` | Model picker shell | `AnchoredPopoverButton` custom popover | No | Picker shell is still custom rather than the native compact `.popover(...).contentSize(...)` target in the plan. |
| `Epistemos/App/RootView.swift:1219` | Local model tree state | Real `DisclosureGroup` | Partial | Local-model picker group is already a real disclosure section. |
| `Epistemos/App/RootView.swift:1490` | Cloud provider/model tree state | Real `DisclosureGroup` | Partial | Cloud picker sections already disclose correctly, but the surrounding picker remains custom. |
| `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift:27` | Sidebar model-vault group | Real `DisclosureGroup` | Partial | Sidebar top-level model-vault section is already collapsible. |
| `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift:301` | Sidebar contribution group | Real `DisclosureGroup` | Partial | Nested contribution history is already inline disclosure, not a modal sheet. |
| `Epistemos/Views/Notes/NotesSidebar.swift:676` | Sidebar mounting point | Inline sidebar section | Partial | Notes sidebar now mounts model vaults inline, which partially mitigates `I-013`, but file operations still bypass the future resource runtime. |

## Summary Of Drift Relative To The Register

- `I-001` is real, but the current workaround is local to `ModelVaultsSidebarSection` and does not protect other write/read surfaces.
- `I-002` and `I-003` are confirmed: note lookup and mutation currently split across Swift chat helpers, Swift live-note helpers, Swift vault mutators, and Rust vault tools.
- `I-004` through `I-006` are confirmed: attachments only carry presentation metadata and are turned into prompt text, not live capability-bearing resources.
- `I-009` and `I-010` are confirmed at the architecture level: approvals exist as allow/block patterns and per-call JSON-based decisions, not stored resource grants.
- `I-007` and `I-008` are confirmed: successful tool/file results are surfaced without a shared verified-readback pipeline.
- `I-011` through `I-013` remain valid, but the current app already contains partial `DisclosureGroup` migration work that later steps should preserve rather than re-do.
