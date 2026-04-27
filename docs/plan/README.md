# docs/plan/ — Master Execution Plan

**Purpose.** This folder is the single execution doctrine + sequencing plan for Epistemos.
It fuses the canonical authority (`docs/architecture/PLAN_V2.md`), the operational
constraints (`/CLAUDE.md`), the four-architect synthesis, the 21-item Tier 3/4 dossier,
and the user's research corpus (`~/Downloads/Advice/` and `~/Downloads/final/`) into one
deterministic plan that any agent can execute without drifting.

**This folder does NOT replace PLAN_V2.** `docs/architecture/PLAN_V2.md` is the
architectural authority. This folder is the *execution layer* that hangs off it. If
this plan ever contradicts PLAN_V2, PLAN_V2 wins and this plan must be revised — never
the reverse.

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
