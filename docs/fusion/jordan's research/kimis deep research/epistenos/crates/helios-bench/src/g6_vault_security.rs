//! G6 — Vault Security Tests.
//!
//! Validates the biometric gate latency, HMAC token integrity, token
//! forgery resistance, and permission boundary enforcement.
//!
//! Security requirements:
//! - Auth latency < 50 ms (biometric gate).
//! - Token validation rate > 10 000 tokens/sec.
//! - Forgery detection rate = 100 %.
//! - Permission violations are always blocked.

use std::time::{Duration, Instant};

use anyhow::{Context, Result};
use clap::Parser;
use hmac::{Hmac, Mac};
use serde::{Deserialize, Serialize};
use sha2::Sha256;
use tracing::{info, warn};

use helios_bench::metrics::{BenchmarkReport, Timer};

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

/// G6 — Vault security benchmark (standalone binary).
#[derive(Parser, Debug)]
#[command(name = "g6-vault-security", about = "Touch ID, HMAC tokens, permission boundaries")]
struct Cli {
    /// Number of iterations per test.
    #[arg(long, default_value_t = 100)]
    iterations: usize,
    /// Output JSONL path.
    #[arg(long)]
    output: Option<std::path::PathBuf>,
    /// Verbose logging.
    #[arg(long)]
    verbose: bool,
}

// ---------------------------------------------------------------------------
// HMAC token
// ---------------------------------------------------------------------------

type HmacSha256 = Hmac<Sha256>;

/// A signed authentication token.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct HmacToken {
    /// Token payload (user ID + timestamp + permissions).
    pub payload: Vec<u8>,
    /// HMAC-SHA256 signature (32 bytes).
    pub signature: Vec<u8>,
    /// Expiration timestamp (Unix seconds).
    pub expires_at: u64,
    /// Permission set as bitflags.
    pub permissions: u64,
}

impl HmacToken {
    /// Create a new token with a secret key.
    pub fn new(
        user_id: &str,
        permissions: u64,
        ttl_seconds: u64,
        secret: &[u8],
    ) -> Result<Self> {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
        let expires_at = now + ttl_seconds;
        let payload = format!("{}:{}:{}", user_id, expires_at, permissions)
            .into_bytes();

        let mut mac = HmacSha256::new_from_slice(secret)
            .map_err(|e| anyhow::anyhow!("HMAC init error: {}", e))?;
        mac.update(&payload);
        let signature = mac.finalize().into_bytes().to_vec();

        Ok(Self {
            payload,
            signature,
            expires_at,
            permissions,
        })
    }

    /// Validate the token against a secret and permission requirement.
    pub fn validate(&self, secret: &[u8], required_permission: u64) -> bool {
        // Check expiration
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
        if now > self.expires_at {
            return false;
        }

        // Check permission
        if self.permissions & required_permission == 0 {
            return false;
        }

        // Verify HMAC
        let mut mac = match HmacSha256::new_from_slice(secret) {
            Ok(m) => m,
            Err(_) => return false,
        };
        mac.update(&self.payload);
        mac.verify_slice(&self.signature).is_ok()
    }

    /// Verify only the signature (no expiration / permission checks).
    pub fn verify_signature(&self, secret: &[u8]) -> bool {
        let mut mac = match HmacSha256::new_from_slice(secret) {
            Ok(m) => m,
            Err(_) => return false,
        };
        mac.update(&self.payload);
        mac.verify_slice(&self.signature).is_ok()
    }
}

/// Attempt to forge a token (should fail validation).
///
/// This function demonstrates a naive forgery attack: copy the payload
/// but generate a new signature with a different key.
pub fn forge_token() -> HmacToken {
    let payload = b"forged:user:9999:0xff".to_vec();
    let mut mac = HmacSha256::new_from_slice(b"attacker_key").expect("HMAC init");
    mac.update(&payload);
    let signature = mac.finalize().into_bytes().to_vec();
    HmacToken {
        payload,
        signature,
        expires_at: u64::MAX,
        permissions: 0xff,
    }
}

// ---------------------------------------------------------------------------
// Biometric gate stub
// ---------------------------------------------------------------------------

/// Simulated biometric authentication gate.
struct BiometricGate {
    /// Enrollment template (256-dim feature vector).
    template: Vec<f32>,
    /// Match threshold (cosine similarity).
    threshold: f32,
}

impl BiometricGate {
    fn new() -> Self {
        let mut template = Vec::with_capacity(256);
        for i in 0..256 {
            template.push(((i * 7919) as f32).sin() * 0.5);
        }
        Self {
            template,
            threshold: 0.85,
        }
    }

    /// Authenticate a sample against the enrolled template.
    ///
    /// Returns `(success, latency_ms)`.
    fn authenticate(&self, sample: &[f32]) -> (bool, f64) {
        let start = Instant::now();
        let dot: f32 = self
            .template
            .iter()
            .zip(sample.iter())
            .map(|(a, b)| a * b)
            .sum();
        let norm_t: f32 = self.template.iter().map(|x| x * x).sum::<f32>().sqrt();
        let norm_s: f32 = sample.iter().map(|x| x * x).sum::<f32>().sqrt();
        let sim = if norm_t > 0.0 && norm_s > 0.0 {
            dot / (norm_t * norm_s)
        } else {
            0.0
        };
        let elapsed = start.elapsed().as_secs_f64() * 1000.0;
        (sim >= self.threshold, elapsed)
    }

    /// Generate a synthetic matching sample.
    fn matching_sample(&self) -> Vec<f32> {
        self.template
            .iter()
            .map(|&x| x + rand::random::<f32>() * 0.02 - 0.01)
            .collect()
    }

    /// Generate a synthetic non-matching sample.
    fn non_matching_sample(&self) -> Vec<f32> {
        (0..256)
            .map(|i| ((i * 1319) as f32).cos() * 0.5)
            .collect()
    }
}

// ---------------------------------------------------------------------------
// Permission boundary stub
// ---------------------------------------------------------------------------

/// Permission bitflags.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Permissions {
    pub read: bool,
    pub write: bool,
    pub execute: bool,
    pub admin: bool,
}

impl Permissions {
    pub fn to_bits(self) -> u64 {
        let mut bits = 0u64;
        if self.read { bits |= 1; }
        if self.write { bits |= 2; }
        if self.execute { bits |= 4; }
        if self.admin { bits |= 8; }
        bits
    }

    pub fn from_bits(bits: u64) -> Self {
        Self {
            read: bits & 1 != 0,
            write: bits & 2 != 0,
            execute: bits & 4 != 0,
            admin: bits & 8 != 0,
        }
    }

    pub fn can_read(self) -> bool { self.read }
    pub fn can_write(self) -> bool { self.write }
    pub fn can_execute(self) -> bool { self.execute }
    pub fn can_admin(self) -> bool { self.admin }
}

/// Enforce a permission boundary.
///
/// Returns `true` if the operation is permitted, `false` otherwise.
pub fn check_permission_boundary(token: &HmacToken, required: u64) -> bool {
    let secret = b"helios_vault_master_secret_2024";
    token.validate(secret, required)
}

// ---------------------------------------------------------------------------
// Metrics
// ---------------------------------------------------------------------------

/// Security benchmark metrics.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SecurityMetrics {
    /// Average biometric authentication latency (ms).
    pub auth_latency_ms: f32,
    /// Token validation throughput (tokens/sec).
    pub token_validation_rate: f32,
    /// Rate at which forged tokens are detected (should be 1.0).
    pub forgery_detection_rate: f32,
    /// Whether a permission violation was correctly blocked.
    pub permission_violation_blocked: bool,
    /// Number of iterations run.
    pub iterations: usize,
    /// False acceptance rate (biometric).
    pub false_accept_rate: f32,
    /// False rejection rate (biometric).
    pub false_reject_rate: f32,
}

// ---------------------------------------------------------------------------
// Benchmark runner
// ---------------------------------------------------------------------------

/// Run the vault security benchmark.
///
/// Tests:
/// 1. Biometric gate latency and accuracy.
/// 2. Token creation, validation, and throughput.
/// 3. Forgery resistance.
/// 4. Permission boundary enforcement.
pub fn run_vault_security(iterations: usize) -> Result<SecurityMetrics> {
    info!("G6 — Vault Security: {} iterations", iterations);
    let secret = b"helios_vault_master_secret_2024";
    let bio = BiometricGate::new();

    // 1. Biometric latency + accuracy
    let mut auth_latencies = Vec::with_capacity(iterations);
    let mut false_accepts = 0usize;
    let mut false_rejects = 0usize;

    for _ in 0..iterations {
        let (success, latency) = bio.authenticate(&bio.matching_sample());
        auth_latencies.push(latency);
        if !success {
            false_rejects += 1;
        }
    }
    for _ in 0..iterations {
        let (success, _) = bio.authenticate(&bio.non_matching_sample());
        if success {
            false_accepts += 1;
        }
    }

    let auth_latency_ms = if !auth_latencies.is_empty() {
        auth_latencies.iter().sum::<f64>() / auth_latencies.len() as f64
    } else {
        0.0
    };

    // 2. Token validation throughput
    let token = HmacToken::new("user_42", Permissions { read: true, write: false, execute: false, admin: false }.to_bits(), 3600, secret)?;
    let t_val = Timer::start("token_validation");
    let mut valid_count = 0usize;
    for _ in 0..iterations {
        if token.validate(secret, 1) {
            valid_count += 1;
        }
    }
    let val_ms = t_val.stop();
    let token_validation_rate = if val_ms > 0.0 {
        (iterations as f64 / (val_ms / 1000.0)) as f32
    } else {
        f32::INFINITY
    };

    // 3. Forgery resistance
    let forged = forge_token();
    let mut forgeries_detected = 0usize;
    for _ in 0..iterations {
        if !forged.validate(secret, 1) && !forged.verify_signature(secret) {
            forgeries_detected += 1;
        }
    }
    let forgery_detection_rate = forgeries_detected as f32 / iterations as f32;

    // 4. Permission boundaries
    let read_token = HmacToken::new("reader", Permissions { read: true, write: false, execute: false, admin: false }.to_bits(), 3600, secret)?;
    let write_token = HmacToken::new("writer", Permissions { read: true, write: true, execute: false, admin: false }.to_bits(), 3600, secret)?;

    let read_blocked = !check_permission_boundary(&read_token, 2); // write permission
    let write_allowed = check_permission_boundary(&write_token, 2);
    let permission_violation_blocked = read_blocked && write_allowed;

    info!(
        "Auth latency: {:.3} ms, Validation rate: {:.0} tok/s, Forgery detection: {:.1}%, Permission blocked: {}",
        auth_latency_ms,
        token_validation_rate,
        forgery_detection_rate * 100.0,
        permission_violation_blocked
    );

    Ok(SecurityMetrics {
        auth_latency_ms: auth_latency_ms as f32,
        token_validation_rate,
        forgery_detection_rate,
        permission_violation_blocked,
        iterations,
        false_accept_rate: false_accepts as f32 / iterations as f32,
        false_reject_rate: false_rejects as f32 / iterations as f32,
    })
}

// ---------------------------------------------------------------------------
// Binary entry point
// ---------------------------------------------------------------------------

fn main() -> Result<()> {
    let cli = Cli::parse();

    let subscriber = tracing_subscriber::fmt()
        .with_max_level(if cli.verbose {
            tracing::Level::DEBUG
        } else {
            tracing::Level::INFO
        })
        .finish();
    let _guard = tracing::subscriber::set_default(subscriber);

    let metrics = run_vault_security(cli.iterations)?;

    let mut report = BenchmarkReport::new();
    report.push("g6", "vault", "auth_latency_ms", metrics.auth_latency_ms as f64, "ms");
    report.push("g6", "vault", "token_validation_rate", metrics.token_validation_rate as f64, "tok/s");
    report.push("g6", "vault", "forgery_detection_rate", metrics.forgery_detection_rate as f64, "ratio");
    report.push(
        "g6",
        "vault",
        "permission_violation_blocked",
        if metrics.permission_violation_blocked { 1.0 } else { 0.0 },
        "bool",
    );
    report.push("g6", "vault", "false_accept_rate", metrics.false_accept_rate as f64, "ratio");
    report.push("g6", "vault", "false_reject_rate", metrics.false_reject_rate as f64, "ratio");

    if let Some(path) = cli.output {
        helios_bench::metrics::report_to_jsonl(&report, &path)?;
    }

    if metrics.forgery_detection_rate >= 1.0 && metrics.permission_violation_blocked {
        info!("G6 VAULT SECURITY: ALL CHECKS PASS");
    } else {
        warn!("G6 VAULT SECURITY: SOME CHECKS FAIL");
    }

    println!("\n{}", helios_bench::metrics::report_to_md(&report));
    Ok(())
}

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn token_create_and_validate() {
        let secret = b"test_secret";
        let token = HmacToken::new("alice", 0x01, 3600, secret).unwrap();
        assert!(token.validate(secret, 0x01));
        assert!(!token.validate(b"wrong_secret", 0x01));
        assert!(!token.validate(secret, 0x02)); // wrong permission
    }

    #[test]
    fn token_expiration() {
        let secret = b"test_secret";
        let token = HmacToken::new("alice", 0x01, 0, secret).unwrap();
        std::thread::sleep(std::time::Duration::from_millis(10));
        assert!(!token.validate(secret, 0x01), "Expired token should fail");
    }

    #[test]
    fn forged_token_fails() {
        let secret = b"test_secret";
        let forged = forge_token();
        assert!(!forged.validate(secret, 0x01));
        assert!(!forged.verify_signature(secret));
    }

    #[test]
    fn biometric_match() {
        let gate = BiometricGate::new();
        let sample = gate.matching_sample();
        let (success, _latency) = gate.authenticate(&sample);
        assert!(success, "Matching sample should authenticate");
    }

    #[test]
    fn biometric_non_match() {
        let gate = BiometricGate::new();
        let sample = gate.non_matching_sample();
        let (success, _latency) = gate.authenticate(&sample);
        assert!(!success, "Non-matching sample should not authenticate");
    }

    #[test]
    fn permission_boundary_enforced() {
        let secret = b"test_secret";
        let read_token = HmacToken::new("reader", Permissions { read: true, write: false, execute: false, admin: false }.to_bits(), 3600, secret).unwrap();
        let write_token = HmacToken::new("writer", Permissions { read: true, write: true, execute: false, admin: false }.to_bits(), 3600, secret).unwrap();

        assert!(check_permission_boundary(&read_token, 1)); // read OK
        assert!(!check_permission_boundary(&read_token, 2)); // write blocked
        assert!(check_permission_boundary(&write_token, 2)); // write OK
        assert!(check_permission_boundary(&write_token, 1)); // read OK (implied)
    }

    #[test]
    fn run_security_suite() {
        let m = run_vault_security(50).unwrap();
        assert!(m.auth_latency_ms >= 0.0);
        assert!(m.token_validation_rate > 0.0);
        assert!((m.forgery_detection_rate - 1.0).abs() < 1e-3);
        assert!(m.permission_violation_blocked);
    }
}
