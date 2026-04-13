use std::collections::{HashMap, VecDeque};
use std::sync::Mutex;

fn next_handle_id(prefix: &str) -> String {
    format!("{prefix}-{:016x}", rand::random::<u64>())
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RuntimeKind {
    Gguf,
    Mlx,
    Remote,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExecutionMode {
    Local,
    Remote,
    Hybrid,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReasoningProfile {
    Standard,
    Deep,
    Adaptive,
    Experimental,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RuntimeOperation {
    Generate,
    Embed,
    Adapt,
    ImageGenerate,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RuntimeContractError {
    ModelNotFound,
    ModelNotLoaded,
    UnsupportedCapability,
    Timeout,
    Cancelled,
    PolicyDenied,
    RuntimeUnavailable,
    MemoryPressure,
    InvalidTransition,
    BackendFailure,
    ContractViolation,
}

impl std::fmt::Display for RuntimeContractError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let label = match self {
            Self::ModelNotFound => "model_not_found",
            Self::ModelNotLoaded => "model_not_loaded",
            Self::UnsupportedCapability => "unsupported_capability",
            Self::Timeout => "timeout",
            Self::Cancelled => "cancelled",
            Self::PolicyDenied => "policy_denied",
            Self::RuntimeUnavailable => "runtime_unavailable",
            Self::MemoryPressure => "memory_pressure",
            Self::InvalidTransition => "invalid_transition",
            Self::BackendFailure => "backend_failure",
            Self::ContractViolation => "contract_violation",
        };
        f.write_str(label)
    }
}

impl std::error::Error for RuntimeContractError {}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GenerationEventKind {
    Started,
    Token,
    Status,
    ToolStatus,
    Summary,
    Completed,
    Failed,
    Cancelled,
}

impl GenerationEventKind {
    fn is_terminal(self) -> bool {
        matches!(self, Self::Completed | Self::Failed | Self::Cancelled)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RuntimePolicy {
    pub available_runtime_kinds: Vec<RuntimeKind>,
    pub primary_generation_runtime_kind: RuntimeKind,
    pub allow_mlx_generation_fallback: bool,
    pub allowed_reasoning_profiles: Vec<ReasoningProfile>,
    pub default_reasoning_profile: ReasoningProfile,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RuntimeModelLoadRequest {
    pub requested_runtime_kind: Option<RuntimeKind>,
    pub execution_mode: ExecutionMode,
    pub model_id: String,
    pub artifact_id: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RuntimeModelHandle {
    pub handle_id: String,
    pub runtime_kind: RuntimeKind,
    pub execution_mode: ExecutionMode,
    pub model_id: String,
    pub artifact_id: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct RuntimeGenerationStreamOptions {
    pub include_status_events: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RuntimeHandshakeRequest {
    pub requested_runtime_kind: Option<RuntimeKind>,
    pub execution_mode: ExecutionMode,
    pub operation: RuntimeOperation,
    pub reasoning_profile: Option<ReasoningProfile>,
    pub execution_policy_ref: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RuntimeHandshake {
    pub requested_runtime_kind: Option<RuntimeKind>,
    pub resolved_runtime_kind: RuntimeKind,
    pub requested_reasoning_profile: Option<ReasoningProfile>,
    pub resolved_reasoning_profile: Option<ReasoningProfile>,
    pub execution_policy_id: Option<String>,
    pub capabilities: RuntimeCapabilities,
    pub used_fallback_resolution: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub struct RuntimeGenerationRequest {
    pub request_id: String,
    pub requested_runtime_kind: Option<RuntimeKind>,
    pub execution_mode: ExecutionMode,
    pub model_id: String,
    pub artifact_id: Option<String>,
    pub model_handle_id: Option<String>,
    pub prompt: String,
    pub system_prompt: Option<String>,
    pub max_output_tokens: u32,
    pub temperature: f64,
    pub stop_sequences: Vec<String>,
    pub tool_policy_ref: Option<String>,
    pub context_ref: Option<String>,
    pub reasoning_profile: Option<ReasoningProfile>,
    pub execution_policy_ref: Option<String>,
    pub priority: i32,
    pub timeout_ms: u32,
    pub stream_options: RuntimeGenerationStreamOptions,
}

#[derive(Debug, Clone, PartialEq)]
pub struct RuntimeGenerationSummary {
    pub request_id: String,
    pub requested_runtime_kind: Option<RuntimeKind>,
    pub resolved_runtime_kind: RuntimeKind,
    pub requested_reasoning_profile: Option<ReasoningProfile>,
    pub resolved_reasoning_profile: ReasoningProfile,
    pub execution_mode: ExecutionMode,
    pub model_id: String,
    pub artifact_id: Option<String>,
    pub execution_policy_id: Option<String>,
    pub fallback_mode: String,
    pub time_to_first_token_ms: Option<f64>,
    pub total_duration_ms: f64,
    pub tokens_per_second: Option<f64>,
    pub output_token_count: u32,
    pub output_character_count: u32,
    pub memory_pressure_state: String,
    pub execution_phase: String,
    pub masking_state: String,
    pub kv_policy_state: String,
    pub expert_budget_state: String,
    pub adaptation_state: String,
    pub guardrail_state: String,
    pub cancelled: bool,
    pub error_class: Option<RuntimeContractError>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct RuntimeGenerationEvent {
    pub kind: GenerationEventKind,
    pub text: Option<String>,
    pub status: Option<String>,
    pub summary: Option<RuntimeGenerationSummary>,
    pub error_class: Option<RuntimeContractError>,
    pub error_message: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RuntimeStatsTarget {
    pub model_handle_id: Option<String>,
    pub stream_handle: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RuntimeStats {
    pub requested_runtime_kind: Option<RuntimeKind>,
    pub resolved_runtime_kind: Option<RuntimeKind>,
    pub requested_reasoning_profile: Option<ReasoningProfile>,
    pub resolved_reasoning_profile: Option<ReasoningProfile>,
    pub model_id: Option<String>,
    pub artifact_id: Option<String>,
    pub execution_policy_id: Option<String>,
    pub fallback_mode: Option<String>,
    pub memory_pressure_state: Option<String>,
    pub execution_phase: Option<String>,
    pub masking_state: String,
    pub kv_policy_state: String,
    pub expert_budget_state: String,
    pub adaptation_state: String,
    pub guardrail_state: String,
    pub capabilities: RuntimeCapabilities,
    pub cancelled: bool,
    pub terminal_event_emitted: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RuntimeCapabilities {
    pub supports_generate: bool,
    pub supports_embed: bool,
    pub supports_adapt: bool,
    pub supports_image_generate: bool,
    pub supports_structured_masking: bool,
    pub supports_dynamic_sparsity: bool,
    pub supports_speculative_decoding: bool,
    pub supports_streaming_from_ssd: bool,
    pub supports_kv_policy: bool,
    pub supports_expert_budgeting: bool,
    pub supports_serial_io_audit: bool,
    pub supports_tool_calls: bool,
}

impl RuntimeCapabilities {
    fn for_runtime(runtime_kind: RuntimeKind) -> Self {
        match runtime_kind {
            RuntimeKind::Gguf => Self {
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
            },
            RuntimeKind::Mlx => Self {
                supports_generate: true,
                supports_embed: true,
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
            },
            RuntimeKind::Remote => Self {
                supports_generate: false,
                supports_embed: false,
                supports_adapt: false,
                supports_image_generate: false,
                supports_structured_masking: false,
                supports_dynamic_sparsity: false,
                supports_speculative_decoding: false,
                supports_streaming_from_ssd: false,
                supports_kv_policy: false,
                supports_expert_budgeting: false,
                supports_serial_io_audit: false,
                supports_tool_calls: false,
            },
        }
    }

    fn supports_operation(&self, operation: RuntimeOperation) -> bool {
        match operation {
            RuntimeOperation::Generate => self.supports_generate,
            RuntimeOperation::Embed => self.supports_embed,
            RuntimeOperation::Adapt => self.supports_adapt,
            RuntimeOperation::ImageGenerate => self.supports_image_generate,
        }
    }
}

#[derive(Debug, Clone)]
struct StreamState {
    requested_runtime_kind: Option<RuntimeKind>,
    resolved_runtime_kind: RuntimeKind,
    requested_reasoning_profile: Option<ReasoningProfile>,
    resolved_reasoning_profile: ReasoningProfile,
    execution_plan: RuntimeExecutionPlan,
    model_handle: RuntimeModelHandle,
    events: VecDeque<RuntimeGenerationEvent>,
    started_emitted: bool,
    terminal_emitted: bool,
    cancellation_requested: bool,
    latest_summary: Option<RuntimeGenerationSummary>,
}

impl StreamState {
    fn new(
        requested_runtime_kind: Option<RuntimeKind>,
        resolved_runtime_kind: RuntimeKind,
        requested_reasoning_profile: Option<ReasoningProfile>,
        resolved_reasoning_profile: ReasoningProfile,
        execution_plan: RuntimeExecutionPlan,
        model_handle: RuntimeModelHandle,
    ) -> Self {
        Self {
            requested_runtime_kind,
            resolved_runtime_kind,
            requested_reasoning_profile,
            resolved_reasoning_profile,
            execution_plan,
            model_handle,
            events: VecDeque::new(),
            started_emitted: false,
            terminal_emitted: false,
            cancellation_requested: false,
            latest_summary: None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct RuntimeExecutionPlan {
    execution_policy_id: String,
    masking_state: String,
    kv_policy_state: String,
    expert_budget_state: String,
    adaptation_state: String,
    guardrail_state: String,
}

impl RuntimeExecutionPlan {
    fn resolved(
        execution_mode: ExecutionMode,
        reasoning_profile: ReasoningProfile,
        requested_execution_policy_id: Option<&str>,
    ) -> Result<Self, RuntimeContractError> {
        let resolved_execution_policy_id =
            format!("policy.{}.{}", reasoning_profile.label(), execution_mode.label());
        if let Some(requested_execution_policy_id) = requested_execution_policy_id {
            if requested_execution_policy_id != resolved_execution_policy_id {
                return Err(RuntimeContractError::PolicyDenied);
            }
        }

        let expert_budget_state = match reasoning_profile {
            ReasoningProfile::Standard => "default",
            ReasoningProfile::Deep => "deep",
            ReasoningProfile::Adaptive => "adaptive_helper",
            ReasoningProfile::Experimental => "experimental",
        };
        let adaptation_state = match reasoning_profile {
            ReasoningProfile::Adaptive => "helper_model_only",
            ReasoningProfile::Standard
            | ReasoningProfile::Deep
            | ReasoningProfile::Experimental => "disabled",
        };
        let guardrail_state = match reasoning_profile {
            ReasoningProfile::Experimental => "experimental",
            ReasoningProfile::Standard
            | ReasoningProfile::Deep
            | ReasoningProfile::Adaptive => "clear",
        };

        Ok(Self {
            execution_policy_id: resolved_execution_policy_id,
            masking_state: "dense".into(),
            kv_policy_state: "baseline".into(),
            expert_budget_state: expert_budget_state.into(),
            adaptation_state: adaptation_state.into(),
            guardrail_state: guardrail_state.into(),
        })
    }
}

impl ReasoningProfile {
    fn label(self) -> &'static str {
        match self {
            Self::Standard => "standard",
            Self::Deep => "deep",
            Self::Adaptive => "adaptive",
            Self::Experimental => "experimental",
        }
    }
}

impl ExecutionMode {
    fn label(self) -> &'static str {
        match self {
            Self::Local => "local",
            Self::Remote => "remote",
            Self::Hybrid => "hybrid",
        }
    }
}

pub struct RuntimeControlPlane {
    policy: Mutex<RuntimePolicy>,
    model_handles: Mutex<HashMap<String, RuntimeModelHandle>>,
    streams: Mutex<HashMap<String, StreamState>>,
}

impl RuntimeControlPlane {
    pub fn new(
        available_runtime_kinds: Vec<RuntimeKind>,
        primary_generation_runtime_kind: RuntimeKind,
        allow_mlx_generation_fallback: bool,
    ) -> Self {
        Self {
            policy: Mutex::new(RuntimePolicy {
                available_runtime_kinds,
                primary_generation_runtime_kind,
                allow_mlx_generation_fallback,
                allowed_reasoning_profiles: vec![ReasoningProfile::Standard, ReasoningProfile::Deep],
                default_reasoning_profile: ReasoningProfile::Standard,
            }),
            model_handles: Mutex::new(HashMap::new()),
            streams: Mutex::new(HashMap::new()),
        }
    }

    pub fn set_policy(&self, policy: RuntimePolicy) {
        if let Ok(mut current) = self.policy.lock() {
            *current = policy;
        }
    }

    pub fn load_model(
        &self,
        request: RuntimeModelLoadRequest,
    ) -> Result<RuntimeModelHandle, RuntimeContractError> {
        let resolved_runtime_kind =
            self.resolve_runtime_kind(request.requested_runtime_kind, RuntimeOperation::Generate)?;
        let handle = RuntimeModelHandle {
            handle_id: next_handle_id("model"),
            runtime_kind: resolved_runtime_kind,
            execution_mode: request.execution_mode,
            model_id: request.model_id,
            artifact_id: request.artifact_id,
        };
        self.model_handles
            .lock()
            .map_err(|_| RuntimeContractError::BackendFailure)?
            .insert(handle.handle_id.clone(), handle.clone());
        Ok(handle)
    }

    pub fn unload_model(&self, handle_id: String) -> Result<(), RuntimeContractError> {
        let removed = self
            .model_handles
            .lock()
            .map_err(|_| RuntimeContractError::BackendFailure)?
            .remove(&handle_id);
        if removed.is_some() {
            Ok(())
        } else {
            Err(RuntimeContractError::ModelNotLoaded)
        }
    }

    pub fn generate(
        &self,
        request: RuntimeGenerationRequest,
    ) -> Result<String, RuntimeContractError> {
        let handshake = self.handshake(RuntimeHandshakeRequest {
            requested_runtime_kind: request.requested_runtime_kind,
            execution_mode: request.execution_mode,
            operation: RuntimeOperation::Generate,
            reasoning_profile: request.reasoning_profile,
            execution_policy_ref: request.execution_policy_ref.clone(),
        })?;
        let resolved_runtime_kind = handshake.resolved_runtime_kind;
        let resolved_reasoning_profile = handshake
            .resolved_reasoning_profile
            .ok_or(RuntimeContractError::ContractViolation)?;
        let execution_plan = self.resolve_execution_plan(&request, resolved_reasoning_profile)?;
        let model_handle = self.resolve_or_load_model_handle(&request, resolved_runtime_kind)?;
        let stream_handle = next_handle_id("stream");
        let state = StreamState::new(
            request.requested_runtime_kind,
            resolved_runtime_kind,
            request.reasoning_profile,
            resolved_reasoning_profile,
            execution_plan,
            model_handle,
        );
        self.streams
            .lock()
            .map_err(|_| RuntimeContractError::BackendFailure)?
            .insert(stream_handle.clone(), state);
        Ok(stream_handle)
    }

    pub fn handshake(
        &self,
        request: RuntimeHandshakeRequest,
    ) -> Result<RuntimeHandshake, RuntimeContractError> {
        let resolved_runtime_kind =
            self.resolve_runtime_kind(request.requested_runtime_kind, request.operation)?;
        let capabilities = RuntimeCapabilities::for_runtime(resolved_runtime_kind);
        if !capabilities.supports_operation(request.operation) {
            return Err(RuntimeContractError::UnsupportedCapability);
        }

        let resolved_reasoning_profile = match request.operation {
            RuntimeOperation::Generate => {
                Some(self.resolve_reasoning_profile(request.reasoning_profile)?)
            }
            RuntimeOperation::Embed | RuntimeOperation::Adapt | RuntimeOperation::ImageGenerate => {
                None
            }
        };
        let execution_policy_id = match resolved_reasoning_profile {
            Some(resolved_reasoning_profile) => Some(
                RuntimeExecutionPlan::resolved(
                    request.execution_mode,
                    resolved_reasoning_profile,
                    request.execution_policy_ref.as_deref(),
                )?
                .execution_policy_id,
            ),
            None => None,
        };

        Ok(RuntimeHandshake {
            requested_runtime_kind: request.requested_runtime_kind,
            resolved_runtime_kind,
            requested_reasoning_profile: request.reasoning_profile,
            resolved_reasoning_profile,
            execution_policy_id,
            capabilities,
            used_fallback_resolution: matches!(
                request.requested_runtime_kind,
                Some(requested_runtime_kind) if requested_runtime_kind != resolved_runtime_kind
            ),
        })
    }

    pub fn emit_started(&self, stream_handle: String) -> Result<(), RuntimeContractError> {
        self.mutate_open_stream(&stream_handle, |stream| {
            if stream.started_emitted {
                return Err(RuntimeContractError::ContractViolation);
            }
            stream.started_emitted = true;
            stream.events.push_back(RuntimeGenerationEvent {
                kind: GenerationEventKind::Started,
                text: None,
                status: None,
                summary: None,
                error_class: None,
                error_message: None,
            });
            Ok(())
        })
    }

    pub fn emit_status(
        &self,
        stream_handle: String,
        status: String,
    ) -> Result<(), RuntimeContractError> {
        self.mutate_open_stream(&stream_handle, |stream| {
            if !stream.started_emitted {
                return Err(RuntimeContractError::ContractViolation);
            }
            stream.events.push_back(RuntimeGenerationEvent {
                kind: GenerationEventKind::Status,
                text: None,
                status: Some(status),
                summary: None,
                error_class: None,
                error_message: None,
            });
            Ok(())
        })
    }

    pub fn emit_token(
        &self,
        stream_handle: String,
        text: String,
    ) -> Result<(), RuntimeContractError> {
        self.mutate_open_stream(&stream_handle, |stream| {
            if !stream.started_emitted {
                return Err(RuntimeContractError::ContractViolation);
            }
            stream.events.push_back(RuntimeGenerationEvent {
                kind: GenerationEventKind::Token,
                text: Some(text),
                status: None,
                summary: None,
                error_class: None,
                error_message: None,
            });
            Ok(())
        })
    }

    pub fn emit_summary(
        &self,
        stream_handle: String,
        summary: RuntimeGenerationSummary,
    ) -> Result<(), RuntimeContractError> {
        self.mutate_open_stream(&stream_handle, |stream| {
            if !stream.started_emitted {
                return Err(RuntimeContractError::ContractViolation);
            }
            let normalized_summary = Self::normalized_summary(stream, summary);
            stream.latest_summary = Some(normalized_summary.clone());
            stream.events.push_back(RuntimeGenerationEvent {
                kind: GenerationEventKind::Summary,
                text: None,
                status: None,
                summary: Some(normalized_summary),
                error_class: None,
                error_message: None,
            });
            Ok(())
        })
    }

    pub fn finish_completed(
        &self,
        stream_handle: String,
        summary: RuntimeGenerationSummary,
    ) -> Result<(), RuntimeContractError> {
        self.finish_terminal_event(
            &stream_handle,
            RuntimeGenerationEvent {
                kind: GenerationEventKind::Completed,
                text: None,
                status: None,
                summary: Some(summary.clone()),
                error_class: summary.error_class,
                error_message: None,
            },
            Some(summary),
            false,
        )
    }

    pub fn finish_failed(
        &self,
        stream_handle: String,
        error_class: RuntimeContractError,
        error_message: String,
        summary: Option<RuntimeGenerationSummary>,
    ) -> Result<(), RuntimeContractError> {
        self.finish_terminal_event(
            &stream_handle,
            RuntimeGenerationEvent {
                kind: GenerationEventKind::Failed,
                text: None,
                status: None,
                summary: summary.clone(),
                error_class: Some(error_class),
                error_message: Some(error_message),
            },
            summary,
            false,
        )
    }

    pub fn finish_cancelled(
        &self,
        stream_handle: String,
        summary: Option<RuntimeGenerationSummary>,
    ) -> Result<(), RuntimeContractError> {
        self.finish_terminal_event(
            &stream_handle,
            RuntimeGenerationEvent {
                kind: GenerationEventKind::Cancelled,
                text: None,
                status: None,
                summary: summary.clone(),
                error_class: Some(RuntimeContractError::Cancelled),
                error_message: None,
            },
            summary,
            true,
        )
    }

    pub fn cancel(&self, stream_handle: String) -> Result<(), RuntimeContractError> {
        self.finish_cancelled(stream_handle, None)
    }

    pub fn poll_event(
        &self,
        stream_handle: String,
    ) -> Result<Option<RuntimeGenerationEvent>, RuntimeContractError> {
        let mut streams = self
            .streams
            .lock()
            .map_err(|_| RuntimeContractError::BackendFailure)?;
        let stream = streams
            .get_mut(&stream_handle)
            .ok_or(RuntimeContractError::ModelNotLoaded)?;
        Ok(stream.events.pop_front())
    }

    pub fn poll_events(
        &self,
        stream_handle: String,
        max_events: u32,
    ) -> Result<Vec<RuntimeGenerationEvent>, RuntimeContractError> {
        let mut streams = self
            .streams
            .lock()
            .map_err(|_| RuntimeContractError::BackendFailure)?;
        let stream = streams
            .get_mut(&stream_handle)
            .ok_or(RuntimeContractError::ModelNotLoaded)?;

        let count = max_events as usize;
        let mut events = Vec::with_capacity(count);
        for _ in 0..count {
            let Some(event) = stream.events.pop_front() else {
                break;
            };
            events.push(event);
        }
        Ok(events)
    }

    pub fn close_stream(&self, stream_handle: String) -> bool {
        self.streams
            .lock()
            .map(|mut streams| streams.remove(&stream_handle).is_some())
            .unwrap_or(false)
    }

    pub fn stats(
        &self,
        target: RuntimeStatsTarget,
    ) -> Result<RuntimeStats, RuntimeContractError> {
        if let Some(model_handle_id) = target.model_handle_id {
            let handles = self
                .model_handles
                .lock()
                .map_err(|_| RuntimeContractError::BackendFailure)?;
            let handle = handles
                .get(&model_handle_id)
                .ok_or(RuntimeContractError::ModelNotLoaded)?;
            return Ok(RuntimeStats {
                requested_runtime_kind: Some(handle.runtime_kind),
                resolved_runtime_kind: Some(handle.runtime_kind),
                requested_reasoning_profile: None,
                resolved_reasoning_profile: None,
                model_id: Some(handle.model_id.clone()),
                artifact_id: handle.artifact_id.clone(),
                execution_policy_id: None,
                fallback_mode: None,
                memory_pressure_state: None,
                execution_phase: None,
                masking_state: "dense".into(),
                kv_policy_state: "baseline".into(),
                expert_budget_state: "default".into(),
                adaptation_state: "disabled".into(),
                guardrail_state: "clear".into(),
                capabilities: RuntimeCapabilities::for_runtime(handle.runtime_kind),
                cancelled: false,
                terminal_event_emitted: false,
            });
        }

        let Some(stream_handle) = target.stream_handle else {
            return Err(RuntimeContractError::ModelNotLoaded);
        };
        let streams = self
            .streams
            .lock()
            .map_err(|_| RuntimeContractError::BackendFailure)?;
        let stream = streams
            .get(&stream_handle)
            .ok_or(RuntimeContractError::ModelNotLoaded)?;
        Ok(RuntimeStats {
            requested_runtime_kind: stream.requested_runtime_kind,
            resolved_runtime_kind: Some(stream.resolved_runtime_kind),
            requested_reasoning_profile: stream.requested_reasoning_profile,
            resolved_reasoning_profile: Some(stream.resolved_reasoning_profile),
            model_id: Some(stream.model_handle.model_id.clone()),
            artifact_id: stream.model_handle.artifact_id.clone(),
            execution_policy_id: stream
                .latest_summary
                .as_ref()
                .and_then(|summary| summary.execution_policy_id.clone())
                .or_else(|| Some(stream.execution_plan.execution_policy_id.clone())),
            fallback_mode: stream
                .latest_summary
                .as_ref()
                .map(|summary| summary.fallback_mode.clone()),
            memory_pressure_state: stream
                .latest_summary
                .as_ref()
                .map(|summary| summary.memory_pressure_state.clone()),
            execution_phase: stream
                .latest_summary
                .as_ref()
                .map(|summary| summary.execution_phase.clone()),
            masking_state: stream
                .latest_summary
                .as_ref()
                .map(|summary| summary.masking_state.clone())
                .unwrap_or_else(|| stream.execution_plan.masking_state.clone()),
            kv_policy_state: stream
                .latest_summary
                .as_ref()
                .map(|summary| summary.kv_policy_state.clone())
                .unwrap_or_else(|| stream.execution_plan.kv_policy_state.clone()),
            expert_budget_state: stream
                .latest_summary
                .as_ref()
                .map(|summary| summary.expert_budget_state.clone())
                .unwrap_or_else(|| stream.execution_plan.expert_budget_state.clone()),
            adaptation_state: stream
                .latest_summary
                .as_ref()
                .map(|summary| summary.adaptation_state.clone())
                .unwrap_or_else(|| stream.execution_plan.adaptation_state.clone()),
            guardrail_state: stream
                .latest_summary
                .as_ref()
                .map(|summary| summary.guardrail_state.clone())
                .unwrap_or_else(|| stream.execution_plan.guardrail_state.clone()),
            capabilities: RuntimeCapabilities::for_runtime(stream.resolved_runtime_kind),
            cancelled: stream.cancellation_requested,
            terminal_event_emitted: stream.terminal_emitted,
        })
    }

    pub fn embed(&self) -> Result<(), RuntimeContractError> {
        let _ = self.resolve_runtime_kind(None, RuntimeOperation::Embed)?;
        Ok(())
    }

    pub fn adapt(&self) -> Result<(), RuntimeContractError> {
        let _ = self.resolve_runtime_kind(None, RuntimeOperation::Adapt)?;
        Err(RuntimeContractError::UnsupportedCapability)
    }

    pub fn image_generate(&self) -> Result<(), RuntimeContractError> {
        let _ = self.resolve_runtime_kind(None, RuntimeOperation::ImageGenerate)?;
        Err(RuntimeContractError::UnsupportedCapability)
    }

    fn resolve_runtime_kind(
        &self,
        requested_runtime_kind: Option<RuntimeKind>,
        operation: RuntimeOperation,
    ) -> Result<RuntimeKind, RuntimeContractError> {
        let policy = self
            .policy
            .lock()
            .map_err(|_| RuntimeContractError::BackendFailure)?
            .clone();
        match operation {
            RuntimeOperation::Embed | RuntimeOperation::Adapt | RuntimeOperation::ImageGenerate => {
                if policy.available_runtime_kinds.contains(&RuntimeKind::Mlx) {
                    Ok(RuntimeKind::Mlx)
                } else {
                    Err(RuntimeContractError::UnsupportedCapability)
                }
            }
            RuntimeOperation::Generate => {
                if let Some(requested_runtime_kind) = requested_runtime_kind {
                    if policy
                        .available_runtime_kinds
                        .contains(&requested_runtime_kind)
                    {
                        return Ok(requested_runtime_kind);
                    }
                    if requested_runtime_kind == RuntimeKind::Gguf
                        && policy.allow_mlx_generation_fallback
                        && policy.available_runtime_kinds.contains(&RuntimeKind::Mlx)
                    {
                        return Ok(RuntimeKind::Mlx);
                    }
                    return Err(RuntimeContractError::RuntimeUnavailable);
                }

                if policy
                    .available_runtime_kinds
                    .contains(&policy.primary_generation_runtime_kind)
                {
                    return Ok(policy.primary_generation_runtime_kind);
                }

                if policy.allow_mlx_generation_fallback
                    && policy.available_runtime_kinds.contains(&RuntimeKind::Mlx)
                {
                    return Ok(RuntimeKind::Mlx);
                }

                Err(RuntimeContractError::RuntimeUnavailable)
            }
        }
    }

    fn resolve_reasoning_profile(
        &self,
        requested_reasoning_profile: Option<ReasoningProfile>,
    ) -> Result<ReasoningProfile, RuntimeContractError> {
        let policy = self
            .policy
            .lock()
            .map_err(|_| RuntimeContractError::BackendFailure)?
            .clone();
        let resolved_reasoning_profile =
            requested_reasoning_profile.unwrap_or(policy.default_reasoning_profile);
        if policy
            .allowed_reasoning_profiles
            .contains(&resolved_reasoning_profile)
        {
            Ok(resolved_reasoning_profile)
        } else {
            Err(RuntimeContractError::PolicyDenied)
        }
    }

    fn resolve_execution_plan(
        &self,
        request: &RuntimeGenerationRequest,
        resolved_reasoning_profile: ReasoningProfile,
    ) -> Result<RuntimeExecutionPlan, RuntimeContractError> {
        RuntimeExecutionPlan::resolved(
            request.execution_mode,
            resolved_reasoning_profile,
            request.execution_policy_ref.as_deref(),
        )
    }

    fn resolve_or_load_model_handle(
        &self,
        request: &RuntimeGenerationRequest,
        resolved_runtime_kind: RuntimeKind,
    ) -> Result<RuntimeModelHandle, RuntimeContractError> {
        if let Some(model_handle_id) = &request.model_handle_id {
            let handles = self
                .model_handles
                .lock()
                .map_err(|_| RuntimeContractError::BackendFailure)?;
            let handle = handles
                .get(model_handle_id)
                .ok_or(RuntimeContractError::ModelNotLoaded)?;
            if handle.runtime_kind != resolved_runtime_kind {
                return Err(RuntimeContractError::InvalidTransition);
            }
            return Ok(handle.clone());
        }

        self.load_model(RuntimeModelLoadRequest {
            requested_runtime_kind: request.requested_runtime_kind,
            execution_mode: request.execution_mode,
            model_id: request.model_id.clone(),
            artifact_id: request.artifact_id.clone(),
        })
    }

    fn finish_terminal_event(
        &self,
        stream_handle: &str,
        event: RuntimeGenerationEvent,
        summary: Option<RuntimeGenerationSummary>,
        cancelled: bool,
    ) -> Result<(), RuntimeContractError> {
        self.mutate_open_stream(stream_handle, |stream| {
            if !stream.started_emitted {
                return Err(RuntimeContractError::ContractViolation);
            }
            if !event.kind.is_terminal() {
                return Err(RuntimeContractError::ContractViolation);
            }
            let normalized_summary = summary.map(|summary| {
                let mut normalized_summary = Self::normalized_summary(stream, summary);
                normalized_summary.cancelled = cancelled;
                normalized_summary
            });
            let mut normalized_event = event;
            normalized_event.summary = normalized_summary.clone();
            stream.latest_summary = normalized_summary;
            stream.cancellation_requested = cancelled;
            stream.terminal_emitted = true;
            stream.events.push_back(normalized_event);
            Ok(())
        })
    }

    fn mutate_open_stream(
        &self,
        stream_handle: &str,
        body: impl FnOnce(&mut StreamState) -> Result<(), RuntimeContractError>,
    ) -> Result<(), RuntimeContractError> {
        let mut streams = self
            .streams
            .lock()
            .map_err(|_| RuntimeContractError::BackendFailure)?;
        let stream = streams
            .get_mut(stream_handle)
            .ok_or(RuntimeContractError::ModelNotLoaded)?;
        if stream.terminal_emitted {
            return Err(RuntimeContractError::ContractViolation);
        }
        body(stream)
    }

    fn normalized_summary(
        stream: &StreamState,
        mut summary: RuntimeGenerationSummary,
    ) -> RuntimeGenerationSummary {
        summary.requested_runtime_kind = stream.requested_runtime_kind;
        summary.resolved_runtime_kind = stream.resolved_runtime_kind;
        summary.requested_reasoning_profile = stream.requested_reasoning_profile;
        summary.resolved_reasoning_profile = stream.resolved_reasoning_profile;
        summary.execution_mode = stream.model_handle.execution_mode;
        summary.model_id = stream.model_handle.model_id.clone();
        summary.artifact_id = stream.model_handle.artifact_id.clone();
        summary.execution_policy_id = Some(stream.execution_plan.execution_policy_id.clone());
        summary.masking_state = stream.execution_plan.masking_state.clone();
        summary.kv_policy_state = stream.execution_plan.kv_policy_state.clone();
        summary.expert_budget_state = stream.execution_plan.expert_budget_state.clone();
        summary.adaptation_state = stream.execution_plan.adaptation_state.clone();
        summary.guardrail_state = stream.execution_plan.guardrail_state.clone();
        summary
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_policy(available_runtime_kinds: Vec<RuntimeKind>) -> RuntimeControlPlane {
        RuntimeControlPlane::new(available_runtime_kinds, RuntimeKind::Gguf, true)
    }

    #[test]
    fn capability_handshake_resolves_runtime_capabilities_before_generation() {
        let control_plane = make_policy(vec![RuntimeKind::Gguf, RuntimeKind::Mlx]);

        let handshake = control_plane
            .handshake(RuntimeHandshakeRequest {
                requested_runtime_kind: Some(RuntimeKind::Gguf),
                execution_mode: ExecutionMode::Local,
                operation: RuntimeOperation::Generate,
                reasoning_profile: Some(ReasoningProfile::Deep),
                execution_policy_ref: None,
            })
            .expect("generation handshake");

        assert_eq!(handshake.requested_runtime_kind, Some(RuntimeKind::Gguf));
        assert_eq!(handshake.resolved_runtime_kind, RuntimeKind::Gguf);
        assert_eq!(
            handshake.requested_reasoning_profile,
            Some(ReasoningProfile::Deep)
        );
        assert_eq!(
            handshake.resolved_reasoning_profile,
            Some(ReasoningProfile::Deep)
        );
        assert_eq!(
            handshake.execution_policy_id.as_deref(),
            Some("policy.deep.local")
        );
        assert!(!handshake.used_fallback_resolution);
        assert!(handshake.capabilities.supports_generate);
        assert!(handshake.capabilities.supports_streaming_from_ssd);
        assert!(handshake.capabilities.supports_serial_io_audit);
        assert!(!handshake.capabilities.supports_speculative_decoding);
        assert!(!handshake.capabilities.supports_dynamic_sparsity);
    }

    #[test]
    fn capability_handshake_reports_explicit_mlx_fallback_when_gguf_is_unavailable() {
        let control_plane = make_policy(vec![RuntimeKind::Mlx]);

        let handshake = control_plane
            .handshake(RuntimeHandshakeRequest {
                requested_runtime_kind: Some(RuntimeKind::Gguf),
                execution_mode: ExecutionMode::Local,
                operation: RuntimeOperation::Generate,
                reasoning_profile: Some(ReasoningProfile::Standard),
                execution_policy_ref: None,
            })
            .expect("mlx fallback handshake");

        assert_eq!(handshake.requested_runtime_kind, Some(RuntimeKind::Gguf));
        assert_eq!(handshake.resolved_runtime_kind, RuntimeKind::Mlx);
        assert!(handshake.used_fallback_resolution);
        assert!(handshake.capabilities.supports_generate);
    }

    #[test]
    fn capability_handshake_exposes_mlx_embedding_support_before_execution_starts() {
        let control_plane = make_policy(vec![RuntimeKind::Mlx]);

        let handshake = control_plane
            .handshake(RuntimeHandshakeRequest {
                requested_runtime_kind: Some(RuntimeKind::Mlx),
                execution_mode: ExecutionMode::Local,
                operation: RuntimeOperation::Embed,
                reasoning_profile: None,
                execution_policy_ref: None,
            })
            .expect("mlx embed handshake should succeed");

        assert_eq!(handshake.requested_runtime_kind, Some(RuntimeKind::Mlx));
        assert_eq!(handshake.resolved_runtime_kind, RuntimeKind::Mlx);
        assert!(handshake.capabilities.supports_embed);
        assert!(!handshake.used_fallback_resolution);
    }

    #[test]
    fn generation_falls_back_to_mlx_when_gguf_is_unavailable() {
        let control_plane = make_policy(vec![RuntimeKind::Mlx]);
        let handle = control_plane
            .load_model(RuntimeModelLoadRequest {
                requested_runtime_kind: None,
                execution_mode: ExecutionMode::Local,
                model_id: "qwen".into(),
                artifact_id: Some("qwen-apex".into()),
            })
            .expect("load_model should succeed");

        assert_eq!(handle.runtime_kind, RuntimeKind::Mlx);
        assert_eq!(handle.artifact_id.as_deref(), Some("qwen-apex"));
    }

    #[test]
    fn model_handles_are_runtime_scoped() {
        let control_plane = make_policy(vec![RuntimeKind::Gguf, RuntimeKind::Mlx]);
        let handle = control_plane
            .load_model(RuntimeModelLoadRequest {
                requested_runtime_kind: Some(RuntimeKind::Mlx),
                execution_mode: ExecutionMode::Local,
                model_id: "qwen".into(),
                artifact_id: None,
            })
            .expect("mlx handle");

        let error = control_plane
            .generate(RuntimeGenerationRequest {
                request_id: "req".into(),
                requested_runtime_kind: Some(RuntimeKind::Gguf),
                execution_mode: ExecutionMode::Local,
                model_id: "qwen".into(),
                artifact_id: None,
                model_handle_id: Some(handle.handle_id),
                prompt: "hello".into(),
                system_prompt: None,
                max_output_tokens: 32,
                temperature: 0.2,
                stop_sequences: Vec::new(),
                tool_policy_ref: None,
                context_ref: None,
                reasoning_profile: Some(ReasoningProfile::Standard),
                execution_policy_ref: None,
                priority: 0,
                timeout_ms: 1_000,
                stream_options: RuntimeGenerationStreamOptions::default(),
            })
            .expect_err("cross-runtime handle reuse must fail");

        assert_eq!(error, RuntimeContractError::InvalidTransition);
    }

    #[test]
    fn stream_event_ordering_is_enforced() {
        let control_plane = make_policy(vec![RuntimeKind::Mlx]);
        let stream_handle = control_plane
            .generate(RuntimeGenerationRequest {
                request_id: "req".into(),
                requested_runtime_kind: Some(RuntimeKind::Gguf),
                execution_mode: ExecutionMode::Local,
                model_id: "qwen".into(),
                artifact_id: Some("qwen-apex".into()),
                model_handle_id: None,
                prompt: "hello".into(),
                system_prompt: None,
                max_output_tokens: 32,
                temperature: 0.2,
                stop_sequences: Vec::new(),
                tool_policy_ref: None,
                context_ref: None,
                reasoning_profile: Some(ReasoningProfile::Deep),
                execution_policy_ref: Some("policy.deep.local".into()),
                priority: 0,
                timeout_ms: 1_000,
                stream_options: RuntimeGenerationStreamOptions::default(),
            })
            .expect("stream");

        control_plane
            .emit_started(stream_handle.clone())
            .expect("started");
        control_plane
            .emit_token(stream_handle.clone(), "hello".into())
            .expect("token");
        control_plane
            .finish_completed(
                stream_handle.clone(),
                RuntimeGenerationSummary {
                    request_id: "req".into(),
                    requested_runtime_kind: Some(RuntimeKind::Gguf),
                    resolved_runtime_kind: RuntimeKind::Mlx,
                    requested_reasoning_profile: Some(ReasoningProfile::Deep),
                    resolved_reasoning_profile: ReasoningProfile::Deep,
                    execution_mode: ExecutionMode::Local,
                    model_id: "qwen".into(),
                    artifact_id: Some("qwen-apex".into()),
                    execution_policy_id: Some("policy.deep.local".into()),
                    fallback_mode: "resident".into(),
                    time_to_first_token_ms: Some(10.0),
                    total_duration_ms: 20.0,
                    tokens_per_second: Some(50.0),
                    output_token_count: 1,
                    output_character_count: 5,
                    memory_pressure_state: "normal".into(),
                    execution_phase: "decode".into(),
                    masking_state: "dense".into(),
                    kv_policy_state: "baseline".into(),
                    expert_budget_state: "default".into(),
                    adaptation_state: "disabled".into(),
                    guardrail_state: "clear".into(),
                    cancelled: false,
                    error_class: None,
                },
            )
            .expect("completed");

        let events = control_plane
            .poll_events(stream_handle.clone(), 10)
            .expect("events");
        assert_eq!(events.len(), 3);
        assert_eq!(events[0].kind, GenerationEventKind::Started);
        assert_eq!(events[1].kind, GenerationEventKind::Token);
        assert_eq!(events[2].kind, GenerationEventKind::Completed);

        let stats = control_plane
            .stats(RuntimeStatsTarget {
                model_handle_id: None,
                stream_handle: Some(stream_handle.clone()),
            })
            .expect("stream stats");
        assert_eq!(
            stats.requested_reasoning_profile,
            Some(ReasoningProfile::Deep)
        );
        assert_eq!(
            stats.resolved_reasoning_profile,
            Some(ReasoningProfile::Deep)
        );
        assert_eq!(
            stats.execution_policy_id.as_deref(),
            Some("policy.deep.local")
        );
        assert!(stats.capabilities.supports_generate);
        assert!(stats.capabilities.supports_serial_io_audit);
        assert!(!stats.capabilities.supports_adapt);

        let error = control_plane
            .emit_token(stream_handle, "late".into())
            .expect_err("terminal stream must reject more events");
        assert_eq!(error, RuntimeContractError::ContractViolation);
    }

    #[test]
    fn adaptive_reasoning_is_denied_by_default_policy() {
        let control_plane = make_policy(vec![RuntimeKind::Gguf, RuntimeKind::Mlx]);
        let error = control_plane
            .generate(RuntimeGenerationRequest {
                request_id: "req-adaptive".into(),
                requested_runtime_kind: Some(RuntimeKind::Gguf),
                execution_mode: ExecutionMode::Local,
                model_id: "qwen".into(),
                artifact_id: Some("qwen-apex".into()),
                model_handle_id: None,
                prompt: "hello".into(),
                system_prompt: None,
                max_output_tokens: 32,
                temperature: 0.2,
                stop_sequences: Vec::new(),
                tool_policy_ref: None,
                context_ref: None,
                reasoning_profile: Some(ReasoningProfile::Adaptive),
                execution_policy_ref: Some("policy.adaptive.helper".into()),
                priority: 0,
                timeout_ms: 1_000,
                stream_options: RuntimeGenerationStreamOptions::default(),
            })
            .expect_err("adaptive reasoning should be denied in phase 1");

        assert_eq!(error, RuntimeContractError::PolicyDenied);
    }

    #[test]
    fn deep_reasoning_resolves_default_policy_metadata() {
        let control_plane = make_policy(vec![RuntimeKind::Gguf, RuntimeKind::Mlx]);
        let stream_handle = control_plane
            .generate(RuntimeGenerationRequest {
                request_id: "req-deep".into(),
                requested_runtime_kind: Some(RuntimeKind::Gguf),
                execution_mode: ExecutionMode::Local,
                model_id: "qwen".into(),
                artifact_id: Some("qwen-apex".into()),
                model_handle_id: None,
                prompt: "hello".into(),
                system_prompt: None,
                max_output_tokens: 32,
                temperature: 0.2,
                stop_sequences: Vec::new(),
                tool_policy_ref: None,
                context_ref: None,
                reasoning_profile: Some(ReasoningProfile::Deep),
                execution_policy_ref: None,
                priority: 0,
                timeout_ms: 1_000,
                stream_options: RuntimeGenerationStreamOptions::default(),
            })
            .expect("deep reasoning should resolve");

        let stats = control_plane
            .stats(RuntimeStatsTarget {
                model_handle_id: None,
                stream_handle: Some(stream_handle),
            })
            .expect("stream stats");

        assert_eq!(
            stats.execution_policy_id.as_deref(),
            Some("policy.deep.local")
        );
        assert_eq!(stats.masking_state, "dense");
        assert_eq!(stats.kv_policy_state, "baseline");
        assert_eq!(stats.expert_budget_state, "deep");
        assert_eq!(stats.adaptation_state, "disabled");
        assert_eq!(stats.guardrail_state, "clear");
    }

    #[test]
    fn mismatched_execution_policy_is_denied() {
        let control_plane = make_policy(vec![RuntimeKind::Gguf, RuntimeKind::Mlx]);
        let error = control_plane
            .generate(RuntimeGenerationRequest {
                request_id: "req-mismatch".into(),
                requested_runtime_kind: Some(RuntimeKind::Gguf),
                execution_mode: ExecutionMode::Local,
                model_id: "qwen".into(),
                artifact_id: Some("qwen-apex".into()),
                model_handle_id: None,
                prompt: "hello".into(),
                system_prompt: None,
                max_output_tokens: 32,
                temperature: 0.2,
                stop_sequences: Vec::new(),
                tool_policy_ref: None,
                context_ref: None,
                reasoning_profile: Some(ReasoningProfile::Deep),
                execution_policy_ref: Some("policy.standard.local".into()),
                priority: 0,
                timeout_ms: 1_000,
                stream_options: RuntimeGenerationStreamOptions::default(),
            })
            .expect_err("mismatched policy ids must fail closed");

        assert_eq!(error, RuntimeContractError::PolicyDenied);
    }
}
