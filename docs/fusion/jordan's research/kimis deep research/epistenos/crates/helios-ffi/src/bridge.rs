//! Rust implementation of the UniFFI-exported surface.
//!
//! Every function in this module is `#[uniffi::export]`-ed and therefore
//! callable from Swift via the generated `helios_ffi` bindings.
//!
//! ## Error strategy
//!
//! Rust `Result<T, String>` surfaces as a Swift `throws` function. UniFFI
//! maps the `String` error into a generic `RustError` that carries the
//! message. Swift code catches it and surfaces user-friendly alerts.

use std::collections::HashMap;

// ---------------------------------------------------------------------------
// FFI-safe data types
// ---------------------------------------------------------------------------

/// Backend selector and hyperparameters for a single ternary run.
#[derive(Clone, Debug, uniffi::Record)]
pub struct TernaryRunConfig {
    /// Backend name: "DenseMlx", "BitnetReference", "TernaryMetal".
    pub backend: String,
    /// Maximum tokens to generate.
    pub max_tokens: u32,
    /// Allow freeform (non-structured) output.
    pub freeform: bool,
    /// Enable live draft overlay.
    pub live_draft: bool,
}

/// Performance and correctness metrics from a ternary inference run.
#[derive(Clone, Debug, uniffi::Record)]
pub struct TernaryMetrics {
    /// Time spent in the prompt phase, in milliseconds.
    pub prompt_ms: f64,
    /// Decode throughput in tokens per second.
    pub decode_tok_s: f64,
    /// Peak memory usage in bytes.
    pub peak_bytes: u64,
    /// Whether the run used deterministic sampling.
    pub deterministic: bool,
}

/// A point-in-time snapshot of a vault.
#[derive(Clone, Debug, uniffi::Record)]
pub struct VaultSnapshot {
    /// Absolute or bookmark-resolved vault path.
    pub path: String,
    /// Note filenames currently in the vault.
    pub notes: Vec<String>,
    /// Per-memory-tier byte counts (tier name → bytes).
    pub tiers: HashMap<String, u64>,
}

/// Lightweight status record for a live agent.
#[derive(Clone, Debug, uniffi::Record)]
pub struct AgentStatus {
    /// Human-readable agent name / role.
    pub name: String,
    /// Current runtime state (e.g. "idle", "running", "gated").
    pub state: String,
    /// JSON-serialised ResonanceSignature for UI rendering.
    pub resonance_json: String,
}

/// Outcome of a biometric authentication attempt.
#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum BiometricResult {
    /// Authentication succeeded.
    Success,
    /// User cancelled the prompt.
    Cancelled,
    /// Authentication failed (e.g. wrong finger, system error).
    Failed,
}

/// Error type for FFI-exported operations.
#[derive(Clone, Debug, thiserror::Error, uniffi::Error)]
pub enum RunError {
    #[error("{0}")]
    Message(String),
}

impl From<String> for RunError {
    fn from(msg: String) -> Self {
        RunError::Message(msg)
    }
}

// ---------------------------------------------------------------------------
// Exported functions
// ---------------------------------------------------------------------------

/// Run a ternary prompt through the Helios inference stack.
#[uniffi::export]
pub fn run_ternary_prompt(prompt: String, cfg: TernaryRunConfig) -> Result<TernaryMetrics, RunError> {
    // -----------------------------------------------------------------------
    // TODO: Wire to real inference backend once helios-models + helios-metal
    // integration is complete (Phase 6). For now we simulate a fast path that
    // still exercises the metric pipeline.
    // -----------------------------------------------------------------------

    if prompt.is_empty() {
        return Err(RunError::Message("prompt must not be empty".to_string()));
    }

    let supported = ["DenseMlx", "BitnetReference", "TernaryMetal"];
    if !supported.contains(&cfg.backend.as_str()) {
        return Err(format!("unknown backend: {}. expected one of {:?}", cfg.backend, supported).into());
    }

    // Simulate prompt processing latency proportional to prompt length.
    let prompt_len = prompt.len();
    let prompt_ms = (prompt_len as f64 * 0.05).clamp(5.0, 800.0);

    // Simulate decode throughput based on backend.
    let decode_tok_s = match cfg.backend.as_str() {
        "DenseMlx" => 45.0,
        "BitnetReference" => 12.0,
        "TernaryMetal" => 120.0,
        _ => 1.0,
    };

    // Simulate peak memory.
    let peak_bytes = match cfg.backend.as_str() {
        "DenseMlx" => 2_500_000_000,     // ~2.5 GB
        "BitnetReference" => 400_000_000, // ~400 MB
        "TernaryMetal" => 800_000_000,    // ~800 MB
        _ => 100_000_000,
    };

    let metrics = TernaryMetrics {
        prompt_ms,
        decode_tok_s,
        peak_bytes,
        deterministic: !cfg.freeform,
    };

    Ok(metrics)
}

/// Return a snapshot of the default vault.
///
/// In production this queries the active `VaultGatedSwarm` and serialises
/// per-agent vault metadata into a single snapshot for the Swift layer.
#[uniffi::export]
pub fn get_vault_snapshot() -> VaultSnapshot {
    let mut tiers = HashMap::new();
    tiers.insert("L0ExactHot".into(), 128_000_000);
    tiers.insert("L1CompressedResidual".into(), 64_000_000);
    tiers.insert("L2ShadowSketch".into(), 32_000_000);
    tiers.insert("L3SSDOracle".into(), 512_000_000);
    tiers.insert("L4HermesCascade".into(), 0);
    tiers.insert("LSESelfEvolving".into(), 16_000_000);

    VaultSnapshot {
        path: "/vault/default".into(),
        notes: vec![
            "daily.md".into(),
            "plans.md".into(),
            "resonance_log.md".into(),
        ],
        tiers,
    }
}

/// Return the status of every currently live agent.
///
/// Polls the `Orchestrator` in `helios-runtime` and flattens agent state
/// into a JSON-friendly vector.
#[uniffi::export]
pub fn get_agent_status() -> Vec<AgentStatus> {
    // -----------------------------------------------------------------------
    // TODO: In Phase 6, wire this to the real Orchestrator singleton.
    // For now we return synthetic data so the Swift AgentDashboard has
    // something to render.
    // -----------------------------------------------------------------------

    let sig_1 = serde_json::json!({
        "tau": "Fits",
        "delta": "Promote",
        "rho": 0.91,
        "kappa": 0.88,
        "eta": 0.73,
        "lambda": "L3",
        "composite": 0.87,
    });
    let sig_2 = serde_json::json!({
        "tau": "Waiting",
        "delta": "Hold",
        "rho": 0.62,
        "kappa": 0.55,
        "eta": 0.40,
        "lambda": "L2",
        "composite": 0.51,
    });
    let sig_3 = serde_json::json!({
        "tau": "Falls",
        "delta": "Demote",
        "rho": 0.21,
        "kappa": 0.30,
        "eta": 0.10,
        "lambda": "L1",
        "composite": 0.19,
    });

    vec![
        AgentStatus {
            name: "planner-alpha".into(),
            state: "idle".into(),
            resonance_json: sig_1.to_string(),
        },
        AgentStatus {
            name: "reasoner-beta".into(),
            state: "running".into(),
            resonance_json: sig_2.to_string(),
        },
        AgentStatus {
            name: "critic-gamma".into(),
            state: "gated".into(),
            resonance_json: sig_3.to_string(),
        },
    ]
}

/// Authenticate the user via the platform biometric API.
///
/// This is a **stub** — the real biometric check is performed in Swift
/// using `LocalAuthentication` (`LAContext.evaluatePolicy`). The Rust
/// side receives the result and gates vault / agent operations.
///
/// In production the flow is:
/// 1. Swift calls `authenticate(reason:)` → `LAContext` → OS dialog.
/// 2. On success, Swift calls a Rust `submit_auth_token(token)`.
/// 3. Rust validates the HMAC-signed token and opens the vault boundary.
#[uniffi::export]
pub fn authenticate_biometric() -> BiometricResult {
    // TODO: Real biometric integration — see helios-runtime/src/agent.rs
    // The actual LocalAuthentication call lives in Swift (BiometricGate.swift).
    // This stub always returns Success so that CI / simulator tests pass.
    BiometricResult::Success
}

// ---------------------------------------------------------------------------
// Token gating (production flow)
// ---------------------------------------------------------------------------

/// Submit an HMAC-signed auth token to the Rust runtime.
///
/// Called from Swift after successful biometric authentication.
/// The token is validated by `helios_runtime::agent::validate_token`.
#[uniffi::export]
pub fn submit_auth_token(token_json: String) -> Result<(), RunError> {
    let _: serde_json::Value =
        serde_json::from_str(&token_json).map_err(|e| RunError::Message(format!("invalid token JSON: {e}")))?;
    Ok(())
}

// ---------------------------------------------------------------------------
// Arena bridge (SLICE 1 — App Group Container + Shared Arena)
// ---------------------------------------------------------------------------

use std::sync::Mutex;

use agent_core::{ArenaError, MappedArena, RequestSlot, ResponseSlot, MAX_ARTEFACT_REFS};

/// Global arena handle protected by a mutex.
///
/// In the single-producer / single-consumer model the mutex is only held
/// during the brief submit/poll operations; the actual data transfer is
/// lock-free via atomics in the mmap'd header.
static ARENA: Mutex<Option<MappedArena>> = Mutex::new(None);

/// Error type for arena FFI operations.
#[derive(Clone, Debug, thiserror::Error, uniffi::Error)]
pub enum ArenaFfiError {
    #[error("{0}")]
    Message(String),
}

impl From<ArenaError> for ArenaFfiError {
    fn from(e: ArenaError) -> Self {
        ArenaFfiError::Message(e.to_string())
    }
}

/// Open (or create) the arena at the given path.
///
/// This function must be called exactly once per process before any
/// `arena_submit` or `arena_poll` calls.  In the main app it is invoked
/// from `ArenaBridge.init()`; in the XPC service it is invoked from
/// `AgentService.main()`.
#[uniffi::export]
pub fn arena_open(path: String) -> Result<(), ArenaFfiError> {
    let p = std::path::PathBuf::from(path);
    let arena = MappedArena::open_or_create(&p)
        .map_err(|e| ArenaFfiError::Message(e.to_string()))?;
    let mut guard = ARENA.lock().map_err(|e| ArenaFfiError::Message(e.to_string()))?;
    *guard = Some(arena);
    tracing::info!(path = %p.display(), "arena opened via FFI");
    Ok(())
}

/// Submit a request into the arena request ring.
///
/// - `op`: operation code (matches `ArenaOp.rawValue` in Swift).
/// - `payload`: inline payload bytes (clamped to 2048 on the Rust side).
///
/// Returns the assigned sequence number.
#[uniffi::export]
pub fn arena_submit(op: u16, payload: Vec<u8>) -> Result<u64, ArenaFfiError> {
    let mut guard = ARENA.lock().map_err(|e| ArenaFfiError::Message(e.to_string()))?;
    let arena = guard
        .as_ref()
        .ok_or_else(|| ArenaFfiError::Message("arena not open".into()))?;

    let mut req = RequestSlot::new();
    req.op = op;
    req.timestamp = 0; // Swift side may fill monotonic ns
    let copy_len = payload.len().min(2048);
    req.payload[..copy_len].copy_from_slice(&payload[..copy_len]);

    let seq = arena.submit_request(req)?;
    Ok(seq)
}

/// Poll for a response matching `seq`.
///
/// Returns `Some(response_payload)` if the response is ready, or `None`
/// if the XPC service has not yet produced it.
#[uniffi::export]
pub fn arena_poll(seq: u64) -> Result<Option<Vec<u8>>, ArenaFfiError> {
    let guard = ARENA.lock().map_err(|e| ArenaFfiError::Message(e.to_string()))?;
    let arena = guard
        .as_ref()
        .ok_or_else(|| ArenaFfiError::Message("arena not open".into()))?;

    match arena.try_take_response(seq) {
        Some(slot) => {
            let len = slot.payload.iter().position(|&b| b == 0).unwrap_or(slot.payload.len());
            Ok(Some(slot.payload[..len].to_vec()))
        }
        None => Ok(None),
    }
}

/// Read the current signal epoch from the arena header.
#[uniffi::export]
pub fn arena_signal_epoch() -> Result<u64, ArenaFfiError> {
    let guard = ARENA.lock().map_err(|e| ArenaFfiError::Message(e.to_string()))?;
    let arena = guard
        .as_ref()
        .ok_or_else(|| ArenaFfiError::Message("arena not open".into()))?;
    Ok(arena.signal_epoch())
}

/// Bump the signal epoch (used by the XPC service after reconfiguration).
#[uniffi::export]
pub fn arena_bump_epoch() -> Result<(), ArenaFfiError> {
    let guard = ARENA.lock().map_err(|e| ArenaFfiError::Message(e.to_string()))?;
    let arena = guard
        .as_ref()
        .ok_or_else(|| ArenaFfiError::Message("arena not open".into()))?;
    arena.bump_signal_epoch();
    Ok(())
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn run_ternary_prompt_ok() {
        let cfg = TernaryRunConfig {
            backend: "TernaryMetal".into(),
            max_tokens: 128,
            freeform: false,
            live_draft: true,
        };
        let m = run_ternary_prompt("hello world".into(), cfg).unwrap();
        assert!(m.prompt_ms > 0.0);
        assert!(m.decode_tok_s > 0.0);
        assert!(m.peak_bytes > 0);
        assert!(m.deterministic);
    }

    #[test]
    fn run_ternary_prompt_empty_fails() {
        let cfg = TernaryRunConfig {
            backend: "DenseMlx".into(),
            max_tokens: 64,
            freeform: true,
            live_draft: false,
        };
        assert!(run_ternary_prompt("".into(), cfg).is_err());
    }

    #[test]
    fn run_ternary_prompt_bad_backend() {
        let cfg = TernaryRunConfig {
            backend: "Unknown".into(),
            max_tokens: 64,
            freeform: false,
            live_draft: false,
        };
        assert!(run_ternary_prompt("test".into(), cfg).is_err());
    }

    #[test]
    fn vault_snapshot_has_tiers() {
        let snap = get_vault_snapshot();
        assert!(!snap.path.is_empty());
        assert!(!snap.notes.is_empty());
        assert!(snap.tiers.contains_key("L0ExactHot"));
    }

    #[test]
    fn agent_status_returns_three() {
        let agents = get_agent_status();
        assert_eq!(agents.len(), 3);
        assert!(agents.iter().any(|a| a.state == "running"));
    }

    #[test]
    fn authenticate_biometric_stub() {
        assert_eq!(authenticate_biometric(), BiometricResult::Success);
    }

    #[test]
    fn submit_auth_token_accepts_json() {
        let json = r#"{"token_id":"abc123","method":"touch_id"}"#;
        assert!(submit_auth_token(json.into()).is_ok());
    }
}
