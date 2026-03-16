---
name: UI/UX Hardening Audit
description: Aggressive recursive audit skill for toolbar dynamics, scroll stability, layout churn, dead UI code, animation-driver conflicts, accessibility regressions, and performance hardening.
---

# UI/UX Hardening Audit

Use this skill when the task is to aggressively audit and harden the app's UI behavior, especially scroll stability, toolbar dynamics, layout churn, architectural residue, and performance regressions.

## Operating rules

1. Create or refresh the reusable harness in `tools/ui_hardening_skill/` before running the audit.
2. Treat main chat scroll, mini chat scroll, and notes scroll as first-class failure domains.
3. Verify every suspected root cause against the code before fixing it.
4. Prefer the smallest architectural correction that removes the most runtime instability.
5. Add a regression test for every confirmed bug.
6. Re-run the relevant harness scripts and targeted tests after each fix.

## Run order

1. `tools/ui_hardening_skill/run_full_audit.sh`
2. Implement the highest-signal fixes.
3. Re-run:
   - `tools/ui_hardening_skill/run_scroll_audit.sh`
   - `tools/ui_hardening_skill/run_layout_churn_audit.sh`
   - `tools/ui_hardening_skill/run_perf_audit.sh`
4. If toolbar dynamics changed, also re-run:
   - `tools/ui_hardening_skill/run_toolbar_audit.sh`
   - `tools/ui_hardening_skill/run_dead_code_audit.sh`

## Required outputs

- A report under `docs/audits/ui-hardening/`
- A report bundle under `tools/ui_hardening_skill/reports/<timestamp>/`
- Regression tests for confirmed failures

## Minimum evidence

- Static scan findings from the harness
- Targeted `xcodebuild` test output for the added regression suites
- Build or profile evidence when scroll or render performance is changed
