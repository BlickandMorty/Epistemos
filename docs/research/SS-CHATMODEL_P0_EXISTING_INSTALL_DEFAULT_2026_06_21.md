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

## ⚠️ CORRECTED DIAGNOSIS (monitor real-state check via `defaults read com.epistemos.app`, 2026-06-21)
The owner's ACTUAL persisted state is NOT Qwen — it is `epistemos.preferredLocalTextModelID =
google/gemma-4-E2B-it-qat-q4_0-gguf` (tiny E2B Gemma). So the migration (b64188984, repairs persisted *Qwen*) does
NOT touch the owner's state → does NOT fix the report. DOWNGRADED to "staged, not reaching the user."
REAL root (grounded): `sanitizedInteractiveLocalTextModelID` migrates a not-installed/unavailable pick → `recommended`
(InferenceState.swift comment ~:4256 "not-installed → recommended"), and `recommendedLocalTextModelID` = HARDCODED
`.qwen3_4B4Bit` (:3057). So:
- persisted E2B loads → owner "stays gemma 2[B]" (stuck tiny);
- persisted E2B can't load (GGUF not installed / runtime unavailable — no .gguf found under app support) → fallback =
  recommended = **Qwen** → owner "defaults to qwen". Both symptoms = ONE root: tiny-E2B default + Qwen fallback.
REAL FIX (Part A is now THE critical piece, not the Qwen migration):
1. `recommendedLocalTextModelID` (:3057) → headroom-aware Gemma (the SAME initialDefaultLocalTextModelID logic), so the
   not-installed/unavailable FALLBACK is a real Gemma, never Qwen. Resolve the type issue (it returns LocalTextModelID
   but the working Gemma is a GGUF descriptor) — pick a runnable Gemma the loader supports, or change the return type.
2. Don't strand the owner on tiny E2B: the headroom-aware default should pick the largest Gemma that fits (E4B/12B if
   RAM allows), and/or repair a persisted tiny-E2B-auto-default similarly to the Qwen migration.
3. Reachable picker so the owner can change it live.
VERIFY AGAINST THE OWNER'S REAL STATE: persisted Gemma-E2B (+ E2B unavailable) → resolves to a real Gemma, NEVER Qwen;
confirm via `defaults read` after launch and/or the resolution unit test seeded with E2B (not Qwen).

## ‼️ OWNER REFRAME (2026-06-21): this IS a no-hidden-fallback violation (SS-HF) — eliminate it, don't re-point it
Owner: "remember NO FALLBACKS — that literally should have been fixed." Correct. The `not-installed/unavailable pick →
recommendedLocalTextModelID` SILENT migration in sanitizedInteractiveLocalTextModelID is precisely the hidden fallback
SS-HF said to remove. The fix is NOT "make the fallback Gemma instead of Qwen" — it is:
1. **NO SILENT SUBSTITUTION.** The chat runs the model the user PICKED. If that pick can't load, the app does NOT
   silently swap to recommended/Qwen/any other model.
2. **DEFAULT MUST BE RUNNABLE.** The fresh/headroom-aware default must be a model that is actually INSTALLED + loadable,
   so no fallback is ever needed (if nothing capable is installed, prompt to install — honestly — don't fake a model).
3. **HONEST AT POINT OF USE** (SS-HF, already started 8a09bdbb3): if a pick is unavailable, surface it where the user
   is (chat composer): "Gemma E2B isn't loaded — [install] / [pick another]" — never a silent Qwen.
4. Remove/neutralize the `recommended`-as-silent-fallback path; keep both Qwens + all Gemmas as EXPLICIT picks only.
VERIFY against the owner's REAL state (persisted Gemma-E2B): pick loads → runs E2B; pick can't load → HONEST surfaced
message, NEVER a silent Qwen. No hidden fallback anywhere on the chat model-resolution path.

## ‼️ FURTHER GROUNDED FINDING (monitor, 2026-06-21): E2B IS installed → fallback is RUNTIME-unavailable, not missing-file
The persisted Gemma E2B GGUF IS on disk: `~/Library/Application Support/Epistemos/Models/text/hub/
models--google--gemma-4-E2B-it-qat-q4_0-gguf/snapshots/.../gemma-4-E2B_q4_0-it.gguf` (+ ModelQuarantine copy; 12B GGUF +
26B staging + mlx gemma-4-e2b also present). So `localPickUnavailableReason` is NOT `.notInstalled` — it is almost
certainly `.runtimeUnavailable` (the GGUF/llama lane is not in `availableLocalGenerationRuntimeKinds` on the live path)
or `.exceedsMemory`. THAT is what trips the silent `sanitizedInteractiveLocalTextModelID` migration → recommended(Qwen).
Implications for the no-fallback fix:
- The honest point-of-use message must state the REAL reason ("Gemma E2B needs the GGUF runtime, which isn't enabled" /
  "exceeds memory"), determined from localPickUnavailableReason — not a generic "not installed".
- The DEFAULT must be a model runnable in an AVAILABLE runtime (e.g. an MLX Gemma when the GGUF lane is off) so the user
  is never defaulted onto a model whose runtime can't run → which is what forces the fallback today.
- Verify the owner's exact reason: instrument/log localPickUnavailableReason(for: gemma-4-E2B) on the real install.
Still: NO SILENT SWAP regardless of reason — run the pick or surface honestly.
