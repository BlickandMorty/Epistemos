#include <metal_stdlib>
using namespace metal;

// ============================================================================
// surprise_grad_step.metal
// Titans-MAC online surprise gradient kernel.
//
// Implements the fast-weight update from Titans-MAC:
//   W_fast += lr * surprise * outer(error, input)
// with momentum and decay.
//
// This kernel handles one (row, col) pair per thread, updating a single
// fast-weight element. The surprise scalar is precomputed and passed in.
//
// Fast weights are stored in row-major float (needs more precision than half).
//
// Algorithm per element W[i,j]:
//   grad = error[i] * input[j]
//   W[i,j] = decay * W[i,j] + lr * surprise * grad
//
// Inputs:
//   fast_weights: [out_dim, in_dim] mutable fast weight matrix
//   error:        [out_dim] gradient / error vector
//   input:        [in_dim] input vector
//   surprise:     [1] scalar surprise value (||grad||^2 or CE spike)
//
// Expected bottleneck: memory bandwidth (read-modify-write on weights).
// ============================================================================

kernel void surprise_grad_step(
    device       float* fast_weights,  // [out_dim, in_dim]
    device const half*  error,          // [out_dim]
    device const half*  input,          // [in_dim]
    device const float* surprise,        // [1]
    constant     uint&  in_dim,
    constant     uint&  out_dim,
    constant     float& lr,
    constant     float& decay,
    uint gid [[thread_position_in_grid]])
{
    const uint total = out_dim * in_dim;
    if (gid >= total) return;

    const uint row = gid / in_dim;
    const uint col = gid % in_dim;

    float e = float(error[row]);
    float x = float(input[col]);
    float s = surprise[0];

    // Compute outer product contribution
    float grad = e * x;
    float update = lr * s * grad;

    // Apply decay and accumulate
    uint idx = row * in_dim + col;
    float old_w = fast_weights[idx];
    float new_w = decay * old_w + update;
    fast_weights[idx] = new_w;
}
