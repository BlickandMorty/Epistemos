# LOOP PROMPT (queue-driven) — paste as the build-loop directive (2026-06-22)

You are the Epistemos build loop. EVERY iteration, do EXACTLY this — in order, no skipping:

1. **RE-READ `docs/WORK_QUEUE_2026_06_22.md` IN FULL.** It is short — read all of it every time. It is your
   source of truth for WHAT to do and in WHAT order.
2. **Pick the FIRST unchecked `[ ]` (or `[~]` needing work) item, top of the queue down.** TIER 0 before TIER 1,
   etc. Do NOT jump ahead. Do NOT move to a lower tier while a TIER-0 item is unchecked/unverified.
3. **Read ONLY that item's `→plan:` section(s)** in docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md for the
   exact specifics/acceptance. (This is how you get the detail WITHOUT re-reading all 1,700 lines.) If the item
   references another doc, read that slice too.
4. **DO the item for REAL** — actual code, the additive-safe way, no stub, no fake-done.
5. **VERIFY:** fast gate (cargo test --lib / targeted compile) for logic; for any UI/runtime item, it is NOT
   done until it RENDERS/WORKS at runtime. If you cannot prove runtime headlessly, mark `[~]` "built, NEEDS
   owner/computer-use runtime-verify" — NEVER `[x]`. Build-green is NOT done (this is why act kept failing).
6. **UPDATE `docs/WORK_QUEUE_2026_06_22.md`**: set the item `[x]` (runtime-verified) or `[~]` (built, needs
   runtime-verify) + a one-line result. Commit + push (Co-Authored-By Claude). 
7. **Do NOT continue past a broken/unverified TIER-0 item.** If TIER-0 isn't all `[x]`/`[~]`-with-real-progress,
   keep working TIER 0. Owner P0 runtime reports preempt everything — pivot instantly, add to queue TIER 0.

STANDING (the queue's STANDING section applies to every item): no fake-done · runtime-verify UI · no red on
main · code-more-build-less (fast per-increment gate; heavy xcodebuild only at checkpoints; never idle-block) ·
never delete chat IP · NO-ADDED-TERMS (build owner intent as-is) · NO-QUEUE-JUMPING · latest-owner-directive-wins
· 70B/new-model EXCLUDED · Companion clones OFF-LIMITS · main-only.

WHY THIS PROMPT: the plan grew to ~1,700 lines and re-reading it whole each loop made you point-fix incoherently
+ ship UI "done" on build-green that didn't render. The QUEUE is small (re-read fully every loop) and each item
points to its exact plan slice (read only that). So you always do the right next thing with the right specifics,
update status every loop, and never forget or drift. The plan stays full as the authority — the queue is the
execution index.
