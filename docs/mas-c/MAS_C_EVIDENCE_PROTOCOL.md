# MAS C Evidence Protocol

ID: `MAS-C-EVIDENCE-PROTOCOL-2026-07-08`

This protocol defines the evidence shape every MAS C feature agent should leave
behind. It exists because MAS C is allowed to batch builds/tests during long
work, but it is not allowed to lose proof.

## When To Use

Use this protocol whenever an agent:

- starts a MAS C feature
- changes code, project config, entitlements, storage, permissions, release
  scripts, source ingestion, or UI behavior
- batches verification instead of running every check immediately
- claims a feature phase is ready for review
- absorbs new external research into MAS C

## Intent Checkpoint

Every feature work session starts with this evidence block in the active
progress note or handoff:

```text
Feature:
Owner excerpt:
Interpreted intent:
Hard constraints:
Non-goals:
Acceptance checks:
Contradictions or questions:
Next action:
Docs read:
Source files read:
Skills used:
```

Rules:

- `Owner excerpt` preserves the owner's exact wording or an exact excerpt.
- `Interpreted intent` must not soften product-weight words like "replace",
  "new stack", "revamp", "V2", or "whole new thing".
- `Hard constraints` must include MAS-only, vault truth, MAS June, and no
  hidden runtime unless the feature plan explicitly says otherwise.
- Update the checkpoint after every owner steer before the next implementation
  edit.

## Verification-Debt Ledger

When builds/tests/checks are batched, record each deferred proof immediately:

| Item | Touched scope | Risk if skipped | Expected proof | Checkpoint trigger | Status |
|---|---|---|---|---|---|
| command or manual check | files/features affected | behavior or release risk | what would prove it | when to run | queued/running/pass/fail/skipped-with-reason |

Rules:

- A ledger entry is not evidence by itself; it is a promise to collect evidence.
- High-risk local checks should not be deferred merely for convenience.
- At checkpoint, run the narrow checks first, then broader MAS checks if shared
  behavior changed.
- If a check cannot run, record the blocker and the strongest available
  source-level evidence.

## Feature Evidence Pack

Each feature should leave this pack when a phase is ready for review:

```text
Feature ID:
Phase:
Branch/worktree:
Files changed:
Files read before editing:
Owner intent checkpoint:
Implementation summary:
F1 vault bus evidence:
F2 agent capability evidence:
F3 status/provenance evidence:
F4 graph evidence:
F5 provenance/citation evidence:
F6 event bus evidence:
Tests/source guards run:
Builds run:
Manual/runtime evidence:
Screenshots or artifacts:
Entitlement/privacy impact:
Source/legal impact:
Storage/truth impact:
Release scan impact:
Verification debt remaining:
Known risks:
Next hardening target:
```

Use "not applicable" only when the feature plan makes that contract irrelevant.
Use "not run" only when a check is genuinely unrun and explain why.

## Release Evidence Pack

Before any MAS release-readiness claim, collect:

- exact commit or worktree state
- `xcodegen` status if project files changed
- `Epistemos-AppStore` build output path
- MAS test command and result
- entitlement printout
- privacy manifest printout
- release archive strings scan
- release archive resource scan
- classification of any legacy Goose/Hermes bridge names
- App Review notes for networking, local files, audio, cloud, source ingest, and
  in-process bridge behavior
- source/legal table for all network research features
- vault fixture and rollback proof for storage/editing features

## UI Evidence Pack

When visible UI changes, collect:

- target surface and route/window
- before screenshot when available
- after screenshot
- viewport or window size
- manual steps
- state shown and why it is real
- native/AppKit/SwiftUI ownership versus WKWebView ownership
- reduced-motion behavior if animation changed
- accessibility, contrast, and text-fit notes
- why the change is more than wrapper/reskin/token polish

## Storage Evidence Pack

When storage changes, collect:

- source of truth statement
- vault files before/after
- op-log/provenance entry
- derived index rebuild proof
- conflict fixture
- rollback or recovery proof
- security-scoped access proof
- data-loss risk review
- migration path if schema changed

## Source Legality Evidence Pack

When source ingestion changes, collect:

- source/API name
- official terms or documentation link
- allowed status: allowed, allowed-with-conditions, parked, or forbidden
- commercial-use condition
- attribution condition
- rate-limit condition
- privacy impact
- user-consent impact
- offline or no-source fallback
- MAS implementation shape
- release blocker if unresolved

## Handoff Summary

Every handoff should close with:

```text
What changed:
What was verified:
What was not verified:
Why remaining risk is acceptable or blocking:
Next action:
```

Never turn missing evidence into a completion claim.

