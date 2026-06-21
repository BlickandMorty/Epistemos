# SS-CHATMODEL P0 — chat default keeps landing on Qwen / stuck small-Gemma on EXISTING installs (owner 5th report 2026-06-21)

Owner (verbatim, frustrated, 5th+ report): "regular chat keeps defaulting to qwen or it will just stay gemma 2... everything about the chat is just not working." The prior fix (89ef5a206) was FRESH-INSTALL ONLY + flag-gated picker — it never reached the owner's existing install. GREEN-BUT-NOT-REACHING.

## GROUNDED ROOT CAUSE (read in code, not guessed)
1. `InferenceState.recommendedLocalTextModelID` is HARDCODED `.qwen3_4B4Bit` (InferenceState.swift:3057-3058). It's the source-of-truth "recommended" feeding live paths (e.g. initialDefaultLocalTextModelID legacy branch :4377 returns `snapshot.recommendedLocalTextModelID.rawValue`; baseLocalRuntimeContentLength; recommendedConstrainedLocalTextModelID). So the LIVE default leans Qwen.
2. PERSISTED pick wins: `preferredLocalTextModelID`/`preferredChatModelSelection` persist to UserDefaults (keys `epistemos.preferredLocalTextModelID` / `epistemos.preferredChatModelSelection`, persistPreferredChatModelSelection :5388-5401) and load AFTER init (:5392-5397), overriding the new init default. An existing install with a stale persisted Qwen KEEPS Qwen — 89ef5a206 (fresh-install/unset only) never touches it.
3. The visible effort/model PICKER is flag-gated default-OFF (`EPISTEMOS_FAST_EFFORT_PICKER_V0`, da2209add) → owner has no reachable live way to change the model → stuck on Qwen or small Gemma.

## THE REAL FIX (LIVE, reaches existing installs, NOT flag-gated, test the PERSISTED path)
A. `recommendedLocalTextModelID` (:3057) → headroom-aware Gemma (reuse initialDefaultLocalTextModelID logic), never hardcoded Qwen. Audit every consumer for Qwen-lean.
B. ONE-TIME MIGRATION of stale persisted default: on load, if persisted `preferredLocalTextModelID` is the OLD auto-default Qwen, repair it to the headroom-aware Gemma default — keyed by a `epistemos.modelDefaultMigratedV2` flag so it runs once and never stomps a DELIBERATE Qwen choice (if owner truly wants Qwen they re-pick; both stay available). This is the piece that actually reaches the owner.
C. A WORKING, REACHABLE model picker on the chat surface (the flag-gated effort picker is unreachable) — so the owner can change models live. Either default-on the picker or ensure the existing runtime picker changes the model + persists.
D. TEST the EXISTING-INSTALL path: seed UserDefaults with persisted Qwen → after launch/migration, resolved chat model = Gemma (not Qwen); deliberate-Qwen-pick is preserved; full routing matrix; NO SS-CR regression. Not just fresh-install.

Acceptance = owner on a real existing install gets Gemma by default + can change it live + it sticks. DONE only when witnessed/owner-confirmed, not fresh-install-test-green.
