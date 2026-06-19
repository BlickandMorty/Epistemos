# Native finetune substrate verdict — kill the Python QLoRA/MoLoRA black boxes (2026-06-18)

**Verdict: REPLACE the Python finetune subprocess path with the ALREADY-VENDORED
native mlx-swift-lm LoRA trainer. This is WIRING, not a from-scratch port — the
native substrate (`MLXLLM.LoRATrain`, `loadLoRAData`, `MLXLMCommon`
`LoRAConfiguration`/`LoRAContainer`) is already in `LocalPackages/mlx-swift-lm`
and linked (MLXLLM + MLXLMCommon). No `.py` on the MAS path. Kill-order below;
first native slice (the chat→text data bridge) LANDED this pass.**

## The Python black boxes (NO-SIDECAR violations)
All three spawn `/usr/bin/python3` via `Process()` — already MAS-incompatible
(the code itself notes "the App Store sandbox cannot spawn /usr/bin/python3"),
gated `#if !EPISTEMOS_APP_STORE`, Pro/dev-only. The owner wants them GONE, not
just gated.

| Piece | What it does | Invocation |
|---|---|---|
| `Training/QLoRATrainer.swift` | QLoRA finetune → adapter `.safetensors` + `training_metadata.json` | `Process()` → `train_knowledge.py` / `train_style.py` (both use **mlx-lm** — see the progress parser "mlx-lm training log format") |
| `MoLoRA/MoLoRAInferenceService.swift` | Mixture-of-LoRA adapter inference (decide-once routing from layer-0 hidden states) | long-lived `Process()` → `molora_inference.py`, stdin/stdout JSON lines |
| `PythonEnvironmentManager.swift` | Finds a system/homebrew python3, manages a venv, installs pip deps | venv + subprocess |
| `MOHAWK/*.py` + `Training/scripts/*.py` | Training-data generation + a RunPod **remote** training pipeline | python scripts / `runpod_full_pipeline.sh` |

## The native substrate is ALREADY vendored
`LocalPackages/mlx-swift-lm` (a linked local package; MLXLLM + MLXLMCommon are in
the build) ships everything the Python did:
- **`MLXLLM/LoraTrain.swift`** — `LoRATrain.train(model, train, validate, optimizer, loss, tokenizer, parameters:)` (the native training loop, mlx-lm parity).
- **`MLXLLM/Lora+Data.swift`** — `loadLoRAData(directory:name:)` / `loadLoRAData(url:)` / `loadJSONL`.
- **`MLXLMCommon/Adapters/LoRA/`** — `LoRAConfiguration` (rank/scale/keys, `.lora`/`.dora`), `LoRAContainer` (load/apply/fuse/remove adapters at runtime), `LoRALinear` / `QLoRALinear` / `DoRALinear`.
- `skills/mlx-swift-lm/references/lora-adapters.md` — the API guide.

So the Epistemos-side `TrainingConfig` + `AdapterMetadata` (already Swift) map
directly onto `LoRAConfiguration` + the trainer's `Parameters`; QLoRA = LoRA over
a quantized base (`QLoRALinear`), which the native container already supports.

## The one real gap (closed this pass)
`loadJSONL` decodes ONLY `{"text": …}`. Epistemos emits CHAT JSONL
(`{"messages": [{"role","content"}, …]}` — verified in
`MOHAWK/epistemos_training_data/train.jsonl`). So the native trainer can't read
Epistemos data as-is. **First native slice (LANDED):**
`Training/LoRAChatDataConverter.swift` — a pure, unit-tested converter that
flattens each chat example into a ChatML training string and emits the
`{"text": …}` JSONL the native `loadLoRAData`/`LoRATrain` consume. No Python.
INERT until the trainer slice wires it.

## Kill-order (incremental, each verified, Pro/in-process, MAS-safe)
1. ✅ **Data bridge** — `LoRAChatDataConverter` (chat JSONL → `{"text": …}`). DONE.
2. **Native trainer** — `NativeLoRATrainer` (Swift) wrapping `MLXLLM.LoRATrain.train`
   + `LoRAConfiguration` from `TrainingConfig`, producing the same adapter
   `.safetensors` + `AdapterMetadata`. Flag-gated, replaces `QLoRATrainer`'s
   `#if !EPISTEMOS_APP_STORE` Process body. In-process MLX on Apple Silicon.
3. **Native adapter apply** — use `LoRAContainer.load/apply` for inference with a
   trained adapter (the MLX inference lane already exists); deprecate
   `molora_inference.py`. MoLoRA routing (decide-once over multiple adapters) is a
   follow-on — start with single-adapter apply (covers the knowledge/style vault
   adapters), then port the router natively if still wanted.
4. **Native data-gen** — port the `MOHAWK` data-generation to Swift (it reads the
   vault + emits chat JSONL; `VaultAnalyzer.swift` already does vault analysis in
   Swift). RunPod remote training is Pro/dev infra, not a MAS path — keep it out
   of the app entirely.
5. **Delete** (own commits, grep-proven dead): `train_*.py`, `molora_inference.py`,
   `sgmm_kernel.py`, `train_router.py`, `PythonEnvironmentManager.swift`, the
   `Process()` bodies in QLoRATrainer/MoLoRAInferenceService once their native
   replacements ship + are wired.

## ProvenanceGate
The native source is `LocalPackages/mlx-swift-lm` — already vendored, MIT
(ml-explore/mlx-swift-examples lineage), already in the build. No new third-party
logic enters; we WIRE an existing linked package. `F-ProprietaryCompression-
ProvenanceGate` posture: `direct_import` (the package is already a dependency).

## Net
The expensive part (a native MLX LoRA trainer) is DONE upstream and already in
the repo. The work is: bridge the data (done), wire `LoRATrain.train` behind the
existing `TrainingConfig`/`AdapterMetadata` types, swap adapter apply to
`LoRAContainer`, port data-gen to Swift, then delete the `.py`. Every step is
in-process Swift+MLX — zero subprocess, MAS-safe (training itself stays Pro by
cost/entitlement, but via NATIVE code, not Python). First slice shipped; trainer
slice is next.
