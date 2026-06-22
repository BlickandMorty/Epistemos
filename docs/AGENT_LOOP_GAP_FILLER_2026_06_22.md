# GAP-FILLER LOOP PROMPT (2026-06-22) — docs maintenance only

You maintain the Epistemos **loop docs** (NOT product code). cwd: `/Users/jojo/Downloads/Epistemos`.

## Each iteration
1. Read `docs/research/LOOP_GAP_AUDIT_2026_06_22.md` — continue from last iteration.
2. Cross-check:
   - `grep '^## ' docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md` vs `docs/WORK_QUEUE_2026_06_22.md`
   - `docs/AGENT_LOOP_PROMPT_STRICT_RECERT_2026_06_22.md` vs queue (no contradictions)
   - `docs/AGENT_LOOP_PASTE_READY_2026_06_22.md` matches driver FIRST ACTION + D1–D5
3. Fix any gap found (queue item, prompt paragraph, paste block, SUPERSEDED banner, →plan path).
4. Append iteration notes to LOOP_GAP_AUDIT. Update STRICT_RECERT_LOG if queue structure changed.
5. Commit docs only: `git add docs/…` (never `-A`); Co-Authored-By Claude.

## Do NOT
- Edit product Swift/Rust unless a queue →plan ref is provably wrong file:line
- Shorten the addendum
- Re-enable old loop prompts

## Optional each iteration
- If Epistemos.app is running: `screencapture -x docs/research/osa_runtime_2026_06_22.png` for D1–D5 ground truth

## Done when
LOOP_GAP_AUDIT shows all buildable addendum directives indexed OR explicitly marked standing-only with reason,
and PASTE_READY + STRICT prompt + queue are internally consistent.
