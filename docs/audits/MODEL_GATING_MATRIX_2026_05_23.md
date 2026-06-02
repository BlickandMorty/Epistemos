# Model Gating Matrix — 2026-05-23

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

Audit doc per **ISSUE-2026-05-16-015** safe-auto-fix protocol
(`docs/APP_ISSUES_AUTO_FIX.md:64`). Produced by walking every gating
site referenced in the issue's investigation log and cross-checking
against the live source.

This is the **doctrine-cross-check** deliverable. It surfaces which
of the user's "i still cant use higher models" frustrations resolve
to honest-and-doctrinally-correct gates vs. stale-or-overly-conservative
gates that should be revisited. No code changed; this is observation.

## TL;DR — gates ranked by likelihood of being the user's blocker

| Rank | Gate site | Doctrine alignment | Likely impact on user |
|------|-----------|---------------------|------------------------|
| 1 | `LocalToolGrammar.supportsStructuredToolCalling` (`.swift:147-153`) | NEEDS-RUNTIME-PROBE | If `canImport(CMLXStructured)` is false at runtime, EVERY local model gets `supportsAgentMode = false`. UI shows agent mode unavailable for all local models. |
| 2 | `primaryAgentModelMinHostRAMGB` (`LocalModelInfrastructure.swift` = 32) | HONEST DENSE-PATH GATE | Keeps dense 36B-class MLX agent models off on 16 GB hosts. V6.1/V6.2 ternary + KV-Direct + sparse-active + EML/Geometry/Scan IR doctrine remains the Capability Ceiling route, but the dense gate must not drop until `F-70B-Local-Cocktail` or an equivalent SSD/RAM composition falsifier passes. |
| 3 | `canActAsAgent` switch in `InferenceState.swift:420` | DOCTRINALLY-HONEST (per RCA-LOCAL-AGENT-GRAMMAR-001) | Excludes Gemma 3/4 and Mistral families because they emit malformed `<tool_call>` XML. Honest at the model level. Re-enable path documented in the comment (lines 434-438). |
| 4 | `hasConfiguredCloudAccess` in `InferenceState.swift:4643` | HONEST-BUT-INVISIBLE | Cloud picks silently route to local when API key missing OR Focus mode `forceLocalModelsOnly` is set. The fallback is correct; the UX is the issue — user can't see WHY cloud isn't selectable. |
| 5 | `ConfidenceRouter.hasCapableLocalAgentModel` (`.swift:299`) | DERIVED — composes 1+3 | Combines `LocalToolGrammar.supportsLocalAgentLoop` and `canActAsAgent`. Will be correct if upstream gates are correct. |

## Detail — every gating site mapped

### G1. `LocalToolGrammar.supportsStructuredToolCalling`
**File**: `Epistemos/LocalAgent/LocalToolGrammar.swift:147-153`

```swift
static var supportsStructuredToolCalling: Bool {
    #if canImport(MLXStructured) && canImport(CMLXStructured) && canImport(JSONSchema)
    true
    #else
    false
    #endif
}
```

**Issue**: Requires ALL three modules to resolve. `Epistemos.xcodeproj`
links the `MLXStructured` product from `mlx-swift-structured`, but:
- `CMLXStructured` is an internal target (not exported as a public product)
- `JSONSchema` is a transitive dep of MLXStructured via `swift-json-schema`

**Doctrine reference**: User memory ([HELIOS V5 Substrate LANDED 2026-05-06](MEMORY.md)) — substrate uses MLX-Swift through structured outputs. The local-agent path documented in V6.1 doctrine should be live.

**Next action**: Runtime probe — add a `#if DEBUG` log at app startup printing `LocalToolGrammar.supportsStructuredToolCalling` to confirm whether this gate is firing true or false in the actual build. **If false → root cause of "i still cant use higher models".**

### G2. `primaryAgentModelMinHostRAMGB`
**File**: `Epistemos/Engine/LocalModelInfrastructure.swift`

```swift
nonisolated static let primaryAgentModelMinHostRAMGB: Int = 32
nonisolated static let primaryAgentModelMinHostRAMGB_powerUser: Int = 32
nonisolated static func minRAMForPrimaryAgentModel(isPowerUser: Bool) -> Int {
    return isPowerUser ? primaryAgentModelMinHostRAMGB_powerUser : primaryAgentModelMinHostRAMGB
}
```

**Issue**: `32` is derived from dense-4bit arithmetic (`36B × 0.5 GB ≈ 18 GB resident`). That is correct for the current dense MLX path. It does NOT prove the no-compromise substrate ceiling has failed; it only says the current route is not yet the ACS/UAS cocktail.

| Substrate primitive | Effect on 36B resident | Doctrine source |
|---------------------|------------------------|------------------|
| Ternary kernel (BitNet b1.58-class) | 36B at ternary ≈ **9 GB** instead of 18 GB | `agent_core/src/research/ternary/` (11 files, 3,385 LOC) + V6.1 E5 |
| Sherry/Leech lattice VQ | Sub-4bit-dense equivalent | `agent_core/src/research/sherry_lattice/` (1,582 LOC) |
| KV-Direct memory-arch floor | Eliminates per-token KV cache growth | V6.1 falsifier #2 + `agent_core/src/kv_direct/` |
| Sparse-active assembly | MoE-aware loading of only active experts | V6.1 Five-Plane Assembly + MASTER_FUSION §3.x |
| EML / Geometry / Scan IR | Turns eligible kernels, layers, and transforms into typed charts instead of opaque blobs | `docs/fusion/ADDRESSABLE_NEURAL_SUBSTRATE_CANON_2026_05_24.md` §6 |

**2026-05-27 correction**: Power-user mode is now a Capability Ceiling posture, not a memory bypass. It keeps research controls visible but **does not lower the 36B dense memory gate**. The 16 GB route must be reopened through `F-70B-Local-Cocktail`, `F-KV-Direct-Gate`, `F-UAS-CopyCount`, PageGather packetized caller-path consumption, active assembly, and a real local artifact.

**Next action**: Keep Settings honest and build the substrate path. When the cocktail passes, add a new model-route class for SSD/RAM addressable execution instead of mutating the dense MLX gate.

### G3. `canActAsAgent` switch
**File**: `Epistemos/State/InferenceState.swift:420-462`

**Status**: DOCTRINALLY HONEST.

The exclusion list (Gemma 3/4, Mistral, Devstral) is grounded in
RCA-LOCAL-AGENT-GRAMMAR-001 (2026-05-14): those families emit malformed
`<tool_call>` XML under the Hermes-style grammar the app uses. User
screenshot confirmed gemma3_4BQAT4Bit failure.

Re-enable path is documented in source (lines 434-438): prove tool-call
grammar honored by MLXStructured strict masking OR document a working
soft-guidance template, then add a source-guard test.

**Next action**: None for now. This gate is doing its job. When the user wants Gemma/Mistral agent mode, the work is to wire family-specific tool-call grammars, not to flip this gate.

### G4. `hasConfiguredCloudAccess`
**File**: `Epistemos/State/InferenceState.swift:4643`

Used in 6+ call sites (lines 4239, 4315, 4506, 4630, 4686, 4691, 4724, 4729, 4755, 5077, 5094) for honest provider-readiness checking.

**Status**: HONEST-BUT-INVISIBLE.

The gate itself is correct (it asks "does the user have a key for this provider in Keychain?"). The UX gap is what the user sees when it returns false: silent fallback to local. The user wanted: explicit "Cloud key missing — add one in Settings" affordance + per-model capability badge.

**Next action**: When the cloud picker hits `hasConfiguredCloudAccess = false`, show an inline `.notice` row in the model picker (not a silent skip). The `APIKeysHealthRow` (mentioned in `Status: Patched (APIKeysHealthRow shipped 35120f79b)`) already surfaces per-provider key state — the picker just needs to thread that state into its item-level rendering.

### G5. `ConfidenceRouter.hasCapableLocalAgentModel`
**File**: `Epistemos/LocalAgent/ConfidenceRouter.swift:299`

Used in 2 call sites (lines 176, 279). Derived gate — composes `LocalToolGrammar.supportsLocalAgentLoop` and `canActAsAgent`.

**Status**: DERIVED — will be correct iff G1 + G3 are correct.

If G1 evaluates false in the live build (per the runtime probe recommended above), this gate cascades to "no model qualifies" which is the user's observed symptom.

## What changed since ISSUE-2026-05-16-015 was filed

The investigation log (lines 144-152 of the issue) names:
> "Added §4.E sub-mission to docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md so Codex's autonomous loop picks this up + audits + drafts a fix plan before any irreversible code change."

That Codex sub-mission has not landed an audit doc on main yet. This file (`MODEL_GATING_MATRIX_2026_05_23.md`) is the first audit-deliverable response to that sub-mission. It does not change any source — only surfaces what's already in the code.

## Recommended next actions (in priority order)

1. **Runtime probe (safe-auto-fix)** — add `#if DEBUG` startup log of `LocalToolGrammar.supportsStructuredToolCalling`, `cloudProviderValidationStates`, and `LocalHardwareCapabilitySnapshot.current`. Confirms G1 + G4 behaviour in the live app target. Single-file edit, no behaviour change.
2. **Capability Ceiling model gate (safe-auto-fix)** — keep power-user mode visible, but do not let it lower the dense 36B RAM gate. Unlock the 16 GB path only through a separate SSD/RAM addressable-substrate route with a passing artifact.
3. **Cloud-key affordance (destructive, needs sign-off)** — make `hasConfiguredCloudAccess = false` produce an inline picker notice with a "Set up keys" button, not a silent fallback.
4. **Family-specific tool-call grammars (multi-week)** — wire Gemma's function-call-JSON grammar + Mistral's [INST] convention. Will let G3 re-include those families.
5. **Ternary + ACS/UAS inference wiring (multi-week)** — make V6.1/V6.2's ternary, KV-Direct, PageGather, Active Assembly, and EML/Geometry/Scan IR claims runtime reality. This is what can honestly open the 16 GB / 70B-class Capability Ceiling path.

## File map cross-reference

```
G1: Epistemos/LocalAgent/LocalToolGrammar.swift:147-161
G2: Epistemos/Engine/LocalModelInfrastructure.swift:1046, 1066, 1075, 1089, 1102
G3: Epistemos/State/InferenceState.swift:420-462
G4: Epistemos/State/InferenceState.swift:4643 (definition)
    Epistemos/State/InferenceState.swift:4239,4315,4506,4630,4686,4691,4724,4729,4755,5077,5094 (call sites)
G5: Epistemos/LocalAgent/ConfidenceRouter.swift:176, 279, 299
Derived (UI surface):
    Epistemos/State/InferenceState.swift:475 (supportsAgentMode = canActAsAgent && supportsStructuredToolCalling)
    Epistemos/State/InferenceState.swift:468 (canRunLocalAgentLoop = canActAsAgent && supportsLocalAgentLoop)
```
