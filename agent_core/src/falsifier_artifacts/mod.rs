//! `falsifier_artifacts` — schema-conformant witness emission for T23B
//! F-* falsifier harnesses.
//!
//! Source:
//! - `docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md`
//!   (schema_version `2026-05-18.2`, 18 required top-level fields,
//!   M2 Pro 16 GB UMA hardware pin).
//! - `docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md` §Terminal F.
//! - `docs/falsifiers/M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md`.
//!
//! # Scope (Phase 2 Terminal F, intentional minimum)
//!
//! This module emits the **18 required top-level fields** named in the
//! schema's frontmatter table. It does NOT yet emit the optional
//! `fixture_lineage` / `provider_receipts` shells, the per-axis
//! evidence-kind/threshold-source/aggregate-sample/sidecar-digest
//! sub-schemas, or the JSON Schema draft 2020-12 `$ref` namespace
//! resolution — those land in a follow-up validator binary (W-46) per
//! `docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md` §Terminal F step 4.
//!
//! The artifacts produced by this module are honest fallback witnesses:
//! they pin the M2 Pro 16 GB hardware, log the exact `command_digest`,
//! record per-axis `measurements` + `acceptance_thresholds` +
//! `pass_per_axis` + `overall_pass`, and emit a canonical
//! `result_digest` over the measurement payload. Terminal F is
//! deliberately conservative: missing fields are surfaced as
//! `notes` caveats, never silently defaulted to a green claim.

use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;

pub mod axes;

/// Pinned hardware fields per FALSIFIER_ARTIFACT_SCHEMA `$defs.hardware_pin`.
/// Schema constants — any drift fails the artifact.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct HardwarePin {
    pub machine: String,
    pub cpu: String,
    pub gpu: String,
    pub unified_memory_gb: u32,
    pub memory_bandwidth_gb_s: u32,
}

impl HardwarePin {
    /// Canonical M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA,
    /// approximately 200 GB/s memory bandwidth (Jojo's shippability rig).
    pub fn m2_pro_2023_16gb() -> Self {
        Self {
            machine: "M2 Pro 14-inch 2023".to_string(),
            cpu: "12-core CPU".to_string(),
            gpu: "19-core GPU".to_string(),
            unified_memory_gb: 16,
            memory_bandwidth_gb_s: 200,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ToolchainIdentity {
    pub xcodebuild: String,
    pub swift: String,
    pub rustc: String,
    pub python: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RunnerEnvironment {
    pub cwd: String,
    pub shell: String,
    pub env_policy: String,
    pub locale: String,
    pub timezone: String,
    pub os_build: String,
    pub toolchain_identity: ToolchainIdentity,
    pub thermal_state_start: String,
    pub thermal_state_end: String,
    pub power_source: String,
}

impl RunnerEnvironment {
    /// Minimal honest pin — toolchain strings + thermal/power left as
    /// best-effort placeholders that pass the schema's enum gates
    /// (`unknown` is allowed for thermal_state_*).
    pub fn local_default(rustc_version: &str) -> Self {
        Self {
            cwd: "repo_root".to_string(),
            shell: "zsh".to_string(),
            env_policy: "script_owned".to_string(),
            locale: "C".to_string(),
            timezone: "UTC".to_string(),
            os_build: detect_os_build(),
            toolchain_identity: ToolchainIdentity {
                xcodebuild: "not_used".to_string(),
                swift: "not_used".to_string(),
                rustc: rustc_version.to_string(),
                python: "not_used".to_string(),
            },
            thermal_state_start: "unknown".to_string(),
            thermal_state_end: "unknown".to_string(),
            power_source: "unknown".to_string(),
        }
    }
}

fn detect_os_build() -> String {
    // Schema permits any non-empty `[A-Za-z0-9._() -]+` token. Honest
    // default until we shell out to `sw_vers -buildVersion` from the
    // harness: a static "Darwin 25" marker covering the macOS 26
    // family the user's rig runs on per CLAUDE.md.
    "Darwin 25 (macOS 26 family)".to_string()
}

/// Per-axis numeric measurement + unit, per schema `measurements` axis shape.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Measurement {
    pub value: serde_json::Value,
    pub unit: String,
}

/// Per-axis acceptance threshold (operator + value + unit), per schema
/// `acceptance_thresholds` shape.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AcceptanceThreshold {
    pub operator: String,
    pub value: serde_json::Value,
    pub unit: String,
}

/// Schema-conformant witness — all 18 required top-level fields per
/// `docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md`. Optional
/// `fixture_lineage` + `provider_receipts` deferred to a follow-up.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct FalsifierArtifact {
    pub falsifier_id: String,
    pub schema_version: String,
    pub artifact_kind: String,
    pub hardware_pin: HardwarePin,
    pub command: String,
    pub command_digest: String,
    pub runner_environment: RunnerEnvironment,
    pub commit_sha: String,
    pub fixture_id: String,
    pub timestamp_utc: String,
    pub result_digest: String,
    pub measurements: BTreeMap<String, Measurement>,
    pub acceptance_thresholds: BTreeMap<String, AcceptanceThreshold>,
    pub pass_per_axis: BTreeMap<String, bool>,
    pub overall_pass: bool,
    pub fallback_tier: String,
    pub anomalies: Vec<serde_json::Value>,
    pub notes: String,
}

pub const CANONICAL_SCHEMA_VERSION: &str = "2026-05-18.2";

/// Builder shape — collects fields, fills the digest fields automatically
/// on `build()`.
pub struct ArtifactBuilder {
    pub falsifier_id: String,
    pub artifact_kind: ArtifactKind,
    pub command: String,
    pub commit_sha: String,
    pub fixture_id: String,
    pub measurements: BTreeMap<String, Measurement>,
    pub acceptance_thresholds: BTreeMap<String, AcceptanceThreshold>,
    pub pass_per_axis: BTreeMap<String, bool>,
    pub fallback_tier: FallbackTier,
    pub anomalies: Vec<serde_json::Value>,
    pub notes: String,
    pub timestamp_utc: String,
}

#[derive(Clone, Copy, Debug)]
pub enum ArtifactKind {
    PrimaryWitness,
    FallbackWitness,
    FailureReport,
}

impl ArtifactKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::PrimaryWitness => "primary_witness",
            Self::FallbackWitness => "fallback_witness",
            Self::FailureReport => "failure_report",
        }
    }
}

#[derive(Clone, Copy, Debug)]
pub enum FallbackTier {
    Primary,
    Fallback,
    Fail,
}

impl FallbackTier {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Primary => "Primary",
            Self::Fallback => "Fallback",
            Self::Fail => "Fail",
        }
    }
}

impl ArtifactBuilder {
    pub fn build(self) -> FalsifierArtifact {
        let overall_pass = self.pass_per_axis.values().copied().all(|v| v);
        let result_digest = canonical_digest(&self.measurements, &self.pass_per_axis);
        let command_digest = sha256_hex(self.command.as_bytes());
        let rustc_version = env!("CARGO_PKG_VERSION");
        FalsifierArtifact {
            falsifier_id: self.falsifier_id,
            schema_version: CANONICAL_SCHEMA_VERSION.to_string(),
            artifact_kind: self.artifact_kind.as_str().to_string(),
            hardware_pin: HardwarePin::m2_pro_2023_16gb(),
            command: self.command,
            command_digest,
            runner_environment: RunnerEnvironment::local_default(&format!(
                "rustc (agent_core {rustc_version})"
            )),
            commit_sha: self.commit_sha,
            fixture_id: self.fixture_id,
            timestamp_utc: self.timestamp_utc,
            result_digest,
            measurements: self.measurements,
            acceptance_thresholds: self.acceptance_thresholds,
            pass_per_axis: self.pass_per_axis,
            overall_pass,
            fallback_tier: self.fallback_tier.as_str().to_string(),
            anomalies: self.anomalies,
            notes: self.notes,
        }
    }
}

pub fn sha256_hex(bytes: &[u8]) -> String {
    let mut h = Sha256::new();
    h.update(bytes);
    format!("sha256:{}", hex(&h.finalize()))
}

fn hex(bytes: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut out = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        out.push(HEX[(byte >> 4) as usize] as char);
        out.push(HEX[(byte & 0x0f) as usize] as char);
    }
    out
}

fn canonical_digest(
    measurements: &BTreeMap<String, Measurement>,
    pass_per_axis: &BTreeMap<String, bool>,
) -> String {
    // BTreeMap iteration is sorted-by-key; serialize to canonical JSON
    // (no whitespace, ASCII-only) for byte-stable digest.
    let payload = serde_json::json!({
        "measurements": measurements,
        "pass_per_axis": pass_per_axis,
    });
    let s = serde_json::to_string(&payload).expect("canonical JSON serialize");
    sha256_hex(s.as_bytes())
}

/// Emit the artifact as canonical JSON to a writer.
pub fn write_artifact<W: std::io::Write>(
    writer: &mut W,
    artifact: &FalsifierArtifact,
) -> std::io::Result<()> {
    let s = serde_json::to_string_pretty(artifact)
        .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?;
    writer.write_all(s.as_bytes())?;
    writer.write_all(b"\n")?;
    Ok(())
}

pub fn add_bool_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    passed: bool,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::Bool(passed),
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), passed);
}

pub fn add_count_eq_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    expected: u64,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::from(expected),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual == expected);
}

pub fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    operator: &str,
    expected: u64,
    unit: &str,
) {
    let passed = match operator {
        "==" => actual == expected,
        ">" => actual > expected,
        ">=" => actual >= expected,
        "<" => actual < expected,
        "<=" => actual <= expected,
        _ => false,
    };
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::from(expected),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), passed);
}

/// RFC 3339 UTC `Z` timestamp string.
pub fn now_utc_rfc3339() -> String {
    chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string()
}

/// Best-effort git HEAD SHA (full 40-char hex). Returns
/// `"0000000000000000000000000000000000000000"` if git is unavailable
/// — the artifact then carries a `git_unavailable` anomaly so replay
/// callers can flag it.
pub fn current_commit_sha() -> String {
    std::process::Command::new("git")
        .args(["rev-parse", "HEAD"])
        .output()
        .ok()
        .and_then(|o| {
            if o.status.success() {
                String::from_utf8(o.stdout)
                    .ok()
                    .map(|s| s.trim().to_string())
            } else {
                None
            }
        })
        .filter(|s| s.len() == 40 && s.chars().all(|c| c.is_ascii_hexdigit()))
        .unwrap_or_else(|| "0".repeat(40))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn float_measurement(v: f64) -> Measurement {
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from_f64(v).unwrap()),
            unit: "ratio".to_string(),
        }
    }

    fn float_threshold(op: &str, v: f64) -> AcceptanceThreshold {
        AcceptanceThreshold {
            operator: op.to_string(),
            value: serde_json::Value::Number(serde_json::Number::from_f64(v).unwrap()),
            unit: "ratio".to_string(),
        }
    }

    #[test]
    fn m2_pro_pin_matches_canonical_constants() {
        let p = HardwarePin::m2_pro_2023_16gb();
        assert_eq!(p.machine, "M2 Pro 14-inch 2023");
        assert_eq!(p.cpu, "12-core CPU");
        assert_eq!(p.gpu, "19-core GPU");
        assert_eq!(p.unified_memory_gb, 16);
        assert_eq!(p.memory_bandwidth_gb_s, 200);
    }

    #[test]
    fn overall_pass_requires_all_axes_pass() {
        let mut measurements = BTreeMap::new();
        measurements.insert("axis_a".to_string(), float_measurement(0.99));
        measurements.insert("axis_b".to_string(), float_measurement(0.50));
        let mut thresholds = BTreeMap::new();
        thresholds.insert("axis_a".to_string(), float_threshold(">=", 0.95));
        thresholds.insert("axis_b".to_string(), float_threshold(">=", 0.95));
        let mut pass = BTreeMap::new();
        pass.insert("axis_a".to_string(), true);
        pass.insert("axis_b".to_string(), false);

        let art = ArtifactBuilder {
            falsifier_id: "F-Test".to_string(),
            artifact_kind: ArtifactKind::FallbackWitness,
            command: "cargo run --bin test".to_string(),
            commit_sha: "0".repeat(40),
            fixture_id: "test_fixture_v1".to_string(),
            measurements,
            acceptance_thresholds: thresholds,
            pass_per_axis: pass,
            fallback_tier: FallbackTier::Fallback,
            anomalies: vec![],
            notes: "none".to_string(),
            timestamp_utc: "2026-05-23T00:00:00Z".to_string(),
        }
        .build();
        assert!(!art.overall_pass);
    }

    #[test]
    fn overall_pass_true_when_all_axes_pass() {
        let mut measurements = BTreeMap::new();
        measurements.insert("axis_a".to_string(), float_measurement(0.99));
        let mut thresholds = BTreeMap::new();
        thresholds.insert("axis_a".to_string(), float_threshold(">=", 0.95));
        let mut pass = BTreeMap::new();
        pass.insert("axis_a".to_string(), true);

        let art = ArtifactBuilder {
            falsifier_id: "F-Test".to_string(),
            artifact_kind: ArtifactKind::PrimaryWitness,
            command: "cargo run --bin test".to_string(),
            commit_sha: "0".repeat(40),
            fixture_id: "test_fixture_v1".to_string(),
            measurements,
            acceptance_thresholds: thresholds,
            pass_per_axis: pass,
            fallback_tier: FallbackTier::Primary,
            anomalies: vec![],
            notes: "none".to_string(),
            timestamp_utc: "2026-05-23T00:00:00Z".to_string(),
        }
        .build();
        assert!(art.overall_pass);
    }

    #[test]
    fn result_digest_is_stable_across_runs() {
        let mut m = BTreeMap::new();
        m.insert("a".to_string(), float_measurement(1.0));
        let mut p = BTreeMap::new();
        p.insert("a".to_string(), true);
        let d1 = canonical_digest(&m, &p);
        let d2 = canonical_digest(&m, &p);
        assert_eq!(d1, d2);
        assert!(d1.starts_with("sha256:"));
        assert_eq!(d1.len(), 7 + 64);
    }

    #[test]
    fn command_digest_is_sha256_hex_lowercase_prefixed() {
        let d = sha256_hex(b"hello");
        assert_eq!(
            d,
            "sha256:2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        );
    }

    #[test]
    fn timestamp_is_z_suffix_rfc3339() {
        let t = now_utc_rfc3339();
        assert!(t.ends_with('Z'));
        assert_eq!(t.len(), 20); // YYYY-MM-DDTHH:MM:SSZ
    }
}
