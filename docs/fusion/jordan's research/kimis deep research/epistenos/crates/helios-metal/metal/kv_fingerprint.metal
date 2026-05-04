#include <metal_stdlib>
using namespace metal;

// ============================================================================
// kv_fingerprint.metal
// Ternary KV fingerprint shadow for L2 memory tier.
//
// Per-token, per-head: extract sign of dominant key channels.
// Creates a compact ternary fingerprint that shadows the full KV cache.
//
// Encoding per channel (2 bits):
//   +1 (significant positive) -> 10
//    0 (near zero, |val| < threshold) -> 01
//   -1 (significant negative) -> 00
//   reserved -> 11
//
// Pack 4 channels per byte (2 bits each).
// head_dim must be a multiple of 4.
//
// Algorithm per token:
//   for each head:
//     for each group of 4 channels:
//       classify each channel into {-1, 0, +1}
//       pack 4 x 2 bits into one uchar
//
// Output: fingerprint[token, n_heads, head_dim/4] of uchar.
// ============================================================================

inline uchar encode_trit(float val, float threshold) {
    if (val > threshold)  return 0x2;  // +1 -> 10
    if (val < -threshold) return 0x0;  // -1 -> 00
    return 0x1;                        //  0 -> 01
}

kernel void kv_fingerprint(
    device const half* keys,          // [seq_len, n_heads, head_dim]
    device       uchar* fingerprint,  // [seq_len, n_heads, head_dim/4]
    constant     uint& head_dim,       // dimension per head (multiple of 4)
    constant     uint& n_heads,        // number of heads
    constant     float& zero_threshold,// threshold for zero bucket
    uint2 gid [[thread_position_in_grid]])
{
    const uint tid   = gid.x;  // token index
    const uint hid   = gid.y;  // head index

    // Bounds check
    // (out-of-bounds threads return early silently)
    if (hid >= n_heads) return;

    const uint channels_per_byte = 4;
    const uint bytes_per_head    = head_dim / channels_per_byte;
    const uint key_offset        = tid * n_heads * head_dim + hid * head_dim;
    const uint fp_offset         = tid * n_heads * bytes_per_head + hid * bytes_per_head;

    for (uint b = 0; b < bytes_per_head; b++) {
        uchar packed = 0;
        uint base = key_offset + b * channels_per_byte;

        for (uint c = 0; c < channels_per_byte; c++) {
            float val = float(keys[base + c]);
            uchar trit = encode_trit(val, zero_threshold);
            packed |= (trit << (c * 2));
        }

        fingerprint[fp_offset + b] = packed;
    }
}
