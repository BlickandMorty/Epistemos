# Vault State Schema

**Version:** 2
**Date:** 2026-04-08

## Two State Formats

### 1. MLX Prompt Cache (Primary Path — Phase 1A)

MLX-Swift's native `savePromptCache`/`loadPromptCache` handles MambaCache serialization. This is the primary path for state persistence because it's maintained by the MLX team and correctly handles all SSM model variants.

**File extension:** `.mlxcache`
**Location:** `{vault_root}/ssm_cache/{model_id}/{session_id}_{timestamp}.mlxcache`

**Contents:** Tree-flattened MLXArray tensors:
- `0.0`, `0.1` — Layer 0 conv state, SSM state
- `1.0`, `1.1` — Layer 1 conv state, SSM state
- ...
- Metadata dict: `model_id`, `session_id`, `timestamp`, `format`

**MambaCache per layer:**
- `cache[0]` — Conv state: `[batch, d_conv-1, d_inner]` (sliding window buffer)
- `cache[1]` — SSM state: `[batch, d_state, d_inner]` (recurrent hidden state)

### 2. MAMB Binary Format (Custom Runtime — Phase 1B)

Flat binary format designed for zero-copy mmap. Used by the Rust custom runtime.

**File extension:** `.mambastate`
**Location:** `{vault_root}/ssm_state/{model_hash_hex}/{session_id}_{timestamp}.mambastate`

#### v2 Header (56 bytes)

```
Offset  Size  Type    Field
------  ----  ------  -----
0       4     u32     magic = 0x4D414D42 ("MAMB")
4       4     u32     version = 2
8       4     u32     layer_count
12      4     u32     state_dim (N)
16      4     u32     head_dim (D_head)
20      4     u32     dtype (0=f16, 1=f32)
24      4     u32     session_id_len
28      8     u64     timestamp (Unix seconds)
36      8     u64     vault_id (hash of vault root path)
44      8     u64     model_hash (hash of model identifier)
52      4     u32     flags (bit 0: has_conv_state)
56      4     u32     reserved (0)
```

#### Body

```
Offset          Content
------          -------
60              session_id (UTF-8 bytes, padded to 8-byte alignment)
60 + padded_len Layer 0 SSM state: state_dim × head_dim × 2 bytes (f16)
...             Layer 1..N SSM state
```

#### v1 Backward Compatibility

v1 files have 36-byte headers without vault_id/model_hash/flags. The loader detects version from header byte 4-7 and reads accordingly. v2 writers always write v2.

## State Sizes (Representative)

| Model | Layers | H | N | D_head | SSM State | Conv State | Total |
|-------|--------|---|---|--------|-----------|------------|-------|
| LFM2 350M | 24 | 16 | 16 | 64 | ~768 KB | ~384 KB | ~1.1 MB |
| LFM2.5 1.6B | 48 | 32 | 64 | 64 | ~12.6 MB | ~6.3 MB | ~18.9 MB |
| Mamba2 2.7B | 64 | 32 | 64 | 64 | ~16.8 MB | ~8.4 MB | ~25.2 MB |
| Jamba 3B (hybrid) | 32 mamba | 32 | 16 | 64 | ~2 MB | ~1 MB | ~3 MB |

## Vault Scoping

States are scoped by:
1. **vault_root** — Physical directory (hashed as `vault_id`)
2. **model_id** — Model identifier string (hashed as `model_hash`, used as subdirectory)
3. **session_id** — Chat session UUID

This ensures states from different vaults/models never collide.

## Lifecycle Rules

1. Auto-save after each generation turn (if `ssmAutoSaveOnTurnEnd` enabled)
2. Keep latest `ssmMaxSnapshotsPerModel` per model (default 5)
3. States older than 30 days auto-pruned by NightBrain
4. Manual clear via settings UI
5. States invalidated when vault notes modified after snapshot (staleness check)
