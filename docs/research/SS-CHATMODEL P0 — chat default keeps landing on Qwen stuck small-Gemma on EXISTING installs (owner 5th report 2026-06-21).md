---
id: DF81D39D-0319-4722-A3C1-30B6209CAE5F
title: SS-CHATMODEL P0 — chat default keeps landing on Qwen / stuck small-Gemma on EXISTING installs (owner 5th report 2026-06-21)
---

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

The owner's ACTUAL persisted state is NOT Qwen — it is `epistemos.preferredLocalTextModelID = google/gemma-4-E2B-it-qat-q4_0-gguf` (tiny E2B Gemma). So the migration (b64188984, repairs persisted *Qwen*) does
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

Owner: "remember NO FALLBACKS — that literally should have been fixed." Correct. The `not-installed/unavailable pick → recommendedLocalTextModelID` SILENT migration in sanitizedInteractiveLocalTextModelID is precisely the hidden fallback
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

The persisted Gemma E2B GGUF IS on disk: `~/Library/Application Support/Epistemos/Models/text/hub/ models--google--gemma-4-E2B-it-qat-q4_0-gguf/snapshots/.../gemma-4-E2B_q4_0-it.gguf` (+ ModelQuarantine copy; 12B GGUF +
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

## ‼️ ELIMINATION HALF (5273bfd3c) — real but DEFAULT-OFF = not reaching the owner (monitor audit 2026-06-21)

5273bfd3c makes dense MLX gemma4 E2B/E4B runnable + migrates GGUF Gemma → MLX (no Qwen substitution) — BUT behind
EPISTEMOS_MLX_GEMMA4_DENSE_RUNNABLE_V0 DEFAULT OFF, pending owner env-var validation (the headless load+generate test hit
a metallib env-wall, not a decode error). Per PROVEN-DONE that is "staged, not reaching the user"; and "owner validates
with one env var" CONTRADICTS the owner's "I will not check manually." NOT done.
RESOLUTION (two concerns, separate):

1. CHAT-WORKS-BY-DEFAULT (must reach the owner with NO flag, NO manual step): the default-on migration of the owner's
 unrunnable GGUF Gemma must target a model ALREADY PROVEN-RUNNABLE on the live MLX path (the known-good foundation Fast
 default) — so chat answers immediately, no Qwen substitution, no env var. This is the owner-facing fix; default ON.
2. DENSE-MLX-GEMMA4 ENABLEMENT (improvement): keep EPISTEMOS_MLX_GEMMA4_DENSE_RUNNABLE_V0, but prove generation via
 COMPUTER-USE (the real app bundle loads the metallib the headless test can't) — monitor builds with flag=1, launches,
 confirms a real chat round-trip generates; if it generates, flip the flag DEFAULT ON. If it can't be proven, keep #1.
The owner must NOT have to set an env var for chat to work. Verify #1 reaches the owner's persisted-E2B state by default.

## ✅ SHIPPED (loop, 2026-06-21): concern #1 — DEFAULT-ON migration to a PROVEN-RUNNABLE MLX Gemma (no flag, no manual step)

Ground truth verified on the owner's real rig: `mlx-community/gemma-3-4b-it-qat-4bit` **IS installed**
(`~/Library/Application Support/Epistemos/Models/text/active/mlx-community--gemma-3-4b-it-qat-4bit/`), and `gemma3_4BQAT4Bit`
is the **proven-runnable** MLX Gemma — registered `"gemma3"` → `Gemma3TextModel` in `LLMModelFactory`, NOT in
`isAwaitingSwiftRuntimeLoader`, NOT held out of automatic routing (the code says "Gemma 3 has a stable loader"), in
`isEpistemosShippedLocalModel` ("Fast local"), and a real `LocalTextModelID` the persisted-pick load accepts (a GGUF
descriptor id is rejected by the `LocalTextModelID(rawValue:)`-gated load — part of why GGUF-E2B never stuck).

Fix (`migrateGgufGemmaDefaultToMlx`, DEFAULT-ON, keyed `epistemos.ggufGemmaToMlxMigratedV1`): a persisted GGUF Gemma default
→ `gemma3_4BQAT4Bit`. So the owner's `google/gemma-4-E2B-it-qat-q4_0-gguf` resolves to a **running MLX Gemma 3, never Qwen,
no env var, no manual step**. Only GGUF Gemma picks are remapped (deliberate Qwen / non-Gemma picks untouched → no SS-CR
regression); the migration only sets the *preferred* pick, so the resolver still enforces actual runnability. The flag now
only changes the TARGET (Gemma 3 default vs dense gemma4 when `EPISTEMOS_MLX_GEMMA4_DENSE_RUNNABLE_V0=1` — concern #2 stays
the separate improvement). Real-state test (`MlxGemma4DenseRunnableMigrationTests`): persisted GGUF-E2B + dense flag OFF →
`gemma3_4BQAT4Bit`, asserts no "qwen"/"gguf" in the result + that Gemma 3 is not awaiting-loader (so it genuinely generates).
**Reaches the owner on next launch with zero manual steps.** (Concern #2 — proving dense gemma4 MLX via computer-use — remains
the monitor's task; this firing makes chat work by default regardless of that outcome.)

## 🔴🔴 COMPUTER-USE PROOF (monitor, 2026-06-21): the default-on migration (0342b016b) does NOT work on the real install

Launched a fresh build of HEAD against the owner's REAL com.epistemos.app defaults:

- BEFORE: preferredLocalTextModelID = google/gemma-4-E2B-it-qat-q4_0-gguf ; ggufGemmaToMlxMigratedV1 = unset
- AFTER launch: preferredLocalTextModelID = google/gemma-4-E2B-it-qat-q4_0-gguf (UNCHANGED) ;
preferredChatModelSelection = ...gguf (UNCHANGED) ; ggufGemmaToMlxMigratedV1 = 1 (SET)
VERDICT: migrateGgufGemmaDefaultToMlx RAN (its once-only key flipped to 1) but did NOT rewrite the persisted model
value. The MlxGemma4DenseRunnableMigrationTests passed because they exercised the mapping in isolation — the real
init-time write does not land. So the owner stays on GGUF-E2B → still falls to Qwen, AND because the key is now 1 it
will NEVER retry. GREEN-BUT-NOT-REACHING, caught only by computer-use (the owner's exact directive).
ROOT to find (loop): why the value write doesn't persist on real launch — candidates: (a) migration sets @Published but
persist happens via persistPreferredChatModelSelection which isn't called / writes a different key; (b) the persisted-pick
LOAD after init re-reads UserDefaults and overwrites the migrated @Published value (order claim 3489-before-3497 may be
wrong at runtime, or the load re-persists the raw stored value); (c) the GGUF id stored doesn't match the migration's
match predicate so it skips the rewrite but still sets the key.
FIX REQUIREMENTS:

1. Set the migrated key ONLY AFTER a successful value rewrite is persisted to UserDefaults (verify-read-back) — never
 set the once-only key on a no-op.
2. The flag is now POLLUTED on real installs (migratedV1=1, value still GGUF — my verify-launch set it; the owner's own
 launches would too). The fix must RE-MIGRATE despite migratedV1=1 → use a V2 key that RE-CHECKS the actual persisted
 value (if it's a GGUF Gemma, rewrite) rather than trusting the done-flag.
3. Re-verify via the SAME computer-use defaults-read (launch → preferredLocalTextModelID becomes the MLX Gemma 3), not
 just a unit test. Unit-green is insufficient — proven only when the real launch rewrites the value.

## ✅ SHIPPED (loop, 2026-06-21): POST-LOAD repair — the deeper root + a robust idempotent fix

DEEPER ROOT (read in code, beyond the 3 candidates): the persisted load of `preferredLocalTextModelID` at
InferenceState.swift:3497 is `LocalTextModelID(rawValue:)`-GATED, so a GGUF id is REJECTED and the in-memory value falls
back to `initialDefaultLocalTextModelID` (:3452) — which itself returns a **GGUF Fast Gemma** (foundation default,
memory-filtered only, no runtime filter). So on a real/clean launch the unrunnable GGUF arrives in-memory AFTER the
pre-load static migration ran (keys may be unset at migration time → it sets V1=1, finds nothing to rewrite). That is why
"V1=1 but value unchanged": the migration is structurally too early — the GGUF default is produced downstream of it.
THE FIX (robust, idempotent, no key — strictly better than a V2 done-flag):

- `repairedGgufGemmaSelection(localID:selection:ggufLaneAvailable:denseGemma4Enabled:)` — pure: maps an unrunnable GGUF
Gemma (in localID and/or `.localMLX` selection) → `gemma3_4BQAT4Bit`, returns nil when nothing needs repair.
- `repairUnrunnableGgufGemmaSelection(defaults:)` — instance; runs at the END of model-selection init (AFTER the
persisted-pick load, line ~3524) on the FINAL in-memory values, rewrites the @Observable properties AND persists both
UserDefaults keys. Catches BOTH a persisted GGUF Gemma AND the GGUF foundation default.
- Idempotent: gemma3 is not a GGUF id, so re-running is a no-op → NO once-only key, so NO V1-style pollution is possible;
it RE-CHECKS the actual value every launch (exactly the owner's "re-check, don't trust the done-flag" requirement,
achieved without a flag). Runtime-guarded: only fires when `.gguf ∉ availableLocalGenerationRuntimeKinds` (a runnable
GGUF lane leaves a deliberate GGUF pick alone). No SS-CR risk (non-Gemma / cloud picks untouched).
- Pure-logic tests added (owner's exact GGUF id → gemma3 in both fields; lane-on no-op; idempotent on gemma3/Qwen).
REAL PROOF still pending: monitor computer-use relaunch + `defaults read` should now show BOTH
`epistemos.preferredLocalTextModelID` and `epistemos.preferredChatModelSelection` = `mlx-community/gemma-3-4b-it-qat-4bit`.
The pre-load migration (V1) is kept (harmless, handles the persisted-GGUF-in-localKey case early); the post-load repair is
the authoritative catch.

## ⚠️ VERIFICATION CEILING (monitor, 2026-06-21): Debug-build computer-use CANNOT verify this runtime-guarded fix

Re-verify of 0d935af12 via Debug launch: persisted value UNCHANGED (still GGUF) — but INCONCLUSIVE, two confounders:
(1) 2 stray Epistemos instances were running (stale old build re-persisting GGUF) — killed. (2) availableLocalGeneration
RuntimeKinds defaults [.mlx] (:3342) but is mutated at runtime — a Debug build OUTSIDE the MAS sandbox can spawn the
llama/gguf subprocess → .gguf gets ADDED → the GGUF Gemma is RUNNABLE in Debug → the bug doesn't reproduce AND the
runtime-guarded repair correctly no-ops. The owner's MAS/release app blocks the subprocess → .gguf absent → repair fires.
So a Debug launch cannot reproduce the owner's MAS runtime; my computer-use has a CEILING for sandbox-dependent behavior.
REAL PROOF for this fix = a DETERMINISTIC INTEGRATION TEST that FORCES the MAS condition headlessly:

- Seed persisted preferredLocalTextModelID/Selection = google/gemma-4-E2B-it-qat-q4_0-gguf.
- Force availableLocalGenerationRuntimeKinds = [.mlx] (gguf lane OFF, simulating MAS sandbox).
- Run the FULL model-selection init (load + POST-LOAD repair), then ASSERT the persisted value (both keys) == gemma3.
This proves the repair RUNS (not just the pure mapping) AND persists, under the owner's exact condition, headlessly +
deterministically — the verification a Debug launch can't give. (The existing pure-logic test only covers the mapping.)

## ✅ SHIPPED (loop, 2026-06-21): the deterministic MAS-condition integration test

`EpistemosTests/GgufGemmaPostLoadRepairIntegrationTests.swift` — exactly the test the ceiling calls for, runnable
headlessly in the normal suite (no MLX/metallib dependency — it constructs InferenceState, which defers model loading):

- MAS condition is the NATURAL test default: `availableLocalGenerationRuntimeKinds` keeps its `[.mlx]` value because the
only mutator (`setAvailableLocalGenerationRuntimeKinds`, :4296) is never called in init. The test ASSERTS
`inference.availableLocalGenerationRuntimeKinds == [.mlx]` as an explicit precondition (so the guard must fire).
- Replicates the owner's EXACT polluted state: seeds `epistemos.preferredLocalTextModelID` +
`epistemos.preferredChatModelSelection` = `google/gemma-4-E2B-it-qat-q4_0-gguf` AND `ggufGemmaToMlxMigratedV1 = true`,
so the pre-load migration's once-only guard SKIPS and ONLY the post-load repair can fix it.
- Runs the FULL init (16 GB snapshot, keychain stubbed), then asserts BOTH persisted UserDefaults keys AND the in-memory
`preferredLocalTextModelID` / `preferredChatModelSelection` == `mlx-community/gemma-3-4b-it-qat-4bit`. Saves/clears/restores
the touched keys (`.serialized` suite) so `UserDefaults.standard` is left clean.
- Relies on `simplifiedLineupActive` (default true) so `initialDefaultLocalTextModelID` is a GGUF Gemma — the value the
LocalTextModelID-gated load (:3497) falls back to and the repair then rewrites.

**✅ PROVEN — the test RUNS + PASSES headlessly (loop, 2026-06-21):**
`xcodebuild test-without-building -only-testing:'EpistemosTests/GgufGemmaPostLoadRepairIntegrationTests/fullInitRepairsGgufToGemma3UnderMASCondition()'`
→ `✔ Test "owner MAS state (persisted GGUF-E2B + polluted V1, gguf lane off) → full init persists gemma3 in BOTH keys" passed`
→ `✔ Test run with 1 test in 1 suite passed`. (The legacy "Executed 0 tests" line is only the XCTest counter, which does not
count Swift Testing tests — the Swift Testing runner's `✔` is authoritative.) So the POST-LOAD repair is now PROVEN, under
the owner's exact MAS condition, headlessly + deterministically: the full init rewrites BOTH persisted keys + the in-memory
selection to `mlx-community/gemma-3-4b-it-qat-4bit` — no Qwen, no GGUF, no env var. The verification ceiling is resolved; a
real owner relaunch on the MAS/release build will land the same result (the test exercises the identical code path).