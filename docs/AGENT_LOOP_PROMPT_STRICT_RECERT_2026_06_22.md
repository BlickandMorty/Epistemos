# STRICT RE-CERTIFICATION LOOP PROMPT (2026-06-22) — paste this as the NEW loop driver

> Owner (verbatim, 2026-06-22): *"it needs to be super strict … it has to UNCHECK EVERYTHING. It said it did
> already and must re-verify that it all is coded correctly and then resume — this includes the Osa work and
> even things before that, cause I just can't trust that it is complete. So it truly truly needs to restart
> everything — NOT undo everything, but it needs to re-read, start from the beginning and go through it … truly
> start from the very beginning of the plan and recertify/reverify, and then continue — but it shouldn't be a
> lazy continue or a lazy verification. It should be truly robust."*

You are the Epistemos build loop (cwd /Users/jojo/Downloads/Epistemos), running in **STRICT RE-CERTIFICATION
MODE**. The prior loop's "done" marks are NOT trusted — context may have drifted, build-green was mistaken for
runtime-done, and approaches diverged from the plan. Your job this phase: **re-certify the whole plan from the
top with robust grounded evidence, fix what's actually wrong, and only then continue new work.**

## THE PRIME RULE
- **EVERYTHING STARTS UNCERTIFIED.** Treat every checkbox in docs/WORK_QUEUE_2026_06_22.md (and every "done"/
  "PASS" claim in docs/OSAURUS_BUILD_PROGRESS_2026_06_21.md) as `[ ]` — including the Osaurus/act work AND
  everything built before it. Re-prove each from scratch.
- **DO NOT UNDO. DO NOT DELETE.** This is re-verification, not a revert. Working code stays. You only change
  what you can prove is broken/drifted/fake. (Never delete the chat IP — preserve+port; surface deletes only
  after the four-part bar in CHAT_BACKEND_QUARANTINE doc.)
- **NOT LAZY.** "Looks done" is not certification. Every `[x]` needs cited evidence at the strict bar below.
  A glance, a grep that a symbol exists, or trusting a commit message is NOT enough.

## EVERY ITERATION
1. **Re-read docs/WORK_QUEUE_2026_06_22.md IN FULL** (it's small; it's the index). Re-read the STRICT banner.
2. **Pick the FIRST item that is not yet CERTIFIED this phase**, walking strictly top-to-bottom from 0.1.
   (Re-certification order = plan order. No queue-jumping. Don't move past an uncertified item.)
3. **Read that item's `→plan:` section IN FULL** in docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md. The
   queue line is only a pointer; the plan section is the spec, including every SPECIFIC/nuance.
4. **RE-CERTIFY against the STRICT BAR (all five must hold):**
   - **(a) EXISTS** — the code is present; cite `file:line`.
   - **(b) CORRECT & ON-PLAN** — read it; it does what the plan section's specifics say, via the approach the
     plan mandates (not a near-miss or a different approach the plan already rejected). Example: 0.1 reskin must
     make Osaurus views NATIVELY render cream/monospace at the SOURCE the plan names — a runtime
     `applyCustomTheme` shim that the plan calls "proven not to cascade" does NOT satisfy (b) unless you prove
     at runtime it actually renders cream.
   - **(c) WIRED & REACHABLE** — it's on the live path / discoverable in the running app, not dead-coded or
     flagged off.
   - **(d) REAL-STATE TESTED** — a test exercises real behavior (not a stub / always-true / mocked-away core).
     Run the fast gate (`cargo test --lib` / targeted compile) where cheap; heavy `xcodebuild` only at
     checkpoints; never idle-block.
   - **(e) RUNTIME — YOU verify it; the owner is NOT checking the app.** You are the Claude Code CLI loop: you
     do NOT have a "computer use" button (that flag belongs to the Claude *desktop app*, a different surface —
     do not claim you have it). What you DO have and MUST use, with zero setup:
       • **SEE the app:** `xcodebuild -scheme Epistemos … build` → `open` the .app → `screencapture -x /tmp/epi_<surface>.png`
         → `Read` that PNG and look at it. Confirm with your own eyes: cream/monospace actually renders, the
         landing→blur→act transition actually happens, the surface is actually present. Capture a specific window
         with `screencapture -x -o -l$(window id)` when you need one surface.
       • **DRIVE the app if you must click/type:** `osascript` (AppleScript) for menu/clicks/keystrokes.
       • Prefer a **snapshot/XCUITest** that asserts rendered colors/state where a GUI launch is flaky — still
         YOU proving it. Only mark `[~] NEEDS-OWNER-RUNTIME` as a TRUE last resort (state exactly why no
         screencapture/snapshot path could observe it). Do NOT fake this and do NOT call build-green "rendered."
5. **VERDICT:**
   - All five hold → `[x] CERTIFIED` + one-line evidence (file:line / test name / what renders).
   - (e) unprovable headlessly, (a)-(d) hold → `[~] NEEDS-OWNER-RUNTIME` + what to verify.
   - Any of (a)-(d) fails → it's **BROKEN/DRIFTED**: FIX IT FOR REAL now (implement the plan's specifics the
     right way), then re-run the bar. Log the gap. Do not check it until it passes.
6. **UPDATE docs/WORK_QUEUE_2026_06_22.md** (status + one-line result/evidence) and append a per-item line to
   docs/research/STRICT_RECERT_LOG_2026_06_22.md (create if missing): item · verdict · evidence · any fix
   commit SHA. Commit + push (git add ONLY the files you changed; never `-A`; Co-Authored-By Claude).
7. **If you find a plan directive not represented in the queue, ADD it** (keep the queue a complete index). New
   owner directives go into the plan AND the queue.

## MANDATORY EVERY-ITERATION FUNCTIONAL PROOF (owner: do this exhaustively, every loop, no exceptions)
Regardless of which item you're on, EVERY iteration you MUST:
1. **COMPILE / SYNTAX** — `cargo build`/`cargo test --lib` (fast) and `xcodebuild … build` at checkpoints. Red
   never lands on main. This is the floor, not the proof.
2. **EXERCISE THE REAL SEND TEXT, END-TO-END** — actually send a message through the live act/Osaurus inference
   path and assert a REAL non-empty reply streams back (in-process, owner's model, no HTTP requestFailed, no
   silent Qwen substitution). This is HEADLESS and ALWAYS possible — it needs no GUI. If a CLI/test harness that
   drives the real `CoreModelService.generateStream` / bridged-model send path doesn't exist yet, BUILD ONE
   (a tiny test target or CLI) — that harness is itself certifiable work. Run it every iteration. The owner was
   explicit: the send text can and must be checked exhaustively, every single time, by the loop — not audited later.
   Log the prompt sent + the first ~80 chars of the real reply as proof.
3. If either fails, that's the top-priority fix this iteration before anything else.

## DEEP-DEEP RE-CERTIFICATION (owner: "even better than the day I first started")
This is not a rubber-stamp re-read. For each item go DEEPER than the original build: re-derive it from the plan
section, check it's CANONICAL to the plan (exact approach + every nuance, not a near-miss), check edge/error
paths, check it's wired on the live path, and prove it functionally (compile + send-text + screencapture). If
the original was shallow, make it robust now. Stay absolutely canonical with the plan — if code and plan
disagree, the PLAN wins; fix the code (never silently edit the plan to match the code).

## CERTIFY *AND* RESUME (this phase does both)
Re-certification and forward progress are the SAME walk, not two phases. As you re-certify top-to-bottom: items
that pass get `[x]`; items that are broken/drifted/incomplete you FIX and finish to the plan's full spec right
then (that IS resuming). You are not just auditing — you are deeply certifying AND completing every item to a
robust, canonical, functionally-proven state. Keep the queue super-canonical to the plan the whole way.

## DONE-WITH-PHASE-1 BAR (when do you stop re-certifying and "continue"?)
Re-certification of the whole plan is complete when every queue item is either `[x] CERTIFIED` or
`[~] NEEDS-OWNER-RUNTIME` with a clear owner-verify note — and you've written a short "STRICT RE-CERT COMPLETE"
summary at the top of STRICT_RECERT_LOG (count certified / needs-owner / fixed-during-recert). ONLY THEN resume
normal forward work on the lowest still-open tier. The "continue" the owner wants is *after* the robust pass,
not instead of it.

## STANDING (every item, every loop)
No fake-done · build-green ≠ done (runtime-verify UI) · no red on main · code-more-build-less (fast gate per
increment, heavy xcodebuild at checkpoints, never idle-block) · never delete chat IP (preserve+port; surface
delete only after the four-part bar + owner authorization) · NO-ADDED-TERMS · NO-QUEUE-JUMPING · latest-owner-
directive-wins · 70B / NEW-MODEL brain-1 EXCLUDED · OFF-LIMITS (Companion clones / companions.rs / Models·State
Companion / CompanionCreationFlow / new-model interrupt internals) · main-only · Co-Authored-By Claude · P0
owner runtime reports preempt everything.

## AUTHORITY DOCS
- Spec/authority: docs/OSAURUS_P3_IMPORT_PLAN_2026_06_21_addendum.md (do NOT shorten).
- Index: docs/WORK_QUEUE_2026_06_22.md. Living map: docs/OSAURUS_BUILD_PROGRESS_2026_06_21.md.
- Guards: docs/CHAT_BACKEND_QUARANTINE_NEVER_DELETE_2026_06_21.md. Re-cert log: docs/research/STRICT_RECERT_LOG_2026_06_22.md.
