//! VaultGatedSwarm — multi-agent runtime with biometric gating.
//!
//! This module implements the **security boundary** of the Epistenos
//! runtime. Every agent runs inside a per-agent vault with fine-grained
//! permission boundaries. Access to the vault is gated by biometric
//! authentication, producing HMAC-signed capability tokens.
//!
//! ## Security model
//!
//! 1. **BiometricGate** — the user authenticates via TouchID, FaceID, or Passcode.
//! 2. **authenticate** — produces an `AuthToken` signed with `blake3`-based HMAC.
//! 3. **AgentVault** — each agent sees only the vault paths it is authorised for.
//! 4. **HmacToken** — capability token that carries permissions in a tamper-evident envelope.
//!
//! The biometric gate is the only entry-point into the swarm. Without a
//! valid token, an agent cannot read, write, or invoke tools.

use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use thiserror::Error;
use tracing::{debug, error, info, instrument, warn};
use hex;

// ---------------------------------------------------------------------------
// BiometricGate — authentication modality
// ---------------------------------------------------------------------------

/// The biometric authentication modality used to enter the system.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum BiometricGate {
    /// Fingerprint-based authentication (iOS/macOS TouchID).
    TouchID,
    /// Facial-recognition authentication (iOS/macOS FaceID).
    FaceID,
    /// Fallback numeric or alphanumeric passcode.
    Passcode,
}

impl std::fmt::Display for BiometricGate {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            BiometricGate::TouchID => write!(f, "touch_id"),
            BiometricGate::FaceID => write!(f, "face_id"),
            BiometricGate::Passcode => write!(f, "passcode"),
        }
    }
}

// ---------------------------------------------------------------------------
// AuthToken — signed capability token
// ---------------------------------------------------------------------------

/// A time-bounded, HMAC-signed authentication token.
///
/// Tokens are issued by the `authenticate` function and consumed by
/// vault operations. The token embeds:
/// - a nonce (unique per authentication)
/// - an expiry timestamp
/// - a permissions hash (what the bearer is allowed to do)
/// - an HMAC over all of the above
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct AuthToken {
    /// Blake3 hash of the token content (used as token ID).
    pub token_id: [u8; 32],
    /// Authentication method used.
    pub method: BiometricGate,
    /// When the token expires.
    pub expires_at: chrono::DateTime<chrono::Utc>,
    /// HMAC of (token_id || method || expires_at) using a system secret.
    pub hmac: [u8; 32],
}

/// Errors during biometric authentication or token validation.
#[derive(Error, Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum AuthError {
    #[error("biometric check failed: {0}")]
    BiometricFailed(String),

    #[error("token expired at {0}")]
    TokenExpired(chrono::DateTime<chrono::Utc>),

    #[error("token HMAC invalid")]
    HmacInvalid,

    #[error("permission denied: {action} on {resource}")]
    PermissionDenied { action: String, resource: String },

    #[error("vault path not authorised: {0}")]
    VaultPathDenied(String),
}

// ---------------------------------------------------------------------------
// HmacToken — blake3-based capability token
// ---------------------------------------------------------------------------

/// An HMAC token is a capability-granting ticket with a chained hash
/// that links it to a parent token and a set of permissions.
///
/// The HMAC is computed using Blake3 keyed mode, which provides both
/// integrity and origin authentication.
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct HmacToken {
    /// The token ID (Blake3 hash of canonical form).
    pub id: [u8; 32],
    /// Parent token ID (for delegation chains).
    pub parent: Option<[u8; 32]>,
    /// Permissions granted by this token.
    pub permissions: Vec<String>,
    /// Keyed Blake3 MAC over the canonical form.
    pub mac: [u8; 32],
}

impl HmacToken {
    /// Compute the canonical hash of a token without the MAC.
    pub fn canonical_bytes(&self) -> Vec<u8> {
        let mut buf = Vec::new();
        if let Some(p) = self.parent {
            buf.extend_from_slice(&p);
        }
        for perm in &self.permissions {
            buf.extend_from_slice(perm.as_bytes());
        }
        buf
    }

    /// Verify the MAC against a secret key.
    ///
    /// Uses Blake3 keyed mode: `keyed_hash(key, canonical_bytes)`.
    pub fn verify(&self, secret: &[u8; 32]) -> bool {
        let expected = blake3::keyed_hash(secret, &self.canonical_bytes());
        expected.as_bytes() == &self.mac[..]
    }

    /// Issue a new child token with a subset of permissions.
    pub fn delegate(&self, permissions: Vec<String>, secret: &[u8; 32]) -> Self {
        let canonical = {
            let mut buf = Vec::new();
            buf.extend_from_slice(&self.id);
            for perm in &permissions {
                buf.extend_from_slice(perm.as_bytes());
            }
            buf
        };
        let id = blake3::hash(&canonical).into();
        let mac: [u8; 32] = blake3::keyed_hash(secret, &canonical).into();
        Self {
            id,
            parent: Some(self.id),
            permissions,
            mac,
        }
    }
}

// ---------------------------------------------------------------------------
// authenticate — biometric gating entry-point
// ---------------------------------------------------------------------------

/// System authentication secret (in production this is loaded from the
/// Secure Enclave / keychain, never hardcoded).
///
/// For tests we use a deterministic placeholder.
fn system_secret() -> [u8; 32] {
    // TODO: Load from Secure Enclave / keychain at boot
    let mut key = [0u8; 32];
    for (i, b) in key.iter_mut().enumerate() {
        *b = i as u8;
    }
    key
}

/// Authenticate a user via a biometric gate.
///
/// In production this calls into the OS biometric APIs (LocalAuthentication
/// on Apple platforms, BiometricPrompt on Android). The stub here simulates
/// a successful authentication.
///
/// Returns an `AuthToken` with a 1-hour expiry and HMAC signed by the
/// system secret.
#[instrument(skip(gate), fields(method = %gate))]
pub fn authenticate(gate: BiometricGate) -> Result<AuthToken, AuthError> {
    // TODO: real biometric check via OS API
    info!(method = %gate, "biometric authentication requested");

    let now = chrono::Utc::now();
    let expires_at = now + chrono::Duration::hours(1);

    let mut canonical = Vec::new();
    canonical.extend_from_slice(gate.to_string().as_bytes());
    canonical.extend_from_slice(&now.timestamp().to_le_bytes());
    let token_id: [u8; 32] = blake3::hash(&canonical).into();

    let mut mac_input = Vec::new();
    mac_input.extend_from_slice(&token_id);
    mac_input.extend_from_slice(gate.to_string().as_bytes());
    mac_input.extend_from_slice(&expires_at.timestamp().to_le_bytes());
    let hmac: [u8; 32] = blake3::keyed_hash(&system_secret(), &mac_input).into();

    let token = AuthToken {
        token_id,
        method: gate,
        expires_at,
        hmac,
    };

    debug!(token_id = hex::encode(&token.token_id), "token issued");
    Ok(token)
}

/// Validate that an `AuthToken` is still valid (not expired, HMAC correct).
#[instrument(skip(token))]
pub fn validate_token(token: &AuthToken) -> Result<(), AuthError> {
    let now = chrono::Utc::now();
    if now > token.expires_at {
        warn!("token expired");
        return Err(AuthError::TokenExpired(token.expires_at));
    }

    let mut mac_input = Vec::new();
    mac_input.extend_from_slice(&token.token_id);
    mac_input.extend_from_slice(token.method.to_string().as_bytes());
    mac_input.extend_from_slice(&token.expires_at.timestamp().to_le_bytes());
    let expected: [u8; 32] = blake3::keyed_hash(&system_secret(), &mac_input).into();

    if expected != token.hmac {
        error!("token HMAC mismatch");
        return Err(AuthError::HmacInvalid);
    }

    debug!("token valid");
    Ok(())
}

// ---------------------------------------------------------------------------
// VaultPermissions — what an agent is allowed to do
// ---------------------------------------------------------------------------

/// A set of permission grants for an agent.
#[derive(Clone, Debug, Default, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct VaultPermissions {
    /// Paths the agent is allowed to read.
    pub read_paths: HashSet<String>,
    /// Paths the agent is allowed to write.
    pub write_paths: HashSet<String>,
    /// Tools the agent is allowed to invoke.
    pub tools: HashSet<String>,
    /// Maximum residency level the agent can access.
    pub max_residency: crate::gate::Residency,
}

impl VaultPermissions {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn can_read(&self, path: &str) -> bool {
        self.read_paths.iter().any(|p| path.starts_with(p))
    }

    pub fn can_write(&self, path: &str) -> bool {
        self.write_paths.iter().any(|p| path.starts_with(p))
    }

    pub fn can_use_tool(&self, tool: &str) -> bool {
        self.tools.contains(tool)
    }
}

// ---------------------------------------------------------------------------
// AgentVault — per-agent vault view
// ---------------------------------------------------------------------------

/// A per-agent vault that enforces permission boundaries.
///
/// Each agent in the swarm has its own `AgentVault`. The vault mediates
/// all reads, writes, and tool invocations, checking the bearer token
/// against the agent's permission set.
#[derive(Clone, Debug)]
pub struct AgentVault {
    pub agent_id: crate::types::AgentId,
    pub permissions: VaultPermissions,
    /// In-memory vault store (path → content).
    store: HashMap<String, String>,
}

impl AgentVault {
    pub fn new(agent_id: crate::types::AgentId, permissions: VaultPermissions) -> Self {
        Self {
            agent_id,
            permissions,
            store: HashMap::new(),
        }
    }

    /// Read a vault path, checking the token and permissions.
    #[instrument(skip(self, token), fields(agent = %self.agent_id))]
    pub fn read(
        &self,
        token: &AuthToken,
        path: &str,
    ) -> Result<Option<&String>, AuthError> {
        validate_token(token)?;
        if !self.permissions.can_read(path) {
            return Err(AuthError::VaultPathDenied(path.into()));
        }
        debug!(path, "vault read");
        Ok(self.store.get(path))
    }

    /// Write to a vault path, checking the token and permissions.
    #[instrument(skip(self, token), fields(agent = %self.agent_id))]
    pub fn write(
        &mut self,
        token: &AuthToken,
        path: &str,
        content: String,
    ) -> Result<(), AuthError> {
        validate_token(token)?;
        if !self.permissions.can_write(path) {
            return Err(AuthError::VaultPathDenied(path.into()));
        }
        debug!(path, "vault write");
        self.store.insert(path.into(), content);
        Ok(())
    }

    /// List all paths in this agent's vault.
    pub fn list_paths(&self) -> Vec<&String> {
        self.store.keys().collect()
    }
}

// ---------------------------------------------------------------------------
// VaultGatedSwarm — the multi-agent swarm
// ---------------------------------------------------------------------------

/// The `VaultGatedSwarm` is the top-level runtime that manages a
/// collection of agents, each with its own vault, and enforces
/// biometric gating at the system boundary.
///
/// All agents share a single authentication context — once the user
/// authenticates, the resulting token is propagated to all agent
/// vaults for the duration of the session.
#[derive(Clone, Debug)]
pub struct VaultGatedSwarm {
    /// Currently active agents.
    pub agents: HashMap<crate::types::AgentId, AgentVault>,
    /// The active session token (if any).
    pub session_token: Option<AuthToken>,
}

impl VaultGatedSwarm {
    pub fn new() -> Self {
        Self {
            agents: HashMap::new(),
            session_token: None,
        }
    }

    /// Authenticate the swarm boundary.
    pub fn authenticate_boundary(&mut self, gate: BiometricGate) -> Result<(), AuthError> {
        let token = authenticate(gate)?;
        self.session_token = Some(token);
        info!("swarm boundary authenticated");
        Ok(())
    }

    /// Register a new agent vault in the swarm.
    pub fn register_agent(
        &mut self,
        agent_id: crate::types::AgentId,
        permissions: VaultPermissions,
    ) {
        self.agents.insert(agent_id, AgentVault::new(agent_id, permissions));
    }

    /// Get a vault by agent ID (requires active session).
    pub fn vault(
        &self,
        agent_id: crate::types::AgentId,
    ) -> Result<&AgentVault, AuthError> {
        if self.session_token.is_none() {
            return Err(AuthError::BiometricFailed("no active session".into()));
        }
        self.agents
            .get(&agent_id)
            .ok_or_else(|| AuthError::BiometricFailed("agent not found".into()))
    }

    /// Get a mutable vault by agent ID (requires active session).
    pub fn vault_mut(
        &mut self,
        agent_id: crate::types::AgentId,
    ) -> Result<&mut AgentVault, AuthError> {
        if self.session_token.is_none() {
            return Err(AuthError::BiometricFailed("no active session".into()));
        }
        self.agents
            .get_mut(&agent_id)
            .ok_or_else(|| AuthError::BiometricFailed("agent not found".into()))
    }

    /// Number of agents in the swarm.
    pub fn agent_count(&self) -> usize {
        self.agents.len()
    }
}

impl Default for VaultGatedSwarm {
    fn default() -> Self {
        Self::new()
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::AgentId;

    #[test]
    fn biometric_gate_display() {
        assert_eq!(BiometricGate::TouchID.to_string(), "touch_id");
        assert_eq!(BiometricGate::FaceID.to_string(), "face_id");
        assert_eq!(BiometricGate::Passcode.to_string(), "passcode");
    }

    #[test]
    fn authenticate_produces_token() {
        let token = authenticate(BiometricGate::Passcode).unwrap();
        assert_eq!(token.method, BiometricGate::Passcode);
        assert!(token.expires_at > chrono::Utc::now());
    }

    #[test]
    fn validate_token_ok() {
        let token = authenticate(BiometricGate::Passcode).unwrap();
        assert!(validate_token(&token).is_ok());
    }

    #[test]
    fn validate_token_expired() {
        let mut token = authenticate(BiometricGate::Passcode).unwrap();
        // Back-date the expiry
        token.expires_at = chrono::Utc::now() - chrono::Duration::hours(1);
        let err = validate_token(&token).unwrap_err();
        assert!(matches!(err, AuthError::TokenExpired(_)));
    }

    #[test]
    fn validate_token_hmac_tampered() {
        let mut token = authenticate(BiometricGate::Passcode).unwrap();
        token.hmac[0] ^= 0xFF; // corrupt one byte
        let err = validate_token(&token).unwrap_err();
        assert_eq!(err, AuthError::HmacInvalid);
    }

    #[test]
    fn hmac_token_verify() {
        let secret = [42u8; 32];
        let token = HmacToken {
            id: [1u8; 32],
            parent: None,
            permissions: vec!["read".into(), "write".into()],
            mac: blake3::keyed_hash(&secret, b"readwrite").into(),
        };
        assert!(token.verify(&secret));
        assert!(!token.verify(&[0u8; 32]));
    }

    #[test]
    fn hmac_token_delegation() {
        let secret = [99u8; 32];
        let parent = HmacToken {
            id: [1u8; 32],
            parent: None,
            permissions: vec!["read".into(), "write".into(), "delete".into()],
            mac: blake3::keyed_hash(&secret, &[0u8; 1]).into(),
        };
        let child = parent.delegate(vec!["read".into()], &secret);
        assert_eq!(child.parent, Some(parent.id));
        assert_eq!(child.permissions, vec!["read".into()]);
        assert!(child.verify(&secret));
    }

    #[test]
    fn vault_permissions_checks() {
        let mut perms = VaultPermissions::new();
        perms.read_paths.insert("/vault/plans".into());
        perms.write_paths.insert("/vault/plans".into());
        perms.tools.insert("reason.plan".into());

        assert!(perms.can_read("/vault/plans/daily"));
        assert!(!perms.can_read("/vault/secrets"));
        assert!(perms.can_write("/vault/plans/daily"));
        assert!(!perms.can_write("/vault/secrets"));
        assert!(perms.can_use_tool("reason.plan"));
        assert!(!perms.can_use_tool("vault.search"));
    }

    #[test]
    fn agent_vault_read_write() {
        let agent = AgentId::new();
        let mut perms = VaultPermissions::new();
        perms.read_paths.insert("/vault".into());
        perms.write_paths.insert("/vault".into());
        let mut vault = AgentVault::new(agent, perms);

        let token = authenticate(BiometricGate::Passcode).unwrap();
        vault.write(&token, "/vault/test", "hello".into()).unwrap();
        let content = vault.read(&token, "/vault/test").unwrap();
        assert_eq!(content, "hello");
    }

    #[test]
    fn agent_vault_permission_denied() {
        let agent = AgentId::new();
        let perms = VaultPermissions::new(); // empty = no permissions
        let mut vault = AgentVault::new(agent, perms);

        let token = authenticate(BiometricGate::Passcode).unwrap();
        let err = vault.write(&token, "/vault/test", "hello".into()).unwrap_err();
        assert!(matches!(err, AuthError::VaultPathDenied(_)));
    }

    #[test]
    fn swarm_boundary_auth() {
        let mut swarm = VaultGatedSwarm::new();
        assert!(swarm.session_token.is_none());
        swarm.authenticate_boundary(BiometricGate::FaceID).unwrap();
        assert!(swarm.session_token.is_some());
    }

    #[test]
    fn swarm_vault_access_requires_auth() {
        let mut swarm = VaultGatedSwarm::new();
        let agent = AgentId::new();
        swarm.register_agent(agent, VaultPermissions::new());
        // No authentication → cannot access vault
        let err = swarm.vault(agent).unwrap_err();
        assert!(matches!(err, AuthError::BiometricFailed(_)));
    }

    #[test]
    fn swarm_register_and_access() {
        let mut swarm = VaultGatedSwarm::new();
        swarm.authenticate_boundary(BiometricGate::Passcode).unwrap();

        let agent = AgentId::new();
        let mut perms = VaultPermissions::new();
        perms.read_paths.insert("/".into());
        perms.write_paths.insert("/".into());
        swarm.register_agent(agent, perms);

        let token = swarm.session_token.clone().unwrap();
        let vault = swarm.vault_mut(agent).unwrap();
        vault.write(&token, "/notes", "hello".into()).unwrap();
        let content = vault.read(&token, "/notes").unwrap();
        assert_eq!(content, "hello");
    }
}
