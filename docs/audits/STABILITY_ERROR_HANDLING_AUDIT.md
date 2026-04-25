# Stability + Error Handling Audit

Date: 2026-04-25
Severity: BLOCKER / HIGH / MEDIUM / LOW / DEFER. Confidence noted per finding.

## Risk table

| Risk | File | Failure mode | User-facing behavior today | Required behavior | Priority |
|---|---|---|---|---|---|
| Force unwrap / `try!` / `as!` | (none found) | n/a | n/a | n/a | DEFER |
| `Int(Float)` traps on NaN/Infinity | guarded sites: `CodeEditorView.swift:2662+3059` use `.isFinite` check | n/a | n/a | none | DEFER |
| `try?` on critical write paths | NoteFileStorage clean; VaultSyncService clean | n/a | n/a | none | DEFER |
| `try?` on AppBootstrap directory create | `AppBootstrap.swift:975` (`createDirectory`) | non-critical: store falls back to default | acceptable today | none | DEFER |
| `try?` on snapshot persistence | `ChatState.swift:484` (`data.write(.atomic)`) | non-critical: cache snapshot | acceptable | none | DEFER |
| `Vec::from_raw_parts` allocator mismatch (ISSUE-2026-04-04-001) | `graph-engine/src/lib.rs:2001+2327` | crash on hide/resign-active | FIXED via `into_boxed_slice` + `Box::from_raw` per AGENT_PROGRESS 2026-04-15 | verify no regression | DEFER (regression-tested) |
| `unsafe { std::slice::from_raw_parts }` in agent_core | `agent_core/src/shared_memory.rs` | read-only slice from owned buffer; lifetime bounded by struct | safe pattern | none | DEFER |
| `DispatchQueue.main.sync` (deadlock pattern banned by CLAUDE.md) | grep returns 0 matches | n/a | n/a | none | DEFER (clean) |
| HermesSubprocessManager Swift-side health check | not yet wired (Phase Omega-2) | subprocess hang masked by stdin-writeable status | per AGENT_PROGRESS 2026-04-02: PTY layer is solid; Swift bridge deferred | future work, non-blocking | DEFER |
| omega-mcp/src/pty.rs orphan cleanup + SIGTERM→SIGKILL | `:265+428+522+680` | tested 8 cases; `__EPPWD__` marker fixed | none | none | DEFER |
| HologramOverlay hide → bounded teardown 10s, MainActor.assumeIsolated | `HologramOverlay.swift:532-560` | clean lifecycle | none | none | DEFER |
| NotificationCenter observers — 42 add/remove pairs balanced | scattered | clean | none | none | DEFER |
| `nonisolated(unsafe)` on NSView properties — 20 uses, all `// SAFETY:` commented | scattered | safe pattern | none | none | DEFER |
| Permission injection (note content can grant capability) | `agent_core/src/permissions.rs` reads only stored grants, never note content | n/a | none — secured | none | DEFER |
| Verified-write contract (I-007/I-008) | `agent_core/src/runtime.rs verified_write` + Swift E2E test | "AI lies about writes" — FIXED | none | none | DEFER |
| Bookmark startup validation (S.4) | `VaultSyncService.swift:25-29` + tests at `VaultSyncServiceAuditTests.swift:198-273` | stale bookmark rejected; clean restore on valid | none | none | DEFER |
| App init logs swallowing failures (per AGENT_PROGRESS 2026-04-02) | `AppBootstrap.swift` startup integrity, welcome-back, Instant Recall snapshot, model-profile save — all log on failure | improved error visibility | none | none | DEFER |
| Empty states / first-run guidance | partial | some empty states are bare | add concise one-line hints | LOW (P2) | manual UI review |
| Provider error UI (401/429/content-policy) | typed error enum + classify() landed (per Master Plan Q + W) | shows recovery buttons | confirm coverage for Anthropic/Google paths | LOW (P2) | provider-specific tests |
| Permissions failure visible feedback | `AgentControlSettingsView.activeGrantsSection` shows revoke; permission_denied path returns `ToolError::PermissionDenied` | shown in chat as failed tool result | confirm clear copy on denial | LOW (P2) | manual: revoke grant → retry → see clear message |
| Offline / cloud provider failure | typed error path landed | recovery buttons | confirm "Switch to local" recovery on outage | LOW (P2) | unplug network → invoke cloud → recovery shown |

## Crash classes

All known critical crash classes are CLOSED per `KNOWN_ISSUES_REGISTER.md` (15/18 fixed; 3 design partials):

- I-007/I-008 verified_write contract — FIXED.
- I-009 permission gate fail-closed default — FIXED.
- I-010 prompt injection — FIXED at design level.
- I-019 macOS 26 global event monitor — code site no longer exists; tracked closed.
- ISSUE-2026-04-04-001 Vec drop malloc — FIXED 2026-04-15.
- ISSUE-2026-04-06-001 Pinned inspector freeze — FIXED via `force_alive` flag.

## Top 3 stability gaps

1. **HermesSubprocessManager Swift-side health check** — not blocking V1 because PTY layer is robust standalone. Schedule for Phase Omega-2.
2. **Empty-state polish** — bare states harm first-run UX. P2 polish pass.
3. **Provider error recovery** — typed-error landed, but verify coverage for all four providers (Anthropic, OpenAI, Perplexity, Google).

## Verdict

Stability is shippable. Phase R closure was real. Test coverage is strong. The gap is polish (empty states, error copy) plus the Hermes Swift bridge (deferred). No P0 stability blocker.

Confidence: HIGH on closed items (parallel-agent audit verified directly).
