# Claude's Synopsis — How I Will Treat the Epistemos Multi-Month Upgrade Plan

**Author:** Claude (Opus 4.6, 1M context)
**Date:** 2026-04-04
**Audience:** User + future Claude sessions
**Status:** Binding operating contract

---

## The Two-Tier Research Corpus

There are **two search tiers**, and I must search both every time:

**Tier 1 — `~/Downloads/` (recursive, including nested folders)**: The **pure massive research**. ~4,400+ markdown files as of 2026-04-04, across nested folders (`old research/`, conversation exports, etc.). Raw research dumps, external research essays, Perplexity/Claude/independent dossiers, unified1/2/3-style comparison docs, ebooks, PDFs, paper drafts. This is where the user pastes what they find online and in sessions. It's unstructured, overlapping, sometimes contradictory. **Search here FIRST** for every new concept.

**Tier 2 — `~/Downloads/Epistemos/docs/` (the project repo)**: The **structured plans**. CODEX_PROMPT_CHAIN, PHASE_I_IMPLEMENTATION_GUIDE, VISION_BACKLOG, architecture docs, handoffs, progress trackers. This is where the raw research has been distilled into actionable specs. **Search here for FINAL CHECKS** after Tier 1, to see what the user has committed to as the canonical plan.

Neither tier is sufficient alone:
- Tier 1 without Tier 2 → I miss the user's architectural decisions and final scope
- Tier 2 without Tier 1 → I miss the "why" and the alternatives the user evaluated

```bash
# Tier 1: raw research
grep -rln "<feature>" ~/Downloads/ --include="*.md" --include="*.txt" --include="*.pdf"
# Tier 2: structured plans
grep -rln "<feature>" ~/Downloads/Epistemos/docs/
```

## The Core Realization

The user has spent **dozens of prior sessions** researching each feature and phase of Epistemos. Every feature has:

- A **research essay** (GOOSE_AGENT_RESEARCH.md, HERMES_INTEGRATION_RESEARCH.md, GRAPH_SDF_LABEL_RESEARCH_PROMPT.md, UNIFIED_SUBSTRATE_RESEARCH.md, CONTROL_PLANE_RESEARCH.md, etc.)
- An **implementation prompt / protocol** (CODEX_PROMPT_CHAIN.md §A-1..I-3, PHASE_I_IMPLEMENTATION_GUIDE.md, IMPLEMENTATION_PROMPTS.md)
- A **vision backlog entry** (VISION_BACKLOG.md §3-PRIME, §3-SHADOW, §3-GRAPH, §3-PHYSICS, etc.)
- An **architecture/audit doc** (ARCHITECTURE_AUDIT.md, EPISTEMOS_FUSED_v3.md, OMEGA_ARCHITECTURE.md)
- **Handoff logs** (handoffs/2026-*.md)
- **Progress trackers** (AGENT_PROGRESS.md, PROGRESS.md, PHASE_CHECKLIST.md, APP_ISSUES_AUTO_FIX.md)

There is no single "the spec" for any feature. The spec is **the intersection** of all of these docs. When I read one and skip the others, I drift. Every disconnect in prior sessions has traced back to reading fewer docs than exist.

The user has explicitly said: **"I am deliberately wanting to be verbose; do not care about token cost."**

## Foundation Philosophy — The Best-Version Audit

**The user's research corpus contains multiple VERSIONS of every concept at different levels of rigor. My job, every single time, is to enumerate those versions and ship the BEST one.**

This is not a "nice-to-have." It is the operating substrate of every audit, every phase transition, and every feature implementation. I do it automatically, as second nature, without being asked. If I ever write code without first asking "which version of this does the user's research recommend as best?" I have failed the protocol.

### The Best-Version Loop (runs continuously)

1. **Enumerate.** For any concept/line/feature, grep both tiers for the concept and its synonyms. List every distinct implementation version found. Typical count: 2–5 versions per concept.

2. **Rank.** Apply weights in order:
   - **Rigor**: benchmarks, measured numbers, Apple/academic doc citations, specific API names. Higher rigor → higher rank.
   - **Philosophy alignment**: zero-copy, direct Metal, Rust-first, <5MB binary, in-process inference (no sidecars), truth-lives-in-Rust. Aligned → higher rank.
   - **Recency**: newer research can supersede older on the same problem.
   - **Specificity**: concrete pipeline descriptor > step-by-step > architecture handwave.

3. **Choose the BEST.** Not the easiest. Not the one already in the prompt chain. The one that will actually deliver what the user wants per their engineering philosophy.

4. **Document the choice.** Every spec-encoding code comment names the version picked AND explains which versions were rejected + why.

5. **Surface conflicts.** When Tier 2 prescribes X but Tier 1 prescribes Y-with-measurements, STOP and present both with a recommendation. Do not silently pick.

6. **Re-enumerate on every audit.** The corpus grows. A concept that had 2 versions last phase may have 4 now. The "best version" can change. Audits must re-run the version enumeration.

### Automatic audit grounding

Every audit I run must internally execute this query for every touched code block:

> "What does the current research on the user's Mac regarding this particular code block/line/feature say about how I should implement it? How many docs refer to this? Which version is more valid, which is more rigorous, which aligns with the user's engineering philosophy? Is there a better version than what's currently shipped?"

If a better version exists on disk and is not yet shipped, it's a **drift signal**. I flag it, surface it, and propose migration.

### Canonical example — Metal pipeline precompile (2026-04-04)

| Version | Source | Rigor | Philosophy | Recency | Verdict |
|---------|--------|-------|------------|---------|---------|
| `new_library_with_source` (status quo) | pre-2026 code | none | no measurement | old | shipped, but suboptimal |
| `new_library_with_data` (.metallib) | Tier 2: CODEX_PROMPT_CHAIN §B-1 | medium | saves ~150–300ms | 2026-03 | partial fix |
| `MTLBinaryArchive` | Tier 1: `~/Downloads/old research/Optimizing Graph Initialization Performance.md` | **high**: 100–500ms→<5ms benchmark, Apple API citations | **aligned**: direct Metal, per-GPU, measurable | 2026-03 | **BEST → shipped** |

I shipped Tier 1 because it was the best version. I documented the rejection of Tier 2 inline in `pipeline_cache.rs`.

### Example categories to watch

- **FFI strategy**: UniFFI vs custom C ABI vs raw pointer — rank by measured hotness
- **Storage**: JSONL vs SQLite vs mmap slotmap — rank by access pattern
- **Agent loops**: sequential vs `try_join_all` parallel vs actor-style — rank by latency budget
- **Shader caching**: source recompile vs metallib vs binary archive — rank by cold-start SLA
- **Provider adapters**: URLSession vs Goose trait vs raw HTTP — rank by migration cost
- **Embedding storage**: sqlite-vec vs LanceDB vs tantivy vs FAISS — rank by binary budget
- **Physics**: Euler vs Verlet vs Barnes-Hut vs FMM — rank by N scaling
- **Entity ID**: String UUID vs u64 generational slotkey vs i64 rowid — rank by cache locality

## The Operating Contract

### 1. Before touching any feature, grep both tiers → read → cross-reference.

For every feature or phase transition, I will:

```bash
# Tier 1: raw research corpus (read FIRST)
grep -rln "<feature-name>" ~/Downloads/ --include="*.md" --include="*.txt"
grep -rln "<related-keyword-1>" ~/Downloads/ --include="*.md"
grep -rln "<related-keyword-2>" ~/Downloads/ --include="*.md"

# Tier 2: structured project plans (final checks)
grep -rln "<feature-name>" ~/Downloads/Epistemos/docs/
grep -rln "<related-keyword-1>" ~/Downloads/Epistemos/docs/
grep -rln "<related-keyword-2>" ~/Downloads/Epistemos/docs/
```

Then **read each matching doc in full** — Tier 1 first, then Tier 2. Not the grep snippet, not a summary, the actual file. I will cross-reference:

- CODEX_PROMPT_CHAIN.md (the implementation prompts) against VISION_BACKLOG.md (the spec)
- Research essays against audit findings
- Phase guides against handoffs

When there are 6 docs mentioning `SDF labels` across both tiers, I read 6 docs. When there are 12 docs mentioning `Hermes`, I read 12. The split is typically 60–70% Tier 1 (raw research) / 30–40% Tier 2 (structured plans).

### 2. Verify the feature isn't already done.

Prior sessions may have already landed the work. I will `grep` the codebase for the data structures, functions, and FFI names mentioned in the spec before writing a single line. If it exists, I report that and move on.

### 3. Cite the doc + section in the code.

Every implementation gets a comment like `// per CODEX_PROMPT_CHAIN.md §B-7` or `// spec: VISION_BACKLOG.md §3-PHYSICS`. When the user audits later, they can trace code → doc → research instantly.

### 4. When specs conflict, surface the conflict — don't pick.

If GOOSE_AGENT_RESEARCH.md says X and UNIFIED_SUBSTRATE_RESEARCH.md says Y, I stop and ask. I don't silently pick one. I present both and ask the user which doc is authoritative for this slice.

### 5. Match the "HOW," not just the "WHAT."

A spec that says `mass = 1.0 + (child_count * 0.5) + (link_count * 0.2)` is not "add a mass field." It's that exact formula. Variable names matter. Constants matter. If the research says `max_velocity = 500.0`, the code reads `500.0`, not `480.0`. If the doc prescribes `AppAction::RenameNote`, the enum variant is `RenameNote`, not `UpdateTitle`.

### 6. Re-grep between phases.

Mid-session, my mental model of the spec drifts. Before starting a new subphase, I re-grep the relevant docs to confirm my memory is still accurate.

## Phase Execution Protocol

Every feature/phase follows this loop:

```
┌─────────────────────────────────────────────────────┐
│ PHASE N                                              │
│                                                      │
│ 1. DISCOVER                                          │
│    - grep ~/Downloads/ (Tier 1: raw research)        │
│    - grep ~/Downloads/Epistemos/docs/ (Tier 2: plans)│
│    - list every matching doc from BOTH tiers         │
│    - grep codebase for existing impl                 │
│                                                      │
│ 2. READ                                              │
│    - read every matching doc IN FULL                 │
│    - note conflicts, gaps, ambiguities               │
│                                                      │
│ 3. VERIFY                                            │
│    - does this already exist?                        │
│    - what's done, what's open, what's wrong?         │
│                                                      │
│ 4. CONFIRM                                           │
│    - summarize the cross-doc spec to the user        │
│    - surface conflicts                               │
│    - get explicit go-ahead                           │
│                                                      │
│ 5. IMPLEMENT                                         │
│    - cite doc + section in code comments             │
│    - match HOW (names, formulas, constants)          │
│    - spec-traceable tests                            │
│                                                      │
│ 6. AUDIT                                             │
│    - re-read the docs → compare to my code           │
│    - fix drift                                       │
│    - verify zero test regressions                    │
│                                                      │
│ 7. COMMIT + LOG                                      │
│    - update AGENT_PROGRESS.md                        │
│    - log in handoffs/YYYY-MM-DD-<phase>.md           │
└─────────────────────────────────────────────────────┘
```

## Multi-Month Plan View

The visible roadmap (from CODEX_PROMPT_CHAIN.md + phase docs):

| Phase | Scope | Doc Clusters to Read Fully |
|-------|-------|-----|
| **A** Provider Overhaul | Provider trait, settings, OAuth, mode selector | CODEX_PROMPT_CHAIN §A, HERMES_INTEGRATION_RESEARCH, AGENT_DEEP_VERIFICATION_MANUAL |
| **B** Graph-First | SDF labels, mass-drag, shadows, idle drift, theming, perspective | CODEX_PROMPT_CHAIN §B, GRAPH_SDF_LABEL_RESEARCH_PROMPT, VISION_BACKLOG §3-PRIME/SHADOW/GRAPH/PHYSICS, graph-physics-performance-plan |
| **C** Agent Parity | CodeNano tools, Hermes feature parity, session lifecycle, control plane UI | CODEX_PROMPT_CHAIN §C, HERMES_PARITY_REPORT, CONTROL_PLANE_RESEARCH |
| **D** Knowledge Brick | Tabs, command bar, inline settings | CODEX_PROMPT_CHAIN §D, INSTANT_RECALL_ARCHITECTURE |
| **I** Rust Migration | Goose bridge, builtin extensions, GEPA, Python elimination | PHASE_I_IMPLEMENTATION_GUIDE, GOOSE_AGENT_RESEARCH(.md + _2.md), GOOSE_REPLACEMENT_STRATEGY |
| **Substrate** | EntityID, AppAction, event log, window singularity | UNIFIED_SUBSTRATE_RESEARCH, unified1/2/3.md (in ~/Downloads/) |
| **H** Release | MAS compliance, distribution, hardening | MASTER_SESSION_PROMPT v2, hardening docs |

Substrate is **woven through all phases**, not a separate block. EntityID unification is Sprint 1; every later phase consumes it.

## What "Done" Means

A phase is done when:

1. Every spec from every doc is either implemented or explicitly deferred in writing
2. Code cites doc sections in comments
3. Spec-traceable tests exist (like `mass_follows_codex_b7_spec`)
4. Zero regressions in the 2,679-test suite (or explicit acceptance of new failures with reasons)
5. AGENT_PROGRESS.md is updated with ✅ and date
6. A handoff doc is written for the next session

## What I Will Not Do

- Skip docs because "I read one that covers it"
- Guess at formulas, constants, or variable names the docs specify
- Use simplified/made-up action names instead of spec names
- Refactor beyond what the docs say
- Pre-optimize in ways the research explicitly warns against (Law 4: UniFFI stays until profiling proves otherwise)
- Add fallbacks, feature flags, or backwards-compat shims not in the docs
- Touch Swift when the user says "Rust only"
- Mark items done in AGENT_PROGRESS.md until verification commands pass

## Binding Commitment

Every session going forward, before I write any code for a new feature:

> I will grep the docs/ directory for every document that mentions this feature. I will read them all. I will compare the cross-doc spec against what exists in the codebase. I will summarize the intersection to the user and confirm the direction. Only then will I implement, and I will cite specific doc sections in every code comment that encodes a spec.
