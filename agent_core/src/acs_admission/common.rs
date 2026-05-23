//! Shared constants used across acs_admission submodules.
//!
//! Lifted from the original monolithic mod.rs as part of T18B decompose.

pub const ACS_AUDIT_RUN_EVENT_KEY: &str = "acs.audit.record";
pub(crate) const SCOPE_REX_ADMISSION_PROOF_DOMAIN: &[u8] =
    b"epistemos.acs.scope_rex_admission_proof.v1";
pub(crate) const CAPABILITY_SIGNATURE_BYTES: usize = 32;
pub(crate) const MUTATION_INTEGRITY_HASH_BYTES: usize = 32;
pub(crate) const MALFORMED_REQUEST_AUDIT_PREFIX: &str = "malformed_request";
pub(crate) const MALFORMED_POLICY_AUDIT_PREFIX: &str = "malformed_policy";
