---
id: 2EC20A9D-4F6D-4877-A2E9-261C2E1E6AE6
title: "SS-PROVEN-DONE — \"done\" means PROVEN to reach the user in their REAL state (owner 2026-06-21)"
---

# SS-PROVEN-DONE — "done" means PROVEN to reach the user in their REAL state (owner 2026-06-21)

Owner (verbatim): "since this exists with the Qwen [bug], it must exist with other things — assume almost ALL items are  
NOT done / unfinished. Build a more robust, more PROVEN way to make sure they all get done correctly so I don't have to  
keep checking manually — one check and it's good. STOP saying things are done if they're not done."

The Qwen P0 (SS-CHATMODEL) exposed the failure mode: a fix was tested FRESH-INSTALL + flag-gated-OFF, marked done, but  
the owner's EXISTING install (persisted prefs) was never touched. Test-green ≠ reaches-the-user. This doctrine raises the  
bar for EVERY item and mandates a re-audit of everything already called done.

## THE NEW "DONE" BAR — all five required, or it is NOT done

1. **REAL-STATE, not clean-room.** The verifying test must simulate the user's ACTUAL state, not a pristine one:  
 existing install with PERSISTED UserDefaults/prefs (not fresh/unset), real model availability (installed vs not),  
 real credential/vault/device conditions. A fresh-install-only or empty-state test does NOT prove done.
2. **LIVE, not flag-gated-off.** An owner-reported BUG FIX must be ON the path the user actually hits — default-ON once  
 its regression guard passes. A default-OFF flag means the user never sees the fix = NOT done (it's a staged increment,  
 label it "staged behind FLAG, not reaching the user yet"). Flags are for genuinely risky NEW features pending owner  
 opt-in, NOT for bug fixes the owner is waiting on.
3. **MIGRATION/EXISTING-USER reach.** If state persists (prefs, vault, caches, saved picks), the fix must REPAIR existing  
 persisted state (one-time migration), not just change behavior for new state. The owner is always an existing user.
4. **END-TO-END, not unit-only.** Trace the whole path the user touches (UI → state → resolution → runtime), not just  
 the one function. The Qwen unit passed; the end-to-end path (persisted pref → load → resolve) still returned Qwen.
5. **WITNESSED or HONESTLY-PENDING.** Mark [x] only with cited real-state evidence. If it can't be proven headlessly,  
 it stays [ ] with an explicit "PENDING real-state witness" — never an optimistic [x]. No "done" without proof.

## RE-AUDIT MANDATE (assume almost everything is unproven)

Treat the ENTIRE current DONE/[x] set as UNPROVEN until re-verified under the five-point bar. The loop runs a standing  
PROVEN-DONE RE-AUDIT pass: for each [x] / "audited PASS" item, re-check it against REAL user-state; if it only had  
fresh-install/flag-off/unit-green evidence, DOWNGRADE it to [ ] with a "needs real-state proof" note and a real-state  
test, then re-fix to reach the user. Priority order: the owner's repeated reports first (chat model/routing, theme,  
images, graph, voice, picker), then the rest. The monitor (last-auditor) applies the same bar — no "PASS" without  
real-state-reaching proof; a flag-gated-off or fresh-install-only commit is reported as "staged, NOT reaching the user yet."

## STANDING — no more false done

- The loop STOPS marking [x] / saying "done"/"complete" on test-green or build-green alone.
- Every owner-reported bug gets a real-state regression test that would have CAUGHT the original report.
- "Visual/live PENDING OWNER" is allowed ONLY for genuine pixel/taste verification — NOT as cover for "I didn't prove it
reaches the user." If reaching-the-user can be tested, test it.
Cross-ref SS-CHATMODEL_P0, LOOP_HARDENED_ENGINEERING_CONTRACT, SS-CLEAN DONE-RE-AUDIT, MASTER_BUILD_QUEUE.

