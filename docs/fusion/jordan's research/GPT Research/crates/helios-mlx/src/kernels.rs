//! Metal shader source registry for MLX JIT integration.

/// EML softmax kernel source.
pub const EML_SOFTMAX: &str = include_str!("../../../kernels/eml_softmax.metal");
/// Shadow attention kernel source.
pub const SHADOW_ATTENTION: &str = include_str!("../../../kernels/shadow_attention.metal");
/// FWHT kernel source.
pub const FWHT: &str = include_str!("../../../kernels/fwht.metal");
/// Sherry decode kernel source.
pub const SHERRY_DECODE: &str = include_str!("../../../kernels/sherry_decode.metal");
/// CountSketch kernel source.
pub const COUNT_SKETCH: &str = include_str!("../../../kernels/count_sketch.metal");

/// Return all kernel names and sources for build-time validation.
#[must_use]
pub fn all_kernels() -> [(&'static str, &'static str); 5] {
    [
        ("eml_softmax", EML_SOFTMAX),
        ("shadow_attention", SHADOW_ATTENTION),
        ("fwht", FWHT),
        ("sherry_decode", SHERRY_DECODE),
        ("count_sketch", COUNT_SKETCH),
    ]
}
