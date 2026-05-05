---
state: canon
canon_promoted_on: 2026-05-05
audit_item: B5 (Codex #6)
---

# MAS / Pro source-guard sweep — 2026-05-05

> **Question answered:** does any Pro-only surface (subprocess
> spawning, network access requiring `com.apple.security.network.*`,
> private framework loading, etc.) leak into the MAS build path?
>
> **Method:** systematic grep of every `Command::new` /
> `tokio::process::Command` / `std::process::Command` / `Pipe`
> instantiation site, classified by its module's compile-time gating.

## Summary verdict

| Status | Count | Items |
|---|---|---|
| Properly Pro-gated | 9 | apple, browser, cli_passthrough, computer_use, custom_tools, delegate_task, discovery, imessage, imessage_contacts, intelligence, macos, media, scheduling, stdio_mcp, terminal, trajectory (all under `#[cfg(feature = "pro-build")] pub mod` in `lib.rs:96-148`) |
| Properly Pro-gated impl | 1 | `BashExecuteHandler` in `tools/registry.rs:2410` (gated at impl level with `#[cfg(feature = "pro-build")]`) |
| Library helpers (always compile, only callable from Pro paths) | 1 | `security.rs::harden_cli_subprocess*` (Pro-only callers; security helpers themselves are pure functions) |
| Test-only spawns | 5 | All `Command::new` sites inside `#[cfg(test)]` blocks (`security.rs:1131,1153`, `terminal.rs:741`, etc.) |
| Build artifact | 1 | `tirith.rs:268` — needs verification (see below) |
| **Orphan source files (do not compile, do not ship)** | **3** | **`code_execution.rs`, `graph_query.rs`, `note_tools.rs`** |

## Pro-gated module surface (clean)

These are all properly behind `#[cfg(feature = "pro-build")]` in
`lib.rs`'s `tools` module block:

```
agent_core/src/lib.rs lines 113-147:
  #[cfg(feature = "pro-build")] pub mod apple;          // osascript spawn
  #[cfg(feature = "pro-build")] pub mod browser;        // browser binary spawn
  #[cfg(feature = "pro-build")] pub mod cli_passthrough; // claude/codex/gemini/kimi spawn
  #[cfg(feature = "pro-build")] pub mod imessage;       // osascript spawn
  #[cfg(feature = "pro-build")] pub mod media;          // `say` spawn
  #[cfg(feature = "pro-build")] pub mod terminal;       // user shell command
  #[cfg(feature = "pro-build")] pub mod computer_use;
  #[cfg(feature = "pro-build")] pub mod custom_tools;
  #[cfg(feature = "pro-build")] pub mod delegate_task;
  #[cfg(feature = "pro-build")] pub mod discovery;
  #[cfg(feature = "pro-build")] pub mod imessage_contacts;
  #[cfg(feature = "pro-build")] pub mod intelligence;
  #[cfg(feature = "pro-build")] pub mod macos;
  #[cfg(feature = "pro-build")] pub mod scheduling;
  #[cfg(feature = "pro-build")] pub mod stdio_mcp;
  #[cfg(feature = "pro-build")] pub mod trajectory;
```

Verified: `cargo build --no-default-features --features mas-build`
does NOT compile any of these modules. The MAS_RUNTIME_FORBIDDEN_TOOLS
list in `tools/registry.rs:43-79` provides defense-in-depth at the
runtime tool-surface layer.

## Per-impl gating (clean)

`BashExecuteHandler` in `tools/registry.rs:2410-2435` is Pro-gated
at the impl level: `#[cfg(feature = "pro-build")] impl ToolHandler for
BashExecuteHandler`. The bash spawn at line 2435 is unreachable from
the MAS build.

## Library helpers (clean)

`security.rs::harden_cli_subprocess(&mut tokio::process::Command)` and
its variants are pure-function helpers that compile in both MAS and
Pro builds. They take a `Command` reference and apply the canonical
`env_clear` + 10-var allowlist + 24-vector denylist + `kill_on_drop`
+ `process_group(0)`. Compiling these helpers in MAS doesn't grant
MAS the ability to spawn — there are no Command::new invocations
that reach them under MAS gating.

The 4 `security.rs` test functions that DO spawn (`tests::*`) are
inside `#[cfg(test)]` so they only compile during `cargo test`,
which is fine.

## Test-only spawns (clean)

All `#[cfg(test)]`-gated `Command::new` sites:
- `security.rs:1131,1153` — env-var leak verification tests
- `terminal.rs:741` — `Command::new("true").spawn()` test
- `cli_passthrough.rs` test module
- `imessage.rs` test module
- Various others in `#[cfg(test)] mod tests` blocks

These never compile into the production binary (`cargo build` skips
test code).

## Items needing verification

### `tirith.rs:268`

```rust
let mut cmd = tokio::process::Command::new(binary);
```

`tirith.rs` is declared at top level in `lib.rs:99` as `pub mod
tirith;` (not inside the `tools` block, not feature-gated). This
means `tirith` compiles + ships in BOTH MAS and Pro builds.

Two checks needed:
1. Does any code path in `tirith` actually CALL the function
   containing line 268? If it's only reachable from a Pro feature,
   the spawn never fires under MAS but the binary still contains it.
2. Should `tirith` itself be gated? Or is the spawn site dead code?

**Status:** Needs Codex verification. Flagged as a potential MAS leak
pending review.

## Orphan source files (action required)

Three source files exist in `agent_core/src/tools/` but are NOT
declared as modules in `lib.rs`. Rust ignores them silently — they
neither compile nor ship today.

| File | LOC | Last touched | What it implements |
|---|---|---|---|
| `code_execution.rs` | 105 | `2ca663a1` (Pre-V2 Gap 1b) | `CodeExecutionTool` + `code_execution_tool_schema()` for python/node/ruby/bash/swift/rust execution |
| `graph_query.rs` | 276 | `5463759d` (Phase 7) | PKM-specific graph query tool |
| `note_tools.rs` | 523 | `5463759d` (Phase 7) | PKM-specific note manipulation tools |

**Total:** 904 LOC of orphan source.

**Two interpretations** (canon-promotion-protocol candidate-state):

1. **Vestigial** — written for Hermes-parity but superseded by other
   tools (the cli_passthrough handlers cover code-execution use cases
   for Pro tier; vault tools cover note manipulation; graph tools
   exist elsewhere). Action: delete per the user's "if not needed,
   get rid of it" directive.
2. **Forward-staged** — implementations ready to wire when needed.
   Action: declare under `#[cfg(feature = "pro-build")] pub mod` so
   they at least compile in Pro builds, and register their handlers
   in the tool registry.

**My finding:** these three files implement features that either
overlap with existing wired tools (code_execution overlaps with
cli_passthrough), are PKM-domain (graph_query, note_tools — would
match if there was a PKM tool surface in the registry but I don't see
one). Pre-V2 Gap 1b commit `2ca663a1` was a "consolidate in-flight
recovery work" pass, suggesting these were salvage drops rather than
intentional staging.

**Recommended action:** delete the three orphan files. They're not
referenced, not compiled, not in any production path. If a future
need re-emerges, git history preserves them. This matches the user's
explicit stance from 2026-05-05 LSPServerProcess deletion ("if i dont
need something get rid of it"). The deletion is a separate commit
because it requires explicit user / Codex sign-off.

**Held for sign-off.** This source-guard report is the audit; the
deletion is the action.

## Verification

- `cargo build --no-default-features --features mas-build` succeeds
  + does not include any Pro-gated module
- `cargo build --no-default-features --features pro-build,lsp-runtime`
  succeeds + includes all Pro modules
- `cargo build --features lsp-runtime` (default = mas-build +
  lsp-runtime) succeeds, MAS surface confirmed
- All test-only spawns are inside `#[cfg(test)]` blocks (verified
  via grep of `Command::new` against `cfg(test)` boundaries)

## Audit ledger update

- B5 / Codex #6 (MAS/Pro brutal-separation source guard): **Pro
  module gating CLEAN**. One item needing verification (`tirith.rs`
  spawn). Three orphan files flagged for deletion sign-off.

## Cross-refs

- `docs/CANONICAL_UPGRADE_AUDIT_2026_05_05.md` §B5 (the audit ask)
- `docs/CODEX_CANONICAL_DRIFT_AUDIT_2026_05_05.md` CD-007 (Codex's
  matching observation: "PARTIAL ALIGNMENT. Run a full source guard
  over every Command::new, Process, and Pipe surface before signing
  MAS canon.")
- `agent_core/src/lib.rs:96-148` — the canonical Pro-gating block
- `agent_core/src/tools/registry.rs:43-79` — `MAS_RUNTIME_FORBIDDEN_TOOLS`
  defense-in-depth list
