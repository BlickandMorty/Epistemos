//! Benchmark harness for KL drift, recall, and gate reports.

pub mod kl_drift;
pub mod recall;

pub use kl_drift::{kl_from_logits_pair, DriftSample};
pub use recall::{top_k_recall, RecallCase};
