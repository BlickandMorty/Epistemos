# Claude Omega Audit + Training Grounding Manifesto

> **Index status**: CANONICAL-OPERATIONAL — Standing operational mandate for Omega/KnowledgeFusion/training/evals work; North Star preservation.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



## Purpose

This document is no longer just a fix handoff.

It is the standing session brief for any Claude Code work touching:

- Omega
- KnowledgeFusion
- model training
- adapters
- evals
- app-specific agent behavior
- Instant Recall
- reasoning / planning / tool use

If the work affects the model, agent behavior, training data, eval harnesses, or app-specific reflexes, Claude must ground here first.

The goal is not to ship isolated features.

The goal is to preserve the Epistemos North Star while making the system:

- more truthful
- more reflexive
- safer
- faster on repeated local workflows
- more robust across app changes
- more benchmarked rather than vibes-driven

---

## Session Mandate

For every relevant session, Claude must read these first before proposing edits:

### Core bibles

1. `CLAUDE.md`
2. `EPISTEMOS-NORTH-STAR.md`
3. `docs/NANO-MASTER-TRAINING-GUIDE.md`
4. `docs/TRAINING_GUIDE.md`
5. `docs/SESSION_STATE_2026_03_25.md`

### External grounding files

6. `/Users/jojo/Downloads/EPISTEMOS-NORTH-STAR.md`
7. `/Users/jojo/Downloads/EPISTEMOS-NANO-MASTER-TRAINING-GUIDE.md`
8. `/Users/jojo/Downloads/Epistemos  A New Paradigm for Time-Aware Personal Knowledge.md`

### Required when touching training or the model

9. Read the relevant scripts, configs, and eval harnesses under `Epistemos/KnowledgeFusion/` before editing.
10. Read the exact training script being changed before editing it.
11. Read the exact eval or benchmark harness that will prove the change.
12. Read the app-specific data generation path if the work affects Epistemos self-knowledge.

If Claude is changing training behavior without first reading the script/config/eval path, the work is not grounded enough.

---

## Big-Picture Non-Negotiables

These ideas must be preserved across all future work.

### 1. Stay hybrid

Epistemos is a **75% Mamba / 25% Attention hybrid**.

Do not drift toward pure Mamba.
Do not remove the attention anchors.
Do not speak as if Mamba-3 makes the attention layers unnecessary.

The retained attention layers exist for:

- exact AX tree token retrieval
- JSON / schema anchoring
- multi-turn context anchoring

### 2. Mamba-2 now, Mamba-3 later, inside the same hybrid

Build with Mamba-2 while tooling is validated.
When tooling catches up, swap the Mamba layers to Mamba-3 **inside the same hybrid skeleton**.

The migration target is:

- same hybrid architecture
- same attention layer role
- same adapter / routing worldview
- same safety / eval doctrine

This is a layer swap, not an excuse to redesign the whole system.

### 3. MLX / Metal GPU for the hybrid, not ANE

The hybrid reasoning / action model must deploy honestly on MLX / Metal GPU.

Do not pretend selective scan is an ANE-native path if the real deployment path is not robust.

ANE is for sidecars that fit it cleanly:

- lightweight vision verification
- embeddings
- routing / classification

### 4. App-specific self-knowledge is a core training pillar

Epistemos-specific fluency is not optional polish.
It is a first-class training objective.

It must be preserved through these four layers:

1. Code Graph
2. Symbol QA
3. AX Atlas with diffs
4. Trajectory replay / agentic rollouts

If Claude proposes generic tool-call tuning while neglecting these four layers, it is missing the moat.

### 5. The Epistemos data allocation is sacred

The app-specific share must stay large enough to preserve reflexive self-knowledge.

Working target:

- protect the Epistemos allocation around the documented 20% range
- do not starve general macOS competence
- do not let app-specific data bloat so far that general behavior collapses

### 6. Reflex over prompt bloat

Repeated in-app reasoning should move into:

- adapters
- recipes
- app-specific datasets
- code-graph priors
- AX atlas diffs

Do not solve persistent app fluency by endlessly stuffing more code or UI dumps into prompts.

### 7. Version-aware adapters are mandatory

Meaningful Epistemos code or UI changes must trigger adapter refresh logic.

Do not tolerate stale app-specific knowledge.
Do not ship UI changes against stale adapters if the design assumes app reflexes.

### 8. Evals decide reality

No architecture claim counts without measurement.
No adapter should replace production because it “feels smarter.”

Every serious training or routing change must be judged on both:

- general macOS holdout
- Epistemos-specific holdout

### 9. Safety is part of training, not an afterthought

Do not optimize for eagerness.
Optimize for bounded, trustworthy autonomy.

The model should know:

- when to observe
- when to suggest
- when to ask
- when to halt
- when not to touch the machine

### 10. The app is about temporal truth, not static notes

Epistemos is not a generic note app.
It is a time-aware cognitive system built around timestamped epistemic states.

That means model, memory, retrieval, and training work should preserve:

- temporal belief evolution
- ambient recall
- self-improvement without cloud dependence
- personalized reasoning grounded in the user’s own corpus

---

## Audit Doctrine Upgrade

From this point forward, audits must not only ask “does this feature compile?”

They must also ask:

### Architecture drift

- Did the change preserve the hybrid Mamba/Attention architecture?
- Did it accidentally move reasoning assumptions toward pure SSM or pure cloud dependence?
- Did it violate the MLX/Metal vs ANE deployment truth?

### Training drift

- Did the work preserve app-specific meta-training as a first-class objective?
- Did it respect the documented data mix and anti-forgetting constraints?
- Did it preserve version-aware adapter regeneration expectations?

### Eval drift

- Is there a real benchmark, harness, or scripted check backing the claim?
- Are both general macOS and Epistemos-specific metrics considered?
- Is there a rollback path?

### Safety drift

- Did the change make the agent more reckless?
- Did it expand autonomy without adding proof, logs, or gates?
- Did it weaken confirmation, scope, or privacy boundaries?

### Truthfulness drift

- Does the UI or doc promise a capability that runtime does not actually deliver?
- Does the code claim a deployment path, benchmark, or enforcement guarantee that is not real?

If any of these drift checks fail, the work is incomplete even if the code compiles.

---

## Required Work Cycle For Training / Model Changes

For any substantial training or model work, Claude should structure its work in this order:

### State block

- objective
- current baseline
- failure mode
- constraints
- rollback point

### Plan

- exact files to inspect
- exact files to edit
- exact scripts to run
- exact evals to run
- exact success criteria

### Implementation

- what changed
- why it changed
- what was deliberately not changed

### Eval results

- general macOS metrics
- Epistemos-specific metrics
- latency / resource metrics
- safety / regression metrics

### Decision

- ship
- canary
- reject
- rollback
- needs research

### Next most leveraged step

- only one next step
- chosen for highest expected gain with lowest regression risk

---

## Research Halt Protocol

If Claude hits an unresolved technical uncertainty that would make action bluff-y, it must stop and emit:

```text
RESEARCH NEEDED - HALTING

TOPIC: [exact topic]

WHY BLOCKED: [why execution would be unsafe or low-confidence]

SPECIFIC QUESTIONS:
1. [question]
2. [question]
3. [question]

FILES CONSULTED:
- [file]
- [file]

WHAT I WILL DO AFTER RESEARCH:
- [next step 1]
- [next step 2]
```

Do not invent framework support.
Do not invent benchmark wins.
Do not invent deployment readiness.

---

## Training-Specific Audit Checklist

When Claude works on training, the audit must explicitly verify:

1. The hybrid ratio and layer-role logic were preserved.
2. Mamba-2 vs Mamba-3 claims are honest and aligned with current tooling.
3. MLX/Metal deployment remains the real path for the hybrid model.
4. ANE work is confined to honest sidecar jobs.
5. App-specific training still includes Code Graph, Symbol QA, AX Atlas diffs, and trajectories.
6. The Epistemos-specific data allocation was not quietly starved.
7. Negative examples and error-recovery data were not dropped.
8. Adapter generation / refresh logic remains version-aware.
9. Eval coverage includes both general macOS and Epistemos-specific holdouts.
10. Safety gates still exist for destructive or ambiguous actions.
11. Claims of “reflex” are backed by weight/adaptor/recipe changes, not just bigger prompts.
12. Claims of “faster” or “lighter” are backed by latency/resource evidence.

---

## Existing Omega Fix Scope Still Applies

The earlier audit-repair findings remain part of the standing scope:

### Finding 1

Constrained decoding must never be presented as fully constraining unless it truly masks invalid continuations.

### Finding 2

Planner prompt, grammar, registry, and runtime tool contracts must agree.

### Finding 3

Settings shown in the UI must actually affect runtime behavior or be removed/disabled.

### ReasoningLoop / Ω18 / training additions

Audits must also verify that:

- ReasoningLoop is reachable, test-backed, and not merely decorative
- Instant Recall is actually used in live flows, not only indexed in the background
- training docs and code preserve the big-picture architecture and app-specific reflex strategy

---

## What Not To Do

- Do not reduce this work to “make the tests pass.”
- Do not accept local improvements that violate the North Star.
- Do not treat app-specific training as optional garnish.
- Do not let benchmark theater replace actual eval harnesses.
- Do not let stale adapters or fake capability claims ship.
- Do not optimize for broad bragging rights over narrow, compounding wins inside Epistemos and repeated local workflows.

---

## Definition Of Done

Work is not done when:

- code compiles
- one demo works
- a prompt looks smarter
- a report sounds ambitious

Work is done when:

- the implementation is honest
- the architecture is preserved
- the safety model is preserved
- the right evals move
- regressions are checked
- rollback exists
- the change helps Epistemos win on its own ground

That ground is:

- its own app
- its own machine
- repeated local workflows
- ambient memory
- time-aware truth
- safe autonomy

