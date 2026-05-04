use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::PathBuf;
use std::sync::Mutex;

pub mod config;
pub mod cost_tracker;
pub mod provider_api;
pub mod provider_client;
pub mod routing;

pub use config::{
    AgentProviderConfig, AgentRuntimeConfig, LocalAgentPolicy, McpServerConfig, McpTransport,
    ProviderCapabilities, RuntimeProviderKind,
};
pub use provider_api::{ProviderHeader, ProviderRequestBlueprint};
pub use provider_client::ProviderClientError;
pub use routing::{RouteDecision, RoutingReason};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct AgentEvent {
    pub sequence: u64,
    pub phase: String,
    pub payload: String,
    pub timestamp: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct AgentTurnResult {
    pub session_id: String,
    pub stop_reason: String,
    pub assistant_text: String,
    pub turn_count: u32,
    pub emitted_event_count: u32,
    pub transcript_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
struct PersistedTranscriptEntry {
    session_id: String,
    timestamp: String,
    role: String,
    content: Vec<ContentBlock>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
struct ContentBlock {
    kind: String,
    text: String,
    tool_call_id: String,
    tool_name: String,
    payload_json: String,
}

impl ContentBlock {
    fn text(text: impl Into<String>) -> Self {
        Self {
            kind: "text".to_string(),
            text: text.into(),
            tool_call_id: String::new(),
            tool_name: String::new(),
            payload_json: String::new(),
        }
    }

    fn thinking(text: impl Into<String>) -> Self {
        Self {
            kind: "thinking".to_string(),
            text: text.into(),
            tool_call_id: String::new(),
            tool_name: String::new(),
            payload_json: String::new(),
        }
    }

    fn tool_use(call: &ToolCall) -> Self {
        Self {
            kind: "tool_use".to_string(),
            text: String::new(),
            tool_call_id: call.id.clone(),
            tool_name: call.name.clone(),
            payload_json: call.input_json.clone(),
        }
    }

    fn tool_result(result: &ToolResult) -> Self {
        Self {
            kind: "tool_result".to_string(),
            text: String::new(),
            tool_call_id: result.call_id.clone(),
            tool_name: result.tool_name.clone(),
            payload_json: result.result_json.clone(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
struct AgentMessage {
    role: String,
    content: Vec<ContentBlock>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
enum StopReason {
    EndTurn,
    ToolUse,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
struct ToolCall {
    id: String,
    name: String,
    input_json: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
struct ToolResult {
    call_id: String,
    tool_name: String,
    result_json: String,
}

#[derive(Debug, Clone)]
enum ProviderEvent {
    ThinkingDelta(String),
    TextDelta(String),
    ToolStart(ToolCall),
}

#[derive(Debug, Clone)]
struct ProviderTurn {
    events: Vec<ProviderEvent>,
    content_blocks: Vec<ContentBlock>,
    stop_reason: StopReason,
}

trait AgentProvider {
    fn next_turn(&self, messages: &[AgentMessage]) -> Result<ProviderTurn, String>;
}

trait ToolExecutor {
    fn execute(&self, call: &ToolCall) -> Result<ToolResult, String>;
}

pub struct AgentSession {
    session_id: String,
    transcript_path: PathBuf,
    runtime_config: AgentRuntimeConfig,
    provider_api_keys: Mutex<HashMap<RuntimeProviderKind, String>>,
    messages: Mutex<Vec<AgentMessage>>,
    events: Mutex<Vec<AgentEvent>>,
    next_sequence: Mutex<u64>,
}

impl AgentSession {
    pub fn new(session_id: String, transcript_root: String) -> Self {
        let runtime_config =
            AgentRuntimeConfig::production_defaults(if transcript_root.is_empty() {
                std::env::temp_dir().display().to_string()
            } else {
                transcript_root
            });
        Self::new_with_runtime_config(session_id, runtime_config)
    }

    fn new_with_runtime_config(session_id: String, runtime_config: AgentRuntimeConfig) -> Self {
        let root = if runtime_config.transcript_root.is_empty() {
            std::env::temp_dir()
        } else {
            PathBuf::from(&runtime_config.transcript_root)
        };
        let safe_session_id = sanitize_session_id(&session_id);
        let session_dir = root.join(&safe_session_id);
        let _ = fs::create_dir_all(&session_dir);
        let transcript_path = session_dir.join("transcript.jsonl");
        Self {
            session_id: safe_session_id,
            transcript_path,
            runtime_config,
            provider_api_keys: Mutex::new(HashMap::new()),
            messages: Mutex::new(Vec::new()),
            events: Mutex::new(Vec::new()),
            next_sequence: Mutex::new(1),
        }
    }

    pub fn run_scaffold_turn(&self, user_message: String) -> AgentTurnResult {
        let route = routing::route_objective(&user_message, &self.runtime_config);
        let provider = ScaffoldProvider::new(route);
        let executor = NoopToolExecutor;
        match run_agent_loop(self, user_message, &provider, &executor) {
            Ok(result) => result,
            Err(error) => {
                let _ = self.push_event("error", error.clone());
                let emitted_event_count = self.events.lock().unwrap().len() as u32;
                AgentTurnResult {
                    session_id: self.session_id.clone(),
                    stop_reason: "error".to_string(),
                    assistant_text: error,
                    turn_count: 0,
                    emitted_event_count,
                    transcript_path: self.transcript_path.display().to_string(),
                }
            }
        }
    }

    pub fn drain_events(&self) -> Vec<AgentEvent> {
        let mut events = self.events.lock().unwrap();
        let drained = events.clone();
        events.clear();
        drained
    }

    pub fn transcript_path(&self) -> String {
        self.transcript_path.display().to_string()
    }

    pub fn transcript_jsonl(&self) -> String {
        fs::read_to_string(&self.transcript_path).unwrap_or_default()
    }

    pub fn runtime_blueprint_json(&self) -> String {
        serde_json::to_string_pretty(&self.runtime_config).unwrap_or_else(|_| "{}".to_string())
    }

    pub fn route_objective_json(&self, objective: String) -> String {
        let route = routing::route_objective(&objective, &self.runtime_config);
        serde_json::to_string_pretty(&route).unwrap_or_else(|_| "{}".to_string())
    }

    pub fn set_provider_api_key(&self, provider: String, api_key: String) -> bool {
        let Some(provider_kind) = RuntimeProviderKind::parse(&provider) else {
            return false;
        };
        self.provider_api_keys
            .lock()
            .map(|mut api_keys| {
                api_keys.insert(provider_kind, api_key);
                true
            })
            .unwrap_or(false)
    }

    pub fn run_live_routed_turn(&self, user_message: String) -> AgentTurnResult {
        let route = routing::route_objective(&user_message, &self.runtime_config);
        self.run_live_turn(Some(route), user_message, None)
    }

    pub fn run_live_provider_turn(
        &self,
        user_message: String,
        provider: String,
    ) -> AgentTurnResult {
        let provider_kind = match RuntimeProviderKind::parse(&provider) {
            Some(provider_kind) => provider_kind,
            None => {
                let error = format!("unknown provider `{provider}`");
                let _ = self.push_event("error", error.clone());
                return AgentTurnResult {
                    session_id: self.session_id.clone(),
                    stop_reason: "error".to_string(),
                    assistant_text: error,
                    turn_count: 0,
                    emitted_event_count: self.events.lock().unwrap().len() as u32,
                    transcript_path: self.transcript_path.display().to_string(),
                };
            }
        };
        self.run_live_turn(None, user_message, Some(provider_kind))
    }

    fn push_event(
        &self,
        phase: impl Into<String>,
        payload: impl Into<String>,
    ) -> Result<(), String> {
        let mut next_sequence = self
            .next_sequence
            .lock()
            .map_err(|_| "event sequence lock poisoned".to_string())?;
        let event = AgentEvent {
            sequence: *next_sequence,
            phase: phase.into(),
            payload: payload.into(),
            timestamp: timestamp_string(),
        };
        *next_sequence += 1;
        self.events
            .lock()
            .map_err(|_| "event queue lock poisoned".to_string())?
            .push(event);
        Ok(())
    }

    fn append_message(
        &self,
        role: impl Into<String>,
        content: Vec<ContentBlock>,
    ) -> Result<(), String> {
        let role = role.into();
        let message = AgentMessage {
            role: role.clone(),
            content: content.clone(),
        };

        self.messages
            .lock()
            .map_err(|_| "message lock poisoned".to_string())?
            .push(message);

        let line = PersistedTranscriptEntry {
            session_id: self.session_id.clone(),
            timestamp: timestamp_string(),
            role,
            content,
        };
        append_jsonl_line(&self.transcript_path, &line)
    }

    fn snapshot_messages(&self) -> Result<Vec<AgentMessage>, String> {
        Ok(self
            .messages
            .lock()
            .map_err(|_| "message lock poisoned".to_string())?
            .clone())
    }

    fn run_live_turn(
        &self,
        routed_decision: Option<RouteDecision>,
        user_message: String,
        provider_override: Option<RuntimeProviderKind>,
    ) -> AgentTurnResult {
        match self.run_live_turn_inner(routed_decision, user_message, provider_override) {
            Ok(result) => result,
            Err(error) => {
                let _ = self.push_event("error", error.clone());
                let emitted_event_count = self.events.lock().unwrap().len() as u32;
                AgentTurnResult {
                    session_id: self.session_id.clone(),
                    stop_reason: "error".to_string(),
                    assistant_text: error,
                    turn_count: 0,
                    emitted_event_count,
                    transcript_path: self.transcript_path.display().to_string(),
                }
            }
        }
    }

    fn run_live_turn_inner(
        &self,
        routed_decision: Option<RouteDecision>,
        user_message: String,
        provider_override: Option<RuntimeProviderKind>,
    ) -> Result<AgentTurnResult, String> {
        let trimmed = user_message.trim().to_string();
        if trimmed.is_empty() {
            return Err("user message is empty".to_string());
        }

        self.append_message("user", vec![ContentBlock::text(trimmed.clone())])?;

        let route = routed_decision
            .unwrap_or_else(|| routing::route_objective(&trimmed, &self.runtime_config));
        let provider_kind = provider_override.unwrap_or(route.provider);
        let provider = self
            .runtime_config
            .provider(provider_kind)
            .ok_or_else(|| format!("provider `{}` is not configured", provider_kind.as_str()))?;
        let effective_route = if provider_override.is_some() && provider_kind != route.provider {
            let mut notes = route.notes.clone();
            notes.push(format!(
                "Provider override forced {} for this turn.",
                provider_kind.as_str()
            ));
            RouteDecision {
                provider: provider_kind,
                model: provider.model.clone(),
                reason: route.reason,
                hosted_tool_domains: route.hosted_tool_domains.clone(),
                remote_mcp_servers: route.remote_mcp_servers.clone(),
                allow_local_full_loop: provider_kind == RuntimeProviderKind::Local
                    && route.allow_local_full_loop,
                notes,
            }
        } else {
            route
        };

        let route_payload =
            serde_json::to_string(&effective_route).map_err(|error| error.to_string())?;
        self.push_event("route_selected", route_payload)?;

        let api_key_override = self
            .provider_api_keys
            .lock()
            .map_err(|_| "provider api key lock poisoned".to_string())?
            .get(&provider_kind)
            .cloned();

        let turn = provider_client::run_stream_turn_blocking(
            provider,
            api_key_override.as_deref(),
            &trimmed,
            None,
            2048,
            2048,
            &self.runtime_config.mcp_servers,
        )
        .map_err(|error| error.to_string())?;

        let mut emitted_event_count = 1u32;
        for event in &turn.events {
            match event {
                ProviderEvent::ThinkingDelta(text) => {
                    self.push_event("thinking_delta", text.clone())?;
                    emitted_event_count += 1;
                }
                ProviderEvent::TextDelta(text) => {
                    self.push_event("text_delta", text.clone())?;
                    emitted_event_count += 1;
                }
                ProviderEvent::ToolStart(call) => {
                    let payload = serde_json::to_string(call).map_err(|error| error.to_string())?;
                    self.push_event("tool_start", payload)?;
                    emitted_event_count += 1;
                }
            }
        }

        self.append_message("assistant", turn.content_blocks.clone())?;
        let stop_reason = match &turn.stop_reason {
            StopReason::EndTurn => "end_turn",
            StopReason::ToolUse => "tool_use",
        }
        .to_string();
        self.push_event("complete", stop_reason.clone())?;
        emitted_event_count += 1;

        let assistant_text = turn
            .content_blocks
            .iter()
            .filter(|block| block.kind == "text")
            .map(|block| block.text.as_str())
            .collect::<Vec<_>>()
            .join("");

        Ok(AgentTurnResult {
            session_id: self.session_id.clone(),
            stop_reason,
            assistant_text,
            turn_count: 1,
            emitted_event_count,
            transcript_path: self.transcript_path.display().to_string(),
        })
    }
}

fn run_agent_loop<P: AgentProvider, E: ToolExecutor>(
    session: &AgentSession,
    objective: String,
    provider: &P,
    executor: &E,
) -> Result<AgentTurnResult, String> {
    session.append_message("user", vec![ContentBlock::text(objective)])?;

    let mut turn_count = 0u32;
    let mut emitted_event_count = 0u32;

    loop {
        turn_count += 1;
        let messages = session.snapshot_messages()?;
        let turn = provider.next_turn(&messages)?;

        for event in &turn.events {
            match event {
                ProviderEvent::ThinkingDelta(text) => {
                    session.push_event("thinking_delta", text.clone())?;
                    emitted_event_count += 1;
                }
                ProviderEvent::TextDelta(text) => {
                    session.push_event("text_delta", text.clone())?;
                    emitted_event_count += 1;
                }
                ProviderEvent::ToolStart(call) => {
                    let payload = serde_json::to_string(call).map_err(|err| err.to_string())?;
                    session.push_event("tool_start", payload)?;
                    emitted_event_count += 1;
                }
            }
        }

        match turn.stop_reason {
            StopReason::EndTurn => {
                session.append_message("assistant", turn.content_blocks.clone())?;
                session.push_event("complete", "end_turn")?;
                emitted_event_count += 1;
                let assistant_text = turn
                    .content_blocks
                    .iter()
                    .filter(|block| block.kind == "text")
                    .map(|block| block.text.as_str())
                    .collect::<Vec<_>>()
                    .join("");
                return Ok(AgentTurnResult {
                    session_id: session.session_id.clone(),
                    stop_reason: "end_turn".to_string(),
                    assistant_text,
                    turn_count,
                    emitted_event_count,
                    transcript_path: session.transcript_path.display().to_string(),
                });
            }
            StopReason::ToolUse => {
                session.append_message("assistant", turn.content_blocks.clone())?;
                let tool_calls = extract_tool_calls(&turn.content_blocks);
                if tool_calls.is_empty() {
                    return Err("tool_use stop reason without tool calls".to_string());
                }

                let mut result_blocks = Vec::with_capacity(tool_calls.len());
                for call in tool_calls {
                    let result = executor.execute(&call)?;
                    let payload = serde_json::to_string(&result).map_err(|err| err.to_string())?;
                    session.push_event("tool_result", payload)?;
                    emitted_event_count += 1;
                    result_blocks.push(ContentBlock::tool_result(&result));
                }

                session.append_message("user_tool_result", result_blocks)?;
            }
        }
    }
}

fn extract_tool_calls(blocks: &[ContentBlock]) -> Vec<ToolCall> {
    blocks
        .iter()
        .filter(|block| block.kind == "tool_use")
        .map(|block| ToolCall {
            id: block.tool_call_id.clone(),
            name: block.tool_name.clone(),
            input_json: block.payload_json.clone(),
        })
        .collect()
}

fn append_jsonl_line(path: &PathBuf, entry: &PersistedTranscriptEntry) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|err| err.to_string())?;
    }

    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(path)
        .map_err(|err| err.to_string())?;
    let json = serde_json::to_string(entry).map_err(|err| err.to_string())?;
    file.write_all(json.as_bytes())
        .map_err(|err| err.to_string())?;
    file.write_all(b"\n").map_err(|err| err.to_string())?;
    Ok(())
}

fn timestamp_string() -> String {
    chrono::Utc::now().to_rfc3339()
}

fn sanitize_session_id(session_id: &str) -> String {
    let cleaned: String = session_id
        .chars()
        .map(|character| {
            if character.is_ascii_alphanumeric() || character == '-' || character == '_' {
                character
            } else {
                '_'
            }
        })
        .collect();

    if cleaned.is_empty() {
        "default".to_string()
    } else {
        cleaned
    }
}

#[derive(Default)]
struct NoopToolExecutor;

impl ToolExecutor for NoopToolExecutor {
    fn execute(&self, call: &ToolCall) -> Result<ToolResult, String> {
        Ok(ToolResult {
            call_id: call.id.clone(),
            tool_name: call.name.clone(),
            result_json: call.input_json.clone(),
        })
    }
}

struct ScaffoldProvider {
    route: RouteDecision,
}

impl ScaffoldProvider {
    fn new(route: RouteDecision) -> Self {
        Self { route }
    }
}

impl AgentProvider for ScaffoldProvider {
    fn next_turn(&self, _messages: &[AgentMessage]) -> Result<ProviderTurn, String> {
        let thinking = format!(
            "Scaffold route selected {} because the objective matched {}.",
            self.route.provider.as_str(),
            self.route.reason.as_str(),
        );
        let response = format!(
            "Runtime scaffold routed this request to {} using model {}. The real provider client and MCP-backed tool loop are the next replacement step.",
            self.route.provider.as_str(),
            self.route.model,
        );
        Ok(ProviderTurn {
            events: vec![
                ProviderEvent::ThinkingDelta(thinking.clone()),
                ProviderEvent::TextDelta(response.clone()),
            ],
            content_blocks: vec![
                ContentBlock::thinking(thinking),
                ContentBlock::text(response),
            ],
            stop_reason: StopReason::EndTurn,
        })
    }
}

// ── Phase 4: Agent Budget Ledger ────────────────────────────────────────────

#[derive(Debug, Clone, PartialEq)]
pub struct AgentBudgetLimits {
    pub max_tokens: u64,
    pub max_wall_ms: u64,
    pub max_recursion_depth: u32,
    pub max_child_agents: u32,
    pub max_review_rounds: u32,
}

impl Default for AgentBudgetLimits {
    fn default() -> Self {
        Self {
            max_tokens: 50_000,
            max_wall_ms: 120_000,
            max_recursion_depth: 3,
            max_child_agents: 5,
            max_review_rounds: 3,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BudgetDimension {
    Tokens,
    WallClock,
    RecursionDepth,
    ChildAgents,
    ReviewRounds,
}

impl BudgetDimension {
    pub fn label(self) -> &'static str {
        match self {
            Self::Tokens => "tokens",
            Self::WallClock => "wall_clock",
            Self::RecursionDepth => "recursion_depth",
            Self::ChildAgents => "child_agents",
            Self::ReviewRounds => "review_rounds",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum BudgetCheckResult {
    WithinBudget,
    Exhausted(String),
}

#[derive(Debug)]
pub struct AgentBudgetLedger {
    limits: AgentBudgetLimits,
    tokens_spent: Mutex<u64>,
    wall_ms_spent: Mutex<u64>,
    recursion_depth: Mutex<u32>,
    child_agent_count: Mutex<u32>,
    review_round_count: Mutex<u32>,
}

impl AgentBudgetLedger {
    pub fn new(limits: AgentBudgetLimits) -> Self {
        Self {
            limits,
            tokens_spent: Mutex::new(0),
            wall_ms_spent: Mutex::new(0),
            recursion_depth: Mutex::new(0),
            child_agent_count: Mutex::new(0),
            review_round_count: Mutex::new(0),
        }
    }

    pub fn record_tokens(&self, count: u64) {
        if let Ok(mut spent) = self.tokens_spent.lock() {
            *spent = spent.saturating_add(count);
        }
    }

    pub fn record_wall_ms(&self, ms: u64) {
        if let Ok(mut spent) = self.wall_ms_spent.lock() {
            *spent = spent.saturating_add(ms);
        }
    }

    pub fn record_recursion_depth(&self, depth: u32) {
        if let Ok(mut d) = self.recursion_depth.lock() {
            *d = depth;
        }
    }

    pub fn record_child_agent(&self) {
        if let Ok(mut count) = self.child_agent_count.lock() {
            *count = count.saturating_add(1);
        }
    }

    pub fn record_review_round(&self) {
        if let Ok(mut count) = self.review_round_count.lock() {
            *count = count.saturating_add(1);
        }
    }

    pub fn check(&self, dimension: BudgetDimension) -> BudgetCheckResult {
        match dimension {
            BudgetDimension::Tokens => {
                let spent = self.tokens_spent.lock().map(|v| *v).unwrap_or(0);
                if spent >= self.limits.max_tokens {
                    BudgetCheckResult::Exhausted(format!(
                        "token budget exhausted: {spent}/{}",
                        self.limits.max_tokens
                    ))
                } else {
                    BudgetCheckResult::WithinBudget
                }
            }
            BudgetDimension::WallClock => {
                let spent = self.wall_ms_spent.lock().map(|v| *v).unwrap_or(0);
                if spent >= self.limits.max_wall_ms {
                    BudgetCheckResult::Exhausted(format!(
                        "wall-clock budget exhausted: {spent}ms/{}ms",
                        self.limits.max_wall_ms
                    ))
                } else {
                    BudgetCheckResult::WithinBudget
                }
            }
            BudgetDimension::RecursionDepth => {
                let depth = self.recursion_depth.lock().map(|v| *v).unwrap_or(0);
                if depth >= self.limits.max_recursion_depth {
                    BudgetCheckResult::Exhausted(format!(
                        "recursion depth exhausted: {depth}/{}",
                        self.limits.max_recursion_depth
                    ))
                } else {
                    BudgetCheckResult::WithinBudget
                }
            }
            BudgetDimension::ChildAgents => {
                let count = self.child_agent_count.lock().map(|v| *v).unwrap_or(0);
                if count >= self.limits.max_child_agents {
                    BudgetCheckResult::Exhausted(format!(
                        "child agent limit reached: {count}/{}",
                        self.limits.max_child_agents
                    ))
                } else {
                    BudgetCheckResult::WithinBudget
                }
            }
            BudgetDimension::ReviewRounds => {
                let count = self.review_round_count.lock().map(|v| *v).unwrap_or(0);
                if count >= self.limits.max_review_rounds {
                    BudgetCheckResult::Exhausted(format!(
                        "review round limit reached: {count}/{}",
                        self.limits.max_review_rounds
                    ))
                } else {
                    BudgetCheckResult::WithinBudget
                }
            }
        }
    }

    pub fn check_all(&self) -> BudgetCheckResult {
        for dim in [
            BudgetDimension::Tokens,
            BudgetDimension::WallClock,
            BudgetDimension::RecursionDepth,
            BudgetDimension::ChildAgents,
            BudgetDimension::ReviewRounds,
        ] {
            let result = self.check(dim);
            if result != BudgetCheckResult::WithinBudget {
                return result;
            }
        }
        BudgetCheckResult::WithinBudget
    }

    pub fn snapshot(&self) -> AgentBudgetSnapshot {
        AgentBudgetSnapshot {
            tokens_spent: self.tokens_spent.lock().map(|v| *v).unwrap_or(0),
            wall_ms_spent: self.wall_ms_spent.lock().map(|v| *v).unwrap_or(0),
            recursion_depth: self.recursion_depth.lock().map(|v| *v).unwrap_or(0),
            child_agent_count: self.child_agent_count.lock().map(|v| *v).unwrap_or(0),
            review_round_count: self.review_round_count.lock().map(|v| *v).unwrap_or(0),
            max_tokens: self.limits.max_tokens,
            max_wall_ms: self.limits.max_wall_ms,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct AgentBudgetSnapshot {
    pub tokens_spent: u64,
    pub wall_ms_spent: u64,
    pub recursion_depth: u32,
    pub child_agent_count: u32,
    pub review_round_count: u32,
    pub max_tokens: u64,
    pub max_wall_ms: u64,
}

// ── Phase 4: Agent Audit Log ────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AgentAuditEntry {
    pub message_id: String,
    pub task_id: String,
    pub sender_role: String,
    pub sender_id: String,
    pub recipient_role: String,
    pub recipient_id: String,
    pub message_type: String,
    pub purpose: String,
    pub confidence: Option<f64>,
    pub token_cost: u64,
    pub wall_ms: u64,
    pub changed_result: bool,
    pub timestamp: String,
}

#[derive(Debug)]
pub struct AgentAuditLog {
    entries: Mutex<Vec<AgentAuditEntry>>,
}

impl AgentAuditLog {
    pub fn new() -> Self {
        Self {
            entries: Mutex::new(Vec::new()),
        }
    }

    pub fn record(&self, entry: AgentAuditEntry) {
        if let Ok(mut entries) = self.entries.lock() {
            entries.push(entry);
        }
    }

    pub fn entries(&self) -> Vec<AgentAuditEntry> {
        self.entries.lock().map(|e| e.clone()).unwrap_or_default()
    }

    pub fn entry_count(&self) -> usize {
        self.entries.lock().map(|e| e.len()).unwrap_or(0)
    }

    pub fn total_token_cost(&self) -> u64 {
        self.entries
            .lock()
            .map(|e| e.iter().map(|entry| entry.token_cost).sum())
            .unwrap_or(0)
    }

    pub fn entries_for_task(&self, task_id: &str) -> Vec<AgentAuditEntry> {
        self.entries
            .lock()
            .map(|e| {
                e.iter()
                    .filter(|entry| entry.task_id == task_id)
                    .cloned()
                    .collect()
            })
            .unwrap_or_default()
    }

    pub fn persist_jsonl(&self, path: &std::path::Path) -> Result<(), std::io::Error> {
        let entries = self.entries();
        let file = OpenOptions::new().create(true).append(true).open(path)?;
        let mut writer = std::io::BufWriter::new(file);
        for entry in &entries {
            if let Ok(json) = serde_json::to_string(entry) {
                writeln!(writer, "{}", json)?;
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::{HashMap, VecDeque};
    use std::fs;
    use std::io::{Read, Write};
    use std::net::TcpListener;
    use std::thread;
    use std::time::{SystemTime, UNIX_EPOCH};

    struct ScriptedProvider {
        turns: Mutex<VecDeque<ProviderTurn>>,
    }

    impl ScriptedProvider {
        fn new(turns: Vec<ProviderTurn>) -> Self {
            Self {
                turns: Mutex::new(turns.into()),
            }
        }
    }

    impl AgentProvider for ScriptedProvider {
        fn next_turn(&self, _messages: &[AgentMessage]) -> Result<ProviderTurn, String> {
            self.turns
                .lock()
                .unwrap()
                .pop_front()
                .ok_or_else(|| "provider exhausted".to_string())
        }
    }

    struct ScriptedToolExecutor {
        results: HashMap<String, ToolResult>,
    }

    impl ScriptedToolExecutor {
        fn new(results: HashMap<String, ToolResult>) -> Self {
            Self { results }
        }
    }

    impl ToolExecutor for ScriptedToolExecutor {
        fn execute(&self, call: &ToolCall) -> Result<ToolResult, String> {
            self.results
                .get(&call.id)
                .cloned()
                .ok_or_else(|| format!("missing tool result for {}", call.id))
        }
    }

    fn temp_root(name: &str) -> PathBuf {
        let suffix = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir().join(format!("epistemos-agent-runtime-{name}-{suffix}"))
    }

    #[test]
    fn preserves_assistant_thinking_blocks_across_tool_use_turns() {
        let root = temp_root("thinking-blocks");
        let session = AgentSession::new("thinking-blocks".to_string(), root.display().to_string());
        let search_call = ToolCall {
            id: "tool-1".to_string(),
            name: "vault_search".to_string(),
            input_json: r#"{"query":"openclaw"}"#.to_string(),
        };
        let provider = ScriptedProvider::new(vec![
            ProviderTurn {
                events: vec![
                    ProviderEvent::ThinkingDelta("Need vault context first".to_string()),
                    ProviderEvent::ToolStart(search_call.clone()),
                ],
                content_blocks: vec![
                    ContentBlock {
                        kind: "thinking".to_string(),
                        text: "Need vault context first".to_string(),
                        tool_call_id: String::new(),
                        tool_name: String::new(),
                        payload_json: String::new(),
                    },
                    ContentBlock::tool_use(&search_call),
                ],
                stop_reason: StopReason::ToolUse,
            },
            ProviderTurn {
                events: vec![ProviderEvent::TextDelta(
                    "Found the right vault context and can answer now.".to_string(),
                )],
                content_blocks: vec![ContentBlock {
                    kind: "text".to_string(),
                    text: "Found the right vault context and can answer now.".to_string(),
                    tool_call_id: String::new(),
                    tool_name: String::new(),
                    payload_json: String::new(),
                }],
                stop_reason: StopReason::EndTurn,
            },
        ]);
        let executor = ScriptedToolExecutor::new(HashMap::from([(
            "tool-1".to_string(),
            ToolResult {
                call_id: "tool-1".to_string(),
                tool_name: "vault_search".to_string(),
                result_json: r#"{"matches":[{"title":"OpenClaw patterns"}]}"#.to_string(),
            },
        )]));

        let result = run_agent_loop(
            &session,
            "How should Omega evolve?".to_string(),
            &provider,
            &executor,
        )
        .expect("agent loop should succeed");

        assert_eq!(result.stop_reason, "end_turn");

        let transcript = session.transcript_jsonl();
        assert!(transcript.contains("\"role\":\"assistant\""));
        assert!(transcript.contains("\"kind\":\"thinking\""));
        assert!(transcript.contains("\"kind\":\"tool_use\""));
        assert!(transcript.contains("\"role\":\"user_tool_result\""));

        let events = session.drain_events();
        let phases: Vec<&str> = events.iter().map(|event| event.phase.as_str()).collect();
        assert_eq!(
            phases,
            vec![
                "thinking_delta",
                "tool_start",
                "tool_result",
                "text_delta",
                "complete"
            ]
        );
    }

    #[test]
    fn scaffold_turn_persists_jsonl_transcript() {
        let root = temp_root("scaffold");
        let session = AgentSession::new("scaffold".to_string(), root.display().to_string());

        let result = session.run_scaffold_turn("Bridge Omega to a living loop".to_string());

        assert_eq!(result.stop_reason, "end_turn");
        assert!(fs::metadata(session.transcript_path()).is_ok());

        let transcript = session.transcript_jsonl();
        let line_count = transcript.lines().count();
        assert_eq!(line_count, 2);
        assert!(transcript.contains("Bridge Omega to a living loop"));
        assert!(transcript.contains("Runtime scaffold routed this request"));

        let events = session.drain_events();
        assert_eq!(
            events.last().map(|event| event.phase.as_str()),
            Some("complete")
        );
    }

    #[test]
    fn runtime_blueprint_exposes_real_cloud_and_mcp_defaults() {
        let root = temp_root("runtime-blueprint");
        let session =
            AgentSession::new("runtime-blueprint".to_string(), root.display().to_string());

        let blueprint = session.runtime_blueprint_json();

        assert!(blueprint.contains("https://api.anthropic.com/v1/messages"));
        assert!(blueprint.contains("https://api.perplexity.ai/v1/agent"));
        assert!(blueprint.contains("\"name\": \"vault\""));
        assert!(blueprint.contains("\"name\": \"system\""));
    }

    #[test]
    fn route_objective_exposes_local_agent_policy_decision() {
        let root = temp_root("route-objective");
        let session = AgentSession::new("route-objective".to_string(), root.display().to_string());

        let route = session.route_objective_json("Keep this private and local only".to_string());

        assert!(route.contains("\"provider\": \"local\""));
        assert!(route.contains("\"reason\": \"privacy\""));
        assert!(route.contains("\"allow_local_full_loop\": true"));
    }

    #[test]
    fn live_provider_turn_persists_transcript_and_runtime_events() {
        let root = temp_root("live-provider-turn");
        let response = concat!(
            "event: response.output_text.delta\n",
            "data: {\"type\":\"response.output_text.delta\",\"delta\":\"Live\"}\n\n",
            "event: response.output_text.delta\n",
            "data: {\"type\":\"response.output_text.delta\",\"delta\":\" runtime\"}\n\n",
            "data: [DONE]\n\n"
        )
        .to_string();
        let url = spawn_mock_server(response);

        let mut runtime_config =
            AgentRuntimeConfig::production_defaults(root.display().to_string());
        let provider = runtime_config
            .providers
            .iter_mut()
            .find(|provider| provider.kind == RuntimeProviderKind::OpenAI)
            .expect("openai provider should exist");
        provider.base_url = url;
        provider.api_key_env = "EP_TEST_OPENAI_KEY".to_string();

        let session =
            AgentSession::new_with_runtime_config("live-provider-turn".to_string(), runtime_config);
        assert!(session.set_provider_api_key("openai".to_string(), "test-key".to_string()));

        let result = session.run_live_provider_turn("Say hello".to_string(), "openai".to_string());

        assert_eq!(result.stop_reason, "end_turn");
        assert_eq!(result.assistant_text, "Live runtime");
        let transcript = session.transcript_jsonl();
        assert!(transcript.contains("Say hello"));
        assert!(transcript.contains("\"text\":\"Live\""));
        assert!(transcript.contains("\"text\":\" runtime\""));

        let events = session.drain_events();
        let phases: Vec<&str> = events.iter().map(|event| event.phase.as_str()).collect();
        assert_eq!(
            phases,
            vec!["route_selected", "text_delta", "text_delta", "complete"]
        );
    }

    fn spawn_mock_server(response_body: String) -> String {
        let listener = TcpListener::bind("127.0.0.1:0").expect("listener should bind");
        let address = listener.local_addr().expect("listener should have address");

        thread::spawn(move || {
            let (mut stream, _) = listener
                .accept()
                .expect("mock server should accept request");
            let mut buffer = [0_u8; 8192];
            let _ = stream.read(&mut buffer).expect("request should read");

            let response = format!(
                "HTTP/1.1 200 OK\r\ncontent-type: text/event-stream\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{}",
                response_body.len(),
                response_body
            );
            stream
                .write_all(response.as_bytes())
                .expect("response should write");
        });

        format!("http://{}", address)
    }

    // ── Phase 4: Budget Ledger Tests ────────────────────────────────────

    #[test]
    fn budget_ledger_tracks_token_spend() {
        let ledger = AgentBudgetLedger::new(AgentBudgetLimits {
            max_tokens: 100,
            ..Default::default()
        });
        ledger.record_tokens(50);
        assert_eq!(
            ledger.check(BudgetDimension::Tokens),
            BudgetCheckResult::WithinBudget
        );
        ledger.record_tokens(60);
        assert!(matches!(
            ledger.check(BudgetDimension::Tokens),
            BudgetCheckResult::Exhausted(_)
        ));
    }

    #[test]
    fn budget_ledger_tracks_wall_clock() {
        let ledger = AgentBudgetLedger::new(AgentBudgetLimits {
            max_wall_ms: 1000,
            ..Default::default()
        });
        ledger.record_wall_ms(500);
        assert_eq!(
            ledger.check(BudgetDimension::WallClock),
            BudgetCheckResult::WithinBudget
        );
        ledger.record_wall_ms(600);
        assert!(matches!(
            ledger.check(BudgetDimension::WallClock),
            BudgetCheckResult::Exhausted(_)
        ));
    }

    #[test]
    fn budget_ledger_enforces_recursion_depth() {
        let ledger = AgentBudgetLedger::new(AgentBudgetLimits {
            max_recursion_depth: 2,
            ..Default::default()
        });
        ledger.record_recursion_depth(1);
        assert_eq!(
            ledger.check(BudgetDimension::RecursionDepth),
            BudgetCheckResult::WithinBudget
        );
        ledger.record_recursion_depth(3);
        assert!(matches!(
            ledger.check(BudgetDimension::RecursionDepth),
            BudgetCheckResult::Exhausted(_)
        ));
    }

    #[test]
    fn budget_ledger_enforces_child_agent_limit() {
        let ledger = AgentBudgetLedger::new(AgentBudgetLimits {
            max_child_agents: 2,
            ..Default::default()
        });
        ledger.record_child_agent();
        ledger.record_child_agent();
        assert!(matches!(
            ledger.check(BudgetDimension::ChildAgents),
            BudgetCheckResult::Exhausted(_)
        ));
    }

    #[test]
    fn budget_ledger_check_all_returns_first_exhaustion() {
        let ledger = AgentBudgetLedger::new(AgentBudgetLimits {
            max_tokens: 10,
            max_wall_ms: 100_000,
            ..Default::default()
        });
        ledger.record_tokens(20);
        let result = ledger.check_all();
        assert!(matches!(result, BudgetCheckResult::Exhausted(_)));
    }

    #[test]
    fn budget_ledger_snapshot_reflects_state() {
        let ledger = AgentBudgetLedger::new(AgentBudgetLimits::default());
        ledger.record_tokens(42);
        ledger.record_wall_ms(100);
        let snap = ledger.snapshot();
        assert_eq!(snap.tokens_spent, 42);
        assert_eq!(snap.wall_ms_spent, 100);
    }

    // ── Phase 4: Audit Log Tests ────────────────────────────────────────

    #[test]
    fn audit_log_records_entries() {
        let log = AgentAuditLog::new();
        log.record(AgentAuditEntry {
            message_id: "msg-1".into(),
            task_id: "task-1".into(),
            sender_role: "overseer".into(),
            sender_id: "os-1".into(),
            recipient_role: "main_agent".into(),
            recipient_id: "agent-1".into(),
            message_type: "instruction".into(),
            purpose: "plan next step".into(),
            confidence: Some(0.9),
            token_cost: 100,
            wall_ms: 50,
            changed_result: true,
            timestamp: "2026-04-13T12:00:00Z".into(),
        });
        assert_eq!(log.entry_count(), 1);
        assert_eq!(log.total_token_cost(), 100);
    }

    #[test]
    fn audit_log_filters_by_task() {
        let log = AgentAuditLog::new();
        for i in 0..3 {
            log.record(AgentAuditEntry {
                message_id: format!("msg-{i}"),
                task_id: if i < 2 {
                    "task-a".into()
                } else {
                    "task-b".into()
                },
                sender_role: "overseer".into(),
                sender_id: "os".into(),
                recipient_role: "main_agent".into(),
                recipient_id: "ag".into(),
                message_type: "instruction".into(),
                purpose: "test".into(),
                confidence: None,
                token_cost: 10,
                wall_ms: 5,
                changed_result: false,
                timestamp: "2026-04-13T12:00:00Z".into(),
            });
        }
        assert_eq!(log.entries_for_task("task-a").len(), 2);
        assert_eq!(log.entries_for_task("task-b").len(), 1);
    }

    #[test]
    fn audit_log_persists_to_jsonl() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("audit.jsonl");
        let log = AgentAuditLog::new();
        log.record(AgentAuditEntry {
            message_id: "msg-persist".into(),
            task_id: "task-persist".into(),
            sender_role: "overseer".into(),
            sender_id: "os".into(),
            recipient_role: "main_agent".into(),
            recipient_id: "ag".into(),
            message_type: "instruction".into(),
            purpose: "persist test".into(),
            confidence: Some(0.8),
            token_cost: 50,
            wall_ms: 25,
            changed_result: true,
            timestamp: "2026-04-13T12:00:00Z".into(),
        });
        log.persist_jsonl(&path).expect("persist should succeed");
        let content = fs::read_to_string(&path).expect("read file");
        assert!(content.contains("msg-persist"));
        assert!(content.contains("task-persist"));
    }
}
