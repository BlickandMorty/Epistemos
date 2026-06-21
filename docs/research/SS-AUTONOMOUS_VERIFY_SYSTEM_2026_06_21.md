# SS-AUTONOMOUS-VERIFY — multi-checker verification so the owner never checks manually (2026-06-21)

Owner: "I will NOT be checking manually. Use computer-use or some type of thing. Make sure the agent continues
building, never stops. If something is unfinished, add it back to the plan to audit/re-research. If something is NOT
being touched at all, maybe you're adding the wrong thing -> needs more research. Have other checkers do different
checks. A robust way to make sure this actually gets built without me wasting time."

## THE CHECKERS (different angles, all autonomous — no owner)
1. **NEVER-STOP** — `scripts/epi_loop_watchdog.sh` (pid in /tmp/epi_watchdog.log): resumes any park within ~2 min.
   PROVEN: log shows autonomous "RESUMED a park". Monitor verifies it alive each fire; relaunch if dead.
2. **CODE-TRACE** (monitor, each notable commit): trace the LIVE path end-to-end in source (not the commit message).
   Caught the Qwen P0: recommendedLocalTextModelID hardcoded :3057 + persisted-pick-wins :5392.
3. **REAL-STATE TEST** (loop, per PROVEN-DONE): the regression test must simulate the user's actual state (persisted
   prefs / existing install), not fresh — and would have caught the original owner report.
4. **COMPUTER-USE** (monitor, after key fixes + periodically): `scripts/epi_verify_app.sh` launches the real app,
   brings it front, screenshots /tmp/epi_app_shot.png; the monitor READS the screenshot to confirm launch-smoke (no
   crash) + visually verify the fix on-screen. PROVEN 2026-06-21 (launched + read the Welcome-Back screen). For deep
   navigation, osascript System Events (Accessibility) can click/read AX; full click-through is limited (no cliclick).
5. **COVERAGE-GAP** (monitor, periodic): `scripts/epi_coverage_gap.sh` — any OPEN ledger SS-tag with 0 commits in the
   window = "not being touched -> maybe wrong slice -> RE-RESEARCH." 2026-06-21 run: 0 untouched (all open tags have ≥1
   commit). NOTE: touched != done; PROVEN-DONE real-state is the real bar.
6. **COVERAGE SWEEP + NUANCE + FOLLOW-ON-CAPTURE + nuclear review** (loop+monitor): existing SS-CLEAN gates.

## OPERATING RULE
- Loop never stops (watchdog). Unfinished -> stays [ ] + back into the walk. Untouched -> re-research the slice (the
  ask may be mapped wrong). Done -> only with PROVEN-DONE real-state proof; otherwise "staged, not reaching the user."
- The monitor runs computer-use verify after each owner-reported P0 fix (esp. SS-CHATMODEL) on a FRESH build, reads the
  screenshot, and reports what it actually saw — never "done" without that. Honest about limits, no fabricated proof.
Cross-ref SS-PROVEN_DONE_DOCTRINE, SS-CHATMODEL_P0, LOOP_HARDENED_ENGINEERING_CONTRACT.
