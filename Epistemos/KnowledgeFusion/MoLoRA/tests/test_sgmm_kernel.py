"""Tests for the SGMM Metal kernel correctness."""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import mlx.core as mx
from sgmm_kernel import apply_lora_delta, apply_lora_delta_fallback, lora_delta


def _reference_lora(x, a, b, scale):
    """Pure Python/MLX reference: (x @ A) @ B * scale."""
    return apply_lora_delta_fallback(x, a, b, scale)


def test_kernel_rank8():
    """Kernel matches reference for rank=8."""
    B, d_in, rank, d_out = 8, 128, 8, 64
    x = mx.random.normal((B, d_in)).astype(mx.float16)
    a = mx.random.normal((d_in, rank)).astype(mx.float16)
    b = mx.random.normal((rank, d_out)).astype(mx.float16)

    ref = _reference_lora(x, a, b, 2.0)
    result = lora_delta(x, a, b, 2.0)
    mx.eval(ref, result)

    diff = float(mx.max(mx.abs(result - ref)))
    assert diff < 0.1, f"rank=8 diff too large: {diff}"


def test_kernel_rank32():
    """Kernel matches reference for rank=32."""
    B, d_in, rank, d_out = 4, 256, 32, 128
    x = mx.random.normal((B, d_in)).astype(mx.float16)
    a = mx.random.normal((d_in, rank)).astype(mx.float16)
    b = mx.random.normal((rank, d_out)).astype(mx.float16)

    ref = _reference_lora(x, a, b, 2.0)
    result = lora_delta(x, a, b, 2.0)
    mx.eval(ref, result)

    diff = float(mx.max(mx.abs(result - ref)))
    assert diff < 0.5, f"rank=32 diff too large: {diff}"


def test_single_token():
    """Edge case: single token in group."""
    x = mx.random.normal((1, 64)).astype(mx.float16)
    a = mx.random.normal((64, 8)).astype(mx.float16)
    b = mx.random.normal((8, 32)).astype(mx.float16)

    ref = _reference_lora(x, a, b, 1.0)
    result = lora_delta(x, a, b, 1.0)
    mx.eval(ref, result)

    diff = float(mx.max(mx.abs(result - ref)))
    assert diff < 0.1, f"single token diff: {diff}"


def test_scale_zero():
    """Scale=0 should produce zero output."""
    x = mx.random.normal((4, 64)).astype(mx.float16)
    a = mx.random.normal((64, 8)).astype(mx.float16)
    b = mx.random.normal((8, 32)).astype(mx.float16)

    result = lora_delta(x, a, b, 0.0)
    mx.eval(result)

    assert float(mx.max(mx.abs(result))) < 1e-6


def test_output_shape():
    """Output shape matches [B, d_out]."""
    B, d_in, rank, d_out = 16, 512, 16, 256
    x = mx.random.normal((B, d_in)).astype(mx.float16)
    a = mx.random.normal((d_in, rank)).astype(mx.float16)
    b = mx.random.normal((rank, d_out)).astype(mx.float16)

    result = lora_delta(x, a, b, 2.0)
    mx.eval(result)

    assert result.shape == (B, d_out), f"Expected ({B}, {d_out}), got {result.shape}"


def test_fallback_matches_reference():
    """Fallback (pure MLX matmul) produces correct results."""
    x = mx.random.normal((4, 64)).astype(mx.float16)
    a = mx.random.normal((64, 8)).astype(mx.float16)
    b = mx.random.normal((8, 32)).astype(mx.float16)

    result = apply_lora_delta_fallback(x, a, b, 2.0)
    mx.eval(result)

    # Manual reference
    manual = (x @ a) @ b * 2.0
    mx.eval(manual)

    diff = float(mx.max(mx.abs(result - manual)))
    assert diff < 1e-4, f"Fallback diff: {diff}"


if __name__ == "__main__":
    tests = [
        test_kernel_rank8,
        test_kernel_rank32,
        test_single_token,
        test_scale_zero,
        test_output_shape,
        test_fallback_matches_reference,
    ]
    for test in tests:
        try:
            test()
            print(f"  PASS: {test.__name__}")
        except Exception as e:
            print(f"  FAIL: {test.__name__}: {e}")
