# 10 - Local Agent Redirect and Status Templates

## Paste-ready local coding agent prompt

```text
Read before editing: 00_READ_FIRST.md, 01_OWNER_LOCK_AND_CANONICAL_THESIS.md, 02_MASTER_BUILD_ORDER_AND_DEPENDENCY_GRAPH.md, 08_MAS_LEGALITY_PRIVACY_RELEASE_EVIDENCE.md, then the specific feature doc for your task.

Treat MAS-ONLY-SHIP-LOCK-2026-07-07 as active. Epistemos is one Mac App Store product. MAS/June is the only active agent surface. Use in-process agent_core, native Swift/AppKit/SwiftUI, bundled WKWebView assets, Keychain, security-scoped bookmarks, sandbox-safe storage, approval-gated tools, and vault file/artifact truth.

Do not revive Pro, Developer-ID, Experimental, 1Code, OpenChamber, Goose runtime, Kindred runtime, browser-use/Chromium, terminal/code-exec, stdio MCP, local server, subprocess, hidden sidecar, second chat runtime, second transcript database, second tool authority, or second data room.

Before the first edit, write an Owner Intent Checkpoint: verbatim owner steer excerpt, interpreted intent, hard constraints, non-goals, acceptance checks, contradictions/questions, and next action.

During implementation, keep a verification-debt ledger: deferred command, touched files, risk reason, expected proof, and checkpoint trigger. Batch builds only when safe. Never run competing xcodebuild jobs.

After every meaningful change: read the diff, search for parked-lane leaks, run narrow checks, and update evidence. After apparent completion: do not stop; run contradiction sweep, MAS leak scan, storage/data-loss evidence, entitlements/privacy checks, App Review notes, and release tests.

Autonomous overnight mode: if the owner is absent, do not stop the whole run to ask routine questions. Choose conservative, MAS-safe, reversible defaults; log uncertainty; continue audits, tests, source reading, hardening, and documentation. Only block the specific unsafe branch for destructive/data-loss/paid/external-submission/credential/legal/product-strategy decisions, mark OWNER_DECISION_REQUIRED, and continue safe adjacent work.

If you are already in flight and your current plan assumes Pro, Experimental, 1Code, Goose, Kindred, browser-use/Chromium, terminal/code-exec, local server, subprocess, sidecar, second transcript DB, or a second data room as an active lane, pause implementation. Write a handoff with files touched, diffs, evidence, verification debt, and exact stale assumption, then restart from this MAS master canon before editing further.

If a required local fact is not proven, mark REQUIRES LOCAL VERIFICATION and give the exact command.
```

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
