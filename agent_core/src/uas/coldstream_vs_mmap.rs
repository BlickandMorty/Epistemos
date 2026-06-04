//! ColdStream-vs-mmap benchmark-plan contracts.
//!
//! This is a metadata-only benchmark table witness. It proves that the
//! ColdStream-vs-mmap comparison is same-fixture, visible, bounded, and
//! rollback-safe before any live mmap/pread/ColdStream benchmark can promote.

use std::collections::{BTreeSet, HashMap, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const COLDSTREAM_VS_MMAP_CURSOR: &str = "coldstream_vs_mmap";
pub const COLDSTREAM_VS_MMAP_NEXT_CURSOR: &str = "slab_arena_copy_count";

const BENCHMARK_PLAN_PREFIX: &str = "benchmark_plan:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ROLLBACK_PREFIX: &str = "rollback:";
const ADMISSION_PREFIX: &str = "admission:";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const CANCEL_GROUP_PREFIX: &str = "cancel_group:";
const FALLBACK_PREFIX: &str = "fallback:";
const SOURCE_PREFIX: &str = "official_source:";
const MIN_VISIBLE_SUMMARY_BYTES: usize = 128;
const MAX_METADATA_BYTES: u64 = 256 * 1024;
const MAX_COPY_COUNT: u32 = 2;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:coldstream-vs-mmap:baseline-kind
// Plane: Verification
// Residency: metadata-only baseline label; no runtime bytes move.
pub enum ColdStreamBaselineKind {
    MmapFault,
    NaivePread,
    ColdStreamPlan,
}

impl ColdStreamBaselineKind {
    fn tag(&self) -> &'static str {
        match self {
            Self::MmapFault => "mmap_fault",
            Self::NaivePread => "naive_pread",
            Self::ColdStreamPlan => "coldstream_plan",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:coldstream-vs-mmap:error
// Plane: Verification
// Residency: metadata-only rejection taxonomy.
pub enum ColdStreamVsMmapError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptyFixture,
    EmptyBaselineRow(String),
    EmptySurface,
    DuplicateFixture(String),
    DuplicateSurface(String),
    DuplicateAnswerPacket(String),
    DuplicateBaselineRow(String),
    MissingBaseline(String, ColdStreamBaselineKind),
    MissingBenchmarkPlanRef(String),
    MissingAnswerPacket(String),
    MissingRunEventLog(String),
    MissingRollback(String),
    MissingAdmission,
    MissingScopeRex,
    MissingSovereignGate,
    MissingCompatibilityFence(String),
    MissingCancelGroup(String),
    MissingFallback(String),
    MissingSurfaceRef(String),
    MissingOfficialSource(String),
    MissingRequiredMarker(String),
    ForbiddenMarker(String),
    MissingLayerSeparation,
    MissingVisibleSummary(String),
    P99BelowP95(String),
    ZeroBytes(String),
    ReadAmplificationInvalid(String),
    CopyBudgetExceeded(String),
    CancellationMissing(String),
    ColdStreamDoesNotBeatMmap(String),
    ColdStreamDoesNotBeatPread(String),
    FixtureIdMismatch(String),
    HiddenRouteAuthority,
    RoutePolicyMutation,
    ScopeRexBypass,
    SovereignGateBypass,
    AnswerPacketSuppression,
    HiddenChainExposure,
    HiddenCloudRoute,
    SsdAsRamClaim,
    ProductStatusMismatch,
    LiveBenchmarkAttempted,
    RuntimeBytesLoaded,
    ModelBytesLoaded,
    MetadataBudgetExceeded,
    BaselineUnbeaten(&'static str),
}

impl fmt::Display for ColdStreamVsMmapError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptyFixture => write!(f, "missing ColdStream-vs-mmap fixture"),
            Self::EmptyBaselineRow(id) => write!(f, "fixture `{id}` has no baseline rows"),
            Self::EmptySurface => write!(f, "missing visible benchmark surface"),
            Self::DuplicateFixture(id) => write!(f, "duplicate fixture `{id}`"),
            Self::DuplicateSurface(id) => write!(f, "duplicate surface `{id}`"),
            Self::DuplicateAnswerPacket(id) => write!(f, "duplicate AnswerPacket `{id}`"),
            Self::DuplicateBaselineRow(id) => write!(f, "duplicate baseline row `{id}`"),
            Self::MissingBaseline(id, kind) => {
                write!(f, "fixture `{id}` missing `{}` row", kind.tag())
            }
            Self::MissingBenchmarkPlanRef(id) => write!(f, "fixture `{id}` missing plan ref"),
            Self::MissingAnswerPacket(id) => write!(f, "fixture `{id}` missing AnswerPacket ref"),
            Self::MissingRunEventLog(id) => write!(f, "fixture `{id}` missing RunEventLog ref"),
            Self::MissingRollback(id) => write!(f, "fixture `{id}` missing rollback ref"),
            Self::MissingAdmission => write!(f, "missing admission ref"),
            Self::MissingScopeRex => write!(f, "missing SCOPE-Rex ref"),
            Self::MissingSovereignGate => write!(f, "missing SovereignGate ref"),
            Self::MissingCompatibilityFence(id) => {
                write!(f, "fixture `{id}` missing compatibility fence")
            }
            Self::MissingCancelGroup(id) => write!(f, "fixture `{id}` missing cancel group"),
            Self::MissingFallback(id) => write!(f, "fixture `{id}` missing fallback"),
            Self::MissingSurfaceRef(id) => write!(f, "fixture `{id}` has no surface"),
            Self::MissingOfficialSource(source) => write!(f, "missing source `{source}`"),
            Self::MissingRequiredMarker(marker) => write!(f, "missing marker `{marker}`"),
            Self::ForbiddenMarker(marker) => write!(f, "forbidden marker `{marker}`"),
            Self::MissingLayerSeparation => write!(f, "L1/L2/L3 separation missing"),
            Self::MissingVisibleSummary(id) => write!(f, "fixture `{id}` missing visible summary"),
            Self::P99BelowP95(id) => write!(f, "row `{id}` has p99 below p95"),
            Self::ZeroBytes(id) => write!(f, "row `{id}` has zero byte accounting"),
            Self::ReadAmplificationInvalid(id) => {
                write!(f, "row `{id}` has invalid read amplification")
            }
            Self::CopyBudgetExceeded(id) => write!(f, "row `{id}` exceeds copy budget"),
            Self::CancellationMissing(id) => write!(f, "fixture `{id}` missing cancellation proof"),
            Self::ColdStreamDoesNotBeatMmap(id) => {
                write!(f, "fixture `{id}` does not beat mmap baseline")
            }
            Self::ColdStreamDoesNotBeatPread(id) => {
                write!(f, "fixture `{id}` does not beat pread baseline")
            }
            Self::FixtureIdMismatch(id) => write!(f, "baseline row `{id}` has mismatched fixture"),
            Self::HiddenRouteAuthority => write!(f, "hidden route authority attempted"),
            Self::RoutePolicyMutation => write!(f, "route policy mutation attempted"),
            Self::ScopeRexBypass => write!(f, "SCOPE-Rex bypass attempted"),
            Self::SovereignGateBypass => write!(f, "SovereignGate bypass attempted"),
            Self::AnswerPacketSuppression => write!(f, "AnswerPacket suppression attempted"),
            Self::HiddenChainExposure => write!(f, "hidden chain exposure attempted"),
            Self::HiddenCloudRoute => write!(f, "hidden cloud route attempted"),
            Self::SsdAsRamClaim => write!(f, "SSD-as-RAM claim attempted"),
            Self::ProductStatusMismatch => write!(f, "product status promoted beyond Pro Research"),
            Self::LiveBenchmarkAttempted => write!(f, "metadata witness attempted live benchmark"),
            Self::RuntimeBytesLoaded => write!(f, "metadata witness loaded runtime bytes"),
            Self::ModelBytesLoaded => write!(f, "metadata witness loaded model bytes"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
            Self::BaselineUnbeaten(name) => write!(f, "baseline `{name}` was unbeaten"),
        }
    }
}

impl std::error::Error for ColdStreamVsMmapError {}

#[derive(Clone, Debug)]
// UAS: uas:coldstream-vs-mmap:baseline-row
// Plane: Verification
// Residency: metadata-only row; values are bounded synthetic measurements.
pub struct ColdStreamBaselineRow {
    pub row_id: String,
    pub fixture_id: String,
    pub kind: ColdStreamBaselineKind,
    pub bytes_requested: u64,
    pub bytes_read: u64,
    pub read_amplification_bps: u32,
    pub p95_stall_ms: u32,
    pub p99_stall_ms: u32,
    pub copy_count: u32,
}

impl ColdStreamBaselineRow {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        row_id: impl Into<String>,
        fixture_id: impl Into<String>,
        kind: ColdStreamBaselineKind,
        bytes_requested: u64,
        bytes_read: u64,
        read_amplification_bps: u32,
        p95_stall_ms: u32,
        p99_stall_ms: u32,
        copy_count: u32,
    ) -> Result<Self, ColdStreamVsMmapError> {
        let row = Self {
            row_id: row_id.into(),
            fixture_id: fixture_id.into(),
            kind,
            bytes_requested,
            bytes_read,
            read_amplification_bps,
            p95_stall_ms,
            p99_stall_ms,
            copy_count,
        };
        validate_row(&row)?;
        Ok(row)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:coldstream-vs-mmap:fixture
// Plane: Controller + Verification
// Residency: metadata-only comparison fixture; no file I/O is performed.
pub struct ColdStreamVsMmapFixture {
    pub fixture_id: String,
    pub benchmark_plan_ref: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub rollback_ref: String,
    pub admission_ref: String,
    pub scope_rex_ref: String,
    pub sovereign_gate_ref: String,
    pub compatibility_fence: String,
    pub cancel_group_ref: String,
    pub fallback_ref: String,
    pub visible_summary: String,
    pub rows: Vec<ColdStreamBaselineRow>,
    pub cancellation_count: u32,
    pub l1_l2_l3_separated: bool,
    pub hidden_route_authority: bool,
    pub route_policy_mutated: bool,
    pub scope_rex_bypassed: bool,
    pub sovereign_gate_bypassed: bool,
    pub answer_packet_suppressed: bool,
    pub hidden_chain_exposed: bool,
    pub hidden_cloud_route: bool,
    pub ssd_as_ram_claimed: bool,
    pub live_benchmark_attempted: bool,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub metadata_bytes: u64,
}

impl ColdStreamVsMmapFixture {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        fixture_id: impl Into<String>,
        benchmark_plan_ref: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        rollback_ref: impl Into<String>,
        admission_ref: impl Into<String>,
        scope_rex_ref: impl Into<String>,
        sovereign_gate_ref: impl Into<String>,
        compatibility_fence: impl Into<String>,
        cancel_group_ref: impl Into<String>,
        fallback_ref: impl Into<String>,
        visible_summary: impl Into<String>,
        rows: Vec<ColdStreamBaselineRow>,
        cancellation_count: u32,
        l1_l2_l3_separated: bool,
        hidden_route_authority: bool,
        route_policy_mutated: bool,
        scope_rex_bypassed: bool,
        sovereign_gate_bypassed: bool,
        answer_packet_suppressed: bool,
        hidden_chain_exposed: bool,
        hidden_cloud_route: bool,
        ssd_as_ram_claimed: bool,
        live_benchmark_attempted: bool,
        runtime_bytes_loaded: u64,
        model_bytes_loaded: u64,
        metadata_bytes: u64,
    ) -> Result<Self, ColdStreamVsMmapError> {
        let fixture = Self {
            fixture_id: fixture_id.into(),
            benchmark_plan_ref: benchmark_plan_ref.into(),
            answer_packet_ref: answer_packet_ref.into(),
            run_event_log_ref: run_event_log_ref.into(),
            rollback_ref: rollback_ref.into(),
            admission_ref: admission_ref.into(),
            scope_rex_ref: scope_rex_ref.into(),
            sovereign_gate_ref: sovereign_gate_ref.into(),
            compatibility_fence: compatibility_fence.into(),
            cancel_group_ref: cancel_group_ref.into(),
            fallback_ref: fallback_ref.into(),
            visible_summary: visible_summary.into(),
            rows,
            cancellation_count,
            l1_l2_l3_separated,
            hidden_route_authority,
            route_policy_mutated,
            scope_rex_bypassed,
            sovereign_gate_bypassed,
            answer_packet_suppressed,
            hidden_chain_exposed,
            hidden_cloud_route,
            ssd_as_ram_claimed,
            live_benchmark_attempted,
            runtime_bytes_loaded,
            model_bytes_loaded,
            metadata_bytes,
        };
        validate_fixture(&fixture)?;
        Ok(fixture)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:coldstream-vs-mmap:surface
// Plane: Verification
// Residency: visible proof text; metadata-only scan.
pub struct ColdStreamVsMmapSurface {
    pub surface_id: String,
    pub answer_packet_ref: String,
    pub visible_text: String,
    pub required_markers: Vec<String>,
    pub forbidden_markers: Vec<String>,
}

impl ColdStreamVsMmapSurface {
    pub fn new(
        surface_id: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        visible_text: impl Into<String>,
        required_markers: Vec<String>,
        forbidden_markers: Vec<String>,
    ) -> Result<Self, ColdStreamVsMmapError> {
        let surface = Self {
            surface_id: surface_id.into(),
            answer_packet_ref: answer_packet_ref.into(),
            visible_text: visible_text.into(),
            required_markers,
            forbidden_markers,
        };
        validate_surface(&surface)?;
        Ok(surface)
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
// UAS: uas:coldstream-vs-mmap:metrics
// Plane: Verification
// Residency: metadata-only aggregate metrics.
pub struct ColdStreamVsMmapMetrics {
    pub fixture_count: u64,
    pub baseline_row_count: u64,
    pub surface_count: u64,
    pub answer_packet_count: u64,
    pub run_event_log_count: u64,
    pub official_source_count: u64,
    pub max_coldstream_p95_stall_ms: u64,
    pub max_coldstream_p99_stall_ms: u64,
    pub max_mmap_p99_stall_ms: u64,
    pub max_pread_p99_stall_ms: u64,
    pub max_coldstream_read_amplification_bps: u64,
    pub min_mmap_stall_win_bps: u64,
    pub min_pread_stall_win_bps: u64,
    pub min_mmap_read_amplification_win_bps: u64,
    pub min_pread_read_amplification_win_bps: u64,
    pub max_copy_count: u64,
    pub cancellation_count: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub max_metadata_bytes: u64,
    pub mmap_fault_baseline_bps: u64,
    pub naive_pread_baseline_bps: u64,
    pub no_answer_packet_baseline_bps: u64,
    pub live_authority_baseline_bps: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:coldstream-vs-mmap:witness
// Plane: Controller + Verification
// Residency: metadata-only benchmark-plan witness.
pub struct ColdStreamVsMmapWitness {
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub fixtures: Vec<ColdStreamVsMmapFixture>,
    pub surfaces: Vec<ColdStreamVsMmapSurface>,
    pub official_source_refs: Vec<String>,
    pub mmap_fault_baseline_bps: u64,
    pub naive_pread_baseline_bps: u64,
    pub no_answer_packet_baseline_bps: u64,
    pub live_authority_baseline_bps: u64,
}

impl ColdStreamVsMmapWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        fixtures: Vec<ColdStreamVsMmapFixture>,
        surfaces: Vec<ColdStreamVsMmapSurface>,
        official_source_refs: Vec<String>,
        mmap_fault_baseline_bps: u64,
        naive_pread_baseline_bps: u64,
        no_answer_packet_baseline_bps: u64,
        live_authority_baseline_bps: u64,
    ) -> Result<Self, ColdStreamVsMmapError> {
        let witness = Self {
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            fixtures,
            surfaces,
            official_source_refs,
            mmap_fault_baseline_bps,
            naive_pread_baseline_bps,
            no_answer_packet_baseline_bps,
            live_authority_baseline_bps,
        };
        validate_witness(&witness)?;
        Ok(witness)
    }

    pub fn metrics(&self) -> ColdStreamVsMmapMetrics {
        let mut metrics = ColdStreamVsMmapMetrics {
            fixture_count: self.fixtures.len() as u64,
            baseline_row_count: self
                .fixtures
                .iter()
                .map(|fixture| fixture.rows.len() as u64)
                .sum(),
            surface_count: self.surfaces.len() as u64,
            answer_packet_count: self
                .fixtures
                .iter()
                .map(|fixture| fixture.answer_packet_ref.as_str())
                .collect::<BTreeSet<_>>()
                .len() as u64,
            run_event_log_count: self
                .fixtures
                .iter()
                .map(|fixture| fixture.run_event_log_ref.as_str())
                .collect::<BTreeSet<_>>()
                .len() as u64,
            official_source_count: self.official_source_refs.len() as u64,
            mmap_fault_baseline_bps: self.mmap_fault_baseline_bps,
            naive_pread_baseline_bps: self.naive_pread_baseline_bps,
            no_answer_packet_baseline_bps: self.no_answer_packet_baseline_bps,
            live_authority_baseline_bps: self.live_authority_baseline_bps,
            ..ColdStreamVsMmapMetrics::default()
        };
        let mut min_mmap_stall_win = u64::MAX;
        let mut min_pread_stall_win = u64::MAX;
        let mut min_mmap_read_win = u64::MAX;
        let mut min_pread_read_win = u64::MAX;
        for fixture in &self.fixtures {
            if let (Some(coldstream), Some(mmap), Some(pread)) = (
                row_for(fixture, ColdStreamBaselineKind::ColdStreamPlan),
                row_for(fixture, ColdStreamBaselineKind::MmapFault),
                row_for(fixture, ColdStreamBaselineKind::NaivePread),
            ) {
                metrics.max_coldstream_p95_stall_ms = metrics
                    .max_coldstream_p95_stall_ms
                    .max(u64::from(coldstream.p95_stall_ms));
                metrics.max_coldstream_p99_stall_ms = metrics
                    .max_coldstream_p99_stall_ms
                    .max(u64::from(coldstream.p99_stall_ms));
                metrics.max_mmap_p99_stall_ms = metrics
                    .max_mmap_p99_stall_ms
                    .max(u64::from(mmap.p99_stall_ms));
                metrics.max_pread_p99_stall_ms = metrics
                    .max_pread_p99_stall_ms
                    .max(u64::from(pread.p99_stall_ms));
                metrics.max_coldstream_read_amplification_bps = metrics
                    .max_coldstream_read_amplification_bps
                    .max(u64::from(coldstream.read_amplification_bps));
                metrics.max_copy_count =
                    metrics.max_copy_count.max(u64::from(coldstream.copy_count));
                metrics.cancellation_count += u64::from(fixture.cancellation_count);
                metrics.runtime_bytes_loaded += fixture.runtime_bytes_loaded;
                metrics.model_bytes_loaded += fixture.model_bytes_loaded;
                metrics.max_metadata_bytes = metrics.max_metadata_bytes.max(fixture.metadata_bytes);
                min_mmap_stall_win =
                    min_mmap_stall_win.min(win_bps(mmap.p99_stall_ms, coldstream.p99_stall_ms));
                min_pread_stall_win =
                    min_pread_stall_win.min(win_bps(pread.p99_stall_ms, coldstream.p99_stall_ms));
                min_mmap_read_win = min_mmap_read_win.min(win_bps(
                    mmap.read_amplification_bps,
                    coldstream.read_amplification_bps,
                ));
                min_pread_read_win = min_pread_read_win.min(win_bps(
                    pread.read_amplification_bps,
                    coldstream.read_amplification_bps,
                ));
            }
        }
        metrics.min_mmap_stall_win_bps = min_mmap_stall_win;
        metrics.min_pread_stall_win_bps = min_pread_stall_win;
        metrics.min_mmap_read_amplification_win_bps = min_mmap_read_win;
        metrics.min_pread_read_amplification_win_bps = min_pread_read_win;
        metrics
    }

    pub fn address(&self) -> String {
        let mut fixture_ids = self
            .fixtures
            .iter()
            .map(|fixture| fixture.fixture_id.as_str())
            .collect::<Vec<_>>();
        fixture_ids.sort_unstable();
        let mut sources = self
            .official_source_refs
            .iter()
            .map(String::as_str)
            .collect::<Vec<_>>();
        sources.sort_unstable();
        let digest_input = format!(
            "coldstream-vs-mmap|{}|{}|{}",
            self.route_authority,
            fixture_ids.join("|"),
            sources.join("|")
        );
        let digest = sha256_hex(digest_input.as_bytes());
        format!("uas:coldstream-vs-mmap:sha256:{digest}")
    }
}

fn validate_witness(witness: &ColdStreamVsMmapWitness) -> Result<(), ColdStreamVsMmapError> {
    if witness.fixtures.is_empty() {
        return Err(ColdStreamVsMmapError::EmptyFixture);
    }
    if witness.surfaces.is_empty() {
        return Err(ColdStreamVsMmapError::EmptySurface);
    }
    if witness.product_build != ProductBuild::Pro
        || witness.pro_status != ProStatus::ResearchCandidate
    {
        return Err(ColdStreamVsMmapError::ProductStatusMismatch);
    }
    if witness.route_authority != "benchmark_plan_only" {
        return Err(ColdStreamVsMmapError::HiddenRouteAuthority);
    }
    validate_sources(&witness.official_source_refs)?;

    let surface_packet_refs = witness
        .surfaces
        .iter()
        .map(|surface| surface.answer_packet_ref.as_str())
        .collect::<HashSet<_>>();
    let mut fixture_ids = HashSet::new();
    let mut packet_refs = HashSet::new();
    for fixture in &witness.fixtures {
        validate_fixture(fixture)?;
        if !fixture_ids.insert(fixture.fixture_id.clone()) {
            return Err(ColdStreamVsMmapError::DuplicateFixture(
                fixture.fixture_id.clone(),
            ));
        }
        if !packet_refs.insert(fixture.answer_packet_ref.clone()) {
            return Err(ColdStreamVsMmapError::DuplicateAnswerPacket(
                fixture.answer_packet_ref.clone(),
            ));
        }
        if !surface_packet_refs.contains(fixture.answer_packet_ref.as_str()) {
            return Err(ColdStreamVsMmapError::MissingSurfaceRef(
                fixture.fixture_id.clone(),
            ));
        }
    }

    let mut surface_ids = HashSet::new();
    for surface in &witness.surfaces {
        validate_surface(surface)?;
        if !surface_ids.insert(surface.surface_id.clone()) {
            return Err(ColdStreamVsMmapError::DuplicateSurface(
                surface.surface_id.clone(),
            ));
        }
    }
    if witness.mmap_fault_baseline_bps >= 9_000 {
        return Err(ColdStreamVsMmapError::BaselineUnbeaten("mmap_fault"));
    }
    if witness.naive_pread_baseline_bps >= 9_000 {
        return Err(ColdStreamVsMmapError::BaselineUnbeaten("naive_pread"));
    }
    if witness.no_answer_packet_baseline_bps >= 9_000 {
        return Err(ColdStreamVsMmapError::BaselineUnbeaten("no_answer_packet"));
    }
    if witness.live_authority_baseline_bps >= 9_000 {
        return Err(ColdStreamVsMmapError::BaselineUnbeaten("live_authority"));
    }
    Ok(())
}

fn validate_sources(sources: &[String]) -> Result<(), ColdStreamVsMmapError> {
    let required = [
        "official_source:apple_mmap",
        "official_source:apple_fcntl",
        "official_source:apple_dispatch_io",
    ];
    let source_set = sources.iter().map(String::as_str).collect::<HashSet<_>>();
    for source in required {
        if !source_set.contains(source) {
            return Err(ColdStreamVsMmapError::MissingOfficialSource(
                source.to_string(),
            ));
        }
    }
    for source in sources {
        validate_nonempty("official_source_ref", source)?;
        if !source.starts_with(SOURCE_PREFIX) {
            return Err(ColdStreamVsMmapError::MissingOfficialSource(source.clone()));
        }
    }
    Ok(())
}

fn validate_fixture(fixture: &ColdStreamVsMmapFixture) -> Result<(), ColdStreamVsMmapError> {
    for (field, value) in [
        ("fixture_id", fixture.fixture_id.as_str()),
        ("benchmark_plan_ref", fixture.benchmark_plan_ref.as_str()),
        ("answer_packet_ref", fixture.answer_packet_ref.as_str()),
        ("run_event_log_ref", fixture.run_event_log_ref.as_str()),
        ("rollback_ref", fixture.rollback_ref.as_str()),
        ("admission_ref", fixture.admission_ref.as_str()),
        ("scope_rex_ref", fixture.scope_rex_ref.as_str()),
        ("sovereign_gate_ref", fixture.sovereign_gate_ref.as_str()),
        ("compatibility_fence", fixture.compatibility_fence.as_str()),
        ("cancel_group_ref", fixture.cancel_group_ref.as_str()),
        ("fallback_ref", fixture.fallback_ref.as_str()),
        ("visible_summary", fixture.visible_summary.as_str()),
    ] {
        validate_nonempty(field, value)?;
    }
    if !fixture
        .benchmark_plan_ref
        .starts_with(BENCHMARK_PLAN_PREFIX)
    {
        return Err(ColdStreamVsMmapError::MissingBenchmarkPlanRef(
            fixture.fixture_id.clone(),
        ));
    }
    if !fixture.answer_packet_ref.starts_with(ANSWER_PACKET_PREFIX) {
        return Err(ColdStreamVsMmapError::MissingAnswerPacket(
            fixture.fixture_id.clone(),
        ));
    }
    if !fixture.run_event_log_ref.starts_with(RUN_EVENT_LOG_PREFIX) {
        return Err(ColdStreamVsMmapError::MissingRunEventLog(
            fixture.fixture_id.clone(),
        ));
    }
    if !fixture.rollback_ref.starts_with(ROLLBACK_PREFIX) {
        return Err(ColdStreamVsMmapError::MissingRollback(
            fixture.fixture_id.clone(),
        ));
    }
    if !fixture.admission_ref.starts_with(ADMISSION_PREFIX) {
        return Err(ColdStreamVsMmapError::MissingAdmission);
    }
    if !fixture.scope_rex_ref.starts_with(SCOPE_REX_PREFIX) {
        return Err(ColdStreamVsMmapError::MissingScopeRex);
    }
    if !fixture
        .sovereign_gate_ref
        .starts_with(SOVEREIGN_GATE_PREFIX)
    {
        return Err(ColdStreamVsMmapError::MissingSovereignGate);
    }
    if !fixture
        .compatibility_fence
        .starts_with(COMPATIBILITY_FENCE_PREFIX)
    {
        return Err(ColdStreamVsMmapError::MissingCompatibilityFence(
            fixture.fixture_id.clone(),
        ));
    }
    if !fixture.cancel_group_ref.starts_with(CANCEL_GROUP_PREFIX) {
        return Err(ColdStreamVsMmapError::MissingCancelGroup(
            fixture.fixture_id.clone(),
        ));
    }
    if !fixture.fallback_ref.starts_with(FALLBACK_PREFIX) {
        return Err(ColdStreamVsMmapError::MissingFallback(
            fixture.fixture_id.clone(),
        ));
    }
    if fixture.rows.is_empty() {
        return Err(ColdStreamVsMmapError::EmptyBaselineRow(
            fixture.fixture_id.clone(),
        ));
    }
    if !visible_summary_is_honest(fixture) {
        return Err(ColdStreamVsMmapError::MissingVisibleSummary(
            fixture.fixture_id.clone(),
        ));
    }
    if fixture.cancellation_count == 0 {
        return Err(ColdStreamVsMmapError::CancellationMissing(
            fixture.fixture_id.clone(),
        ));
    }
    if !fixture.l1_l2_l3_separated {
        return Err(ColdStreamVsMmapError::MissingLayerSeparation);
    }
    if fixture.hidden_route_authority {
        return Err(ColdStreamVsMmapError::HiddenRouteAuthority);
    }
    if fixture.route_policy_mutated {
        return Err(ColdStreamVsMmapError::RoutePolicyMutation);
    }
    if fixture.scope_rex_bypassed {
        return Err(ColdStreamVsMmapError::ScopeRexBypass);
    }
    if fixture.sovereign_gate_bypassed {
        return Err(ColdStreamVsMmapError::SovereignGateBypass);
    }
    if fixture.answer_packet_suppressed {
        return Err(ColdStreamVsMmapError::AnswerPacketSuppression);
    }
    if fixture.hidden_chain_exposed || contains_hidden_reasoning(&fixture.visible_summary) {
        return Err(ColdStreamVsMmapError::HiddenChainExposure);
    }
    if fixture.hidden_cloud_route {
        return Err(ColdStreamVsMmapError::HiddenCloudRoute);
    }
    if fixture.ssd_as_ram_claimed || contains_ssd_as_ram_claim(&fixture.visible_summary) {
        return Err(ColdStreamVsMmapError::SsdAsRamClaim);
    }
    if fixture.live_benchmark_attempted {
        return Err(ColdStreamVsMmapError::LiveBenchmarkAttempted);
    }
    if fixture.runtime_bytes_loaded > 0 {
        return Err(ColdStreamVsMmapError::RuntimeBytesLoaded);
    }
    if fixture.model_bytes_loaded > 0 {
        return Err(ColdStreamVsMmapError::ModelBytesLoaded);
    }
    if fixture.metadata_bytes > MAX_METADATA_BYTES {
        return Err(ColdStreamVsMmapError::MetadataBudgetExceeded);
    }
    validate_rows(fixture)?;
    Ok(())
}

fn validate_rows(fixture: &ColdStreamVsMmapFixture) -> Result<(), ColdStreamVsMmapError> {
    let mut row_ids = HashSet::new();
    let mut rows_by_kind = HashMap::new();
    for row in &fixture.rows {
        validate_row(row)?;
        if row.fixture_id != fixture.fixture_id {
            return Err(ColdStreamVsMmapError::FixtureIdMismatch(row.row_id.clone()));
        }
        if !row_ids.insert(row.row_id.clone()) {
            return Err(ColdStreamVsMmapError::DuplicateBaselineRow(
                row.row_id.clone(),
            ));
        }
        rows_by_kind.insert(row.kind.clone(), row);
    }
    for kind in [
        ColdStreamBaselineKind::MmapFault,
        ColdStreamBaselineKind::NaivePread,
        ColdStreamBaselineKind::ColdStreamPlan,
    ] {
        if !rows_by_kind.contains_key(&kind) {
            return Err(ColdStreamVsMmapError::MissingBaseline(
                fixture.fixture_id.clone(),
                kind,
            ));
        }
    }
    let mmap = rows_by_kind[&ColdStreamBaselineKind::MmapFault];
    let pread = rows_by_kind[&ColdStreamBaselineKind::NaivePread];
    let coldstream = rows_by_kind[&ColdStreamBaselineKind::ColdStreamPlan];
    if coldstream.p95_stall_ms >= mmap.p95_stall_ms
        || coldstream.p99_stall_ms >= mmap.p99_stall_ms
        || coldstream.read_amplification_bps >= mmap.read_amplification_bps
    {
        return Err(ColdStreamVsMmapError::ColdStreamDoesNotBeatMmap(
            fixture.fixture_id.clone(),
        ));
    }
    if coldstream.p95_stall_ms >= pread.p95_stall_ms
        || coldstream.p99_stall_ms >= pread.p99_stall_ms
        || coldstream.read_amplification_bps >= pread.read_amplification_bps
    {
        return Err(ColdStreamVsMmapError::ColdStreamDoesNotBeatPread(
            fixture.fixture_id.clone(),
        ));
    }
    Ok(())
}

fn validate_row(row: &ColdStreamBaselineRow) -> Result<(), ColdStreamVsMmapError> {
    validate_nonempty("row_id", &row.row_id)?;
    validate_nonempty("fixture_id", &row.fixture_id)?;
    if row.bytes_requested == 0 || row.bytes_read == 0 {
        return Err(ColdStreamVsMmapError::ZeroBytes(row.row_id.clone()));
    }
    if row.read_amplification_bps < 10_000 || row.bytes_read < row.bytes_requested {
        return Err(ColdStreamVsMmapError::ReadAmplificationInvalid(
            row.row_id.clone(),
        ));
    }
    if row.p99_stall_ms < row.p95_stall_ms {
        return Err(ColdStreamVsMmapError::P99BelowP95(row.row_id.clone()));
    }
    if row.kind == ColdStreamBaselineKind::ColdStreamPlan && row.copy_count > MAX_COPY_COUNT {
        return Err(ColdStreamVsMmapError::CopyBudgetExceeded(
            row.row_id.clone(),
        ));
    }
    Ok(())
}

fn validate_surface(surface: &ColdStreamVsMmapSurface) -> Result<(), ColdStreamVsMmapError> {
    validate_nonempty("surface_id", &surface.surface_id)?;
    validate_nonempty("answer_packet_ref", &surface.answer_packet_ref)?;
    validate_nonempty("visible_text", &surface.visible_text)?;
    if !surface.answer_packet_ref.starts_with(ANSWER_PACKET_PREFIX) {
        return Err(ColdStreamVsMmapError::MissingAnswerPacket(
            surface.surface_id.clone(),
        ));
    }
    for marker in &surface.required_markers {
        validate_nonempty("required_marker", marker)?;
        if !surface.visible_text.contains(marker) {
            return Err(ColdStreamVsMmapError::MissingRequiredMarker(marker.clone()));
        }
    }
    for marker in &surface.forbidden_markers {
        validate_nonempty("forbidden_marker", marker)?;
        if surface.visible_text.contains(marker) {
            return Err(ColdStreamVsMmapError::ForbiddenMarker(marker.clone()));
        }
    }
    if contains_hidden_reasoning(&surface.visible_text) {
        return Err(ColdStreamVsMmapError::HiddenChainExposure);
    }
    if contains_ssd_as_ram_claim(&surface.visible_text) {
        return Err(ColdStreamVsMmapError::SsdAsRamClaim);
    }
    Ok(())
}

fn validate_nonempty(field: &'static str, value: &str) -> Result<(), ColdStreamVsMmapError> {
    if value.is_empty() {
        return Err(ColdStreamVsMmapError::MissingField(field));
    }
    if value != value.trim() {
        return Err(ColdStreamVsMmapError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(char::is_control) {
        return Err(ColdStreamVsMmapError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

fn row_for(
    fixture: &ColdStreamVsMmapFixture,
    kind: ColdStreamBaselineKind,
) -> Option<&ColdStreamBaselineRow> {
    fixture.rows.iter().find(|row| row.kind == kind)
}

fn win_bps(baseline: u32, candidate: u32) -> u64 {
    if baseline == 0 || candidate >= baseline {
        0
    } else {
        u64::from((baseline - candidate) * 10_000 / baseline)
    }
}

fn visible_summary_is_honest(fixture: &ColdStreamVsMmapFixture) -> bool {
    let summary = fixture.visible_summary.to_ascii_lowercase();
    fixture.visible_summary.len() >= MIN_VISIBLE_SUMMARY_BYTES
        && summary.contains("metadata-only")
        && summary.contains("mmap")
        && summary.contains("pread")
        && summary.contains("coldstream")
        && summary.contains("p95")
        && summary.contains("p99")
        && summary.contains("read amplification")
        && summary.contains("answerpacket")
        && summary.contains("rollback")
        && summary.contains("l1/l2/l3")
        && summary.contains("no live benchmark")
}

fn contains_hidden_reasoning(value: &str) -> bool {
    let lower = value.to_ascii_lowercase();
    lower.contains("chain-of-thought")
        || lower.contains("hidden reasoning")
        || lower.contains("<cot>")
        || lower.contains("private scratchpad")
}

fn contains_ssd_as_ram_claim(value: &str) -> bool {
    let lower = value.to_ascii_lowercase();
    lower.contains("ssd is ram")
        || lower.contains("ssd = ram")
        || lower.contains("mmap is ram")
        || lower.contains("live 70b local runtime")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn valid_witness_binds_same_fixture_benchmark_plan() {
        let witness = fixture_witness().expect("witness");
        let metrics = witness.metrics();
        assert_eq!(metrics.fixture_count, 3);
        assert_eq!(metrics.baseline_row_count, 9);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert!(metrics.min_mmap_stall_win_bps >= 1_000);
        assert!(metrics.min_pread_read_amplification_win_bps >= 500);
        assert!(witness
            .address()
            .starts_with("uas:coldstream-vs-mmap:sha256:"));
    }

    #[test]
    fn address_is_deterministic_under_fixture_order() {
        let witness = fixture_witness().expect("witness");
        let address = witness.address();
        let mut fixtures = witness.fixtures.clone();
        fixtures.reverse();
        let reversed = ColdStreamVsMmapWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "benchmark_plan_only",
            fixtures,
            witness.surfaces.clone(),
            witness.official_source_refs.clone(),
            4_000,
            4_250,
            4_500,
            4_750,
        )
        .expect("reversed");
        assert_eq!(address, reversed.address());
    }

    #[test]
    fn rejects_unbeaten_or_mismatched_baselines() {
        assert_eq!(
            reject_fixture(|fixture| {
                let coldstream = fixture
                    .rows
                    .iter_mut()
                    .find(|row| row.kind == ColdStreamBaselineKind::ColdStreamPlan)
                    .expect("coldstream");
                coldstream.p99_stall_ms = 900;
            })
            .unwrap_err(),
            ColdStreamVsMmapError::ColdStreamDoesNotBeatMmap("fixture-cpu".to_string())
        );
        assert_eq!(
            reject_fixture(|fixture| fixture.rows[0].fixture_id = "fixture-other".to_string())
                .unwrap_err(),
            ColdStreamVsMmapError::FixtureIdMismatch("mmap-cpu".to_string())
        );
    }

    #[test]
    fn rejects_missing_visible_proof_and_authority_bypass() {
        assert_eq!(
            reject_fixture(|fixture| fixture.answer_packet_ref = "packet:cpu".to_string())
                .unwrap_err(),
            ColdStreamVsMmapError::MissingAnswerPacket("fixture-cpu".to_string())
        );
        assert_eq!(
            reject_fixture(|fixture| fixture.scope_rex_bypassed = true).unwrap_err(),
            ColdStreamVsMmapError::ScopeRexBypass
        );
        assert_eq!(
            reject_fixture(|fixture| fixture.ssd_as_ram_claimed = true).unwrap_err(),
            ColdStreamVsMmapError::SsdAsRamClaim
        );
    }

    #[test]
    fn rejects_live_or_product_promotion() {
        assert_eq!(
            reject_fixture(|fixture| fixture.live_benchmark_attempted = true).unwrap_err(),
            ColdStreamVsMmapError::LiveBenchmarkAttempted
        );
        assert_eq!(
            reject_fixture(|fixture| fixture.runtime_bytes_loaded = 1).unwrap_err(),
            ColdStreamVsMmapError::RuntimeBytesLoaded
        );
        assert!(ColdStreamVsMmapWitness::new(
            ProductBuild::Mas,
            ProStatus::ResearchCandidate,
            "benchmark_plan_only",
            fixture_fixtures().expect("fixtures"),
            fixture_surfaces().expect("surfaces"),
            fixture_sources(),
            4_000,
            4_250,
            4_500,
            4_750,
        )
        .is_err());
    }

    fn reject_fixture(
        mutate: impl FnOnce(&mut ColdStreamVsMmapFixture),
    ) -> Result<ColdStreamVsMmapWitness, ColdStreamVsMmapError> {
        let mut fixtures = fixture_fixtures()?;
        mutate(&mut fixtures[0]);
        ColdStreamVsMmapWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "benchmark_plan_only",
            fixtures,
            fixture_surfaces()?,
            fixture_sources(),
            4_000,
            4_250,
            4_500,
            4_750,
        )
    }

    fn fixture_witness() -> Result<ColdStreamVsMmapWitness, ColdStreamVsMmapError> {
        ColdStreamVsMmapWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "benchmark_plan_only",
            fixture_fixtures()?,
            fixture_surfaces()?,
            fixture_sources(),
            4_000,
            4_250,
            4_500,
            4_750,
        )
    }

    fn fixture_sources() -> Vec<String> {
        vec![
            "official_source:apple_mmap".to_string(),
            "official_source:apple_fcntl".to_string(),
            "official_source:apple_dispatch_io".to_string(),
            "official_source:apple_metal_resource_loading".to_string(),
        ]
    }

    fn fixture_fixtures() -> Result<Vec<ColdStreamVsMmapFixture>, ColdStreamVsMmapError> {
        Ok(vec![
            fixture("cpu", 128 * 1024, 36, 52, 32, 42, 18, 24)?,
            fixture("metal", 192 * 1024, 48, 70, 38, 54, 22, 30)?,
            fixture("mlx", 256 * 1024, 56, 84, 44, 66, 28, 36)?,
        ])
    }

    #[allow(clippy::too_many_arguments)]
    fn fixture(
        suffix: &str,
        bytes: u64,
        mmap_p95: u32,
        mmap_p99: u32,
        pread_p95: u32,
        pread_p99: u32,
        cold_p95: u32,
        cold_p99: u32,
    ) -> Result<ColdStreamVsMmapFixture, ColdStreamVsMmapError> {
        let fixture_id = format!("fixture-{suffix}");
        let rows = vec![
            row(
                "mmap",
                suffix,
                ColdStreamBaselineKind::MmapFault,
                bytes,
                18_000,
                mmap_p95,
                mmap_p99,
                1,
            )?,
            row(
                "pread",
                suffix,
                ColdStreamBaselineKind::NaivePread,
                bytes,
                14_000,
                pread_p95,
                pread_p99,
                1,
            )?,
            row(
                "coldstream",
                suffix,
                ColdStreamBaselineKind::ColdStreamPlan,
                bytes,
                11_200,
                cold_p95,
                cold_p99,
                2,
            )?,
        ];
        ColdStreamVsMmapFixture::new(
            fixture_id,
            format!("benchmark_plan:{suffix}:coldstream_vs_mmap"),
            format!("answer_packet:{suffix}"),
            format!("run_event_log:{suffix}"),
            format!("rollback:{suffix}"),
            format!("admission:{suffix}"),
            format!("scope_rex:{suffix}"),
            format!("sovereign_gate:{suffix}"),
            format!("compat:{suffix}:coldstream_vs_mmap"),
            format!("cancel_group:{suffix}"),
            format!("fallback:{suffix}:pread_visible"),
            format!("Metadata-only ColdStream vs mmap/pread benchmark plan for {suffix}: p95 and p99 stall, read amplification, AnswerPacket, rollback, and L1/L2/L3 separation are visible; no live benchmark or product promotion is claimed."),
            rows,
            1,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            0,
            0,
            42 * 1024,
        )
    }

    fn row(
        prefix: &str,
        suffix: &str,
        kind: ColdStreamBaselineKind,
        bytes: u64,
        read_amplification_bps: u32,
        p95_stall_ms: u32,
        p99_stall_ms: u32,
        copy_count: u32,
    ) -> Result<ColdStreamBaselineRow, ColdStreamVsMmapError> {
        ColdStreamBaselineRow::new(
            format!("{prefix}-{suffix}"),
            format!("fixture-{suffix}"),
            kind,
            bytes,
            bytes * u64::from(read_amplification_bps) / 10_000,
            read_amplification_bps,
            p95_stall_ms,
            p99_stall_ms,
            copy_count,
        )
    }

    fn fixture_surfaces() -> Result<Vec<ColdStreamVsMmapSurface>, ColdStreamVsMmapError> {
        ["cpu", "metal", "mlx"]
            .into_iter()
            .map(|suffix| {
                ColdStreamVsMmapSurface::new(
                    format!("surface-{suffix}"),
                    format!("answer_packet:{suffix}"),
                    format!("AnswerPacket visible ColdStream vs mmap/pread metadata-only benchmark plan surface {suffix}: p95, p99, read amplification, rollback, cancellation, and L1/L2/L3 separation are visible; no live benchmark and no SSD-as-RAM claim is promoted."),
                    vec![
                        "ColdStream".to_string(),
                        "mmap".to_string(),
                        "pread".to_string(),
                        "AnswerPacket".to_string(),
                        "no live benchmark".to_string(),
                    ],
                    vec![
                        "SSD is RAM".to_string(),
                        "70B route is live".to_string(),
                        "hidden reasoning".to_string(),
                    ],
                )
            })
            .collect()
    }
}
