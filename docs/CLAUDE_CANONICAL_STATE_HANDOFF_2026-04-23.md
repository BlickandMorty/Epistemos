# Claude Handoff — Canonical State Audit

> **Index status**: CANONICAL-OPERATIONAL — 2026-04-23 canonical state handoff; recent operational reference.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



**Date:** April 23, 2026  
**Purpose:** Audit the current Epistemos app state against the implementation plan before further implementation work begins.

**Paste this prompt into Claude Code as-is.**

---

You are auditing the current state of **Epistemos** to determine whether the live implementation is still canonical relative to the implementation plan.

## Ground Truth Rule

Treat [docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md](/Users/jojo/Downloads/Epistemos/docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md) as the **current ground truth plan**.

Treat the current app and codebase as the **v1 implementation baseline** that must be checked against that plan.

Do **not** assume the current app is canonical just because it exists.
Do **not** assume the plan is perfect just because it is the plan.

Your job is to tell us, with evidence:

1. what in the current app is already canonical and matches the plan
2. what in the app has drifted and should be migrated to the plan
3. what in the plan is missing real, correct app behavior and should be reflected back into the plan
4. what should be changed on either side before new implementation starts

If the app needs to be **reflected, migrated, renamed, reorganized, or changed in any way** to align with the plan, say so explicitly.
If the plan needs to absorb reality from the current app, say so explicitly.

## Critical Constraint

The user is editing `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md` in real time.

- Do **not** edit that file.
- Do **not** treat it as disposable.
- If you think it needs changes, report them in a separate audit output instead of modifying the plan directly.

## First Reads

Read these first:

1. `/Users/jojo/Downloads/Epistemos/AGENTS.md`
2. `/Users/jojo/Downloads/Epistemos/docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md`
3. `/Users/jojo/Downloads/Epistemos/docs/audit-progress.md`
4. `/Users/jojo/Downloads/Epistemos/docs/future-work-audit.md`

Then inspect the current implementation.

## Current Areas To Audit Carefully

Please pay special attention to the areas that have recently changed or that have shown drift/risk:

### 1. Landing / Home Canonicality

Audit whether the landing surface is actually behaving the way the plan intends, especially:

- typewriter greeting / rotating phrases
- home-window identity and occlusion handling
- landing/home state drift

Key files:

- `/Users/jojo/Downloads/Epistemos/Epistemos/App/RootView.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Landing/LandingView.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Landing/LiquidGreeting.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/LandingOptimizationTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/RuntimeValidationTests.swift`

### 2. Model Vault Canonicality

Audit whether model vaults truly behave like first-class folders/files in the notes system, while still remaining distinct from native user notes.

Check:

- folder creation
- nested folders/files
- markdown vs code-file opening behavior
- whether model vaults behave like a master storage location for model-owned files, including non-native-vault files
- whether the sidebar organization is clear and canonical

Key files:

- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/ModelVaultsSidebarSection.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/ModelVaultBrowserSheet.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/NotesSidebar.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/ProseEditorView.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/KnowledgeProfileStore.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/Extensions.swift`

### 3. Contribution Timeline / “Alive” Agent Surface

Audit whether the contribution timeline and model contribution UI are actually comprehensive, understandable, and canonical.

Also assess the broader concern that tool use and regular chat-agent behavior have not always felt “alive,” complete, or truthful enough.

Key files:

- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/ModelInvolvementSheet.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/ModelVaultsSidebarSection.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/ModelVaultBrowserTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/RuntimeValidationTests.swift`

### 4. Routing / Truthfulness / Repair-Loop Hardening

Audit whether the current agent and routing surfaces are genuinely hardened against:

- duplicate behavior
- mismatched state
- lying / silent fallback behavior
- invisible repair loops
- non-responsive tool-use turns

Key files:

- `/Users/jojo/Downloads/Epistemos/Epistemos/State/InferenceState.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/LocalAgent/LocalAgentLoop.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Sync/VaultIndexActor.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Shared/AppKitPopover.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/LocalAgentLoopTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/TriageServiceTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/RuntimeValidationTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/VaultIndexActorTests.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/AppKitPopoverAuditTests.swift`

## What I Need From You

Produce a **canonical-state audit**, not a vague summary.

Your output should answer:

1. **What is canonical already**
2. **What is implemented but should be migrated**
3. **What is missing from the plan but present in the app and should be reflected into the plan**
4. **What is planned but still not truly implemented**
5. **What is ambiguous and needs a product/architecture decision**

For each mismatch, classify it as exactly one of:

- `migrate app to plan`
- `reflect app behavior into plan`
- `both need revision`
- `unclear / needs decision`

## Verification Expectations

Do not rely on code reading alone if a runtime check is feasible.

Where possible:

- build the app
- run targeted tests
- manually inspect the relevant UI/runtime surfaces
- distinguish clearly between:
  - code appears correct
  - tests passed
  - manual runtime verified
  - blocked / could not verify

If Xcode or runtime tooling is flaky, say that plainly and do not overclaim.

## Output Format

Use this structure:

### A. Canonical Matches
Short list of places where plan and app already agree.

### B. Drift Requiring Migration
Every place where the app should change to match the plan.

### C. Reality The Plan Must Absorb
Every place where the current app has real behavior the plan should reflect.

### D. False Confidence / Risk Areas
Anything that looks implemented but is not trustworthy enough yet.

### E. Recommended Next Moves
Ordered next actions before new implementation begins.

For every finding, include file paths and concrete evidence.

## Important Tone Constraint

Be direct and honest.
If something is cargo-culted, partial, confusing, or non-canonical, say so.
If something is good and should remain the reference implementation, say so.

The goal is to make the **plan the durable ground truth** and ensure the app is either:

- already aligned with it, or
- clearly queued for migration/reflection before new work starts.

