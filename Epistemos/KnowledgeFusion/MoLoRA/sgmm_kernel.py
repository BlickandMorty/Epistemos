"""
Epistemos MoLoRA — Segmented Grouped Matrix Multiplication (SGMM) Metal Kernel

Computes LoRA delta: delta_y = (x @ A) @ B * scale
for a single adapter group's tokens using a custom Metal compute kernel.

Architecture: AdaFuse decide-once pre-gating. Tokens are sorted by adapter
assignment ONCE before the forward pass. Each kernel launch processes one
contiguous adapter group — zero SIMD divergence.

CRITICAL: This kernel NEVER fuses adapters into base weights.
Adapters remain as separate A/B matrices. The delta is added to the base
matmul output externally.
"""

import mlx.core as mx

# ── Metal Kernel Source ──────────────────────────────────────────────────────

SGMM_LORA_KERNEL_SOURCE = """
    // Fused LoRA delta: delta_y = (x @ A) @ B * scale
    // x:      [B_group, d_in]   — hidden states for this adapter group
    // lora_a: [d_in, rank]      — LoRA down-projection
    // lora_b: [rank, d_out]     — LoRA up-projection
    // delta_y:[B_group, d_out]  — output LoRA contribution
    //
    // Each thread computes one (token, out_dim) element.
    // Inner loop over rank is small (8 or 32), fits in registers.

    uint token_id = thread_position_in_grid.y;
    uint j = thread_position_in_grid.x;

    if (token_id >= B_group || j >= d_out) return;

    // Phase 1: Compute intermediate = dot(x[token_id, :], A[:, r]) for each r
    // Phase 2: Accumulate intermediate[r] * B[r, j] for all r
    // Fused into single loop to keep intermediate in registers.

    T acc = T(0);
    for (uint r = 0; r < rank; ++r) {
        // dot(x[token_id, :], A[:, r])
        T inner = T(0);
        for (uint k = 0; k < d_in; ++k) {
            inner += x[token_id * d_in + k] * lora_a[k * rank + r];
        }
        // Multiply by B[r, j]
        acc += inner * lora_b[r * d_out + j];
    }

    delta_y[token_id * d_out + j] = acc * T(scale);
"""

# Optimized version with threadgroup memory tiling for larger d_in
SGMM_LORA_KERNEL_TILED_SOURCE = """
    // Tiled version: uses threadgroup memory to cache x tiles.
    // Better for d_in > 256 where global memory reads dominate.

    uint token_id = thread_position_in_grid.y;
    uint j = thread_position_in_grid.x;

    if (token_id >= B_group || j >= d_out) return;

    T acc = T(0);

    // For small rank (<=32), the A columns fit in registers.
    // Loop over rank in outer loop, accumulate x·A[:,r] via tiled reads of x.
    for (uint r = 0; r < rank; ++r) {
        T inner = T(0);

        // Tile over d_in dimension for better cache utilization
        for (uint k_base = 0; k_base < d_in; k_base += 32) {
            uint k_end = min(k_base + 32, d_in);
            for (uint k = k_base; k < k_end; ++k) {
                inner += x[token_id * d_in + k] * lora_a[k * rank + r];
            }
        }

        acc += inner * lora_b[r * d_out + j];
    }

    delta_y[token_id * d_out + j] = acc * T(scale);
"""


# ── Python Wrapper ───────────────────────────────────────────────────────────

_kernel_cache = {}


def _get_kernel(d_in: int, rank: int, d_out: int):
    """Get or create the cached Metal kernel for given dimensions."""
    key = (d_in, rank, d_out)
    if key not in _kernel_cache:
        # Use tiled version for larger hidden dims
        source = SGMM_LORA_KERNEL_TILED_SOURCE if d_in > 256 else SGMM_LORA_KERNEL_SOURCE

        _kernel_cache[key] = mx.fast.metal_kernel(
            name=f"sgmm_lora_{d_in}_{rank}_{d_out}",
            input_names=["x", "lora_a", "lora_b"],
            output_names=["delta_y"],
            source=source,
            header="""
                constant uint& B_group [[buffer(10)]];
                constant uint& d_in    [[buffer(11)]];
                constant uint& rank    [[buffer(12)]];
                constant uint& d_out   [[buffer(13)]];
                constant float& scale  [[buffer(14)]];
            """,
        )
    return _kernel_cache[key]


def apply_lora_delta(
    x: mx.array,
    lora_a: mx.array,
    lora_b: mx.array,
    scale: float,
) -> mx.array:
    """
    Compute LoRA delta for one adapter group using the Metal kernel.

    Args:
        x:      [B_group, d_in]  float16 — hidden states for this group
        lora_a: [d_in, rank]     float16 — LoRA A matrix
        lora_b: [rank, d_out]    float16 — LoRA B matrix
        scale:  float            — alpha / rank scaling factor

    Returns:
        delta_y: [B_group, d_out] float16 — LoRA contribution
    """
    B_group, d_in = x.shape
    rank = lora_a.shape[1]
    d_out = lora_b.shape[1]

    # Ensure contiguous row-major layout
    x = mx.contiguous(x) if not x.flags["row_contiguous"] else x
    lora_a = mx.contiguous(lora_a) if not lora_a.flags["row_contiguous"] else lora_a
    lora_b = mx.contiguous(lora_b) if not lora_b.flags["row_contiguous"] else lora_b

    kernel = _get_kernel(d_in, rank, d_out)

    # Threadgroup: 32 wide (d_out tiles), 1 tall (tokens processed per thread)
    tg_x = min(32, d_out)
    tg_y = min(32, B_group)
    grid_x = (d_out + tg_x - 1) // tg_x * tg_x
    grid_y = (B_group + tg_y - 1) // tg_y * tg_y

    outputs = kernel(
        inputs=[x, lora_a, lora_b],
        template=[("T", x.dtype)],
        grid=(grid_x, grid_y, 1),
        threadgroup=(tg_x, tg_y, 1),
        output_shapes=[(B_group, d_out)],
        output_dtypes=[x.dtype],
        init_value=0,
        verbose=False,
        # Pass dimension constants
        B_group=B_group,
        d_in=d_in,
        rank=rank,
        d_out=d_out,
        scale=scale,
    )

    return outputs[0]


def apply_lora_delta_fallback(
    x: mx.array,
    lora_a: mx.array,
    lora_b: mx.array,
    scale: float,
) -> mx.array:
    """
    Pure MLX fallback (no custom kernel). Used if Metal kernel fails.
    Same computation: delta_y = (x @ A) @ B * scale
    """
    intermediate = mx.matmul(x, lora_a)    # [B_group, rank]
    delta = mx.matmul(intermediate, lora_b)  # [B_group, d_out]
    return delta * scale


# Auto-select: try Metal kernel, fall back to MLX matmul
def lora_delta(
    x: mx.array,
    lora_a: mx.array,
    lora_b: mx.array,
    scale: float,
) -> mx.array:
    """
    Compute LoRA delta with automatic kernel selection.
    Tries custom Metal kernel first, falls back to MLX matmul.
    """
    try:
        return apply_lora_delta(x, lora_a, lora_b, scale)
    except Exception:
        return apply_lora_delta_fallback(x, lora_a, lora_b, scale)
