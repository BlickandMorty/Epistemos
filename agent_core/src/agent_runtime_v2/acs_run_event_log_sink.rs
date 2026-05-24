//! ACS (Anchored Cognitive Substrate / Autopoietic Cognitive Stack)
//! RunEventLog adapter for v2 tool admission.
//!
//! The implementation lives in `crate::acs_admission` because the sink
//! is part of the ACS admission substrate. This module gives T11/v2
//! callers the canonical runtime path without duplicating the write
//! semantics.

pub use crate::acs_admission::ACSRunEventLogSink;
