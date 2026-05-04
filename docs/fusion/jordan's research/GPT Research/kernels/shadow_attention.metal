#include <metal_stdlib>
using namespace metal;

kernel void score_pages(
    device const char* query_i8 [[buffer(0)]],
    device const char* pages_i8 [[buffer(1)]],
    device int* scores [[buffer(2)]],
    constant uint& sketch_dim [[buffer(3)]],
    uint page_id [[thread_position_in_grid]]) {
    int acc = 0;
    uint base = page_id * sketch_dim;
    for (uint i = 0; i < sketch_dim; ++i) {
        acc += int(query_i8[i]) * int(pages_i8[base + i]);
    }
    scores[page_id] = acc;
}

kernel void select_top_k(
    device const int* scores [[buffer(0)]],
    device uint* indices [[buffer(1)]],
    constant uint& n_pages [[buffer(2)]],
    constant uint& k [[buffer(3)]],
    uint tid [[thread_position_in_grid]]) {
    if (tid != 0) { return; }
    for (uint i = 0; i < k; ++i) {
        int best = INT_MIN;
        uint best_idx = 0;
        for (uint j = 0; j < n_pages; ++j) {
            bool already = false;
            for (uint t = 0; t < i; ++t) { already = already || indices[t] == j; }
            if (!already && scores[j] > best) { best = scores[j]; best_idx = j; }
        }
        indices[i] = best_idx;
    }
}

kernel void escalation_check(
    device const float* uncertainty [[buffer(0)]],
    device uchar* tier_out [[buffer(1)]],
    constant uint& n [[buffer(2)]],
    uint tid [[thread_position_in_grid]]) {
    if (tid >= n) { return; }
    float u = uncertainty[tid];
    tier_out[tid] = (u < 0.05f) ? 2 : ((u < 0.20f) ? 1 : 0);
}
