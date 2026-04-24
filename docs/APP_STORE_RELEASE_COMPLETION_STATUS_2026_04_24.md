# App Store Release Completion Status — 2026-04-24

This is the handoff tracker for the **non-Pro / App Store lane**. It exists so the App Store work can finish cleanly first, while Pro development can continue later without rediscovering what is shared, what is gated, and what is still intentionally deferred.

## Governing Rule

App Store work means **bounded execution only**:

- Keep: chat, bounded agent behavior, local MLX, Apple Intelligence, user-key cloud providers, vault/search/note tools, schema-safe UI, resource grants, verified writes, App Store-safe settings.
- Exclude or compile out: shell/Bash, Docker, external CLI spawning, stdio MCP, iMessage channel, long-horizon background agents, dynamic plugin/script execution, Pro-only computer-use stack.
- Shared code must stay profile-gated, not forked. Pro should inherit hardening without App Store constraints leaking into Pro-only capability.

## Latest Landed App Store Hardening

Recent release-hardening commits on `codex/runtime-input-audit`:

| Commit | Scope |
|---|---|
| `e87fbb6d` | Hide/gate Pro settings from App Store profile. |
| `5be4067a` | Scrub executable runtime script assets from App Store bundle. |
| `f763fbce` | Stub native computer-use stack in App Store build. |
| `c8d6f632` | Skip Pro runtime startup in App Store build. |
| `0ab57d80` | Compile `agent_core` with `mas-sandbox` for App Store. |
| `133aaff7` | Fix relay SQLite params macro. |
| `13978496` | Repair release-test regressions after App Store gating. |
| `35dd0e68` | Harden vault import rollback and async body-read fallback. |
| `48fed7d7` | Strip Pro tool code from App Store `agent_core`. |
| `5785cef0` | Ensure App Store launch window surfaces. |
| `d6f5de5b` | Polish App Store launch/composer affordances. |
| `caa3fdbf` | Harden App Store chat startup and runtime readiness. |

## Verified Baseline From This Pass

Automated checks already run after the current hardening series:

- Full Swift suite: **4,264 tests / 486 suites passed**.
- `graph-engine`: **2,458/2,458 passed**, 8 ignored benchmark tests.
- `omega-mcp`: **126/126 passed**.
- `omega-ax`: **12/12 passed**.
- `agent_core` default: **630 lib + 2 relay + 5 worker + doctests passed**.
- `agent_core --features mas-sandbox`: **499 lib + 2 relay + 5 worker + doctests passed**.
- Focused release/routing slice: **182 tests passed**.
- App Store Release build: `Epistemos-AppStore` + `Release` + `CODE_SIGNING_ALLOWED=NO` **BUILD SUCCEEDED**.

Manual Computer Use smoke on the real App Store Release bundle:

- App launched a visible window.
- Composer showed `Read + Search vault`.
- Shell/Pro affordances were not visible.
- Plain local chat accepted `ping` and returned `pong`.
- The previous restricted-tools policy warning did **not** appear.

## Phase R / Foundation Status

| Area | Status | Notes |
|---|---|---|
| R.2 canonical IDs | Mostly fixed | Sidebar/read-side model aliases route through Rust alias registry. Write-edge canonicalization remains deferred by convention. |
| R.3 read gateway | Partial | Background/indexing/context read paths migrated to gateway-first async cascade. Legacy sync save/edit paths remain intentionally outside that slice. |
| R.4 live vs snapshot attachments | Partial | Note mentions, file helper, and paste helper now carry explicit manifests. Tool-dispatch write gate still needs end-to-end wiring. |
| R.5 permission grants | Fixed for ResourceId-gated tools | Default-on, fail-closed enforcement; grants persist on disk; note content is not authority. |
| R.6 verified writes | Partial | Rust registry `write_file`, `patch`, `vault_write` verify readback; FFI bridge exists. Swift-originated write paths still need migration or explicit separation as user-editor writes. |
| R.7 grant visibility | Partial | Composer chip and Settings active-grants/revoke surface exist. Manual revoke/in-flight failure smoke still needed. |
| R.8 picker/collapse | Fixed for scoped surfaces | Model picker is compact popover-sized; model picker and model-vault tree use real `DisclosureGroup`; model vault browser is inline rather than a modal browser sheet. |
| R.9 regression suite | Partial | Phase R suites exist and are green in focused runs. Need the final eight split-brain tests plus full-suite closure after remaining R.4/R.6 wiring. |

## App Store-Compatible Work Still To Finish

These are **non-Pro** and should be completed before claiming App Store readiness:

1. **Attachment write-dispatch gate**  
   Wire attachment manifests into the write/delete/create tool-dispatch boundary. Snapshot attachments must deny writes; live note/file attachments must route through the canonical resource/permission path. Add an end-to-end test: attach note/file → model write attempt → disk changes only when live + granted + verified.

2. **Swift-originated verified writes**  
   Migrate AI/tool-originated Swift write paths to `resourceVerifiedWrite` or an equivalent readback-verifying wrapper. Keep ordinary user editor saves separate so normal typing is not blocked by agent permission grants. Remaining high-risk paths include `LiveNoteExecutor`, `AppCoordinator`, `CodeEditorView`, `ModelVaultBrowserStore`, `JournalIntents`, and sync/import flows.

3. **Grant UI manual smoke**  
   Verify Settings active grants list/revoke on a real running App Store build. Confirm revoking a grant causes a matching in-flight or next tool call to fail with a clear denied state.

4. **App Store release audit closure**  
   Run the release-audit skill to completion: full automated checks, logs, manual runtime checks, entitlement/privacy review, and repeated zero-fail validation. Do not mark ready until the recursive release-audit bar is met.

5. **App Store metadata and compliance**  
   Confirm entitlements, privacy manifest, App Privacy answers, privacy policy/support URLs, review notes, screenshots, TestFlight setup, export-compliance answers, and sandbox file-access language.

6. **Manual workflow matrix**  
   Dogfood at least: first launch, no-model setup path, local chat, cloud-key missing path, model install/detection, note read/search, note AI accept/discard, attachment grant, file attachment, export/history, vault import rollback, settings privacy/permissions, accessibility basics, quit/reopen.

## Pro Continuation Handoff

Do **not** start these until the App Store lane is accepted or the user explicitly branches Pro work:

- Phase D+ Power Mode CLI subprocess activation.
- Phase H Docker sandbox.
- Phase K iMessage channel.
- Phase G+ full CLI config compiler for `.claude`, `.codex`, `.gemini`.
- Pro tools: Bash, MultiEdit, WebFetch, long-horizon background agents, broad stdio MCP.

When Pro starts, use the App Store hardening as the shared base. The Pro work should add capabilities behind `PolicyProfile`/build-profile gates, not duplicate the runtime.

