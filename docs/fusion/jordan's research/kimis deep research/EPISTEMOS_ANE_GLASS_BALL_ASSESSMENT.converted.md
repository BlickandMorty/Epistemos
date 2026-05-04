# EPISTEMOS ANE CONTROL ROOM — GLASS BALL ASSESSMENT
## Technical Feasibility of Real-Time Neural Engine Cognition Observatory

**Date**: 2026-05-02 | **Assessment Type**: Buildable Feature Analysis
**Target Tier**: Research (Developer ID + Notarization) | **Est. Build Time**: 4-6 weeks

---

# EXECUTIVE SUMMARY

## The Answer: Yes — With a Critical Reframe

The "ANE Control Room" you envision is **absolutely buildable**, but the "glass ball" is not a window into ANE silicon transistors. It is a **Model Cognition Observatory** — a real-time visualization of what the AI model is *thinking*, decoded through Sparse Autoencoders (SAEs) that make the invisible visible.

**What the Glass Ball Actually Shows:**
- Not: "ANE Core 3 is at 84% utilization, 2.3W power draw"
- But: "The model has activated 'legal reasoning' (0.82), 'uncertainty' (0.34), 'sycophantic praise' (0.12) — and is suppressing 'deceptive language' (-0.18)"

This is **infinitely more useful** than raw hardware telemetry. It is also the **cutting edge of AI interpretability** — what Anthropic, OpenAI, and Google DeepMind are building right now.

---

# PART I: WHAT IS ACTUALLY POSSIBLE

## 1.1 ANE Hardware Telemetry (Possible, Limited Value)

### What Exists Today

| Metric | How to Access | What's Needed | Value |
|--------|--------------|---------------|-------|
| **ANE power draw** | `IOKit` private API (`IOReport`, `IOSMC`) | `disable-library-validation` entitlement | Low — just watts |
| **ANE frequency** | Same IOKit channels | SMC read access | Low — just MHz |
| **ANE utilization %** | Derived from power/frequency correlation | Calibration per chip | Medium — busy/idle |
| **Per-core ANE state** | **NOT exposed by Apple** | Would need kernel driver | **Impossible** |
| **ANE instruction trace** | **NOT exposed by Apple** | Would need silicon-level debug | **Impossible** |
| **ANE SRAM bank state** | **NOT exposed by Apple** | Would need JTAG equivalent | **Impossible** |

**Tools that do this**: `macmon` (Rust, no-root), `asitop` (Python, needs sudo), `FluidTop` — all use the same private IOKit/SMC channels to read ANE power/frequency.

**Assessment**: You CAN build an ANE hardware dashboard showing power, frequency, and derived utilization. But this is **system monitor territory**, not "glass ball into intelligence." It's like showing CPU temperature instead of what the software is doing.

---

## 1.2 The Real Glass Ball: SAE-Based Model Cognition Observatory

### What Sparse Autoencoders Actually Do

SAEs are the **key technology** that makes the glass ball real. They were developed by Anthropic (Claude), OpenAI (GPT-4), and Google DeepMind (Gemma) in 2024-2025 specifically to solve this problem: **making neural networks interpretable.**

**How it works:**

```
[Model Layer N Activation]  (12,288 dimensional dense vector — opaque)
            ↓
    [SAE Encoder Matrix]  (12,288 × 49,512)
            ↓
    [Sparse Feature Vector]  (49,512 dimensions, ~50-300 non-zero)
            ↓
    [Interpretable Concepts]  ("Golden Gate Bridge", "legal reasoning",
                                "uncertainty", "deceptive language",
                                "sycophantic praise", "humans have flaws")
```

**Real discoveries from Anthropic's research (2024):**
- A feature that activates on **"Golden Gate Bridge"** — when clamped to max, Claude claimed to *be* the bridge
- A feature for **"sycophantic praise"** — activates on phrases like "a generous and gracious man"
- A feature for **"humans have flaws"** — activates on "My Dad wasn't perfect (are any of us?)"
- A feature for **"deceptive language"** — can be suppressed to make the model more honest
- A feature for **"backdoor / unsafe code"** — can be amplified to detect malicious code

**The glass ball is this:** A real-time sphere where each "ray" or "facet" represents an active SAE feature. The brightness/color shows activation strength. The layout clusters related concepts. You can **see the model's thoughts** as they form.

---

### The Glass Ball UI Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    MODEL COGNITION OBSERVATORY                  │
│                                                                 │
│     ┌─────────────────┐         ┌──────────────────┐         │
│     │                 │         │  ACTIVE FEATURES   │         │
│     │    ☆ GLASS      │         │  ───────────────   │         │
│     │      BALL       │         │  • legal reasoning │ 0.82    │
│     │                 │         │  • code syntax     │ 0.76    │
│     │   (central      │         │  • uncertainty     │ 0.34    │
│     │    sphere with  │         │  • memory recall   │ 0.28    │
│     │    pulsing      │         │  • sycophancy      │ 0.12    │
│     │    features     │         │  • deception      │ -0.18   │
│     │    orbiting)    │         │                    │         │
│     │                 │         │  SUPPRESSED        │         │
│     └─────────────────┘         │  • harmful content │ -0.45   │
│              │                  └──────────────────┘         │
│              ↓                                                  │
│     ┌─────────────────┐         ┌──────────────────┐         │
│     │  ATTENTION MAP  │         │  KV CACHE STATE  │         │
│     │  (what model is │         │  (working memory) │         │
│     │   looking at)   │         │  ───────────────  │         │
│     │                 │         │  [████░░░░░░░░░░] │ 25%     │
│     │  [heatmap of    │         │  [████████░░░░░░] │ 50%     │
│     │   token          │         │  [██████░░░░░░░░] │ 38%     │
│     │   importance]    │         │  [██████████░░░░] │ 63%     │
│     └─────────────────┘         └──────────────────┘         │
│                                                                 │
│  [ANE Power: 2.3W] [GPU: 1.1W] [Latency: 23ms] [Tokens/sec: 42]│
└─────────────────────────────────────────────────────────────────┘
```

---

## 1.3 How to Build It — Technical Path

### Phase 1: Activation Capture Pipeline (Week 1-2)

**For MLX-based models (Qwen, DeepSeek local):**

```swift
// Swift side: Request hidden states from MLX inference
let result = await mlxModel.generate(
    tokens: inputTokens,
    maxTokens: 1024,
    temperature: 0.7,
    // Critical: capture intermediate activations
    captureLayer: 12,  // Which transformer layer to inspect
    captureEveryN: 4   // Capture every 4th token for performance
)

// Returns: [ActivationSnapshot] — one per captured token
struct ActivationSnapshot {
    let token: String
    let tokenIndex: Int
    let layer: Int
    let activationVector: [Float]  // 12,288 or 4,096 dimensions
    let timestamp: UInt64
}
```

**For CoreML models (Apple Intelligence):**

Core ML does NOT natively expose intermediate activations. You need:
1. **Custom `MLCustomLayer`** that intercepts and copies activations during forward pass
2. Or: **Model splitting** — break the model at layer N, run first N layers, capture output, run rest

```swift
// Custom layer that copies activations to shared buffer
@objc(SpyLayer) class SpyLayer: NSObject, MLCustomLayer {
    func evaluate(inputs: [MLMultiArray], outputs: [MLMultiArray]) throws {
        // Copy input activation to shared observation buffer
        ActivationBuffer.shared.append(inputs[0])
        // Pass through unchanged
        outputs[0] = inputs[0]
    }
}
```

**Performance note**: Capturing every layer for every token is too slow (2-5× slowdown). Capture:
- One designated "observation layer" (typically middle layer ~N/2)
- Every Nth token during generation (sampling)
- Only when user has Glass Ball panel visible

---

### Phase 2: SAE Encoder — The Translation Layer (Week 2-3)

**Option A: Pre-trained SAE (Fastest to build)**

Use existing open-source SAEs:
- **Gemma Scope** (Google DeepMind) — SAEs for Gemma 2 2B/9B/27B
- **LLaMA Scope** — SAEs for LLaMA 3.1 8B
- **SAELens** (open source) — ecosystem of trained SAEs

```python
# SAE forward pass (PyTorch → convert to Core ML or MLX)
# SAE is just: encoded = TopK(W_enc @ (activation - b_pre) + b_enc)
#             decoded = W_dec @ encoded + b_pre

# Convert to Metal Performance Shaders for real-time:
# MPSMatrixMultiplication for encoder/decoder matrices
```

**Option B: Train Your Own SAE (Best for your specific model)**

```rust
// Rust SAE training (offline, not real-time)
// 1. Collect 10M-100M activations from your target model
// 2. Train SAE with TopK sparsity (k=50-300 active features)
// 3. Export encoder/decoder matrices as Metal buffers

// Training data: activation vectors from layer 12 of your Qwen model
// Running on 1M tokens of diverse text (code, chat, reasoning, memory)
```

**Key insight**: You only need the **encoder** for the Glass Ball. The decoder is for reconstruction/steering. The encoder converts opaque activations → sparse interpretable features in one matrix multiplication.

---

### Phase 3: Real-Time Feature Interpretation (Week 3-4)

**The challenge**: The SAE gives you 49,512 numbers. Most are zero. ~50-300 are non-zero. But what do they MEAN?

**Current approach (Anthropic/Neuronpedia):**
1. For each feature, find the 10 inputs that maximally activate it
2. Use a frontier LLM (Claude/GPT-4) to auto-generate a label: "This feature activates on legal reasoning, contracts, and liability concepts"
3. Human review and curation
4. Store: feature_id → {label, description, example_activations}

**Your approach (automated, in-app):**

```rust
// Pre-computed feature dictionary (generated once, shipped with app)
struct FeatureMetadata {
    feature_id: u32,
    label: String,           // e.g., "legal_reasoning"
    description: String,     // e.g., "Activates on legal terminology, contracts, liability"
    category: FeatureCategory, // Code | Reasoning | Memory | Emotion | Safety | Entity
    top_tokens: Vec<String>, // "contract", "liability", "clause", "agreement"
    example_phrases: Vec<String>,
    safety_relevant: bool,   // Is this a safety/bias feature?
}

// At runtime: map active feature IDs to metadata
fn interpret_activations(sparse_features: &[(u32, f32)]) -> Vec<ActiveConcept> {
    sparse_features.iter()
        .filter(|(_, strength)| *strength > 0.1)  // Threshold
        .map(|(id, strength)| {
            let meta = FEATURE_DB.get(id)?;
            ActiveConcept {
                label: meta.label.clone(),
                strength: *strength,
                category: meta.category,
                safety_relevant: meta.safety_relevant,
            }
        })
        .collect()
}
```

**The Glass Ball visualization receives**: `Vec<ActiveConcept>` every ~100ms during generation.

---

### Phase 4: The Glass Ball UI (Week 4-5)

**Metal-based real-time visualization:**

```metal
// Vertex shader: feature particles orbiting central sphere
vertex GlassBallVertexOut glass_ball_vertex(
    constant float3* feature_positions [[buffer(0)]],
    constant float* feature_strengths [[buffer(1)]],
    constant float4* feature_colors [[buffer(2)]],
    uint gid [[vertex_id]],
    float time [[buffer(3)]]
) {
    // Features orbit the center sphere with speed proportional to strength
    float angle = time * (0.5 + feature_strengths[gid]);
    float radius = 0.3 + feature_strengths[gid] * 0.5;
    
    float3 pos = feature_positions[gid];
    pos.x = cos(angle) * radius;
    pos.z = sin(angle) * radius;
    pos.y += sin(time * 2.0 + gid) * 0.1 * feature_strengths[gid];
    
    // Size proportional to activation strength
    float size = 0.02 + feature_strengths[gid] * 0.08;
    
    return GlassBallVertexOut {
        position: float4(pos, 1.0),
        color: feature_colors[gid],
        size: size,
        strength: feature_strengths[gid]
    };
}

// Fragment shader: glow based on strength
fragment float4 glass_ball_fragment(
    GlassBallVertexOut in [[stage_in]],
    float2 point_coord [[point_coord]]
) {
    float dist = length(point_coord - 0.5);
    float alpha = smoothstep(0.5, 0.0, dist) * in.strength;
    return float4(in.color.rgb, alpha);
}
```

**Swift UI integration:**

```swift
struct GlassBallView: View {
    @ObservedObject var cognitionState: CognitionState
    
    var body: some View {
        ZStack {
            // Central sphere — "the model's mind"
            MetalGlassBallRepresentable(
                activeFeatures: cognitionState.activeFeatures,
                attentionMap: cognitionState.attentionMap,
                generationPhase: cognitionState.phase
            )
            .frame(width: 400, height: 400)
            
            // Overlay: feature labels on hover
            FeatureLabelOverlay(features: cognitionState.activeFeatures)
            
            // Bottom bar: ANE/GPU telemetry
            HardwareTelemetryBar(
                anePower: cognitionState.anePowerWatts,
                gpuPower: cognitionState.gpuPowerWatts,
                tokensPerSecond: cognitionState.tokensPerSecond
            )
        }
    }
}
```

---

### Phase 5: Activation Steering — The Control Aspect (Week 5-6)

The "Control Room" isn't just observation. It's **intervention**.

**Activation steering math** (from Anthropic's research):

```
h̃ = h + α · v_steer

Where:
  h = original activation at layer N
  v_steer = decoder vector for the feature you want to amplify/suppress
  α = steering strength (positive = amplify, negative = suppress)
```

**In your app, this becomes user-adjustable sliders:**

```swift
struct SteeringPanel: View {
    @Binding var steerConfig: SteeringConfiguration
    
    var body: some View {
        VStack {
            Text("Cognitive Steering")
                .font(.headline)
            
            // Safety features (always-on defaults)
            SteeringSlider(
                feature: "deceptive_language",
                label: "Honesty",
                range: -1.0...1.0,
                value: $steerConfig.honestyStrength,
                defaultValue: 0.3  // Slight boost to honesty by default
            )
            
            SteeringSlider(
                feature: "unsafe_code",
                label: "Code Safety",
                range: -1.0...1.0,
                value: $steerConfig.codeSafetyStrength,
                defaultValue: 0.5
            )
            
            // Creativity/Style (user-adjustable)
            SteeringSlider(
                feature: "creative_writing",
                label: "Creativity",
                range: -1.0...1.0,
                value: $steerConfig.creativityStrength,
                defaultValue: 0.0
            )
            
            SteeringSlider(
                feature: "technical_depth",
                label: "Technical Depth",
                range: -1.0...1.0,
                value: $steerConfig.technicalDepthStrength,
                defaultValue: 0.0
            )
            
            // Danger zone (gated, requires explicit enable)
            if steerConfig.advancedMode {
                SteeringSlider(
                    feature: "sycophantic_praise",
                    label: "Sycophancy Suppression",
                    range: -1.0...1.0,
                    value: $steerConfig.sycophancySuppression,
                    defaultValue: 0.2
                )
            }
        }
    }
}
```

**Behind the scenes:**

```rust
// During model forward pass, intercept layer N activations
fn generate_with_steering(
    tokens: &[u32],
    max_new_tokens: usize,
    steering_config: &SteeringConfig,
) -> Vec<u32> {
    let mut generated = tokens.to_vec();
    
    for _ in 0..max_new_tokens {
        // Forward pass to observation layer
        let mut hidden_states = model.forward_to_layer(&generated, OBSERVATION_LAYER);
        
        // Apply steering vectors
        for steering in &steering_config.active_vectors {
            let feature_id = steering.feature_id;
            let strength = steering.strength;
            let decoder_vector = &sae.decoder[feature_id];  // 12,288 dims
            
            // h̃ = h + α · v_steer
            for (i, h) in hidden_states.iter_mut().enumerate() {
                *h += strength * decoder_vector[i];
            }
        }
        
        // Continue forward pass from observation layer to output
        let logits = model.forward_from_layer(hidden_states, OBSERVATION_LAYER);
        let next_token = sample(logits);
        generated.push(next_token);
    }
    
    generated
}
```

---

# PART II: WHAT IS NOT POSSIBLE (Honest Boundaries)

## 2.1 ANE Silicon-Level Introspection

| Dream | Reality |
|-------|---------|
| "See which ANE cores are active" | ANE exposes no per-core state. It's a black box accelerator. |
| "See the MIL instruction stream" | MIL is compiled to E5 binary; no disassembly or trace available. |
| "See SRAM contents during computation" | 32MB SRAM is internal to ANE; no peek interface. |
| "See weight values in ANE memory" | ANE uses compressed/quantized weights; no readback path. |
| "Halt ANE mid-inference and inspect" | No debug interrupt or breakpoint mechanism. |

**Why Apple does this**: The ANE is a trade secret. Its microarchitecture (dataflow, scheduling, compression formats) is proprietary. Exposing it would reveal competitive IP.

**Workaround**: The model's activations (what it computes) are observable. The ANE's implementation (how it computes) is not. The Glass Ball observes the former.

## 2.2 Real-Time Training on ANE

| Claim | Reality |
|-------|---------|
| "Train models directly on ANE" | ANEgpt (March 2026) showed NaN divergence after step 1. Not stable. |
| "Backpropagation on ANE" | ANE only supports inference. No backward pass hardware. |
| "Fine-tune while user chats" | Would need GPU/CPU for training, not ANE. |

**Reality**: ANE is inference-only. Training/fine-tuning happens on GPU or CPU. The ANE runs the frozen forward pass.

## 2.3 Cross-Model Feature Universality

| Hope | Reality |
|------|---------|
| "One SAE works for all models" | SAEs are model-specific. A Qwen SAE doesn't work on LLaMA. |
| "Features transfer between models" | Research shows ~30-60% overlap. Not universal. |

**Reality**: You need a separate SAE per model architecture. But features WITHIN a model family (e.g., all Qwen variants) may transfer.

---

# PART III: THE INTEGRATED ANE DASHBOARD

## What You CAN Build Today

Combine both layers into one unified control room:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    EPISTEMOS COGNITION OBSERVATORY                          │
│                         [Research Tier — Direct ANE]                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────────────────┐  ┌─────────────────────────────────────┐      │
│  │    ☆ GLASS BALL ☆       │  │      HARDWARE SUBSTRATE PANEL       │      │
│  │                         │  │                                     │      │
│  │     [Metal-rendered       │  │  ANE Power: ████████░░ 2.3W        │      │
│  │      3D sphere with      │  │  GPU Power: ████░░░░░░ 1.1W        │      │
│  │      orbiting feature     │  │  ANE Freq:  ██████████ 1.2GHz      │      │
│  │      particles]           │  │  Temp:      ██░░░░░░░░ 43°C        │      │
│  │                         │  │  ANE Util:  ██████░░░░ 62% (derived)│      │
│  │  Active concepts pulse   │  │                                     │      │
│  │  and glow. Related       │  │  [┌─────────────────────────┐]      │      │
│  │  concepts cluster.       │  │  │ ANE Workload Breakdown  │]      │      │
│  │                         │  │  │ • Text gen: 65%         │]      │      │
│  │  Touch/drag to rotate.   │  │  │ • Embedding: 20%       │]      │      │
│  │  Click feature to see    │  │  │ • Attention: 15%       │]      │      │
│  │  activating tokens.     │  │  └─────────────────────────┘]      │      │
│  │                         │  │                                     │      │
│  └─────────────────────────┘  └─────────────────────────────────────┘      │
│                                                                               │
│  ┌─────────────────────────┐  ┌─────────────────────────────────────┐      │
│  │   ATTENTION MAP         │  │   COGNITIVE STEERING PANEL        │      │
│  │   (what model sees)     │  │   (adjust behavior in real-time)  │      │
│  │                         │  │                                     │      │
│  │  [heatmap over input     │  │  Honesty        [====|====]  0.3   │      │
│  │   text, brighter =      │  │  Code Safety    [====|====]  0.5   │      │
│  │   more attention]       │  │  Creativity     [====|====]  0.0   │      │
│  │                         │  │  Technical Deep [====|====]  0.1   │      │
│  │  "The contract shall    │  │  Sycophancy Supp[====|====] -0.2   │      │
│  │   be binding..."        │  │                                     │      │
│  │   ▓▓▓▓▓░░░░▓▓▓▓▓▓▓▓    │  │  [Apply Steering] [Reset Defaults]  │      │
│  │   contract binding      │  │                                     │      │
│  └─────────────────────────┘  └─────────────────────────────────────┘      │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  KV CACHE / WORKING MEMORY VISUALIZATION                            │   │
│  │                                                                     │   │
│  │  [Crystal lattice showing retained context tokens. Size = memory    │   │
│  │   pressure. Color = token importance. Fade = decay over time.]     │   │
│  │                                                                     │   │
│  │  • "Project requirements" [████████] 0.92 (recent, critical)      │   │
│  │  • "User wants legal review" [██████░░] 0.74 (recent, important)   │   │
│  │  • "Previous conversation" [██░░░░░░] 0.31 (older, fading)       │   │
│  │  • "System prompt" [████░░░░░] 0.58 (persistent)                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                               │
│  Status: Generating token 47/1024 | Latency: 23ms/tok | t/s: 42 | ANE Active  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# PART IV: THE BUILD PLAN

## Phase 1: Foundation (Week 1)
- [ ] Integrate `macmon` IOKit power reading for ANE/GPU telemetry
- [ ] Add `ANEKit.swift` — wrapper for SMC/IOKit private APIs
- [ ] Build hardware panel (power, frequency, temperature, derived utilization)

## Phase 2: Activation Capture (Week 2)
- [ ] Modify MLX inference to expose hidden states at designated layer
- [ ] Add `ActivationBuffer` — ring buffer for streaming captures
- [ ] Performance: capture every 4th token, only when panel visible

## Phase 3: SAE Integration (Week 3)
- [ ] Port Gemma Scope SAE encoder to Metal Performance Shaders
- [ ] Or: Train custom SAE on your Qwen model activations
- [ ] Build `SAEEncoder` — matrix multiply + TopK on GPU

## Phase 4: Feature Database (Week 4)
- [ ] Auto-label top-activating features using frontier LLM API
- [ ] Build `FeatureMetadataDB` with categories, descriptions, examples
- [ ] Manual curation pass for safety-critical features

## Phase 5: Glass Ball UI (Week 5)
- [ ] Metal particle system for orbiting features
- [ ] Color coding by category (code=blue, reasoning=green, safety=red)
- [ ] Interaction: hover to see label, click to see examples

## Phase 6: Steering (Week 6)
- [ ] Add steering vector application to inference pipeline
- [ ] Build `SteeringConfiguration` with named presets
- [ ] Safety interlocks: max steering magnitude, forbidden feature combinations

**Total**: 6 weeks from nothing to a working ANE Cognition Observatory.

---

# PART V: RISKS & MITIGATIONS

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| SAE slows inference by >20% | Medium | High | Capture only every Nth token; run SAE on separate Metal queue |
| Feature labels are nonsense | Medium | Medium | Auto-label with LLM + human curation; show confidence scores |
| Steering makes model incoherent | Medium | High | Clamp total steering magnitude; interlock conflicting vectors |
| ANE power API breaks in macOS update | Low | High | Graceful degradation to GPU-only metrics; monitor Apple beta releases |
| SAE features don't generalize | Medium | Medium | Train on diverse corpus; validate on held-out data |
| App size bloat (SAE matrices) | Medium | Medium | SAE matrices are ~200MB; load on-demand for active model |
| User overwhelmed by information | Low | Low | Default to "simple mode" (just Glass Ball); advanced panel collapsible |

---

# PART VI: THE TRUTH ABOUT THE "GLASS BALL"

## What You Actually Get

The Glass Ball is not magic. It is **mechanistic interpretability** made real-time and beautiful. It shows:

1. **What concepts the model is activating** (via SAE features)
2. **What the model is attending to** (via attention heatmap)
3. **What the model remembers** (via KV cache visualization)
4. **How much power the ANE is using** (via IOKit telemetry)
5. **How you can steer the model** (via activation intervention)

This is **more powerful** than raw ANE telemetry would be. Knowing "the model is currently reasoning about legal liability with 0.8 confidence and is attending to the word 'indemnify'" is infinitely more actionable than "ANE Core 3 is at 84% utilization."

## The Honest Limitation

You cannot see inside the ANE silicon. Apple will never expose that. But you CAN see inside the model's mind — and that is what matters.

The ANE is just a calculator. The model is the intelligence. The Glass Ball looks at the intelligence.

---

# PART VII: INTEGRATION WITH YOUR EXISTING ARCHITECTURE

## Where This Fits

| Your Existing Layer | How Glass Ball Connects |
|--------------------|------------------------|
| `agent_core` (agent runtime) | Add `cognition_observatory.rs` module; streams activation data |
| `MLXInferenceService.swift` | Add `captureHiddenStates` parameter; return `ActivationSnapshot[]` |
| `epistemos-shadow` (search) | Feature DB lookup for SAE feature metadata |
| `graph-engine` (graph) | Store feature activation history as time-series graph nodes |
| `ContextualShadows` (memory) | KV cache visualization uses same data structures |
| Provenance spine (OpLog) | Every steering intervention is logged with before/after activations |
| Ternary substrate | Claim states can be colored by active safety features |
| Residency Governor | Memory eviction decisions informed by feature importance scores |

## The Feature Flag

```rust
#[cfg(feature = "research")]
fn enable_cognition_observatory() -> bool {
    // Requires: direct ANE access (for telemetry)
    // Requires: Metal compute (for SAE encoding)
    // Requires: not sandboxed (for IOKit SMC access)
    true
}
```

---

*This assessment is based on:
- Anthropic "Scaling Monosemanticity" paper (May 2024) ^1^ ^2^- OpenAI SAE research (June 2024) ^1^- Google DeepMind Gemma Scope (July 2024) ^1^ ^3^- SAE survey paper (EMNLP 2025) ^1^- Anthropic feature steering documentation ^4^ ^5^- Neuronpedia steering API ^5^- macmon/FluidTop ANE power monitoring tools ^6^ ^7^- M4 ANE direct programming research (maderix 2026) ^8^- MLX Metal debugger documentation ^9^- Core ML custom layer protocols ^10^ ^11^- Mechanistic interpretability community research (SAELens, etc.) ^12^ ^13^*
