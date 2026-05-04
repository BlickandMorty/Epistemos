#include <metal_stdlib>
using namespace metal;

// Core seed: CountSketch update using q16 fixed-point integer atomics.
// The runtime converts back to float after the GPU update pass.

constant uint epst_mersenne_p = 0x7fffffffu;

inline uint epst_hash_mersenne(uint a, uint b, uint index) {
    ulong product = ulong(a) * ulong(index) + ulong(b);
    uint hi = uint(product >> 31);
    uint lo = uint(product & ulong(epst_mersenne_p));
    uint sum = hi + lo;
    return (sum >= epst_mersenne_p) ? (sum - epst_mersenne_p) : sum;
}

inline int epst_count_sketch_sign(uint c, uint d, uint index) {
    return ((epst_hash_mersenne(c, d, index) & 1u) == 0u) ? 1 : -1;
}

kernel void count_sketch_update(
    device atomic_int* sketch_q16,
    device const half* values,
    device const uint* indices,
    constant uint& update_count,
    constant uint& width,
    constant uint& depth,
    constant uint4& hash_params,
    constant float& value_scale,
    uint gid [[thread_position_in_grid]])
{
    if (gid >= update_count || width == 0 || depth == 0) {
        return;
    }

    uint index = indices[gid];
    int scaled_value = int(rint(float(values[gid]) * value_scale));

    for (uint row = 0; row < depth; row++) {
        uint a = hash_params.x + row * 2654435761u;
        uint b = hash_params.y + row * 2246822519u;
        uint c = hash_params.z + row * 3266489917u;
        uint d = hash_params.w + row * 668265263u;
        uint bucket = epst_hash_mersenne(a, b, index) % width;
        int addend = scaled_value * epst_count_sketch_sign(c, d, index);
        atomic_fetch_add_explicit(&sketch_q16[row * width + bucket], addend, memory_order_relaxed);
    }
}
