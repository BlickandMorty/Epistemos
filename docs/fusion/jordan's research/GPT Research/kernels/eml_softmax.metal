#include <metal_stdlib>
using namespace metal;

inline float eml(float x, float y) {
    return exp(x) - log(max(y, 1.0e-12f));
}

kernel void eml_softmax_lse(
    device const float* logits [[buffer(0)]],
    device float* probs [[buffer(1)]],
    device float* lse_out [[buffer(2)]],
    constant uint& n [[buffer(3)]],
    uint tid [[thread_position_in_grid]]) {
    if (tid != 0) { return; }
    float max_v = -INFINITY;
    for (uint i = 0; i < n; ++i) { max_v = max(max_v, logits[i]); }
    float sum_v = 0.0f;
    for (uint i = 0; i < n; ++i) { sum_v += exp(logits[i] - max_v); }
    float lse = max_v + log(sum_v);
    for (uint i = 0; i < n; ++i) { probs[i] = exp(logits[i] - lse); }
    lse_out[0] = lse;
}

kernel void eml_cross_entropy(
    device const float* probs [[buffer(0)]],
    device const uint* target [[buffer(1)]],
    device float* out [[buffer(2)]],
    uint tid [[thread_position_in_grid]]) {
    if (tid == 0) { out[0] = -log(max(probs[target[0]], 1.0e-12f)); }
}

kernel void eml_kl_divergence(
    device const float* p [[buffer(0)]],
    device const float* q [[buffer(1)]],
    device float* out [[buffer(2)]],
    constant uint& n [[buffer(3)]],
    uint tid [[thread_position_in_grid]]) {
    if (tid != 0) { return; }
    float acc = 0.0f;
    for (uint i = 0; i < n; ++i) {
        float pp = max(p[i], 1.0e-12f);
        float qq = max(q[i], 1.0e-12f);
        acc += pp * log(pp / qq);
    }
    out[0] = acc;
}
