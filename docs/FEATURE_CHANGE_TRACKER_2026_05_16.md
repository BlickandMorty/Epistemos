# Feature Change Tracker — 2026-05-16

**Purpose:** Every feature shipped (or substantively modified) by any terminal logs an entry. Each entry cross-references which canonical docs were updated alongside the code, so Terminal C can audit completeness.

**Status:** LIVING — append every feature ship. Cross-reference: `docs/PARALLEL_FLOW_DOCTRINE_2026_05_16.md §5 lockstep rules`, `docs/HARDENING_TRACKER_2026_05_16.md` (Phase 2 follow-on).

---

## §1. Why this tracker exists

Drift pattern observed in run 2026-05-16: a feature ships in code but the doctrine row doesn't update, or vice versa. Audit-of-audit catches it eventually but with latency.

This tracker is the **PRE-commit checklist**: before pushing, terminal verifies every relevant doc has been touched. Same-commit lockstep enforces atomicity.

---

## §2. Required doc-update checklist per feature

When any terminal ships a feature, the SAME commit must touch:

| Required | Doc | Update |
|---|---|---|
| ✓ | `agent_core/src/...` or `Epistemos/...` | The actual code |
| ✓ | `agent_core/tests/...` or `Epistemos*/Tests/...` | At least one test |
| ✓ | `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md §8` | Implementation Log row |
| ✓ | `docs/FEATURE_CHANGE_TRACKER_2026_05_16.md` (this doc) §3 | Append row |
| ✓ | `docs/HARDENING_TRACKER_2026_05_16.md §2` | Append row with all axes ⬜ |
| Conditional | `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md §3.x` or `§6 Wave row` | If feature lands a new doctrine pillar or Wave row |
| Conditional | `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md §X` | If feature touches Hermes 2.0 surface |
| Conditional | `docs/legal/licenses.md` | If feature adds a Rust crate or Swift package |
| Conditional | `docs/release/MAS_APP_REVIEW_NOTES.md` | If feature touches MAS entitlement or App Store posture |
| Conditional | `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` | If feature closes a CONFIRMED/TODO bug |
| Conditional | `docs/APP_ISSUES_AUTO_FIX.md` | If feature closes an Open opportunistic fix |
| Conditional | `docs/RESEARCH_COVERAGE_GAP_AUDIT_*` | If feature closes a gap-audit row |

**Same commit** — these docs must all update together. Cross-terminal `git push` from a single iter commit. Phase 2 hardening commits follow same lockstep.

---

## §3. Per-feature tracker (append rows as features ship)

Row format:

```
| # | Feature | Shipped (commit) | Terminal | Code path | Tests | §8 Log | MASTER_FUSION | HERMES | licenses | App Review | RECURSIVE_TODO | APP_ISSUES | Gap audit | HARDENING_TRACKER |
```

| # | Feature | Shipped | Terminal | Code | Tests | §8 | MF | HRM | Lic | AR | RT | AI | GA | HT |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | _(first row: append on first Phase 1 feature ship)_ | | | | | | | | | | | | | |
| AoA#28 | Audit-of-audit cycle #28 (iter 128) pass-through — 14-commit burst (B 7-J-envelope wave + 2 B-substrate + 1 B-doc-for-F + 3 D-self-audit + 1 A-self-audit); cadence step-back from 30-min low-touch back to 3-min cron `51f01c4e` | this commit | C | docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md §9 #28 | N/A (audit) | ✓ | N/A | N/A | N/A | N/A | N/A | N/A | ✓ | N/A |
| AoA#29 | Audit-of-audit cycle #29 (iter 129) pass-through — 3-commit window: B B2-M14 Laplace DP gate substrate lands (forward-staged at #2 doctrine row §3.42; 16 tests) + D fix(D-self-audit) harden_cli_subprocess applied to terminal.rs with autonomous 4-doc §5.6 lockstep + A T-A-27 self-audit #4 streak 4/5; distributed §5.6 lockstep mature across A/B/D | this commit | C | docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md §9 #29 | N/A (audit) | ✓ | N/A | N/A | N/A | N/A | N/A | N/A | ✓ | N/A |

Legend per cell:
- ✓ = doc updated in same commit
- N/A = doc genuinely doesn't need updating
- ⚠ = should have updated but didn't (drift; Terminal C catches)
- _(empty)_ = pending

---

## §4. Audit responsibility

Terminal C reads this tracker every audit-of-audit cycle:
1. For each row marked ✓ across the board → ON-TRACK
2. For each row with ⚠ → flag in §9 PASS-2 register + surface as DRIFT to originating terminal
3. For each row with _(empty)_ cells past 24h → flag as incomplete

---

## §5. Sample row (when Terminal A closes P0 Wave 0 vault lifecycle)

```
| 1 | Live vault lifecycle (Reset Everything clears all stale state) | <SHA> | A | Epistemos/App/AppBootstrap.swift + Vault/VaultRegistry.swift + Sync/VaultSyncService.swift | Epistemos/Tests/VaultLifecycleTests.swift | ✓ | N/A | N/A | N/A | N/A | ✓ (V1-GATE-LIVE-MAS-001 closed) | ✓ (Issue #N closed) | N/A | ✓ (HT row 1) |
```

---

## §6. Pre-commit gate (manual; future CI lint)

Before pushing any feature commit, run:
```bash
# Did the commit touch §8 Implementation Log?
git diff --cached --name-only | grep -q "MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md" || echo "WARN: §8 not touched"

# Did it touch this tracker?
git diff --cached --name-only | grep -q "FEATURE_CHANGE_TRACKER_2026_05_16.md" || echo "WARN: tracker not touched"

# Did it touch HARDENING_TRACKER?
git diff --cached --name-only | grep -q "HARDENING_TRACKER_2026_05_16.md" || echo "WARN: hardening tracker not touched"
```

Future enhancement: add this as a pre-commit hook in `.git/hooks/pre-commit` so terminals can't bypass.

---

*Living tracker. Owner: Terminal C audits; every terminal appends own feature rows. Lockstep rule per `PARALLEL_FLOW_DOCTRINE §5`.*
