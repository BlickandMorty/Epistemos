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
| Properly Pro-gated top-level module | 1 | `tirith` (`#[cfg(feature = "pro-build")] pub mod tirith;`) |
| Properly Pro-gated impl | 1 | `BashExecuteHandler` in `tools/registry.rs:2410` (gated at impl level with `#[cfg(feature = "pro-build")]`) |
| Library helpers (always compile, only callable from Pro paths) | 1 | `security.rs::harden_cli_subprocess*` (Pro-only callers; security helpers themselves are pure functions) |
| Test-only spawns | 5 | All `Command::new` sites inside `#[cfg(test)]` blocks (`security.rs:1131,1153`, `terminal.rs:741`, etc.) |
| Build artifact | 0 | `tirith.rs:268` resolved by Pro-gating the top-level module + approval caller |
| **Orphan source files (do not compile, do not ship)** | **0** | Codex continuation resolved all three originally identified orphan files |
| Swift process/Pipe surfaces | 10 files | Re-audited by Codex continuation; all direct `Process` / `Pipe` surfaces are `#if !EPISTEMOS_APP_STORE` Pro/Harness/Research paths or already named MoLoRA/QLoRA Python debt. No deletion: these are scaffold or Pro-only runtime surfaces, not proven-dead orphan files. |

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

## Swift Process / Pipe surface (preserve, do not delete)

Codex continuation widened the grep from Rust `Command::new` to Swift
`Process.init()` / `Pipe()` sites across `Epistemos/`. The result is
clean for MAS separation but important for scaffold preservation:

| Surface | Classification |
|---|---|
| `Epistemos/Harness/CompletionChecker.swift` | Whole file is `#if !EPISTEMOS_APP_STORE`; Pro/Research harness only. |
| `Epistemos/Harness/EvalSandbox.swift` | Whole file is `#if !EPISTEMOS_APP_STORE`; Pro/Research sandbox runner only. |
| `Epistemos/Harness/HarnessLab.swift` | Whole file is `#if !EPISTEMOS_APP_STORE`; Pro/Research evaluation lab only. |
| `Epistemos/Vault/VaultChatMutator.swift` | Git subprocess path is `#if !EPISTEMOS_APP_STORE`; Pro-only vault git helper. |
| `Epistemos/Sync/VaultSyncService.swift` | `tmutil` helper is `#if !EPISTEMOS_APP_STORE`; MAS path returns before reaching it. |
| `Epistemos/KnowledgeFusion/Alignment/KTOTrainer.swift` | Python trainer path is `#if !EPISTEMOS_APP_STORE`; research/training scaffold. |
| `Epistemos/KnowledgeFusion/MoLoRA/MoLoRAInferenceService.swift` | Python subprocess path is `#if !EPISTEMOS_APP_STORE`; named doctrine debt to port, not dead code. |
| `Epistemos/KnowledgeFusion/Training/QLoRATrainer.swift` | Python subprocess path is `#if !EPISTEMOS_APP_STORE`; named doctrine debt to port, not dead code. |
| `Epistemos/KnowledgeFusion/PythonEnvironmentManager.swift` | Python environment setup is `#if !EPISTEMOS_APP_STORE`; should be deleted only after W7-H/W7-I ports land. |
| `Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift` | Whisper/MLX process helpers are `#if !EPISTEMOS_APP_STORE`; Pro/research ingestion surface. |

This pass deliberately **does not delete** MoLoRA, QLoRA, Python
environment, or harness files. The final doctrine names MoLoRA/QLoRA
as structural subprocess debt, but also says to remove cleanup
scaffolds only after the ports land. That makes these files intended
scaffold or Pro/Research surface today, not dead past code.

## Resolved verification items

### `tirith.rs:268`

```rust
let mut cmd = tokio::process::Command::new(binary);
```

Codex continuation resolution: `tirith.rs` is now declared as a
Pro-only top-level module:

```rust
#[cfg(feature = "pro-build")]
pub mod tirith;
```

The `approval.rs` caller is also inside `#[cfg(feature =
"pro-build")]`, so MAS/default builds keep pattern-based approval but
do not compile the dormant Tirith subprocess scanner surface.

The original trace showed the spawn was reachable from `approval.rs`
and gated behind `resolve_binary().await` returning `Some(binary)` at
`tirith.rs:129-131`:

```rust
let Some(binary) = self.resolve_binary().await else {
    return self.fallback_result("Tirith binary not available");
};
```

Under MAS sandbox this was already a no-op in practice. Pro-gating
makes that boundary compile-time instead of runtime-only, loses zero
MAS capability, and reduces App Review surface.

**Status:** Resolved. Default/MAS clippy passed, Pro+lsp clippy passed,
default lib tests passed 871/871, and Pro+lsp lib tests passed 1014/1014.

## Orphan source files (action required)

Codex continuation status: all three originally identified orphan
files have been resolved. Two were removed after a reachability +
replacement audit. The third was promoted from scaffold to compiled,
registered, capability-gated code.

| File | LOC | Last touched | What it implements |
|---|---|---|---|
| `note_tools.rs` | 523 | `5463759d` (Phase 7) | PKM-specific note manipulation tools — now declared as `tools::note_tools` and registered through `register_phase_two_note_tools()` |

**Total remaining:** 0 LOC of orphan source.

**Removed by Codex continuation pass:** `code_execution.rs` and
`graph_query.rs`. `code_execution.rs` was an unregistered local
subprocess runner, conflicting with the current no-hot-path-subprocess
doctrine and overlapping with server-side provider code-execution
paths / Pro CLI passthrough surfaces. `graph_query.rs` was superseded
by the wired `tools/graph.rs` implementation, which registers
`graph_query` through `register_phase_two_graph()`.

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

**Updated finding:** `note_tools.rs` was not in the same class as the
two removed files. It contained unique PKM/note affordances
(`note_template`, `note_linker`, `research_digest`,
`citation_extractor`, `markdown_table`), so Codex preserved and wired
it instead of deleting intended scaffold. `note_template.output_path`
now maps to the R.5 vault-note write authorization target, so template
writes do not bypass Sovereign Gate policy.

**Verification:** `cargo clippy --manifest-path agent_core/Cargo.toml
--target aarch64-apple-darwin -- -D warnings` passed, and
`cargo test --manifest-path agent_core/Cargo.toml --lib` passed
882/882 after the promotion.

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
  module gating CLEAN**. `tirith.rs` is Pro-only at compile time.
  Orphan source files resolved: two deleted, one promoted into the
  compiled registry with R.5 gating.

## Cross-refs

- `docs/CANONICAL_UPGRADE_AUDIT_2026_05_05.md` §B5 (the audit ask)
- `docs/CODEX_CANONICAL_DRIFT_AUDIT_2026_05_05.md` CD-007 (Codex's
  matching observation: "PARTIAL ALIGNMENT. Run a full source guard
  over every Command::new, Process, and Pipe surface before signing
  MAS canon.")
- `agent_core/src/lib.rs:96-148` — the canonical Pro-gating block
- `agent_core/src/tools/registry.rs:43-79` — `MAS_RUNTIME_FORBIDDEN_TOOLS`
  defense-in-depth list
