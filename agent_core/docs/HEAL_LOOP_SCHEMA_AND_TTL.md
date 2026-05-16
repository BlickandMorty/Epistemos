# Heal Loop — SQLite Schema, TTL Classes, and Recurring-Pattern Detection (B2-L1)

**Status:** Doctrine row (forward-staging). Substrate NOT-STARTED in `agent_core/src/heal/` as of 2026-05-16; this doc freezes the schema + invariants so when the substrate ships, it doesn't redrift the contract.

**Source:** `docs/fusion/salvage/from-vigorous-goldberg/agent_core_src/heal/log.rs` (576 LOC) + Plan §5.7 (schema verbatim) + Plan §6.9 (WAL crash-safety) + `~/Documents/Epistemos-QuickCapture/FINAL_SYNTHESIS.md §5.5` (Wave-5 ExecutionReceipt tie-in).

**Sibling doctrine docs in `agent_core/docs/`:** `CAPTURE_ROUTING_CLASSIFIER.md` · `EXECUTION_RECEIPT_DOCTRINE_MAPPING.md` · `TOOL_MIGRATION_STATUS.md`.

---

## 1. Architectural premise

The heal loop is the agent runtime's **try → diagnose → correct → retry** mechanism for tool-call failures. Per the salvage spec's framing: every tool error becomes a heal step, not a user-facing failure; the loop captures `stderr` / schema-violation / empty-result and feeds it back to a diagnostician role with a corrected intent.

This module is **the persistence layer for that loop** — every healing attempt across every session lands here, append-only, so:

1. Recurring failure modes are auto-detectable as "prompt drift" alerts.
2. Future RunEventLog (Wave 5) can chain Ed25519 receipts to each row.
3. Post-hoc analysis of heal effectiveness has a single source-of-truth log.

---

## 2. Canonical SQLite schema (Plan §5.7 verbatim)

```sql
CREATE TABLE heal_events (
  id INTEGER PRIMARY KEY,
  ts TEXT NOT NULL,
  tool TEXT NOT NULL,
  variant TEXT NOT NULL,
  original_intent JSON NOT NULL,
  error JSON NOT NULL,
  corrected_intent JSON,
  outcome TEXT NOT NULL,    -- recovered | abandoned | escalated
  step_idx INTEGER NOT NULL,
  session_id TEXT NOT NULL
);

CREATE INDEX heal_events_tool_ts ON heal_events (tool, ts);
CREATE INDEX heal_events_session ON heal_events (session_id);
```

**Rust implementation literal** (per salvage `log.rs:101-116`):

```sql
CREATE TABLE IF NOT EXISTS heal_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT NOT NULL,
  tool TEXT NOT NULL,
  variant TEXT NOT NULL,
  original_intent TEXT NOT NULL,
  error TEXT NOT NULL,
  corrected_intent TEXT,
  outcome TEXT NOT NULL CHECK(outcome IN ('recovered','abandoned','escalated')),
  step_idx INTEGER NOT NULL,
  session_id TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS heal_events_tool_ts ON heal_events (tool, ts);
CREATE INDEX IF NOT EXISTS heal_events_session ON heal_events (session_id);
```

**Schema-shape differences from the Plan literal** (intentional, documented):

| Plan §5.7 literal | Rust literal | Why |
|---|---|---|
| `JSON NOT NULL` on `original_intent`, `error` | `TEXT NOT NULL` | SQLite has no native JSON type; `TEXT` + `serde_json` round-trip is the canonical Rust shape. |
| `JSON` on `corrected_intent` | `TEXT` (nullable) | Same reason; nullable preserves "no correction proposed" state. |
| `outcome TEXT NOT NULL` | `outcome TEXT NOT NULL CHECK(outcome IN ('recovered','abandoned','escalated'))` | DB-level enforcement of the canonical 3-value enum (defensive against malformed inserts). |
| (no session index) | `CREATE INDEX heal_events_session ON heal_events (session_id)` | Session-scoped queries (replay, debugging) need it; the recurring-pattern query uses the tool+ts index. |

---

## 3. Crash-safety invariants (Plan §6.9)

**WAL + synchronous=NORMAL.** Set at `open()` time:

```rust
conn.pragma_update(None, "journal_mode", "WAL")?;
conn.pragma_update(None, "synchronous", "NORMAL")?;
```

**Append-only by design.** The schema has no UPDATE path. Once an event is logged, the row is immutable. Justification: a mid-write crash can leave an incomplete row (which WAL discards on recovery), but it can never corrupt a prior row. This is also what makes the Wave-5 Ed25519 receipt chain viable — a tamper-evident append-only log.

**Append-batch atomicity.** `append_batch(&[HealEvent])` wraps the inserts in a single transaction so partial failures don't leave the log in an inconsistent state.

---

## 4. The 3-value outcome enum (`HealOutcome`)

Per Plan §5.7 (pinned verbatim in `log.rs:42-49`):

| Variant | Meaning |
|---|---|
| `Recovered` | Heal loop succeeded after one or more retries. The corrected intent is logged in `corrected_intent`. |
| `Abandoned` | Loop exhausted retries OR diagnostician gave up. No correction worth the user's attention. |
| `Escalated` | Punted to a higher-tier handler (user review, cloud cascade). **Reserved for Wave 8 Intent→Effect work; NOT emitted yet** per salvage source comment. |

The DB-level `CHECK(outcome IN (...))` constraint enforces this enum so any code path that tries to write `'pending'` or `'unknown'` fails fast.

Serde format: `#[serde(rename_all = "lowercase")]` — strings round-trip as `recovered` / `abandoned` / `escalated`.

---

## 5. Recurring-pattern detection ("prompt drift" alert)

Per Plan §5.7: **"Recurring heal patterns (same tool, same error class, ≥10 events in 7 days) auto-surface as a 'prompt drift' alert in the action trace UI."**

The thresholds are pinned to the plan literal as compile-time constants:

```rust
pub const DEFAULT_RECURRING_WINDOW_DAYS: i64 = 7;
pub const DEFAULT_RECURRING_MIN_EVENTS: u32 = 10;
```

The salvage test `recurring_thresholds_match_plan_5_7_literal` exists to break the build if these constants silently drift.

**Detection query shape:** `recurring_patterns(window_days, min_events)` returns `Vec<RecurringPattern { tool, error_kind, event_count }>` grouped by `(tool, error_kind)` over events with `ts >= now - window_days`.

**Storage / surfacing split (per salvage source comment lines 223-226):** this module ships **storage + query only**; the UI surfacing of the alert lands in Phase 8 observability work, NOT here. This boundary prevents the heal-loop substrate from leaking UI concerns.

---

## 6. TTL classes (forward-stage discipline)

The salvage source as it stands today has **no automatic eviction**. The audit row's "TTL classes (24h default, 7d for auto-research wins)" framing is the canonical post-Wave-5 design that lands when:

1. **Wave 5 stabilize** ships the per-vault Keychain Ed25519 signing key (per `log.rs:144-148` TODO comment).
2. **Wave 8** lands Intent→Effect work that emits the `Escalated` outcome and exposes the prompt-drift alert UI surface.

**Forward-staged TTL doctrine** (lands alongside Wave 5+8):

| Class | TTL | Trigger | Eviction policy |
|---|---|---|---|
| **Default** | 24h | Routine heal events that recovered or were abandoned | Lazy eviction on next `append()` if event count exceeds `MAX_DEFAULT_ROWS` AND `ts < now - 24h`. |
| **Auto-research win** | 7d | Events where `outcome == Recovered` AND `tool ∈ {auto_research.*, vault.search, web.fetch}` AND the correction surfaced a new claim | Same lazy-eviction pattern, longer TTL because these feed the morning auto-research report. |
| **Escalated** | NEVER | `outcome == Escalated` | Sticky until user reviews. Surfaced in the prompt-drift alert UI. |

**Why lazy not periodic.** Active eviction requires a NightBrain task body (per `docs/NIGHTBRAIN_SCHEDULER_POLICY_2026_05_15.md` — see B2-L2 sibling row). Lazy eviction on every append amortizes the cost without requiring a scheduler — preferred for V1.x.

---

## 7. Wave-5 Ed25519 receipt tie-in (TODO at `log.rs:144-148`)

When Wave 5 ships per-vault Keychain Ed25519 signing keys, each `append()` mints an `ExecutionReceipt` signed with that key. The receipt chain is a proof-of-execution audit trail; tampering with the log invalidates the chain.

This is the **chain integrity invariant** that the existing 4 provenance primitives (ClaimLedger · ExecutionReceipt §5.1 · RunEventLog · `.epbundle`) cannot provide for heal-loop events specifically — heal events have their own append cadence (one per tool-error) distinct from per-call ExecutionReceipts.

Per salvage source comment: "Lands together with the broader RunEventLog (Effect / Intent receipts) during Wave 5 stabilize, not piecemeal here."

---

## 8. 30-case eval fixture methodology (sibling row B2-L1 follow-up)

The audit row's "30-case eval methodology embedded in heal_eval.rs" is the **acceptance bar** for the heal loop's effectiveness. Forward-stage:

- Lands at `agent_core/tests/heal_loop_fixtures.md` (per audit destination).
- Each fixture: `original_intent` + injected `error` + expected `corrected_intent` + expected `outcome`.
- 30 cases span the canonical failure modes: schema violation · permission denied · path traversal · empty result · token limit · rate limit · breaker open · stale model · MCP transport error · etc.
- Fixture-test gate: ≥80% recovery rate across the 30 cases before the heal loop is promoted from research-tier to production-default.

This document does NOT include the 30 fixtures themselves — that's a separate slice (`heal_loop_fixtures.md` extraction from `heal_eval.rs` source). This row freezes the schema + invariants only.

---

## 9. Module layout (forward-stage)

When the substrate lands in main:

```
agent_core/src/heal/
├── mod.rs           — module entry, exports
├── log.rs           — HealEventLog, schema, append, recurring_patterns
├── outcome.rs       — HealOutcome enum + serde
├── retry.rs         — retry policy (separate doctrine row, not B2-L1)
└── diagnose.rs      — diagnostician role (separate doctrine row)

agent_core/tests/heal_loop_fixtures.md   ← 30-case eval (B2-L1 follow-up)
```

This doctrine row freezes `log.rs` shape only. `outcome.rs`, `retry.rs`, `diagnose.rs` are separate concerns.

---

## 10. Cross-references

- B2-L1 PASS 2 audit row (this doctrine row's source).
- `docs/fusion/salvage/from-vigorous-goldberg/agent_core_src/heal/log.rs` (576 LOC) — salvage source with full Rust API.
- `~/Documents/Epistemos-QuickCapture/FINAL_SYNTHESIS.md §5.5` — Wave-5 ExecutionReceipt tie-in (TODO at `log.rs:144-148`).
- B2-L2 (sibling, PASS 2) — NightBrain idle scheduler that drives lazy eviction.
- `MASTER_FUSION §3.40` Run Ledger — sibling per-token attestation primitive (orthogonal granularity).
- `HERMES_AGENT_CORE_2_0_DESIGN §5.1` ExecutionReceipt — sibling per-tool-call attestation.
- `agent_core/docs/EXECUTION_RECEIPT_DOCTRINE_MAPPING.md` — adjacent doctrine doc on the ExecutionReceipt surface.
- Plan §5.7 (the canonical heal-loop spec).
- Plan §6.9 (WAL crash-safety doctrine).

---

*— B2-L1 doctrine row. Schema + invariants frozen. Substrate `agent_core/src/heal/` lands when prioritized; eval fixtures land at `agent_core/tests/heal_loop_fixtures.md` separately.*
