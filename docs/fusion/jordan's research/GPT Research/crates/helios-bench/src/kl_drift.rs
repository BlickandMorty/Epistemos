//! Per-token KL drift measurement.

use helios_tensor::kl_from_logits;

#[derive(Clone, Debug, PartialEq)]
pub struct DriftSample {
    pub token_id: u64,
    pub exact_logits: Vec<f32>,
    pub candidate_logits: Vec<f32>,
}

#[must_use]
pub fn kl_from_logits_pair(sample: &DriftSample) -> f32 {
    kl_from_logits(&sample.exact_logits, &sample.candidate_logits)
}
