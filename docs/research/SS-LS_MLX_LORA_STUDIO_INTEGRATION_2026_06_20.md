# SS-LS — MLX-LoRA-Studio → embed + fuse a native fine-tuning STUDIO into Epistemos (2026-06-20)

Owner request (verbatim, 2026-06-20): *"so this is something I wanna add absolutely to my app completely clone
it and infuse it with my already replace it replace my my training one with this and then maybe add my training
data to this new one, but I want to add this new one to my app and then all the things that my app does with
training just fuse it with it or add this new one like add to this new one but like yeah, give it a rescan, etc.
and I want this actually be useful. I want to be able to actually use the models right after they're done, etc.
and of course I don't want to delete any any part of mine. I just wanna add mine into the new one."*
Source: https://github.com/Goekdeniz-Guelmez/MLX-LoRA-Studio/releases/tag/v1.0.0

Authority = `OWNER_REQUESTS_LEDGER_2026_06_18.md` (MLX-LORA-STUDIO item). Governing constraints (CLAUDE.md, OVERRIDE
the literal "completely clone"): **NO HIDDEN SIDECAR / no runtime subprocess on the MAS+notarized path**; APP-NATIVE
BY EMBEDDING (clone the source's *value*, never run a foreign sidecar); preserve ALL existing IP (delete nothing);
honest capability gating; local-first; pixel-art native. Cross-ref SS-AB (model profiles), SS-Z (per-model), the
TurboVec/QAT canon, and the KnowledgeFusion map below.

## What MLX-LoRA-Studio actually is (researched)
Goekdeniz-Guelmez/MLX-LoRA-Studio **v1.0.0**, **MIT license**, a native macOS `.app`/`.dmg`:
- **Swift + SwiftUI + AppKit ~85%**, **Python ~13%**, Shell ~2%.
- **Modes:** LoRA, DoRA, QLoRA (4/6/8-bit), Full fine-tune, **QAT**.
- **9 algorithms:** SFT, DPO, CPO, ORPO, GRPO, Online DPO, XPO, RLHF Reinforce, PPO.
- **Live metrics dashboard:** loss / LR / gradient-norm / throughput, recent-step charts, training logs; pause/
  resume/stop.
- **Memory:** `LiveMemoryMonitor` + `MemoryEstimator` + **ResourceGuard** hardware-viability checks.
- **Synthetic data:** prompt sets, SFT pairs, DPO preference triples → JSONL.
- **Runs archive:** status/algorithm/base-model/dataset/config/logs/adapter-paths/duration/metrics, under
  `~/Library/Application Support/MLXLoRAStudio/runs/` (YAML config).
- **HF integration:** one-click upload w/ model-card metadata.
- **Architecture:** `SwiftUI Views → AppStore (Observable) → PythonJobRunner (stdin/stdout subprocess) →
  Backend/training_runner.py → vendor/mlx-lm-lora (Python trainer)`; bundles its own Python env.

### The hard architectural conflict (decides the whole integration)
Its engine is **Python via a subprocess** (`PythonJobRunner` + `Backend/training_runner.py` + bundled Python +
`vendor/mlx-lm-lora`). Epistemos **forbids** runtime subprocess inference/training on the MAS+notarized path
(CLAUDE.md NO-HIDDEN-SIDECAR) and **already migrated its own trainer OFF Python to in-process MLX-Swift**
(the Python `Process()` was removed 2026-06-18; `QLoRATrainer.runTraining` now calls `NativeLoRATrainer.train`).
→ **Do NOT import `PythonJobRunner`/`training_runner.py`/the bundled Python/`vendor/mlx-lm-lora`.** Take the
**Swift/SwiftUI value** (MIT, directly graftable) and **port the algorithm math natively** onto the engine
Epistemos already ships. "Completely clone it" is honored as **clone all the value, natively** — not the sidecar.

## What Epistemos ALREADY has (so nothing is "replaced"/deleted — it's fused) — `Epistemos/KnowledgeFusion/`
A near-complete native LoRA pipeline already exists and is wired into Settings + an overnight scheduler:
- **Native engine (reuse as-is):** `Training/NativeLoRATrainer.swift:82-166` (real in-process MLX LoRA finetune:
  `LLMModelFactory.loadContainer` → `LoRAContainer.from(model:)` freeze+attach → `Adam` → `LoRATrain.train` →
  writes `adapters.safetensors`+`adapter_config.json`+`training_metadata.json`); `Training/QLoRATrainer.swift:50-184`
  (native wrapper); `Training/NativeLoRAPlan.swift:11-53` (pure hyperparam map, DoRA via `fineTuneType:"dora"`
  already mapped). Engine libs already linked: `MLXLLM`/`MLXLMCommon`/`MLXOptimizers`/`Transformers`
  (`project.yml:119-123,225-229`); `LoRATrain.{train,loss,evaluate,fuse,saveLoRAWeights}` +
  `LoRAContainer.{from,load(into:),fuse(with:),unload}` in `LocalPackages/mlx-swift-lm/...`. So gradients,
  optimizers, LoRA **and DoRA**, fuse-back, safetensors are all compiled in TODAY (Pro builds).
- **Registry/apply/export:** `Adapters/AdapterRegistry.swift:12-153` (atomic JSON source of truth),
  `Adapters/NativeAdapterApply.swift:25-41` (real native apply — **orphan, see gap**), `Adapters/AdapterExporter.swift`
  (`.epistemos-adapter` zip), `Adapters/AdapterRouter.swift`, `Adapters/MoLoRARouter.swift` (multi-adapter, scaffold).
- **Orchestration/UI/scheduler:** `UI/KnowledgeFusionViewModel.swift:27-511` (`trainOnVault` parse→synth→train→
  register→skills; activate/deactivate/delete/export), `UI/TrainOnVaultView.swift` + `TrainingHistoryView` +
  `AdapterSelectorView` (live in `SettingsView.swift:4942-4971`), `Alignment/TrainingScheduler.swift:51-364`
  (overnight KTO/vault/ODIA + deploy gate), `Alignment/KTOTrainer.swift` (**still Python — migrate**).
- **Data/curriculum/marketplace/skills:** `SyntheticData/*` (gen+IFD curator+ODIA), `Training/{CurriculumSorter,
  ExperienceReplayBuffer,VaultAnalyzer,TrainingProfileManager}`, `Marketplace/FineTunePack*` (dataset/loraAdapter/
  instructionPack/knowledgePack), `SkillGeneration/*`.

**Verdict:** Epistemos already owns the engine + registry + data-gen + scheduler. MLX-LoRA-Studio's net-new value =
(1) a polished **studio UI** (live dashboard, runs archive, algorithm guide, ResourceGuard) and (2) **6+ extra
training algorithms + QLoRA-quantized/QAT/full-FT modes**. The integration grafts those two onto the existing
native stack and FUSES the existing KnowledgeFusion surfaces in — deleting nothing.

## The owner's keystone — "actually use the models right after they're done" (the real blocker)
**THE broken link:** `NativeAdapterApply.apply(adapterDirectory:into:)` (`Adapters/NativeAdapterApply.swift:33`,
real, calls `LoRAContainer.from(directory:).load(into:model)`) has **NO caller in the live generation path**.
`MLXInferenceService.loadContainerIfNeeded` (`Epistemos/Engine/MLXInferenceService.swift:1942-2003`) loads the
base model with **no adapter argument**; `AdapterRegistry.getActiveAdapterConfigs()` + `AdapterLoader.adapterPath`
are computed and consumed **nowhere**. So a trained+activated adapter is bookkept "active" but **never changes a
generated token**. Closing this is the single highest-value wiring in this whole request.

Plus a fuse path and a rescan: today there is **no** path that fuses an adapter into a standalone base model and
registers it as a new selectable ModelVault entry (`LoRAContainer.fuse(with:)`/`LoRATrain.fuse` exist, unused).

## Fix-before-fuse (latent data-loss bugs — repair, never delete)
1. **Filename mismatch (silent adapter loss):** trainer writes `adapters.safetensors`
   (`NativeLoRATrainer.swift:97`) but `AdapterLoader.swift:39`, `AdapterExporter.swift:40/100/137`, and
   `TrainingScheduler.swift:334` expect `adapter_weights.safetensors`. Standardize on **`adapters.safetensors`**
   (the name `LoRAContainer.from(directory:)` requires, `LoRAContainer.swift:126`) so load/export/deploy-gate find
   natively-trained adapters.
2. **KTOTrainer still Python:** `Alignment/KTOTrainer.swift:94-96` spawns `/usr/bin/python3` — the only un-migrated
   trainer. Migrate to the native `LoRATrain` path (MAS-safe + parity with the studio's preference algos).

## Ordered build plan (graft-not-vendor; the build loop codes this — cargo --lib / single targeted swift build)
1. **[S] Repair-before-add:** fix the filename mismatch (#1) + migrate KTOTrainer off Python (#2). Tests: a
   natively-trained adapter passes loader/export/deploy-gate existence; no `/usr/bin/python3` spawn remains.
2. **[S] APPLY-GAP KEYSTONE ("use right after" #1):** in `MLXInferenceService.loadContainerIfNeeded`
   (`:1942-2003`), after `LLMModelFactory.loadContainer`, look up the active adapter (`AdapterRegistry
   .getActiveAdapters()` / `SDModelProfile.activeAdapterId`) and call `NativeAdapterApply.apply(adapterDirectory:
   into:)`; invalidate/reload the container on activate so the swap is live mid-session. Pro-gated. Falsifier:
   identical prompt yields different tokens with vs without the active adapter (proves it actually attaches).
3. **[S] FUSE-TO-MODELVAULT + RESCAN ("use right after" #2 + "give it a rescan"):** `LoRAContainer.fuse(with:)` →
   write a fused model dir into `Models/text/active` → register as a first-class selectable entry via
   `Engine/AdvertisedModelStore.swift` → trigger a model **rescan** (`KnowledgeFusionViewModel.detectInstalledModels`
   `:183-195` + HF-cache scan) so the fine-tune is immediately pickable in chat. Net-new, deletes nothing.
4. **[M] Graft the STUDIO UI onto the native engine (the "new one"):** port MLX-LoRA-Studio's SwiftUI value as new
   Epistemos views over the existing `@Observable` `KnowledgeFusionViewModel` (its AppStore-Observable pattern maps
   1:1): a **live metrics dashboard** (loss/LR/grad-norm/throughput recent-step charts — feed from
   `LoRATrain.Progress`/`TrainingProgress`), a **runs archive** (reuse `AdapterRegistry` + `training_metadata.json`),
   an **algorithm guide**, and **ResourceGuard/memory-viability** (reuse `LiveMemoryMonitor` pattern + Epistemos's
   memory-pressure hooks). **FUSE existing KF in:** the studio's Data tab = Epistemos `SyntheticDataGenerator`/
   `VaultAnalyzer`/curriculum/`FineTunePack` marketplace/`SkillGeneration`; its alignment = KTO/ODIA; its registry =
   `AdapterRegistry`. Pixel-art native skin; Pro-gated; **no PythonJobRunner**. Keep ALL existing TrainOnVault/
   TrainingHistory/AdapterSelector views (the new studio is additive — "add mine into the new one").
5. **[M] Port net-new algorithms natively onto `LoRATrain` (no Python):** Epistemos has SFT-style LoRA + DoRA +
   KTO today; add **DPO, CPO, ORPO, GRPO, Online DPO, XPO, RLHF Reinforce, PPO** + **QLoRA quantized-training / QAT
   / full fine-tune** as native loss-fn + optimizer loops on the existing MLX-Swift engine (port the *math* from
   `mlx-lm-lora`'s Apache-2.0 logic = patterns only, not an import; ProvenanceGate research_only/clean-room).
   Each algorithm Pro-gated, honest capability tiers, hardware-gated via ResourceGuard.
6. **[S/standing] Tests + perf each cycle:** apply-gap falsifier (tokens differ), fused-model-selectable test,
   per-algorithm loss-decreases smoke test, no-`/usr/bin/python3` falsifier (MAS-safe), filename round-trip, perf
   before/after. Honest/no-fake/no-green-without-witness.

## License + provenance
- **MLX-LoRA-Studio = MIT** → its **Swift/SwiftUI** views/dashboards graft via direct_import/adapter_wrap
  (ProvenanceGate clears MIT). Keep the LICENSE/attribution.
- **`vendor/mlx-lm-lora` (Apache-2.0) + the Python runner = NOT imported** (NO-HIDDEN-SIDECAR + MAS). Its algorithm
  math is reproduced natively (research_only / clean-room) onto MLX-Swift — patterns, not code lift.
- All training stays **Pro-gated** (`#if !EPISTEMOS_APP_STORE`), honest capability gating (local trainable models
  get the studio; cloud models do not advertise local fine-tune).

## Flagged for the build loop
- Inspect the actual Studio Swift source by `git clone --depth 1` into a TEMP dir to copy exact view/chart layouts
  (then delete the clone — disk just recovered; never vendor the Python tree). Do NOT add the `.dmg` or Python env
  to the repo.
- The apply-gap (step 2) is the owner's literal "use right after" — sequence it FIRST after the repairs; it's the
  cheapest highest-value win and unblocks the whole "actually useful" ask.
- Cross-ref SS-AB so a fine-tuned/fused model gets a real `ModelCapabilityProfile` (ctx/template/tier) on register,
  and SS-G/SS-C so it surfaces in the picker + installs cleanly.

Key files: `Epistemos/KnowledgeFusion/Training/NativeLoRATrainer.swift` · `…/QLoRATrainer.swift` · `…/NativeLoRAPlan
.swift` · `Adapters/{AdapterRegistry,NativeAdapterApply,AdapterLoader,AdapterExporter,MoLoRARouter}.swift` ·
`UI/KnowledgeFusionViewModel.swift` + `UI/TrainOnVaultView.swift` · `Alignment/{TrainingScheduler,KTOTrainer}.swift`
· `Engine/MLXInferenceService.swift:1942-2003` (apply-gap) · `Engine/AdvertisedModelStore.swift` (ModelVault
register) · `LocalPackages/mlx-swift-lm/.../LoraTrain.swift` + `…/Adapters/LoRA/LoRAContainer.swift` (engine).
Cross-ref SS-AB, SS-Z, SS-G, SS-C, TurboVec/QAT canon.
