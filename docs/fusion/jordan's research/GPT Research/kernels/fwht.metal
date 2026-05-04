#include <metal_stdlib>
using namespace metal;

kernel void fwht_inplace(
    device float* values [[buffer(0)]],
    constant uint& n [[buffer(1)]],
    uint tid [[thread_position_in_grid]]) {
    if (tid != 0) { return; }
    for (uint h = 1; h < n; h <<= 1) {
        for (uint i = 0; i < n; i += (h << 1)) {
            for (uint j = i; j < i + h; ++j) {
                float x = values[j];
                float y = values[j + h];
                values[j] = x + y;
                values[j + h] = x - y;
            }
        }
    }
}

kernel void randomized_fwht(
    device const float* input [[buffer(0)]],
    device float* output [[buffer(1)]],
    device const int* signs [[buffer(2)]],
    device const uint* permutation [[buffer(3)]],
    constant uint& n [[buffer(4)]],
    uint tid [[thread_position_in_grid]]) {
    if (tid != 0) { return; }
    for (uint i = 0; i < n; ++i) { output[i] = float(signs[i]) * input[permutation[i]]; }
    for (uint h = 1; h < n; h <<= 1) {
        for (uint i = 0; i < n; i += (h << 1)) {
            for (uint j = i; j < i + h; ++j) {
                float x = output[j];
                float y = output[j + h];
                output[j] = x + y;
                output[j + h] = x - y;
            }
        }
    }
    float inv = rsqrt(float(n));
    for (uint i = 0; i < n; ++i) { output[i] *= inv; }
}
