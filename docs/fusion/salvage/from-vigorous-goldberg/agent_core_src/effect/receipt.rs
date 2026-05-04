//! Per FINAL_SYNTHESIS §5.5 — proof-of-execution receipts.
//!
//! Every applied Effect's RunEventLog row is signed so that "the
//! user can verify any past execution: did the agent really do
//! exactly this?" Tampering with the log invalidates the chain.
//!
//! Canonical ExecutionReceipt shape per FINAL_SYNTHESIS §5.5:
//!
//! ```rust,ignore
//! pub struct ExecutionReceipt {
//!     pub call_id: Ulid,
//!     pub plan_hash: [u8; 32],
//!     pub tool: String,
//!     pub input_hash: [u8; 32],
//!     pub output_hash: [u8; 32],
//!     pub timestamp: SystemTime,
//!     pub capabilities_used: Vec<Capability>,
//!     pub signature: [u8; 64],    // Ed25519 sig
//! }
//! ```
//!
//! This module ships the canonical struct + a `SigningKey` trait so
//! callers can plug in the per-vault Keychain key. The default
//! `HmacSha256SigningKey` is a structural placeholder — it produces
//! cryptographically real signatures that can be verified against
//! the same key, but the §5.5 canon mandates Ed25519 for the
//! production path. The `SigningKey` trait surface lets a future
//! `Ed25519SigningKey` impl land without changing any callers.
//!
//! Verification chain: `verify()` recomputes the canonical canonical
//! signing payload from the receipt fields and asks the key to
//! check the signature. Any field tampering breaks the signature.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

/// One capability exercised by a tool call (file-system path, network
/// host, biometric session, …). Per FINAL_SYNTHESIS §5.2 ephemeral
/// capability tokens — the receipt records exactly which capabilities
/// were authorized for THIS call.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
#[serde(tag = "kind", content = "value", rename_all = "snake_case")]
pub enum Capability {
    /// e.g. `vault://notes/a.md`, with optional verb (read/write/delete).
    VaultPath { path: String, verb: String },
    /// `localhost:port` or external host.
    NetworkHost { host: String },
    /// `secure_enclave://session/<ttl>`.
    BiometricSession { ttl_secs: u32 },
    /// Catch-all for capability strings that don't fit a typed variant
    /// yet. The schema can grow without breaking old receipts.
    Other { name: String },
}

/// Canonical ExecutionReceipt per FINAL_SYNTHESIS §5.5.
///
/// Stored alongside each RunEventLog row (heal_events.sqlite,
/// undo_events.sqlite, action_trace.sqlite). Tamper-evident: changing
/// any field invalidates the signature.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct ExecutionReceipt {
    /// Per-call ULID.
    pub call_id: String,
    /// Hash of the LivePlan (Wave 7) the call ran under, or the
    /// route_capture decision hash for Wave 0–5.
    pub plan_hash: String,
    /// Canonical dotted tool name (`vault.write`, `reason.think`, …).
    pub tool: String,
    /// SHA-256 of the canonical-JSON serialization of the Intent
    /// input. Locks the receipt to the exact input.
    pub input_hash: String,
    /// SHA-256 of the canonical-JSON serialization of the resulting
    /// Effect (or the ApplyError when failed).
    pub output_hash: String,
    /// RFC3339.
    pub timestamp: DateTime<Utc>,
    pub capabilities_used: Vec<Capability>,
    /// Hex-encoded signature bytes. Width is 64 bytes for Ed25519
    /// (canon target) or 32 bytes for the HmacSha256 placeholder.
    pub signature: String,
}

impl ExecutionReceipt {
    /// Build a receipt + sign it with the supplied key.
    pub fn sign<K: SigningKey>(
        call_id: impl Into<String>,
        plan_hash: impl Into<String>,
        tool: impl Into<String>,
        input_bytes: &[u8],
        output_bytes: &[u8],
        capabilities_used: Vec<Capability>,
        key: &K,
    ) -> Self {
        let input_hash = hex_sha256(input_bytes);
        let output_hash = hex_sha256(output_bytes);
        let timestamp = Utc::now();
        let mut receipt = Self {
            call_id: call_id.into(),
            plan_hash: plan_hash.into(),
            tool: tool.into(),
            input_hash,
            output_hash,
            timestamp,
            capabilities_used,
            signature: String::new(),
        };
        let payload = receipt.canonical_signing_payload();
        receipt.signature = hex_encode(&key.sign(&payload));
        receipt
    }

    /// Verify the signature against `key`. Recomputes the canonical
    /// payload and asks the key to check. Returns `false` on any
    /// mismatch — tampered field, mismatched key, malformed sig.
    pub fn verify<K: SigningKey>(&self, key: &K) -> bool {
        let payload = self.canonical_signing_payload();
        match hex_decode(&self.signature) {
            Some(sig_bytes) => key.verify(&payload, &sig_bytes),
            None => false,
        }
    }

    /// Canonical bytes that go into the signature. Order-stable +
    /// length-prefixed so a future variant can extend without
    /// invalidating old receipts.
    fn canonical_signing_payload(&self) -> Vec<u8> {
        let mut buf = Vec::with_capacity(256);
        write_field(&mut buf, b"call_id", self.call_id.as_bytes());
        write_field(&mut buf, b"plan_hash", self.plan_hash.as_bytes());
        write_field(&mut buf, b"tool", self.tool.as_bytes());
        write_field(&mut buf, b"input_hash", self.input_hash.as_bytes());
        write_field(&mut buf, b"output_hash", self.output_hash.as_bytes());
        let ts = self.timestamp.to_rfc3339();
        write_field(&mut buf, b"timestamp", ts.as_bytes());
        for (i, cap) in self.capabilities_used.iter().enumerate() {
            let key_str = format!("cap_{i}");
            // Caps go through serde_json so the canonical bytes are
            // identical to what's in the row. Fail-soft on serialize
            // error: the cap is treated as empty bytes (which is
            // distinct from "absent" because the field name is
            // length-prefixed).
            let cap_bytes = serde_json::to_vec(cap).unwrap_or_default();
            write_field(&mut buf, key_str.as_bytes(), &cap_bytes);
        }
        buf
    }
}

fn write_field(buf: &mut Vec<u8>, name: &[u8], value: &[u8]) {
    buf.extend_from_slice(&(name.len() as u32).to_le_bytes());
    buf.extend_from_slice(name);
    buf.extend_from_slice(&(value.len() as u32).to_le_bytes());
    buf.extend_from_slice(value);
}

fn hex_sha256(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

/// Inline lowercase-hex encoder so we don't pull a new crate dep
/// just for the receipt module.
fn hex_encode(bytes: &[u8]) -> String {
    let mut out = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        out.push_str(&format!("{:02x}", b));
    }
    out
}

/// Inline hex decoder. Returns `None` on any non-hex char or odd
/// length so callers can treat malformed signatures as failed
/// verification (not a panic).
fn hex_decode(s: &str) -> Option<Vec<u8>> {
    if s.len() % 2 != 0 {
        return None;
    }
    let mut out = Vec::with_capacity(s.len() / 2);
    let bytes = s.as_bytes();
    for chunk in bytes.chunks(2) {
        let hi = hex_nybble(chunk[0])?;
        let lo = hex_nybble(chunk[1])?;
        out.push((hi << 4) | lo);
    }
    Some(out)
}

fn hex_nybble(b: u8) -> Option<u8> {
    match b {
        b'0'..=b'9' => Some(b - b'0'),
        b'a'..=b'f' => Some(b - b'a' + 10),
        b'A'..=b'F' => Some(b - b'A' + 10),
        _ => None,
    }
}

/// Per-vault signing key abstraction. Ed25519 lands here once the
/// keychain integration is wired (Wave 5 stabilize). For now the
/// HmacSha256 placeholder satisfies the §5.5 invariant "tampering
/// invalidates the chain" without pulling in a new crate dep.
pub trait SigningKey: Send + Sync {
    /// Produce a signature over the canonical payload bytes.
    fn sign(&self, payload: &[u8]) -> Vec<u8>;

    /// Verify a signature against the canonical payload bytes.
    /// Implementors must use constant-time equality where applicable.
    fn verify(&self, payload: &[u8], signature: &[u8]) -> bool;
}

/// HMAC-SHA256-based placeholder. Tamper-evident (any payload change
/// produces a different MAC) but cryptographically symmetric — anyone
/// holding the key can both sign and verify. Production must swap in
/// Ed25519 once the keychain integration lands.
///
/// Per FINAL_SYNTHESIS §5.5: the canonical algorithm is Ed25519 so the
/// public key can verify without exposing the signing key. This impl
/// is honest about being a placeholder so the audit trail surfaces
/// the gap rather than hiding it.
pub struct HmacSha256SigningKey {
    secret: [u8; 32],
}

impl HmacSha256SigningKey {
    /// Build from a 32-byte secret. Keychain integration will derive
    /// this from the per-vault key the user authorizes via Touch ID.
    pub fn new(secret: [u8; 32]) -> Self {
        Self { secret }
    }

    /// Test helper: deterministic key seeded from `b"epistemos-test"`.
    /// Production code MUST use `new()` with the keychain-derived
    /// secret.
    #[cfg(test)]
    pub fn new_test() -> Self {
        let mut h = Sha256::new();
        h.update(b"epistemos-test");
        let digest: [u8; 32] = h.finalize().into();
        Self::new(digest)
    }

    fn mac(&self, payload: &[u8]) -> [u8; 32] {
        // Standard HMAC-SHA256 inner / outer key derivation. We don't
        // pull in `hmac` crate to avoid a new dep — the construction
        // is short and well-known.
        const BLOCK: usize = 64;
        let mut k_pad = [0u8; BLOCK];
        // secret is 32 bytes ≤ block size, just zero-pad.
        k_pad[..32].copy_from_slice(&self.secret);
        let mut ipad = [0x36u8; BLOCK];
        let mut opad = [0x5cu8; BLOCK];
        for i in 0..BLOCK {
            ipad[i] ^= k_pad[i];
            opad[i] ^= k_pad[i];
        }
        let mut inner = Sha256::new();
        inner.update(ipad);
        inner.update(payload);
        let inner_hash = inner.finalize();
        let mut outer = Sha256::new();
        outer.update(opad);
        outer.update(inner_hash);
        outer.finalize().into()
    }
}

impl SigningKey for HmacSha256SigningKey {
    fn sign(&self, payload: &[u8]) -> Vec<u8> {
        self.mac(payload).to_vec()
    }

    fn verify(&self, payload: &[u8], signature: &[u8]) -> bool {
        let expected = self.mac(payload);
        // Constant-time equality: don't short-circuit on first byte.
        if signature.len() != expected.len() {
            return false;
        }
        let mut diff = 0u8;
        for i in 0..signature.len() {
            diff |= signature[i] ^ expected[i];
        }
        diff == 0
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sign_then_verify_round_trips() {
        let key = HmacSha256SigningKey::new_test();
        let receipt = ExecutionReceipt::sign(
            "01HX42KQM3R7N9PVK0X8Z3W5MQ",
            "sha256:plan-hash-deadbeef",
            "vault.write",
            b"intent-input-bytes",
            b"effect-output-bytes",
            vec![Capability::VaultPath {
                path: "notes/a.md".into(),
                verb: "write".into(),
            }],
            &key,
        );
        assert!(receipt.verify(&key));
    }

    #[test]
    fn tampering_with_input_hash_invalidates_signature() {
        let key = HmacSha256SigningKey::new_test();
        let mut receipt = ExecutionReceipt::sign(
            "id1",
            "plan",
            "vault.write",
            b"input",
            b"output",
            vec![],
            &key,
        );
        // Mutate the receipt without re-signing.
        receipt.input_hash = "tampered".to_string();
        assert!(!receipt.verify(&key), "tampered receipt must not verify");
    }

    #[test]
    fn tampering_with_tool_name_invalidates_signature() {
        let key = HmacSha256SigningKey::new_test();
        let mut receipt = ExecutionReceipt::sign(
            "id1", "plan", "vault.write", b"i", b"o", vec![], &key,
        );
        receipt.tool = "vault.delete".to_string();
        assert!(!receipt.verify(&key));
    }

    #[test]
    fn different_keys_do_not_verify() {
        let key_a = HmacSha256SigningKey::new_test();
        let key_b = HmacSha256SigningKey::new([0xFF; 32]);
        let receipt = ExecutionReceipt::sign(
            "id1", "plan", "vault.write", b"i", b"o", vec![], &key_a,
        );
        assert!(receipt.verify(&key_a));
        assert!(!receipt.verify(&key_b));
    }

    #[test]
    fn malformed_signature_hex_fails_verification_safely() {
        let key = HmacSha256SigningKey::new_test();
        let mut receipt = ExecutionReceipt::sign(
            "id1", "plan", "vault.write", b"i", b"o", vec![], &key,
        );
        receipt.signature = "not hex".to_string();
        assert!(!receipt.verify(&key));
    }

    #[test]
    fn capabilities_are_part_of_signed_payload() {
        let key = HmacSha256SigningKey::new_test();
        let receipt_a = ExecutionReceipt::sign(
            "id1", "plan", "vault.write", b"i", b"o",
            vec![Capability::VaultPath {
                path: "a.md".into(),
                verb: "write".into(),
            }],
            &key,
        );
        let receipt_b = ExecutionReceipt::sign(
            "id1", "plan", "vault.write", b"i", b"o",
            vec![Capability::VaultPath {
                path: "b.md".into(),
                verb: "write".into(),
            }],
            &key,
        );
        // Receipts share id/tool/input/output but DIFFER on capabilities;
        // signatures must not match.
        assert_ne!(receipt_a.signature, receipt_b.signature);
        // Both verify with their own canonical payload.
        assert!(receipt_a.verify(&key));
        assert!(receipt_b.verify(&key));
    }

    #[test]
    fn input_hash_is_sha256_hex() {
        let key = HmacSha256SigningKey::new_test();
        let receipt = ExecutionReceipt::sign(
            "id1", "plan", "vault.write", b"hello", b"world", vec![], &key,
        );
        // sha256("hello") = 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
        assert_eq!(
            receipt.input_hash,
            "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        );
        assert_eq!(
            receipt.output_hash,
            // sha256("world") = 486ea46224d1bb4fb680f34f7c9ad96a8f24ec88be73ea8e5a6c65260e9cb8a7
            "486ea46224d1bb4fb680f34f7c9ad96a8f24ec88be73ea8e5a6c65260e9cb8a7"
        );
    }

    #[test]
    fn hmac_sha256_signature_width_is_32_bytes() {
        let key = HmacSha256SigningKey::new_test();
        let receipt = ExecutionReceipt::sign(
            "id1", "plan", "vault.write", b"i", b"o", vec![], &key,
        );
        // Hex-encoded 32 bytes = 64 chars.
        assert_eq!(receipt.signature.len(), 64);
    }
}
