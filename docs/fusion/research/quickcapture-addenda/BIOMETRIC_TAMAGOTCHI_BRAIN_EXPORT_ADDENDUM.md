# BIOMETRIC + TAMAGOTCHI + BRAIN-EXPORT ADDENDUM (Waves 9–11)

**Status**: Final addendum capturing two design threads from the user's Gemini brainstorm sessions plus one new core capability: **biometric authentication as a substrate-wide gate**. Created 2026-04-29.
**Sequence**: do not begin until `PLAN.md` Phases 0.5–13 ✅, Wave 6 (Obscura/Eidos) ✅, Wave 7 (Live Files) ✅, Wave 8 (deliberation/auto-research) ✅. This is Waves 9–11, the productization layer.
**Purpose**: synthesize the user's biometric ask + the Tamagotchi agent surface + the Brain-Export feature into a coherent addendum, with **explicit critique** of what was already covered in prior plans, what's net-new, and what's hype vs. ground-truth from the Gemini chats.

This addendum is shorter and more critical than its predecessors. The earlier addendums had the responsibility of inventing the substrate. This one has the responsibility of *not bloating it* — only the strongest of the user's brainstorm survives the audit.

---

## 0. Audit pass — what's already covered, what's net-new, what's hype

The Gemini chats covered eight threads. Honest classification:

| Thread | Status | Notes |
|---|---|---|
| **Biometric authentication via Secure Enclave** | **NET-NEW** — Wave 9 | Not in prior canon. Genuine substrate addition. The user's main ask. |
| **Tamagotchi pixel-art agent UI** | **NET-NEW UX** — Wave 10 | Aesthetic and metaphorical layer. Not in prior canon. Strong concept; needs hardening for enterprise. |
| **Per-agent multi-vault + sub-agent dispatch** | **PARTIAL OVERLAP** | `vault_registry.rs` already supports multi-vault identity. New: per-agent capability scoping, A2A "phone" UX. |
| **Accessory system (LoRAs as equipment)** | **NET-NEW UX wrapper** — Wave 10 | The PEFT/LoRA/steering-vector tech is already in PLAN.md §6.6 (per-model engineering). New is the visual metaphor + S-LoRA hot-swap. |
| **Confidence meter + 70%-biometric-triggered re-learn** | **NET-NEW** — Wave 9 | Genuine mechanism. Real tech (logprobs / token entropy) backs it. Needs careful gate design (see §2.4). |
| **Cloud-as-Teacher / Local-as-Student distillation** | **PARTIAL OVERLAP** | `MoLoRAInferenceService.swift` exists; PLAN.md §6.5 covers per-model engineering. New: explicit "Lab" UX, privacy sluice, catastrophic-forgetting eval. |
| **Brain Export / business productization** | **NET-NEW BUSINESS LAYER** — Wave 11 | Productization decision, not just engineering. Has IP/legal implications outside scope of this doc; we capture the *technical* surface only. |
| **Two-pronged self-critique + constrained sampling** | **ALREADY IN CANON** | This is `PLAN.md` §17.2 G1–G4 + §3.3 llguidance grammar-bound dispatch. Gemini re-derived what we already designed. |

**Hype vs. ground-truth from Gemini** (be careful citing these):

| Gemini claim | Reality check |
|---|---|
| "DFlash speculative decoding (Feb 2026 breakthrough)" | Speculative decoding is real (Medusa, EAGLE-3, vLLM). "DFlash" specifically — I cannot verify. Use generic "speculative decoding" terminology. |
| "Kimi K2.5 Agent Swarm coordinates 100 agents" | Swarm orchestration is a research direction; specific scaling claims unverified. Don't quote. |
| "RTX 50-series break-even within 3 months" | Hardware ROI claim wildly variable per workload. Drop. |
| "Patent the recursive self-learning loop" | Patenting AI training methods is legally fraught and rapidly evolving. Trade-secret + copyright + compiled binary is a more defensible strategy than utility patents on agentic loops. |
| "Confidential Computing (TEE) lets cloud train without seeing data" | Apple's Private Cloud Compute is a partial precedent; general claim is stronger than the technology actually delivers in 2026. |
| "Karpathy AutoResearch (March 2026)" | Verified ✅. Already in `LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md` Wave 8. |
| "Compile-Verify-Mint pipeline" | Already in `PLAN.md` §17. Gemini's "deterministic compiled brain artifact" is the same concept. |
| "Logic Entity vs Cluster Provider" strategic split | This is sound strategic advice, not a technical claim. Worth absorbing. |

The signal from the Gemini chats survives the filter; the noise (timestamped product names, exact metric claims) doesn't. The canon below uses only the signal.

---

## 1. Wave 9 — Biometric Substrate

The user's primary ask: *"the fingerprint also can be used to reset a model or reset an agent when it gets stuck."* Plus implicit: biometric for tool authorization, system-prompt edits, capability changes, vault unlock.

This is genuinely a substrate-level addition. It extends `FINAL_SYNTHESIS.md` §5 (privacy hardening) and Layer 4 (Immune) of the Reflective Loop.

### 1.1 The principle

> **Biometric is not a per-action prompt. Biometric is a hardware-rooted authority delegation.**

A naive design taps Touch ID before every tool call. The user hates this within 5 minutes; the OS rate-limits it; the system becomes unusable. The right design is a **biometric-bonded ephemeral capability token** that persists for a bounded session and covers a bounded scope.

### 1.2 The biometric authority model

```
USER (presents Touch ID / Face ID / Apple Watch unlock)
   │
   ▼
SECURE ENCLAVE (verifies biometric; returns signed assertion)
   │
   ▼
RUST AGENT_CORE (mints a Session Authority Token):
   {
     scope: capabilities granted,
     ttl: bounded duration,
     bound_to: agent_id or live_file_id or vault_zone,
     signature: Ed25519 over scope+ttl+bound_to
   }
   │
   ▼
TOOL CALLS within token's scope and TTL execute without re-prompting
TOOL CALLS outside token's scope require fresh biometric
```

The Secure Enclave is hardware-rooted; the signed assertion cannot be forged by software; the session token is short-lived and scope-bounded. This gives the user *one tap* per session that authorizes a coherent unit of work, instead of *one tap* per tool call that destroys flow.

### 1.3 When biometric IS required

These categories *always* require fresh biometric — no token reuse:

1. **Editing an agent's system prompt or capability manifest.** Per-edit; no token cache.
2. **Editing a Live File's `LivePlan` capability scope.** (Beyond what the user-visible diff already requires per `FINAL_SYNTHESIS.md` §3.)
3. **Authorizing a tool call with `irreversible: true`** (per `arxiv:2603.20953` deterministic pre-action authorization). Send-money, delete-permanently, send-message-on-behalf-of-user, etc.
4. **Resetting an agent below the 70% confidence threshold** (see §2.4).
5. **Loading a Brain Artifact** (Wave 11) into a Tamagotchi.
6. **Accessing the master vault under encryption Tier 3** (passphrase-derived key per `PLAN.md` §10.1; biometric provides the unlock).
7. **Promoting a Live File to policy-grade Cognitive Weight** (per `FINAL_SYNTHESIS.md` §3 four-tier system).
8. **Crossing the cloud boundary when Cloud setting = Off** (override-once-with-biometric pattern).

### 1.4 When biometric is NOT required

Equally important — the system must not degrade into prompt-fatigue:

1. **Routine reads** (capture, search, vault queries within authorized zones).
2. **Tool calls within an active Session Authority Token's scope** that are *reversible* and *non-destructive*.
3. **Background NightBrain jobs** (auto-research overnight; uses a separate "background authority" granted at the previous foreground session and bound to the device + hostname).
4. **Live File scheduled triggers** when the LivePlan was already biometric-signed at compile time.
5. **The first-run capture** (don't make the user authenticate before they've even tried the product).

### 1.5 Implementation outline

The Swift side talks to `LocalAuthentication` framework; the Rust side receives signed assertions across UniFFI:

```swift
// Epistemos/Security/BiometricAuthority.swift
import LocalAuthentication

@MainActor
public final class BiometricAuthorityService {
    private let context = LAContext()

    public func mintSessionToken(
        scope: CapabilityScope,
        boundTo: AuthorityBinding,
        ttl: TimeInterval = 300    // 5 min default
    ) async throws -> SessionAuthorityToken {
        let reason = scope.userVisibleReason()
        let evaluated = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
        guard evaluated else { throw BioError.userDeclined }
        return try await AgentCore.shared.mintToken(scope: scope, boundTo: boundTo, ttl: ttl)
    }

    public func authorizeIrreversibleAction(
        action: IrreversibleAction
    ) async throws -> SignedAssertion {
        // Always fresh biometric — no token caching for this category
        let reason = "Authorize: \(action.description)"
        try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
        return try await AgentCore.shared.signAssertion(for: action)
    }
}
```

The Rust side wraps token minting in the existing capability firewall (Layer 4 of the Reflective Loop):

```rust
// agent_core/src/security/biometric.rs
pub struct SessionAuthorityToken {
    pub token_id: Ulid,
    pub scope: CapabilityScope,
    pub bound_to: AuthorityBinding,
    pub issued_at: SystemTime,
    pub expires_at: SystemTime,
    pub signature: [u8; 64],     // Ed25519 over the above
}

impl SessionAuthorityToken {
    pub fn covers(&self, action: &ProposedAction) -> AuthorityVerdict {
        if SystemTime::now() > self.expires_at { return AuthorityVerdict::Expired; }
        if !self.scope.includes(&action.required_capability) { return AuthorityVerdict::OutOfScope; }
        if !self.bound_to.matches(&action.binding) { return AuthorityVerdict::WrongBinding; }
        if action.is_irreversible() { return AuthorityVerdict::FreshBiometricRequired; }
        AuthorityVerdict::Authorized
    }
}
```

Layer 4 (Immune) of the Reflective Loop calls `token.covers(&action)` before executing every tool call. Verdicts:

- `Authorized` → execute.
- `Expired` / `OutOfScope` / `WrongBinding` → request fresh biometric (Swift surface).
- `FreshBiometricRequired` → request fresh biometric regardless of cached token.

This is exactly the deterministic pre-action authorization pattern from `arxiv:2603.20953`, with hardware-rooted authentication.

### 1.6 Anti-patterns to avoid

The Gemini chats had moments of biometric over-enthusiasm. Explicit don'ts:

- **Don't prompt biometric per token** (the model would generate; that's not the granularity). Per *action*, not per LLM call.
- **Don't claim "biometric-encrypted memory"**. The Secure Enclave protects keys; data is encrypted by those keys at rest. Be precise about what biometric does (gates key access) vs. what it doesn't (encrypt data on its own).
- **Don't require biometric on a Mac without Touch ID** (older Macs, accessibility users). Fall back to system password via `LAPolicy.deviceOwnerAuthentication` (which accepts password).
- **Don't lie about Apple Watch unlock cost**. Apple Watch unlock counts as biometric for `LAContext` but has its own UX latency. Document the actual flows.
- **Don't store the biometric assertion in the token**. Store the *fact of authentication* (a signed claim from Secure Enclave with the key reference); never raw biometric data. Apple's API never exposes raw biometric data to apps anyway.

### 1.7 Phase 21 — Biometric substrate

**Scope**:
- `Epistemos/Security/BiometricAuthorityService.swift` — Swift LocalAuthentication wrapper.
- `agent_core/src/security/biometric.rs` — Rust session-token + scope/binding model.
- UniFFI bindings: `mintSessionToken`, `authorizeIrreversibleAction`, `revokeAllTokens` (panic-button).
- Integration with Layer 4 of the Reflective Loop: every tool call passes through `token.covers(&action)`.
- 8 categories of "always fresh biometric" enforced.
- 5 categories of "no biometric needed" verified.
- Settings UI: tri-state per category (Always / Default / Never with strong override warning).

**Exit**:
- A 100-action eval suite where each category is exercised. Authorization correct in all 100 cases.
- Token TTL respected; expired tokens reject with `Expired`.
- Apple Watch unlock + system-password fallback both verified on test hardware.
- Audit log entry per biometric prompt with reason, outcome, action gated.

---

## 2. Wave 9 (cont.) — The Confidence Meter and the 70% Biometric-Triggered Re-learn

The user's specific ask: *"if the Tamagotchi has below 70% confidence, you can give it a fingerprint... and it does a re-learn."*

This is a real, useful pattern. But the naive version — "any time confidence drops, scan everything" — is wasteful and can entrench wrong answers. Here is the rigorous version.

### 2.1 What "confidence" means

LLMs do not have a single "confidence" number. We synthesize one from:

1. **Token entropy** — average per-token logprob across the response. Low logprob mean = uncertainty.
2. **Schema-validation pass rate** — IterGen recovery count (more recoveries = more uncertainty).
3. **Self-consistency** — sample N=5 generations, measure semantic agreement. High disagreement = uncertainty.
4. **Tool-call success rate over recent N calls** — high failure = drift.
5. **Citation coverage** — answer references vault drawers / web sources / none.
6. **Variant-ladder fall-through** — if Variant A failed and we're on Variant B, that's signal.

Composite confidence = weighted combination, bounded to [0, 1]. Stored in `ToolMeta.confidence` per `PLAN.md` §3.1.

### 2.2 The 70% threshold and what triggers below it

When composite confidence falls below 0.70 sustained over 3 consecutive tool calls, the agent enters a `Suspended-LowConfidence` state (extending the `LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md` state machine). The agent stops; the Tamagotchi UI shows a worried emote; the user is offered:

- **Tap fingerprint to re-learn**
- **Tap fingerprint to override and continue**
- **Open trace to see why confidence dropped**
- **Dismiss (agent stays suspended; user reviews later)**

Critical: the re-learn is **not** "scan everything and hope." It is a structured diagnostic + targeted refresh:

```rust
// agent_core/src/heal/relearn.rs
pub async fn biometric_relearn(
    agent_id: AgentId,
    auth: SessionAuthorityToken,    // fresh biometric required
    ctx: &AgentCtx,
) -> Result<RelearnReport, RelearnError> {
    auth.must_cover(&Capability::AgentReset)?;

    // 1. Diagnose what dropped — entropy, validation, tool failure, etc.
    let signals = ctx.confidence_signals_window(agent_id, last_n=20);
    let primary_cause = signals.dominant_failure_mode();

    // 2. Targeted refresh by cause — NOT generic re-scan.
    let report = match primary_cause {
        Cause::SchemaDrift => refresh_grammars(agent_id, ctx).await?,
        Cause::ContextStale => refresh_vault_index(agent_id, ctx).await?,
        Cause::ToolUnavailable => circuit_breaker_reset(agent_id, ctx).await?,
        Cause::ConceptCollision => recanonicalize_concepts(agent_id, ctx).await?,
        Cause::CitationGap => trigger_eidos_plus_research(agent_id, ctx).await?,
        Cause::ModelDrift => suggest_lora_retrain(agent_id, ctx).await?,
        Cause::Unknown => collect_diagnostic_bundle(agent_id, ctx).await?,
    };

    // 3. Bounded retry: ONE attempt at the previously-failing task.
    //    If still <70%, surface to user; don't loop indefinitely.
    Ok(report)
}
```

The key discipline: **diagnose before refresh.** Re-learn isn't omnidirectional; it's targeted at the specific signal that dropped. If the agent is failing because a tool is returning errors, scanning the vault doesn't help — the fix is a circuit-breaker reset on that tool. If the agent is failing because a concept canonicalization collided, the fix is to re-run canonicalization with the alias-table updated. The fingerprint doesn't *cause* the fix; it *authorizes* a structured, expensive operation that the user wouldn't want happening unbidden.

### 2.3 Anti-pattern: confidence-feedback runaway

A subtle trap. If "low confidence → re-learn → resume" is automated without bounds, an adversarial input could *force* expensive re-learn loops as a denial-of-service vector. Mitigations:

- Re-learn is **always biometric-gated**. The user must consent.
- Re-learn budget is **bounded per agent per day** (default 3). Beyond that, the agent goes to `Quarantined` and waits for explicit user review.
- Re-learn outcome is **logged with provenance**. The user can see exactly what was refreshed and roll back.

### 2.4 Phase 22 — Confidence meter + biometric re-learn

**Scope**:
- `agent_core/src/confidence/composite.rs` — composite-confidence computation from the 6 signals.
- `agent_core/src/heal/relearn.rs` — diagnose-first targeted-refresh logic.
- `Epistemos/Agent/ConfidenceMeterView.swift` — Tamagotchi-style visual meter (or a non-game progress arc for Tactical mode).
- Integration: composite confidence written to every `ToolMeta`; Layer-4 (Immune) reads it; sustained <70% triggers `Suspended-LowConfidence`.
- Fingerprint UX: clean, single-prompt approval flow with the four options listed in §2.2.

**Exit**:
- Synthetic-failure eval: inject 50 confidence-drop scenarios; relearn correctly diagnoses cause in ≥85% of cases.
- DoS-resistance: adversarial input that tries to force re-learn loops is bounded by per-day budget; no unbounded compute.
- UX: from "agent stops" → "user taps fingerprint" → "agent resumes" in <2 seconds (excluding the actual diagnostic work).

---

## 3. Wave 10 — The Tamagotchi Agent Surface

This is a UI/UX feature, not a substrate change. Done well, it makes Epistemos delightful and approachable. Done poorly, it makes Epistemos look like a toy that no enterprise will trust.

### 3.1 The duality: Pixel mode + Tactical mode

The Gemini chats correctly noted that pixel-art Tamagotchis would be a hard sell to defense or medical clients. The right answer is a UI mode toggle (per user, per device, persistent):

| Mode | Use case | Visual character |
|---|---|---|
| **Pixel mode** | Solo developers, founders, creators, casual personal use | Pixel art, animated walking sprites, emotes, color-per-agent |
| **Tactical mode** | Enterprise, compliance, medical, defense, legal | Minimalist info-dense panels, status pills, no animations beyond status changes |

Same agent, same capabilities, same backend — only the rendering layer differs. The substrate doesn't know which mode is active.

This is critical because Wave 11 (Brain Export) targets enterprise clients; the tactical mode is what they see; the pixel mode is what your weekend-hacker target market sees. One product, two appropriate aesthetics.

### 3.2 Per-agent identity model

Each agent has:

```rust
pub struct AgentIdentity {
    pub id: AgentId,
    pub name: String,                 // user-given
    pub purpose: String,              // user-given, ≤140 chars
    pub provider: AgentProvider,      // local model id | cloud provider | hybrid
    pub vaults: Vec<VaultId>,         // master + specialized
    pub capability_manifest: Manifest,
    pub avatar: AgentAvatar,          // sprite (pixel mode) or color-pill (tactical mode)
    pub state: AgentState,            // see §3.4
    pub created_at: SystemTime,
    pub last_biometric_auth: Option<SystemTime>,
}

pub enum AgentProvider {
    LocalModel(ModelId),                              // e.g., qwen2.5-7b
    CloudProvider(CloudProvider),                     // e.g., Claude, OpenAI
    Hybrid { primary: ModelId, escalation: CloudProvider },
}
```

The 4 reference identities (Claude orange, GPT mono, Hermes graph-themed, Kimi blue) are *seed templates*; the user can rename, recolor, repurpose. Identity is data, not code.

### 3.3 Sub-agent dispatch with capability inheritance

The Gemini chats imagined sub-agents inheriting from parents. The architecturally honest version: **sub-agents inherit a *strict subset* of the parent's capabilities, never more.**

```rust
pub fn spawn_subagent(
    parent: &AgentIdentity,
    auth: SessionAuthorityToken,
    purpose: String,
    capability_subset: Manifest,
) -> Result<AgentIdentity, SpawnError> {
    auth.must_cover(&Capability::SpawnSubagent)?;
    if !parent.capability_manifest.covers(&capability_subset) {
        return Err(SpawnError::CapabilityEscalation);
    }
    // sub-agent gets ≤ parent's capabilities, never more
    Ok(AgentIdentity::child_of(parent, purpose, capability_subset))
}
```

This prevents the failure mode where an over-eager loop spawns sub-agents with broader powers than the parent. Capabilities only narrow.

### 3.4 Agent state machine (extending Live File state machine)

```
[Idle] ────user invokes────► [Working]
   ▲                              │
   │                       ┌──────┼──────┐
   │                       │      │      │
   │                    success  block  drift
   │                       │      │      │
   │                       ▼      ▼      ▼
   └──── [Idle] ◄─── [Idle] [Paused] [Suspended-LowConfidence]
                                │              │
                              user           biometric
                              taps             tap
                                │              │
                                ▼              ▼
                            (Working)     (relearn → Working
                                          OR override → Working
                                          OR dismiss → Idle)
```

`Suspended-LowConfidence` is the §2.2 state. `Paused` is "blocked on user / network / permission" per the standard Live File pattern. `Idle` is the default; the agent walks around the homepage in Pixel mode or shows as "ready" in Tactical mode.

### 3.5 The "phone" and "computer-use" interactions

A2A communication via UI metaphor:

- **Tap-and-drag agent A onto agent B** (Pixel mode) / **right-click → "Connect to..."** (Tactical mode) → opens a structured channel between them. They exchange typed messages (closed schema), not free-form text. This is `MCP`-shaped (Model Context Protocol) — A queries B's exposed capabilities; B replies with structured results.
- **Computer-use icon** (eye emoji in Pixel mode; "Watch" button in Tactical mode) → agent A enters supervisor-loop mode, observing agent B's actions and able to inject corrective steering. Both agents must hold biometric session tokens covering the supervisor capability.

### 3.6 The accessory system

LoRAs and steering vectors are real, named tech. The Gemini "helmet/glasses/book/armor" mapping is a clean visual metaphor for them. Honest engineering reality:

| Visual | Tech | Trade-off |
|---|---|---|
| Helmet (speed) | Speculative-decoding draft model paired with the agent's main model | +VRAM for draft; +1.4–1.8× generation speed when paired correctly. Tokenizer must match. |
| Glasses (precision) | Activation-steering vector (ITI / RepE-style) | Strong on small targeted behaviors; degrades general capability if mis-tuned. Always evaluate post-application. |
| Book (style) | Style-transfer LoRA (low rank, 8–16) | Cheap to train and apply; effect is real but bounded. |
| Armor (safety) | Safety-tuned adapter trained on refusal patterns | Reduces certain failure modes; can also reduce helpfulness if over-applied. |
| Color (precision tier) | Quantization choice (4-bit / 8-bit / FP16) | Lower bits = lower VRAM, lower quality. Must benchmark per task. |

S-LoRA (Sheng et al.) is the right tech for runtime hot-swap — multiple LoRAs loaded simultaneously, attached/detached per inference. Apple MLX has growing support for this; verify before promising hot-swap UX.

The accessory UI lives in the per-agent inspector. **Apply / unapply requires biometric** (capability change). Each application logs to the agent's history.

### 3.7 Phase 23 — Tamagotchi agent surface

**Scope**:
- `Epistemos/Agent/PixelMode/` — sprite system, walking animation, emotes (24 base, customizable).
- `Epistemos/Agent/TacticalMode/` — info-dense panels, status pills.
- `Epistemos/Agent/ModeToggle.swift` — persistent per-user mode preference.
- `agent_core/src/agent_identity/` — AgentIdentity, sub-agent dispatch, capability inheritance.
- `agent_core/src/agent_state/` — full state machine.
- A2A "phone" channel: structured message-passing between agents via MCP-shaped API.
- Computer-use supervisor loop with biometric-gated cap.
- Accessory system: load/apply/unapply LoRAs and steering vectors with per-action biometric.

**Exit**:
- 50 Tamagotchi sprites, 24 emotes, smooth 60 FPS walking on M-series.
- Tactical mode is information-equivalent to Pixel mode (no Pixel-only features).
- Sub-agent capability subset enforced (10 attack tests).
- A2A channel passes structured messages, never free-form text.
- Accessory hot-swap latency < 200ms p95 (verifies S-LoRA actually works on target hardware).

---

## 4. Wave 10 (cont.) — The Cloud-as-Teacher Distillation Lab

The Gemini "Lab" UX is a strong wrapper around real distillation tech. The substrate already supports cloud-as-generator (per `OBSCURA_BROWSER_ADDENDUM.md` Wave 6 §21); this addendum extends it to *teacher-student distillation* on user-vault data.

### 4.1 The mechanism (honest)

Cloud teacher → Local student via overnight LoRA training:

1. **User selects a "messy vault"** (a folder of documents, captures, notes).
2. **Privacy sluice** (PII redaction by a small local classifier) runs first. Anything PII-flagged is either redacted, abstracted, or excluded — user choice with clear preview.
3. **Cloud teacher generates structured Q&A pairs** from the cleaned data. Output is JSON-schema-bound (per existing constrained-decoding stack).
4. **Local QLoRA training** consumes the Q&A pairs, training a LoRA adapter on the local Tamagotchi's base model. NightBrain-scheduled (idle + AC).
5. **Eval gate** — a frozen test set runs before and after training. Catastrophic forgetting blocks the LoRA from being applied. Specific drift in *targeted* abilities is the goal; *general* capability degradation is a fail.
6. **User reviews morning report** — what improved, what regressed, accept/reject.

### 4.2 Catastrophic forgetting — the eval that protects users

Without this gate, every "training session" risks making the agent worse at things it was previously good at. The eval gate runs:

- 30 baseline tasks the agent was previously verified on (per per-model bench from `PLAN.md` §6.5).
- Allowed regression: ≤5% on any single task; ≤2% average across all 30.
- Required improvement: ≥10% on the targeted ability the LoRA was trained for.
- If gate fails, LoRA is tombstoned with a diagnostic report. **Default action is reject, not accept.**

### 4.3 Phase 24 — Distillation lab

**Scope**:
- `Epistemos/Lab/` — Pixel-mode and Tactical-mode lab UIs (Professor/Student in Pixel; "Distillation Run" panel in Tactical).
- `agent_core/src/distillation/` — Q&A generation, LoRA training, eval gate.
- `agent_core/src/security/pii_sluice.rs` — local PII redaction with user-preview.
- Cloud-egress only happens after biometric authorization for the specific session.
- NightBrain integration; runs are bounded (max 1 per agent per night by default).

**Exit**:
- 10-vault eval: distillation produces measurable improvement on targeted ability ≥85% of runs.
- Catastrophic-forgetting gate: when injected with bad LoRA, gate rejects 100% of the time.
- PII sluice: standard PII benchmark (names, addresses, phone numbers, SSN-like patterns) ≥99% redaction recall.

---

## 5. Wave 11 — Brain Export (productization layer)

This is the user's "business mode" — exporting fine-tuned weights + scaffold + test report to enterprise clients. It is **a business model decision** with engineering and legal consequences. This addendum covers the technical surface only; the business viability and legal strategy are out of scope and the user's call.

### 5.1 The Brain Artifact

A signed, sealed bundle containing:

```
brain-artifact-<sha>.epistemos/
├── metadata.json              # signed manifest
├── weights/
│   ├── base_model.gguf       # license-permissive base (Llama, Qwen, Mistral)
│   └── adapters/
│       ├── domain.lora.safetensors
│       └── style.lora.safetensors
├── scaffold/
│   └── runtime.dylib         # compiled Rust runtime; obfuscated; license-keyed
├── schemas/
│   ├── tool_grammars/        # Live File compiled grammars for the domain
│   └── live_plans/           # signed LivePlans for canonical workflows
├── test_report/
│   ├── baseline_scores.json
│   ├── domain_eval.json
│   ├── safety_eval.json
│   └── catastrophic_forgetting.json
├── source_provenance.md      # what training data was used; from where; licensing
└── signature.bin             # Ed25519 over the entire bundle by the issuing Epistemos
```

Critical properties:

- **The base model must be license-permissive** for redistribution (Llama 3, Qwen, Mistral — all permit commercial). The user cannot ship a proprietary frontier model in a Brain Artifact.
- **The scaffold is compiled, not source.** Obfuscated Rust; license-keyed; bound to a hardware/customer fingerprint provided at issue time.
- **Test report is part of the contract.** The customer sees what the brain was verified on. If they run the brain on a workload outside the test scope, the report's claims don't apply.
- **Signature chain.** The bundle is Ed25519-signed by the issuing instance of Epistemos. Tampering invalidates.

### 5.2 IP strategy — honest version

The Gemini chats listed five legal pillars (patent / copyright / trade secret / trademark / contracts). For a solo developer in 2026, the realistic priorities:

| Mechanism | Priority | Rationale |
|---|---|---|
| **Trade secret** (compiled scaffold; never source) | **High** | Strongest practical moat. No filing fees. |
| **Copyright** (your authored source) | **High** | Automatic in most jurisdictions; register the core engine for stronger remedies. |
| **Trademark** (Epistemos name + logo) | **Medium** | Affordable; protects brand. |
| **Contracts** (EULA / MSA for export customers) | **High** | The actual enforcement mechanism. License compiled artifact, not source. |
| **Patents on agentic loops / recursive logic** | **Low / risky** | AI-method patentability is unstable in 2026; expensive to file; likely contested; defensive value uncertain. |

The Gemini suggestion to patent every loop and schema is over-stated. **Compiled binaries + contracts + trade secret** is the realistic moat for a solo developer. Patents are a possibility once the company has the budget and a clear novel claim that survives prior-art scrutiny.

### 5.3 The "stay in the app" lock-in

The Gemini chats correctly identified that the user's strategic interest is keeping enterprise clients *inside Epistemos as the C2 layer*, not handing them autonomous infrastructure. Concretely:

- The Brain Artifact runs on the customer's hardware, but **commands flow through Epistemos** (Studio Edition or Cluster Hub Edition).
- The customer can update the Brain Artifact's training data only by feeding it back through Epistemos's distillation lab.
- Renewal of the artifact license is gated on continued Epistemos subscription.
- Disconnecting from Epistemos puts the artifact into a "cached" mode where it works on existing tasks but cannot be retrained or extended.

This is a **pragmatic lock-in**, not a hostile one. The customer always retains the right to export their data, never their proprietary training. Fair on both sides.

### 5.4 Phase 25 — Brain Export

**Scope**:
- `agent_core/src/brain_export/` — bundle construction, signing, manifest schema.
- License keying with hardware/customer fingerprint binding.
- Compilation pipeline for the scaffold (Rust → obfuscated dylib).
- EULA / MSA template (legal review required before any actual customer).
- Test report generation hooks into the existing eval harness.
- Studio Edition vs. Cluster Hub Edition feature differentiation.

**Exit**:
- A reference Brain Artifact for a synthetic legal-research domain is produced end-to-end.
- Tamper detection: modifying the artifact post-signing causes signature verification to fail.
- License binding: the artifact runs only on hardware matching the issued fingerprint.

This phase is **gated on legal review** of the EULA/MSA. Engineering can build it; the user must consult a lawyer before any first customer.

---

## 6. Strategic positioning (YC pitch / sovereign-AI moat)

The user has a YC-application angle. Captured here for completeness, separate from technical architecture.

### 6.1 What's true

- Local-first sovereign AI for compliance-heavy industries (legal, medical, defense, finance) is a real market gap.
- Cloud-LLM data residency and audit failures are genuine adoption blockers in those verticals.
- A founder profile combining military background, AI red-teaming experience, and Apple-native engineering is a strong "founder-market fit" signal.
- The substrate-as-product framing (Epistemos as the OS, Brain Artifacts as deployments) is a clean product story.

### 6.2 What's harder than the chat suggested

- "Air-gapped enterprise customers" have long sales cycles (6–18 months). YC timeline doesn't favor them as your first revenue.
- Solo founders pitching defense/intelligence customers need security clearances or partners. Verify pathways before pitching.
- "Verified intelligence" is a marketing term; what you actually sell is *compiled artifacts with test reports*. Pitch the concrete thing.
- The Tamagotchi UI is great for a viral demo and bad for a defense-procurement pitch. Have the Tactical mode ready before the YC interview.

### 6.3 The honest pitch

> **Epistemos is a sovereign AI workspace and brain-deployment platform. Solo developers and small teams use it to build, fine-tune, and deploy local-first AI agents on their own hardware, with hardware-rooted biometric authorization and a verifiable compile-pipeline. Compliance-bound enterprises (legal, medical, defense, finance) license compiled Brain Artifacts that run inside their own perimeter while remaining controlled and updatable through the Epistemos studio.**

That's the version that survives an investor audit. The Tamagotchi metaphor is the user-acquisition surface; the Brain Artifact is the enterprise revenue surface; the substrate is the moat that ties them together.

---

## 7. Anti-hype critique — what NOT to do

The Gemini chats had moments of architectural over-reach. Explicit don'ts:

1. **Don't claim "0% hallucination"** — claim "0% syntactic violation under grammar-bound dispatch." Semantic hallucination is reduced but not eliminated.
2. **Don't claim "the model writes its own code overnight."** Claim "the auto-research loop tunes prompts, few-shots, and LoRA adapters; the Rust core itself is never auto-modified."
3. **Don't claim "agent swarms with 100 sub-agents."** Claim "bounded sub-agent dispatch under capability inheritance." Scaling claims need empirical backing.
4. **Don't promise "verifiably shippable" without naming the verification.** The verification is the Compile-Verify-Mint pipeline + per-agent test reports + catastrophic-forgetting gate. Be specific.
5. **Don't promise patent protection on the recursive loop.** Promise compiled-binary protection. Patents are aspirational.
6. **Don't promise enterprise customers in your YC video.** Show real users solving real problems. Enterprise comes after Series A.
7. **Don't conflate "biometric" with "encrypted."** Biometric gates key access. Encryption is what protects data. They cooperate; they're not the same.
8. **Don't promise "complete privacy" in the cloud-as-teacher path.** Promise "PII-redacted egress with user preview" — the honest version.

Engineering integrity here is a moat. Over-promising erodes the trust the substrate is designed to build.

---

## 8. Integration with existing waves

| Existing wave | This addendum's interaction |
|---|---|
| `PLAN.md` §3 Tool registry | Wave 9 adds biometric-bonded session tokens to ToolCtx; Layer 4 (Immune) consults them. |
| `PLAN.md` §17 Compile-Verify-Mint | Brain Export (Wave 11) ships compiled artifacts gated by Compile-Verify-Mint outcomes. |
| `OBSCURA_BROWSER_ADDENDUM.md` Wave 6 | Cloud-as-teacher (Wave 10) reuses the cloud-as-generator pipeline; just adds the distillation step. |
| `LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md` Wave 7 | Live File state machine extended with `Suspended-LowConfidence`; LivePlan signing pairs with biometric session tokens. |
| `LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md` Wave 8 | Auto-research feeds confidence-meter signals; agent re-learn diagnostics feed auto-research baselines. |
| `FINAL_SYNTHESIS.md` §5 privacy stack | Wave 9 biometric is the hardware-rooted authority on top of the existing capability tokens. |

This addendum doesn't conflict with prior waves. It fills the productization layer they implied but didn't specify.

---

## 9. Phase work — Waves 9–11

| Phase | Wave | Scope |
|---|---|---|
| **21** | 9 | Biometric substrate (Secure Enclave + session tokens + capability scope/binding) |
| **22** | 9 | Confidence meter + biometric-triggered re-learn (diagnose-first, bounded) |
| **23** | 10 | Tamagotchi + Tactical agent surface (Pixel mode, Tactical mode, A2A "phone", computer-use supervisor, accessories) |
| **24** | 10 | Cloud-as-teacher distillation lab (PII sluice + Q&A gen + local QLoRA + catastrophic-forgetting gate) |
| **25** | 11 | Brain Export (artifact bundle + signing + license binding + EULA/MSA — gated on legal review) |

Each phase follows the existing builder workflow: TodoWrite, mandatory web research, verification gate before commit, never batch.

---

## 10. Verification gates

| Phase | Gate | Pass criterion |
|---|---|---|
| 21 | `cargo run --bin biometric_eval --features wave-9` | 100/100 authorization decisions correct across 8 categories |
| 22 | `cargo run --bin confidence_relearn_eval` | Diagnose+targeted-refresh correct in ≥85% of 50 synthetic-failure scenarios |
| 23 | `swift test --filter TamagotchiSurfaceTests` + sub-agent capability eval | 60 FPS Pixel; 10/10 sub-agent capability-escalation attempts blocked |
| 24 | `cargo run --bin distillation_lab_eval -- --vaults 10` | ≥85% targeted improvement; 100% catastrophic-forgetting rejection |
| 25 | `cargo run --bin brain_artifact_eval` | tamper-detection 100%; license-binding 100%; reference artifact constructs end-to-end |

Phase 25 additionally gated by **legal review** of EULA/MSA — this is a non-engineering blocker.

---

## 11. Risks and open questions

1. **Touch ID rate-limit cliff.** Apple's `LAContext` rate-limits failures; aggressive biometric prompts can trigger lockouts. Test on real hardware; tune prompts.
2. **Apple Watch as biometric.** Counts as biometric for `LAContext` but UX is different. Document expectations.
3. **Older Macs without Secure Enclave (pre-T2).** Wave 9 must gracefully degrade to system-password; document the security trade-off.
4. **Tamagotchi UI as enterprise-blocker.** Tactical mode must be feature-equivalent; verify with mock enterprise demo before promoting Wave 10.
5. **S-LoRA hot-swap latency on real hardware.** MLX support is evolving; benchmark before promising the accessory-system UX.
6. **Cloud-as-teacher PII risk.** Even with sluice, edge cases leak. The user-preview step must be unmissable; default-redact aggressive.
7. **Catastrophic-forgetting eval coverage.** 30 baseline tasks may miss subtle regressions. Expand eval as new domains are added.
8. **Brain Export legal exposure.** Distributing weights derived from licensed base models requires careful licensing audit per base model. Llama, Qwen, Mistral all have differing terms; verify per artifact.
9. **License-key binding to hardware fingerprint.** The fingerprint (CPU id, machine UUID) is stable but legitimate hardware changes (replacement Mac) require a re-issuance process. Build it into the lifecycle.
10. **YC application timing.** If targeting a specific batch deadline, sequencing of demoable features matters. The user should pick which wave's UX is the demo and ship that first as a MVP-grade slice — not all of Waves 9–11.

---

## 12. References

### Biometric / Secure Enclave
- [Apple `LocalAuthentication` framework](https://developer.apple.com/documentation/localauthentication)
- [Apple Secure Enclave Overview](https://support.apple.com/guide/security/secure-enclave-sec59b0b31ff/web)
- [`LAPolicy.deviceOwnerAuthenticationWithBiometrics`](https://developer.apple.com/documentation/localauthentication/lapolicy/deviceownerauthenticationwithbiometrics)

### Deterministic pre-action authorization
- [arxiv:2603.20953 — *Before the Tool Call: Deterministic Pre-Action Authorization*](https://arxiv.org/html/2603.20953v1)

### LoRA / S-LoRA / accessory tech
- [LoRA: Low-Rank Adaptation of Large Language Models (arxiv:2106.09685)](https://arxiv.org/abs/2106.09685)
- [S-LoRA: Serving Thousands of Concurrent LoRA Adapters (arxiv:2311.03285)](https://arxiv.org/abs/2311.03285)
- [Activation Steering / RepE — Representation Engineering (arxiv:2310.01405)](https://arxiv.org/abs/2310.01405)

### Distillation
- [Knowledge Distillation: A Survey (arxiv:2006.05525)](https://arxiv.org/abs/2006.05525)
- [QLoRA: Efficient Finetuning of Quantized LLMs (arxiv:2305.14314)](https://arxiv.org/abs/2305.14314)

### Karpathy AutoResearch (already in canon Wave 8)
- [karpathy/autoresearch](https://github.com/karpathy/autoresearch)

### Strategic / market
- [Y Combinator Request for Startups](https://www.ycombinator.com/rfs)

---

## 13. Summary — what changes in the user's product

If Waves 9–11 ship:

- **Touch your finger to the trackpad to authorize a tool call, edit a system prompt, reset a confused agent, or commit a Live File policy change.** One tap per session per scope. Hardware-rooted; tamper-evident; logged with provenance.
- **A confidence meter on every agent.** When it drops below 70% sustained, the agent stops and asks for a fingerprint to re-learn. The re-learn is *targeted* (diagnose-first), bounded (3 per day default), and reversible.
- **A pixel-art Tamagotchi UI by default; a Tactical info-dense UI for enterprise.** Same agents; same capabilities; two appropriate aesthetics.
- **Per-agent multi-vaults, sub-agent capability inheritance (only narrowing), A2A "phone" channel for structured exchange, computer-use supervisor mode for one-agent-watching-another.**
- **An accessory system** where applying a LoRA looks like equipping a helmet (speed), glasses (precision), book (style), or armor (safety). Each application is biometric-gated and reversible.
- **A distillation lab** where a "Professor" (cloud) teaches a "Student" (local) on the user's vault data, with PII sluice + catastrophic-forgetting gate.
- **A Brain Export feature** that bundles fine-tuned weights + compiled scaffold + test reports into a signed artifact licensed to enterprise clients running on their own hardware, with the customer remaining controlled and updatable through Epistemos as their C2 layer.

The substrate doesn't change. The product, finally, becomes one. The biometric layer is the trust spine. The Tamagotchi UI is the user-love surface. The Brain Export is the business surface. All three sit on the unified substrate that the prior addendums already built.

That is Epistemos's complete shape.

---

*End of Wave 9–11 Addendum. This document is the final productization layer. Subsequent revisions are explicit (next version → BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM_v2.md).*
