//! SSD wear budget contracts for ColdStream transport.
//!
//! This is a metadata-only guard: it proves repeated transport plans account
//! for read/write volume, burst volume, energy, cache pressure, rollback, and
//! visible AnswerPacket caveats before ColdStream can claim a hot-path win.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const SSD_WEAR_BUDGET_CURSOR: &str = "ssd_wear_budget";
pub const SSD_WEAR_BUDGET_NEXT_CURSOR: &str = "coldstream_vs_mmap";

const BUDGET_PREFIX: &str = "ssd_wear_budget:";
const TRANSPORT_TRACE_PREFIX: &str = "transport_trace:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ROLLBACK_PREFIX: &str = "rollback:";
const ADMISSION_PREFIX: &str = "admission:";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const CACHE_POLICY_PREFIX: &str = "cache_policy:";
const MAX_METADATA_BYTES: u64 = 192 * 1024;
const MAX_WRITE_AMPLIFICATION_BPS: u32 = 15_000;
const MIN_VISIBLE_CAVEAT_BYTES: usize = 96;

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:ssd-wear-budget:error
// Plane: Verification
// Residency: metadata-only rejection taxonomy.
pub enum SsdWearBudgetError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptyPlan,
    EmptySurface,
    DuplicatePlan(String),
    DuplicateSurface(String),
    DuplicateAnswerPacket(String),
    MissingBudgetRef(String),
    MissingTransportTrace(String),
    MissingAnswerPacket(String),
    MissingRunEventLog(String),
    MissingRollback(String),
    MissingAdmission,
    MissingScopeRex,
    MissingSovereignGate,
    MissingCompatibilityFence(String),
    MissingCachePolicy(String),
    MissingSurfaceRef(String),
    MissingRequiredMarker(String),
    ForbiddenMarker(String),
    MissingLayerSeparation,
    MissingWearCaveat(String),
    MissingVisibleSummary(String),
    ZeroBudget(String),
    ZeroObservedVolume(String),
    DailyReadBudgetExceeded(String),
    DailyWriteBudgetExceeded(String),
    BurstReadBudgetExceeded(String),
    BurstWriteBudgetExceeded(String),
    EnergyBudgetExceeded(String),
    CachePollutionBudgetExceeded(String),
    WriteAmplificationInvalid(String),
    ReuseHorizonMissing(String),
    HiddenRouteAuthority,
    RoutePolicyMutation,
    ScopeRexBypass,
    SovereignGateBypass,
    AnswerPacketSuppression,
    HiddenChainExposure,
    HiddenCloudRoute,
    ProductStatusMismatch,
    RuntimeBytesLoaded,
    ModelBytesLoaded,
    MetadataBudgetExceeded,
    BaselineUnbeaten(&'static str),
}

impl fmt::Display for SsdWearBudgetError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptyPlan => write!(f, "missing SSD wear budget plan"),
            Self::EmptySurface => write!(f, "missing SSD wear visibility surface"),
            Self::DuplicatePlan(id) => write!(f, "duplicate SSD wear plan `{id}`"),
            Self::DuplicateSurface(id) => write!(f, "duplicate SSD wear surface `{id}`"),
            Self::DuplicateAnswerPacket(id) => write!(f, "duplicate AnswerPacket `{id}`"),
            Self::MissingBudgetRef(id) => write!(f, "plan `{id}` missing budget ref"),
            Self::MissingTransportTrace(id) => write!(f, "plan `{id}` missing transport trace ref"),
            Self::MissingAnswerPacket(id) => write!(f, "plan `{id}` missing AnswerPacket ref"),
            Self::MissingRunEventLog(id) => write!(f, "plan `{id}` missing RunEventLog ref"),
            Self::MissingRollback(id) => write!(f, "plan `{id}` missing rollback ref"),
            Self::MissingAdmission => write!(f, "missing admission ref"),
            Self::MissingScopeRex => write!(f, "missing SCOPE-Rex ref"),
            Self::MissingSovereignGate => write!(f, "missing SovereignGate ref"),
            Self::MissingCompatibilityFence(id) => {
                write!(f, "plan `{id}` missing compatibility fence")
            }
            Self::MissingCachePolicy(id) => write!(f, "plan `{id}` missing cache policy ref"),
            Self::MissingSurfaceRef(id) => write!(f, "plan `{id}` has no matching surface"),
            Self::MissingRequiredMarker(marker) => write!(f, "missing required marker `{marker}`"),
            Self::ForbiddenMarker(marker) => write!(f, "forbidden marker `{marker}` present"),
            Self::MissingLayerSeparation => write!(f, "L1/L2/L3 separation missing"),
            Self::MissingWearCaveat(id) => write!(f, "plan `{id}` missing visible wear caveat"),
            Self::MissingVisibleSummary(id) => write!(f, "plan `{id}` missing visible summary"),
            Self::ZeroBudget(id) => write!(f, "plan `{id}` has a zero budget"),
            Self::ZeroObservedVolume(id) => write!(f, "plan `{id}` has zero observed volume"),
            Self::DailyReadBudgetExceeded(id) => {
                write!(f, "plan `{id}` exceeds daily read budget")
            }
            Self::DailyWriteBudgetExceeded(id) => {
                write!(f, "plan `{id}` exceeds daily write budget")
            }
            Self::BurstReadBudgetExceeded(id) => {
                write!(f, "plan `{id}` exceeds burst read budget")
            }
            Self::BurstWriteBudgetExceeded(id) => {
                write!(f, "plan `{id}` exceeds burst write budget")
            }
            Self::EnergyBudgetExceeded(id) => write!(f, "plan `{id}` exceeds energy budget"),
            Self::CachePollutionBudgetExceeded(id) => {
                write!(f, "plan `{id}` exceeds cache pollution budget")
            }
            Self::WriteAmplificationInvalid(id) => {
                write!(f, "plan `{id}` has invalid write amplification")
            }
            Self::ReuseHorizonMissing(id) => write!(f, "plan `{id}` missing reuse horizon"),
            Self::HiddenRouteAuthority => write!(f, "hidden route authority attempted"),
            Self::RoutePolicyMutation => write!(f, "route policy mutation attempted"),
            Self::ScopeRexBypass => write!(f, "SCOPE-Rex bypass attempted"),
            Self::SovereignGateBypass => write!(f, "SovereignGate bypass attempted"),
            Self::AnswerPacketSuppression => write!(f, "AnswerPacket suppression attempted"),
            Self::HiddenChainExposure => write!(f, "hidden chain exposure attempted"),
            Self::HiddenCloudRoute => write!(f, "hidden cloud route attempted"),
            Self::ProductStatusMismatch => write!(f, "product status promoted beyond Pro Research"),
            Self::RuntimeBytesLoaded => write!(f, "metadata witness loaded runtime bytes"),
            Self::ModelBytesLoaded => write!(f, "metadata witness loaded model bytes"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
            Self::BaselineUnbeaten(name) => write!(f, "baseline `{name}` was unbeaten"),
        }
    }
}

impl std::error::Error for SsdWearBudgetError {}

#[derive(Clone, Debug)]
// UAS: uas:ssd-wear-budget:plan
// Plane: Controller + Verification
// Residency: metadata-only budget card; does not read, write, or transport bytes.
pub struct SsdWearBudgetPlan {
    pub plan_id: String,
    pub route_id: String,
    pub budget_ref: String,
    pub transport_trace_ref: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub rollback_ref: String,
    pub admission_ref: String,
    pub scope_rex_ref: String,
    pub sovereign_gate_ref: String,
    pub compatibility_fence: String,
    pub cache_policy_ref: String,
    pub observed_read_bytes: u64,
    pub observed_write_bytes: u64,
    pub daily_read_budget_bytes: u64,
    pub daily_write_budget_bytes: u64,
    pub burst_read_budget_bytes: u64,
    pub burst_write_budget_bytes: u64,
    pub energy_millijoules: u64,
    pub energy_budget_millijoules: u64,
    pub cache_pollution_bps: u32,
    pub cache_pollution_budget_bps: u32,
    pub write_amplification_bps: u32,
    pub reuse_horizon_ms: u64,
    pub visible_wear_caveat: String,
    pub user_visible_summary: String,
    pub l1_l2_l3_separated: bool,
    pub hidden_route_authority: bool,
    pub route_policy_mutated: bool,
    pub scope_rex_bypassed: bool,
    pub sovereign_gate_bypassed: bool,
    pub answer_packet_suppressed: bool,
    pub hidden_chain_exposed: bool,
    pub hidden_cloud_route: bool,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub metadata_bytes: u64,
}

impl SsdWearBudgetPlan {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        plan_id: impl Into<String>,
        route_id: impl Into<String>,
        budget_ref: impl Into<String>,
        transport_trace_ref: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        rollback_ref: impl Into<String>,
        admission_ref: impl Into<String>,
        scope_rex_ref: impl Into<String>,
        sovereign_gate_ref: impl Into<String>,
        compatibility_fence: impl Into<String>,
        cache_policy_ref: impl Into<String>,
        observed_read_bytes: u64,
        observed_write_bytes: u64,
        daily_read_budget_bytes: u64,
        daily_write_budget_bytes: u64,
        burst_read_budget_bytes: u64,
        burst_write_budget_bytes: u64,
        energy_millijoules: u64,
        energy_budget_millijoules: u64,
        cache_pollution_bps: u32,
        cache_pollution_budget_bps: u32,
        write_amplification_bps: u32,
        reuse_horizon_ms: u64,
        visible_wear_caveat: impl Into<String>,
        user_visible_summary: impl Into<String>,
        l1_l2_l3_separated: bool,
        hidden_route_authority: bool,
        route_policy_mutated: bool,
        scope_rex_bypassed: bool,
        sovereign_gate_bypassed: bool,
        answer_packet_suppressed: bool,
        hidden_chain_exposed: bool,
        hidden_cloud_route: bool,
        runtime_bytes_loaded: u64,
        model_bytes_loaded: u64,
        metadata_bytes: u64,
    ) -> Result<Self, SsdWearBudgetError> {
        let plan = Self {
            plan_id: plan_id.into(),
            route_id: route_id.into(),
            budget_ref: budget_ref.into(),
            transport_trace_ref: transport_trace_ref.into(),
            answer_packet_ref: answer_packet_ref.into(),
            run_event_log_ref: run_event_log_ref.into(),
            rollback_ref: rollback_ref.into(),
            admission_ref: admission_ref.into(),
            scope_rex_ref: scope_rex_ref.into(),
            sovereign_gate_ref: sovereign_gate_ref.into(),
            compatibility_fence: compatibility_fence.into(),
            cache_policy_ref: cache_policy_ref.into(),
            observed_read_bytes,
            observed_write_bytes,
            daily_read_budget_bytes,
            daily_write_budget_bytes,
            burst_read_budget_bytes,
            burst_write_budget_bytes,
            energy_millijoules,
            energy_budget_millijoules,
            cache_pollution_bps,
            cache_pollution_budget_bps,
            write_amplification_bps,
            reuse_horizon_ms,
            visible_wear_caveat: visible_wear_caveat.into(),
            user_visible_summary: user_visible_summary.into(),
            l1_l2_l3_separated,
            hidden_route_authority,
            route_policy_mutated,
            scope_rex_bypassed,
            sovereign_gate_bypassed,
            answer_packet_suppressed,
            hidden_chain_exposed,
            hidden_cloud_route,
            runtime_bytes_loaded,
            model_bytes_loaded,
            metadata_bytes,
        };
        validate_plan_contract(&plan)?;
        Ok(plan)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:ssd-wear-budget:surface
// Plane: Verification
// Residency: visible proof text; metadata-only scan.
pub struct SsdWearBudgetSurface {
    pub surface_id: String,
    pub answer_packet_ref: String,
    pub visible_text: String,
    pub required_markers: Vec<String>,
    pub forbidden_markers: Vec<String>,
}

impl SsdWearBudgetSurface {
    pub fn new(
        surface_id: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        visible_text: impl Into<String>,
        required_markers: Vec<String>,
        forbidden_markers: Vec<String>,
    ) -> Result<Self, SsdWearBudgetError> {
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

#[derive(Clone, Debug)]
// UAS: uas:ssd-wear-budget:witness
// Plane: Controller + Verification
// Residency: metadata-only registry for repeated transport budget safety.
pub struct SsdWearBudgetWitness {
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub plans: Vec<SsdWearBudgetPlan>,
    pub surfaces: Vec<SsdWearBudgetSurface>,
    pub unbudgeted_loop_baseline_bps: u64,
    pub cache_pollution_baseline_bps: u64,
    pub silent_wear_baseline_bps: u64,
    pub live_authority_baseline_bps: u64,
}

impl SsdWearBudgetWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        plans: Vec<SsdWearBudgetPlan>,
        surfaces: Vec<SsdWearBudgetSurface>,
        unbudgeted_loop_baseline_bps: u64,
        cache_pollution_baseline_bps: u64,
        silent_wear_baseline_bps: u64,
        live_authority_baseline_bps: u64,
    ) -> Result<Self, SsdWearBudgetError> {
        let witness = Self {
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            plans,
            surfaces,
            unbudgeted_loop_baseline_bps,
            cache_pollution_baseline_bps,
            silent_wear_baseline_bps,
            live_authority_baseline_bps,
        };
        validate_witness(&witness)?;
        Ok(witness)
    }

    pub fn metrics(&self) -> SsdWearBudgetMetrics {
        let answer_packets = self
            .plans
            .iter()
            .map(|plan| plan.answer_packet_ref.as_str())
            .collect::<BTreeSet<_>>();
        let run_logs = self
            .plans
            .iter()
            .map(|plan| plan.run_event_log_ref.as_str())
            .collect::<BTreeSet<_>>();
        SsdWearBudgetMetrics {
            plan_count: self.plans.len() as u64,
            surface_count: self.surfaces.len() as u64,
            answer_packet_count: answer_packets.len() as u64,
            run_event_log_count: run_logs.len() as u64,
            observed_read_bytes: self.plans.iter().map(|plan| plan.observed_read_bytes).sum(),
            observed_write_bytes: self
                .plans
                .iter()
                .map(|plan| plan.observed_write_bytes)
                .sum(),
            daily_read_budget_bytes: self
                .plans
                .iter()
                .map(|plan| plan.daily_read_budget_bytes)
                .sum(),
            daily_write_budget_bytes: self
                .plans
                .iter()
                .map(|plan| plan.daily_write_budget_bytes)
                .sum(),
            max_burst_read_bytes: self
                .plans
                .iter()
                .map(|plan| plan.burst_read_budget_bytes)
                .max()
                .unwrap_or(0),
            max_burst_write_bytes: self
                .plans
                .iter()
                .map(|plan| plan.burst_write_budget_bytes)
                .max()
                .unwrap_or(0),
            max_energy_millijoules: self
                .plans
                .iter()
                .map(|plan| plan.energy_millijoules)
                .max()
                .unwrap_or(0),
            max_cache_pollution_bps: self
                .plans
                .iter()
                .map(|plan| u64::from(plan.cache_pollution_bps))
                .max()
                .unwrap_or(0),
            max_write_amplification_bps: self
                .plans
                .iter()
                .map(|plan| u64::from(plan.write_amplification_bps))
                .max()
                .unwrap_or(0),
            min_reuse_horizon_ms: self
                .plans
                .iter()
                .map(|plan| plan.reuse_horizon_ms)
                .min()
                .unwrap_or(0),
            runtime_bytes_loaded: self
                .plans
                .iter()
                .map(|plan| plan.runtime_bytes_loaded)
                .sum(),
            model_bytes_loaded: self.plans.iter().map(|plan| plan.model_bytes_loaded).sum(),
            max_metadata_bytes: self
                .plans
                .iter()
                .map(|plan| plan.metadata_bytes)
                .max()
                .unwrap_or(0),
            unbudgeted_loop_baseline_bps: self.unbudgeted_loop_baseline_bps,
            cache_pollution_baseline_bps: self.cache_pollution_baseline_bps,
            silent_wear_baseline_bps: self.silent_wear_baseline_bps,
            live_authority_baseline_bps: self.live_authority_baseline_bps,
        }
    }

    pub fn address(&self) -> String {
        let mut parts = self
            .plans
            .iter()
            .map(|plan| {
                format!(
                    "{}|{}|{}|{}|{}|{}|{}",
                    plan.plan_id,
                    plan.route_id,
                    plan.budget_ref,
                    plan.transport_trace_ref,
                    plan.answer_packet_ref,
                    plan.observed_read_bytes,
                    plan.observed_write_bytes
                )
            })
            .collect::<Vec<_>>();
        for surface in &self.surfaces {
            parts.push(format!(
                "surface|{}|{}|{}",
                surface.surface_id,
                surface.answer_packet_ref,
                sha256_hex(surface.visible_text.as_bytes())
            ));
        }
        parts.sort();
        format!(
            "uas:ssd-wear-budget:{}",
            sha256_hex(parts.join("\n").as_bytes())
        )
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:ssd-wear-budget:metrics
// Plane: Verification
// Residency: metadata-only aggregation; no runtime/model bytes.
pub struct SsdWearBudgetMetrics {
    pub plan_count: u64,
    pub surface_count: u64,
    pub answer_packet_count: u64,
    pub run_event_log_count: u64,
    pub observed_read_bytes: u64,
    pub observed_write_bytes: u64,
    pub daily_read_budget_bytes: u64,
    pub daily_write_budget_bytes: u64,
    pub max_burst_read_bytes: u64,
    pub max_burst_write_bytes: u64,
    pub max_energy_millijoules: u64,
    pub max_cache_pollution_bps: u64,
    pub max_write_amplification_bps: u64,
    pub min_reuse_horizon_ms: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub max_metadata_bytes: u64,
    pub unbudgeted_loop_baseline_bps: u64,
    pub cache_pollution_baseline_bps: u64,
    pub silent_wear_baseline_bps: u64,
    pub live_authority_baseline_bps: u64,
}

fn validate_witness(witness: &SsdWearBudgetWitness) -> Result<(), SsdWearBudgetError> {
    if witness.plans.is_empty() {
        return Err(SsdWearBudgetError::EmptyPlan);
    }
    if witness.surfaces.is_empty() {
        return Err(SsdWearBudgetError::EmptySurface);
    }
    validate_nonempty("route_authority", &witness.route_authority)?;
    if witness.product_build != ProductBuild::Pro
        || witness.pro_status != ProStatus::ResearchCandidate
    {
        return Err(SsdWearBudgetError::ProductStatusMismatch);
    }
    if witness.route_authority != "wear_budget_only" {
        return Err(SsdWearBudgetError::HiddenRouteAuthority);
    }

    let mut surface_ids = HashSet::new();
    for surface in &witness.surfaces {
        validate_surface(surface)?;
        if !surface_ids.insert(surface.surface_id.clone()) {
            return Err(SsdWearBudgetError::DuplicateSurface(
                surface.surface_id.clone(),
            ));
        }
    }
    let surface_packet_refs = witness
        .surfaces
        .iter()
        .map(|surface| surface.answer_packet_ref.as_str())
        .collect::<HashSet<_>>();
    let mut plan_ids = HashSet::new();
    let mut packet_refs = HashSet::new();
    for plan in &witness.plans {
        validate_plan_contract(plan)?;
        if !plan_ids.insert(plan.plan_id.clone()) {
            return Err(SsdWearBudgetError::DuplicatePlan(plan.plan_id.clone()));
        }
        if !packet_refs.insert(plan.answer_packet_ref.clone()) {
            return Err(SsdWearBudgetError::DuplicateAnswerPacket(
                plan.answer_packet_ref.clone(),
            ));
        }
        if !surface_packet_refs.contains(plan.answer_packet_ref.as_str()) {
            return Err(SsdWearBudgetError::MissingSurfaceRef(plan.plan_id.clone()));
        }
    }

    if witness.unbudgeted_loop_baseline_bps >= 9_000 {
        return Err(SsdWearBudgetError::BaselineUnbeaten("unbudgeted_loop"));
    }
    if witness.cache_pollution_baseline_bps >= 9_000 {
        return Err(SsdWearBudgetError::BaselineUnbeaten("cache_pollution"));
    }
    if witness.silent_wear_baseline_bps >= 9_000 {
        return Err(SsdWearBudgetError::BaselineUnbeaten("silent_wear"));
    }
    if witness.live_authority_baseline_bps >= 9_000 {
        return Err(SsdWearBudgetError::BaselineUnbeaten("live_authority"));
    }
    Ok(())
}

fn validate_plan_contract(plan: &SsdWearBudgetPlan) -> Result<(), SsdWearBudgetError> {
    for (field, value) in [
        ("plan_id", plan.plan_id.as_str()),
        ("route_id", plan.route_id.as_str()),
        ("budget_ref", plan.budget_ref.as_str()),
        ("transport_trace_ref", plan.transport_trace_ref.as_str()),
        ("answer_packet_ref", plan.answer_packet_ref.as_str()),
        ("run_event_log_ref", plan.run_event_log_ref.as_str()),
        ("rollback_ref", plan.rollback_ref.as_str()),
        ("admission_ref", plan.admission_ref.as_str()),
        ("scope_rex_ref", plan.scope_rex_ref.as_str()),
        ("sovereign_gate_ref", plan.sovereign_gate_ref.as_str()),
        ("compatibility_fence", plan.compatibility_fence.as_str()),
        ("cache_policy_ref", plan.cache_policy_ref.as_str()),
        ("visible_wear_caveat", plan.visible_wear_caveat.as_str()),
        ("user_visible_summary", plan.user_visible_summary.as_str()),
    ] {
        validate_nonempty(field, value)?;
    }
    if !plan.budget_ref.starts_with(BUDGET_PREFIX) {
        return Err(SsdWearBudgetError::MissingBudgetRef(plan.plan_id.clone()));
    }
    if !plan.transport_trace_ref.starts_with(TRANSPORT_TRACE_PREFIX) {
        return Err(SsdWearBudgetError::MissingTransportTrace(
            plan.plan_id.clone(),
        ));
    }
    if !plan.answer_packet_ref.starts_with(ANSWER_PACKET_PREFIX) {
        return Err(SsdWearBudgetError::MissingAnswerPacket(
            plan.plan_id.clone(),
        ));
    }
    if !plan.run_event_log_ref.starts_with(RUN_EVENT_LOG_PREFIX) {
        return Err(SsdWearBudgetError::MissingRunEventLog(plan.plan_id.clone()));
    }
    if !plan.rollback_ref.starts_with(ROLLBACK_PREFIX) {
        return Err(SsdWearBudgetError::MissingRollback(plan.plan_id.clone()));
    }
    if !plan.admission_ref.starts_with(ADMISSION_PREFIX) {
        return Err(SsdWearBudgetError::MissingAdmission);
    }
    if !plan.scope_rex_ref.starts_with(SCOPE_REX_PREFIX) {
        return Err(SsdWearBudgetError::MissingScopeRex);
    }
    if !plan.sovereign_gate_ref.starts_with(SOVEREIGN_GATE_PREFIX) {
        return Err(SsdWearBudgetError::MissingSovereignGate);
    }
    if !plan
        .compatibility_fence
        .starts_with(COMPATIBILITY_FENCE_PREFIX)
    {
        return Err(SsdWearBudgetError::MissingCompatibilityFence(
            plan.plan_id.clone(),
        ));
    }
    if !plan.cache_policy_ref.starts_with(CACHE_POLICY_PREFIX) {
        return Err(SsdWearBudgetError::MissingCachePolicy(plan.plan_id.clone()));
    }
    if plan.daily_read_budget_bytes == 0
        || plan.daily_write_budget_bytes == 0
        || plan.burst_read_budget_bytes == 0
        || plan.burst_write_budget_bytes == 0
        || plan.energy_budget_millijoules == 0
        || plan.cache_pollution_budget_bps == 0
    {
        return Err(SsdWearBudgetError::ZeroBudget(plan.plan_id.clone()));
    }
    if plan.observed_read_bytes == 0 && plan.observed_write_bytes == 0 {
        return Err(SsdWearBudgetError::ZeroObservedVolume(plan.plan_id.clone()));
    }
    if plan.observed_read_bytes > plan.daily_read_budget_bytes {
        return Err(SsdWearBudgetError::DailyReadBudgetExceeded(
            plan.plan_id.clone(),
        ));
    }
    if plan.observed_write_bytes > plan.daily_write_budget_bytes {
        return Err(SsdWearBudgetError::DailyWriteBudgetExceeded(
            plan.plan_id.clone(),
        ));
    }
    if plan.observed_read_bytes > plan.burst_read_budget_bytes {
        return Err(SsdWearBudgetError::BurstReadBudgetExceeded(
            plan.plan_id.clone(),
        ));
    }
    if plan.observed_write_bytes > plan.burst_write_budget_bytes {
        return Err(SsdWearBudgetError::BurstWriteBudgetExceeded(
            plan.plan_id.clone(),
        ));
    }
    if plan.energy_millijoules > plan.energy_budget_millijoules {
        return Err(SsdWearBudgetError::EnergyBudgetExceeded(
            plan.plan_id.clone(),
        ));
    }
    if plan.cache_pollution_bps > plan.cache_pollution_budget_bps {
        return Err(SsdWearBudgetError::CachePollutionBudgetExceeded(
            plan.plan_id.clone(),
        ));
    }
    if !(10_000..=MAX_WRITE_AMPLIFICATION_BPS).contains(&plan.write_amplification_bps) {
        return Err(SsdWearBudgetError::WriteAmplificationInvalid(
            plan.plan_id.clone(),
        ));
    }
    if plan.reuse_horizon_ms == 0 {
        return Err(SsdWearBudgetError::ReuseHorizonMissing(
            plan.plan_id.clone(),
        ));
    }
    if !visible_caveat_mentions_wear(&plan.visible_wear_caveat) {
        return Err(SsdWearBudgetError::MissingWearCaveat(plan.plan_id.clone()));
    }
    if !visible_summary_mentions_budget(plan) {
        return Err(SsdWearBudgetError::MissingVisibleSummary(
            plan.plan_id.clone(),
        ));
    }
    if !plan.l1_l2_l3_separated {
        return Err(SsdWearBudgetError::MissingLayerSeparation);
    }
    if plan.hidden_route_authority {
        return Err(SsdWearBudgetError::HiddenRouteAuthority);
    }
    if plan.route_policy_mutated {
        return Err(SsdWearBudgetError::RoutePolicyMutation);
    }
    if plan.scope_rex_bypassed {
        return Err(SsdWearBudgetError::ScopeRexBypass);
    }
    if plan.sovereign_gate_bypassed {
        return Err(SsdWearBudgetError::SovereignGateBypass);
    }
    if plan.answer_packet_suppressed {
        return Err(SsdWearBudgetError::AnswerPacketSuppression);
    }
    if plan.hidden_chain_exposed
        || contains_hidden_reasoning(&plan.user_visible_summary)
        || contains_hidden_reasoning(&plan.visible_wear_caveat)
    {
        return Err(SsdWearBudgetError::HiddenChainExposure);
    }
    if plan.hidden_cloud_route {
        return Err(SsdWearBudgetError::HiddenCloudRoute);
    }
    if plan.runtime_bytes_loaded > 0 {
        return Err(SsdWearBudgetError::RuntimeBytesLoaded);
    }
    if plan.model_bytes_loaded > 0 {
        return Err(SsdWearBudgetError::ModelBytesLoaded);
    }
    if plan.metadata_bytes > MAX_METADATA_BYTES {
        return Err(SsdWearBudgetError::MetadataBudgetExceeded);
    }
    Ok(())
}

fn validate_surface(surface: &SsdWearBudgetSurface) -> Result<(), SsdWearBudgetError> {
    validate_nonempty("surface_id", &surface.surface_id)?;
    validate_nonempty("answer_packet_ref", &surface.answer_packet_ref)?;
    validate_nonempty("visible_text", &surface.visible_text)?;
    if !surface.answer_packet_ref.starts_with(ANSWER_PACKET_PREFIX) {
        return Err(SsdWearBudgetError::MissingAnswerPacket(
            surface.surface_id.clone(),
        ));
    }
    for marker in &surface.required_markers {
        validate_nonempty("required_marker", marker)?;
        if !surface.visible_text.contains(marker) {
            return Err(SsdWearBudgetError::MissingRequiredMarker(marker.clone()));
        }
    }
    for marker in &surface.forbidden_markers {
        validate_nonempty("forbidden_marker", marker)?;
        if surface.visible_text.contains(marker) {
            return Err(SsdWearBudgetError::ForbiddenMarker(marker.clone()));
        }
    }
    if contains_hidden_reasoning(&surface.visible_text) {
        return Err(SsdWearBudgetError::HiddenChainExposure);
    }
    Ok(())
}

fn validate_nonempty(field: &'static str, value: &str) -> Result<(), SsdWearBudgetError> {
    if value.is_empty() {
        return Err(SsdWearBudgetError::MissingField(field));
    }
    if value != value.trim() {
        return Err(SsdWearBudgetError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(char::is_control) {
        return Err(SsdWearBudgetError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

fn visible_caveat_mentions_wear(value: &str) -> bool {
    let lower = value.to_ascii_lowercase();
    value.len() >= MIN_VISIBLE_CAVEAT_BYTES
        && lower.contains("ssd")
        && lower.contains("wear")
        && lower.contains("energy")
        && lower.contains("cache")
        && lower.contains("visible")
        && lower.contains("rollback")
        && lower.contains("answerpacket")
}

fn visible_summary_mentions_budget(plan: &SsdWearBudgetPlan) -> bool {
    let summary = plan.user_visible_summary.to_ascii_lowercase();
    plan.user_visible_summary.len() >= MIN_VISIBLE_CAVEAT_BYTES
        && summary.contains("ssd")
        && summary.contains("wear")
        && summary.contains("bytes")
        && summary.contains("energy")
        && summary.contains("cache")
        && summary.contains("answerpacket")
        && summary.contains(&plan.observed_read_bytes.to_string())
        && summary.contains(&plan.observed_write_bytes.to_string())
}

fn contains_hidden_reasoning(value: &str) -> bool {
    let lower = value.to_ascii_lowercase();
    lower.contains("chain-of-thought")
        || lower.contains("hidden reasoning")
        || lower.contains("<cot>")
        || lower.contains("private scratchpad")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn valid_witness_binds_wear_budget() {
        let witness = fixture_witness().expect("witness");
        let metrics = witness.metrics();
        assert_eq!(metrics.plan_count, 3);
        assert_eq!(metrics.answer_packet_count, 3);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert!(witness.address().starts_with("uas:ssd-wear-budget:sha256:"));
    }

    #[test]
    fn address_is_deterministic_under_plan_order() {
        let witness = fixture_witness().expect("witness");
        let address = witness.address();
        let mut plans = witness.plans.clone();
        plans.reverse();
        let reversed = SsdWearBudgetWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "wear_budget_only",
            plans,
            witness.surfaces.clone(),
            4_000,
            4_500,
            4_750,
            4_250,
        )
        .expect("reversed");
        assert_eq!(address, reversed.address());
    }

    #[test]
    fn rejects_budget_overruns() {
        assert_eq!(
            reject_plan(|plan| plan.observed_read_bytes = plan.daily_read_budget_bytes + 1)
                .unwrap_err(),
            SsdWearBudgetError::DailyReadBudgetExceeded("wear-plan-a".to_string())
        );
        assert_eq!(
            reject_plan(|plan| plan.energy_millijoules = plan.energy_budget_millijoules + 1)
                .unwrap_err(),
            SsdWearBudgetError::EnergyBudgetExceeded("wear-plan-a".to_string())
        );
        assert_eq!(
            reject_plan(|plan| plan.cache_pollution_bps = plan.cache_pollution_budget_bps + 1)
                .unwrap_err(),
            SsdWearBudgetError::CachePollutionBudgetExceeded("wear-plan-a".to_string())
        );
    }

    #[test]
    fn rejects_missing_visible_refs() {
        assert_eq!(
            reject_plan(|plan| plan.budget_ref = "budget-a".to_string()).unwrap_err(),
            SsdWearBudgetError::MissingBudgetRef("wear-plan-a".to_string())
        );
        assert_eq!(
            reject_plan(|plan| plan.answer_packet_ref = "packet-a".to_string()).unwrap_err(),
            SsdWearBudgetError::MissingAnswerPacket("wear-plan-a".to_string())
        );
        assert_eq!(
            reject_plan(|plan| plan.visible_wear_caveat = "silent".to_string()).unwrap_err(),
            SsdWearBudgetError::MissingWearCaveat("wear-plan-a".to_string())
        );
    }

    #[test]
    fn rejects_hidden_authority_and_runtime_bytes() {
        assert_eq!(
            reject_plan(|plan| plan.hidden_route_authority = true).unwrap_err(),
            SsdWearBudgetError::HiddenRouteAuthority
        );
        assert_eq!(
            reject_plan(|plan| plan.runtime_bytes_loaded = 1).unwrap_err(),
            SsdWearBudgetError::RuntimeBytesLoaded
        );
        assert!(SsdWearBudgetWitness::new(
            ProductBuild::Mas,
            ProStatus::ResearchCandidate,
            "wear_budget_only",
            fixture_plans().expect("plans"),
            fixture_surfaces().expect("surfaces"),
            4_000,
            4_500,
            4_750,
            4_250,
        )
        .is_err());
    }

    #[test]
    fn witness_revalidates_mutated_plans() {
        let mut plans = fixture_plans().expect("plans");
        plans[0].observed_write_bytes = plans[0].daily_write_budget_bytes + 1;
        assert_eq!(
            SsdWearBudgetWitness::new(
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                "wear_budget_only",
                plans,
                fixture_surfaces().expect("surfaces"),
                4_000,
                4_500,
                4_750,
                4_250,
            )
            .unwrap_err(),
            SsdWearBudgetError::DailyWriteBudgetExceeded("wear-plan-a".to_string())
        );
    }

    fn reject_plan(
        mutate: impl FnOnce(&mut SsdWearBudgetPlan),
    ) -> Result<SsdWearBudgetWitness, SsdWearBudgetError> {
        let mut plans = fixture_plans()?;
        mutate(&mut plans[0]);
        SsdWearBudgetWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "wear_budget_only",
            plans,
            fixture_surfaces()?,
            4_000,
            4_500,
            4_750,
            4_250,
        )
    }

    fn fixture_witness() -> Result<SsdWearBudgetWitness, SsdWearBudgetError> {
        SsdWearBudgetWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "wear_budget_only",
            fixture_plans()?,
            fixture_surfaces()?,
            4_000,
            4_500,
            4_750,
            4_250,
        )
    }

    fn fixture_plans() -> Result<Vec<SsdWearBudgetPlan>, SsdWearBudgetError> {
        ["a", "b", "c"]
            .into_iter()
            .enumerate()
            .map(|(index, suffix)| {
                let read = 64 * 1024 * (index as u64 + 2);
                let write = 8 * 1024 * (index as u64 + 1);
                plan(suffix, read, write)
            })
            .collect()
    }

    fn plan(suffix: &str, read: u64, write: u64) -> Result<SsdWearBudgetPlan, SsdWearBudgetError> {
        SsdWearBudgetPlan::new(
            format!("wear-plan-{suffix}"),
            format!("route:{suffix}"),
            format!("ssd_wear_budget:{suffix}"),
            format!("transport_trace:{suffix}"),
            format!("answer_packet:{suffix}"),
            format!("run_event_log:{suffix}"),
            format!("rollback:{suffix}"),
            format!("admission:{suffix}"),
            format!("scope_rex:{suffix}"),
            format!("sovereign_gate:{suffix}"),
            format!("compat:{suffix}"),
            format!("cache_policy:{suffix}"),
            read,
            write,
            read * 8,
            write * 8 + 1,
            read * 4,
            write * 4 + 1,
            90 + read / 1024,
            1_000,
            640,
            1_000,
            11_200,
            30_000,
            format!(
                "SSD wear, energy, and cache impact are visible in AnswerPacket; fallback remains visible and rollback: {suffix} is bound."
            ),
            format!(
                "AnswerPacket shows SSD wear budget for {read} read bytes and {write} write bytes with energy and cache caveats before cold transport affects output."
            ),
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            0,
            0,
            32 * 1024,
        )
    }

    fn fixture_surfaces() -> Result<Vec<SsdWearBudgetSurface>, SsdWearBudgetError> {
        ["a", "b", "c"]
            .into_iter()
            .map(|suffix| {
                SsdWearBudgetSurface::new(
                    format!("surface-{suffix}"),
                    format!("answer_packet:{suffix}"),
                    format!("AnswerPacket visible SSD wear budget surface {suffix}: bytes, energy, cache, fallback, and rollback caveats are shown; no hidden runtime promotion is claimed."),
                    vec![
                        "SSD wear".to_string(),
                        "AnswerPacket".to_string(),
                        "rollback".to_string(),
                    ],
                    vec!["70B route is live".to_string(), "hidden reasoning".to_string()],
                )
            })
            .collect()
    }
}
