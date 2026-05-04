# Codex Prompt — SCOPE-Rex Substrate Update for Epistemos

You are working on Epistemos, a native macOS Swift 6 / Rust / UniFFI / Metal / MLX cognitive workspace.

Your job is not to implement every research idea. Your job is to update the project safely with the SCOPE-Rex substrate direction while preserving the existing verified release plan.

## 0. Non-negotiable context

Read these docs first:

1. `EPST_UNIFIED_SUBSTRATE_MASTER_PLAN_V2_SCOPE_REX_2026_05_01.md`
2. `MASTER_FUSION_OVERLAY_2026_04_30.md`
3. `MASTER_BUILD_PLAN_OVERLAY_2026_04_30.md`
4. `SOURCE_MAP_AND_GATE_REGISTER_2026_04_30.md`
5. `CODEX_VERIFIED_STATE_2026_04_25.md`
6. `WORKTREE_FUSION_PROTOCOL.md`
7. `SCOPE-Rex OSPC — Final Fusion Architecture`
8. `ODSC²: Verified Fusion of OSFT + PSOFT + coSO with SCOPE-Rex`

Then report:

- current git HEAD
- dirty files
- current lane
- whether the repo is safe to touch

Do not edit code until this is reported.

## 1. Architecture thesis

Epistemos is not a model wrapper. It is a verifiable cognition substrate.

The updated SCOPE-Rex spine is:

```text
TypedArtifact
  -> MutationEnvelope
  -> RunEventLog
  -> AgentEvent
  -> GraphEvent
  -> WitnessedState / ClaimGraph / FeatureFingerprint
  -> Halo | Graph | Theater | Audit | Research Mode
```

The model proposes. Rex governs.

## 2. Your first implementation target

Do not implement OSFT, PSOFT, coSO, private ANE APIs, activation steering, sparse texture KV, or full feature steering.

Implement only a non-invasive Rust semantic kernel skeleton and one vertical slice plan.

Create a branch or docs-only patch first. Ask before code if the repo has dirty state.

## 3. Required module plan

Propose these crates/modules without disrupting current build:

```text
rex/
  crates/
    rex-kernel/
      ledger.rs
      governor.rs
      claims.rs
      contracts.rs
      safety.rs
      scheduler.rs
    rex-memory/
      semantic.rs
      fingerprint.rs
      retrieval.rs
    rex-adapt/
      grpo.rs
      harness.rs
    rex-bridge/
      lib.rs
      rex.udl
    rex-bench/
      ledger_tests.rs
      governor_tests.rs
```

If this repo already has matching structures, map to existing modules instead of adding duplicates.

## 4. Required types

Propose or implement these types only if they do not conflict with existing structures:

```rust
pub enum Residency {
    TransientContext,
    RetrievalMemory,
    FeatureRule,
    HarnessRule,
    GrpoPrior,
    PsoftAdapter,
    OsftCore,
    CloudDistilled,
    Quarantine,
}

pub struct ResidencySignal {
    pub repeat_count: u32,
    pub verification_score: f32,
    pub runtime_gain: f32,
    pub forgetting_risk: f32,
    pub safety_risk: f32,
    pub privacy_sensitivity: f32,
    pub evidence_strength: f32,
}

pub struct SemanticDelta {
    pub event_id: String,
    pub parent_state: String,
    pub claim_ids: Vec<String>,
    pub feature_refs: Vec<FeatureRef>,
    pub tool_hashes: Vec<String>,
    pub proof_refs: Vec<String>,
    pub auth_ref: Option<String>,
}

pub struct WitnessedState {
    pub state_id: String,
    pub materialized_from: String,
    pub memory_root: String,
    pub claim_root: String,
    pub proof_root: String,
}

pub enum ClaimKind {
    Empirical,
    Mathematical,
    CodeInvariant,
    Causal,
    Speculative,
}
```

## 5. Residency Governor behavior

Implement a pure function first:

```rust
pub fn choose_residency(sig: &ResidencySignal) -> Residency {
    if sig.safety_risk > 0.7 { return Residency::Quarantine; }
    if sig.privacy_sensitivity > 0.9 { return Residency::Quarantine; }
    if sig.verification_score < 0.5 { return Residency::TransientContext; }
    if sig.repeat_count < 3 { return Residency::TransientContext; }
    if sig.repeat_count < 5 && sig.runtime_gain < 0.1 { return Residency::FeatureRule; }
    if sig.repeat_count < 10 { return Residency::GrpoPrior; }
    if sig.verification_score > 0.8 && sig.runtime_gain > 0.2 {
        if sig.forgetting_risk > 0.6 { return Residency::OsftCore; }
        return Residency::PsoftAdapter;
    }
    Residency::RetrievalMemory
}
```

Unit tests must cover safety quarantine, transient context, feature rule, GRPO prior, PSOFT adapter, OSFT core, and retrieval memory.

## 6. Verified Research Mode skeleton

Create a design or skeleton for:

```text
input -> retrieval -> draft -> claim extraction -> verification labels -> repaired answer -> ledger commit
```

UI labels:

```text
Verified
Plausible but unverified
Speculative
Blocked
```

No full UI required unless the user explicitly asks. The first pass can be data structures + tests + design doc.

## 7. Hard no's

Do not:

- add private Apple ANE APIs
- add Python to hot path
- add OSFT/PSOFT/coSO training to Core release path
- claim infinite memory
- claim zero forgetting
- claim local beats cloud on all tasks
- bypass existing Resource Runtime
- duplicate an existing graph/artifact system
- rewrite the app
- touch Liquid Wave or Quick Capture active work unless assigned

## 8. Verification

Every patch must prove:

- builds cleanly
- unit tests for new pure logic pass
- no hot-path subprocess
- no private API
- no change to Core/MAS entitlements
- every new concept maps to existing artifact/provenance spine or is explicitly isolated

## 9. Output format

Before coding, respond with:

```text
Phase:
Repo state:
Docs read:
Files I will touch:
Existing modules I will reuse:
New modules I propose:
Risks:
Verification plan:
```

Then stop for user approval.
