// direct_conv.metal — Depthwise 1D convolution for Mamba-2
//
// Mamba-2 uses a short depthwise convolution (d_conv=4) before the SSM layer.
// This is a 4-tap FIR filter — FFT is wasteful for this kernel size.
// Direct sliding-window convolution: 4 multiply-accumulate ops per output.
//
// The convolution is causal (only past tokens contribute) and depthwise
// (each channel is convolved independently with its own 4-tap kernel).
//
// Weights are stored in constant memory for fastest access on Apple Silicon.

#include <metal_stdlib>
using namespace metal;

// ---------------------------------------------------------------------------
// Direct Causal Depthwise Conv1D (d_conv = 4)
// ---------------------------------------------------------------------------

/// Apply causal depthwise 1D convolution with kernel size 4.
/// Each channel is independently convolved: y[t,d] = sum(w[k] * x[t-k, d])
///
/// Input:  x — (B, L, D) input activations
/// Weights: w — (D, d_conv) convolution kernels per channel
/// Output: y — (B, L, D) convolved output
///
/// Grid: (D, L, B) — one thread per (channel, position, batch)
kernel void depthwise_conv1d_k4(
    device const half *x           [[buffer(0)]],  // (B, L, D) input
    device const half *w           [[buffer(1)]],  // (D, 4) weights
    device half       *y           [[buffer(2)]],  // (B, L, D) output
    constant uint     &batch_size  [[buffer(3)]],
    constant uint     &seq_len     [[buffer(4)]],
    constant uint     &d_model     [[buffer(5)]],
    uint3 gid [[thread_position_in_grid]]
)
{
    uint d     = gid.x;  // channel
    uint t     = gid.y;  // time position
    uint batch = gid.z;  // batch

    if (d >= d_model || t >= seq_len || batch >= batch_size) return;

    // Load weights for this channel (constant-like access pattern)
    float w0 = float(w[d * 4 + 0]);
    float w1 = float(w[d * 4 + 1]);
    float w2 = float(w[d * 4 + 2]);
    float w3 = float(w[d * 4 + 3]);

    // Base offset for this batch
    uint base = batch * seq_len * d_model;

    // Causal convolution: only access t, t-1, t-2, t-3
    float acc = w0 * float(x[base + t * d_model + d]);

    if (t >= 1) {
        acc += w1 * float(x[base + (t - 1) * d_model + d]);
    }
    if (t >= 2) {
        acc += w2 * float(x[base + (t - 2) * d_model + d]);
    }
    if (t >= 3) {
        acc += w3 * float(x[base + (t - 3) * d_model + d]);
    }

    y[base + t * d_model + d] = half(acc);
}

// ---------------------------------------------------------------------------
// Fused Conv + SiLU (common Mamba-2 pattern)
// ---------------------------------------------------------------------------

/// Depthwise conv1d followed by SiLU activation in a single pass.
/// Eliminates an intermediate buffer write for the activation.
kernel void depthwise_conv1d_k4_silu(
    device const half *x           [[buffer(0)]],  // (B, L, D)
    device const half *w           [[buffer(1)]],  // (D, 4)
    device half       *y           [[buffer(2)]],  // (B, L, D)
    constant uint     &batch_size  [[buffer(3)]],
    constant uint     &seq_len     [[buffer(4)]],
    constant uint     &d_model     [[buffer(5)]],
    uint3 gid [[thread_position_in_grid]]
)
{
    uint d     = gid.x;
    uint t     = gid.y;
    uint batch = gid.z;

    if (d >= d_model || t >= seq_len || batch >= batch_size) return;

    float w0 = float(w[d * 4 + 0]);
    float w1 = float(w[d * 4 + 1]);
    float w2 = float(w[d * 4 + 2]);
    float w3 = float(w[d * 4 + 3]);

    uint base = batch * seq_len * d_model;

    float acc = w0 * float(x[base + t * d_model + d]);
    if (t >= 1) acc += w1 * float(x[base + (t - 1) * d_model + d]);
    if (t >= 2) acc += w2 * float(x[base + (t - 2) * d_model + d]);
    if (t >= 3) acc += w3 * float(x[base + (t - 3) * d_model + d]);

    // SiLU activation: silu(x) = x * sigmoid(x)
    float sigmoid_acc = 1.0f / (1.0f + exp(-acc));
    y[base + t * d_model + d] = half(acc * sigmoid_acc);
}

// ---------------------------------------------------------------------------
// Autoregressive Conv State Update (decode phase)
// ---------------------------------------------------------------------------

/// During autoregressive decode, maintain a sliding window buffer of the
/// last (d_conv - 1) = 3 tokens per channel. Each new token shifts the
/// window and applies the convolution.
///
/// conv_state: (B, D, d_conv-1) — rolling buffer of previous tokens
/// x_new: (B, 1, D) — new token embedding
/// w: (D, d_conv) — conv weights
/// y: (B, 1, D) — convolution output for new token
kernel void conv1d_step(
    device half       *conv_state  [[buffer(0)]],  // (B, D, 3) — updated in place
    device const half *x_new       [[buffer(1)]],  // (B, D) — new token
    device const half *w           [[buffer(2)]],  // (D, 4) — weights
    device half       *y           [[buffer(3)]],  // (B, D) — output
    constant uint     &batch_size  [[buffer(4)]],
    constant uint     &d_model     [[buffer(5)]],
    uint2 gid [[thread_position_in_grid]]  // (d, batch)
)
{
    uint d     = gid.x;
    uint batch = gid.y;

    if (d >= d_model || batch >= batch_size) return;

    uint state_base = batch * d_model * 3 + d * 3;

    // Load conv state: [t-3, t-2, t-1]
    float s0 = float(conv_state[state_base + 0]);  // oldest (t-3)
    float s1 = float(conv_state[state_base + 1]);  // t-2
    float s2 = float(conv_state[state_base + 2]);  // t-1
    float x  = float(x_new[batch * d_model + d]);  // t (new)

    // Conv weights
    float w0 = float(w[d * 4 + 0]);  // weight for current token
    float w1 = float(w[d * 4 + 1]);  // weight for t-1
    float w2 = float(w[d * 4 + 2]);  // weight for t-2
    float w3 = float(w[d * 4 + 3]);  // weight for t-3

    // Convolution
    float out = w0 * x + w1 * s2 + w2 * s1 + w3 * s0;
    y[batch * d_model + d] = half(out);

    // Shift state: drop oldest, add new
    conv_state[state_base + 0] = half(s1);  // was t-2, now t-3
    conv_state[state_base + 1] = half(s2);  // was t-1, now t-2
    conv_state[state_base + 2] = half(x);   // current, now t-1
}
