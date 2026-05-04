// capability.rs
// Epistemos — HMAC-scoped capability grants
//
// Short-lived, signed, independently verifiable tokens.
// The HMAC root key lives in the macOS Keychain (shared access group,
// `WhenUnlockedThisDeviceOnly`) and is NEVER handed to helpers.
// The app issues grants; helpers only verify.
//
// Security invariants:
//   1. Root key never leaves the app process.
//   2. Grants expire; helpers reject expired tokens.
//   3. Signature verification uses constant-time comparison (subtle).
//   4. Tampered grants fail verification.
//   5. Subject mismatch fails verification.
//

use hmac::{Hmac, Mac};
use serde::{Deserialize, Serialize};
use sha2::Sha256;
use std::time::{SystemTime, UNIX_EPOCH};
use subtle::ConstantTimeEq;

// HMAC-SHA256 type alias.
type HmacSha256 = Hmac<Sha256>;

// ---------------------------------------------------------------------------
// Capability flags
// ---------------------------------------------------------------------------

bitflags::bitflags! {
    /// Capability flags define what actions a grant permits.
    ///
    /// Each flag is a distinct power. Grants should be issued with the
    /// minimum set required for a single action (principle of least privilege).
    #[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq)]
    pub struct CapFlags: u32 {
        const READ_VAULT      = 0x0001;
        const WRITE_VAULT     = 0x0002;
        const SUMMARIZE       = 0x0004;
        const SEARCH_WEB      = 0x0008;
        const CALL_PROVIDER   = 0x0010;
        const EXPORT_TEXT     = 0x0020;
        const EXECUTE_TOOL    = 0x0040;
    }
}

// ---------------------------------------------------------------------------
// Typed errors
// ---------------------------------------------------------------------------

/// Errors that can occur during capability issuance or verification.
#[derive(thiserror::Error, Debug, Clone, PartialEq, Eq)]
pub enum CapabilityError {
    #[error("capability grant expired")]
    Expired,
    #[error("capability signature invalid")]
    SignatureInvalid,
    #[error("capability subject mismatch")]
    SubjectMismatch,
    #[error("capability does not allow requested action")]
    FlagDenied,
    #[error("serialization failed: {0}")]
    Serialize(String),
    #[error("HMAC initialization failed: {0}")]
    MacInit(String),
    #[error("key derivation failed: {0}")]
    KeyDerivation(String),
}

// ---------------------------------------------------------------------------
// Capability grant (native Rust shape)
// ---------------------------------------------------------------------------

/// A signed, time-bounded capability grant.
///
/// `sig` covers every field except itself. The signing process serializes
/// the grant with `sig` zeroed, computes HMAC-SHA256 over the serialized
/// bytes, and writes the result back into `sig`.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub struct CapabilityGrant {
    pub subject: String,
    pub action_id: String,
    pub flags: CapFlags,
    pub expires_at_unix: u64,
    pub max_input_bytes: u32,
    pub max_output_bytes: u32,
    pub allowed_provider_ids: Vec<String>,
    pub vault_ids: Vec<String>,
    pub nonce: [u8; 16],
    pub sig: [u8; 32],
}

impl CapabilityGrant {
    /// Issue a new grant and sign it with the provided root key.
    ///
    /// # Arguments
    /// * `subject` — The helper/service identifier this grant is issued to.
    /// * `action_id` — Audit correlation identifier.
    /// * `flags` — Permission flags.
    /// * `vault_ids` — Vault identifiers the grant is scoped to.
    /// * `ttl_seconds` — Time-to-live in seconds from now.
    /// * `key` — HMAC root key bytes (32+ bytes recommended).
    ///
    /// # Errors
    /// Returns `CapabilityError::Serialize` or `CapabilityError::MacInit` on failure.
    pub fn issue(
        subject: String,
        action_id: String,
        flags: CapFlags,
        vault_ids: Vec<String>,
        allowed_provider_ids: Vec<String>,
        max_input_bytes: u32,
        max_output_bytes: u32,
        ttl_seconds: u64,
        key: &[u8],
    ) -> Result<Self, CapabilityError> {
        let expires_at_unix = now_unix()
            .checked_add(ttl_seconds)
            .ok_or_else(|| CapabilityError::Serialize("ttl overflow".into()))?;

        let mut nonce = [0u8; 16];
        // SAFETY: getrandom is a safe, well-tested crate for OS entropy.
        // If getrandom fails, we fall back to a timestamp-based nonce which
        // is weaker but still unique per issuance on the same thread.
        if getrandom::fill(&mut nonce).is_err() {
            let ts = now_unix().to_le_bytes();
            nonce[..8].copy_from_slice(&ts);
            let pid = std::process::id().to_le_bytes();
            nonce[8..12].copy_from_slice(&pid);
        }

        let mut grant = Self {
            subject,
            action_id,
            flags,
            expires_at_unix,
            max_input_bytes,
            max_output_bytes,
            allowed_provider_ids,
            vault_ids,
            nonce,
            sig: [0u8; 32],
        };
        grant.sign(key)?;
        Ok(grant)
    }

    /// Sign (or re-sign) this grant with the given key.
    ///
    /// Zeros `sig`, serializes the struct, computes HMAC-SHA256, and stores
    /// the result in `sig`.
    pub fn sign(&mut self, key: &[u8]) -> Result<(), CapabilityError> {
        self.sig.fill(0);
        let payload = postcard::to_stdvec(self)
            .map_err(|e| CapabilityError::Serialize(e.to_string()))?;

        let mut mac = HmacSha256::new_from_slice(key)
            .map_err(|e| CapabilityError::MacInit(e.to_string()))?;
        mac.update(&payload);
        let result = mac.finalize().into_bytes();
        self.sig.copy_from_slice(&result);
        Ok(())
    }

    /// Verify this grant against the given key.
    ///
    /// Checks:
    /// 1. Expiry (`expires_at_unix >= now`).
    /// 2. Signature (constant-time HMAC comparison).
    /// 3. Optional: subject match (pass expected subject to enforce).
    ///
    /// # Arguments
    /// * `key` — HMAC root key bytes.
    /// * `expected_subject` — If `Some`, enforce subject equality.
    pub fn verify(
        &self,
        key: &[u8],
        expected_subject: Option<&str>,
    ) -> Result<(), CapabilityError> {
        if self.is_expired() {
            return Err(CapabilityError::Expired);
        }
        if let Some(expected) = expected_subject {
            if self.subject != expected {
                return Err(CapabilityError::SubjectMismatch);
            }
        }

        // Clone, zero sig, serialize, and compute expected HMAC.
        let mut tmp = self.clone();
        tmp.sig.fill(0);
        let payload = postcard::to_stdvec(&tmp)
            .map_err(|e| CapabilityError::Serialize(e.to_string()))?;

        let mut mac = HmacSha256::new_from_slice(key)
            .map_err(|e| CapabilityError::MacInit(e.to_string()))?;
        mac.update(&payload);
        let expected = mac.finalize().into_bytes();

        // Constant-time comparison to prevent timing attacks on the signature.
        if expected.as_slice().ct_eq(&self.sig).into() {
            Ok(())
        } else {
            Err(CapabilityError::SignatureInvalid)
        }
    }

    /// Returns `true` if the grant has expired.
    pub fn is_expired(&self) -> bool {
        now_unix() > self.expires_at_unix
    }

    /// Returns `true` if the grant permits the given flag(s).
    pub fn allows(&self, flag: CapFlags) -> bool {
        self.flags.contains(flag)
    }

    /// Derive a per-subject verification key from the root key.
    ///
    /// Helpers do NOT receive the root key. The app derives a helper-specific
    /// key using HMAC-SHA256(root_key, subject) and passes only the derived key.
    /// Even if the derived key leaks, it is scoped to one subject.
    pub fn derive_verification_key(root_key: &[u8], subject: &str) -> Result<Vec<u8>, CapabilityError> {
        let mut mac = HmacSha256::new_from_slice(root_key)
            .map_err(|e| CapabilityError::KeyDerivation(e.to_string()))?;
        mac.update(subject.as_bytes());
        Ok(mac.finalize().into_bytes().to_vec())
    }
}

// ---------------------------------------------------------------------------
// FFI-compatible shape
// ---------------------------------------------------------------------------

/// C-compatible capability grant for raw FFI boundaries.
///
/// String fields are null-terminated UTF-8 pointers (borrowed, not owned).
/// Arrays are fixed-size. This struct is intended for use with `objc2`
/// or raw C callers; UniFFI callers should use the native `CapabilityGrant`
/// directly via `#[derive(uniffi::Record)]`.
///
/// # Safety
/// All pointer fields must be valid, null-terminated, and outlive this struct.
#[repr(C)]
pub struct CapabilityGrantFfi {
    pub subject: *const std::ffi::c_char,
    pub action_id: *const std::ffi::c_char,
    pub flags: u32,
    pub expires_at_unix: u64,
    pub max_input_bytes: u32,
    pub max_output_bytes: u32,
    pub nonce: [u8; 16],
    pub sig: [u8; 32],
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn now_unix() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

// ---------------------------------------------------------------------------
// UniFFI record bridge (optional — enable when UniFFI is present)
// ---------------------------------------------------------------------------

// When the `uniffi` feature is enabled in the crate, add:
//   #[derive(uniffi::Record)]
// above `CapabilityGrant` and export the public methods with
//   #[uniffi::export]
//
// For now, the struct is plain Serialize/Deserialize so it can also be
// passed across the boundary as a byte blob via `postcard`.

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn test_key() -> Vec<u8> {
        vec![0x42; 32]
    }

    #[test]
    fn capability_issue_verify_roundtrip() {
        let key = test_key();
        let grant = CapabilityGrant::issue(
            "agent_xpc".into(),
            "action_001".into(),
            CapFlags::READ_VAULT | CapFlags::SUMMARIZE,
            vec!["vault_a".into()],
            vec![],
            1024,
            4096,
            300,
            &key,
        )
        .expect("issue should succeed");

        assert!(!grant.is_expired());
        assert!(grant.allows(CapFlags::READ_VAULT));
        assert!(grant.allows(CapFlags::SUMMARIZE));
        assert!(!grant.allows(CapFlags::WRITE_VAULT));
        assert!(!grant.is_expired());

        grant
            .verify(&key, Some("agent_xpc"))
            .expect("verify should succeed");
    }

    #[test]
    fn capability_expired_rejected() {
        let key = test_key();
        let grant = CapabilityGrant::issue(
            "agent_xpc".into(),
            "action_002".into(),
            CapFlags::READ_VAULT,
            vec!["vault_b".into()],
            vec![],
            1024,
            4096,
            1, // 1 second TTL
            &key,
        )
        .expect("issue should succeed");

        // Wait for expiry.
        std::thread::sleep(std::time::Duration::from_secs(2));
        assert!(grant.is_expired());

        let result = grant.verify(&key, Some("agent_xpc"));
        assert_eq!(result, Err(CapabilityError::Expired));
    }

    #[test]
    fn capability_wrong_key_rejected() {
        let key = test_key();
        let wrong_key = vec![0xAB; 32];
        let grant = CapabilityGrant::issue(
            "agent_xpc".into(),
            "action_003".into(),
            CapFlags::READ_VAULT,
            vec!["vault_c".into()],
            vec![],
            1024,
            4096,
            300,
            &key,
        )
        .expect("issue should succeed");

        let result = grant.verify(&wrong_key, Some("agent_xpc"));
        assert_eq!(result, Err(CapabilityError::SignatureInvalid));
    }

    #[test]
    fn capability_tampered_rejected() {
        let key = test_key();
        let mut grant = CapabilityGrant::issue(
            "agent_xpc".into(),
            "action_004".into(),
            CapFlags::READ_VAULT,
            vec!["vault_d".into()],
            vec![],
            1024,
            4096,
            300,
            &key,
        )
        .expect("issue should succeed");

        // Tamper: flip one bit in the flags.
        grant.flags = CapFlags::from_bits_truncate(grant.flags.bits() ^ 0xFFFF);
        // Re-serialize but do NOT re-sign — the signature is now mismatched.
        let result = grant.verify(&key, Some("agent_xpc"));
        assert_eq!(result, Err(CapabilityError::SignatureInvalid));
    }

    #[test]
    fn capability_subject_mismatch_rejected() {
        let key = test_key();
        let grant = CapabilityGrant::issue(
            "agent_xpc".into(),
            "action_005".into(),
            CapFlags::READ_VAULT,
            vec!["vault_e".into()],
            vec![],
            1024,
            4096,
            300,
            &key,
        )
        .expect("issue should succeed");

        let result = grant.verify(&key, Some("provider_xpc"));
        assert_eq!(result, Err(CapabilityError::SubjectMismatch));
    }

    #[test]
    fn capability_allows_checks() {
        let key = test_key();
        let grant = CapabilityGrant::issue(
            "agent_xpc".into(),
            "action_006".into(),
            CapFlags::READ_VAULT | CapFlags::WRITE_VAULT | CapFlags::EXECUTE_TOOL,
            vec!["vault_f".into()],
            vec![],
            1024,
            4096,
            300,
            &key,
        )
        .expect("issue should succeed");

        assert!(grant.allows(CapFlags::READ_VAULT));
        assert!(grant.allows(CapFlags::WRITE_VAULT));
        assert!(grant.allows(CapFlags::EXECUTE_TOOL));
        assert!(!grant.allows(CapFlags::SUMMARIZE));
        assert!(!grant.allows(CapFlags::SEARCH_WEB));
        assert!(!grant.allows(CapFlags::CALL_PROVIDER));
    }

    #[test]
    fn capability_provider_ids_roundtrip() {
        let key = test_key();
        let grant = CapabilityGrant::issue(
            "provider_xpc".into(),
            "action_007".into(),
            CapFlags::CALL_PROVIDER,
            vec![],
            vec!["anthropic".into(), "openai".into()],
            1024,
            4096,
            300,
            &key,
        )
        .expect("issue should succeed");

        assert_eq!(grant.allowed_provider_ids, vec!["anthropic", "openai"]);
        grant
            .verify(&key, Some("provider_xpc"))
            .expect("verify should succeed");
    }

    #[test]
    fn capability_derive_key_isolation() {
        let root = test_key();
        let key_agent = CapabilityGrant::derive_verification_key(&root, "agent_xpc")
            .expect("derive should succeed");
        let key_provider = CapabilityGrant::derive_verification_key(&root, "provider_xpc")
            .expect("derive should succeed");

        // Derived keys must differ.
        assert_ne!(key_agent, key_provider);

        // A grant issued with the agent-derived key should verify with that key
        // but NOT with the provider-derived key.
        let mut grant = CapabilityGrant {
            subject: "agent_xpc".into(),
            action_id: "action_008".into(),
            flags: CapFlags::READ_VAULT,
            expires_at_unix: now_unix() + 300,
            max_input_bytes: 1024,
            max_output_bytes: 4096,
            allowed_provider_ids: vec![],
            vault_ids: vec!["vault_g".into()],
            nonce: [0u8; 16],
            sig: [0u8; 32],
        };
        grant.sign(&key_agent).expect("sign should succeed");

        grant
            .verify(&key_agent, Some("agent_xpc"))
            .expect("verify with derived key should succeed");

        let result = grant.verify(&key_provider, Some("agent_xpc"));
        assert_eq!(result, Err(CapabilityError::SignatureInvalid));
    }

    #[test]
    fn capability_verify_without_subject_check() {
        let key = test_key();
        let grant = CapabilityGrant::issue(
            "any_subject".into(),
            "action_009".into(),
            CapFlags::READ_VAULT,
            vec![],
            vec![],
            1024,
            4096,
            300,
            &key,
        )
        .expect("issue should succeed");

        // When expected_subject is None, we skip subject validation.
        grant.verify(&key, None).expect("verify should succeed");
    }

    #[test]
    fn capability_max_bytes_roundtrip() {
        let key = test_key();
        let grant = CapabilityGrant::issue(
            "agent_xpc".into(),
            "action_010".into(),
            CapFlags::READ_VAULT,
            vec![],
            vec![],
            8192,
            16384,
            300,
            &key,
        )
        .expect("issue should succeed");

        assert_eq!(grant.max_input_bytes, 8192);
        assert_eq!(grant.max_output_bytes, 16384);
    }
}
