#include <metal_stdlib>
using namespace metal;

// ============================================================================
// count_sketch_update.metal
// Streaming Count-Min / Count-Sketch update kernel.
//
// Used for L2 memory tier: compact approximate histograms over token keys.
// Each thread handles one index update.
//
// Hash function (pairwise independent):
//   h_j(index) = ((a_j * index + b_j) % p) % W
// where p = 2^31 - 1 (Mersenne prime).
//
// Sign hash:
//   g_j(index) = +1 if ((c_j * index + d_j) % p) & 1 == 0 else -1
//
// Atomic add to shared sketch buffer:
//   sketch[j, h_j(index)] += sign * value
//
// Parameters packed in ulong4 hash_params:
//   x = a_0, y = b_0, z = c_0, w = d_0 for single hash (d repetitions use seed).
// ============================================================================

// Mersenne prime p = 2^31 - 1
constant uint P = 0x7FFFFFFF;

inline uint hash_mersenne(uint a, uint b, uint index) {
    // (a * index + b) % p  using 64-bit intermediate to avoid overflow
    ulong prod = (ulong)a * (ulong)index + (ulong)b;
    // Fast mod by Mersenne prime: x % p where p = 2^31 - 1
    // x = hi * 2^31 + lo = hi * (p + 1) + lo = hi * p + hi + lo
    // => x % p = (hi + lo) % p
    uint hi = (uint)(prod >> 31);
    uint lo = (uint)(prod & P);
    uint sum = hi + lo;
    return (sum >= P) ? (sum - P) : sum;
}

inline int hash_sign(uint c, uint d, uint index) {
    uint h = hash_mersenne(c, d, index);
    return ((h & 1u) == 0u) ? 1 : -1;
}

kernel void count_sketch_update(
    device atomic_float* sketch,        // [d, w] sketch table (row-major)
    device const half*   values,        // [n] values to insert
    device const uint*   indices,       // [n] indices to hash
    constant     uint&   n,             // number of updates
    constant     uint&   w,             // sketch width
    constant     uint&   d,             // sketch depth (hash repetitions)
    constant     ulong4& hash_params,   // (a, b, c, d) base hash seeds
    uint gid [[thread_position_in_grid]])
{
    if (gid >= n) return;

    float val = float(values[gid]);
    uint  idx = indices[gid];

    // Derive per-depth hash seeds deterministically from base params
    uint a_base = (uint)(hash_params.x & 0xFFFFFFFF);
    uint b_base = (uint)(hash_params.y & 0xFFFFFFFF);
    uint c_base = (uint)(hash_params.z & 0xFFFFFFFF);
    uint d_base = (uint)(hash_params.w & 0xFFFFFFFF);

    for (uint depth = 0; depth < d; depth++) {
        // Perturb seeds per depth using small prime increments
        uint a = a_base + depth * 2654435761u;
        uint b = b_base + depth * 2246822519u;
        uint c = c_base + depth * 3266489917u;
        uint dd = d_base + depth * 668265263u;

        uint h = hash_mersenne(a, b, idx);
        uint bucket = h % w;
        int  sign   = hash_sign(c, dd, idx);

        uint flat_idx = depth * w + bucket;
        float addend = val * float(sign);
        atomic_fetch_add_explicit(&sketch[flat_idx], addend, memory_order_relaxed);
    }
}
