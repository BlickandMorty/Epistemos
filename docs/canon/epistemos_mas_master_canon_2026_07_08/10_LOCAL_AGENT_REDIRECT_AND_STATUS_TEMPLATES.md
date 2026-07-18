# 10 - Local Agent Redirect and Status Templates

## July 15 sequential-lane execution override

Read `16_TWO_LANE_REMOVAL_AND_REBUILD_DIRECTIVE_2026_07_15.md`. Run Lane R
first using the Free V1 removal prompt. Do not start Lane B until Lane R records
a stable source checkpoint. Lane R owns canceled/parked removal and fail-closed
boundaries; its “notebook removal” applies only to the retired
Chat/Sheet/Body-strip workspace, not a future Epdoc-native notebook. Lane B
then owns rich native Epdoc recovery and the blank Multitask Graph repair.
Preserve their disjoint file maps, leave Settings to its separate owner, and
defer Xcode/app evidence until both source checkpoints are stable and one
integration owner runs the single verification artifact.

## July 15 redirect override

Prepend this to every local prompt: read
`14_OWNER_SCOPE_REDUCTION_AND_PAUSE_CHECKPOINT_2026_07_15.md` and
`15_OWNER_DIRECTIVE_COVERAGE_AND_HARDENING_CHECKPOINT_2026_07_15.md`; cancel LumenLens
and all AI/agent/model/provider/generative work; park Reckoner and all sheet/
dataset/grid/database-product work; retain non-AI Editor Core, KEELSTONE,
Kokoro, and the remaining non-AI capability ring. Do not execute the old Prompt
3 or Prompt 4. The current state is paused for owner review; after resumption,
continue the existing KEELSTONE key and do not start another execution key.

## Paste-ready local coding agent prompt

```text
Read before editing: 00_READ_FIRST.md, 14_OWNER_SCOPE_REDUCTION_AND_PAUSE_CHECKPOINT_2026_07_15.md, 15_OWNER_DIRECTIVE_COVERAGE_AND_HARDENING_CHECKPOINT_2026_07_15.md, 01_OWNER_LOCK_AND_CANONICAL_THESIS.md, 02_MASTER_BUILD_ORDER_AND_DEPENDENCY_GRAPH.md, 11_FREE_V1_EPDOC_PLANNER_AND_CAPABILITY_RING_2026_07_13.md, 12_LIVE_REFERENCE_AND_FREE_V1_SURFACE_REGISTRY_2026_07_13.md, 08_MAS_LEGALITY_PRIVACY_RELEASE_EVIDENCE.md, then the specific surviving feature doc for your task.

Treat MAS-ONLY-SHIP-LOCK-2026-07-07 as active. Epistemos is one Mac App Store product. Free V1 has no active agent or AI surface; June/LumenLens/AI are canceled. Browser and ResearchHub are deferred deterministic paid possibilities and absent from Free V1. Reckoner is parked. Keep Kokoro, KEELSTONE, non-AI Editor Core/Epdoc planner/tasks/calendar, Meeting, Sync, Quick Capture, PDF/import, graph/search, deterministic HTML workspace, and export active through native Swift/AppKit/SwiftUI, bundled approved assets, security-scoped bookmarks, sandbox-safe storage, and vault file/artifact truth.

Use one centralized free-V1 capability policy across navigation, settings, Epdoc chrome, shortcuts, deep links, restoration, provider startup, queries, and background jobs. Preserve compatibility data and provenance, but do not compile/initialize canceled AI source, implement StoreKit/payment/signing, execute Prompt 3/4, or revive Reckoner.

Do not revive Pro, Developer-ID, Experimental, 1Code, OpenChamber, Goose runtime, Kindred runtime, browser-use/Chromium, terminal/code-exec, stdio MCP, local server, subprocess, hidden sidecar, second chat runtime, second transcript database, second tool authority, or second data room.

Before the first edit, write an Owner Intent Checkpoint: verbatim owner steer excerpt, interpreted intent, hard constraints, non-goals, acceptance checks, contradictions/questions, and next action.

During implementation, keep a verification-debt ledger: deferred command, touched files, risk reason, expected proof, and checkpoint trigger. Batch builds only when safe. Never run competing xcodebuild jobs.

After every meaningful change: read the diff, search for parked-lane leaks, run narrow checks, and update evidence. After apparent completion: do not stop; run contradiction sweep, MAS leak scan, storage/data-loss evidence, entitlements/privacy checks, App Review notes, and release tests.

Autonomous overnight mode: if the owner is absent, do not stop the whole run to ask routine questions. Choose conservative, MAS-safe, reversible defaults; log uncertainty; continue audits, tests, source reading, hardening, and documentation. Only block the specific unsafe branch for destructive/data-loss/paid/external-submission/credential/legal/product-strategy decisions, mark OWNER_DECISION_REQUIRED, and continue safe adjacent work.

If you are already in flight and your current free-V1 plan assumes June, Browser, ResearchHub, Pro, Experimental, 1Code, Goose, Kindred, browser-use/Chromium, terminal/code-exec, local server, subprocess, sidecar, second transcript DB, or a second data room as an active lane, pause implementation. Write a handoff with files touched, diffs, evidence, verification debt, and exact stale assumption, then restart from this MAS master canon before editing further.

If a required local fact is not proven, mark REQUIRES LOCAL VERIFICATION and give the exact command.
```

## Delegation and one-edit-owner protocol

Read-only investigations may run in parallel for canon, dependency provenance,
call sites, tests, visual references, or release evidence. A single named owner
must make each edit batch, regenerate each build/archive, and consolidate all
subtask findings into the intent/evidence ledger. Never let two agents edit the
same workspace paths or run competing builds. A delegated finding is evidence
only after the edit owner rechecks the cited local files and records the
result; agents may not convert uncertainty into a new product direction.

## Paste-ready cloud research auditor prompt

```text
You are the Epistemos MAS cloud research auditor. You do not have repo access unless files are attached. Work from the master canon ZIP, attached plan docs, and current official primary web sources only.

Verify Apple MAS/App Review/sandbox/privacy/required-reason/StoreKit/source-provider facts using official sources. Do not rely on memory. Do not provide generic App Store advice; map every conclusion to the Epistemos docs.

Output: MAS legality matrix, source/provider matrix, contradiction sweep, F1-F6 integration audit, storage/release verdict review, MiniChat verdict review, local verification command list, and self-critique. Mark all repo-specific claims REQUIRES LOCAL VERIFICATION unless a file proves them.
```

## Status report template

```markdown
# Status Report - <Feature / Phase>

Date:
Agent:
Lock: MAS-ONLY-SHIP-LOCK-2026-07-07

## Owner Intent Checkpoint
- Verbatim owner steer:
- Interpreted intent:
- Hard constraints:
- Non-goals:
- Acceptance checks:
- Contradictions/questions:
- Next action:

## Scope
- Active doc(s):
- Files touched:
- Parked-lane risk:

## Work completed
-

## Evidence
- Commands run:
- Results:
- Manual/runtime proof:
- Screenshots/logs if applicable:

## Verification debt
| Deferred command | Files touched | Risk reason | Expected proof | Trigger |
|---|---|---|---|---|

## F1-F6 impact
| Fabric | Change | Evidence |
|---|---|---|

## MAS release impact
- Entitlements:
- Privacy manifest:
- App Review notes:
- Symbol/leak scan:
- Data-loss/storage risk:

## STOP triggers / blockers
-

## Self-score
Grounded:
Alternatives named:
Build-actionable:
No fabrication:
Constraint fidelity:
Integration depth:
Release safety:
Contradiction cleanup:
```

## `REQUIRES LOCAL VERIFICATION` format

```text
REQUIRES LOCAL VERIFICATION: <claim>
Why it matters: <risk>
File(s): <paths>
Command:
```bash
<exact command>
```
Expected proof: <what should be true>
Fallback if false: <what to do>
```

## STOP trigger format

```text
STOP TRIGGER: <short name>
Severity: HIGH / MED / LOW
Reason: <why this blocks>
Evidence: <command output or source>
Owner decision needed: yes/no
Branch blocked: <exact unsafe branch, not the whole run unless unavoidable>
Safe next work while blocked: <audit/test/hardening/doc/reversible implementation to continue>
```

## Self-score rubric

Every research/build handoff should score 1-5 on:

- Groundedness
- Alternatives named
- Build actionability
- No fabrication
- Constraint fidelity
- Integration depth
- Depth/novelty
- Release safety
- Contradiction cleanup

Any score below 4 means revise before claiming done.
