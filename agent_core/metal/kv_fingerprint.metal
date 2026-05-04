#include <metal_stdlib>
using namespace metal;

// Core seed: compact 2-bit KV sign fingerprint for KV-Direct experiments.

inline uchar epst_encode_trit(float value, float threshold) {
    if (value > threshold) {
        return 0x2;
    }
    if (value < -threshold) {
        return 0x0;
    }
    return 0x1;
}

kernel void kv_fingerprint(
    device const half* keys,
    device uchar* fingerprint,
    constant uint& sequence_length,
    constant uint& head_dim,
    constant uint& head_count,
    constant float& zero_threshold,
    uint2 gid [[thread_position_in_grid]])
{
    uint token = gid.x;
    uint head = gid.y;
    if (token >= sequence_length || head >= head_count || (head_dim & 0x3u) != 0) {
        return;
    }

    uint bytes_per_head = head_dim / 4;
    uint key_offset = token * head_count * head_dim + head * head_dim;
    uint out_offset = token * head_count * bytes_per_head + head * bytes_per_head;

    for (uint byte_index = 0; byte_index < bytes_per_head; byte_index++) {
        uchar packed = 0;
        uint base = key_offset + byte_index * 4;
        for (uint lane = 0; lane < 4; lane++) {
            uchar trit = epst_encode_trit(float(keys[base + lane]), zero_threshold);
            packed |= uchar(trit << uchar(lane * 2));
        }
        fingerprint[out_offset + byte_index] = packed;
    }
}
