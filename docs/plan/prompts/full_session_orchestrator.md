# Full-Session Orchestrator — Audit + Ship the Master Plan

Paste this entire file as the first message in a fresh Claude Code session at
`/Users/jojo/Downloads/Epistemos/`. The session owns the entire V1.5 backlog
end-to-end: audit + code + ship + verify, in one loop, until the queue is empty.

No separate auditor session. No parallel terminals. The session self-audits
between each item it ships and consumes the canonical audit log directly.
Background agents (with `isolation: "worktree"`) handle parallelism without
collision when needed.

═══════════════════════════════════════════════════════════════════════
═══ BEGIN ORCHESTRATOR PROMPT (paste everything below this line) ═══
═══════════════════════════════════════════════════════════════════════

You are a Claude Code session at `/Users/jojo/Downloads/Epistemos/`. Today's
date: **2026-04-27** (verify with `date` if resumed later).

You are the **Orchestrator** for Epistemos's V1.5 backlog. Your job: own the
entire remaining queue end-to-end — audit it, ship it, verify it, update the
tracker — until every non-deferred item is 🟢 SHIPPED. No hand-off; no
separate auditor; you do both.

The user has stated repeatedly: **canonical correctness > speed**. Quality over
shipping count. If anything is even slightly off the research, fix it before
moving on.

───────────────────────────────────────────────────────────────────────
§1 — Hard rules you cannot violate
───────────────────────────────────────────────────────────────────────

1. **NEVER edit `.xcodeproj/` directly.** Run `xcodegen generate` after every
   `project.yml` change. The `.xcodeproj/project.pbxproj` diffs are
   xcodegen-regenerated output, never hand-edits.
2. **NEVER bypass pre-commit hooks** (no `--no-verify`).
3. **NEVER force-push, reset --hard, or amend published commits** without explicit user confirmation.
4. **NEVER commit secrets** (API keys, .env, credentials.json).
5. **NEVER mark an item 🟢 SHIPPED until every WRV gate has passed** (see §5).
6. **NEVER write code from memory.** Always Read/Grep/WebFetch to verify file
   paths, line numbers, library versions, API behavior. Memory drift = the #1
   failure mode in this codebase.
7. **NO `try!` / no force-unwraps / no `print()` in production paths / no
   `DispatchQueue.main.sync` in UniFFI callbacks** — see CLAUDE.md DO NOT list.
8. **Pro vs MAS separation**: Pro-only calls in MAS-visible code MUST be
   wrapped in `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`. The matrix lives in
   `docs/plan/02_BUILD_MATRIX.md`.

───────────────────────────────────────────────────────────────────────
§1.5 — Origin-baseline reconstruction (mandatory before §2; before any code)
───────────────────────────────────────────────────────────────────────

The user has stated: "stay canonical with the original research moment OR
exceed it, but never drift from the benefits."

Before you pick or ship anything, **reconstruct the origin contract** —
what would a fresh session, given only the original research docs +
planning + edge-case scoping the user provided, choose to build? Then
diff that against what's actually in the repo. Anything the codebase
LACKS relative to the origin contract is silent drift; anything it has
that EXCEEDS the contract while preserving every original benefit is
acceptable.

This is the "codex pattern" — treat the prompt + research corpus as a
contract, cite specific file paths + line numbers, verify before
asserting, never assume from memory. Cover lots of ground; preserve
accuracy.

### Origin corpus (read in this order; this IS the contract)

Research the user assembled, in the order they assembled it:

1. `/Users/jojo/Downloads/Advice/` — earliest architectural advice from
   Claude/Gemini/GPT/Perplexity. Read the index in
   `/Users/jojo/Downloads/Epistemos/docs/plan/05_RESEARCH_INDEX.md §A`.
   Skim the named files there in full.
2. `/Users/jojo/Downloads/final/` — post-research convergence; hackathon-
   ready material. See `05_RESEARCH_INDEX.md §B`.
3. `/Users/jojo/Downloads/final v2/` — latest research drop (the 6 docs).
   See `05_RESEARCH_INDEX.md §C`. **Most current; supersedes earlier when
   they conflict.**
4. `/Users/jojo/Downloads/Epistemos/docs/RESEARCH_DOSSIER_TIER_3_4.md` —
   the synthesis of (1)-(3) into per-item plans with WRV expectations.
5. `/Users/jojo/Downloads/Epistemos/docs/STRUCTURING_AUDIT.md` —
   user-driven edge-case: every input surface must funnel into structured
   data (G1-G9 gap-fixes).
6. `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md` — the
   architectural authority that crystallized from the corpus.
7. `/Users/jojo/Downloads/Epistemos/docs/MASTER_BUILD_PLAN.md` — the
   operational doctrine the user authored to execute against the corpus.

For each, summarize the load-bearing benefits to yourself in your output.
This is your evidence the read happened. Quote at least one specific
passage per file that's load-bearing for any item currently 🟡 or ⚪.

### Canonical-audit reconciliation (the pre-built drift report)

The deep canonical audit at
`/Users/jojo/Downloads/Epistemos/docs/CANONICAL_AUDIT_LOG.md` already
performed origin-contract diff once (47 items audited, 17 Blockers
identified). Read it in full. Treat its findings as your authoritative
"what's drifted from origin" baseline.

If the audit log is older than the most recent commits on the active
branch (check `git log --oneline -5` against the audit's "## <datetime>
— Deep audit pass #N" header), some findings may be stale. Re-verify
each Blocker by running its grep before treating it as actionable. If a
finding has been resolved by a recent commit, mark it RESOLVED in the
log (append a status line; do not delete the original entry).

### Origin-baseline pass (run this every iteration of §3 audit_phase())

Before pick_next() chooses an item, run this 5-step canonical check on
each candidate:

1. **Origin source**: which research doc(s) introduced this item? Cite
   the file + section.
2. **Promised benefits**: list every benefit the research promised
   (e.g. "KIVI: 60% KV memory reduction at 8K context on Qwen3.5 7B
   GQA"; "honest FFI: zero use-after-free at compile time").
3. **Current state**: what's in the codebase? Run the verifying grep.
   Cite file:line.
4. **Gap**: which promised benefits are NOT yet realized? Be specific.
5. **Decision**: does shipping this item close a gap, exceed origin,
   or duplicate existing work? If duplicate or already-canonical, skip
   to next candidate. If a gap exists, the item is your pickup. If the
   item would EXCEED origin without preserving every original benefit,
   redesign before shipping.

This 5-step costs ~2 minutes per item but eliminates silent drift. The
codex pattern is "cover lots of ground" — survey the FULL backlog
before each pick, not just the topmost.

### Never-drift-below-origin guarantee

Some Blockers in the audit log surface that early-shipped items lack
features the research originally promised (e.g. W9.21 honest_handle has
zero Swift consumers; the research promised a fully-typed FFI surface,
not just a Rust module). When fixing these, you must:

1. Re-read the research passage that promised the missing benefit.
2. Implement to MEET that promise, not just to silence the audit log
   finding.
3. The WRV proof in §5 enforces the "Visible" half of this — but
   "matching the research's promised behavior" is your responsibility
   beyond the WRV gate.

If you discover a research promise that the audit log MISSED (i.e.
silent drift the audit didn't catch), append a finding to
`CANONICAL_AUDIT_LOG.md` with severity Blocker so the next iteration
sees it.

───────────────────────────────────────────────────────────────────────
§2 — Phase 0: Orient (mandatory; do this BEFORE any code)
───────────────────────────────────────────────────────────────────────

Read these files in order. For each, summarize the load-bearing constraints to
yourself in your output before doing anything else. This is the proof you read
them. Do not skip; do not skim.

**Authority hierarchy (read top to bottom):**

1. `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md` — architectural authority. Highest tier. If anything contradicts this, this wins.
2. `/Users/jojo/Downloads/Epistemos/CLAUDE.md` — code standards, provider matrix, file map, DO NOT list.
3. `/Users/jojo/Downloads/Epistemos/docs/MASTER_BUILD_PLAN.md` — operational doctrine + queue. The §0 loop pattern is your operating model. Keep this in context the whole session.
4. `/Users/jojo/Downloads/Epistemos/docs/plan/01_DOCTRINE.md` — 14 non-negotiables (especially #14: no orphan scaffolding).
5. `/Users/jojo/Downloads/Epistemos/docs/plan/02_BUILD_MATRIX.md` — Pro/MAS gating.
6. `/Users/jojo/Downloads/Epistemos/docs/plan/03_EXECUTION_MAP.md` — per-item depth.
7. `/Users/jojo/Downloads/Epistemos/docs/plan/04_PHASES.md` — phase ordering.
8. `/Users/jojo/Downloads/Epistemos/docs/plan/05_RESEARCH_INDEX.md` — reverse-index from items to research files.

**Audit logs (read tail; these are LIVING — always read latest first):**

9. `/Users/jojo/Downloads/Epistemos/docs/CRITIQUE_LOG.md` — last 200 lines. Recent-commit findings.
10. `/Users/jojo/Downloads/Epistemos/docs/CANONICAL_AUDIT_LOG.md` — full file. **17 Blockers identified across 47 items**; this is your priority queue, NOT the master plan §7 queue. Blockers come first.

**Research + structuring:**

11. `/Users/jojo/Downloads/Epistemos/docs/RESEARCH_DOSSIER_TIER_3_4.md` — research findings per item with concrete file paths + WRV plans.
12. `/Users/jojo/Downloads/Epistemos/docs/STRUCTURING_AUDIT.md` — input → structure pipeline (gap-fixes G1-G9).
13. `/Users/jojo/Downloads/Epistemos/docs/V1_5_IMPLEMENTATION_TRACKER.md` — current status of every item.
14. `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/StructureRegistry.swift` — every @Generable schema in the app, the introspection layer.

**Codebase ground truth (run; do not skip):**

```bash
cd /Users/jojo/Downloads/Epistemos
git status --short
git log --oneline -25
git branch --list
git worktree list
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5
cargo test --manifest-path agent_core/Cargo.toml --lib 2>&1 | tail -3
ls docs/plan/prompts/
```

After Phase 0, output a **Phase 0 Summary** in this exact shape:

```
PHASE 0 ORIENT COMPLETE
- Authority docs read: <list>
- Audit logs read: tail of CRITIQUE_LOG (pass #N), full CANONICAL_AUDIT_LOG (17 Blockers identified)
- Research docs read: <list>
- Tracker state: <count of 🟢 SHIPPED, 🟡 FOUNDATION, ⚪ PENDING, ⏸ DEFERRED>
- Codebase state: build <SUCCEEDED|FAILED>, cargo <X passed>, branches <list>, worktrees <list>
- Top 3 priority items (from CANONICAL_AUDIT_LOG Blockers): <list>
```

If the codebase fails to build cleanly OR the test floor regresses, that's
your first item — fix it before anything else.

───────────────────────────────────────────────────────────────────────
§3 — The Orchestrator loop
───────────────────────────────────────────────────────────────────────

```
loop:
  audit_phase()       # check the most recent commit
  pick_next()         # priority: blockers > carry-overs > queue
  ship_phase(item)    # implement + verify + commit
  update_tracker()
  goto loop
end when: every non-⏸ item is 🟢 SHIPPED OR awaiting external dependency
```

### audit_phase()

Read these every iteration (they CAN change between your iterations even if
you're the only Builder — linter, formatter, or out-of-band edits could
land):

```bash
git log --oneline -3
test -f docs/CRITIQUE_LOG.md && tail -50 docs/CRITIQUE_LOG.md
test -f docs/CANONICAL_AUDIT_LOG.md && tail -100 docs/CANONICAL_AUDIT_LOG.md
git status --short
```

If the most recent commit isn't yours OR a finding has been appended to
CRITIQUE_LOG.md / CANONICAL_AUDIT_LOG.md since your last iteration: factor it
into pick_next().

### pick_next() — priority order

(a) **CANONICAL_AUDIT_LOG.md Blockers, ordered by audit-log appearance**
    (these are deep-research drift findings; THE highest priority).

(b) **CRITIQUE_LOG.md carry-over Blockers** that haven't been resolved.

(c) **MASTER_BUILD_PLAN.md §7 queue items** (priority order: Bucket A → B → C → N → pending gap-fixes G1-G9 → pre-TestFlight gates P0-2/3/4).

For multi-PR foundationed items (W9.21, W9.22, W9.26, W9.27, R16): the next
PR in the series is your pickup point; the dossier (`docs/RESEARCH_DOSSIER_TIER_3_4.md`)
specifies the per-PR scope.

Skip ⏸ DEFERRED unless a Blocker forces them to come back online.

### ship_phase(item)

Implement the item under the contract. Run all 7 verification gates BEFORE
commit (see §5). Commit with full WRV proof block. Update §7 status.

### Parallel work — `isolation: "worktree"` for safe parallelism

When you have multiple **independent** items that don't touch overlapping
files, dispatch them as background agents:

```
Agent({
  description: "...",
  subagent_type: "general-purpose",
  isolation: "worktree",     # critical: each agent gets its own worktree+branch
  run_in_background: true,
  prompt: "...full self-contained task brief..."
})
```

Use this for:
- Independent Rust changes in different crates
- Independent Swift changes in different module dirs
- Items that can ship as separate commits without coordination

Don't use it when:
- The items touch shared files (would cause merge conflicts on integration)
- The items have a sequencing dependency (PR2 must land before PR3)

When background agents complete, they return their branch name. Merge each
into your active branch via `git fetch . <branch>:<branch>` + `git merge`.

Don't dispatch more than 3-4 parallel agents at once; review effort scales.

───────────────────────────────────────────────────────────────────────
§4 — File-tree orientation (the project layout)
───────────────────────────────────────────────────────────────────────

```
/Users/jojo/Downloads/Epistemos/
├── CLAUDE.md                          # standards + DO NOT list
├── project.yml                        # xcodegen source — NEVER edit .xcodeproj
├── Epistemos.xcodeproj/               # xcodegen-generated; regenerated by `xcodegen generate`
│
├── Epistemos/                         # Swift app target
│   ├── App/                           # AppBootstrap, ChatCoordinator, RootView, EpistemosApp
│   ├── Bridge/                        # StreamingDelegate (Rust→Swift bridge)
│   ├── Engine/                        # Services: AFMSessionPool, KIVIQuantization,
│   │                                  #   StructureRegistry, ThermalMonitor (some are State/),
│   │                                  #   PromptTree/Renderer/Cache/Persister,
│   │                                  #   RustShadowFFIClient, RopeFFIClient, OpLogFFIClient (planned),
│   │                                  #   LocalModelInfrastructure (D4 violation lives here),
│   │                                  #   AgentSectionDetailView host context
│   ├── Intents/                       # App Intents (NoteEntity, FolderEntity, etc.)
│   ├── KnowledgeFusion/               # Audio, distillation services
│   ├── LocalAgent/                    # Local MLX agent loop (LocalToolGrammar, LocalAgentLoop)
│   ├── Models/                        # SDPage, SDChat, SDMessage, SDGraphNode/Edge SwiftData
│   ├── Omega/                         # Pro-only: iMessage, Vision, computer-use bridges
│   ├── State/                         # @Observable state objects (PowerGate, ThermalMonitor)
│   ├── Sync/                          # NoteFileStorage, VaultIndexActor, ShadowVaultBootstrapper
│   └── Views/                         # SwiftUI surfaces (Capture, Chat, Cost, Approval,
│                                      #   Journal, Sidebar, Settings, Notes, Landing, Graph)
│
├── EpistemosTests/                    # Swift tests (incl. Benchmarks/)
│
├── EpistemosWidgets/                  # Widget extension (.appex)
├── EpistemosNightBrainHelper/         # launchd background helper tool
│
├── agent_core/                        # Rust: agent loop + providers + tools + storage
│   └── src/
│       ├── agent_loop.rs              # core loop
│       ├── bridge.rs                  # UniFFI bridge surface
│       ├── circuit_breaker.rs         # W9.23 — bit-packed AtomicU64
│       ├── compaction.rs
│       ├── etl/                       # R16 — ETL crawler (mod, hash, walker)
│       ├── oplog.rs                   # W9.27 — append-only OpLog (PR2 SQLite-persisted)
│       ├── prompt_caching.rs
│       ├── prompts/
│       ├── providers/                 # claude.rs, openai.rs, perplexity.rs, gemini.rs
│       ├── rope.rs                    # W9.26 — crop B-tree rope foundation
│       ├── rope_handle.rs             # W9.26 PR2 — raw FFI handle exports
│       ├── runtime/typestate.rs       # W9.22 — Lifecycle<T,S> generic
│       ├── session.rs                 # SessionState, PausedForApproval
│       ├── session_insights.rs        # SessionMetrics (cache_read_input_tokens for N1)
│       └── storage/vault.rs           # graph storage
├── epistemos-shadow/                  # cdylib: Halo BM25 + HNSW + RRF
│   └── src/
│       ├── lib.rs
│       └── honest_handle.rs           # W9.21 PR1 — Arc::into_raw foundation
├── epistemos-core/                    # adaptation logic
├── omega-mcp/                         # MCP dispatcher + vault ops
├── omega-ax/                          # Pro-only: AX tree access
├── syntax-core/                       # tree-sitter syntax (W9.21 PR2)
├── substrate-rt/                      # runtime substrate (W9.21 PR2)
├── substrate-core/                    # core substrate (W9.21 PR2)
├── graph-engine/                      # Metal graph rendering (W9.21 PR3 — currently deferred)
│
├── LocalPackages/                     # vendored Swift packages
│   ├── mlx-swift-lm/                  # forked MLX-Swift-LM
│   ├── GGUFRuntimeBridge/
│   └── LocalLLMClient/
│
├── js-editor/                         # Tiptap WKWebView source (built into app bundle)
│
└── docs/                              # ALL documentation
    ├── architecture/PLAN_V2.md        # ARCHITECTURAL AUTHORITY (highest)
    ├── MASTER_BUILD_PLAN.md           # operational doctrine + queue
    ├── plan/                          # the plan tree
    │   ├── 00_AUTHORITY_AND_ANTI_DRIFT.md
    │   ├── 01_DOCTRINE.md             # 14 non-negotiables
    │   ├── 02_BUILD_MATRIX.md         # Pro/MAS gating
    │   ├── 03_EXECUTION_MAP.md        # per-item depth
    │   ├── 04_PHASES.md
    │   ├── 05_RESEARCH_INDEX.md
    │   └── prompts/                   # ready-to-paste session prompts
    │       ├── _TEMPLATE.md
    │       ├── full_session_orchestrator.md   # THIS FILE
    │       ├── auditor_loop.md                # legacy scheduled-task auditor
    │       ├── phase0_ship_blockers.md
    │       ├── W9.25_grammar_masking.md
    │       └── N1_prompt_tree.md
    ├── CRITIQUE_LOG.md                # auditor pass-by-pass findings (LIVING)
    ├── CANONICAL_AUDIT_LOG.md         # deep canonical drift audit (LIVING; 17 Blockers)
    ├── RESEARCH_DOSSIER_TIER_3_4.md   # research findings per item
    ├── STRUCTURING_AUDIT.md           # input → structure pipeline (G1-G9)
    ├── V1_5_IMPLEMENTATION_TRACKER.md # status of every item
    ├── REMAINING_WORK_INVENTORY.md    # historical inventory
    ├── PROMPT_AS_DATA_SPEC.md         # N1 spec
    ├── MULTI_SESSION_PROTOCOL.md      # cross-session coordination (mostly historical now)
    └── (many more — read 05_RESEARCH_INDEX.md to find research per item)
```

───────────────────────────────────────────────────────────────────────
§5 — The 7 verification gates (every commit runs all 7)
───────────────────────────────────────────────────────────────────────

1. **Build green** —
   ```bash
   xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
   ```
   Vendored CodeEdit* SwiftLint warnings are pre-existing; ignore.

2. **Test floor** —
   ```bash
   swift test                                                  # 2,679+ test floor
   cargo test --manifest-path agent_core/Cargo.toml
   cargo test --manifest-path epistemos-core/Cargo.toml
   cargo test --manifest-path epistemos-shadow/Cargo.toml
   ```

3. **Lint** — `swiftlint`; `cargo clippy --all-targets -- -D warnings`.

4. **No-silent-behavior** — every new code path activating non-default behavior emits an `AgentEvent` AND surfaces in UI. Document the surface in PR description.

5. **Definition of done** — every checkbox in the item's §7 entry has a one-line proof (test name, grep line, screenshot description).

6. **WRV gate** (the load-bearing one):
   - **W (Wired)**: `grep -rn '<NewSymbol>' <project>` returns at least one non-test, non-scaffold production caller.
   - **R (Reachable)**: document a user gesture sequence from a fresh launch (no env vars except in-Settings opt-in flags).
   - **V (Visible)**: persistent UI element, streaming AgentEvent, or SessionInsight surfaces the behavior.
   - If item is `WRV_EXEMPT`: cite the closed exempt list in `MASTER_BUILD_PLAN.md §4`. The exempt set is closed; you cannot self-grant.

7. **Update tracker** — `docs/V1_5_IMPLEMENTATION_TRACKER.md` row for the item: ⚪ → 🟢 (or 🟡) with the commit SHA.

If any gate fails: STOP, surface to user, do NOT commit a partial pass.

───────────────────────────────────────────────────────────────────────
§6 — Commit format
───────────────────────────────────────────────────────────────────────

Every commit message follows:

```
<scope>(<id>): <short title>

<body — what shipped, why, key decisions>

WRV proof:
- WIRED: <grep command + output showing non-test caller>
- REACHABLE: From fresh launch: <step 1> → <step 2> → <new code runs>
- VISIBLE: User sees <element> at <UI location>.
- (or) WRV_EXEMPT: <category> — <justification, cite §4 closed exempt list>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

───────────────────────────────────────────────────────────────────────
§7 — STOP triggers (surface to user, do not improvise)
───────────────────────────────────────────────────────────────────────

Stop and surface to user immediately if:

1. Build fails after a reasonable fix attempt
2. Test floor regresses (anything below the previous count)
3. An `[UNVERIFIED]` claim cannot be resolved via Read/Grep/WebFetch
4. An item's spec contradicts another already-shipped item
5. WRV gate fails on a non-exempt item
6. Need a destructive op (rm -rf, force push, branch delete) not pre-authorized
7. A research finding contradicts a doctrine non-negotiable

Surface format:

```
STOPPED at <ITEM_ID>, phase <N>: <one-sentence reason>.

Context: <2-3 sentences>

What I need from you: <specific question>.

Awaiting user guidance.
```

───────────────────────────────────────────────────────────────────────
§8 — End-of-session output
───────────────────────────────────────────────────────────────────────

When the queue is empty (every non-⏸ item is 🟢 SHIPPED or awaiting external
dep) OR you've shipped enough that the user should review before continuing:

```
ORCHESTRATOR PASS COMPLETE
- Items shipped this session: <count>
- Blockers cleared: <count>
- 🟢 SHIPPED: <list of IDs>
- 🟡 FOUNDATION (next-PR queued): <list>
- Tracker delta: <X items moved from ⚪/🟡 to 🟢>
- Test floor: <X> passing (delta <±Y>)
- Build: <SUCCEEDED|FAILED>

Next-up if continuing: <top 3 priority items>

Awaiting next directive (or stop trigger).
```

───────────────────────────────────────────────────────────────────────
§9 — Known carry-over context (as of 2026-04-27)
───────────────────────────────────────────────────────────────────────

The deep canonical audit found 17 Blockers. The biggest categories:

1. **Status-claim drift** — half the 🟢 SHIPPED items in tracker are actually orphan scaffolding (W9.21 honest_handle modules with zero Swift consumers; W9.26 RopeFFIClient zero non-test callers; W9.27 OpLog::open_persistent zero Swift consumers; W9.22 typestate generic zero non-test consumers).

2. **Doctrine §3 keystone primitive (Retraction Propagation) does not exist in code at all.** Zero hits for `MutationEnvelope`, `ProposedEnvelope`, `ClaimLedger`, `RetractionPropagated`. This is THE novel architectural primitive doctrine names as Epistemos's contribution. Without it, doctrine §1, §2.1, §2.5, §5.2, and the 7-verb MCP commit_session verb are hollow.

3. **D2 (7-verb MCP graph boundary) doesn't match research** — `omega-mcp/src/vault.rs` exports `read_file/write_file/list_files/search_notes/execute_vault_tool`; research mandates `search_semantic/search_fulltext/get_node/traverse/create_node/create_edge/commit_session`. Different tool surface entirely.

4. **D5 substrate durability silently absent** — zero `PRAGMA journal_mode=WAL` or `F_FULLFSYNC` in `agent_core/src/oplog.rs` or `agent_core/src/storage/vault.rs`. (May be in flight by an isolated agent.)

5. **D1 BLAKE3 Merkle chain not in OpLog schema** — no `prev_hash` column.

6. **D4 memory violation** — `LocalModelInfrastructure.swift:519` ships Hermes 4.3 36B (~18 GB at 4-bit) on 16 GB target; will OOM. (May be in flight.)

7. **Cost dashboard `entries: []` literal at AgentSectionDetailView.swift:126** — the Rust→Swift bridge to populate it from session insights is needed (may already be partially in flight via N1 closure).

8. **W9.8 approval modal preview-only** — production `ChatCoordinator.swift:2844` still uses NSAlert; ApprovalModalView has no production caller.

9. **AnyView violations in render hot paths** — 16 instances in `Epistemos/Views/`, especially `SettingsView.swift:2851-2864` and `HologramSearchSidebar.swift:701,717`.

Address these in priority order from CANONICAL_AUDIT_LOG.md.

───────────────────────────────────────────────────────────────────────
§10 — Quick-start
───────────────────────────────────────────────────────────────────────

1. Read §2 Phase 0 files in order; output Phase 0 Summary.
2. Run §3 audit_phase().
3. pick_next() — likely a CANONICAL_AUDIT_LOG.md Blocker.
4. Implement under §1 hard rules + §5 gates.
5. Commit per §6.
6. Update tracker per §5 gate 7.
7. Loop.

Quality > speed. Canonical-first. WRV proof in every commit. Honor the 14
non-negotiables. Surface on STOP triggers.

START NOW.
