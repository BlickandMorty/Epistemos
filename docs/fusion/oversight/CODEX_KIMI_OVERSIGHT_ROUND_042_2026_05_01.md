# Codex / Kimi Oversight Round 042 - EventStore OpLog Dead-Letter PR3B

## Scope

Slice: EventStore OpLog Projection Dead-Letter PR3B.

Gate:
`docs/fusion/deliberation/eventstore_oplog_projection_dead_letter_pr3b_deliberation_2026_05_01.md`

Approved write set:

- `Epistemos/State/EventStore.swift`
- `Epistemos/Engine/MutationOpLogProjector.swift`
- `EpistemosTests/CognitiveSubstrateTests.swift`
- docs under `docs/fusion/**`

## Kimi Result

Kimi was invoked in read-only audit mode and did not complete.

Log:
`/tmp/epistemos-oplog-dead-letter-pr3b-kimi-advisory-20260501.log`

Result:

- Log size: `0` bytes.
- The Kimi subprocess produced no final advisory and was terminated after
  several minutes to avoid blocking the autonomous build loop.
- Before/after status diff was empty, so Kimi did not edit files:
  `/tmp/epistemos-oplog-dead-letter-pr3b-kimi-status-before-20260501.txt`
  versus
  `/tmp/epistemos-oplog-dead-letter-pr3b-kimi-status-after-20260501.txt`.

## Codex Review

Codex local review found no P0/P1 blocker in the implemented PR3B slice.

Implemented behavior:

- `mutation_projection_outbox` stores nullable `dead_lettered_at` and
  `dead_letter_reason`.
- Pending and claim APIs exclude dead-lettered rows.
- Failure recording is owner-scoped and can dead-letter rows at a bounded
  max-attempt threshold.
- Last error is still capped at 512 characters.
- Explicit projection mark/repair clears lease, retry, last-error, and
  dead-letter metadata.
- `MutationOpLogProjector` passes a bounded default max-attempt value when
  recording failures.

## Evidence

Red:

- `/tmp/epistemos-oplog-dead-letter-pr3b-red-20260501.log`
- Expected compiler failures for missing `maxAttempts`, `deadLetteredAt`, and
  `deadLetterReason`.

Green:

- `/tmp/epistemos-oplog-dead-letter-pr3b-green-20260501.log`
- `/tmp/epistemos-oplog-dead-letter-pr3b-green-2-20260501.log`
- `EventStore Cognitive Tables`: `14` tests passed.
- Xcode reported `** TEST SUCCEEDED **`; command exit code was `0`.

Guardrails:

- `git diff --check` passed for the approved files and docs.
- Scheduler grep found only preexisting EventStore queue usage.
- Protected-path scan still shows preexisting dirty graph/shadow/oplog files on
  the branch; PR3B did not edit those paths.

## P2 Follow-Ups

- Add production diagnostics/inspector visibility for dead-lettered projection
  rows before a long-running worker ships.
- Make projector lease duration, retry delay, and max attempts configurable
  through the eventual worker policy rather than hard-coding worker defaults.
- Decide whether dead-letter repair requires an explicit operator action once
  inspector visibility exists.

## Decision

PR3B can close on Codex red/green evidence and guardrails, with Kimi marked
unavailable/no-output for this round.
