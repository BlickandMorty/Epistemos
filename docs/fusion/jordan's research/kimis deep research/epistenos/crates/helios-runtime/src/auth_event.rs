//! OAuth token refresh audit event — sanitized for provenance logging.
//!
//! This module provides [`AuthTokenRefreshedEvent`], a structure purpose-built
//! for the OpLog/EventStore pipeline. It captures **metadata** about credential
//! refreshes without ever storing raw tokens, client secrets, or other
//! sensitive material.
//!
//! ## Sanitization invariants
//!
//! 1. No `access_token` field exists on this struct.
//! 2. No `refresh_token` field exists.
//! 3. `credential_id_hash` is computed from a stable identifier (not the token).
//! 4. `provider_id` is validated against an allow-list at construction time.
//!
//! ## Emitting from Swift
//!
//! The Swift side (`CloudProviderAuthService.swift`) calls
//! `refreshedCredentialIfNeeded()` and should emit this event on every
//! refresh attempt — success or failure — so the provenance log is complete.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use tracing::debug;

/// Sanitized OAuth credential refresh event.
///
/// **NO raw tokens. NO client secrets. ONLY metadata.**
///
/// This struct is deliberately minimal: every field is safe to log, store,
/// and forward across FFI boundaries. The sensitive credential material is
/// reduced to a stable BLAKE3 hash of the *credential identifier* (not the
/// token itself).
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct AuthTokenRefreshedEvent {
    /// Session identifier that triggered the refresh.
    pub session_id: String,
    /// Provider identifier from the allow-list (e.g. `"openai"`, `"anthropic"`).
    pub provider_id: String,
    /// BLAKE3 hash of the credential's stable identifier (not the token).
    pub credential_id_hash: [u8; 32],
    /// Whether the refresh HTTP call succeeded.
    pub refresh_success: bool,
    /// Latency of the refresh round-trip, in milliseconds.
    pub refresh_latency_ms: u64,
    /// Unix timestamp (seconds) when the newly obtained token expires.
    pub token_expiry_unix: u64,
    /// Wall-clock timestamp of this audit event.
    pub timestamp: DateTime<Utc>,
    /// OpLog chain link — hash of the previous event.
    pub prev_hash: [u8; 32],
}

impl AuthTokenRefreshedEvent {
    /// Allowed provider identifiers. Any other value panics at construction.
    pub const ALLOWED_PROVIDERS: &[&str] = &[
        "openai",
        "anthropic",
        "google",
        "mistral",
        "local",
    ];

    /// Create a new sanitized refresh audit event.
    ///
    /// # Arguments
    ///
    /// * `session_id` — Session that owns the credential.
    /// * `provider_id` — Provider name; must be in [`ALLOWED_PROVIDERS`].
    /// * `credential_id` — Stable identifier for the credential (not the
    ///   token text). This is hashed with BLAKE3 before storage.
    /// * `refresh_success` — Outcome of the refresh attempt.
    /// * `refresh_latency_ms` — Round-trip latency.
    /// * `token_expiry_unix` — Expiration time of the new token.
    /// * `prev_hash` — Previous chain hash for OpLog linking.
    ///
    /// # Panics
    ///
    /// Panics if `provider_id` is not in the allow-list.
    ///
    /// # Example
    ///
    /// ```
    /// use helios_runtime::auth_event::AuthTokenRefreshedEvent;
    ///
    /// let event = AuthTokenRefreshedEvent::new(
    ///     "sess-007".into(),
    ///     "openai".into(),
    ///     "cred-42",
    ///     true,
    ///     120,
    ///     1_893_456_789,
    ///     [0u8; 32],
    /// );
    /// ```
    #[tracing::instrument(
        level = "debug",
        skip(credential_id, prev_hash),
        fields(session_id = %session_id, provider_id = %provider_id)
    )]
    pub fn new(
        session_id: String,
        provider_id: String,
        credential_id: &str,
        refresh_success: bool,
        refresh_latency_ms: u64,
        token_expiry_unix: u64,
        prev_hash: [u8; 32],
    ) -> Self {
        assert!(
            Self::ALLOWED_PROVIDERS.contains(&provider_id.as_str()),
            "provider_id '{}' is not in the allow-list: {:?}",
            provider_id,
            Self::ALLOWED_PROVIDERS
        );

        let credential_id_hash = *blake3::hash(credential_id.as_bytes()).as_bytes();

        debug!(
            refresh_success,
            refresh_latency_ms,
            "AuthTokenRefreshedEvent created"
        );

        Self {
            session_id,
            provider_id,
            credential_id_hash,
            refresh_success,
            refresh_latency_ms,
            token_expiry_unix,
            timestamp: Utc::now(),
            prev_hash,
        }
    }

    /// Verify that this event contains no raw token fields by inspecting the
    /// serialized JSON representation.
    ///
    /// Returns `true` if the JSON does **not** contain the substrings
    /// `"access_token"` or `"refresh_token"`.
    pub fn is_sanitized(&self) -> bool {
        let json = serde_json::to_string(self).expect("infallible serialization");
        !json.contains("access_token") && !json.contains("refresh_token")
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    // -----------------------------------------------------------------------
    // 1. Verify struct has no raw token field (runtime JSON inspection)
    // -----------------------------------------------------------------------

    #[test]
    fn test_auth_event_no_raw_token() {
        let event = AuthTokenRefreshedEvent::new(
            "sess-001".into(),
            "openai".into(),
            "cred-stable-42",
            true,
            95,
            1_893_456_789,
            [0u8; 32],
        );

        // Structural check: the JSON representation must not contain token fields.
        let json = serde_json::to_string(&event).expect("serialize");
        assert!(
            !json.contains("access_token"),
            "JSON must not contain 'access_token': {json}"
        );
        assert!(
            !json.contains("refresh_token"),
            "JSON must not contain 'refresh_token': {json}"
        );

        // Also exercise the is_sanitized() helper.
        assert!(event.is_sanitized());
    }

    // -----------------------------------------------------------------------
    // 2. Provider allow-list enforcement — panic on bad provider
    // -----------------------------------------------------------------------

    #[test]
    fn test_auth_event_provider_allowlist() {
        // Valid providers should succeed.
        for provider in AuthTokenRefreshedEvent::ALLOWED_PROVIDERS {
            let _ = AuthTokenRefreshedEvent::new(
                "sess".into(),
                (*provider).into(),
                "cred-x",
                true,
                0,
                0,
                [0u8; 32],
            );
        }
    }

    #[test]
    #[should_panic(expected = "provider_id 'evil-corp' is not in the allow-list")]
    fn test_auth_event_panics_on_bad_provider() {
        let _ = AuthTokenRefreshedEvent::new(
            "sess-002".into(),
            "evil-corp".into(),
            "cred-stable-99",
            false,
            0,
            0,
            [0u8; 32],
        );
    }

    // -----------------------------------------------------------------------
    // 3. Hash stability — same credential ID yields same hash
    // -----------------------------------------------------------------------

    #[test]
    fn test_auth_event_hash_stable() {
        let e1 = AuthTokenRefreshedEvent::new(
            "sess-a".into(),
            "anthropic".into(),
            "cred-stable-hash-test",
            true,
            80,
            1_900_000_000,
            [0u8; 32],
        );
        let e2 = AuthTokenRefreshedEvent::new(
            "sess-b".into(),
            "anthropic".into(),
            "cred-stable-hash-test",
            false, // different outcome
            120,   // different latency
            1_950_000_000,
            [1u8; 32], // different prev_hash
        );

        assert_eq!(
            e1.credential_id_hash, e2.credential_id_hash,
            "same credential_id must produce identical BLAKE3 hash"
        );
    }

    // -----------------------------------------------------------------------
    // 4. Round-trip serialize / deserialize
    // -----------------------------------------------------------------------

    #[test]
    fn test_auth_event_roundtrip() {
        let original = AuthTokenRefreshedEvent::new(
            "sess-roundtrip".into(),
            "google".into(),
            "cred-rt",
            true,
            150,
            2_000_000_000,
            [0xABu8; 32],
        );

        let json = serde_json::to_vec(&original).expect("serialize");
        let back: AuthTokenRefreshedEvent = serde_json::from_slice(&json).expect("deserialize");

        assert_eq!(original, back);
    }

    // -----------------------------------------------------------------------
    // 5. Different credential IDs produce different hashes
    // -----------------------------------------------------------------------

    #[test]
    fn test_auth_event_different_cred_different_hash() {
        let e1 = AuthTokenRefreshedEvent::new(
            "sess".into(),
            "mistral".into(),
            "cred-alpha",
            true,
            0,
            0,
            [0u8; 32],
        );
        let e2 = AuthTokenRefreshedEvent::new(
            "sess".into(),
            "mistral".into(),
            "cred-beta",
            true,
            0,
            0,
            [0u8; 32],
        );

        assert_ne!(
            e1.credential_id_hash, e2.credential_id_hash,
            "different credential_ids must produce different hashes"
        );
    }

    // -----------------------------------------------------------------------
    // 6. Allow-list constant correctness
    // -----------------------------------------------------------------------

    #[test]
    fn test_allowed_providers_const() {
        assert_eq!(
            AuthTokenRefreshedEvent::ALLOWED_PROVIDERS,
            &["openai", "anthropic", "google", "mistral", "local"]
        );
    }
}
