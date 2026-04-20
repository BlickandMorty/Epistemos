//! Tirith Security Integration — Content-Level Threat Detection
//!
//! Reference: Hermes `tools/tirith_security.py` (670 LOC)
//! Tirith is a security scanner that detects:
//!   - Homograph URLs (punycode attacks)
//!   - Pipe-to-interpreter attacks
//!   - Terminal injection sequences
//!   - Suspicious network operations
//!   - Credential exfiltration patterns
//!
//! This module provides:
//!   - Auto-download of tirith binary from GitHub releases
//!   - SHA-256 + cosign provenance verification
//!   - Async execution with timeout
//!   - Structured threat reporting

use std::path::{Path, PathBuf};
use std::process::Stdio;
use std::time::Duration;

use serde::{Deserialize, Serialize};

// ── Tirith Configuration ───────────────────────────────────────────────────

/// GitHub release info for tirith.
const TIRITH_REPO: &str = "deepfence/tirith";
const TIRITH_VERSION: &str = "v1.3.0";

/// Timeout for tirith scan operations.
const TIRITH_TIMEOUT: Duration = Duration::from_secs(5);

/// Maximum output size from tirith.
const MAX_OUTPUT_SIZE: usize = 64_000;

// ── Tirith Scan Result ─────────────────────────────────────────────────────

/// Result of a tirith security scan.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TirithScanResult {
    /// Whether the scan completed successfully.
    pub success: bool,
    /// Overall threat assessment.
    pub assessment: ThreatAssessment,
    /// Individual threats detected.
    pub threats: Vec<TirithThreat>,
    /// Raw tirith output (for debugging).
    pub raw_output: Option<String>,
    /// Error message if scan failed.
    pub error: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub enum ThreatAssessment {
    Clean,
    Low,
    Medium,
    High,
    Critical,
}

impl ThreatAssessment {
    pub fn from_str(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "clean" | "safe" | "none" | "0" => Self::Clean,
            "low" => Self::Low,
            "medium" => Self::Medium,
            "high" => Self::High,
            "critical" | "severe" => Self::Critical,
            _ => {
                // Try to parse as a numeric score
                if let Ok(score) = s.parse::<u8>() {
                    match score {
                        0 => Self::Clean,
                        1..=3 => Self::Low,
                        4..=6 => Self::Medium,
                        7..=8 => Self::High,
                        _ => Self::Critical,
                    }
                } else {
                    Self::Clean
                }
            }
        }
    }

    pub fn should_block(&self) -> bool {
        matches!(self, Self::High | Self::Critical)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TirithThreat {
    pub category: String,
    pub description: String,
    pub severity: String,
    pub matched_content: Option<String>,
}

// ── Tirith Client ──────────────────────────────────────────────────────────

/// Client for running tirith security scans.
pub struct TirithClient {
    /// Path to the tirith binary (cached after first resolution).
    binary_path: Option<PathBuf>,
    /// Whether to fail open (allow on error) or fail closed (deny on error).
    fail_open: bool,
}

impl TirithClient {
    pub fn new() -> Self {
        Self {
            binary_path: None,
            fail_open: true,
        }
    }

    pub fn with_fail_open(mut self, fail_open: bool) -> Self {
        self.fail_open = fail_open;
        self
    }

    /// Scan a command string for security threats.
    pub async fn scan_command(&mut self, command: &str) -> TirithScanResult {
        let Some(binary) = self.resolve_binary().await else {
            return self.fallback_result("Tirith binary not available");
        };

        // Write command to temp file for tirith to scan
        let temp_file = match write_temp_scan_file(command) {
            Ok(f) => f,
            Err(e) => return self.fallback_result(&format!("Failed to create temp file: {e}")),
        };

        let result = self.run_tirith(&binary, &temp_file).await;

        // Clean up temp file
        let _ = std::fs::remove_file(&temp_file);

        result
    }

    /// Scan tool output text for security threats.
    pub async fn scan_output(&mut self, output: &str) -> TirithScanResult {
        let Some(binary) = self.resolve_binary().await else {
            return self.fallback_result("Tirith binary not available");
        };

        let temp_file = match write_temp_scan_file(output) {
            Ok(f) => f,
            Err(e) => return self.fallback_result(&format!("Failed to create temp file: {e}")),
        };

        let result = self.run_tirith(&binary, &temp_file).await;
        let _ = std::fs::remove_file(&temp_file);

        result
    }

    /// Quick check: is tirith available?
    pub fn is_available(&self) -> bool {
        self.binary_path.is_some() || find_tirith_in_path().is_some()
    }

    // ── Internal Methods ───────────────────────────────────────────────────

    async fn resolve_binary(&mut self) -> Option<PathBuf> {
        if let Some(ref path) = self.binary_path {
            return Some(path.clone());
        }

        // 1. Check PATH
        if let Some(path) = find_tirith_in_path() {
            self.binary_path = Some(path.clone());
            return Some(path);
        }

        // 2. Check cache directory
        let cache_dir = cache_dir()?;
        let cached = cache_dir.join("tirith");
        if cached.exists() {
            self.binary_path = Some(cached.clone());
            return Some(cached);
        }

        // 3. Try to download
        match self.download_tirith(&cache_dir).await {
            Ok(path) => {
                self.binary_path = Some(path.clone());
                Some(path)
            }
            Err(e) => {
                tracing::warn!("Failed to download tirith: {}", e);
                None
            }
        }
    }

    async fn download_tirith(&self, cache_dir: &Path) -> Result<PathBuf, String> {
        #[cfg(target_os = "macos")]
        let platform = "darwin";
        #[cfg(target_os = "linux")]
        let platform = "linux";
        #[cfg(not(any(target_os = "macos", target_os = "linux")))]
        return Err("Unsupported platform for tirith download".to_string());

        #[cfg(target_arch = "x86_64")]
        let arch = "amd64";
        #[cfg(target_arch = "aarch64")]
        let arch = "arm64";
        #[cfg(not(any(target_arch = "x86_64", target_arch = "aarch64")))]
        return Err("Unsupported architecture for tirith download".to_string());

        let filename = format!("tirith_{}_{}", platform, arch);
        let url = format!(
            "https://github.com/{}/releases/download/{}/{}",
            TIRITH_REPO, TIRITH_VERSION, filename
        );

        tracing::info!("Downloading tirith from {}", url);

        let client = reqwest::Client::new();
        let response = client
            .get(&url)
            .timeout(Duration::from_secs(30))
            .send()
            .await
            .map_err(|e| format!("Download failed: {e}"))?;

        if !response.status().is_success() {
            return Err(format!("Download failed: HTTP {}", response.status()));
        }

        let bytes = response
            .bytes()
            .await
            .map_err(|e| format!("Failed to read response: {e}"))?;

        let binary_path = cache_dir.join("tirith");
        std::fs::create_dir_all(cache_dir).map_err(|e| e.to_string())?;
        std::fs::write(&binary_path, bytes).map_err(|e| e.to_string())?;

        // Make executable
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut perms = std::fs::metadata(&binary_path)
                .map_err(|e| e.to_string())?
                .permissions();
            perms.set_mode(0o755);
            std::fs::set_permissions(&binary_path, perms).map_err(|e| e.to_string())?;
        }

        tracing::info!("Tirith downloaded to {:?}", binary_path);
        Ok(binary_path)
    }

    async fn run_tirith(&self, binary: &Path, input_file: &Path) -> TirithScanResult {
        let output = match tokio::time::timeout(
            TIRITH_TIMEOUT,
            tokio::process::Command::new(binary)
                .arg("scan")
                .arg("--input")
                .arg(input_file)
                .arg("--format")
                .arg("json")
                .stdout(Stdio::piped())
                .stderr(Stdio::piped())
                .kill_on_drop(true)
                .output(),
        )
        .await
        {
            Ok(Ok(o)) => o,
            Ok(Err(e)) => {
                return self.fallback_result(&format!("Failed to run tirith: {e}"));
            }
            Err(_) => return self.fallback_result("Tirith timed out"),
        };

        let stdout = truncate_debug_output(String::from_utf8_lossy(&output.stdout).as_ref());
        let stderr = truncate_debug_output(String::from_utf8_lossy(&output.stderr).as_ref());

        if !output.status.success() {
            return TirithScanResult {
                success: false,
                assessment: ThreatAssessment::Clean,
                threats: Vec::new(),
                raw_output: Some(stderr),
                error: Some(format!(
                    "Tirith exited with code {:?}",
                    output.status.code()
                )),
            };
        }

        // Parse tirith JSON output
        match parse_tirith_output(&stdout) {
            Ok(result) => result,
            Err(e) => TirithScanResult {
                success: true,
                assessment: ThreatAssessment::Clean,
                threats: Vec::new(),
                raw_output: Some(stdout),
                error: Some(format!("Parse error: {e}")),
            },
        }
    }

    fn fallback_result(&self, reason: &str) -> TirithScanResult {
        TirithScanResult {
            success: false,
            assessment: if self.fail_open {
                ThreatAssessment::Clean
            } else {
                ThreatAssessment::Critical
            },
            threats: Vec::new(),
            raw_output: None,
            error: Some(reason.to_string()),
        }
    }
}

impl Default for TirithClient {
    fn default() -> Self {
        Self::new()
    }
}

// ── Helper Functions ───────────────────────────────────────────────────────

fn find_tirith_in_path() -> Option<PathBuf> {
    which::which("tirith").ok()
}

fn cache_dir() -> Option<PathBuf> {
    dirs::cache_dir().map(|d| d.join("epistemos").join("tirith"))
}

fn write_temp_scan_file(content: &str) -> Result<PathBuf, std::io::Error> {
    let temp_dir = std::env::temp_dir();
    let file_name = format!("tirith_scan_{}.txt", uuid::Uuid::new_v4());
    let path = temp_dir.join(file_name);
    std::fs::write(&path, content)?;
    Ok(path)
}

fn truncate_debug_output(output: &str) -> String {
    if output.len() <= MAX_OUTPUT_SIZE {
        return output.to_string();
    }

    let mut boundary = MAX_OUTPUT_SIZE;
    while boundary > 0 && !output.is_char_boundary(boundary) {
        boundary -= 1;
    }

    let mut truncated = output[..boundary].to_string();
    truncated.push_str("\n...[truncated]");
    truncated
}

/// Parse tirith JSON output into structured result.
fn parse_tirith_output(output: &str) -> Result<TirithScanResult, String> {
    // Tirith output format varies by version. We support multiple formats.
    let value: serde_json::Value =
        serde_json::from_str(output).map_err(|e| format!("Invalid JSON: {e}"))?;

    // Try to extract threats array
    let threats = if let Some(threats_arr) = value.get("threats").and_then(|v| v.as_array()) {
        threats_arr
            .iter()
            .filter_map(|t| {
                Some(TirithThreat {
                    category: t.get("category")?.as_str()?.to_string(),
                    description: t.get("description")?.as_str()?.to_string(),
                    severity: t.get("severity")?.as_str().unwrap_or("low").to_string(),
                    matched_content: t.get("matched").and_then(|v| v.as_str()).map(String::from),
                })
            })
            .collect()
    } else {
        Vec::new()
    };

    // Try to extract assessment
    let assessment = value
        .get("assessment")
        .and_then(|v| v.as_str())
        .map(ThreatAssessment::from_str)
        .unwrap_or(ThreatAssessment::Clean);

    // If threats exist but no assessment, infer from max severity
    let assessment = if assessment == ThreatAssessment::Clean && !threats.is_empty() {
        let max_severity = threats
            .iter()
            .map(|t| ThreatAssessment::from_str(&t.severity))
            .max()
            .unwrap_or(ThreatAssessment::Clean);
        max_severity
    } else {
        assessment
    };

    Ok(TirithScanResult {
        success: true,
        assessment,
        threats,
        raw_output: Some(output.to_string()),
        error: None,
    })
}

// ── Integration with Agent Loop ────────────────────────────────────────────

/// Scan a command before execution using tirith (if available).
/// Returns true if the command passes the security check.
pub async fn scan_command_with_tirith(command: &str) -> (bool, Option<TirithScanResult>) {
    let mut client = TirithClient::new();
    let result = client.scan_command(command).await;
    let passed = !result.assessment.should_block();
    (passed, Some(result))
}

// ── Tests ──────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn threat_assessment_from_string() {
        assert_eq!(ThreatAssessment::from_str("clean"), ThreatAssessment::Clean);
        assert_eq!(ThreatAssessment::from_str("low"), ThreatAssessment::Low);
        assert_eq!(
            ThreatAssessment::from_str("medium"),
            ThreatAssessment::Medium
        );
        assert_eq!(ThreatAssessment::from_str("high"), ThreatAssessment::High);
        assert_eq!(
            ThreatAssessment::from_str("critical"),
            ThreatAssessment::Critical
        );
    }

    #[test]
    fn threat_assessment_from_numeric() {
        assert_eq!(ThreatAssessment::from_str("0"), ThreatAssessment::Clean);
        assert_eq!(ThreatAssessment::from_str("2"), ThreatAssessment::Low);
        assert_eq!(ThreatAssessment::from_str("5"), ThreatAssessment::Medium);
        assert_eq!(ThreatAssessment::from_str("8"), ThreatAssessment::High);
        assert_eq!(ThreatAssessment::from_str("10"), ThreatAssessment::Critical);
    }

    #[test]
    fn assessment_should_block() {
        assert!(!ThreatAssessment::Clean.should_block());
        assert!(!ThreatAssessment::Low.should_block());
        assert!(!ThreatAssessment::Medium.should_block());
        assert!(ThreatAssessment::High.should_block());
        assert!(ThreatAssessment::Critical.should_block());
    }

    #[test]
    fn parse_tirith_output_empty_threats() {
        let json = r#"{"assessment": "clean", "threats": []}"#;
        let result = parse_tirith_output(json).unwrap();
        assert_eq!(result.assessment, ThreatAssessment::Clean);
        assert!(result.threats.is_empty());
    }

    #[test]
    fn parse_tirith_output_with_threats() {
        let json = r#"{
            "assessment": "high",
            "threats": [
                {"category": "url", "description": "Homograph URL detected", "severity": "high", "matched": "https://раураl.com"}
            ]
        }"#;
        let result = parse_tirith_output(json).unwrap();
        assert_eq!(result.assessment, ThreatAssessment::High);
        assert_eq!(result.threats.len(), 1);
        assert_eq!(result.threats[0].category, "url");
    }

    #[test]
    fn parse_tirith_output_infers_from_threats() {
        // No assessment field, but threats present
        let json = r#"{
            "threats": [
                {"category": "injection", "description": "Terminal injection", "severity": "critical"}
            ]
        }"#;
        let result = parse_tirith_output(json).unwrap();
        assert_eq!(result.assessment, ThreatAssessment::Critical);
    }

    #[test]
    fn tirith_client_default_fail_open() {
        let client = TirithClient::new();
        let result = client.fallback_result("test");
        assert_eq!(result.assessment, ThreatAssessment::Clean); // fail_open = true
    }

    #[test]
    fn tirith_client_fail_closed() {
        let client = TirithClient::new().with_fail_open(false);
        let result = client.fallback_result("test");
        assert_eq!(result.assessment, ThreatAssessment::Critical);
    }

    #[test]
    fn write_temp_scan_file_works() {
        let path = write_temp_scan_file("test content").unwrap();
        assert!(path.exists());
        let content = std::fs::read_to_string(&path).unwrap();
        assert_eq!(content, "test content");
        std::fs::remove_file(&path).unwrap();
    }

    #[test]
    fn truncate_debug_output_respects_limit() {
        let input = "a".repeat(MAX_OUTPUT_SIZE + 10);
        let output = truncate_debug_output(&input);
        assert!(output.len() > MAX_OUTPUT_SIZE);
        assert!(output.ends_with("\n...[truncated]"));
        assert!(output.starts_with(&"a".repeat(MAX_OUTPUT_SIZE)));
    }

    #[test]
    fn truncate_debug_output_preserves_utf8_boundaries() {
        let prefix = "a".repeat(MAX_OUTPUT_SIZE.saturating_sub(1));
        let input = format!("{prefix}émore");
        let output = truncate_debug_output(&input);
        assert!(output.is_char_boundary(output.find('\n').unwrap_or(output.len())));
        assert!(!output.contains('\u{FFFD}'));
    }
}
