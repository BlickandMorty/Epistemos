// Layer 3: Agent Orchestration (Rust)
// Orchestrator/Planner with TaskGraph, specialist agent dispatch,
// ConfirmationGate, and ResearchPauseHandler.
// Per Anti-Drift Anchor 1: orchestration MUST be in Rust.

use serde::{Deserialize, Serialize};

// ── Risk Levels ──────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum RiskLevel {
    Low,
    Medium,
    High,
    Critical,
}

impl RiskLevel {
    pub fn from_str(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "low" => RiskLevel::Low,
            "medium" => RiskLevel::Medium,
            "high" => RiskLevel::High,
            "critical" => RiskLevel::Critical,
            _ => RiskLevel::Low,
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            RiskLevel::Low => "low",
            RiskLevel::Medium => "medium",
            RiskLevel::High => "high",
            RiskLevel::Critical => "critical",
        }
    }
}

// ── Task Step ────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskStep {
    pub id: String,
    pub description: String,
    pub assigned_agent: String,
    pub tool_name: String,
    pub arguments_json: String,
    pub depends_on: Vec<String>,
    pub risk_level: RiskLevel,
    pub status: StepStatus,
    pub result_json: Option<String>,
    pub error: Option<String>,
    pub duration_ms: u64,
    pub retry_count: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum StepStatus {
    Pending,
    AwaitingConfirmation,
    Executing,
    Completed,
    Failed,
    Skipped,
}

// ── Task Graph ───────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskGraph {
    pub task_description: String,
    pub steps: Vec<TaskStep>,
    pub status: GraphStatus,
    pub planning_method: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum GraphStatus {
    Idle,
    Planning,
    AwaitingConfirmation,
    Executing,
    Completed,
    Failed,
    Paused,
}

impl TaskGraph {
    pub fn new(task_description: &str) -> Self {
        TaskGraph {
            task_description: task_description.to_string(),
            steps: Vec::new(),
            status: GraphStatus::Idle,
            planning_method: String::new(),
        }
    }

    pub fn add_step(&mut self, step: TaskStep) {
        self.steps.push(step);
    }

    /// Get indices of steps that are ready (all deps satisfied, not yet executed).
    pub fn ready_step_indices(&self) -> Vec<usize> {
        let completed_ids: std::collections::HashSet<&str> = self.steps.iter()
            .filter(|s| s.status == StepStatus::Completed || s.status == StepStatus::Skipped)
            .map(|s| s.id.as_str())
            .collect();

        self.steps.iter().enumerate()
            .filter(|(_, s)| s.status == StepStatus::Pending)
            .filter(|(_, s)| s.depends_on.iter().all(|dep| completed_ids.contains(dep.as_str())))
            .map(|(i, _)| i)
            .collect()
    }

    pub fn is_complete(&self) -> bool {
        !self.steps.is_empty() && self.steps.iter().all(|s| {
            s.status == StepStatus::Completed || s.status == StepStatus::Skipped || s.status == StepStatus::Failed
        })
    }

    pub fn has_failed(&self) -> bool {
        self.steps.iter().any(|s| s.status == StepStatus::Failed)
    }

    pub fn mark_step_completed(&mut self, index: usize, result_json: &str, duration_ms: u64) {
        if let Some(step) = self.steps.get_mut(index) {
            step.status = StepStatus::Completed;
            step.result_json = Some(result_json.to_string());
            step.duration_ms = duration_ms;
        }
    }

    pub fn mark_step_failed(&mut self, index: usize, error: &str, duration_ms: u64) {
        if let Some(step) = self.steps.get_mut(index) {
            step.status = StepStatus::Failed;
            step.error = Some(error.to_string());
            step.duration_ms = duration_ms;
        }
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self).unwrap_or_default()
    }
}

// ── Retry Logic ──────────────────────────────────────────────────────────────

/// Max retries per tool call (per Anchor 6: max 3 retries).
pub const MAX_RETRIES: u32 = 3;

/// Base delay for exponential backoff (0.2s per spec).
pub const BASE_DELAY_MS: u64 = 200;

/// Check if a step should be retried.
pub fn should_retry(step: &TaskStep) -> bool {
    step.retry_count < MAX_RETRIES && is_retriable_error(step.error.as_deref())
}

/// Calculate backoff delay in milliseconds for the given attempt.
pub fn backoff_delay_ms(attempt: u32) -> u64 {
    BASE_DELAY_MS * (1u64 << attempt.min(5)) // Cap at ~6.4s
}

/// Determine if an error is retriable (transient failures only).
fn is_retriable_error(error: Option<&str>) -> bool {
    match error {
        None => false,
        Some(e) => {
            let lower = e.to_lowercase();
            lower.contains("timeout") || lower.contains("connection")
                || lower.contains("temporary") || lower.contains("busy")
                || lower.contains("try again")
        }
    }
}

/// Confidence-based execution decision (per Anchor 6).
pub fn confidence_decision(confidence: f64) -> ConfidenceAction {
    if confidence > 0.9 {
        ConfidenceAction::AutoExecute
    } else if confidence > 0.8 {
        ConfidenceAction::LogAndExecute
    } else if confidence > 0.5 {
        ConfidenceAction::EscalateToUser
    } else {
        ConfidenceAction::Refuse
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ConfidenceAction {
    AutoExecute,
    LogAndExecute,
    EscalateToUser,
    Refuse,
}

// ── Confirmation Gate ────────────────────────────────────────────────────────

/// Risk-based confirmation. Returns whether auto-execute is allowed.
pub fn evaluate_confirmation(risk: &RiskLevel) -> ConfirmationDecision {
    match risk {
        RiskLevel::Low => ConfirmationDecision::AutoExecute,
        RiskLevel::Medium => ConfirmationDecision::ExecuteWithLogging,
        RiskLevel::High => ConfirmationDecision::RequirePreview,
        RiskLevel::Critical => ConfirmationDecision::RequireExplicitConfirm,
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ConfirmationDecision {
    AutoExecute,
    ExecuteWithLogging,
    RequirePreview,
    RequireExplicitConfirm,
}

// ── Heuristic Planner ────────────────────────────────────────────────────────

/// Generate a plan from keywords when no LLM is available.
/// This runs entirely in Rust — no FFI calls needed.
pub fn heuristic_plan(task: &str) -> TaskGraph {
    let mut graph = TaskGraph::new(task);
    graph.planning_method = "heuristic".to_string();
    let lower = task.to_lowercase();

    let step_id = uuid::Uuid::new_v4().to_string();

    // Writing / Summarization
    let write_kw = ["write", "summarize", "summary", "draft", "compose", "rewrite",
                     "outline", "essay", "paragraph", "explain", "describe"];
    if write_kw.iter().any(|k| lower.contains(k)) {
        graph.add_step(TaskStep {
            id: step_id,
            description: format!("Write/summarize: {task}"),
            assigned_agent: "notes".to_string(),
            tool_name: "create_note".to_string(),
            arguments_json: format!("{{\"title\":\"{}\",\"body\":\"\"}}", escape_json(task)),
            depends_on: vec![],
            risk_level: RiskLevel::Low,
            status: StepStatus::Pending,
            result_json: None, error: None, duration_ms: 0, retry_count: 0,
        });
        return graph;
    }

    // Web browsing
    if lower.contains("open") && (lower.contains("safari") || lower.contains("http")
        || lower.contains("url") || lower.contains("website") || lower.contains(".com")) {
        graph.add_step(TaskStep {
            id: step_id,
            description: "Open URL in Safari".to_string(),
            assigned_agent: "safari".to_string(),
            tool_name: "open_url".to_string(),
            arguments_json: "{\"url\":\"https://www.apple.com\"}".to_string(),
            depends_on: vec![],
            risk_level: RiskLevel::Low,
            status: StepStatus::Pending,
            result_json: None, error: None, duration_ms: 0, retry_count: 0,
        });
        return graph;
    }

    // Web search
    let search_kw = ["search", "google", "look up", "find info", "research"];
    if search_kw.iter().any(|k| lower.contains(k)) {
        let query = task.replace("search for ", "").replace("search the web for ", "")
            .replace("google ", "").replace("look up ", "");
        graph.add_step(TaskStep {
            id: step_id,
            description: "Search the web".to_string(),
            assigned_agent: "safari".to_string(),
            tool_name: "search_web".to_string(),
            arguments_json: format!("{{\"query\":\"{}\"}}", escape_json(&query)),
            depends_on: vec![],
            risk_level: RiskLevel::Low,
            status: StepStatus::Pending,
            result_json: None, error: None, duration_ms: 0, retry_count: 0,
        });
        return graph;
    }

    // File listing
    if lower.contains("list") && (lower.contains("file") || lower.contains("folder")) {
        graph.add_step(TaskStep {
            id: step_id,
            description: "List files".to_string(),
            assigned_agent: "file".to_string(),
            tool_name: "list_files".to_string(),
            arguments_json: "{\"path\":\".\"}".to_string(),
            depends_on: vec![],
            risk_level: RiskLevel::Low,
            status: StepStatus::Pending,
            result_json: None, error: None, duration_ms: 0, retry_count: 0,
        });
        return graph;
    }

    // Note creation
    if lower.contains("note") && (lower.contains("create") || lower.contains("new")) {
        graph.add_step(TaskStep {
            id: step_id,
            description: "Create a new note".to_string(),
            assigned_agent: "notes".to_string(),
            tool_name: "create_note".to_string(),
            arguments_json: "{\"title\":\"New Note\",\"body\":\"\"}".to_string(),
            depends_on: vec![],
            risk_level: RiskLevel::Low,
            status: StepStatus::Pending,
            result_json: None, error: None, duration_ms: 0, retry_count: 0,
        });
        return graph;
    }

    // Destructive operations
    if lower.contains("delete") || lower.contains("remove") || lower.contains("trash") {
        graph.add_step(TaskStep {
            id: step_id,
            description: task.to_string(),
            assigned_agent: "file".to_string(),
            tool_name: "delete_file".to_string(),
            arguments_json: "{}".to_string(),
            depends_on: vec![],
            risk_level: RiskLevel::High,
            status: StepStatus::Pending,
            result_json: None, error: None, duration_ms: 0, retry_count: 0,
        });
        return graph;
    }

    // Shell commands
    if lower.starts_with("run ") || lower.starts_with("execute ") || lower.starts_with("ls")
        || lower.starts_with("pwd") || lower.starts_with("echo") {
        let cmd = task.replace("run ", "").replace("execute ", "");
        graph.add_step(TaskStep {
            id: step_id,
            description: format!("Run: {cmd}"),
            assigned_agent: "terminal".to_string(),
            tool_name: "run_command".to_string(),
            arguments_json: format!("{{\"command\":\"{}\"}}", escape_json(&cmd)),
            depends_on: vec![],
            risk_level: RiskLevel::Medium,
            status: StepStatus::Pending,
            result_json: None, error: None, duration_ms: 0, retry_count: 0,
        });
        return graph;
    }

    // Default: acknowledge with notes agent
    graph.add_step(TaskStep {
        id: step_id,
        description: task.to_string(),
        assigned_agent: "notes".to_string(),
        tool_name: "create_note".to_string(),
        arguments_json: format!("{{\"title\":\"{}\",\"body\":\"Load a local AI model in Settings > Inference for intelligent planning.\"}}", escape_json(task)),
        depends_on: vec![],
        risk_level: RiskLevel::Low,
        status: StepStatus::Pending,
        result_json: None, error: None, duration_ms: 0, retry_count: 0,
    });
    graph
}

fn escape_json(s: &str) -> String {
    s.replace('\\', "\\\\").replace('"', "\\\"").replace('\n', "\\n")
}

// ── Agent Protocol ───────────────────────────────────────────────────────────

/// Agent definition stored in the Rust orchestrator.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentDefinition {
    pub name: String,
    pub description: String,
    pub tool_names: Vec<String>,
}

/// Validate that a step's tool is within its agent's allowed toolset.
pub fn validate_agent_toolset(agents: &[AgentDefinition], step: &TaskStep) -> Result<(), String> {
    let agent = agents.iter().find(|a| a.name == step.assigned_agent)
        .ok_or_else(|| format!("Agent '{}' not found", step.assigned_agent))?;

    if !agent.tool_names.contains(&step.tool_name) {
        return Err(format!(
            "Agent '{}' is not allowed to use tool '{}'. Allowed: {:?}",
            step.assigned_agent, step.tool_name, agent.tool_names
        ));
    }

    Ok(())
}

/// The 6 specialist agents per the master prompt spec + Hybrid Action Space.
pub fn default_agents() -> Vec<AgentDefinition> {
    vec![
        AgentDefinition {
            name: "safari".to_string(),
            description: "Web browsing via AppleScript + AX tree".to_string(),
            tool_names: vec!["open_url", "get_page_url", "get_page_title", "search_web"]
                .into_iter().map(String::from).collect(),
        },
        AgentDefinition {
            name: "file".to_string(),
            description: "File system operations scoped to vault".to_string(),
            tool_names: vec!["read_file", "write_file", "list_files", "move_file", "delete_file"]
                .into_iter().map(String::from).collect(),
        },
        AgentDefinition {
            name: "notes".to_string(),
            description: "Epistemos note operations".to_string(),
            tool_names: vec!["create_note", "edit_note", "search_notes", "list_notes"]
                .into_iter().map(String::from).collect(),
        },
        AgentDefinition {
            name: "terminal".to_string(),
            description: "Shell command execution (ephemeral or persistent PTY)".to_string(),
            tool_names: vec!["run_command", "run_persistent"]
                .into_iter().map(String::from).collect(),
        },
        AgentDefinition {
            name: "automation".to_string(),
            description: "Generic macOS automation via AX tree + input simulation".to_string(),
            tool_names: vec!["get_ui_tree", "click_element", "type_text", "press_key", "run_shortcut"]
                .into_iter().map(String::from).collect(),
        },
        AgentDefinition {
            name: "computer".to_string(),
            description: "Ghost OS-style macOS computer use via AXorcist accessibility and input simulation".to_string(),
            tool_names: vec!["see", "click", "type", "scroll", "keys", "screenshot"]
                .into_iter().map(String::from).collect(),
        },
    ]
}

// ── Tests ────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_heuristic_write_routes_to_notes() {
        let graph = heuristic_plan("write me a summary of my essay");
        assert_eq!(graph.steps.len(), 1);
        assert_eq!(graph.steps[0].assigned_agent, "notes");
        assert_eq!(graph.steps[0].tool_name, "create_note");
    }

    #[test]
    fn test_heuristic_search_routes_to_safari() {
        let graph = heuristic_plan("search the web for MLX benchmarks");
        assert_eq!(graph.steps.len(), 1);
        assert_eq!(graph.steps[0].assigned_agent, "safari");
        assert_eq!(graph.steps[0].tool_name, "search_web");
    }

    #[test]
    fn test_heuristic_open_routes_to_safari() {
        let graph = heuristic_plan("open Safari and go to apple.com");
        assert_eq!(graph.steps.len(), 1);
        assert_eq!(graph.steps[0].assigned_agent, "safari");
        assert_eq!(graph.steps[0].tool_name, "open_url");
    }

    #[test]
    fn test_heuristic_list_files() {
        let graph = heuristic_plan("list files in my vault");
        assert_eq!(graph.steps[0].assigned_agent, "file");
        assert_eq!(graph.steps[0].tool_name, "list_files");
    }

    #[test]
    fn test_heuristic_delete_is_high_risk() {
        let graph = heuristic_plan("delete old files");
        assert_eq!(graph.steps[0].risk_level, RiskLevel::High);
    }

    #[test]
    fn test_heuristic_shell_command() {
        let graph = heuristic_plan("run ls -la");
        assert_eq!(graph.steps[0].assigned_agent, "terminal");
        assert_eq!(graph.steps[0].tool_name, "run_command");
    }

    #[test]
    fn test_heuristic_default_is_notes() {
        let graph = heuristic_plan("something random and unrecognized");
        assert_eq!(graph.steps[0].assigned_agent, "notes");
    }

    #[test]
    fn test_task_graph_ready_steps() {
        let mut graph = TaskGraph::new("test");
        let id1 = "step-1".to_string();
        let id2 = "step-2".to_string();
        graph.add_step(TaskStep {
            id: id1.clone(), description: "A".to_string(),
            assigned_agent: "file".to_string(), tool_name: "list_files".to_string(),
            arguments_json: "{}".to_string(), depends_on: vec![],
            risk_level: RiskLevel::Low, status: StepStatus::Pending,
            result_json: None, error: None, duration_ms: 0, retry_count: 0,
        });
        graph.add_step(TaskStep {
            id: id2.clone(), description: "B".to_string(),
            assigned_agent: "terminal".to_string(), tool_name: "run_command".to_string(),
            arguments_json: "{}".to_string(), depends_on: vec![id1.clone()],
            risk_level: RiskLevel::Low, status: StepStatus::Pending,
            result_json: None, error: None, duration_ms: 0, retry_count: 0,
        });

        // Only step 1 is ready (step 2 depends on it)
        assert_eq!(graph.ready_step_indices(), vec![0]);

        // Complete step 1 → step 2 becomes ready
        graph.mark_step_completed(0, "{}", 10);
        assert_eq!(graph.ready_step_indices(), vec![1]);
    }

    #[test]
    fn test_confirmation_gate() {
        assert_eq!(evaluate_confirmation(&RiskLevel::Low), ConfirmationDecision::AutoExecute);
        assert_eq!(evaluate_confirmation(&RiskLevel::Medium), ConfirmationDecision::ExecuteWithLogging);
        assert_eq!(evaluate_confirmation(&RiskLevel::High), ConfirmationDecision::RequirePreview);
        assert_eq!(evaluate_confirmation(&RiskLevel::Critical), ConfirmationDecision::RequireExplicitConfirm);
    }

    #[test]
    fn test_agent_toolset_validation() {
        let agents = default_agents();
        let valid_step = TaskStep {
            id: "s1".to_string(), description: "".to_string(),
            assigned_agent: "safari".to_string(), tool_name: "open_url".to_string(),
            arguments_json: "{}".to_string(), depends_on: vec![],
            risk_level: RiskLevel::Low, status: StepStatus::Pending,
            result_json: None, error: None, duration_ms: 0, retry_count: 0,
        };
        assert!(validate_agent_toolset(&agents, &valid_step).is_ok());

        let invalid_step = TaskStep {
            id: "s2".to_string(), description: "".to_string(),
            assigned_agent: "safari".to_string(), tool_name: "delete_file".to_string(),
            arguments_json: "{}".to_string(), depends_on: vec![],
            risk_level: RiskLevel::Low, status: StepStatus::Pending,
            result_json: None, error: None, duration_ms: 0, retry_count: 0,
        };
        assert!(validate_agent_toolset(&agents, &invalid_step).is_err());
    }

    #[test]
    fn test_graph_completion() {
        let mut graph = TaskGraph::new("test");
        graph.add_step(TaskStep {
            id: "s1".to_string(), description: "".to_string(),
            assigned_agent: "file".to_string(), tool_name: "list_files".to_string(),
            arguments_json: "{}".to_string(), depends_on: vec![],
            risk_level: RiskLevel::Low, status: StepStatus::Pending,
            result_json: None, error: None, duration_ms: 0, retry_count: 0,
        });
        assert!(!graph.is_complete());
        graph.mark_step_completed(0, "{}", 5);
        assert!(graph.is_complete());
        assert!(!graph.has_failed());
    }

    #[test]
    fn test_graph_failure() {
        let mut graph = TaskGraph::new("test");
        graph.add_step(TaskStep {
            id: "s1".to_string(), description: "".to_string(),
            assigned_agent: "file".to_string(), tool_name: "delete_file".to_string(),
            arguments_json: "{}".to_string(), depends_on: vec![],
            risk_level: RiskLevel::High, status: StepStatus::Pending,
            result_json: None, error: None, duration_ms: 0, retry_count: 0,
        });
        graph.mark_step_failed(0, "Permission denied", 1);
        assert!(graph.has_failed());
    }

    #[test]
    fn test_default_agents() {
        let agents = default_agents();
        assert_eq!(agents.len(), 6);
        assert!(agents.iter().any(|a| a.name == "safari"));
        assert!(agents.iter().any(|a| a.name == "file"));
        assert!(agents.iter().any(|a| a.name == "notes"));
        assert!(agents.iter().any(|a| a.name == "terminal"));
        assert!(agents.iter().any(|a| a.name == "automation"));
        assert!(agents.iter().any(|a| a.name == "computer"));

        // Verify terminal has both ephemeral and persistent tools
        let terminal = agents.iter().find(|a| a.name == "terminal").unwrap();
        assert!(terminal.tool_names.contains(&"run_command".to_string()));
        assert!(terminal.tool_names.contains(&"run_persistent".to_string()));

        // Verify computer agent has all 6 tools
        let computer = agents.iter().find(|a| a.name == "computer").unwrap();
        assert_eq!(computer.tool_names.len(), 6);
    }
}
