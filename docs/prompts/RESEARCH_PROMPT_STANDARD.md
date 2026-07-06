# RESEARCH-PROMPT STANDARD — quality rubric + anti-collision naming registry

> Shared standard for every Epistemos deep-research prompt and the plan it produces. Two jobs:
> (1) a **quality rubric + self-critique protocol** every research model must obey; (2) a
> **proprietary, non-colliding naming registry** so each plan and its research can never drift
> into another. Owner authored 2026-07-06. This file does NOT create plans — it governs them.

## 1. Why this exists
The owner will return with **deep research per plan** and then create the plans. To keep each plan
and its research **self-contained and un-driftable**, every plan gets a **unique codename + stable
ID**, used in: the plan filename, the research-doc filename, and a mandatory ID header **inside**
both. A research/plan artifact carrying ID `X` may never silently absorb content scoped to ID `Y`.

## 2. Naming registry (proprietary, collision-proof)

| Plan | Codename | Research-prompt ID | Build |
|---|---|---|---|
| 2 — Editor (lens + companion-edit layer + PDF) | **LUMENLENS** | `EPI-RP-02-LUMENLENS` | both (companion layer 1Code-only) |
| 4 — Iconography (marks + mascot art/rig) | **SIGILRY** | `EPI-RP-04-SIGILRY` | both |
| 5 — Companion (living multi-surface agent) | **KINDRED** | `EPI-RP-05-KINDRED` | **1Code-only** |
| 6 — Quick Capture (unstructured + voice) | **EMBERCATCH** | `EPI-RP-06-EMBERCATCH` | both |
| 7 — Sync + Release + Schema-solidification | **KEELSTONE** | `EPI-RP-07-KEELSTONE` | both |
| 8 — ResearchHub (multi-source feed) | **LODESTAR** | `EPI-RP-08-LODESTAR` | both |

Codenames are deliberately distinctive nouns with no generic overlap. Do not reuse, abbreviate, or
invent new ones without adding a row here first (this table is the single source of truth).

### 2.1 Filename templates (enforced)
- Research **prompt** (this repo, already written): `RESEARCH_PROMPT_PLAN_<N>_<TOPIC>.md`, carrying
  its `EPI-RP-…` ID in the header.
- Owner's returned **research/dossier** (brought back from a deep-research model):
  `RESEARCH_<CODENAME>_<ID>_<YYYY_MM_DD>.md` — e.g. `RESEARCH_KINDRED_EPI-RP-05-KINDRED_2026_07_12.md`.
- Final **plan** (created only when the owner returns): `PLAN_<CODENAME>_<ID>.md` — e.g.
  `PLAN_KINDRED_EPI-RP-05-KINDRED.md`.
The `<CODENAME>` + `<ID>` pair appears in every filename **and** in the first header line of the
file's contents. That pairing is the collision guard.

### 2.2 Anti-drift rules (contents)
1. Every research/plan file's **first line after the title** is: `ID: <EPI-RP-…> · Codename: <CODENAME>`.
2. A file scoped to one ID must **not** contain another plan's ID or codename except in an explicit
   "Dependencies / hand-off seam" section that names the other ID as an *external* interface.
3. Cross-plan needs are expressed as **named seams** (owner side / other-plan side), never by copying
   the other plan's scope inline.
4. When the owner returns research, it is filed under its own `RESEARCH_<CODENAME>_…` name; the plan
   that consumes it cites it by filename + ID. One research doc → one plan.

## 3. Quality rubric — every research model MUST self-apply before returning
Append this instruction to every research brief (or reference this file). Before finalizing, the
model **self-scores its dossier 1–5 on each axis, prints the scores, and iterates any section
scoring ≤3 until all axes are ≥4. A dossier with any axis <4 is not done.**

| Axis | 5 = excellent | 1 = failing |
|---|---|---|
| **Grounded** | every non-trivial claim cited to a primary/official source | asserted from memory |
| **Alternatives named** | chosen mechanism + the rejected options + *why* | one option, no trade-offs |
| **Build-actionable** | an engineer could build from it: schemas, seams, phased order, done-bars | generic advice |
| **No fabrication** | no invented APIs/features; unknowns flagged with fallback | confident hand-wave |
| **Constraint-fidelity** | honors every hard constraint in the brief (build split, platform, safety) | ignores/softens constraints |
| **Depth/novelty** | goes past the obvious; names the 3–5 genuinely novel moves | surface survey |

Also require a short **"self-critique" section**: the 3 weakest points of the dossier and what a
follow-up cycle should investigate. Honesty about gaps beats false completeness.

## 4. Source discipline (all briefs)
- **Tier 1 (prefer):** official docs, standards, primary source code, first-party API references,
  the product's own material. **Tier 2:** reputable technical write-ups/papers. **Tier 3 (corroborate
  only):** blogs/forums. Never cite Tier 3 where Tier 1 exists.
- Distinguish **observed** (seen in a primary source) from **inferred**. Flag version-gated or
  uncertain capabilities and give a fallback. Cite with resolvable links.

## 5. Output shape (all briefs)
Lead with a ½-page executive thesis, then the dimensioned sections, then a **phased build order**
where each phase has a **witnessable "proven-done" bar** (a real behavior, not "compiles"), then
**open questions preserved** (never silently resolved), then the **self-critique + rubric scores**.

## 6. How each prompt references this
Each `RESEARCH_PROMPT_PLAN_*.md` carries, in its header: its `EPI-RP-…` ID + codename, and the line
"Obey `RESEARCH_PROMPT_STANDARD.md` §3 rubric + §4 sources + §5 shape." That keeps the six briefs
consistent and upgradeable from one place.
