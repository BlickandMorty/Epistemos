# Codex Manifesto — Verbose Doc-First Protocol for Epistemos

> **Index status**: CANONICAL-OPERATIONAL — 2026-04-04 binding operating contract for Codex — two-tier research corpus protocol + docfirst search protocol.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



**Audience:** Codex (OpenAI coding agent)
**Author:** User, via Claude
**Date:** 2026-04-04
**Status:** Binding operating contract. Read this BEFORE touching any code. Re-read at every phase boundary.

---

## READ THIS FIRST

You are not starting from zero. The user has spent **dozens of prior sessions** researching Epistemos.

### Two-Tier Research Corpus — SEARCH BOTH EVERY TIME

**Tier 1 — `~/Downloads/` (recursive, all nested folders)**
The **pure massive research**. ~4,400+ markdown files as of 2026-04-04, across nested folders like `old research/`, conversation exports, deep dossiers. Raw research dumps, external essays, Perplexity/Claude/independent comparison docs (unified1/2/3.md style), PDFs. Unstructured and overlapping — this is where the user pastes what they find. **Search here FIRST** for every concept.

**Tier 2 — `~/Downloads/Epistemos/docs/`**
The **structured plans**. CODEX_PROMPT_CHAIN, PHASE_I_IMPLEMENTATION_GUIDE, VISION_BACKLOG, architecture docs, handoffs. Distilled, canonical. **Search here for FINAL CHECKS** after Tier 1.

You must search both tiers before writing code. Neither is sufficient alone.

For every feature, every phase, every architectural decision, there is:

- A research essay (sometimes two or three)
- A CODEX_PROMPT_CHAIN.md section with exact implementation steps
- A VISION_BACKLOG.md entry
- An architecture/audit doc
- Handoff logs from prior sessions
- Progress trackers

**You must read all of them, in full, before writing code.**

The user has explicitly said: *"I am deliberately wanting to be verbose; do not care about token cost."*

Token budget is not a constraint. Doc coverage is the constraint.

---

## THE SEVEN LAWS

### Law 1: Grep BOTH Tiers Before Code

Before you touch a single line of code for a feature, run on BOTH tiers:

```bash
# Tier 1: raw research corpus (~/Downloads/ recursive)
grep -rln "<feature-name>" ~/Downloads/ --include="*.md" --include="*.txt"
grep -rln "<primary-keyword>" ~/Downloads/ --include="*.md"
grep -rln "<related-keyword>" ~/Downloads/ --include="*.md"

# Tier 2: structured plans (project docs/)
grep -rln "<feature-name>" ~/Downloads/Epistemos/docs/
grep -rln "<primary-keyword>" ~/Downloads/Epistemos/docs/
grep -rln "<related-keyword>" ~/Downloads/Epistemos/docs/
```

Find **every** doc that mentions the feature in BOTH tiers. Not the first one. All of them. Typical split is 60–70% raw research / 30–40% structured plans.

### Law 2: Read In Full, Both Tiers

For every doc that appears in your grep results across BOTH tiers, read it end-to-end. Not the grep snippet. Not a summary. The entire file.

Expect 8–20 docs per feature (5–12 in Tier 1 raw research, 3–8 in Tier 2 structured plans). Read all of them.

If a doc is long (>2000 lines), read it in chunks — but read all chunks before coding.

Read order: **Tier 1 first** (to understand the "why" and the alternatives the user evaluated), then **Tier 2** (to see what the user committed to as the canonical plan).

### Law 3: Cross-Reference The Intersection Across Both Tiers

The spec for any feature is the **intersection** of:

**Tier 1 (raw research, `~/Downloads/`):**
1. **Research essays / dossiers** — the "why" and the alternatives evaluated
2. **Unified comparison docs** (unified1.md, unified2.md, unified3.md style) — independent sources converging on the same architecture
3. **Conversation exports** — prior session findings
4. **External PDFs / papers** — academic sources the user pulled

**Tier 2 (structured plans, `docs/`):**
5. **CODEX_PROMPT_CHAIN.md section** — the exact implementation recipe
6. **VISION_BACKLOG.md entry** — the aesthetic/UX goal
7. **PHASE_I_IMPLEMENTATION_GUIDE.md** or phase-specific guide — step-by-step protocol
8. **Architecture doc** (EPISTEMOS_FUSED_v3.md, OMEGA_ARCHITECTURE.md) — system-level constraints
9. **Handoff logs** (handoffs/YYYY-MM-DD-*.md) — what prior sessions actually shipped
10. **Progress tracker** (AGENT_PROGRESS.md, PROGRESS.md) — what's already marked done

When docs conflict between tiers or within a tier, **stop and ask the user which is authoritative.** Do not silently pick.

### Law 4: Verify Before You Build

Before implementing, grep the codebase:

```bash
grep -rn "<function-name>\|<struct-name>\|<FFI-symbol>" agent_core/ graph-engine/ substrate-core/ Epistemos/
```

Prior sessions may have landed the work. If it exists, **report it and stop.** Do not rebuild.

If partial work exists, name exactly what's there and what's missing before continuing.

### Law 5: Match The HOW, Not Just The WHAT

A spec that says:

```
mass = 1.0 + (child_count * 0.5) + (link_count * 0.2)
```

…is not "add a mass field." It is that **exact formula**.

- Variable names matter. `child_count`, not `num_children`.
- Constants matter. `0.5`, not `0.4`.
- Enum variant names matter. `RenameNote`, not `UpdateTitle`.
- FFI symbol names matter. `graph_engine_set_node_mass`, not `set_mass`.
- Default values matter. `max_velocity = 500.0`, not `480.0`.

If the docs prescribe a name, formula, or constant, use it verbatim. If you deviate, say so and explain why in the PR/commit message.

### Law 6: Cite The Doc In The Code

Every non-trivial implementation carries a comment:

```rust
// Per docs/CODEX_PROMPT_CHAIN.md §B-7 (Mass-Drag Physics):
//   mass = 1.0 + (child_count * 0.5) + (link_count * 0.2)
// child_count = outgoing "contains" edges (edge_type == 1).
```

This is not optional. When the user audits later, they trace code → comment → doc → research in seconds.

### Law 7b: The Best-Version Audit (foundation philosophy)

**For every feature, every line, every code block, every phase transition, and every audit pass: enumerate VERSIONS.**

The user's research corpus contains **multiple versions of the same concept** at different levels of rigor. A Tier 2 prompt might say "use `new_library_with_data()`" while a Tier 1 dossier in `~/Downloads/old research/` says "use `MTLBinaryArchive` — benchmarks show 100-500ms → <5ms." These are DIFFERENT versions of the same answer. The user wants the **best** version, every time.

On every audit (automatic or manual) and every feature entry, you MUST:

1. **Enumerate versions.** Grep both tiers for the concept AND its synonyms. List every distinct implementation version found. Typical count: 2–5 versions per concept.

2. **Rank them.** Weight in this order:
   - **Rigor**: benchmarks, measured numbers, Apple/academic doc citations, specific APIs. Higher rigor → higher rank.
   - **Philosophy alignment**: zero-copy, direct Metal, Rust-first, <5MB binary, in-process inference (no sidecars), truth-lives-in-Rust. Aligned → higher rank.
   - **Recency**: newer research can supersede older when tackling the same problem.
   - **Specificity**: concrete pipeline descriptor > step-by-step > hand-wave architecture.

3. **Choose the BEST version.** Not "the easiest." Not "the one in the prompt chain." Not "the one I already read." The one that delivers what the user wants per their engineering philosophy.

4. **Document the choice.** Every spec-encoding code comment names the version picked AND explains which versions were rejected + why.

5. **Surface conflicts proactively.** When Tier 2 prescribes X but Tier 1 prescribes Y-with-measurements, STOP and present both with a recommendation. Do not silently pick.

6. **Re-enumerate on every audit.** The corpus grows. A concept that had 2 versions last phase may have 4 now. The "best version" can change.

#### Automatic audit behavior

When Codex runs its automatic audits (phase audits, pre-release verification, drift checks), it MUST execute this query for every touched code block:

> "What does the current research on the user's Mac regarding this particular code block/line/feature say about how I should implement it? How many docs refer to this? Which is more valid, which is more rigorous, which aligns with the user's engineering philosophy? Is there a better version than what's currently shipped?"

If a better version exists, the audit output must flag it with: `[BEST-VERSION-DRIFT] <file>:<line> currently uses <impl-A>. Research <doc-B> describes <impl-C> with <rigor-signal>. Recommend migration because <philosophy-alignment>.`

#### Canonical example — Metal pipeline precompile (2026-04-04)

| Version | Source | Rigor | Philosophy | Recency | Verdict |
|---------|--------|-------|------------|---------|---------|
| `new_library_with_source` (status quo) | pre-2026 code | none | no measurement | old | shipped, but suboptimal |
| `new_library_with_data` (.metallib) | Tier 2: CODEX_PROMPT_CHAIN §B-1 | medium | saves ~150-300ms | 2026-03 | partial fix |
| `MTLBinaryArchive` | Tier 1: `~/Downloads/old research/Optimizing Graph Initialization Performance.md` | **high**: 100–500ms→<5ms benchmark, Apple API citations | **aligned**: direct Metal, measurable, per-GPU | 2026-03 | **BEST → shipped** |

### Law 7: Re-Grep Both Tiers Between Phases

Your mental model of the spec drifts as you work. Before starting a new subphase:

1. Re-grep Tier 1 (`~/Downloads/`) for the next subphase's feature name
2. Re-grep Tier 2 (`~/Downloads/Epistemos/docs/`) for the same
3. Re-read the top-ranked docs in both tiers
4. Re-verify your understanding before the first line of new code

Note: the user periodically drops new research into `~/Downloads/` mid-project. A doc that didn't exist at Phase N may be the authoritative source by Phase N+1.

---

## THE PHASE EXECUTION LOOP

For every feature or phase:

```
1. DISCOVER
   - grep ~/Downloads/ recursive (Tier 1: raw research)
   - grep ~/Downloads/Epistemos/docs/ (Tier 2: structured plans)
   - list EVERY matching doc from BOTH tiers
   - grep codebase for existing impl

2. READ
   - read every matching doc IN FULL, Tier 1 first then Tier 2
   - note conflicts within and across tiers
   - ask the user when docs conflict

2b. ENUMERATE VERSIONS (Law 7b)
   - list every distinct IMPLEMENTATION VERSION of this concept found across docs
   - rank by rigor → philosophy → recency → specificity
   - pick the BEST version (not the easiest)
   - document rejected versions + why

3. VERIFY
   - does this already exist?
   - what's done, what's open, what's wrong?

4. CONFIRM
   - summarize the cross-doc spec back to the user
   - surface any conflicts found
   - wait for explicit go-ahead

5. IMPLEMENT
   - cite doc + section in EVERY code comment that encodes a spec
   - match names, formulas, constants verbatim
   - add spec-traceable tests

6. AUDIT
   - re-read the docs → compare to your code
   - re-enumerate versions (corpus may have grown since IMPLEMENT)
   - flag [BEST-VERSION-DRIFT] if a better version now exists
   - fix drift
   - verify zero test regressions

7. COMMIT + LOG
   - update docs/AGENT_PROGRESS.md
   - write docs/handoffs/YYYY-MM-DD-<phase>.md
   - link code → doc sections in the commit message
```

---

## THE MULTI-MONTH PLAN

These are the known phases. Each has its own doc cluster — read the whole cluster before starting the phase.

| Phase | Scope | Doc Cluster (read ALL of these before starting) |
|-------|-------|-------------------------------------------------|
| **A** Provider Overhaul | Provider trait, settings, OAuth, mode selector, triage | `CODEX_PROMPT_CHAIN.md §A-1..A-9`, `HERMES_INTEGRATION_RESEARCH.md`, `AGENT_DEEP_VERIFICATION_MANUAL.md`, `AGENT_PROGRESS.md`, `OMEGA_ARCHITECTURE.md` |
| **B** Graph-First | SDF labels, mass-drag, shadows, idle drift, theming, perspective layers | `CODEX_PROMPT_CHAIN.md §B-1..B-9`, `GRAPH_SDF_LABEL_RESEARCH_PROMPT.md`, `VISION_BACKLOG.md §3-PRIME/SHADOW/GRAPH/PHYSICS`, `docs/plans/2026-03-07-graph-physics-performance-plan.md` |
| **C** Agent Parity | CodeNano tools, Hermes feature parity, session lifecycle, control plane UI | `CODEX_PROMPT_CHAIN.md §C-1..C-5`, `HERMES_PARITY_REPORT.md`, `CONTROL_PLANE_RESEARCH.md`, `BEST_OF_CLAW_AND_OPENCLAW.md` |
| **D** Knowledge Brick | Tabs, command bar, inline settings | `CODEX_PROMPT_CHAIN.md §D-1..D-4`, `INSTANT_RECALL_ARCHITECTURE.md` |
| **I** Rust Migration | Goose bridge, builtin extensions, GEPA, Python elimination | `PHASE_I_IMPLEMENTATION_GUIDE.md`, `GOOSE_AGENT_RESEARCH.md`, `GOOSE_AGENT_RESEARCH_2.md`, `GOOSE_REPLACEMENT_STRATEGY.md` |
| **Substrate** | EntityID unification, AppAction event log, window singularity (Sprints 1–5, woven through all phases) | `UNIFIED_SUBSTRATE_RESEARCH.md`, `~/Downloads/unified 1.md`, `~/Downloads/unified2.md`, `~/Downloads/unified 3.md` |
| **H** Release | MAS compliance, distribution, hardening | `MASTER_SESSION_PROMPT_v2.md`, `FINAL_VERIFICATION_CHECKLIST.md`, `HARDENING_VERIFICATION.md` |

**Important:** Substrate is not a separate block. It weaves through every phase. EntityID must be live before graph/agent/sidebar fully integrate with it.

---

## WHAT "DONE" MEANS

A phase is done when **all** of these are true:

1. Every spec from every doc in the phase's cluster is either implemented or explicitly deferred in writing
2. Every code path that encodes a spec cites its doc section in a comment
3. Spec-traceable tests exist and pass (e.g. `mass_follows_codex_b7_spec`)
4. Zero regressions in the 2,679-test suite OR explicit written acceptance of new failures with justification
5. `docs/AGENT_PROGRESS.md` updated with ✅ and date
6. A handoff doc written at `docs/handoffs/YYYY-MM-DD-<phase>.md`

---

## WHAT YOU WILL NOT DO

- **Do not skip docs** because "I read one that covers it." Read every doc in the cluster.
- **Do not guess** formulas, constants, variable names, or enum variants the docs specify.
- **Do not use simplified/made-up names** instead of the names in the spec.
- **Do not refactor** beyond what the docs explicitly ask for.
- **Do not pre-optimize** in ways the research explicitly warns against (e.g. Law 4 of UNIFIED_SUBSTRATE_RESEARCH: UniFFI stays until profiling proves otherwise).
- **Do not add fallbacks**, feature flags, or backwards-compat shims not in the docs.
- **Do not touch Swift** when the user says "Rust only."
- **Do not mark items done** in AGENT_PROGRESS.md until verification commands pass.
- **Do not silently pick** between conflicting docs — surface the conflict and ask.
- **Do not trust memory** over a fresh grep — your mental model drifts.

---

## SESSION START CHECKLIST

Every new session, before the first line of code:

- [ ] Read `CLAUDE.md`
- [ ] Read `docs/CLAUDE_UPGRADE_PLAN_SYNOPSIS.md`
- [ ] Read `docs/AGENT_PROGRESS.md` — what's next?
- [ ] Read `docs/APP_ISSUES_AUTO_FIX.md` — any open issues?
- [ ] Read the current sprint file in `docs/sprint-sessions/`
- [ ] Read the latest `docs/handoffs/` log
- [ ] For the target feature: grep `~/Downloads/` recursive (Tier 1 raw research), read every matching doc IN FULL
- [ ] For the target feature: grep `~/Downloads/Epistemos/docs/` (Tier 2 structured plans), read every matching doc IN FULL
- [ ] For the target feature: grep the codebase to see what exists
- [ ] **For the target feature: enumerate every IMPLEMENTATION VERSION found across both tiers, rank them, pick the BEST (Law 7b)**

Only then do you write code.

---

## BINDING COMMITMENT

Before I write a single line of code for any feature, I will:

1. Grep `~/Downloads/` recursive (Tier 1 raw research) for every document mentioning this feature
2. Grep `~/Downloads/Epistemos/docs/` (Tier 2 structured plans) for the same
3. Read them all in full, Tier 1 first
4. Grep the codebase to verify what already exists
5. **Enumerate every IMPLEMENTATION VERSION found across both tiers (Law 7b)**
6. **Rank the versions by rigor → philosophy → recency → specificity, pick the BEST**
7. Summarize the cross-tier, cross-doc spec + version verdict to the user
8. Confirm direction
9. Cite specific doc sections (noting which tier, which version) in every code comment that encodes a spec
10. Write spec-traceable tests
11. Re-audit against BOTH tiers after implementation, re-enumerate versions, flag drift

The user has paid for this in research time — months of gathering raw research into `~/Downloads/` and distilling it into `docs/`. I will not waste it by reading one doc when five exist, or one tier when two exist, or shipping the Tier 2 literal version when a better Tier 1 version sits on disk.
