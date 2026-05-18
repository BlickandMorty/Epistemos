// F-ULP-Oracle T12 kernels.
//
// Hardware pin: M2 Pro 14-inch 2023, 16 GB UMA, about 200 GB/s.
// Domain: closed [0.5, 2]. No clamps are applied in the kernels; callers
// own fixture validity and NaN/inf/subnormal hardening paths.

#include <metal_stdlib>
using namespace metal;

kernel void fulpExpFp16(
    device const half* x        [[buffer(0)]],
    device       half* out      [[buffer(1)]],
    constant     uint& count    [[buffer(2)]],
    uint               gid      [[thread_position_in_grid]]
) {
    if (gid >= count) return;
    out[gid] = half(exp(float(x[gid])));
}

kernel void fulpLnFp16(
    device const half* y        [[buffer(0)]],
    device       half* out      [[buffer(1)]],
    constant     uint& count    [[buffer(2)]],
    uint               gid      [[thread_position_in_grid]]
) {
    if (gid >= count) return;
    out[gid] = half(log(float(y[gid])));
}

kernel void fulpEmlFp16(
    device const half* x        [[buffer(0)]],
    device const half* y        [[buffer(1)]],
    device       half* out      [[buffer(2)]],
    constant     uint& count    [[buffer(3)]],
    uint               gid      [[thread_position_in_grid]]
) {
    if (gid >= count) return;
    out[gid] = half(exp(float(x[gid])) - log(float(y[gid])));
}
