# Mamba2 Phase 1 Completion

Date: 2026-04-08

## Phase 1 status

Phase 1 is complete.

Phase 1 in this repo now means:

- the custom Metal helper runtime compiles and warms on Apple Silicon
- the helper path is wired into MLX load-time preparation
- SSM state persistence is real and resumed end to end
- the diagnostic helper forward pass is compile-validated and test-validated
- unsupported release claims are hidden or downgraded

Phase 1 does not mean the custom Metal runtime is the live generation backend.

## What is now complete

### 1. Runtime metadata and warmup wiring

- `LocalTextModelID.mamba2_2B4Bit` exposes an `SSMRuntimeProfile`.
- The MLX local load path calls `prepareCustomSSMRuntimeIfNeeded`.
- On Apple Silicon, that warmup now:
  - compiles all 14 helper kernels
  - allocates shared state buffers
  - allocates the inference heap

### 2. Safe architecture support

- Apple Silicon builds keep the real helper diagnostic path.
- Non-Apple-Silicon slices no longer try to compile dead `Float16` helper code.
- The previous universal Release failure on x86_64 is fixed.

This is a truth-preserving gate, not a fake portability claim.

### 3. SSM persistence path

- Mamba2 save/resume passed live on 2026-04-08 through the MLX path.
- `ConversationPersistence.shared.bindSSMStatePath(...)` remains wired from `AppBootstrap`.
- State files were saved and resumed from disk successfully during live smoke.
- In-memory SSM session reuse is now scoped to the active chat session id, reducing recurrent-state bleed between separate Mamba/Liquid conversations.

### 4. Constraint alignment

The validated runtime path still matches the safe research-derived constraints already adopted in source:

- chunk size `Q = 128`
- MPS matmul path retained
- shared state buffers retained
- helper runtime warmup only, not reckless backend replacement

## Runtime evidence captured on 2026-04-08

From the live Mamba2 smoke in `EpistemosTests/LocalModelInfrastructureTests.swift`:

- `MetalRuntimeManager initialized on Apple M2 Pro`
- `All 14 Mamba-2 kernels compiled successfully`
- `Allocated state buffers: 2 x 16.0MB (64 layers, H=32, N=64, D=64)`
- `Allocated inference heap: 48MB`
- `Prepared custom SSM runtime for mlx-community/mamba2-2.7b-4bit chunk=128 heap=50331648`
- SSM save/resume completed successfully across two generations

Also observed repeatedly:

- `No chat template was included or provided, so converting messages to simple text format.`

That warning is real and still needs cleanup before anyone claims the Mamba chat UX is fully tuned.

## What remains intentionally unfinished

### 1. Custom Metal generation backend

The helper runtime is not the live token generation engine.

Current truth:

- recurrent state persistence is real
- helper kernels are real
- diagnostic forward pass is real
- token generation still runs through MLX

Do not document or market this as a completed custom Metal Mamba backend.

### 2. Agent-mode claims

Mamba2 agent mode remains hidden from the release path.

This is intentional and correct until all of the following are validated with runtime evidence:

- tool behavior
- long-context behavior
- stable chat formatting
- failure handling
- repeated end-to-end quality

### 3. Full model-experience validation

Phase 1 completion does not cover:

- quality benchmarking
- thinking-mode validation
- tool-use validation
- file/reference comprehension validation
- full local-model parity sweep

## Release posture after this phase

### Safe to claim

- Mamba2 supports MLX-based local generation.
- Mamba2 supports SSM state save/resume.
- Apple Silicon builds warm the custom Metal helper runtime during preparation.

### Not safe to claim

- custom Metal Mamba generation is live
- Mamba2 is a validated local agent model
- Mamba2 release UX is fully tuned

## Next phase recommendation

Phase 2 should focus on truth-preserving usability, not architectural fantasy:

1. Add or validate a proper chat template for Mamba2.
2. Run explicit attachment/reference quality checks for Mamba2.
3. Decide whether any part of the custom helper runtime should become part of the real inference path, and only do so behind a feature gate with numerical validation.
4. Keep agent mode hidden until those checks pass.
