# 00 — Authority & Anti-Drift Contract

**Audience:** Every agent (Claude Code, Codex, manually-driven sessions, background agents)
that touches the Epistemos codebase. Humans, too.

**Status:** Binding. Violating this contract is itself a bug.

---

## 1. Authority hierarchy (immutable)

| Tier | Document | Owns |
|---|---|---|
| 1 | `docs/architecture/PLAN_V2.md` | Architectural truth — system shape, layered model, doctrine, non-negotiables |
| 2 | `CLAUDE.md` | Code standards, provider matrix, file map, "DO NOT" list |
| 3 | `docs/plan/01_DOCTRINE.md` | Fifth-position rulings on the five A/B/C/D tensions; the novel primitive |
| 4 | `docs/plan/02_BUILD_MATRIX.md` | Pro vs MAS gating per item |
| 5 | `docs/plan/03_EXECUTION_MAP.md` | Per-item file-level execution rules |
| 6 | `docs/plan/prompts/<task>.md` | Task-specific instructions |

**Conflict rule:** If tier *N* contradicts tier *N–k* (k ≥ 1), tier *N–k* wins. The
contradiction must be surfaced explicitly to the user as a documented disagreement
before any code is written. Never silently resolve it. Never edit upward (e.g., never
edit PLAN_V2 to match a task prompt; the task prompt is wrong).

---

## 2. Mandatory pre-flight reads

**Before writing or editing any code or any document in `docs/plan/` or anywhere else
in the repo, the agent MUST read in full:**

- `docs/architecture/PLAN_V2.md`
- `CLAUDE.md`
- `docs/plan/01_DOCTRINE.md`
- The relevant entry in `docs/plan/03_EXECUTION_MAP.md` for the item being worked on
- The Pro/MAS gating row in `docs/plan/02_BUILD_MATRIX.md` for the item
- All research docs flagged in `docs/plan/05_RESEARCH_INDEX.md` for the item
- The matching task prompt in `docs/plan/prompts/` (or `_TEMPLATE.md` if generating one)

**There is no "skim" option.** "Read in full" means the agent has actually loaded the
content into context. If the file is too long, the agent must Read it in segments and
summarize back the load-bearing constraints to itself before proceeding.

---

## 3. The auto-research mandate

**If the agent encounters a term, API, library, version, file path, line number, or
benchmark figure that is NOT verified in its current context, it MUST stop and verify
before continuing.** Verification means one of:

- `Read` the file at the cited path and quote the relevant lines.
- `Grep` for the symbol/term and confirm its presence and signature.
- `WebFetch` the official documentation URL.
- A research doc in `~/Downloads/Advice/` or `~/Downloads/final/` (path indexed in `05_RESEARCH_INDEX.md`).

**The agent must not assert from memory.** Memory drift is the #1 source of agent
hallucination. If the agent thinks "uniffi 0.30 supports X" — it must verify, not assume.

**If verification is impossible** (e.g., no internet, file missing): the claim is
tagged `[UNVERIFIED]` inline and the agent surfaces it to the user before proceeding.
Do not write code that depends on `[UNVERIFIED]` claims without explicit user approval.

---

## 4. Verification gates (per task)

A task is **NOT** complete until ALL of the following pass. Skipping any of these is a
contract violation.

### 4.1 Build green
```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
```
- Exit code 0.
- Zero new warnings on lines the task touched.

### 4.2 Test floor preserved
```bash
swift test                                        # 2,679-test suite floor
cargo test --manifest-path agent_core/Cargo.toml  # Rust agent_core
cargo test --manifest-path epistemos-core/Cargo.toml
cargo test --manifest-path epistemos-shadow/Cargo.toml
```
- Zero regressions. Net new tests for any net new code paths.
- If the task is a hardening task (e.g., W9.21 Honest FFI), TSan stress run required.

### 4.3 Lint clean
```bash
swiftlint
cargo clippy --all-targets -- -D warnings
```

### 4.4 No-silent-behavior audit
For every new code path that activates a non-default behavior (e.g., KIVI KV
quantization, grammar masking, OpLog write):
- The activation MUST be observable in the UI or in `agent_core/src/session_insights.rs`
  telemetry stream.
- Per `PLAN_V2 §3.4`: no silent backend switching, no silent fallback, no silent
  adaptation, no silent mask application, no silent sidecar activation.
- A unit test asserts the observable surface exists.

### 4.5 Definition of done
The task's `definition_of_done` checklist in `03_EXECUTION_MAP.md` (or in the task
prompt) is fully checked. Each checkbox has a one-line proof — a test name, a grep
line, a screenshot of the telemetry surface.

### 4.6 Update AGENT_PROGRESS.md
Per `CLAUDE.md`, items are not marked done in `docs/AGENT_PROGRESS.md` until
verification greps pass. Add today's date and a one-line summary.

### 4.7 Wired-Reachable-Visible (WRV) gate — the anti-scaffolding rule

**The failure mode this prevents:** an agent writes a new file, declares the
feature "done," and the PR ships — but the new code is never called from
production paths, the user has no way to trigger it, and there's no UI signal that
it exists. The codebase grows; the product does not. **This is the dominant agent
drift pattern in this codebase. It is forbidden.**

A task is NOT complete until ALL THREE layers verify:

#### W — Wired (the code is actually called)
- Grep for the new public symbol(s): `grep -rn '<NewSymbol>' Epistemos/ agent_core/src/ epistemos-*/src/ syntax-core/src/ substrate-*/src/ graph-engine/src/ omega-*/src/`
- At least one match MUST be in a production code path (not a test, not a comment, not another scaffold-only file).
- For Rust crates: the new symbol must reach a `pub` export consumed by the host crate or an FFI binding. `cargo tree -p <crate>` confirms the dep chain.
- For Swift: the new type/function must be referenced from `App/`, `Views/`, `Engine/`, `Bridge/`, `LocalAgent/`, or another shipping module.
- **Forbidden:** new files that are imported nowhere except their own tests.

#### R — Reachable (the user can trigger it without debug knobs)
- Document the gesture sequence: "Open the app → < specific clicks/typing > → < the new code runs >."
- The path must work from a fresh app launch on a default-configured machine. No `EPISTEMOS_*` env vars, no debug menus, no `#if DEBUG` blocks.
- **Exception:** opt-in feature flags surfaced in shipping Settings UI count as "reachable" provided the toggle is visible in the shipped app. Hidden env-var-only flags do NOT count.
- **Forbidden:** features that only run during tests, only run when a debug build is active, or only run when an undocumented flag is set.

#### V — Visible (the user can see it's working)
- The feature must be observable through at least one of:
  - A persistent UI element (status pill, indicator, badge, row in `ModelAboutSheet` or equivalent)
  - A streaming `AgentEvent` rendered in the chat surface
  - A `SessionInsight` field surfaced somewhere the user can see (cost dashboard, briefing, settings)
- **Forbidden:** "the feature works internally; the user just doesn't know" — that is indistinguishable from no feature.
- **No silent fallback:** if the feature can degrade (e.g., grammar masking falls back to soft guidance), the degradation MUST be visibly indicated. Per `01_DOCTRINE.md §6 #5`.

#### WRV exemptions

Some items are infrastructure-only and have no user-facing surface. These are
exempt from R and V (but never from W). The exempt items are listed in
`03_EXECUTION_MAP.md` under each item's notes with the marker:

```
WRV_EXEMPT: <one of "infrastructure", "build", "test-only"> — <reason>
```

Examples: R14 (UniFFI bump — pure plumbing), D5 (durability discipline — invisible
when working), W9.21 (Honest FFI — architectural).

**These are the only exemptions.** A task that thinks it should be exempt but is
not in the list must STOP and surface to the user before claiming exemption.

#### WRV proof artifact

Every PR must include a "WRV proof" block in the description:

```
## WRV proof
- WIRED: <grep command> returned: <output showing non-test caller>
- REACHABLE: From a fresh app launch: <step 1> → <step 2> → <step N> → <new code runs>
- VISIBLE: User sees <element type> at <UI location> when feature is active.
- (or) WRV_EXEMPT: infrastructure — <reason>
```

PRs without a WRV proof block are not done. Reviewers (human or agent) must
reject them.

---

## 5. STOP-and-surface triggers

The agent **must stop, surface to the user, and wait for guidance** if it encounters
any of these conditions. The list is exhaustive — if a situation matches a trigger,
the agent does not proceed.

1. **Tier conflict.** This plan's instruction contradicts a higher tier (PLAN_V2 or
   CLAUDE.md). Quote both, surface the contradiction, wait.
2. **Scope creep impulse.** The agent thinks "while I'm here I should also fix X" and
   X is not in the task prompt or `03_EXECUTION_MAP.md`. Stop. Add a note to a TODO
   list. Do not silently expand scope.
3. **Verification failure.** A claim cannot be verified by Read/Grep/WebFetch. Stop,
   tag `[UNVERIFIED]`, surface, wait.
4. **Test regression.** Any test in the 2,679-test floor goes red because of the
   change. Stop, do not commit, surface the regression, wait.
5. **No-silent-behavior violation.** The agent is about to add a code path that
   activates without an observable telemetry surface. Stop, design the surface,
   resume.
6. **Force-unsafe needed.** The agent thinks `try!`, `print()` in production, force
   unwrap, `DispatchQueue.main.sync` in a UniFFI callback, or Debug-format JSON
   serialization is the right move. It isn't. Stop, surface, wait.
7. **Pro vs MAS confusion.** The agent is uncertain whether a code path is allowed
   in MAS. Stop, read `02_BUILD_MATRIX.md`, surface, wait if still unclear.
8. **Memory budget violation.** The agent's change increases steady-state memory
   beyond the 6 GB realtime budget on a 16 GB Mac. Stop, profile, surface.
9. **PLAN_V2 / dossier divergence.** The agent finds itself implementing something
   the dossier specs but PLAN_V2 contradicts (or vice versa). Stop, surface, wait.
10. **Memory file said "always do X."** The user's auto-memory says something that
    contradicts the current task instruction. Stop, surface, wait.

---

## 6. Forbidden actions (zero tolerance)

These are bans. Period. Not "discouraged." Banned.

- Editing `docs/architecture/PLAN_V2.md` for any reason. Even to fix typos. Surface
  to user; user edits it.
- Editing `CLAUDE.md` to match the agent's code instead of editing the agent's code
  to match `CLAUDE.md`.
- Marking items done in `docs/AGENT_PROGRESS.md` before verification greps pass.
- `try!`, force unwraps (`!`), `print()` in production paths.
- `DispatchQueue.main.sync` inside a UniFFI callback (deadlocks).
- `AsyncStream` with `.unbounded` buffering. Use `.bufferingNewest(256)`.
- Debug format (`{:?}`) for JSON serialization (it's not JSON).
- Buffering streaming responses. Forward every token immediately.
- Stripping thinking blocks from message history when `stop_reason == "tool_use"`.
- Spawning subprocesses for inference. Hermes subprocess is for orchestration only.
- Storing API keys in `UserDefaults`. They go in the macOS Keychain.
- Editing `.xcodeproj` directly. Use `xcodegen` against `project.yml`.
- Committing model files (`.gguf`, `.safetensors`, `.mlx`).
- Importing SDKs that don't exist (Anthropic Swift SDK, OpenAI Swift SDK — both
  do NOT exist; use raw URLSession).
- `mkdir`/`Write` in the codebase without first reading the existing file (Write tool
  enforces this; do not work around it).
- `git push --force` to main/master. `--no-verify` to skip hooks. `git reset --hard`
  to discard work. (Per global Bash policy.)

---

## 7. The telemetry mandate (PLAN_V2 §3.4 enforcement)

> "No silent backend switching. No silent cloud escalation. No silent adaptation.
> No silent mask application. No silent sidecar activation. No silent fallback.
> Everything important must be surfaced in telemetry and summaries."

**Operational meaning for tasks:**

- Every feature flag activation surfaces in the UI (status row, model-about sheet,
  session insight, or equivalent).
- Every fallback path emits an `AgentEvent` (or equivalent) so the user can see it
  fired.
- Every cloud escalation appears in the cost dashboard before the call lands.
- Every model swap (e.g., quant scheme changed) is visible in `ModelAboutSheet`.
- Every sandbox-tier choice (JSC / Wasmtime / Bollard / host) is logged with the
  rationale and the approval result.

If the agent cannot describe in one sentence where the user sees a behavior, the
behavior is not allowed.

---

## 8. The 6 GB realtime budget

**Hardware target:** 16 GB Mac, ~6 GB available to the Epistemos process at runtime.
Pro can stretch beyond on 18 GB+ machines, but the floor is 6 GB.

**Operational meaning:**

- A 7 B 4-bit local model with FP16 KV cache at 8K context = ~3.5 GB weights + ~448 MB
  KV ≈ 4 GB. **No headroom for a second model.** Eviction-on-load is mandatory.
- A 7 B 4-bit local model with FP16 KV cache at 32K context = unfeasible without KV
  quantization. **KIVI 2-bit (or TurboQuant) is required for >8K context.**
- Background jobs (ETL crawler, Night Brain, embedding training) MUST hook
  `DispatchSourceMemoryPressure` and yield within 100 ms of receiving `.warning`.
- Hermes Python subprocess (Pro only) is ~200–400 MB resident — counts against the
  6 GB budget.
- Xcode + cargo + npm running concurrently during development reduces the budget
  further. Production budget is what ships, but dev workflow must not OOM the editor.

A task is in violation if it adds a steady-state memory cost > 50 MB without an
explicit memory-budget line item in the definition of done and the user signing off.

---

## 9. The "no scope creep" rule

The single largest source of agent drift in this codebase has been: an agent picks
up task X, sees something nearby that "looks broken," fixes it too, and produces a
sprawling diff. **This is forbidden.**

If the agent identifies an issue outside the task scope:
1. Add it to `docs/APP_ISSUES_AUTO_FIX.md` (or an equivalent file the project tracks).
2. Note it in the PR description as "Out-of-scope finding, filed separately."
3. Do **not** fix it in the same PR.

The exception is per `CLAUDE.md` "Auto-Fix Opportunities": opportunistic fixes for
issues already filed in `docs/APP_ISSUES_AUTO_FIX.md` are allowed when non-destructive
and not derailing. Treat that as the *only* off-task path.

---

## 10. Definition-of-done preamble

For every task, the prompt's definition-of-done section is the source of truth. But
every task's DoD must include at minimum:

- [ ] All verification gates in §4 pass.
- [ ] **WRV gate from §4.7 verifies (or `WRV_EXEMPT` justified per `03_EXECUTION_MAP.md`).**
- [ ] No STOP-and-surface trigger from §5 was ignored.
- [ ] No forbidden action from §6 was committed.
- [ ] The telemetry mandate from §7 is satisfied (this overlaps with WRV-V).
- [ ] The 6 GB realtime budget from §8 is preserved.
- [ ] No scope creep per §9.
- [ ] `AGENT_PROGRESS.md` updated with date + one-line summary.
- [ ] PR description cites the `docs/plan/` entry and the research docs that
      informed the implementation.
- [ ] PR description includes the **WRV proof** block per §4.7.

---

## 11. The single most important rule

**When in doubt, STOP and surface.**

Drift comes from agents that proceed when they shouldn't. Stopping is always cheaper
than reverting. The user would rather answer one question than untangle a bad merge.

If something feels off, it is. Stop. Surface. Wait.
