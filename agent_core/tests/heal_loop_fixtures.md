# Heal Loop Fixture Extraction — 2026-05-04

This file preserves the Quick Capture worktree's heal-loop eval as recovery
fixture doctrine before any main-runtime port. It is intentionally a Markdown
fixture map, not copied Rust code.

## Donor Authority

Sources:

- `.claude/worktrees/vigorous-goldberg-3a2d35/agent_core/src/heal/mod.rs`
- `.claude/worktrees/vigorous-goldberg-3a2d35/agent_core/src/heal/log.rs`
- `.claude/worktrees/vigorous-goldberg-3a2d35/agent_core/src/heal/breaker.rs`
- `.claude/worktrees/vigorous-goldberg-3a2d35/agent_core/src/eval/heal_recovery.rs`
- `.claude/worktrees/vigorous-goldberg-3a2d35/agent_core/src/bin/heal_eval.rs`

## Product Intent

The agent emits an Intent. The Rust runtime applies it. If application fails,
the failure becomes a bounded heal step: feed the failing Intent plus structured
error back to a diagnostician, request a corrected Intent, retry, and stop when
success, give-up, max steps, or breaker-open occurs.

This is not generic retry. It is Try-Heal-Retry with an auditable error and
corrected-intent trail.

## Core Runtime Shape

| Donor concept | Canonical recovery meaning |
|---|---|
| `ApplyError { kind, message, context }` | Typed failure payload; `kind` is the error taxonomy key |
| `Diagnostician` | LLM-bearing or deterministic repair function from `(Intent, ApplyError)` to corrected `Intent` |
| `GiveUpDiagnostician` | No-LLM fallback that surfaces the original error |
| `HealLoop` | Bounded retry loop around Intent application |
| `CircuitBreaker` | Shared breaker state for repeated failures |
| `HealEventLog` | Append-only `heal_events` persistence |
| `HealOutcome` | Exactly `recovered`, `abandoned`, or `escalated` |

Default donor constants:

- `DEFAULT_MAX_HEAL_STEPS = 3`
- `HEAL_BREAKER_FAILURE_THRESHOLD = 5`
- breaker cooldown: 30 seconds
- recurring prompt-drift alert: same tool + same error kind, at least 10 events
  in 7 days

## `heal_events` Shape

The donor persistence schema records:

- `id`
- `ts`
- `tool`
- `variant`
- `original_intent`
- `error`
- `corrected_intent`
- `outcome`
- `step_idx`
- `session_id`

The table is append-only, WAL-backed, and indexed by `(tool, ts)` plus
`session_id`. The donor notes that ExecutionReceipt signing belongs on these
rows during the broader receipt slice, not as an isolated shortcut.

## Synthetic 30-Case Seed

The fixture distribution is:

| Cases | Failure count before success | Expected result |
|---|---:|---|
| 20 | 1 | recovered within 1 backtrack |
| 6 | 2 | recovered within 2 backtracks |
| 3 | 3 | recovered within 3 backtracks |
| 1 | 4 | abandoned |

Error kinds cycle through:

- `schema_violation`
- `io`
- `timeout`
- `permission_denied`
- `conflict`

The fixture uses vault-write intents such as `notes/case-000.md` with simple
body/frontmatter payloads, plus explicit single-case guards for stuck and
first-try-success behavior.

## Exit-Gate Divergence To Preserve

The donor comments contain a contradiction that must not be erased:

- `heal_eval.rs` describes exit code 0 as "report generated and
  `passes_phase_11_exit()` is true".
- `heal_recovery.rs` defines the stricter exit gate as at least 85% recovered
  within 1 backtrack and at least 97% recovered within 3 backtracks.
- The synthetic 30-case distribution yields 20/30 within 1 backtrack
  (66.7%) and 29/30 within 3 backtracks (96.7%), so the donor tests state that
  the synthetic baseline intentionally fails the production exit gate.

Recovery rule: treat this seed as a regression corpus for loop mechanics, not
as a completed ship gate. A production diagnostician must beat the seed.

## Recovery Placement

Track: T4 Resonance Gate / verification, with T2 ExecutionReceipt attachment
and T13 agent-runtime observability.

Recovery stage:

- A-F recovery: preserve the loop shape, event schema, and 30-case seed.
- B.1 / Hermes runtime: introduce typed repair/retry only after Intent and
  ApplyError shapes are stable in main.
- Provenance Console: surface heal patterns and receipt verification in user
  visible trace UI.

## Porting Bar

Before live code moves from the donor:

1. Read current main `agent_core` Intent, tool execution, approval, and
   RunEventLog paths.
2. Add tests for max-step, give-up, breaker-open, success-after-correction, and
   event-log append behavior.
3. Make the exit-gate expectation explicit: fixture-regression pass is not the
   same as production ship pass.
4. Attach ExecutionReceipt to mutating effects.
5. Keep `escalated` reserved until a real higher-tier handler exists.
