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

## ✅ SHIPPED (loop, bc960d3db, 2026-06-21): the REAL-reason half is now honest + tested
The monitor's "state the REAL reason, not a generic not-installed" ask is DONE for the GGUF Gemma case. Root, verified in
code: `localPickUnavailableReason` (InferenceState.swift:4276) ran its runtime-unavailable check ONLY inside
`if let model = LocalTextModelID(rawValue: pickID)`, and the owner's pick `google/gemma-4-E2B-it-qat-q4_0-gguf` is NOT a
`LocalTextModelID` (it is a `GemmaQATRuntimeCandidate`), so it skipped the check and fell through to `.notInstalled`.
Fix: a pure `nonisolated static ggufGemmaCandidateRuntimeReason(pickID:availableRuntimeKinds:)` returns `.runtimeUnavailable`
for a known Gemma GGUF candidate when `.gguf` is not in the runtime set. Wired into `localPickUnavailableReason`; the composer
note (ChatInputBar:829) + Settings `LocalRouteHonestyHealthRow` now read "its runtime isn't available on this build", not
the false "not installed on this Mac". Real-state test (`LocalGgufPickReasonTests`) pins the owner's exact pick + every
staged GGUF Gemma id. **Display-only — the reason flows ONLY into `.substituted`/`.noLocalModel` (verified: no routing
consumer), so this carries zero SS-CR / routing risk** (why it shipped unguarded vs. the routing changes below).

## ⏳ STILL OWNER-GATED (the routing half — items 1/2/4 above): blocked on "no runnable Gemma installed"
The honest-REASON is now correct, but the underlying SILENT SWAP (Gemma pick → Qwen at sanitizedInteractiveLocalTextModelID:6252)
still fires, because the ground truth on the owner's rig is: **no Gemma that is BOTH installed AND runnable in an available
runtime exists.** The runnable MLX Gemma `gemma3_4BQAT4Bit` (mlx-community/gemma-3-4b-it-qat-4bit — NOT in the gemma4
awaiting-loader set, so genuinely runnable today) is the candidate, but it is not installed; the installed Gemmas are all
GGUF (lane off → `.runtimeUnavailable`) or gemma4-MLX (`isAwaitingSwiftRuntimeLoader`). So removing the swap now → resolver
returns nil → chat auto-routes to cloud and fails on credentials → breaks chat (the exact reason the 6252 block was added).
Required fix ORDER (the no-swap edit CANNOT go first):
  1. Make a runnable Gemma the default — owner architecture call: (a) curate/auto-install `gemma3_4BQAT4Bit` (MLX, runnable
     with GGUF lane off) into the Fast lineup + make it the GGUF-off default; OR (b) enable the GGUF lane for the build
     (Pro/dev: `EPISTEMOS_LOCAL_GGUF_CLI_RUNTIME_V0`, MAS-sandbox-blocked); OR (c) land a working MLX gemma4 loader.
     Default resolution must be runtime-aware (check `availableLocalGenerationRuntimeKinds`), never default onto an
     unrunnable pick — `initialDefaultLocalTextModelID` (4412) currently filters Fast candidates by MEMORY only, so it
     returns a GGUF Gemma even when the GGUF lane is off.
  2. THEN eliminate the silent 6252 swap + add the composer install/pick-another affordance (now safe: a runnable default
     means the swap rarely fires, and when a pick truly can't run the honest surface replaces the silent cloud-fail).
  3. Verify on the owner's real install: pick loads → runs the Gemma; pick can't load → honest surfaced message, never silent Qwen.

## 🔑 CORRECTION + SHIPPED (loop, 2026-06-21): option (c) is ALREADY DONE — the MLX gemma4 loader is vendored; the gate is stale
Re-investigating the "no runnable Gemma installed" blocker surfaced a contradiction the code flags against ITSELF:
- The native Apple **Gemma 4 MLX loader IS vendored + registered** — `LocalPackages/mlx-swift-lm/Libraries/MLXLLM/Models/Gemma4Text.swift` + `Gemma4.swift`, registered in `LLMModelFactory` as `"gemma4"`/`"gemma4_text"` (commit `0b5312173`, 2026-06-14, replacing the prior Gemma-3n alias).
- The owner's installed `mlx-community/gemma-4-e2b-it-4bit` `config.json` has top-level `model_type: "gemma4"` — which **matches** the registry entry. So the old "Unsupported model type: gemma4" (on-device 2026-06-16, `3ba6a5667`) predates / contradicts the current registration.
- The code's OWN sibling property `isHeldOutOfAutomaticLocalRouting` (InferenceState.swift:661) documents the real intent verbatim: *"the dense E2B/E4B tiers now run (native Apple MLX port + GGUF llama-cli lane), so `isAwaitingSwiftRuntimeLoader` is no longer false-for-the-right-reason for them"* — i.e. dense gemma4 RUNS + is explicitly selectable, but must stay out of AUTOMATIC routing. `isAwaitingSwiftRuntimeLoader == true` for E2B/E4B is the **stale half** of that contradiction.
- Could not prove generation headlessly: running the package's own `testGemma4E2BLoadsAndGeneratesCoherentTokens` failed at `MLX error: Failed to load the default metallib` — an env wall (MLX's Metal lib isn't loadable under bare `swift test`), NOT a gemma4 decode error. The owner's real app bundle CAN load the metallib.

**Shipped this firing (flag-gated `EPISTEMOS_MLX_GEMMA4_DENSE_RUNNABLE_V0`, default OFF, reversible):**
  - `isAwaitingSwiftRuntimeLoader` returns `!flag` for dense `.gemma4_2B4Bit`/`.gemma4_4B4Bit` (MoE 26B + 31B stay unconditionally gated). `isHeldOutOfAutomaticLocalRouting` unchanged → no automatic-route leak, source guards intact.
  - `migrateGgufGemmaDefaultToMlx` (+ pure `mlxEquivalent(forGgufGemmaID:)`): one-time GGUF Gemma default → same-size MLX Gemma (E2B→`gemma4_2B4Bit`, E4B→`gemma4_4B4Bit`), only GGUF Gemma picks touched. So the owner's persisted `gemma-4-E2B-gguf` → runnable MLX `gemma-4-e2b-4bit` with NO Qwen substitution.
  - Real-state tests (`MlxGemma4DenseRunnableMigrationTests`): owner's exact pick maps + migrates; flag-OFF no-op; gate default preserved (TriageServiceTests' "all 4 tiers gated" still green).
  - **Reversible by design:** flag OFF → dense MLX tiers awaiting-loader again → `migrateStaleGemma4Selection` rewrites them to the foundation default. So a wrong on-device result does no permanent harm.

**OWNER ACTION to reach you live:** set `EPISTEMOS_MLX_GEMMA4_DENSE_RUNNABLE_V0=1` and relaunch. Expected: your persisted Gemma migrates to MLX `gemma-4-e2b-it-4bit` and runs (no Qwen). If it generates coherent text → next firing flips the flag default-ON live (the static evidence says it will). If it errors → the metallib/decode truth is then known on-device and we keep the gate + pursue `gemma3_4BQAT4Bit` install instead.
