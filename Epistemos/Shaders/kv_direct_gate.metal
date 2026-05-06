// kv_direct_gate.metal
//
// HELIOS V5 W8 — KV-Direct gate (Tier-1 round-trip equality).
//
// HELIOS-W8-METAL guard
//
// Per docs/HELIOS_V5_DOC_6_THEOREM_CANON.md §2 H7 (six-tier memory) +
// `agent_core/src/scope_rex/kv/direct_gate.rs` (the Rust pure-Rust
// reference that locks BIT-IDENTICAL output between reference and
// direct paths).
//
// **Tier 1 contract:** for any KV layout that passes the
// `direct_path_eligible()` predicate (same-dim + page-aligned +
// non-empty), the GPU output is BIT-IDENTICAL to the reference
// paged-attention QK row.
//
// Per HELIOS v3 W0 + Qasim et al. arXiv:2603.19664 (residual stream
// is bit-identical sufficient): KV-Direct is the cheaper preflight
// (D_KL ≈ 0 between residual-patched and original output on
// Qwen3-8B-MLX-4bit at 128k).
//
// Loaded by `Epistemos/Engine/MetalRuntimeManager.swift` once W8.b
// Qwen3 KV-cache wiring lands.
//
// Build flags applied by Xcode (release config):
//   -O3 -ffast-math

#include <metal_stdlib>
using namespace metal;

/// KV-Direct QK row kernel.
///
/// Inputs:
///   - query[key_dim] — current query vector
///   - keys[seq_len * key_dim] — KV cache keys (row-major; seq_len
///     pairs of key_dim-vectors)
///   - seq_len, key_dim — layout constants
/// Output:
///   - qk_row[seq_len] — one dot product per cached key position
///
/// One thread per (seq_len) output position. Each thread computes
///   qk_row[gid] = Σ_d query[d] * keys[gid * key_dim + d]
/// in the SAME order as the Rust reference (d ascending) so the
/// floating-point sum is BIT-IDENTICAL.
///
/// **Eligibility:** caller's responsibility — kernel assumes the
/// layout already passed `direct_path_eligible()` checks
/// (key_dim == value_dim, seq_len % page_size == 0, both > 0).
kernel void kvDirectQkRow(
    device const float* query   [[buffer(0)]],
    device const float* keys    [[buffer(1)]],
    device       float* qk_row  [[buffer(2)]],
    constant     uint&  seq_len [[buffer(3)]],
    constant     uint&  key_dim [[buffer(4)]],
    uint                gid     [[thread_position_in_grid]]
) {
    if (gid >= seq_len) return;

    uint base = gid * key_dim;
    float acc = 0.0f;
    for (uint d = 0; d < key_dim; ++d) {
        acc += query[d] * keys[base + d];
    }
    qk_row[gid] = acc;
}
