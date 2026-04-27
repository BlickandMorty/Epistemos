# MASTER BUILD PLAN — Single-file autonomous execution doctrine

**Version:** 1.0 (2026-04-27)
**Purpose:** Everything a fresh Claude Code session needs to autonomously
work through the entire remaining V1.5 backlog over multiple days, shipping
each item end-to-end with WRV (Wired-Reachable-Visible) proof.
**Authority:** Top of the chain. Subordinate only to
`docs/architecture/PLAN_V2.md` (architectural) and `CLAUDE.md` (code
standards). All other plan docs (the `docs/plan/` tree, the dossier, the
tracker) are referenced from here for depth — this file is the single
operational entry point.

---

## §0 — How to use this file

You are a Claude Code session whose job is to ship items from the queue in
§7 below, one at a time, following the contract in §1–§6 for every item.
**Do not skip steps. Do not improvise the contract.** This is a
deterministic loop:

```
loop:
  read this file (only on first turn — keep in context after that)
  pick next item with status ⚪ PENDING from §7 priority queue
  follow §1–§6 contract for that item
  ship it (commit + WRV proof in PR description)
  update §7 status to 🟢 SHIPPED with commit SHA
  goto loop
end when:
  every item in §7 is 🟢 SHIPPED or ⏸ DEFERRED
```

You do NOT ask the user "what next?" — the queue order is the answer.
You DO surface to the user when:
- A STOP-trigger fires (per §3 verification gates)
- A `[UNVERIFIED]` claim cannot be resolved
- An item's spec contradicts another item already shipped
- A test floor regression occurs

When the queue is empty, end with: `MASTER PLAN COMPLETE — N items shipped over M days. Awaiting next directive.`

---

## §1 — Authority hierarchy (highest → lowest)

```
1. docs/architecture/PLAN_V2.md         — architectural authority
2. CLAUDE.md                            — code standards + provider matrix
3. docs/MASTER_BUILD_PLAN.md            — this file (operational doctrine)
4. docs/plan/01_DOCTRINE.md             — fifth-position rulings (deep ref)
5. docs/plan/02_BUILD_MATRIX.md         — Pro/MAS gating (deep ref)
6. docs/plan/03_EXECUTION_MAP.md        — per-item depth (deep ref)
7. PRs / commits                        — executed work
```

If any lower level contradicts a higher one, **the higher one wins**. The
lower one must be revised; never the reverse. This is non-negotiable.

---

## §2 — The 14 non-negotiables (condensed from `docs/plan/01_DOCTRINE.md §6`)

Every commit must satisfy all 14:

1. **No silent behavior.** Telemetry surfaces every non-default behavior.
2. **No subprocess inference.** All inference in-process via Rust/MLX. Hermes subprocess is orchestration only.
3. **No fake features.** Real APIs verified against current docs.
4. **No fallback inspector.** A2UI catalog is closed (~25 components). Unknown schemas are validation errors.
5. **No silent fallback.** If Provider A fails and B is invoked, the user sees it.
6. **No `AnyView` in render hot paths.** Typed view-builder enums only.
7. **No editing PLAN_V2.** Architectural authority. Disagreements surface to user.
8. **No hidden CoT reconstruction.** Thinking blocks preserved verbatim when `stop_reason == "tool_use"`.
9. **No MAS sandbox compromises in Pro paths.** Pro features don't apologize.
10. **No retraction skipping.** Every Claim invalidation propagates; no "fast path".
11. **No `DispatchQueue.main.sync` in UniFFI callbacks.** Always `.async`.
12. **No API keys in `UserDefaults`.** Keychain only.
13. **No marking items done before verification.** Greps must pass first.
14. **No orphaned scaffolding.** Every new feature is Wired + Reachable + Visible. Unwired code is forbidden. **This is the rule N1 was conceived to honor.**

---

## §3 — The 7 verification gates (every item runs all 7 before claiming done)

For every item you ship, run all seven before commit:

1. **Build green** —
   ```bash
   xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
   ```
   For Pro/MAS targets when relevant: add `-configuration ReleasePro` or `ReleaseMAS`.

2. **Test floor preserved** —
   ```bash
   swift test                                       # 2,679-test floor
   cargo test --manifest-path agent_core/Cargo.toml
   cargo test --manifest-path epistemos-core/Cargo.toml
   cargo test --manifest-path epistemos-shadow/Cargo.toml
   ```

3. **Lint clean** — `swiftlint` and `cargo clippy --all-targets -- -D warnings`. Vendored CodeEdit* SwiftLint warnings are pre-existing and don't count.

4. **No-silent-behavior audit** — every new code path that activates a non-default behavior MUST emit an `AgentEvent` AND surface in the UI. Document the surface in your PR description.

5. **Definition of done** — every checkbox in the item's §7 entry has a one-line proof (test name, grep line, screenshot description).

6. **WRV gate (§4 below)** — execute the proof for the item. If the item is `WRV_EXEMPT`, write the exemption justification + cite which §7 line lists this item as exempt. **No self-grant exemptions** — if the item isn't in the closed exempt list, you cannot waive WRV.

7. **Update the item's status** in §7 from ⚪ PENDING / 🔵 IN-PROGRESS to 🟢 SHIPPED with the commit SHA.

If any gate fails, **stop and surface to user**. Do not commit a partial pass.

---

## §4 — WRV gate spec (Wired + Reachable + Visible)

The single most important contract in this file. Every item that isn't
explicitly `WRV_EXEMPT` must prove all three layers in the PR description.

### W — Wired

The new code is actually called from production code paths.

**Verify with:**
```bash
grep -rn '<NewSymbol>' <project_dir>
```
At least one match must be in non-test, non-scaffold production code (NOT
another scaffold-only file). Paste the grep output in the PR description.

If grep returns zero hits or only test/scaffold hits: **the feature is
unwired.** STOP. Do not commit. Surface to user.

### R — Reachable

The user can trigger it without debug knobs.

**Document the gesture sequence:** "Open app → <specific clicks/typing> →
<new code runs>" from a fresh launch on a default-configured machine. No
`EPISTEMOS_*` env vars (except opt-in feature flags exposed in Settings UI,
which count as "reachable"), no debug menus, no `#if DEBUG` blocks.

### V — Visible

The user can SEE it's working.

Observable via persistent UI element (status pill, badge, indicator, row in
ModelAboutSheet), streaming AgentEvent in chat, or SessionInsight field in
cost dashboard / briefing / settings. **No silent fallback allowed.** If the
feature can degrade (e.g. grammar masking falls back to soft guidance), the
degradation MUST be visibly indicated.

### Closed exempt list (cannot self-grant; must be in this list)

- **R14** (UniFFI bump) — `WRV_EXEMPT: infrastructure` (no user-facing surface; build hygiene only)
- **R15** (Benchmark harness) — `WRV_EXEMPT: test-only` (does not ship in either app target)
- **D5** (Substrate durability) — `WRV_EXEMPT: infrastructure` (corruption detection raises errors when triggered, but normal operation is invisible)
- **W9.21** (Honest FFI) — `WRV_EXEMPT: infrastructure` (architectural; no user gesture)
- **W9.22** (Typestate Islands) — `WRV_EXEMPT: infrastructure` (compile-time only)
- **W9.24** (Metal zero-copy) — `WRV_EXEMPT: infrastructure` (perf-only)
- **W9.27** (OpLog) — exempt at substrate level only when no user-facing time-travel affordance yet; not exempt at feature level

**Every other item: not exempt.** WRV must verify. If you think your item should be exempt but isn't on this list: STOP and surface — don't add to the list yourself.

### Required PR description block (mandatory for every item)

```markdown
## WRV proof
- WIRED: <grep command + output showing non-test caller>
- REACHABLE: From a fresh app launch: <step 1> → <step 2> → <step N> → <new code runs>
- VISIBLE: User sees <element type> at <UI location> when feature is active.
  (or) WRV_EXEMPT: <category> — <justification, cite §4 closed list line>
```

---

## §5 — Pro vs MAS build matrix (condensed from `docs/plan/02_BUILD_MATRIX.md`)

Two builds, one codebase, strict separation:

### Compilation conditions

- Swift: `#if EPISTEMOS_PRO` (Pro-only), `#if EPISTEMOS_APP_STORE || MAS_SANDBOX` (MAS-only). Use `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)` to mean "Pro-only".
- Rust: Cargo features `pro` / `mas`.

### MAS build (App Store, sandboxed)

- Sandboxed; security-scoped bookmarks only
- No subprocess (Hermes ACP local forbidden; HTTP remote allowed)
- In-process MCP server only
- No Docker/Bollard
- No AXorcist/AppleEvents
- Cost dashboard required
- Approval modal required
- All structured-data inputs work (UI surfaces same as Pro)
- BudgetPreferences + structuring pipelines work identically

### Pro build (Hardened Runtime, full-feature)

- Full MAS surface PLUS:
- Shell exec (portable-pty + rexpect)
- Docker (Bollard ephemeral)
- Subprocess providers (Claude Code CLI, Codex, Gemini, OpenHands)
- AXorcist, cross-app automation
- iMessage driver
- Long-horizon agent loops
- Computer use

### Both targets share:

- GRDB, Metal, tantivy + usearch
- Local MLX/AFM
- Cost dashboard + budget gate
- Approval modal
- Retraction propagation
- A2UI closed catalog
- ReplayBundle export
- StructureRegistry catalog
- Every item in this plan unless tagged Pro-only or MAS-only

### Pro/MAS bleed prevention

- Every PR declares profile impact in description
- Pro-only Swift code lives behind `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`
- Pro-only Rust crates / features behind `#[cfg(feature = "pro")]`
- New UI components default to "both" unless they call into Pro-only APIs (then guard the call site, not the component)

---

## §6 — Auto-research mandate (no memory drift)

Before asserting any:
- File path
- Line number
- Function signature
- Library version
- Benchmark figure
- API behavior

…verify it. Use:
- `Read` for repo files
- `Grep` for symbols
- `Bash` (`find`, `wc`, `cargo tree`, `git log`) for repo state
- `WebFetch` for official docs

**Do not assert from memory.** Memory drift is the #1 source of agent
hallucination in this codebase. If a §7 entry asserts a line number, that
number was correct when the plan was written but the file may have changed.
Re-verify before treating it as canonical.

If verification fails: STOP and surface to user. Do not silently rebase.

---

## §7 — Item queue (priority-ordered; ship top to bottom)

Each item below is a self-contained spec. Pick the topmost ⚪ PENDING
item, work it through §1–§6, mark it 🟢 SHIPPED with commit SHA, repeat.

**Status legend:**
- 🟢 SHIPPED — code merged + verified end-to-end
- 🟡 FOUNDATION — scaffold landed; subsequent PRs needed for full integration
- 🔵 IN-PROGRESS — actively being built this session
- ⚪ PENDING — not started; the next item to pick up
- ⏸ DEFERRED — explicit decision to wait

---

### Bucket A — 90% already done (ship these first if not done)

| ID | Title | Status | Commit | Notes |
| -- | ----- | ------ | ------ | ----- |
| W9.25 | Grammar masking — link mlx-swift-structured | 🟢 SHIPPED | dcc5521f | mlx-swift-structured 0.1.0 linked via project.yml; canImport guards activate; LogitProcessor full wire-up is a follow-up. |
| R14 | UniFFI 0.28 → 0.29.5 | 🟢 SHIPPED | dcc5521f | All 4 Cargo.toml pinned to =0.29.5; auto-regenerated bindings. |
| W9.30 | KIVI quant — env-flag scaffold | 🟡 FOUNDATION | dcc5521f | KIVIPreferences shipped (`EPISTEMOS_KV_KIVI=1`). KIVIKVCache impl in mlx-swift-lm fork is the next PR. |

### Bucket B — Concrete spec, additive (Bucket A done; ship these next)

| ID | Title | Status | Commit | Notes |
| -- | ----- | ------ | ------ | ----- |
| W9.23 | Bit-packed AtomicU64 circuit breaker | 🟢 SHIPPED | dcc5521f | 6/6 tests pass. |
| W9.29 | ThermalMonitor + LocalMLXRequest scaling | 🟢 SHIPPED | 1d573889 + 43a822ad + linter refactor | nonisolated static helper added by linter — single source of truth for the scaling table. |
| W9.6 | Cost dashboard + BudgetPreferences | 🟢 SHIPPED | dcc5521f + 1d573889 | Wired in Settings → Agent → Spend tab. |
| W9.7 | VaultSelectorView | 🟢 SHIPPED | dcc5521f + 1d573889 | Wired in NotesSidebar above ModelVaultsSidebarSection. |
| W9.8 | ApprovalModalView | 🟢 SHIPPED | dcc5521f + 1d573889 | Wired in Settings → Agent → Authority preview card. |
| W9.13 | DailyNoteView | 🟢 SHIPPED | dcc5521f + 1d573889 | Wired via "Today's brief" button in NotesSidebar bottom bar. |
| R15 | Benchmark harness scaffolds | 🟡 FOUNDATION | dcc5521f | 4 XCTest files; disabled by default; manual `-only-testing` runs. WRV_EXEMPT: test-only. |

### Bucket C — Real work, established pattern (multi-PR per item)

| ID | Title | Status | Commit | Notes |
| -- | ----- | ------ | ------ | ----- |
| W9.21 | Honest FFI (PR2 of 4) | 🟡 FOUNDATION | dcc5521f + b2e4899d | PR1 epistemos-shadow + PR2 substrate-rt+substrate-core+syntax-core honest_handle.rs modules (608 LOC, 12 unit tests, all 72 cargo tests across the 3 crates green). PR3 graph-engine + PR4 Swift consumer cutover remain. WRV_EXEMPT: infrastructure. |
| W9.22 | Typestate Islands foundation | 🟡 FOUNDATION | dcc5521f | Generic Lifecycle<T,S>; 5/5 tests. Concrete MLX/Hermes/AFM wrappers in follow-up. WRV_EXEMPT: infrastructure. |
| W9.26 | B-tree rope (PR2 of N) | 🟡 FOUNDATION | dcc5521f + e9618ddf | PR1 foundation (crop 0.4, utf16-metric) + PR2 raw FFI rope_handle module (12 extern "C" exports + 6 unit tests, 688/688 agent_core tests green). PR3 Swift `RopeFFIClient` + `~Copyable` handle + PR4 NoteFileStorage migration remain. |
| W9.27 | OpLog hand-roll foundation | 🟡 FOUNDATION | dcc5521f | Op enum + Lamport + Vec backing; 4/4 tests. GRDB persistence + Swift mirror next PR. |
| R16 | ETL crawler foundation | 🟡 FOUNDATION | dcc5521f | walker + hash modules; 7/7 tests. apalis-sql + AFM @Generable in PRs 2-3. |

### Bucket N — Novel additions (locked into plan after dossier closed)

#### N1 — Prompt Tree (JSPF + PTF) + StructureRegistry-driven prompt composer 🟢 SHIPPED (7316f86b)

**Phase:** parallel | **Targets:** Both | **Risk:** Med

**Doctrine refs:** §6 #1 (no silent behavior — every prompt audit-able), §6 #14 (no orphan scaffolding — N1 ships with one fully-wired call site or it doesn't ship), §6 #5 (no silent fallback — every prompt the agent sends has a typed, registered shape).

**Build matrix:** Both targets. Composer + renderer pure Swift; cache-control hints are Anthropic-specific but degrade silently for providers without prompt caching (OpenAI Responses API, AFM, MLX local).

**Concept — two formats, one composer:**

**JSPF (JSON-Schema Prompt Format)** — typed `Prompt` value (`Codable + Sendable + Hashable`):

```swift
struct Prompt: Codable, Sendable, Hashable {
    var version: Int                       // schema version (start at 1)
    var id: String                         // stable id; doubles as cache key
    var identity: IdentitySection?         // system role / persona
    var tools: [ToolSpec]                  // available tools (subset of full registry)
    var memory: MemorySection?             // recent chats, relevant notes, ontology refs
    var task: TaskSection                  // the active ask
    var constraints: [ConstraintSection]   // hard rules, capability gates
    var output_schema: OutputSchema?       // expected response shape (links to StructureRegistry)
    var cache_hints: CacheHints            // which subtrees are stable enough to cache
}
```

**PTF (Prompt Tree Format)** — same data laid out as a directory:

```
<vault>/.epistemos/prompts/<session>/<turn>/
  ├── identity.json        — stable per session (cacheable)
  ├── tools.json           — stable per session (cacheable)
  ├── memory/
  │   ├── recent_chats.json  — churns turn-by-turn
  │   ├── relevant_notes.json
  │   └── ontology.json    — stable per vault (cacheable)
  ├── task.json            — churns per turn
  ├── constraints.json     — stable per session (cacheable)
  └── output_schema.json   — stable per task type (cacheable)
```

**Why this matters:**

1. **Token savings via prompt caching.** Anthropic's prompt cache (≥1024 tokens, 5-minute TTL) gives 90 % off on cached portions. Mark identity + tools + ontology + constraints + output_schema as cacheable; only memory.recent_chats + task churn turn-by-turn. Realistic savings: 60-80 % of input tokens on agent loops with stable identity.
2. **Composability.** Subtrees compose deterministically.
3. **Auditability.** Every prompt sent is on disk; users + audit agents can inspect exact shape.
4. **Pre-flight validation.** Composer checks against StructureRegistry so unknown output schemas fail at compose time, not at parse time.
5. **Test isolation.** Subtrees are unit-testable independently.

**Files to touch:**

NEW Swift files:
- `Epistemos/Engine/PromptTree.swift` — typed `Prompt` + `PromptNode` enum + `PromptComposer`
- `Epistemos/Engine/PromptRenderer.swift` — render to Anthropic Messages / OpenAI Responses / AFM @Generable / MLX local-grammar formats
- `Epistemos/Engine/PromptCache.swift` — Anthropic `cache_control` hint generator + per-provider degradation
- `Epistemos/Engine/PromptTreePersister.swift` — serialize PTF to `<vault>/.epistemos/prompts/<session>/<turn>/`
- `EpistemosTests/PromptTreeTests.swift` — 8 tests minimum

EXISTING files to wire (the WRV anchor):
- `Epistemos/App/ChatCoordinator.swift` — first agent turn must use composer end-to-end
- `Epistemos/Engine/StructureRegistry.swift` — extend with at least 4 prompt-shape descriptors

NEW doc:
- `docs/PROMPT_AS_DATA_SPEC.md` — format spec, extension rules, provider compat matrix

**Research mandates:**

- WebFetch https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching — verify 90 % discount + 5-min TTL + 1024-token minimum + 4-breakpoint cap (current as of Apr 2026)
- Read existing prompt-assembly call sites: `agent_core/src/agent_loop.rs`, `Epistemos/App/ChatCoordinator.swift` (the system that gets replaced)
- Read `Epistemos/Engine/StructureRegistry.swift` (already shipped 2026-04-27)
- Read `docs/STRUCTURING_AUDIT.md` (already shipped 2026-04-27)

**Definition of done:**

- [ ] `Prompt` + `PromptNode` types in `PromptTree.swift` with full Codable + Hashable conformance
- [ ] `PromptComposer.compose(...)` produces a typed `Prompt` from inputs
- [ ] `PromptRenderer` renders identical `Prompt` to Anthropic Messages, OpenAI Responses, AFM @Generable, MLX local-grammar
- [ ] `PromptCache.hints(for:)` returns `cache_control` markers; capped at Anthropic's 4-breakpoint limit
- [ ] PTF persistence writes to `<vault>/.epistemos/prompts/<session>/<turn>/` and round-trips cleanly
- [ ] **WRV proof:** `ChatCoordinator` first agent turn uses the composer. Verify with `grep -rn 'PromptComposer.compose' Epistemos/App/ChatCoordinator.swift`. User-visible: `cached_tokens_share` row in Settings → Agent → Spend showing > 0 % after second turn
- [ ] StructureRegistry extended with at least 4 prompt-shape entries
- [ ] `docs/PROMPT_AS_DATA_SPEC.md` written
- [ ] Both legacy and new paths coexist behind `EPISTEMOS_PROMPT_TREE=1` flag (or Settings → Agent → Advanced toggle)
- [ ] Unit tests pass; build green on both MAS and Pro targets

**Implementation order** (each step a checkpoint where build should be green):

1. PromptTree types
2. PromptRenderer (4 targets)
3. PromptCache (with measured-hit-rate logging)
4. PromptTreePersister (with NightBrain GC for last N=20 turns)
5. StructureRegistry extension (4+ prompt-shape entries)
6. ChatCoordinator wire (gated by feature flag)
7. Tests (8 minimum)
8. Docs

**Hard rules:**

- No scope creep. Foundation + ONE wired call site. Don't migrate other call sites in the same PR — that's a follow-up.
- Feature flag is mandatory. Both paths coexist. After 2 weeks of bake time + telemetry showing > 30 % cache hit rate without quality regressions, flag flips default-on; legacy path removed in a separate cleanup PR.
- Cache-hit rate is the success metric. If `cached_tokens_share` doesn't move above 30 % after a few real chat sessions, the cache hints are wrong. Tune them before claiming done.
- StructureRegistry is the introspection layer. The local LLM should be able to ask "what shapes do you send?" and get a real answer.
- Pro/MAS separation: composer + renderer are pure Swift, no Pro-only deps. PTF directory uses existing vault root.

---

### Bucket D — Research-grade, gate on roadmap need (do NOT pick up unless user explicitly authorizes)

| ID | Title | Status | Reason for deferral |
| -- | ----- | ------ | ------------------- |
| W9.10 | TurboQuant 3-bit KV | ⏸ DEFERRED | Wait for KIVI (W9.30) full impl to prove insufficient first. |
| W9.11 | Create ML personalized embeddings | ⏸ DEFERRED | Eval methodology needs design pass. |
| W9.12 | Orphan rediscovery | ⏸ DEFERRED | Wants W9.27 OpLog substrate first (now FOUNDATION). |
| W9.14 | Block references + transclusion | ⏸ DEFERRED | Wants W9.26 rope first for cheap snapshots (now FOUNDATION). |
| W9.15 | Static routing macro | ⏸ DEFERRED | ROI unclear at current view count (~30 view types). |
| W9.24 | Metal zero-copy buffers | ⏸ DEFERRED | UMA may make `bytesNoCopy` a no-op gain. Measure first. |
| W9.28 | Blelloch scan in Metal | ⏸ DEFERRED | Mamba-2 already has 3-dispatch Reduce-then-Scan. Roadmap-gated. |

---

### Pre-TestFlight ship gates (orthogonal — also pending)

| ID | Title | Status | Effort |
| -- | ----- | ------ | ------ |
| P0-2 | Reliability fresh baseline | ⚪ PENDING | ~2 hr |
| P0-3 | TestFlight metadata | ⚪ PENDING | ~4 hr |
| P0-4 | mas-sandbox feature-gating spot-check | ⚪ PENDING | ~30 min |

These are release mechanics, not feature work. Ship them between feature
items as time permits. They block App Store submission but not the queue.

---

## §8 — How to handle multi-PR items (the W9.21 / W9.22 / W9.26 / W9.27 / R16 pattern)

When a Bucket C item lands as 🟡 FOUNDATION, the queue contains follow-up
PRs that complete the wire-up. After picking up a foundationed item:

1. Read the item's existing foundation files
2. Read `docs/RESEARCH_DOSSIER_TIER_3_4.md` section for the item
3. Identify the next PR's scope (PR2 of 4, PR3 of 4, etc.)
4. Implement only that PR's scope
5. WRV-prove the new wire-up at the point of integration
6. Mark the item 🟢 SHIPPED only after the LAST PR lands; otherwise update its commit list and keep status 🟡 FOUNDATION

---

## §9 — Pre-flight reads (mandatory before EVERY item, in this order)

Even though this file gives you everything you need at the operational
level, depth references are still mandatory before writing code:

1. `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md` — architectural authority
2. `/Users/jojo/Downloads/Epistemos/CLAUDE.md` — code standards + provider matrix + file map + DO NOT list
3. **THIS FILE** (you've read it; keep in context)
4. `/Users/jojo/Downloads/Epistemos/docs/plan/01_DOCTRINE.md` — fifth-position rulings (deep ref for the 14 non-negotiables)
5. `/Users/jojo/Downloads/Epistemos/docs/plan/02_BUILD_MATRIX.md` — Pro/MAS gating (deep ref)
6. `/Users/jojo/Downloads/Epistemos/docs/plan/03_EXECUTION_MAP.md` — per-item depth (your item's section)
7. `/Users/jojo/Downloads/Epistemos/docs/STRUCTURING_AUDIT.md` — input → structure pipeline (every input you touch)
8. `/Users/jojo/Downloads/Epistemos/docs/RESEARCH_DOSSIER_TIER_3_4.md` — research findings per item
9. `/Users/jojo/Downloads/Epistemos/docs/V1_5_IMPLEMENTATION_TRACKER.md` — current state of every item
10. `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/StructureRegistry.swift` — schemas the app already has

For each file, summarize the load-bearing constraints to yourself in your
output before doing anything else. This is the proof you read them.

---

## §10 — Output protocol (every commit)

Every commit message follows this format:

```
<scope>(<id>): <short title>

<body explaining what shipped + why>

WRV proof:
- WIRED: <grep + output>
- REACHABLE: <gesture sequence from fresh launch>
- VISIBLE: <UI element + location>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

Every PR description follows the §4 WRV proof block + the §3 verification
gate proofs (per-gate one-line evidence).

After the commit lands, update §7 of THIS FILE inline:
- Change the item's status to 🟢 SHIPPED (or 🟡 FOUNDATION if multi-PR)
- Add the commit SHA to the row
- Don't delete history; supersede with a dated note if needed

Then commit that update separately with: `plan(tracker): mark <ID> as <status> after <SHA>`.

---

## §11 — When to surface to the user (STOP triggers)

Stop and surface immediately if:

1. **Build doesn't go green** after a reasonable fix attempt
2. **Test floor regresses** — you broke something existing
3. **A `[UNVERIFIED]` claim** can't be resolved via WebFetch / Read / Grep
4. **An item's spec contradicts** another item already shipped (drift)
5. **WRV gate fails** and the item isn't on the closed exempt list
6. **You're about to do a destructive operation** — git reset --hard, force push, file delete that wasn't in the spec
7. **You discover scope creep is necessary** — the item needs work outside its declared files-to-touch
8. **You need to install a new dependency** that wasn't pre-approved in the spec
9. **A research finding contradicts** a doctrine non-negotiable (e.g. a paper recommends subprocess inference)

Surface format:

```
STOPPED at item <ID>, phase <N>: <one-sentence reason>.

Context:
<2-3 sentences of relevant detail>

What I need from you:
<specific question or decision request>

Awaiting user guidance.
```

---

## §12 — When the queue is empty

When every item in §7 (Buckets A, B, C, N) is either 🟢 SHIPPED or 🟡 FOUNDATION
(for multi-PR items where the next PR isn't authorized yet), end with:

```
MASTER PLAN COMPLETE.
- 🟢 SHIPPED: <count> items
- 🟡 FOUNDATION: <count> items (next PRs queued in dossier)
- ⏸ DEFERRED: <count> Bucket D items (awaiting roadmap decision)
- Pre-TestFlight gates: <P0-2 status> / <P0-3 status> / <P0-4 status>

Total commits: <N>
Total session days: <M>
Test floor: <X tests passing> (was 2,679; delta <±Y>)

Awaiting next directive.
```

---

## §13 — File map (what's where)

For quick reference (also mirrors `CLAUDE.md`):

### Rust agent_core crate
- Loop: `agent_core/src/agent_loop.rs`
- Bridge: `agent_core/src/bridge.rs`
- Claude SSE: `agent_core/src/providers/claude.rs`
- Perplexity: `agent_core/src/providers/perplexity.rs`
- Tools: `agent_core/src/tools/registry.rs`
- Security: `agent_core/src/security.rs`
- Prompt caching: `agent_core/src/prompt_caching.rs` (relevant for N1)
- Compaction: `agent_core/src/compaction.rs`
- Vault: `agent_core/src/storage/vault.rs`
- Routing: `agent_core/src/routing.rs`
- Session: `agent_core/src/session.rs`
- Circuit breaker: `agent_core/src/circuit_breaker.rs` (W9.23 — shipped)
- OpLog: `agent_core/src/oplog.rs` (W9.27 — foundation)
- Rope: `agent_core/src/rope.rs` (W9.26 — foundation)
- Typestate: `agent_core/src/runtime/typestate.rs` (W9.22 — foundation)
- ETL: `agent_core/src/etl/{mod,hash,walker}.rs` (R16 — foundation)

### Rust epistemos-shadow crate
- Library entry: `epistemos-shadow/src/lib.rs`
- Honest FFI: `epistemos-shadow/src/honest_handle.rs` (W9.21 — foundation PR1)
- State: `epistemos-shadow/src/state.rs`

### Swift App layer
- Bootstrap: `Epistemos/App/AppBootstrap.swift`
- ChatCoordinator: `Epistemos/App/ChatCoordinator.swift` (N1 WRV anchor)
- RootView: `Epistemos/App/RootView.swift`

### Swift Engine layer
- StructureRegistry: `Epistemos/Engine/StructureRegistry.swift`
- AFMSessionPool: `Epistemos/Engine/AFMSessionPool.swift`
- KIVIQuantization: `Epistemos/Engine/KIVIQuantization.swift` (W9.30)
- TextCapturePipeline: `Epistemos/Engine/TextCapturePipeline.swift`

### Swift State layer
- ThermalMonitor: `Epistemos/State/ThermalMonitor.swift` (W9.29)
- PowerGate: `Epistemos/State/PowerGate.swift`

### Swift View layer
- QuickCapture: `Epistemos/Views/Capture/QuickCaptureView.swift`
- CostDashboard: `Epistemos/Views/Cost/CostDashboardView.swift` (W9.6)
- VaultSelector: `Epistemos/Views/Sidebar/VaultSelectorView.swift` (W9.7)
- ApprovalModal: `Epistemos/Views/Approval/ApprovalModalView.swift` (W9.8)
- DailyNote: `Epistemos/Views/Journal/DailyNoteView.swift` (W9.13)
- SessionIntelligenceOverlay: `Epistemos/Views/Landing/SessionIntelligenceOverlay.swift`
- TimeMachineView: `Epistemos/Views/Landing/TimeMachineView.swift`
- AgentSectionDetailView: `Epistemos/Views/Settings/AgentSectionDetailView.swift` (hosts CostDashboard)
- AuthoritySettingsView: `Epistemos/Views/Settings/AuthoritySettingsView.swift` (hosts ApprovalModal preview)
- NotesSidebar: `Epistemos/Views/Notes/NotesSidebar.swift` (hosts VaultSelector + DailyNote)

### Tests
- Benchmark scaffolds: `EpistemosTests/Benchmarks/{AFMGenerableBench,MLXThermalBench,SQLiteVecKNN,UniFFICallbackThroughput}Tests.swift` (R15)

### Build
- xcodegen source: `project.yml` (NEVER edit `.xcodeproj` directly — run `xcodegen generate`)
- Rust build: `build-rust.sh`, `build-syntax-core.sh`, `build-omega-mcp.sh`, etc.
- Tiptap bundle: `bash build-tiptap-bundle.sh`

---

## §14 — Quick-start for a fresh session

If you are a new Claude Code session opening this file for the first time:

1. Read this file end-to-end. It's everything you need.
2. Run the §9 pre-flight reads.
3. Open §7 Item queue. Find the topmost ⚪ PENDING item.
4. Implement it through §1–§6.
5. Commit per §10.
6. Update §7 status.
7. Pick the next ⚪ PENDING item.
8. Repeat until the queue is empty (§12).

If at any point you need user input: §11 (STOP triggers).

You should be able to ship 1-3 items per session day depending on item
size. Bucket A items are typically <1 hour each. Bucket B items are 1-3
hours each. Bucket C items are multi-PR efforts spanning days.

---

## §15 — Changelog

- 2026-04-27 — v1.0 — Initial creation. Consolidates the 10-file `docs/plan/` tree + dossier + tracker + N1 prompt-tree spec into a single autonomous-execution doctrine.

When this file is updated, append a dated entry here. Do not rewrite
history. Supersede with notes; never delete prior rulings.
