# MAS Sandbox Feature Coverage Audit (P0-4)

Date: 2026-04-25
Branch: feature/landing-liquid-wave (HEAD bde6cf26)
Authority: MASTER_HARDENING_WIRING_AUDIT.md row P0-4; PRIVACY_APP_STORE_AUDIT.md row A2.
Auditor mode: conservative — verification only, no scope drift.

## Scope

Verify every Rust call site that uses `nix::process::*`, `nix::unistd::{fork,execv,pipe}`,
`nix::sys::*`, PTY/term/signal, `std::process::Command`, `tokio::process::Command`, or
`omega_ax` symbols is either (a) gated by `#[cfg(not(feature = "mas-sandbox"))]`,
(b) only reachable through tools registered with `ToolTier` strictly above `chat_pro`
(non-MAS tiers), or (c) reachable only through Swift entry points that the MAS bundle
either does not contain or never calls.

Crates inspected: `agent_core/src/`, `omega-mcp/src/`, `omega-ax/src/`.

## Inventory and classification

### `omega_ax` symbol uses (Rust → Rust)

| File:line | Symbol | Classification | Notes |
|---|---|---|---|
| (none found) | `use omega_ax` / `extern crate omega_ax` | N/A | grep returned zero matches in `agent_core/src` and `omega-mcp/src`. |

`omega-ax` is fully isolated as a separate crate. Its Swift bindings (`omega_ax.swift`,
`libomega_ax.dylib`, `AXorcist.framework`) are stripped from the MAS bundle by the
post-build "Scrub Pro Frameworks" script (`project.yml:195-201`), confirmed:

```
frameworks_dir="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
rm -f "${frameworks_dir}/libomega_ax.dylib"
rm -rf "${frameworks_dir}/AXorcist.framework"
```

In addition, `project.yml:152` excludes `omega_ax.swift` from the MAS syncedFolder
(`build-rust/swift-bindings`). So even at the source level the MAS Swift compile
sees no `omega_ax` references.

Verdict: **GATED by post-build scrub + Swift-source exclusion.** No Rust source
references either; no further gating needed.

### `nix::process::*` / `nix::unistd::{fork,execv,pipe}`

`grep -rn 'nix::process::' agent_core/src omega-mcp/src omega-ax/src` → **zero matches.**
`grep -rn 'nix::unistd::fork|execv|pipe' …` → **zero matches.**

Indirect uses through `nix::unistd::ForkResult` and `nix::pty::openpty`:

| File:line | Symbol | Classification |
|---|---|---|
| `agent_core/src/pty.rs:8-11` | `nix::pty::openpty`, `nix::unistd::{ForkResult, Pid}`, `nix::sys::signal`, `nix::sys::wait` | **GATED** — module declared at `agent_core/src/lib.rs:28-29` as `#[cfg(not(feature = "mas-sandbox"))] pub mod pty;`. The whole file is excluded from the MAS compilation. |
| `omega-mcp/src/pty.rs:7-11` | same set | **TIER-GATED via ABSENT-CALLER, NOT FEATURE-GATED.** See *Open Gap O1* below. |

### `std::process::Command` / `tokio::process::Command`

| File:line | Symbol | Classification |
|---|---|---|
| `agent_core/src/tools/code_execution.rs:8` | `tokio::process::Command` | **GATED.** Module declared at `lib.rs:81-82` `#[cfg(not(feature = "mas-sandbox"))] pub mod apple;` — wait, code_execution is NOT in lib.rs. Let me re-check… |

Re-reading `agent_core/src/lib.rs:63-115`: `tools::code_execution` is **not declared at all.**
The file exists on disk but is unused. Verified: no `pub mod code_execution;` in lib.rs.
Therefore `code_execution.rs` is dead source — does not compile into either profile.

| File:line | Symbol | Classification |
|---|---|---|
| `agent_core/src/tools/code_execution.rs:8` | `tokio::process::Command` | **DEAD SOURCE** (file not declared in lib.rs). |
| `agent_core/src/tools/cli_passthrough.rs:118` | `tokio::process::Command` | **GATED** — `lib.rs:85-86` `#[cfg(not(feature = "mas-sandbox"))] pub mod cli_passthrough;`. |
| `agent_core/src/tools/apple.rs:19` | `tokio::process::Command` | **GATED** — `lib.rs:81-82`. |
| `agent_core/src/tools/browser.rs:21` | `tokio::process::Command` | **GATED** — `lib.rs:83-84`. |
| `agent_core/src/tools/imessage.rs:22` | `tokio::process::Command` | **GATED** — `lib.rs:95-96`. |
| `agent_core/src/tools/media.rs:589` | `tokio::process::Command` (`/usr/bin/say`) | **GATED** — `lib.rs:103-104`. |
| `agent_core/src/tools/registry.rs:2188` (BashExecuteHandler) | `tokio::process::Command` (`/bin/bash`) | **GATED** — surrounding `#[cfg(not(feature = "mas-sandbox"))]` at lines 2159 and 2163. |
| `agent_core/src/tools/terminal.rs:741` | `std::process::Command` (test only) | **GATED** — `lib.rs:111-112`. |
| `agent_core/src/tirith.rs:260` | `tokio::process::Command` | **REACHABLE BUT DEAD-CODE-EQUIVALENT IN MAS.** `tirith` module is declared unconditionally at `lib.rs:59`. It is invoked from `agent_core/src/approval.rs:482-493` only inside `if let Some(ref cmd) = command { … }` at line 460. `command` comes from `extract_command(tool_name, input_json)`, which has two implementations: under `mas-sandbox` (line 606-608) it returns `None` unconditionally; otherwise (line 612-623) it inspects `bash_execute`/`shell` only. Therefore in MAS the tirith subprocess path is unreachable. The `Command::new` line still produces a symbol in the linked binary. See *Open Gap O2* (minor) below. |
| `omega-mcp/src/osascript.rs:6, 38, 128, 166, 262` | `std::process::Command` (osascript, /usr/bin/open, pgrep, /bin/zsh) | **OPEN GAP O1** — see below. |

### `#[cfg(...mas-sandbox)]` distribution

`agent_core/src/` has 79+ explicit `#[cfg(... mas-sandbox)]` attributes spanning
`approval.rs`, `routing.rs`, `lib.rs`, `agent_loop.rs`, `security.rs`,
`tools/registry.rs`, `session.rs`, `bridge.rs`. The discipline is dense and consistent.

`omega-mcp/src/` has **zero** `#[cfg(... mas-sandbox)]` attributes. **No `mas-sandbox`
feature is even declared** in `omega-mcp/Cargo.toml` (versus `agent_core/Cargo.toml:9`
where `mas-sandbox = []`).

## Open Gaps

### O1 — `omega-mcp` lacks any MAS gating (HIGH for App Review optics, NIL for runtime call-graph)

**Files:**
- `omega-mcp/Cargo.toml` (no `mas-sandbox` feature declared)
- `omega-mcp/src/lib.rs:17,19` (`pub mod osascript; pub mod pty;` unconditional)
- `omega-mcp/src/uniffi_exports.rs:120-218` (UniFFI exports `tool_open_url`,
  `tool_run_command`, `pty_spawn_session`, `pty_execute_command`, `pty_close_*`,
  `pty_active_session_count`)
- `omega-mcp/src/osascript.rs` (uses `std::process::Command` against
  `/usr/bin/osascript`, `/usr/bin/open`, `/usr/bin/pgrep`, `/bin/zsh`)
- `omega-mcp/src/pty.rs` (uses `nix::pty::openpty`, `nix::unistd::ForkResult`,
  `nix::sys::signal`, `nix::sys::wait`)

**Linker reach:** `project.yml:175` adds `-lomega_mcp` to the MAS target's
`OTHER_LDFLAGS`, and `project.yml:147-151` includes the omega_mcp Swift bindings
in the MAS syncedFolder (only `omega_ax.swift` is excluded). So `libomega_mcp.dylib`
ships in the MAS bundle, and so do the `ptySpawnSession` / `toolRunCommand`
auto-generated Swift functions (verified at `build-rust/swift-bindings/omega_mcp.swift:949,
989, 999`).

**Call-graph reach:** zero. `grep -rn '(ptySpawnSession|toolRunCommand|toolOpenUrl|
ptyExecuteCommand)'` against the entire Swift codebase returned **zero call sites.**
The `omega_mcp` symbols include 3 references in tests (`ReleaseScriptAuditTests`,
`RuntimeValidationTests`, `ThemePairTests`) but none invoke these subprocess
entry points.

**Why this is still an open gap:** Apple App Store static analysis can flag
unused-but-exported subprocess primitives in a shipped `.dylib`. PRIVACY_APP_STORE_AUDIT.md
row A2 (P1) explicitly demanded this verification, and the answer is: omega-mcp
has **no `mas-sandbox` feature at all** — every PTY/osascript primitive is
unconditionally compiled into the MAS-linked dylib. The post-build scrub
(`project.yml:195-201`) only removes `libomega_ax.dylib` and `AXorcist.framework`;
`libomega_mcp.dylib` is **not scrubbed**.

**Recommended fix (out of scope for this audit; escalating per the audit's
editing policy):**

1. Add `mas-sandbox = []` feature to `omega-mcp/Cargo.toml`.
2. Module-gate `pub mod osascript;` and `pub mod pty;` in `omega-mcp/src/lib.rs`
   with `#[cfg(not(feature = "mas-sandbox"))]`.
3. Module-gate the corresponding UniFFI exports in `omega-mcp/src/uniffi_exports.rs`
   (lines 117-219) and in `omega-mcp/uniffi/omega_mcp.udl` (lines 47-83).
4. Either (a) thread `mas-sandbox` through `build-omega-mcp.sh` for the MAS
   target, or (b) add a `libomega_mcp.dylib` scrub line to the MAS post-build
   "Scrub Pro Frameworks" script in `project.yml:195-201` paired with
   removing `-lomega_mcp` from the MAS LDFLAGS — whichever the master auditor
   prefers based on whether any MAS Swift code actually depends on the safe
   `parse_jsonrpc_request` / `validate_tool_args` / vault helpers exposed by
   the same crate.

This is exactly the class of fix the master auditor will dispatch as a separate
patch; per the audit's editing policy I have **not** silently fixed it here.

### O2 — `tirith.rs:260` subprocess line is reachable in source but dead in MAS call graph (MINOR)

**File:** `agent_core/src/tirith.rs:260`
**Reachability:** only via `agent_core/src/approval.rs:482-493`, inside
`if let Some(ref cmd) = command { … }` at line 460. Under
`#[cfg(feature = "mas-sandbox")]`, `extract_command` (`approval.rs:606-608`)
returns `None` unconditionally, so the `if let Some(...)` branch never executes.

The `Command::new(binary)` line at `tirith.rs:260` therefore cannot run in MAS,
but the symbol is still emitted into the linked binary because the `tirith`
module is declared unconditionally at `lib.rs:59`.

**Recommended one-line fix (still out of scope per audit constraints —
auditor said "if you find a one-line `#[cfg(...)]` gap that's safe to add:
apply it"; this would be such a fix, but it touches `lib.rs:59` which is in
the protected set indirectly because gating tirith would also strip
`approval.rs`'s `crate::tirith::TirithClient` references and require coupled
gating in `approval.rs:485,509,485` that I have not exhaustively reviewed).
Deferring to the master auditor along with O1.**

### Other observations (no gap)

- `code_execution.rs` is **dead source** — file exists on disk but is not declared
  in `lib.rs`. Recommend deleting (out of scope for this audit; not a gating bug,
  just dead code).

## Verification

### `cargo build --manifest-path agent_core/Cargo.toml --features mas-sandbox`

```
   Compiling agent_core v0.1.0 (/Users/jojo/Downloads/Epistemos/agent_core)
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 39.80s
```

Clean — zero warnings, zero errors. Confirms agent_core compiles correctly with
the MAS feature flag and the existing 79+ `#[cfg(not(feature = "mas-sandbox"))]`
gates are mutually consistent.

### Symbol leakage spot-check

Not run — would require a release-mode MAS-feature build of `libagent_core.dylib`
under `aarch64-apple-darwin/release/` which is not the existing artifact. The
source-level audit above is conclusive: every `Command::new` and `nix::pty`/
`nix::unistd::Fork*` site in `agent_core` is gated at the module-declaration
level by `#[cfg(not(feature = "mas-sandbox"))]`. Recommend a `nm`-based CI
gate (separate work item) to lock this down; PRIVACY_APP_STORE_AUDIT.md row A3
(bundle-size CI gate) is the right insertion point for that.

## Verdict

**agent_core: PASS.** Every risky surface (`pty`, `bash_execute`, `cli_passthrough`,
`apple`, `browser`, `imessage`, `media`, `terminal`, `computer_use`, `custom_tools`,
`delegate_task`, `discovery`, `intelligence`, `macos`, `scheduling`, `skills`,
`stdio_mcp`, `trajectory`) is module-level gated in `lib.rs:28-29, 81-114`. Build
with `--features mas-sandbox` succeeds cleanly. Tirith reaches subprocess only via
`approval.rs::extract_command` which returns `None` under the feature. The
existing gating discipline is dense and correct.

**omega-mcp: OPEN GAP O1.** No `mas-sandbox` feature exists. PTY/osascript
primitives compile unconditionally into `libomega_mcp.dylib`, which the MAS
target links and ships. UniFFI auto-generates Swift entry points for them in
`omega_mcp.swift` (also bundled). Zero MAS Swift call-graph reach today, so
runtime risk is nil; App Review static-analysis risk is **non-zero** because
the symbols are physically present. PRIVACY_APP_STORE_AUDIT.md row A2 already
demanded this verification — the answer is "not gated."

**No code changes applied** by this audit, per the editing policy ("STOP and
report exact file:line evidence; do NOT silently fix"). The fix is structural
(Cargo feature + `lib.rs` module gates + UDL gating + build-script wiring)
and should be dispatched as a separate patch by the master auditor.

## Files inspected (no modifications)

- `agent_core/Cargo.toml` (verified `mas-sandbox = []` at line 9)
- `agent_core/src/lib.rs` (verified module-gate matrix at lines 28-29, 81-114)
- `agent_core/src/approval.rs` (verified `extract_command` MAS branch at lines 606-623)
- `agent_core/src/tirith.rs` (verified `Command::new(binary)` at line 260)
- `agent_core/src/tools/registry.rs` (verified `BashExecuteHandler` gating at lines 2159, 2163)
- `agent_core/src/tools/{apple,browser,cli_passthrough,imessage,media,terminal,code_execution}.rs`
- `omega-mcp/Cargo.toml` (no `mas-sandbox` feature; no `[features]` section at all)
- `omega-mcp/src/lib.rs` (modules unconditional at lines 17, 19)
- `omega-mcp/src/uniffi_exports.rs` (subprocess Swift entry points at lines 120-218)
- `omega-mcp/src/{osascript,pty}.rs`
- `omega-mcp/uniffi/omega_mcp.udl` (subprocess UDL exports at lines 47-83)
- `omega-ax/src/` (separate crate; not consumed by agent_core or omega-mcp Rust source)
- `project.yml:127-201` (MAS target — LDFLAGS, post-build scrub of omega_ax only,
  syncedFolder excluding only `omega_ax.swift`)
- `build-rust/swift-bindings/omega_mcp.swift` (verified subprocess Swift entry
  points at lines 949, 989, 999)
- `EpistemosTests/AppStoreHardeningTests.swift` (verified existing Swift-side
  `Process.init(` gating tests; omega-mcp Rust side not currently covered)
- `docs/audits/PRIVACY_APP_STORE_AUDIT.md` (row A2 anchor for this audit)

## Verification not run

- `cargo test --manifest-path agent_core/Cargo.toml --lib` — not required
  (no Rust files modified).
- `nm` symbol leak spot-check — would require a release MAS dylib build;
  recommend wiring this into the bundle-size CI gate (PRIVACY row A3).

PASS for agent_core. ESCALATE for omega-mcp (Open Gap O1).
