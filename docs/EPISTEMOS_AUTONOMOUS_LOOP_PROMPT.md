# Epistemos — Autonomous Build Loop Prompt

> Paste everything below the line into a fresh `claude` terminal session (or `/loop` with it).
> It grants standing authority to decide and execute without asking, and defines the loop + the
> safety rails that hold even under full autonomy.

---

You are working on Epistemos (`/Users/jojo/Downloads/Epistemos`) with **standing authority from
Jordan (the owner) to decide and execute everything**. Do **not** ask for input, approval, or
confirmation for local engineering work. Pick the highest-value next slice, do it, verify it,
commit it, and immediately continue to the next. Never stop to ask "should I proceed?" — proceed.
Run in a **forever loop** until you hit a hard stop (defined at the bottom).

When you would normally ask a question, instead: pick the best option yourself, state the decision
in one line, and keep going. "Decide for me" is permanent.

## Priority order (work top-down; finish each before moving on)

1. **Gemma 4** — make every dense tier runnable + honest. (Loader landed 2026-06-14; on-device
   token-gen proof is the only open item — it needs Jordan's machine, so queue it, don't block.)
2. **Capabilities / skills / tools** — every skill and tool in the app actually works, honestly gated.
3. **Harden** all of the above (invariants, witnesses, crash-safety, regression tests).
4. **Full architecture** — the System G sovereign multi-lane runtime + the large-model/70B frontier,
   advanced in MAS-safe, flag-gated, cargo-verifiable slices. (System G is already built in Rust
   `agent_runtime_v2/system_g_runtime.rs` + Swift `RealSystemGRunSeam.swift`/`RuntimeRouter`; the
   frontier is loading large-model bytes — walk the `uas/exotic_quant_*` witness chain, never skip it.)

## The loop (repeat forever)

1. **Orient** — `git status` + `git log --oneline -8`; read `docs/AGENT_PROGRESS.md`,
   `docs/APP_ISSUES_AUTO_FIX.md`, the current sprint file, and the auto-memory index `MEMORY.md`.
2. **Research-first** — before any code/refactor/reroute, search
   `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`, read the canonical local source it names, then
   verify current code/logs. Web-validate only when current API/OS/model/security facts matter.
3. **Pick** the next highest-value slice that is **verifiable now** (prefer Rust/cargo-testable work
   and compile-checkable Swift over anything that can only be proven on-device).
4. **Implement** — match surrounding code style. New runtime/experiment behavior ships behind a
   feature flag that defaults **OFF**. MAS-safe (no hidden sidecar/subprocess on the product path).
5. **Verify (zero regressions, non-negotiable)** —
   - Rust: `cargo test --manifest-path agent_core/Cargo.toml`
   - Swift compile: `xcodebuild build-for-testing -scheme Epistemos -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO` → look for `TEST BUILD SUCCEEDED` (exit 65 with only the entitlements/dev-cert error = compile OK; that's the headless signing block, not a code error).
   - Capture exit codes to a file; never let a trailing `echo` mask the real exit.
6. **Commit** — one focused commit per slice. End the message with
   `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. If on `main`, that's fine — Jordan
   commits to main and has lost work before, so **commit after every change, never batch**.
7. **Record** — update `docs/AGENT_PROGRESS.md` (✅ + date, only after verification passes) and write
   a one-fact memory file + `MEMORY.md` pointer for anything durable/non-obvious.
8. **Loop** — go back to step 1. Do not summarize-and-stop; continue.

## Non-negotiable safety rails (hold even under full autonomy)

- **Zero test regressions** against the suite. Verify before you commit; never mark done on red.
- **No fake features.** Don't claim a model/tool/capability works until it's verified. If it can only
  be proven on Jordan's machine, mark it "pending on-device" honestly and move on.
- **No loading real model bytes / promoting large-model capability** without the canon's witness chain
  (`uas/exotic_quant_*`) AND an on-device run. Build the scaffolding (cargo-verifiable); defer the
  byte-load to Jordan's machine.
- **Honest capability gating** — local models get fast/thinking/research; only cloud gets agent/live.
  Never fake agent capability (e.g., Gemma stays `canActAsAgent == false`).
- **MAS-safe**: in-process Rust FFI / MLX-Swift only on the product path; Pro-only behind
  `#if PRO_BUILD` / `#[cfg(feature = "pro-build")]`. No npm/subprocess at runtime.
- **Preserve thinking blocks**; stream every token; agent decides termination.
- API keys in Keychain, never UserDefaults. No `try!` / force-unwrap / `print()` in production paths.

## Hard stops (the ONLY reasons to pause the loop)

1. A step that genuinely needs Jordan's physical machine (a signed `Product ▸ Run`, an on-device model
   token-gen run, a biometric `SovereignGate` confirm). → Leave a crisp handoff, mark it pending,
   and **continue with other work** — do not let it block the whole loop.
2. A genuinely irreversible / external / destructive action (publishing public content, sending
   messages on Jordan's behalf, deleting data, anything financial, granting permissions). → Note it,
   skip it, continue. These are the only things that still require Jordan to act.
3. Truly nothing verifiable is left. → Write a status summary and idle.

Everything else — design decisions, refactors, which slice next, which lane to open, how to gate it —
**is yours to decide. Decide and keep building.**
