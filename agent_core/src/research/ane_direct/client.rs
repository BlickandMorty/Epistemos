//! Source: see `super::` rustdoc for citation context. This module owns
//! the ANE client trait surface + the in-memory mock.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum AneStatus {
    /// `_ANEClient` private framework available + Pro entitlement
    /// `cs.disable-library-validation` present.
    Available,
    /// Framework or entitlement missing. Callers fall back to GPU/CPU.
    NotAvailable,
}

impl AneStatus {
    pub const ALL: [AneStatus; 2] = [AneStatus::Available, AneStatus::NotAvailable];

    pub const fn code(self) -> &'static str {
        match self {
            AneStatus::Available => "available",
            AneStatus::NotAvailable => "not_available",
        }
    }

    /// Reverse lookup for [`Self::code`].
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|s| s.code() == code)
    }

    /// Predicate. Cross-surface invariant: `is_available iff
    /// !is_not_available` and matches probe()'s return.
    pub const fn is_available(self) -> bool {
        matches!(self, AneStatus::Available)
    }

    pub const fn is_not_available(self) -> bool {
        matches!(self, AneStatus::NotAvailable)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct AneTelemetry {
    /// Aggregate power in watts via SMC. Approximate; not per-op.
    pub power_watts: f32,
    /// Clock frequency in Hz via IOKit `AppleARMIODevice`.
    pub frequency_hz: u64,
    /// Derived `power / max_power` in `[0.0, 1.0]`. Suitable for a
    /// "ANE busy?" UI; do NOT use for performance attribution.
    pub derived_utilization: f32,
}

impl AneTelemetry {
    /// Predicate: `derived_utilization < threshold`. The "is the ANE
    /// available for new work?" check.
    pub fn is_idle_below(&self, threshold: f32) -> bool {
        self.derived_utilization < threshold
    }

    /// Predicate: `derived_utilization ∈ [0.0, 1.0]`. The construction
    /// invariant (also checked by [`MockAneClient::telemetry`]).
    pub fn is_utilization_in_range(&self) -> bool {
        (0.0..=1.0).contains(&self.derived_utilization)
    }
}

impl AneCapabilities {
    /// Convert the hundredths-INT storage to a floating-point TOPS
    /// rating. Cross-surface invariant: `max_int8_tops()` equals
    /// `max_int8_tops_hundredths / 100` exactly.
    pub fn max_int8_tops(&self) -> f32 {
        self.max_int8_tops_hundredths as f32 / 100.0
    }

    /// Predicate: this device has at least one ANE core. The Pro-
    /// gating check: NotAvailable mocks set core_count to 0.
    pub const fn has_cores(&self) -> bool {
        self.core_count > 0
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct AneCapabilities {
    /// Total ANE core count (M2 Pro = 16, M2 Max = 16, M2 Ultra = 32).
    pub core_count: u8,
    /// Max sustained TOPS (M2 Pro ≈ 15.8 INT8, M2 Max ≈ 15.8 INT8).
    /// Floor-stored as int to avoid fp imprecision in serde.
    pub max_int8_tops_hundredths: u32,
    /// Whether the runtime can dispatch ml-package precompiled models.
    pub supports_ml_package: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum AneDirectError {
    /// Caller invoked an ANE op but `probe()` returned NotAvailable.
    NotAvailable,
    /// `derived_utilization` was outside `[0.0, 1.0]`.
    DerivedUtilizationOutOfRange { value: f32 },
}

impl AneDirectError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            AneDirectError::NotAvailable => "not_available",
            AneDirectError::DerivedUtilizationOutOfRange { .. } => {
                "derived_utilization_out_of_range"
            }
        }
    }

    pub const fn is_not_available(&self) -> bool {
        matches!(self, AneDirectError::NotAvailable)
    }

    /// Cross-surface invariant: `is_not_available XOR
    /// is_utilization_out_of_range` partitions all variants.
    pub const fn is_utilization_out_of_range(&self) -> bool {
        matches!(self, AneDirectError::DerivedUtilizationOutOfRange { .. })
    }
}

/// Trait the future `_ANEClient` Pro-gated binding will impl. The
/// substrate floor exposes only the read-only / telemetry surface —
/// dispatch (compile model + run inference) lands when the binding
/// itself lands.
pub trait AneClient {
    fn probe(&self) -> AneStatus;
    fn telemetry(&self) -> Result<AneTelemetry, AneDirectError>;
    fn capabilities(&self) -> Result<AneCapabilities, AneDirectError>;
}

/// In-memory mock for substrate testing. The Pro-gated real impl will
/// live in `agent_core/src/research/ane_direct/` behind a
/// `#[cfg(feature = "pro-build")]` module.
#[derive(Clone, Debug, PartialEq)]
pub struct MockAneClient {
    pub status: AneStatus,
    pub telemetry: AneTelemetry,
    pub capabilities: AneCapabilities,
}

impl MockAneClient {
    /// Canned "M2 Pro idle" mock.
    pub fn idle_m2_pro() -> Self {
        Self {
            status: AneStatus::Available,
            telemetry: AneTelemetry {
                power_watts: 0.1,
                frequency_hz: 0,
                derived_utilization: 0.0,
            },
            capabilities: AneCapabilities {
                core_count: 16,
                max_int8_tops_hundredths: 1_580,
                supports_ml_package: true,
            },
        }
    }

    pub fn busy_m2_pro() -> Self {
        Self {
            status: AneStatus::Available,
            telemetry: AneTelemetry {
                power_watts: 4.5,
                frequency_hz: 1_300_000_000,
                derived_utilization: 0.75,
            },
            capabilities: Self::idle_m2_pro().capabilities,
        }
    }

    pub fn not_available() -> Self {
        Self {
            status: AneStatus::NotAvailable,
            telemetry: AneTelemetry {
                power_watts: 0.0,
                frequency_hz: 0,
                derived_utilization: 0.0,
            },
            capabilities: AneCapabilities {
                core_count: 0,
                max_int8_tops_hundredths: 0,
                supports_ml_package: false,
            },
        }
    }
}

impl AneClient for MockAneClient {
    fn probe(&self) -> AneStatus {
        self.status
    }

    fn telemetry(&self) -> Result<AneTelemetry, AneDirectError> {
        if self.status == AneStatus::NotAvailable {
            return Err(AneDirectError::NotAvailable);
        }
        if !(0.0..=1.0).contains(&self.telemetry.derived_utilization) {
            return Err(AneDirectError::DerivedUtilizationOutOfRange {
                value: self.telemetry.derived_utilization,
            });
        }
        Ok(self.telemetry)
    }

    fn capabilities(&self) -> Result<AneCapabilities, AneDirectError> {
        if self.status == AneStatus::NotAvailable {
            return Err(AneDirectError::NotAvailable);
        }
        Ok(self.capabilities)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn idle_m2_pro_mock_reports_available_and_low_power() {
        let m = MockAneClient::idle_m2_pro();
        assert_eq!(m.probe(), AneStatus::Available);
        let t = m.telemetry().unwrap();
        assert!(t.power_watts < 1.0);
        assert_eq!(t.derived_utilization, 0.0);
    }

    #[test]
    fn busy_m2_pro_mock_reports_nonzero_utilization() {
        let m = MockAneClient::busy_m2_pro();
        let t = m.telemetry().unwrap();
        assert!(t.derived_utilization > 0.0);
        assert!(t.derived_utilization <= 1.0);
        assert!(t.power_watts > 1.0);
    }

    #[test]
    fn not_available_mock_rejects_telemetry() {
        let m = MockAneClient::not_available();
        assert_eq!(m.probe(), AneStatus::NotAvailable);
        let err = m.telemetry().unwrap_err();
        assert_eq!(err, AneDirectError::NotAvailable);
    }

    #[test]
    fn not_available_mock_rejects_capabilities() {
        let m = MockAneClient::not_available();
        let err = m.capabilities().unwrap_err();
        assert_eq!(err, AneDirectError::NotAvailable);
    }

    #[test]
    fn derived_utilization_out_of_range_errors() {
        let mut m = MockAneClient::idle_m2_pro();
        m.telemetry.derived_utilization = 1.5;
        let err = m.telemetry().unwrap_err();
        assert_eq!(
            err,
            AneDirectError::DerivedUtilizationOutOfRange { value: 1.5 }
        );
    }

    #[test]
    fn capabilities_reports_m2_pro_core_count() {
        let m = MockAneClient::idle_m2_pro();
        let c = m.capabilities().unwrap();
        assert_eq!(c.core_count, 16);
        assert!(c.supports_ml_package);
    }

    #[test]
    fn max_int8_tops_in_hundredths_is_about_15_8() {
        let m = MockAneClient::idle_m2_pro();
        let c = m.capabilities().unwrap();
        let tops_float = (c.max_int8_tops_hundredths as f32) / 100.0;
        assert!((tops_float - 15.8).abs() < 0.5);
    }

    #[test]
    fn telemetry_roundtrips_through_serde_json() {
        let t = MockAneClient::busy_m2_pro().telemetry().unwrap();
        let json = serde_json::to_string(&t).unwrap();
        let back: AneTelemetry = serde_json::from_str(&json).unwrap();
        assert_eq!(t, back);
    }

    #[test]
    fn capabilities_roundtrips_through_serde_json() {
        let c = MockAneClient::idle_m2_pro().capabilities().unwrap();
        let json = serde_json::to_string(&c).unwrap();
        let back: AneCapabilities = serde_json::from_str(&json).unwrap();
        assert_eq!(c, back);
    }

    #[test]
    fn status_roundtrips_through_serde_json() {
        let s = AneStatus::Available;
        let json = serde_json::to_string(&s).unwrap();
        let back: AneStatus = serde_json::from_str(&json).unwrap();
        assert_eq!(s, back);
    }

    #[test]
    fn busy_below_max_utilization() {
        let m = MockAneClient::busy_m2_pro();
        assert!(m.telemetry.derived_utilization < 1.0);
    }

    #[test]
    fn idle_to_busy_to_idle_lifecycle() {
        let idle = MockAneClient::idle_m2_pro();
        let busy = MockAneClient::busy_m2_pro();
        assert!(idle.telemetry.power_watts < busy.telemetry.power_watts);
        assert!(idle.telemetry.derived_utilization < busy.telemetry.derived_utilization);
        assert_eq!(idle.capabilities, busy.capabilities);
    }

    // ── diagnostic surface (iter 194) ────────────────────────────────────────

    #[test]
    fn status_from_code_roundtrips_all() {
        for s in AneStatus::ALL.iter().copied() {
            assert_eq!(AneStatus::from_code(s.code()), Some(s));
        }
        assert_eq!(AneStatus::from_code("Available"), None);
    }

    #[test]
    fn status_is_available_xor_not_available() {
        // Cross-surface invariant.
        for s in AneStatus::ALL.iter().copied() {
            assert_ne!(s.is_available(), s.is_not_available());
        }
    }

    #[test]
    fn status_is_available_matches_probe() {
        // Cross-surface invariant: AneStatus::is_available agrees with
        // the value returned by AneClient::probe.
        let m = MockAneClient::idle_m2_pro();
        assert!(m.probe().is_available());
        let m = MockAneClient::not_available();
        assert!(!m.probe().is_available());
        assert!(m.probe().is_not_available());
    }

    #[test]
    fn telemetry_is_idle_below_threshold() {
        let m = MockAneClient::idle_m2_pro();
        let t = m.telemetry().unwrap();
        assert!(t.is_idle_below(0.1));
        assert!(t.is_idle_below(1.0));
        let m = MockAneClient::busy_m2_pro();
        let t = m.telemetry().unwrap();
        assert!(!t.is_idle_below(0.5)); // busy = 0.75
    }

    #[test]
    fn telemetry_utilization_in_range_for_mocks() {
        for m in [MockAneClient::idle_m2_pro(), MockAneClient::busy_m2_pro()] {
            assert!(m.telemetry.is_utilization_in_range());
        }
    }

    #[test]
    fn telemetry_out_of_range_invariant_fires() {
        let mut m = MockAneClient::idle_m2_pro();
        m.telemetry.derived_utilization = 1.5;
        assert!(!m.telemetry.is_utilization_in_range());
    }

    #[test]
    fn capabilities_max_int8_tops_matches_hundredths_div_100() {
        // Cross-surface invariant.
        let m = MockAneClient::idle_m2_pro();
        let c = m.capabilities().unwrap();
        let expected = c.max_int8_tops_hundredths as f32 / 100.0;
        assert!((c.max_int8_tops() - expected).abs() < 1e-9);
        assert!((c.max_int8_tops() - 15.8).abs() < 0.5);
    }

    #[test]
    fn capabilities_has_cores_false_for_not_available() {
        let m = MockAneClient::not_available();
        // Direct access since capabilities() returns NotAvailable error.
        assert!(!m.capabilities.has_cores());
        // Available mock has cores.
        let m = MockAneClient::idle_m2_pro();
        assert!(m.capabilities.has_cores());
    }

    #[test]
    fn ane_direct_error_classifiers_partition() {
        let variants = [
            AneDirectError::NotAvailable,
            AneDirectError::DerivedUtilizationOutOfRange { value: 1.5 },
        ];
        // Cross-surface invariant: is_not_available XOR is_utilization_out_of_range.
        for e in variants {
            assert_ne!(e.is_not_available(), e.is_utilization_out_of_range());
        }
        assert_eq!(variants[0].cause(), "not_available");
        assert_eq!(variants[1].cause(), "derived_utilization_out_of_range");
    }
}
