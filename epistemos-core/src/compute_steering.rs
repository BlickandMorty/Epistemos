use crate::runtime_contract::{
    ExecutionMode, ReasoningProfile, RuntimeCapabilities, RuntimeContractError,
};
use serde::Deserialize;

// ── Core Enums ──────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ComputeProfile {
    Standard,
    DeepGraph,
    Adaptive,
    Experimental,
    VisualSidecar,
}

impl ComputeProfile {
    pub fn label(self) -> &'static str {
        match self {
            Self::Standard => "standard",
            Self::DeepGraph => "deep_graph",
            Self::Adaptive => "adaptive",
            Self::Experimental => "experimental",
            Self::VisualSidecar => "visual_sidecar",
        }
    }
}

impl From<ReasoningProfile> for ComputeProfile {
    fn from(profile: ReasoningProfile) -> Self {
        match profile {
            ReasoningProfile::Standard => Self::Standard,
            ReasoningProfile::Deep => Self::DeepGraph,
            ReasoningProfile::Adaptive => Self::Adaptive,
            ReasoningProfile::Experimental => Self::Experimental,
            ReasoningProfile::VisualSidecar => Self::VisualSidecar,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExpertBudgetClass {
    Default,
    Constrained,
    Deep,
}

impl ExpertBudgetClass {
    pub fn label(self) -> &'static str {
        match self {
            Self::Default => "default",
            Self::Constrained => "constrained",
            Self::Deep => "deep",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum KVPolicyKind {
    Baseline,
    Compressed,
    Blocked,
}

impl KVPolicyKind {
    pub fn label(self) -> &'static str {
        match self {
            Self::Baseline => "baseline",
            Self::Compressed => "compressed",
            Self::Blocked => "blocked",
        }
    }
}

// ── Compute Budget ──────────────────────────────────────────────────────────

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct ComputeBudget {
    pub max_wall_ms: Option<u64>,
    pub max_tokens: Option<u32>,
    pub max_io_bytes: Option<u64>,
    pub max_adapt_steps: Option<u32>,
    pub max_aux_calls: Option<u32>,
}

impl ComputeBudget {
    pub fn is_unbounded(&self) -> bool {
        self.max_wall_ms.is_none()
            && self.max_tokens.is_none()
            && self.max_io_bytes.is_none()
            && self.max_adapt_steps.is_none()
            && self.max_aux_calls.is_none()
    }
}

// ── Masking Subsystem ───────────────────────────────────────────────────────

#[derive(Debug, Clone, PartialEq, Deserialize)]
pub struct StructuredMaskPlan {
    pub expert_allowlist: Vec<String>,
    #[serde(default = "default_block_size")]
    pub block_size: u32,
    pub rationale: Option<String>,
}

fn default_block_size() -> u32 {
    128
}

impl Default for StructuredMaskPlan {
    fn default() -> Self {
        Self {
            expert_allowlist: Vec::new(),
            block_size: 128,
            rationale: None,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct ValidatedMask {
    pub plan: StructuredMaskPlan,
    pub active_block_count: u32,
    pub sparsity_ratio: f64,
    pub is_kernel_compatible: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MaskCompileError {
    EmptyAllowlist,
    UnknownExpertName(String),
    SparsityTooAggressive,
    IncompatibleQuantLayout,
    InternalError(String),
}

impl std::fmt::Display for MaskCompileError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::EmptyAllowlist => write!(f, "mask expert allowlist is empty"),
            Self::UnknownExpertName(name) => write!(f, "unknown expert name: {name}"),
            Self::SparsityTooAggressive => {
                write!(f, "sparsity ratio exceeds Phase 2 maximum (70%)")
            }
            Self::IncompatibleQuantLayout => {
                write!(f, "mask layout incompatible with quant format")
            }
            Self::InternalError(msg) => write!(f, "mask compile internal error: {msg}"),
        }
    }
}

impl std::error::Error for MaskCompileError {}

#[derive(Debug, Clone, PartialEq)]
pub enum MaskingState {
    Dense,
    Structured(ValidatedMask),
    #[cfg(feature = "learned_mask_predictor")]
    Predicted(PredictedMask),
    #[cfg(feature = "diet_experiment")]
    DietProfile(String),
    #[cfg(feature = "dip_experiment")]
    DipExperiment(String),
}

impl MaskingState {
    pub fn label(&self) -> &str {
        match self {
            Self::Dense => "dense",
            Self::Structured(_) => "structured",
            #[cfg(feature = "learned_mask_predictor")]
            Self::Predicted(_) => "predicted",
            #[cfg(feature = "diet_experiment")]
            Self::DietProfile(_) => "diet",
            #[cfg(feature = "dip_experiment")]
            Self::DipExperiment(_) => "dip",
        }
    }
}

const MAX_SPARSITY_RATIO_PHASE2: f64 = 0.70;
#[cfg(feature = "learned_mask_predictor")]
const MAX_SPARSITY_RATIO_PREDICTED: f64 = 0.60;

// ── Phase 4: Learned Mask Predictor Types ───────────────────────────────────

#[derive(Debug, Clone, PartialEq)]
pub struct PredictedMask {
    pub layer_masks: Vec<LayerBlockMask>,
    pub confidence: f64,
    pub predictor_model_id: String,
    pub calibration_version: String,
    pub overall_sparsity: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct LayerBlockMask {
    pub layer_index: u32,
    pub active_blocks: Vec<u32>,
    pub total_blocks: u32,
    pub sparsity: f64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MaskPredictError {
    PredictorUnavailable,
    InstructionTooShort,
    ModelMetadataMissing,
    PredictionFailed(String),
    SparsityExceedsCap,
    LowConfidence,
}

impl std::fmt::Display for MaskPredictError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::PredictorUnavailable => write!(f, "mask predictor model is not available"),
            Self::InstructionTooShort => write!(f, "instruction too short for mask prediction"),
            Self::ModelMetadataMissing => write!(f, "target model metadata not available"),
            Self::PredictionFailed(msg) => write!(f, "mask prediction failed: {msg}"),
            Self::SparsityExceedsCap => write!(f, "predicted sparsity exceeds Phase 4 cap (60%)"),
            Self::LowConfidence => write!(f, "prediction confidence below threshold"),
        }
    }
}

impl std::error::Error for MaskPredictError {}

pub struct MaskCompiler;

impl MaskCompiler {
    pub fn compile(
        plan: &StructuredMaskPlan,
        known_experts: &[&str],
    ) -> Result<ValidatedMask, MaskCompileError> {
        if plan.expert_allowlist.is_empty() {
            return Err(MaskCompileError::EmptyAllowlist);
        }

        for name in &plan.expert_allowlist {
            if !known_experts.contains(&name.as_str()) {
                return Err(MaskCompileError::UnknownExpertName(name.clone()));
            }
        }

        let total_experts = known_experts.len() as f64;
        let active_experts = plan.expert_allowlist.len() as f64;
        let sparsity_ratio = if total_experts > 0.0 {
            1.0 - (active_experts / total_experts)
        } else {
            0.0
        };

        if sparsity_ratio > MAX_SPARSITY_RATIO_PHASE2 {
            return Err(MaskCompileError::SparsityTooAggressive);
        }

        let active_block_count = plan.expert_allowlist.len() as u32;
        let is_kernel_compatible = plan.block_size >= 64 && plan.block_size.is_power_of_two();

        Ok(ValidatedMask {
            plan: plan.clone(),
            active_block_count,
            sparsity_ratio,
            is_kernel_compatible,
        })
    }

    #[cfg(feature = "learned_mask_predictor")]
    pub fn compile_predicted(
        predicted: &PredictedMask,
        min_confidence: f64,
    ) -> Result<PredictedMask, MaskPredictError> {
        if predicted.confidence < min_confidence {
            return Err(MaskPredictError::LowConfidence);
        }

        if predicted.overall_sparsity > MAX_SPARSITY_RATIO_PREDICTED {
            return Err(MaskPredictError::SparsityExceedsCap);
        }

        for layer in &predicted.layer_masks {
            if layer.sparsity > MAX_SPARSITY_RATIO_PREDICTED {
                return Err(MaskPredictError::SparsityExceedsCap);
            }
            if layer.active_blocks.is_empty() && layer.total_blocks > 0 {
                return Err(MaskPredictError::PredictionFailed(format!(
                    "layer {} has no active blocks",
                    layer.layer_index
                )));
            }
        }

        Ok(predicted.clone())
    }
}

// ── SteeringGraph (ExecutionGraph DAG) ──────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SteeringGraphNode {
    RetrieveContext,
    GraphScore,
    RerankContext,
    CompressHistory,
    SelectMask,
    GenerateMain,
    AdaptHelper,
    ImageSidecar,
}

impl SteeringGraphNode {
    pub fn label(self) -> &'static str {
        match self {
            Self::RetrieveContext => "retrieve_context",
            Self::GraphScore => "graph_score",
            Self::RerankContext => "rerank_context",
            Self::CompressHistory => "compress_history",
            Self::SelectMask => "select_mask",
            Self::GenerateMain => "generate_main",
            Self::AdaptHelper => "adapt_helper",
            Self::ImageSidecar => "image_sidecar",
        }
    }

    fn requires_gpu(self) -> bool {
        matches!(
            self,
            Self::GenerateMain | Self::AdaptHelper | Self::ImageSidecar | Self::GraphScore
        )
    }

    fn requires_ssd(self) -> bool {
        matches!(self, Self::RetrieveContext | Self::CompressHistory)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NodeResourceEstimate {
    pub estimated_memory_bytes: u64,
    pub estimated_wall_ms: u64,
    pub estimated_io_bytes: u64,
    pub is_adapt_step: bool,
    pub is_aux_call: bool,
    pub requires_gpu: bool,
    pub requires_ssd: bool,
}

impl NodeResourceEstimate {
    fn for_node(node: SteeringGraphNode) -> Self {
        let (wall_ms, io_bytes, is_adapt, is_aux) = match node {
            SteeringGraphNode::RetrieveContext => (50, 1_000_000, false, true),
            SteeringGraphNode::GraphScore => (20, 0, false, true),
            SteeringGraphNode::RerankContext => (30, 0, false, true),
            SteeringGraphNode::CompressHistory => (100, 500_000, false, true),
            SteeringGraphNode::SelectMask => (10, 0, false, false),
            SteeringGraphNode::GenerateMain => (0, 0, false, false),
            SteeringGraphNode::AdaptHelper => (200, 0, true, true),
            SteeringGraphNode::ImageSidecar => (5000, 0, false, true),
        };
        Self {
            estimated_memory_bytes: 0,
            estimated_wall_ms: wall_ms,
            estimated_io_bytes: io_bytes,
            is_adapt_step: is_adapt,
            is_aux_call: is_aux,
            requires_gpu: node.requires_gpu(),
            requires_ssd: node.requires_ssd(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SteeringGraph {
    pub steps: Vec<(SteeringGraphNode, NodeResourceEstimate)>,
}

impl SteeringGraph {
    pub fn node_labels(&self) -> Vec<&'static str> {
        self.steps.iter().map(|(node, _)| node.label()).collect()
    }

    fn validate_serial_invariant(&self) -> Result<(), RuntimeContractError> {
        let mut gpu_active = false;
        for (node, estimate) in &self.steps {
            if gpu_active && estimate.requires_ssd {
                return Err(RuntimeContractError::ContractViolation);
            }
            gpu_active = estimate.requires_gpu;
            let _ = node;
        }
        Ok(())
    }

    fn validate_budget(&self, budget: &Option<ComputeBudget>) -> Result<(), RuntimeContractError> {
        let Some(budget) = budget else {
            return Ok(());
        };

        if let Some(max_wall_ms) = budget.max_wall_ms {
            let total_wall: u64 = self.steps.iter().map(|(_, e)| e.estimated_wall_ms).sum();
            if total_wall > max_wall_ms {
                return Err(RuntimeContractError::PolicyDenied);
            }
        }

        if let Some(max_io_bytes) = budget.max_io_bytes {
            let total_io: u64 = self.steps.iter().map(|(_, e)| e.estimated_io_bytes).sum();
            if total_io > max_io_bytes {
                return Err(RuntimeContractError::PolicyDenied);
            }
        }

        if let Some(max_adapt_steps) = budget.max_adapt_steps {
            let adapt_count = self.steps.iter().filter(|(_, e)| e.is_adapt_step).count() as u32;
            if adapt_count > max_adapt_steps {
                return Err(RuntimeContractError::PolicyDenied);
            }
        }

        if let Some(max_aux_calls) = budget.max_aux_calls {
            let aux_count = self.steps.iter().filter(|(_, e)| e.is_aux_call).count() as u32;
            if aux_count > max_aux_calls {
                return Err(RuntimeContractError::PolicyDenied);
            }
        }

        Ok(())
    }
}

fn is_node_supported(node: SteeringGraphNode, capabilities: &RuntimeCapabilities) -> bool {
    match node {
        SteeringGraphNode::GenerateMain => capabilities.supports_generate,
        SteeringGraphNode::AdaptHelper => capabilities.supports_adapt,
        SteeringGraphNode::ImageSidecar => capabilities.supports_image_generate,
        SteeringGraphNode::SelectMask => capabilities.supports_structured_masking,
        SteeringGraphNode::RetrieveContext
        | SteeringGraphNode::GraphScore
        | SteeringGraphNode::RerankContext
        | SteeringGraphNode::CompressHistory => true,
    }
}

pub fn build_graph(
    profile: ComputeProfile,
    capabilities: &RuntimeCapabilities,
    budget: &Option<ComputeBudget>,
) -> Result<SteeringGraph, RuntimeContractError> {
    let candidate_nodes = match profile {
        ComputeProfile::Standard => vec![SteeringGraphNode::GenerateMain],
        ComputeProfile::DeepGraph => vec![
            SteeringGraphNode::RetrieveContext,
            SteeringGraphNode::GraphScore,
            SteeringGraphNode::RerankContext,
            SteeringGraphNode::GenerateMain,
        ],
        ComputeProfile::Adaptive => {
            let mut nodes = vec![
                SteeringGraphNode::RetrieveContext,
                SteeringGraphNode::RerankContext,
                SteeringGraphNode::GenerateMain,
            ];
            if capabilities.supports_adapt {
                nodes.push(SteeringGraphNode::AdaptHelper);
            }
            nodes
        }
        ComputeProfile::Experimental => vec![
            SteeringGraphNode::RetrieveContext,
            SteeringGraphNode::GraphScore,
            SteeringGraphNode::RerankContext,
            SteeringGraphNode::CompressHistory,
            SteeringGraphNode::SelectMask,
            SteeringGraphNode::GenerateMain,
            SteeringGraphNode::AdaptHelper,
        ],
        ComputeProfile::VisualSidecar => vec![
            SteeringGraphNode::GenerateMain,
            SteeringGraphNode::ImageSidecar,
        ],
    };

    let mut steps = Vec::new();
    for node in &candidate_nodes {
        if !is_node_supported(*node, capabilities) {
            if *node == SteeringGraphNode::GenerateMain {
                return Err(RuntimeContractError::UnsupportedCapability);
            }
            continue;
        }
        steps.push((*node, NodeResourceEstimate::for_node(*node)));
    }

    if steps.is_empty()
        || !steps
            .iter()
            .any(|(n, _)| *n == SteeringGraphNode::GenerateMain)
    {
        return Err(RuntimeContractError::UnsupportedCapability);
    }

    let graph = SteeringGraph { steps };

    graph.validate_serial_invariant()?;

    if let Err(_) = graph.validate_budget(budget) {
        let minimal = SteeringGraph {
            steps: vec![(
                SteeringGraphNode::GenerateMain,
                NodeResourceEstimate::for_node(SteeringGraphNode::GenerateMain),
            )],
        };
        return Ok(minimal);
    }

    Ok(graph)
}

// ── Overseer Hints ──────────────────────────────────────────────────────────

#[derive(Debug, Clone, PartialEq, Default, Deserialize)]
pub struct DepthBudgetHint {
    pub max_turns: u32,
    pub max_reasoning_steps: u32,
    pub max_tool_calls: u32,
    pub max_output_tokens: u32,
}

#[derive(Debug, Clone, PartialEq, Default, Deserialize)]
pub struct LoRABlendCoefficient {
    pub adapter_id: String,
    pub coefficient: f64,
}

#[derive(Debug, Clone, PartialEq, Default, Deserialize)]
pub struct OverseerHints {
    pub mask_plan: Option<StructuredMaskPlan>,
    pub kv_policy_hint: Option<String>,
    pub depth_budget: Option<DepthBudgetHint>,
    pub lora_blend_coefficients: Option<Vec<LoRABlendCoefficient>>,
}

impl OverseerHints {
    pub fn from_json(json: &str) -> Option<Self> {
        serde_json::from_str(json).ok()
    }
}

// ── Resolution ──────────────────────────────────────────────────────────────

#[derive(Debug, Clone, PartialEq)]
pub struct SteeringResolution {
    pub execution_policy_id: String,
    pub compute_profile: ComputeProfile,
    pub compute_budget: Option<ComputeBudget>,
    pub expert_budget_class: ExpertBudgetClass,
    pub kv_policy_kind: KVPolicyKind,
    pub masking_state: MaskingState,
    pub adaptation_state: String,
    pub guardrail_state: String,
    pub sidecar_state: String,
    pub budget_outcome: String,
    pub plan_trace_present: bool,
    pub steering_graph: SteeringGraph,
}

fn resolve_expert_budget_class(
    profile: ComputeProfile,
    budget: &Option<ComputeBudget>,
    memory_pressure: bool,
) -> ExpertBudgetClass {
    if memory_pressure {
        return ExpertBudgetClass::Constrained;
    }

    if let Some(budget) = budget {
        if let Some(max_aux) = budget.max_aux_calls {
            if max_aux <= 2 {
                return ExpertBudgetClass::Constrained;
            }
        }
    }

    match profile {
        ComputeProfile::Standard | ComputeProfile::VisualSidecar => ExpertBudgetClass::Default,
        ComputeProfile::DeepGraph => ExpertBudgetClass::Deep,
        ComputeProfile::Adaptive => ExpertBudgetClass::Default,
        ComputeProfile::Experimental => ExpertBudgetClass::Deep,
    }
}

// ── Expert Budget Tracker (per-turn live tracking) ──────────────────────────

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ExpertBudgetTracker {
    pub budget_class: ExpertBudgetClass,
    pub max_aux_calls: Option<u32>,
    pub aux_calls_used: u32,
    pub max_adapt_steps: Option<u32>,
    pub adapt_steps_used: u32,
}

impl ExpertBudgetTracker {
    pub fn new(budget_class: ExpertBudgetClass, budget: &Option<ComputeBudget>) -> Self {
        Self {
            budget_class,
            max_aux_calls: budget.as_ref().and_then(|b| b.max_aux_calls),
            aux_calls_used: 0,
            max_adapt_steps: budget.as_ref().and_then(|b| b.max_adapt_steps),
            adapt_steps_used: 0,
        }
    }

    pub fn record_aux_call(&mut self) -> bool {
        self.aux_calls_used += 1;
        if let Some(max) = self.max_aux_calls {
            self.aux_calls_used <= max
        } else {
            true
        }
    }

    pub fn record_adapt_step(&mut self) -> bool {
        self.adapt_steps_used += 1;
        if let Some(max) = self.max_adapt_steps {
            self.adapt_steps_used <= max
        } else {
            true
        }
    }

    pub fn is_exhausted(&self) -> bool {
        if let Some(max) = self.max_aux_calls {
            if self.aux_calls_used >= max {
                return true;
            }
        }
        if let Some(max) = self.max_adapt_steps {
            if self.adapt_steps_used >= max {
                return true;
            }
        }
        false
    }

    pub fn telemetry_label(&self) -> String {
        format!(
            "{}(aux={}/{}|adapt={}/{})",
            self.budget_class.label(),
            self.aux_calls_used,
            self.max_aux_calls
                .map(|m| m.to_string())
                .unwrap_or("∞".into()),
            self.adapt_steps_used,
            self.max_adapt_steps
                .map(|m| m.to_string())
                .unwrap_or("∞".into()),
        )
    }
}

fn resolve_kv_policy(
    _profile: ComputeProfile,
    capabilities: &RuntimeCapabilities,
    hints: &Option<OverseerHints>,
) -> KVPolicyKind {
    if let Some(hints) = hints {
        if let Some(hint) = &hints.kv_policy_hint {
            match hint.as_str() {
                "flush_all" | "reset_for_domain_switch" => {
                    if capabilities.supports_kv_policy {
                        return KVPolicyKind::Blocked;
                    }
                }
                "compressed" => {
                    if capabilities.supports_kv_policy {
                        return KVPolicyKind::Compressed;
                    }
                }
                _ => {}
            }
        }
    }
    KVPolicyKind::Baseline
}

fn resolve_masking_state(
    capabilities: &RuntimeCapabilities,
    hints: &Option<OverseerHints>,
    known_experts: &[&str],
) -> MaskingState {
    if !capabilities.supports_structured_masking {
        return MaskingState::Dense;
    }

    if let Some(hints) = hints {
        if let Some(mask_plan) = &hints.mask_plan {
            if known_experts.is_empty() {
                return MaskingState::Dense;
            }
            match MaskCompiler::compile(mask_plan, known_experts) {
                Ok(validated) => return MaskingState::Structured(validated),
                Err(_) => return MaskingState::Dense,
            }
        }
    }

    MaskingState::Dense
}

fn resolve_adaptation_state(profile: ComputeProfile) -> &'static str {
    match profile {
        ComputeProfile::Adaptive => "helper_model_only",
        _ => "disabled",
    }
}

fn resolve_guardrail_state(profile: ComputeProfile) -> &'static str {
    match profile {
        ComputeProfile::Experimental => "experimental",
        ComputeProfile::VisualSidecar => "visual_sidecar",
        _ => "clear",
    }
}

pub fn resolve(
    reasoning_profile: ReasoningProfile,
    execution_mode: ExecutionMode,
    capabilities: &RuntimeCapabilities,
    execution_policy_ref: Option<&str>,
    overseer_hints: Option<OverseerHints>,
) -> Result<SteeringResolution, RuntimeContractError> {
    resolve_with_experts(
        reasoning_profile,
        execution_mode,
        capabilities,
        execution_policy_ref,
        overseer_hints,
        &[],
    )
}

pub fn resolve_with_experts(
    reasoning_profile: ReasoningProfile,
    execution_mode: ExecutionMode,
    capabilities: &RuntimeCapabilities,
    execution_policy_ref: Option<&str>,
    overseer_hints: Option<OverseerHints>,
    known_experts: &[&str],
) -> Result<SteeringResolution, RuntimeContractError> {
    let compute_profile = ComputeProfile::from(reasoning_profile);

    let resolved_execution_policy_id = format!(
        "policy.{}.{}",
        reasoning_profile.label(),
        execution_mode.label()
    );
    if let Some(requested) = execution_policy_ref {
        if requested != resolved_execution_policy_id {
            return Err(RuntimeContractError::PolicyDenied);
        }
    }

    let compute_budget = overseer_hints.as_ref().and_then(|hints| {
        hints.depth_budget.as_ref().map(|db| ComputeBudget {
            max_wall_ms: None,
            max_tokens: Some(db.max_output_tokens),
            max_io_bytes: None,
            max_adapt_steps: None,
            max_aux_calls: Some(db.max_tool_calls),
        })
    });

    let memory_pressure = overseer_hints
        .as_ref()
        .and_then(|h| h.kv_policy_hint.as_deref())
        .map(|h| h == "flush_all" || h == "reset_for_domain_switch")
        .unwrap_or(false);

    let expert_budget_class =
        resolve_expert_budget_class(compute_profile, &compute_budget, memory_pressure);
    let kv_policy_kind = resolve_kv_policy(compute_profile, capabilities, &overseer_hints);
    let masking_state = resolve_masking_state(capabilities, &overseer_hints, known_experts);
    let adaptation_state = resolve_adaptation_state(compute_profile).to_string();
    let guardrail_state = resolve_guardrail_state(compute_profile).to_string();

    let full_graph = build_graph(compute_profile, capabilities, &compute_budget)?;

    let sidecar_state = if full_graph
        .steps
        .iter()
        .any(|(n, _)| *n == SteeringGraphNode::ImageSidecar)
    {
        "active".to_string()
    } else {
        "disabled".to_string()
    };

    let budget_outcome =
        if full_graph.steps.len() <= 1 && !matches!(compute_profile, ComputeProfile::Standard) {
            "trimmed_to_minimal_graph".to_string()
        } else {
            "within_budget".to_string()
        };

    Ok(SteeringResolution {
        execution_policy_id: resolved_execution_policy_id,
        compute_profile,
        compute_budget,
        expert_budget_class,
        kv_policy_kind,
        masking_state,
        adaptation_state,
        guardrail_state,
        sidecar_state,
        budget_outcome,
        plan_trace_present: true,
        steering_graph: full_graph,
    })
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn gguf_capabilities() -> RuntimeCapabilities {
        RuntimeCapabilities {
            supports_generate: true,
            supports_embed: false,
            supports_adapt: false,
            supports_image_generate: false,
            supports_structured_masking: false,
            supports_dynamic_sparsity: false,
            supports_speculative_decoding: false,
            supports_streaming_from_ssd: true,
            supports_kv_policy: false,
            supports_expert_budgeting: false,
            supports_serial_io_audit: true,
            supports_tool_calls: false,
        }
    }

    fn full_capabilities() -> RuntimeCapabilities {
        RuntimeCapabilities {
            supports_generate: true,
            supports_embed: true,
            supports_adapt: true,
            supports_image_generate: true,
            supports_structured_masking: true,
            supports_dynamic_sparsity: true,
            supports_speculative_decoding: true,
            supports_streaming_from_ssd: true,
            supports_kv_policy: true,
            supports_expert_budgeting: true,
            supports_serial_io_audit: true,
            supports_tool_calls: true,
        }
    }

    // ── Profile resolution ──────────────────────────────────────────────

    #[test]
    fn standard_profile_resolves_to_default_expert_budget() {
        let res = resolve(
            ReasoningProfile::Standard,
            ExecutionMode::Local,
            &gguf_capabilities(),
            None,
            None,
        )
        .unwrap();
        assert_eq!(res.expert_budget_class, ExpertBudgetClass::Default);
        assert_eq!(res.compute_profile, ComputeProfile::Standard);
    }

    #[test]
    fn deep_graph_resolves_to_deep_expert_budget() {
        let res = resolve(
            ReasoningProfile::Deep,
            ExecutionMode::Local,
            &gguf_capabilities(),
            None,
            None,
        )
        .unwrap();
        assert_eq!(res.expert_budget_class, ExpertBudgetClass::Deep);
        assert_eq!(res.compute_profile, ComputeProfile::DeepGraph);
    }

    #[test]
    fn adaptive_resolves_to_default_budget_with_helper_adaptation() {
        let res = resolve(
            ReasoningProfile::Adaptive,
            ExecutionMode::Local,
            &gguf_capabilities(),
            None,
            None,
        )
        .unwrap();
        assert_eq!(res.expert_budget_class, ExpertBudgetClass::Default);
        assert_eq!(res.adaptation_state, "helper_model_only");
    }

    #[test]
    fn visual_sidecar_resolves_to_default_budget() {
        let res = resolve(
            ReasoningProfile::VisualSidecar,
            ExecutionMode::Local,
            &gguf_capabilities(),
            None,
            None,
        )
        .unwrap();
        assert_eq!(res.expert_budget_class, ExpertBudgetClass::Default);
        assert_eq!(res.guardrail_state, "visual_sidecar");
    }

    // ── Mask compiler ───────────────────────────────────────────────────

    #[test]
    fn mask_compiler_rejects_empty_allowlist() {
        let plan = StructuredMaskPlan {
            expert_allowlist: vec![],
            block_size: 128,
            rationale: None,
        };
        let result = MaskCompiler::compile(&plan, &["a", "b", "c"]);
        assert!(matches!(result, Err(MaskCompileError::EmptyAllowlist)));
    }

    #[test]
    fn mask_compiler_rejects_unknown_expert_name() {
        let plan = StructuredMaskPlan {
            expert_allowlist: vec!["unknown_expert".into()],
            block_size: 128,
            rationale: None,
        };
        let result = MaskCompiler::compile(&plan, &["a", "b", "c"]);
        assert!(matches!(
            result,
            Err(MaskCompileError::UnknownExpertName(_))
        ));
    }

    #[test]
    fn mask_compiler_accepts_valid_allowlist() {
        let plan = StructuredMaskPlan {
            expert_allowlist: vec!["a".into(), "b".into()],
            block_size: 128,
            rationale: Some("test mask".into()),
        };
        let result = MaskCompiler::compile(&plan, &["a", "b", "c"]);
        assert!(result.is_ok());
        let mask = result.unwrap();
        assert_eq!(mask.active_block_count, 2);
        assert!((mask.sparsity_ratio - (1.0 / 3.0)).abs() < 0.01);
        assert!(mask.is_kernel_compatible);
    }

    #[test]
    fn mask_compiler_rejects_excessive_sparsity() {
        let plan = StructuredMaskPlan {
            expert_allowlist: vec!["a".into()],
            block_size: 128,
            rationale: None,
        };
        let known: Vec<&str> = (0..10)
            .map(|i| {
                // leak is fine in tests for creating &'static str
                Box::leak(format!("expert_{i}").into_boxed_str()) as &str
            })
            .collect();
        let mut known_with_a = known.clone();
        known_with_a.push("a");
        let result = MaskCompiler::compile(&plan, &known_with_a);
        assert!(matches!(
            result,
            Err(MaskCompileError::SparsityTooAggressive)
        ));
    }

    #[test]
    fn unsupported_mask_falls_back_to_dense() {
        let res = resolve(
            ReasoningProfile::Standard,
            ExecutionMode::Local,
            &gguf_capabilities(),
            None,
            Some(OverseerHints {
                mask_plan: Some(StructuredMaskPlan {
                    expert_allowlist: vec!["a".into()],
                    block_size: 128,
                    rationale: None,
                }),
                ..Default::default()
            }),
        )
        .unwrap();
        assert_eq!(res.masking_state.label(), "dense");
    }

    #[test]
    fn dense_fallback_is_always_available() {
        let res = resolve(
            ReasoningProfile::Standard,
            ExecutionMode::Local,
            &gguf_capabilities(),
            None,
            None,
        )
        .unwrap();
        assert_eq!(res.masking_state, MaskingState::Dense);
    }

    // ── KV policy ───────────────────────────────────────────────────────

    #[test]
    fn kv_policy_baseline_is_default() {
        let res = resolve(
            ReasoningProfile::Standard,
            ExecutionMode::Local,
            &gguf_capabilities(),
            None,
            None,
        )
        .unwrap();
        assert_eq!(res.kv_policy_kind, KVPolicyKind::Baseline);
    }

    #[test]
    fn kv_policy_compressed_requires_capability() {
        let res_no_cap = resolve(
            ReasoningProfile::Standard,
            ExecutionMode::Local,
            &gguf_capabilities(),
            None,
            Some(OverseerHints {
                kv_policy_hint: Some("compressed".into()),
                ..Default::default()
            }),
        )
        .unwrap();
        assert_eq!(res_no_cap.kv_policy_kind, KVPolicyKind::Baseline);

        let res_with_cap = resolve(
            ReasoningProfile::Standard,
            ExecutionMode::Local,
            &full_capabilities(),
            None,
            Some(OverseerHints {
                kv_policy_hint: Some("compressed".into()),
                ..Default::default()
            }),
        )
        .unwrap();
        assert_eq!(res_with_cap.kv_policy_kind, KVPolicyKind::Compressed);
    }

    #[test]
    fn kv_policy_blocked_maps_from_overseer_flush_all() {
        let res = resolve(
            ReasoningProfile::Standard,
            ExecutionMode::Local,
            &full_capabilities(),
            None,
            Some(OverseerHints {
                kv_policy_hint: Some("flush_all".into()),
                ..Default::default()
            }),
        )
        .unwrap();
        assert_eq!(res.kv_policy_kind, KVPolicyKind::Blocked);
    }

    // ── Steering graph ──────────────────────────────────────────────────

    #[test]
    fn standard_graph_is_generate_main_only() {
        let graph = build_graph(ComputeProfile::Standard, &gguf_capabilities(), &None).unwrap();
        assert_eq!(graph.steps.len(), 1);
        assert_eq!(graph.steps[0].0, SteeringGraphNode::GenerateMain);
    }

    #[test]
    fn deep_graph_includes_retrieval_and_scoring() {
        let graph = build_graph(ComputeProfile::DeepGraph, &gguf_capabilities(), &None).unwrap();
        let labels = graph.node_labels();
        assert!(labels.contains(&"retrieve_context"));
        assert!(labels.contains(&"graph_score"));
        assert!(labels.contains(&"rerank_context"));
        assert!(labels.contains(&"generate_main"));
    }

    #[test]
    fn steering_graph_rejects_unsupported_nodes() {
        let graph =
            build_graph(ComputeProfile::VisualSidecar, &gguf_capabilities(), &None).unwrap();
        let labels = graph.node_labels();
        assert!(labels.contains(&"generate_main"));
        assert!(!labels.contains(&"image_sidecar"));
    }

    #[test]
    fn steering_graph_enforces_serial_invariant() {
        let bad_graph = SteeringGraph {
            steps: vec![
                (
                    SteeringGraphNode::GenerateMain,
                    NodeResourceEstimate {
                        estimated_memory_bytes: 0,
                        estimated_wall_ms: 0,
                        estimated_io_bytes: 0,
                        is_adapt_step: false,
                        is_aux_call: false,
                        requires_gpu: true,
                        requires_ssd: false,
                    },
                ),
                (
                    SteeringGraphNode::RetrieveContext,
                    NodeResourceEstimate {
                        estimated_memory_bytes: 0,
                        estimated_wall_ms: 0,
                        estimated_io_bytes: 0,
                        is_adapt_step: false,
                        is_aux_call: false,
                        requires_gpu: false,
                        requires_ssd: true,
                    },
                ),
            ],
        };
        assert!(bad_graph.validate_serial_invariant().is_err());
    }

    #[test]
    fn steering_graph_rejects_when_budget_exceeded() {
        let budget = Some(ComputeBudget {
            max_wall_ms: Some(1),
            ..Default::default()
        });
        let graph = SteeringGraph {
            steps: vec![(
                SteeringGraphNode::GenerateMain,
                NodeResourceEstimate {
                    estimated_memory_bytes: 0,
                    estimated_wall_ms: 100,
                    estimated_io_bytes: 0,
                    is_adapt_step: false,
                    is_aux_call: false,
                    requires_gpu: true,
                    requires_ssd: false,
                },
            )],
        };
        assert!(graph.validate_budget(&budget).is_err());
    }

    #[test]
    fn steering_graph_falls_back_to_minimal_on_budget_rejection() {
        let budget = Some(ComputeBudget {
            max_io_bytes: Some(1),
            ..Default::default()
        });
        let mut caps = gguf_capabilities();
        caps.supports_structured_masking = true;

        let graph = build_graph(ComputeProfile::Experimental, &caps, &budget).unwrap();
        assert_eq!(graph.steps.len(), 1);
        assert_eq!(graph.steps[0].0, SteeringGraphNode::GenerateMain);
    }

    // ── Compute budget ──────────────────────────────────────────────────

    #[test]
    fn compute_budget_all_none_is_unbounded() {
        let budget = ComputeBudget::default();
        assert!(budget.is_unbounded());
    }

    #[test]
    fn compute_budget_fields_are_independent() {
        let budget = ComputeBudget {
            max_wall_ms: Some(5000),
            max_tokens: None,
            max_io_bytes: None,
            max_adapt_steps: None,
            max_aux_calls: Some(3),
        };
        assert!(!budget.is_unbounded());
        assert_eq!(budget.max_wall_ms, Some(5000));
        assert_eq!(budget.max_tokens, None);
        assert_eq!(budget.max_aux_calls, Some(3));
    }

    // ── Feature gate tests ──────────────────────────────────────────────

    #[test]
    #[cfg(not(feature = "diet_experiment"))]
    fn diet_masking_state_unavailable_without_feature() {
        // When diet_experiment feature is off, the DietProfile variant doesn't exist.
        // We verify dense is the only non-structured option.
        let state = MaskingState::Dense;
        assert_eq!(state.label(), "dense");
    }

    #[test]
    #[cfg(feature = "diet_experiment")]
    fn diet_masking_state_available_with_feature() {
        let state = MaskingState::DietProfile("global_mask_v1".into());
        assert_eq!(state.label(), "diet");
    }

    #[test]
    #[cfg(not(feature = "dip_experiment"))]
    fn dip_masking_state_unavailable_without_feature() {
        let state = MaskingState::Dense;
        assert_eq!(state.label(), "dense");
    }

    #[test]
    #[cfg(feature = "dip_experiment")]
    fn dip_masking_state_available_with_feature() {
        let state = MaskingState::DipExperiment("swiglu_dip_v1".into());
        assert_eq!(state.label(), "dip");
    }

    // ── Integration: full round-trip ────────────────────────────────────

    #[test]
    fn full_resolution_round_trip() {
        let res = resolve(
            ReasoningProfile::Deep,
            ExecutionMode::Local,
            &gguf_capabilities(),
            Some("policy.deep_graph.local"),
            None,
        )
        .unwrap();

        assert_eq!(res.compute_profile, ComputeProfile::DeepGraph);
        assert_eq!(res.expert_budget_class.label(), "deep");
        assert_eq!(res.kv_policy_kind.label(), "baseline");
        assert_eq!(res.masking_state.label(), "dense");
        assert_eq!(res.adaptation_state, "disabled");
        assert_eq!(res.guardrail_state, "clear");
        assert!(res.plan_trace_present);
        assert_eq!(res.execution_policy_id, "policy.deep_graph.local");

        let labels = res.steering_graph.node_labels();
        assert!(labels.contains(&"generate_main"));
        assert!(labels.contains(&"retrieve_context"));
    }

    #[test]
    fn policy_mismatch_is_denied() {
        let result = resolve(
            ReasoningProfile::Standard,
            ExecutionMode::Local,
            &gguf_capabilities(),
            Some("policy.deep_graph.local"),
            None,
        );
        assert!(matches!(result, Err(RuntimeContractError::PolicyDenied)));
    }

    // ── Fix verification tests ──────────────────────────────────────────

    #[test]
    fn overseer_hints_parse_from_json() {
        let json = r#"{
            "kv_policy_hint": "flush_all",
            "mask_plan": {
                "expert_allowlist": ["expert_a", "expert_b"],
                "block_size": 128,
                "rationale": "test"
            },
            "depth_budget": {
                "max_turns": 3,
                "max_reasoning_steps": 10,
                "max_tool_calls": 5,
                "max_output_tokens": 2048
            },
            "lora_blend_coefficients": [
                {"adapter_id": "coding", "coefficient": 0.7}
            ]
        }"#;
        let hints = OverseerHints::from_json(json);
        assert!(hints.is_some());
        let hints = hints.unwrap();
        assert_eq!(hints.kv_policy_hint.as_deref(), Some("flush_all"));
        assert!(hints.mask_plan.is_some());
        assert_eq!(hints.depth_budget.as_ref().unwrap().max_tool_calls, 5);
        assert_eq!(hints.lora_blend_coefficients.as_ref().unwrap().len(), 1);
    }

    #[test]
    fn overseer_hints_from_invalid_json_returns_none() {
        assert!(OverseerHints::from_json("not json").is_none());
    }

    #[test]
    fn overseer_hints_from_empty_json_object_returns_defaults() {
        let hints = OverseerHints::from_json("{}").unwrap();
        assert!(hints.mask_plan.is_none());
        assert!(hints.kv_policy_hint.is_none());
        assert!(hints.depth_budget.is_none());
        assert!(hints.lora_blend_coefficients.is_none());
    }

    #[test]
    fn resolve_with_experts_validates_against_known_experts() {
        let mut caps = full_capabilities();
        caps.supports_structured_masking = true;

        let res = resolve_with_experts(
            ReasoningProfile::Standard,
            ExecutionMode::Local,
            &caps,
            None,
            Some(OverseerHints {
                mask_plan: Some(StructuredMaskPlan {
                    expert_allowlist: vec!["expert_a".into()],
                    block_size: 128,
                    rationale: None,
                }),
                ..Default::default()
            }),
            &["expert_a", "expert_b", "expert_c"],
        )
        .unwrap();
        assert_eq!(res.masking_state.label(), "structured");

        let res_unknown = resolve_with_experts(
            ReasoningProfile::Standard,
            ExecutionMode::Local,
            &caps,
            None,
            Some(OverseerHints {
                mask_plan: Some(StructuredMaskPlan {
                    expert_allowlist: vec!["unknown_expert".into()],
                    block_size: 128,
                    rationale: None,
                }),
                ..Default::default()
            }),
            &["expert_a", "expert_b", "expert_c"],
        )
        .unwrap();
        assert_eq!(res_unknown.masking_state.label(), "dense");
    }

    #[test]
    fn empty_known_experts_yields_dense_even_with_mask_hints() {
        let mut caps = full_capabilities();
        caps.supports_structured_masking = true;

        let res = resolve_with_experts(
            ReasoningProfile::Standard,
            ExecutionMode::Local,
            &caps,
            None,
            Some(OverseerHints {
                mask_plan: Some(StructuredMaskPlan {
                    expert_allowlist: vec!["a".into()],
                    block_size: 128,
                    rationale: None,
                }),
                ..Default::default()
            }),
            &[],
        )
        .unwrap();
        assert_eq!(res.masking_state.label(), "dense");
    }

    #[test]
    fn budget_enforces_max_adapt_steps() {
        let budget = Some(ComputeBudget {
            max_adapt_steps: Some(0),
            ..Default::default()
        });
        let mut caps = full_capabilities();
        caps.supports_adapt = true;

        let graph = build_graph(ComputeProfile::Adaptive, &caps, &budget).unwrap();
        assert_eq!(graph.steps.len(), 1);
        assert_eq!(graph.steps[0].0, SteeringGraphNode::GenerateMain);
    }

    #[test]
    fn budget_enforces_max_aux_calls() {
        let budget = Some(ComputeBudget {
            max_aux_calls: Some(0),
            ..Default::default()
        });
        let graph = build_graph(ComputeProfile::DeepGraph, &gguf_capabilities(), &budget).unwrap();
        assert_eq!(graph.steps.len(), 1);
        assert_eq!(graph.steps[0].0, SteeringGraphNode::GenerateMain);
    }

    #[test]
    fn hints_flow_through_kv_policy_with_capabilities() {
        let json = r#"{"kv_policy_hint": "compressed"}"#;
        let hints = OverseerHints::from_json(json);

        let res = resolve(
            ReasoningProfile::Standard,
            ExecutionMode::Local,
            &full_capabilities(),
            None,
            hints,
        )
        .unwrap();
        assert_eq!(res.kv_policy_kind, KVPolicyKind::Compressed);
    }

    #[test]
    fn mlx_runtime_capabilities_differ_from_gguf() {
        use crate::runtime_contract::RuntimeKind;
        let gguf_caps = RuntimeCapabilities::for_runtime(RuntimeKind::Gguf);
        let mlx_caps = RuntimeCapabilities::for_runtime(RuntimeKind::Mlx);
        assert!(!gguf_caps.supports_embed);
        assert!(mlx_caps.supports_embed);
    }

    // ── Phase 4: Advanced Expert Budgeting ──────────────────────────────

    #[test]
    fn memory_pressure_produces_constrained_budget() {
        let class = resolve_expert_budget_class(ComputeProfile::DeepGraph, &None, true);
        assert_eq!(class, ExpertBudgetClass::Constrained);
    }

    #[test]
    fn tight_aux_budget_produces_constrained() {
        let budget = Some(ComputeBudget {
            max_aux_calls: Some(1),
            ..Default::default()
        });
        let class = resolve_expert_budget_class(ComputeProfile::Standard, &budget, false);
        assert_eq!(class, ExpertBudgetClass::Constrained);
    }

    #[test]
    fn no_pressure_no_tight_budget_uses_profile_default() {
        let class = resolve_expert_budget_class(ComputeProfile::DeepGraph, &None, false);
        assert_eq!(class, ExpertBudgetClass::Deep);
    }

    #[test]
    fn expert_budget_tracker_records_aux_calls() {
        let mut tracker = ExpertBudgetTracker::new(
            ExpertBudgetClass::Default,
            &Some(ComputeBudget {
                max_aux_calls: Some(2),
                ..Default::default()
            }),
        );
        assert!(tracker.record_aux_call());
        assert!(tracker.record_aux_call());
        assert!(!tracker.record_aux_call());
        assert!(tracker.is_exhausted());
    }

    #[test]
    fn expert_budget_tracker_telemetry_label() {
        let tracker = ExpertBudgetTracker::new(
            ExpertBudgetClass::Deep,
            &Some(ComputeBudget {
                max_aux_calls: Some(5),
                max_adapt_steps: Some(3),
                ..Default::default()
            }),
        );
        let label = tracker.telemetry_label();
        assert!(label.contains("deep"));
        assert!(label.contains("aux=0/5"));
        assert!(label.contains("adapt=0/3"));
    }

    #[test]
    fn expert_budget_tracker_unbounded_never_exhausts() {
        let mut tracker = ExpertBudgetTracker::new(ExpertBudgetClass::Default, &None);
        for _ in 0..100 {
            assert!(tracker.record_aux_call());
        }
        assert!(!tracker.is_exhausted());
    }

    #[test]
    fn flush_all_hint_triggers_constrained_budget() {
        let res = resolve(
            ReasoningProfile::Deep,
            ExecutionMode::Local,
            &gguf_capabilities(),
            None,
            Some(OverseerHints {
                kv_policy_hint: Some("flush_all".into()),
                ..Default::default()
            }),
        )
        .unwrap();
        assert_eq!(res.expert_budget_class, ExpertBudgetClass::Constrained);
    }

    // ── Phase 4: Learned Mask Predictor ─────────────────────────────────

    #[test]
    #[cfg(feature = "learned_mask_predictor")]
    fn predicted_mask_compiles_when_valid() {
        let predicted = PredictedMask {
            layer_masks: vec![LayerBlockMask {
                layer_index: 0,
                active_blocks: vec![0, 1, 2],
                total_blocks: 8,
                sparsity: 0.375,
            }],
            confidence: 0.8,
            predictor_model_id: "ifpruning-v1".into(),
            calibration_version: "2026-04".into(),
            overall_sparsity: 0.375,
        };
        let result = MaskCompiler::compile_predicted(&predicted, 0.6);
        assert!(result.is_ok());
    }

    #[test]
    #[cfg(feature = "learned_mask_predictor")]
    fn predicted_mask_rejects_low_confidence() {
        let predicted = PredictedMask {
            layer_masks: vec![],
            confidence: 0.3,
            predictor_model_id: "test".into(),
            calibration_version: "v1".into(),
            overall_sparsity: 0.1,
        };
        let result = MaskCompiler::compile_predicted(&predicted, 0.6);
        assert!(matches!(result, Err(MaskPredictError::LowConfidence)));
    }

    #[test]
    #[cfg(feature = "learned_mask_predictor")]
    fn predicted_mask_rejects_excessive_sparsity() {
        let predicted = PredictedMask {
            layer_masks: vec![LayerBlockMask {
                layer_index: 0,
                active_blocks: vec![0],
                total_blocks: 10,
                sparsity: 0.9,
            }],
            confidence: 0.9,
            predictor_model_id: "test".into(),
            calibration_version: "v1".into(),
            overall_sparsity: 0.9,
        };
        let result = MaskCompiler::compile_predicted(&predicted, 0.6);
        assert!(matches!(result, Err(MaskPredictError::SparsityExceedsCap)));
    }

    #[test]
    #[cfg(feature = "learned_mask_predictor")]
    fn predicted_mask_rejects_empty_layer_blocks() {
        let predicted = PredictedMask {
            layer_masks: vec![LayerBlockMask {
                layer_index: 0,
                active_blocks: vec![],
                total_blocks: 8,
                sparsity: 0.5,
            }],
            confidence: 0.9,
            predictor_model_id: "test".into(),
            calibration_version: "v1".into(),
            overall_sparsity: 0.5,
        };
        let result = MaskCompiler::compile_predicted(&predicted, 0.6);
        assert!(matches!(result, Err(MaskPredictError::PredictionFailed(_))));
    }

    #[test]
    #[cfg(not(feature = "learned_mask_predictor"))]
    fn predicted_masking_state_unavailable_without_feature() {
        let state = MaskingState::Dense;
        assert_eq!(state.label(), "dense");
    }
}
