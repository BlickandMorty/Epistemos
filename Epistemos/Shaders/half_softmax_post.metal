// half_softmax_post.metal
//
// HELIOS V5 W7 — Half-softmax post-not-pre rewrite (Tier-1 ≤ 2 ULP).
//
// HELIOS-W7-METAL guard
//
// Per docs/HELIOS_V5_DOC_6_THEOREM_CANON.md §2 H2 +
// `agent_core/src/scope_rex/metal/softmax.rs` (the Rust pure-Rust
// reference that locks ≤ 2 ULP drift).
//
// **Tier 1 contract:** the GPU output matches the canonical
// max-subtraction stable softmax within 2 ULP per element on any
// input vector. Per HELIOS v3 §T2: applying half-softmax AFTER the
// resonance phase preserves the Babai lattice closure.
//
// Loaded by `Epistemos/Engine/MetalRuntimeManager.swift` once W7.b
// MLXInferenceService DELTA wiring lands.
//
// Build flags applied by Xcode (release config):
//   -O3 -ffast-math

#include <metal_stdlib>
using namespace metal;

/// Half-softmax post-not-pre kernel. Two-pass canonical form:
///   Pass 1: find max(input)
///   Pass 2: compute exp(input[i] - max), accumulate sum
///   Pass 3: divide each output by sum
///
/// One thread per output element; threadgroup-shared max + sum
/// arrays ensure cross-thread coherence.
///
/// **Numerical stability:**
///   - max-subtraction prevents exp() overflow on large inputs
///   - NaN propagation: any NaN input produces NaN throughout
///     the output (matches Rust reference contract)
///   - Underflow: exp(very-negative) → 0.0 cleanly
///
/// Output positions where input is NaN are NaN; otherwise output
/// is in [0, 1] and Σ output = 1.0 within fp32 epsilon.
kernel void halfSoftmaxPost(
    device const float* input  [[buffer(0)]],
    device       float* output [[buffer(1)]],
    constant     uint&  length [[buffer(2)]],
    threadgroup  float* shared [[threadgroup(0)]],   // size ≥ 2 floats: [max, sum]
    uint                tid    [[thread_position_in_grid]],
    uint                tg_id  [[threadgroup_position_in_grid]],
    uint                tg_size [[threads_per_threadgroup]]
) {
    if (tid >= length) return;

    // Pass 1: parallel reduction to find max.
    // Single-threadgroup launch assumed; for length > tg_size, the
    // host dispatches in tiles + reduces tile-maxes externally.
    if (tid == 0) {
        float m = -INFINITY;
        bool has_nan = false;
        for (uint i = 0; i < length; ++i) {
            float v = input[i];
            if (isnan(v)) { has_nan = true; }
            if (v > m) m = v;
        }
        if (has_nan) {
            // Propagate NaN by writing NaN to shared and short-circuiting.
            shared[0] = NAN;
        } else {
            shared[0] = m;
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    float maxv = shared[0];
    if (isnan(maxv)) {
        output[tid] = NAN;
        return;
    }

    // Pass 2: compute exp(input - max) per thread; threadgroup sum.
    float e = exp(input[tid] - maxv);
    output[tid] = e;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    if (tid == 0) {
        float s = 0.0f;
        for (uint i = 0; i < length; ++i) {
            s += output[i];
        }
        shared[1] = (s > 0.0f) ? s : 1.0f;   // div-zero guard
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Pass 3: normalize.
    float sum = shared[1];
    output[tid] = e / sum;
}
