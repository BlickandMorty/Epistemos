#include <metal_stdlib>
using namespace metal;

inline ulong mix64(ulong x) {
    x ^= x >> 30;
    x *= 0xbf58476d1ce4e5b9UL;
    x ^= x >> 27;
    x *= 0x94d049bb133111ebUL;
    return x ^ (x >> 31);
}

kernel void sketch_update(
    device atomic_float* buckets [[buffer(0)]],
    device const uint* keys [[buffer(1)]],
    device const float* values [[buffer(2)]],
    constant uint& width [[buffer(3)]],
    constant uint& depth [[buffer(4)]],
    constant ulong& seed [[buffer(5)]],
    uint tid [[thread_position_in_grid]]) {
    uint key = keys[tid];
    float value = values[tid];
    for (uint row = 0; row < depth; ++row) {
        ulong h = mix64(seed ^ ulong(key) ^ (ulong(row) * 0x9e3779b97f4a7c15UL));
        uint bucket = uint(h % ulong(width));
        float sign = ((h >> 63) == 0) ? 1.0f : -1.0f;
        atomic_fetch_add_explicit(&buckets[row * width + bucket], sign * value, memory_order_relaxed);
    }
}

kernel void sketch_estimate(
    device const float* buckets [[buffer(0)]],
    device const uint* keys [[buffer(1)]],
    device float* out [[buffer(2)]],
    constant uint& width [[buffer(3)]],
    constant uint& depth [[buffer(4)]],
    constant ulong& seed [[buffer(5)]],
    uint tid [[thread_position_in_grid]]) {
    uint key = keys[tid];
    float acc = 0.0f;
    for (uint row = 0; row < depth; ++row) {
        ulong h = mix64(seed ^ ulong(key) ^ (ulong(row) * 0x9e3779b97f4a7c15UL));
        uint bucket = uint(h % ulong(width));
        float sign = ((h >> 63) == 0) ? 1.0f : -1.0f;
        acc += sign * buckets[row * width + bucket];
    }
    out[tid] = acc / float(depth);
}
