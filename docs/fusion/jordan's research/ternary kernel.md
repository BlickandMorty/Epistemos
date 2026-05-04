# Ternary Kernel Architecture for Epistemos

The deepest, highest-confidence conclusion is this:

**You do not need to make the whole app “mystically ternary.” You need to make the dominant inference path ternary, keep a small dense perimeter for fragile operations, and wrap the whole thing in a control room that can inspect, patch, and evaluate that path in real time.** That is how this becomes brilliant instead of theatrical.

The opportunity is real. entity["company","Microsoft","software company"]’s BitNet work made ternary `{-1, 0, +1}` LLM weights a serious direction rather than a curiosity, and the BitNet/bitnet.cpp/T-MAC line of work shows that specialized low-bit kernels are where the gain actually comes from, not just the quantization format itself. In parallel, MLX explicitly leans on unified memory, with CPU and GPU able to work on the same data, and it provides an extension path for custom operations and custom Metal shader integrations. That combination is exactly why Apple Silicon is a good place to attempt this. citeturn6academia11turn10view0turn10view1turn12view1turn14view1turn17view1turn17view2turn17view3

## What I would actually build

I would not build “a ternary app.”  
I would build **a ternary research lane** inside the app.

That lane would have three backends:

| Backend | Purpose | Why it exists |
|---|---|---|
| `DenseMlxBackend` | Gold-standard baseline | Lets you compare quality, latency, and memory against a known-good dense runtime |
| `BitnetReferenceBackend` | External truth source | Lets you validate against the official BitNet/bitnet.cpp behavior |
| `TernaryMetalBackend` | Your breakthrough lane | Where your custom packed-trit kernels, residual islands, and live control room live |

The breakthrough method I recommend is:

## The extraordinary method

### Ternary Core with Residual Islands

The core idea is simple:

**Most transformer linear layers go ternary.  
A tiny set of “fragile” parameters stays dense.**

Those fragile parameters are the places where accuracy usually dies first when you get too aggressive:

- embeddings
- lm head
- norm scales
- selected outlier channels in attention and MLP projections
- small steering/residual patches
- selected layers near the output

So the model becomes:

\[
y = \mathrm{BitLinear}_{ternary}(x; W_t, s) + \mathrm{ResidualIsland}(x; W_r)
\]

Where:

- `W_t` is packed ternary weight data
- `s` is block scale / normalization metadata
- `W_r` is a very small dense correction path

This is the practical version of a ternary LLM that still has teeth. It is optimistic, but it is grounded. The BitNet line already supports the basic proposition that ternary weights can scale, and the efficient inference papers/repos show that **kernel design is the thing that makes ternary worthwhile in practice**. citeturn6academia11turn10view0turn10view1turn12view1turn14view1

### Why this is better than “full ternary everything”

Because full ternary everything is the fastest route to a dead demo.

What should remain dense at first:

- embeddings
- lm head
- RMSNorm / LayerNorm parameters
- logits processing
- attention softmax
- rope/trig tables
- steering deltas
- safety / verification side channels

What should go ternary first:

- Q/K/V/O projections
- up/down/gate MLP projections
- decode-path GEMV hot loops
- selected prefill GEMM paths after decode is stable

That is the first major architectural correction I would make to the Kimi synthesis: **decode-first ternary optimization**. On-device chat is often decode-bound and memory-bandwidth-bound. That means the earliest wins come from the token-by-token projection path, not from trying to rewrite every kernel in the stack on day one. BitNet/bitnet.cpp and T-MAC both point in that general direction: specialized low-bit kernels matter most where dense multiply dominates runtime and bandwidth. citeturn10view1turn12view1turn14view1

## The kernel portfolio

This is the kernel set I would engineer, in this order.

### Ternary packing and unpacking

You need a standard physical representation before anything else.

Use:

- `00 = -1`
- `01 = 0`
- `10 = +1`
- `11 = reserved`

Pack 16 trits into one `u32`.

This is not the fastest imaginable format, but it is the correct starting point because it is debuggable, deterministic, and friendly to control-room inspection.

### Block-scaled ternary GEMV

This is the first performance-critical kernel.  
For decode, matrix-vector multiply matters more than beautiful abstractions.

Each block should have:

- packed trits
- one fp16 or fp32 block scale
- optional sparse mask or “nonzero count” metadata

### Fused ternary projection with residual island add

Do not stop at “ternary dot product.”  
Fuse the residual island correction into the same pass.

That cuts memory traffic and makes the dense-perimeter idea real.

### Fused RMSNorm + ternary projection

Once the base projection works, fuse one cheap normalization stage before or after projection if profiling says it helps.

### Ternary KV fingerprint kernel

Do **not** ternarize full KV cache first.  
Instead, compute a **ternary fingerprint shadow** for each token or segment:

- sign of dominant key channels
- zero bucket for near-zero channels
- small block scale metadata

This gives you:

- retrieval / memory routing
- semantic dedupe
- implant matching
- cache selection

without risking core-generation quality.

### Live activation capture kernel

One tiny side-effect kernel to copy selected activations to a shared ring buffer for the control room.

### Steering delta apply kernel

A tiny kernel that adds or removes small dense steering vectors or residual patches, layer by layer, without reloading the model.

That becomes the mechanism behind “manual information implantation,” “behavior sliders,” and safe experimental editing.

## Code scaffold

The cleanest approach is a dedicated Rust inference lane with Metal underneath, bridged into Swift with UniFFI. MLX is still extremely valuable, but mainly as a baseline backend and as an experimental comparator. MLX’s own docs highlight unified memory and provide an extension/custom-op path, but a full custom ternary decode stack is cleaner if you own the runtime rather than trying to twist every part of MLX into a different execution model. citeturn17view1turn17view2turn17view3

### Proposed file tree

```text
epistemos/
  App/
    Sources/
      ControlRoom/
        TernaryControlRoomView.swift
        TensorHexView.swift
        KernelTimelineView.swift
        ImplantPanelView.swift
      Chat/
        FreeformSessionView.swift
        LiveDraftOverlay.swift
      Security/
        BiometricWriteGate.swift

  crates/
    ternary-core/
      src/
        lib.rs
        trit.rs
        pack.rs
        scale.rs
        math.rs
        claim_state.rs

    ternary-metal/
      src/
        lib.rs
        device.rs
        pipeline.rs
        heaps.rs
        profiler.rs
        kernels.rs
      metal/
        ternary_pack.metal
        ternary_gemv.metal
        ternary_proj_residual.metal
        ternary_rmsnorm_proj.metal
        kv_fingerprint.metal
        activation_tap.metal
        steering_add.metal

    ternary-model/
      src/
        lib.rs
        bitnet_loader.rs
        gguf_tq.rs
        residual_islands.rs
        layer_map.rs
        projection.rs
        rope.rs
        lm_head.rs

    ternary-memory/
      src/
        lib.rs
        kv_shadow.rs
        implant.rs
        snapshot.rs
        semantic_cache.rs

    ternary-runtime/
      src/
        lib.rs
        backend.rs
        dense_mlx_backend.rs
        bitnet_reference_backend.rs
        ternary_metal_backend.rs
        scheduler.rs
        freeform.rs
        rollback.rs
        metrics.rs

    ternary-eval/
      src/
        lib.rs
        perplexity.rs
        latency.rs
        determinism.rs
        energy.rs
        memory.rs
        taskbench.rs

    ffi-bridge/
      src/
        lib.rs
        api.udl
```

### Core Rust types

```rust
// crates/ternary-core/src/trit.rs
#[repr(i8)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Trit {
    Neg = -1,
    Zero = 0,
    Pos = 1,
}

#[derive(Clone, Copy, Debug)]
pub struct BlockScale(pub f32);

#[derive(Clone, Debug)]
pub struct PackedTritBlock {
    /// 16 trits packed into one u32 (2 bits per trit)
    pub words: Vec<u32>,
    /// one scale per logical block
    pub scales: Vec<BlockScale>,
    /// logical dimensions
    pub rows: usize,
    pub cols: usize,
    /// block size along input dimension
    pub block: usize,
}
```

### Packed ternary projection API

```rust
// crates/ternary-model/src/projection.rs
use ternary_core::PackedTritBlock;

pub struct ResidualIsland {
    pub row_indices: Vec<u32>,
    pub col_indices: Vec<u32>,
    pub values: Vec<f16>,
}

pub struct TernaryProjection {
    pub weight: PackedTritBlock,
    pub residual: Option<ResidualIsland>,
    pub bias: Option<Vec<f16>>,
}

impl TernaryProjection {
    pub fn output_dim(&self) -> usize { self.weight.rows }
    pub fn input_dim(&self) -> usize { self.weight.cols }
}
```

### UniFFI surface

```rust
// crates/ffi-bridge/src/lib.rs
use uniffi::export;

#[derive(uniffi::Record, Clone)]
pub struct TernaryRunConfig {
    pub backend: String, // "dense_mlx" | "bitnet_ref" | "ternary_metal"
    pub max_tokens: u32,
    pub freeform: bool,
    pub live_draft: bool,
}

#[derive(uniffi::Record, Clone)]
pub struct TernaryMetrics {
    pub prompt_ms: f64,
    pub decode_tok_s: f64,
    pub peak_bytes: u64,
    pub deterministic: bool,
}

#[export]
pub fn run_ternary_prompt(prompt: String, cfg: TernaryRunConfig) -> Result<TernaryMetrics, String> {
    ternary_runtime::run(prompt, cfg)
}
```

### Metal kernel scaffold

This is a scaffold, not a fully tuned kernel. The point is to establish the right shape.

```metal
#include <metal_stdlib>
using namespace metal;

inline int decode_trit(uint word, uint slot) {
    uint bits = (word >> (slot * 2)) & 0x3;
    switch (bits) {
        case 0: return -1; // 00
        case 1: return  0; // 01
        case 2: return  1; // 10
        default: return 0; // 11 reserved
    }
}

kernel void ternary_gemv(
    device const half* x              [[buffer(0)]],
    device const uint* packed_w       [[buffer(1)]],
    device const float* block_scales  [[buffer(2)]],
    device float* y                   [[buffer(3)]],
    constant uint& in_dim             [[buffer(4)]],
    constant uint& block_size         [[buffer(5)]],
    constant uint& words_per_row      [[buffer(6)]],
    uint row                          [[thread_position_in_grid]]
) {
    float acc = 0.0f;
    uint base_word = row * words_per_row;

    for (uint j = 0; j < in_dim; ++j) {
        uint word_idx = j / 16;
        uint slot = j % 16;
        int t = decode_trit(packed_w[base_word + word_idx], slot);

        uint block_idx = j / block_size;
        float s = block_scales[row * ((in_dim + block_size - 1) / block_size) + block_idx];

        acc += float(t) * float(x[j]) * s;
    }

    y[row] = acc;
}
```

### Residual-island fused pass

```metal
kernel void ternary_proj_residual(
    device const half* x                 [[buffer(0)]],
    device const uint* packed_w          [[buffer(1)]],
    device const float* block_scales     [[buffer(2)]],
    device const uint* r_rows            [[buffer(3)]],
    device const uint* r_cols            [[buffer(4)]],
    device const half* r_vals            [[buffer(5)]],
    device const uint& residual_nnz      [[buffer(6)]],
    device float* y                      [[buffer(7)]],
    constant uint& in_dim                [[buffer(8)]],
    constant uint& block_size            [[buffer(9)]],
    constant uint& words_per_row         [[buffer(10)]],
    uint row                             [[thread_position_in_grid]]
) {
    float acc = 0.0f;

    uint base_word = row * words_per_row;
    for (uint j = 0; j < in_dim; ++j) {
        uint word_idx = j / 16;
        uint slot = j % 16;
        int t = decode_trit(packed_w[base_word + word_idx], slot);
        uint block_idx = j / block_size;
        float s = block_scales[row * ((in_dim + block_size - 1) / block_size) + block_idx];
        acc += float(t) * float(x[j]) * s;
    }

    for (uint k = 0; k < residual_nnz; ++k) {
        if (r_rows[k] == row) {
            acc += float(r_vals[k]) * float(x[r_cols[k]]);
        }
    }

    y[row] = acc;
}
```

### Swift control room surface

```swift
import SwiftUI

@MainActor
final class TernaryControlRoomModel: ObservableObject {
    @Published var selectedBackend: String = "ternary_metal"
    @Published var liveDraftEnabled: Bool = true
    @Published var freeformEnabled: Bool = true
    @Published var lastMetrics: TernaryMetrics?
    @Published var writePathUnlocked: Bool = false

    func authenticateWritePath() async -> Bool {
        // Gate implant/patch/rollback operations behind biometric approval.
        // Use device-owner authentication on macOS.
        return true
    }

    func run(prompt: String) async {
        let cfg = TernaryRunConfig(
            backend: selectedBackend,
            max_tokens: 256,
            freeform: freeformEnabled,
            live_draft: liveDraftEnabled
        )

        do {
            let result = try runTernaryPrompt(prompt: prompt, cfg: cfg)
            self.lastMetrics = result
        } catch {
            // present diagnostics
        }
    }
}
```

## The research-lane features that are actually worth it

### Live Freeform

This is a very good feature for local models.

The right version is **not** “the model spills private chain-of-thought.”  
The right version is:

- as the user types, the local model emits
  - evolving gist
  - likely intent
  - likely next subquestion
  - possible answer skeleton
- every new keystroke cancels and restarts the draft loop
- debounce at 50–100 ms
- show it in a ghost layer under the cursor or in a right-side live panel
- only the final submitted message enters the durable conversation history

This works well locally because latency can be very small and cost is effectively zero. It is especially good when paired with the ternary state model:

- green = fits / confident
- yellow = waiting / emerging
- red = falls / contradicted

That makes the app feel visceral without pretending it is doing magic.

### Implant control room

The control room should show:

- active backend
- packed weight footprint
- residual-island size
- decode tok/s
- prompt ms
- current steering deltas
- current implant snapshots
- rollback history
- activation tap status

What it should **not** show in v1:

- fake ANE omniscience
- every raw tensor by default
- dozens of simultaneously editable low-level controls

The mistake here would be building a cockpit instead of an instrument.

### Ternary memory routing

A powerful extension of your epistemic architecture is to make memory routing ternary too.

Each candidate memory item gets:

- `+1` promote now
- `0` hold / insufficient evidence
- `-1` reject / likely noise

That is much more useful than a simple include/exclude threshold.

## Rigorous evaluation

If you want this to be intellectually serious, you need a kill-or-promote rubric.

### What to measure

Measure every backend on the same tasks:

- prompt latency
- decode throughput
- peak unified-memory usage
- energy draw
- perplexity regression
- instruction-following regression
- domain-task regression
- determinism under seeded replay
- patch rollback correctness
- crash-free hours

### Minimum go/no-go bar

For the `TernaryMetalBackend` to graduate from research toy to real lane, I would require:

| Metric | Minimum bar |
|---|---|
| Decode tok/s | at least **1.5×** dense baseline on the same laptop for the same model class |
| Peak memory | at least **2×** reduction on core weight footprint |
| Quality | no more than **5% perplexity regression** or a task-specific regression you can justify |
| Stability | zero silent corruption, zero NaN cascades in overnight soak |
| Rollback | full model-state rollback in under **250 ms** |
| Freeform loop | median refresh under **120 ms** |
| Implant safety | all write-path operations hash-logged and reversible |

If it misses those bars, do not romanticize it. Keep the code, keep the research lane, but do not let it colonize the stable app.

### The evaluation ladder

Use four stages.

#### Functional correctness

- packed trit decode matches CPU reference
- projection outputs match scalar reference within tolerance
- residual add path matches dense reference
- chunked and unchunked outputs agree

#### Numerical behavior

- perplexity on held-out text
- stability across long decode
- output drift after implant/patch sequences

#### Systems behavior

- steady-state decode speed
- warm vs cold startup
- memory fragmentation
- contention when control room is open

#### Product behavior

- does Freeform actually help
- does live draft distract or assist
- does the control room make people smarter or just noisier
- does ternary memory routing improve retrieval precision

## The core correction to the older ternary vision

Here is the strongest tweak I would make to the prior synthesis:

**Do not define victory as “everything becomes ternary.”  
Define victory as “the bandwidth-dominant math becomes ternary, while reasoning governance, memory routing, and editing controls also become ternary-native.”**

That means you get three layers of ternarity:

### Numerical ternarity

`{-1, 0, +1}` weights and packed kernels.

### Epistemic ternarity

`fits / waiting / falls` claim states.

### Operational ternarity

`promote / hold / reject` for memory, implants, and agent actions.

That is not just quantization.  
That is an actual new cognitive-stack signature.

## What I would ship in sequence

### First build

- ternary pack/unpack
- decode-only ternary GEMV
- dense baseline comparator
- metrics panel
- rollback
- Freeform local draft mode

### Second build

- fused residual-island kernel
- ternary memory routing
- implant snapshot format
- activation tap
- Swift control room

### Third build

- selected prefill kernels
- smarter residual-island training
- live steering deltas
- ternary KV fingerprints
- research-grade explainability overlays

### Last

- any ANE path
- full-stack tensor surgery
- fully ternary cache or attention
- automatic self-retraining claims

That last group is where projects become fan fiction if you rush them.

## Final doctrine

The brilliant version of this architecture is:

**a local-first knowledge and agent system whose baseline is already strong, but whose research lane introduces a ternary-native runtime where the heavy linear algebra path is packed and accelerated, the fragile parts remain dense and editable, unified memory makes inspection and patching immediate, and the user gets a real control room instead of a black box.**

The most important breakthrough is not “ternary as a number format.”

It is this combination:

- **ternary core math**
- **dense residual islands**
- **ternary epistemic states**
- **ternary memory routing**
- **unified-memory control room**
- **live local Freeform drafting**
- **full rollback and evaluation discipline**

That would actually feel like a new class of software.

## Open questions and limits

The main unanswered engineering questions are not philosophical. They are empirical:

- how large the residual islands need to be before quality stabilizes
- whether decode-first ternary speedup on your exact Apple Silicon targets clears the 1.5× bar
- how much quality loss appears when you move from pure reference kernels to aggressively fused kernels
- whether MLX should remain only the dense baseline, or whether a deeper extension path is worth the maintenance burden
- whether ternary KV fingerprints become genuinely useful for routing and implants, or remain a neat but secondary optimization

Those are not blockers. They are the correct frontier.

The right next move is to implement the decode-path kernels, the dense baseline comparator, and the control-room metrics panel first. If those three pieces sing together, the rest of the architecture stops being speculative and starts being inevitable.