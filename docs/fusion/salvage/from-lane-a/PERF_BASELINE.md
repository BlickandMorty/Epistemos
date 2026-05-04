# Performance Baseline

**Date:** 2026-04-08
**Purpose:** Record actual measurements. No fake benchmarks.

## Hardware Under Test

| Field | Value |
|-------|-------|
| Machine | |
| Chip | |
| GPU Cores | |
| Memory | |
| Memory Bandwidth | |
| macOS Version | |
| Xcode Version | |

## State Persistence Performance

| Operation | Duration | File Size | Notes |
|-----------|----------|-----------|-------|
| Save (MLX cache) | TBD ms | TBD MB | savePromptCache |
| Load (MLX cache) | TBD ms | TBD MB | loadPromptCache |
| Save (MAMB binary) | TBD ms | TBD MB | Rust ssm_state::save |
| Load (MAMB binary) | TBD ms | TBD MB | Rust ssm_state::load |

## Generation Performance (MLX-Swift)

| Model | Quantization | TTFT | tok/s (sustained) | Peak Memory | Context |
|-------|-------------|------|-------------------|-------------|---------|
| LFM2 350M | | TBD | TBD | TBD | |
| LFM2.5 1.6B | | TBD | TBD | TBD | |
| Mamba2 2.7B | | TBD | TBD | TBD | |

## Custom Metal Kernel Performance

| Kernel | Input Size | GPU Time | Throughput | Notes |
|--------|-----------|----------|------------|-------|
| segsum_stable | Q=128, H=32 | TBD | TBD | |
| segsum_stable_tiled | Q=128, H=32 | TBD | TBD | |
| intra_chunk_scan | Q=128, L=1K | TBD | TBD | |
| inter_chunk_reduce | 1K chunks | TBD | TBD | |
| depthwise_conv1d_k4 | L=1K, D=2048 | TBD | TBD | |
| conv1d_step (decode) | D=2048 | TBD | TBD | |

## Session Resume Performance

| Metric | Value | Notes |
|--------|-------|-------|
| Cold start (no state) | TBD ms | |
| Warm resume (with state) | TBD ms | |
| Delta (saved by state) | TBD ms | |

## Measurement Protocol

1. Each metric: median of 5 runs after 1 warmup
2. Use `CFAbsoluteTimeGetCurrent()` for Swift timing
3. Use `MTLCommandBuffer` timestamps for GPU timing
4. Use `mach_absolute_time()` for sub-ms precision
5. Record thermal state (nominal/fair/serious/critical)
6. Record power state (battery/AC)
