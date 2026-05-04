# docs/plan/ — Plan Tree (Depth References)

> **CANONICAL OPERATIONAL ENTRY POINT: [`docs/MASTER_BUILD_PLAN.md`](../MASTER_BUILD_PLAN.md).**
> Read that first for the queue, the §0 loop pattern, and the §10 quick-start.
> This folder contains the depth references (00–05) the master cites by section.
> If you are unsure where to start: open `MASTER_BUILD_PLAN.md`, follow its links here as needed.

**Purpose.** Six numbered depth-reference files plus a `prompts/` subfolder.
Together they fuse the architectural authority (`docs/architecture/PLAN_V2.md`), code standards (`/CLAUDE.md`),
the four-architect synthesis, the 21-item Tier 3/4 dossier, and the user's research corpus
(`~/Downloads/Advice/`, `~/Downloads/final/`, `~/Downloads/final v2/`, `~/Downloads/final v3/`) into a
deterministic plan stack any agent can execute without drifting.

**Authority hierarchy (bottom is operational, top is architectural):**
```
1. docs/architecture/PLAN_V2.md   ← architectural truth (top)
2. CLAUDE.md                       ← code standards
3. docs/MASTER_BUILD_PLAN.md       ← operational doctrine + queue (CANONICAL ENTRY POINT)
4. docs/plan/01_DOCTRINE.md        ← 14 non-negotiables, fifth-position rulings
5. docs/plan/02_BUILD_MATRIX.md    ← Pro/MAS gating
6. docs/plan/03_EXECUTION_MAP.md   ← per-item depth
7. docs/plan/prompts/<task>.md     ← task-specific instructions
```

If a lower level contradicts a higher one, the higher wins. The lower must be revised; never the reverse. **This folder does NOT replace PLAN_V2 or MASTER_BUILD_PLAN.** It hangs off them.

---

## How an agent uses this folder

Every agent session that touches Epistemos code MUST follow this sequence before
writing or editing anything:

1. Read `00_AUTHORITY_AND_ANTI_DRIFT.md` (the contract).
2. Read `01_DOCTRINE.md` (the fifth-position architectural rulings).
3. Read `02_BUILD_MATRIX.md` (Pro vs MAS gating for the specific item).
4. Read the relevant entry in `03_EXECUTION_MAP.md` for the item being worked on.
5. Read the research docs that entry points to (`05_RESEARCH_INDEX.md` is the index).
6. Read the matching prompt in `prompts/` if one exists, OR fill `prompts/_TEMPLATE.md`.
7. Verify file paths and line numbers against the actual codebase before asserting them.
8. Implement against the definition of done in the prompt, not the agent's own ideas.

**No skipping steps.** The pre-flight reads are not optional. An agent that writes
code without reading the contract is a drifting agent.

---

## File index

| File | Purpose | Read first if you are… |
|---|---|---|
| `README.md` | This file. Navigation only. | …new to this folder |
| `00_AUTHORITY_AND_ANTI_DRIFT.md` | The contract every agent obeys: hierarchy, pre-flight reads, **7 verification gates including the WRV (Wired-Reachable-Visible) anti-scaffolding gate**, telemetry mandate, the auto-research rule, definition-of-done preamble. | …about to do anything |
| `01_DOCTRINE.md` | The fused fifth-position architecture. Resolves the five A/B/C/D tensions. Names the novel architectural primitive (retraction propagation). Lists the thirteen non-negotiables. | …making an architectural choice |
| `02_BUILD_MATRIX.md` | Pro vs MAS feature gating. What ships in MAS (sandboxed, strictly gated) vs Pro (Hardened Runtime, non-sandboxed, full-feature). Which dossier items apply to which target. | …adding a feature or unsure if it ships in MAS |
| `03_EXECUTION_MAP.md` | The 21-item map (R14, R15, R16, W9.6–W9.30). Per-item: doctrine alignment, research-doc references, files-to-touch, tests-must-stay-green, telemetry surface required, definition of done. | …picking up a specific dossier item |
| `04_PHASES.md` | Phase 0 → Phase 4 sequencing with entry/exit gates. What ships when. What is explicitly deferred. | …deciding what to do next |
| `05_RESEARCH_INDEX.md` | Every research doc in `/Advice` and `/final` with a one-line summary, a topic taxonomy, and a back-pointer to the items it informs. | …an `03_EXECUTION_MAP.md` entry tells you to read research |
| `prompts/_TEMPLATE.md` | The task-prompt template. Three slots: `{ITEM_ID}`, `{ITEM_TITLE}`, `{MASTER_PLAN_SECTION_REF}`. Everything else is anti-drift boilerplate. | …generating a new task prompt |
| `prompts/phase0_ship_blockers.md` | Ready-to-use prompt for Phase 0 (A+_RELEASE_ROADMAP ship-blockers). | …about to ship the first deliverable |
| `prompts/W9.25_grammar_masking.md` | Ready-to-use prompt for the lowest-risk Bucket A item, as a worked example. | …testing whether the template + plan loop works end-to-end |
| `prompts/N1_prompt_tree.md` | Ready-to-use prompt for the JSPF + PTF prompt-as-data foundation (parallel-track). | …starting the prompt-tree session in a new terminal |

---

## Authority hierarchy (highest → lowest)

```
1. docs/architecture/PLAN_V2.md         — architectural authority
2. CLAUDE.md                            — code standards + provider matrix
3. docs/plan/01_DOCTRINE.md             — fifth-position rulings
4. docs/plan/02_BUILD_MATRIX.md         — Pro/MAS gating
5. docs/plan/03_EXECUTION_MAP.md        — per-item execution rules
6. docs/plan/prompts/<task>.md          — task-specific instructions
```

If a lower level contradicts a higher one, the higher one wins. The lower one must
be revised; never the reverse. This is non-negotiable.

---

## Last updated

2026-04-26 — Initial creation.

When this plan is updated, append the date and a one-line summary at the bottom of
the affected file. Do not rewrite history. Do not delete prior rulings; supersede them
with a dated note.
