# SS-G — Click-to-installed local models: the simplest robust path (2026-06-19)

Read-only research (subagent), code-grounded. Feeds SETTINGS_SIMPLIFICATION_HUB + the MODEL-DOWNLOAD/INSTALL
ledger item (owner's **#1 visible blocker**: *"I can't find a way to install the local models"*).
**Headline: the engine pipeline is ROBUST; the blocker is pure UX discoverability + a MISSING per-model
Install affordance for the models the owner names.** Fix ≈ 1 focused slice, no engine rewrite.

## Why the owner can't install
- The only install UI is **4 levels deep behind a button in a modal sheet** under a mislabeled section:
  Settings → "Models" category → **"Inference"** section → `InferenceDetailView` → "Manage Local Models"
  button (`SettingsView.swift:1814`) → `.sheet` `LocalModelManagerSheet` (`:3174`/`:1983`). "Inference" is not
  a word an owner maps to "install models" (= SS-B finding C).
- Inside the sheet the owner sees the **"Epistemos AI" one-tap package** (`:3212`, `installEpistemosFoundation
  Package()` `LocalModelInfrastructure.swift:2701`) — **all-or-nothing**, `.disabled` once complete (`:3266`),
  no per-model install. This is the only affordance most owners ever see (matches "it only lets me get the
  foundation package").
- The **"All models (advanced)" disclosure is collapsed** + renders the WRONG set: `curated/optionalBaseline
  Descriptors` (`SettingsView.swift:3327-3338`) are **MLX-only** (Qwen/DeepSeek/Bonsai/Llama/QwQ). **Gemma,
  LFM2, VibeThinker — the models the owner names verbatim — are NOT in either list** (they're GGUF foundation
  models in `GemmaQATRuntimeLadder.candidates`). And those MLX Install buttons mostly hit dead "Unsupported
  model type" labels (`:3818`).
- `ModelStackSettingsView` (`:3401`) DOES enumerate the full retained catalog incl. the named GGUF models with
  name/size/RAM/Installed-badge — **but its only per-row control is an advertise Toggle (`:106-113`); NO Install
  button.** So the one surface that shows the owner's models offers no way to install them.

**Engine is fine.** download→verify→atomic-finalize→resume is robust (STEP-2/3 + D2): `ModelDownloadManager
.install` (`:28-114`) resumable staging, runtime-aware verify (GGUF = non-empty `.gguf`, `:157`), HF-LFS etag
checksum (`:196`), atomic `replaceItemAt` (`:97`); partial KEPT on net-fail, deleted only on verify-fail (`:87`);
D2 purge-exemption for `-resume` (`:2494`). Live progress wired end-to-end (`:2666`→`:2595`→`ProgressView(value:)
:3555`). Install download is correctly **NOT entitlement-gated** — only hardware + disk (`:2642,2651`).
`descriptor(for:)` resolves GGUF ids via `gemmaQATGGUFDescriptors` (`:1613`), and `installEpistemosFoundation
Package` already proves per-GGUF `install(modelID:)` works (`:2704-2713`) — **individual GGUF install is fully
supported by the engine; only the UI button is missing.**

## The fix (highest-leverage first)
1. **[M, #1] Add a per-row Install/Installing/Installed control to `ModelStackSettingsView`** (`:79-116`),
   wired to `localModelManager.install(modelID:)` (`:2631`) + `presentationState(for:)` (`:2588`), reusing
   `ModelInstallProgressDisplay.from(fraction:)` (`:2452`) — exactly what `LocalModelRow` already does
   (`:3471`). State-driven: not-installed→**Install** · installing→live `ProgressView` "Downloading N%" ·
   installed→**Installed** badge + Delete/Reinstall · unsupported→honest "Needs N GB", never a fake Install.
   **This single fix makes Gemma/LFM2/VibeThinker individually installable with live progress** and clears
   INSTALL-ANY (req 5) + the named-models requirement (req 11) in one move.
2. **[M] Promote the install surface OUT of the modal** — make the `LocalModelManagerSheet` body the
   Models/Inference detail content; remove the button + `.sheet` (`:1814,1983`); rename "Inference" → "Models"
   (`.inference` enum label `:109`). (= SS-B "Models is a label not a home".)
3. **[S] De-dup the install lists** — drop the MLX-only "All models (advanced)" disclosure + `curated/
   optionalBaselineDescriptors` sections (`:3307-3396`); the stack already covers the full catalog. Keep the
   one-tap package on top + the legacy-cleanup section.
4. **[S] Surface the verify phase + bounded download retry** — label the 100% indeterminate state "Verifying…"
   (`ModelInstallProgressDisplay.indeterminate` exists) so finalize doesn't look frozen; add bounded retry around
   `client.downloadSnapshot` (`ModelDownloadManager.swift:58`) for transient network errors.
5. **[S] Verify immediate selectability** — `install(modelID:)` already calls `syncInferenceInstalledSets()` +
   `adoptInstalledTextModelIfNeeded` (`:2673-2674`); confirm the picker refreshes live
   (`releaseSelectableInstalledLocalTextModelIDs`).

## Honest gating (preserve)
Download is correctly ungated (hardware + disk only). The **runtime** is what's gated: GGUF candidates are held
out of the chat picker/auto-route until they carry route-evidence (`isProductRouteIntegrationCandidate` `:490`;
`supportedAvailableGemmaQATRuntimeCandidates` `InferenceState.swift:3990`); GGUF runtime is in-process
`LocalGGUFClient` (no subprocess, honors NO-HIDDEN-SIDECAR). **Rule: the Install button ALWAYS downloads; if a
model's runtime is Pro/owner-gated, the row's *selectable-in-picker* state (not its Install button) shows the
honest "Pro/runtime pending" badge. Never grey-out Install for a gating reason — only hardware/disk.**

## Acceptance bar (the owner's)
> Owner opens Settings → **Models** (top-level, no hunting), sees every model (Gemma/LFM2/VibeThinker/Qwen/…)
> each with name/size/RAM/state, clicks **Install**, **watches a live bar count up**, sees **Installed**, and the
> model is **immediately selectable in the picker and runs** (or shows an honest "runtime Pro-gated" state) — all
> **without opening a sheet or expanding a disclosure.** Pass = find Install → click → watch → use.

Key files: `Views/Settings/SettingsView.swift` (sheet `:1983`, button `:1814`, `LocalModelManagerSheet :3174`,
install rows `:3288-3419`, disclosure `:3307`, `LocalModelRow :3464`, `ProgressView(value:) :3555`, "Unsupported"
`:3818`) · `Views/Settings/ModelStackSettingsView.swift` (full-catalog list, missing Install `:79-116`) ·
`Engine/LocalModelInfrastructure.swift` (`install :2631`, `presentationState :2588`, baseline lists `:1551-1592`,
`descriptor(for:) :1613`, `gemmaQATGGUFDescriptors :1507`, package `:2701`, progress `:2452`, D2 exempt `:2494`)
· `Engine/ModelDownloadManager.swift` (verify `:136`, checksum `:196`, finalize `:97`, retry site `:58`) ·
`Engine/AdvertisedModelStore.swift` (`ModelStackRow`).
