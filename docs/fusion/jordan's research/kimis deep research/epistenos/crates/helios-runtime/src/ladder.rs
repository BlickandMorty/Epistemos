//! Tool Variant Ladder — deterministic A→B→C→D safety routing.
//!
//! Every tool in the Epistenos runtime has a **variant ladder** — a
//! sequence of fallback implementations ranked by cost, accuracy, and
//! availability. If variant A (the best) fails or times out, the ladder
//! automatically falls through to variant B, then C, then D.
//!
//! Each variant is protected by:
//! - a **RetryBudget** — per-attempt timeout + max attempts
//! - a **CircuitBreaker** — opens after N failures in a sliding window,
//!   heals after a cooldown
//!
//! This ensures that even when external services degrade, the system
//! continues operating with gracefully degraded but deterministic
//! behaviour.

use async_trait::async_trait;
use futures::Future;
use schemars::JsonSchema;
use serde::de::DeserializeOwned;
use serde::Serialize;
use std::collections::HashMap;
use std::pin::Pin;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use thiserror::Error;
use tokio::time::timeout;
use tracing::{debug, error, info, instrument, trace, warn};

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/// Errors that can arise during tool invocation.
#[derive(Error, Debug, Clone, PartialEq)]
pub enum ToolError {
    #[error("tool not found: {0}")]
    NotFound(String),

    #[error("circuit breaker open for {0}")]
    CircuitOpen(String),

    #[error("retry budget exhausted for {0}: {attempts} attempts")]
    BudgetExhausted { tool: String, attempts: u32 },

    #[error("timeout after {0}s")]
    Timeout(u64),

    #[error("invocation failed: {0}")]
    InvocationFailed(String),

    #[error("variant fallthrough exhausted for {0}")]
    VariantsExhausted(String),

    #[error("invalid input: {0}")]
    InvalidInput(String),
}

// ---------------------------------------------------------------------------
// Tool trait — the interface every tool must implement
// ---------------------------------------------------------------------------

/// Context passed to every tool invocation.
#[derive(Clone, Debug)]
pub struct ToolCtx {
    pub agent_id: crate::types::AgentId,
    pub session_id: crate::types::SessionId,
    pub trace_id: String,
}

/// The core tool trait.
///
/// Every tool in the Epistenos runtime implements this trait. The trait
/// is **object-safe** via the associated `Input` and `Output` types,
/// and each tool declares its GBNF grammar for structured generation,
/// its available variants, and its async invocation method.
#[async_trait]
pub trait Tool: Send + Sync {
    /// Static tool name (e.g. `reason.plan`).
    const NAME: &'static str;

    /// Human-readable description for UI and documentation.
    const DESCRIPTION: &'static str;

    /// Input type — must be deserializable and have a JSON Schema.
    type Input: DeserializeOwned + JsonSchema + Send;

    /// Output type — must be serializable and have a JSON Schema.
    type Output: Serialize + JsonSchema + Send;

    /// Return the GBNF grammar string used for structured generation
    /// when this tool is called via an LLM backend.
    fn gbnf() -> &'static str;

    /// Return the ordered list of variant IDs available for this tool.
    /// Variant 0 is the primary (best) implementation; higher indices
    /// are fallbacks.
    fn variants(&self) -> &[VariantId];

    /// Invoke the tool with structured input.
    ///
    /// The implementation is responsible for actual execution (network
    /// calls, file I/O, computation). The `ctx` provides trace context.
    async fn invoke(
        &self,
        input: Self::Input,
        ctx: &ToolCtx,
    ) -> Result<Self::Output, ToolError>;
}

// ---------------------------------------------------------------------------
// Variant types
// ---------------------------------------------------------------------------

/// A variant identifier — human-readable and machine-comparable.
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct VariantId(pub String);

impl VariantId {
    pub fn new(s: impl Into<String>) -> Self {
        Self(s.into())
    }
}

impl std::fmt::Display for VariantId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

/// Routing strategy for a variant.
///
/// Each variant in the ladder declares how it plans to satisfy the
/// tool request:
/// - `Centroid` — use a pre-computed centroid / embedding lookup
/// - `LLMClassify` — classify via a lightweight LLM call
/// - `ConceptSearch` — search a concept graph
/// - `Defer` — defer to a downstream service (async, higher latency)
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum RouteVariant {
    Centroid,
    LLMClassify,
    ConceptSearch,
    Defer,
}

/// A single variant implementation for a tool.
///
/// Variants are boxed trait objects so a [`VariantLadder`] can hold
/// heterogeneous implementations for the same tool.
#[async_trait]
pub trait Variant<T: Tool>: Send + Sync {
    /// Variant identifier.
    fn id(&self) -> &VariantId;

    /// Routing strategy.
    fn route(&self) -> RouteVariant;

    /// Attempt invocation.
    async fn try_invoke(
        &self,
        input: &T::Input,
        ctx: &ToolCtx,
    ) -> Result<T::Output, ToolError>;
}

// ---------------------------------------------------------------------------
// RetryBudget — per-variant resource limits
// ---------------------------------------------------------------------------

/// Resource budget for a single variant attempt.
///
/// Each variant in the ladder gets its own budget so that expensive
/// variants can have tighter constraints than cheap fallbacks.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct RetryBudget {
    /// Maximum wall-clock time for a single attempt.
    pub per_attempt: Duration,
    /// Maximum number of attempts before giving up on this variant.
    pub max_attempts: u32,
}

impl Default for RetryBudget {
    fn default() -> Self {
        Self {
            per_attempt: Duration::from_secs(5),
            max_attempts: 3,
        }
    }
}

impl RetryBudget {
    pub fn new(per_attempt: Duration, max_attempts: u32) -> Self {
        Self {
            per_attempt,
            max_attempts,
        }
    }
}

// ---------------------------------------------------------------------------
// CircuitBreaker — sliding-window failure detection
// ---------------------------------------------------------------------------

/// Per-tool circuit state.
#[derive(Clone, Debug)]
struct CircuitState {
    /// Is the circuit currently open (failing fast)?
    open: bool,
    /// When the circuit was last opened.
    opened_at: Option<Instant>,
    /// Failure timestamps in the sliding window.
    failures: VecDeque<Instant>,
    /// Success timestamps in the sliding window.
    successes: VecDeque<Instant>,
}

impl CircuitState {
    fn new() -> Self {
        Self {
            open: false,
            opened_at: None,
            failures: VecDeque::new(),
            successes: VecDeque::new(),
        }
    }
}

/// Circuit breaker with sliding-window statistics.
///
/// - **Opens** after 5 failures in a 60-second window
/// - **Heals** (closes) after 5 minutes of cooldown once open
/// - **Half-open** is implicit: the first success after cooldown closes it
#[derive(Clone, Debug)]
pub struct CircuitBreaker {
    window: Duration,
    failure_threshold: u32,
    cooldown: Duration,
    circuits: Arc<Mutex<HashMap<String, CircuitState>>>,
}

impl CircuitBreaker {
    /// Create a breaker with default thresholds.
    pub fn new() -> Self {
        Self {
            window: Duration::from_secs(60),
            failure_threshold: 5,
            cooldown: Duration::from_secs(300),
            circuits: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    /// Create with custom thresholds.
    pub fn with_thresholds(window: Duration, failure_threshold: u32, cooldown: Duration) -> Self {
        Self {
            window,
            failure_threshold,
            cooldown,
            circuits: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    fn state_mut(&self, name: &str) -> CircuitState {
        let mut map = self.circuits.lock().unwrap();
        map.get(name).cloned().unwrap_or_else(|| {
            let s = CircuitState::new();
            map.insert(name.to_string(), s.clone());
            s
        })
    }

    fn update(&self, name: &str, state: CircuitState) {
        let mut map = self.circuits.lock().unwrap();
        map.insert(name.to_string(), state);
    }

    /// Is the circuit open for `name`?
    #[instrument(skip(self), fields(name))]
    pub fn is_open(&self, name: &str) -> bool {
        let mut state = self.state_mut(name);
        let now = Instant::now();

        // Evict stale entries
        while let Some(t) = state.failures.front() {
            if now.duration_since(*t) > self.window {
                state.failures.pop_front();
            } else {
                break;
            }
        }
        while let Some(t) = state.successes.front() {
            if now.duration_since(*t) > self.window {
                state.successes.pop_front();
            } else {
                break;
            }
        }

        // If open, check cooldown
        if state.open {
            if let Some(opened) = state.opened_at {
                if now.duration_since(opened) > self.cooldown {
                    info!(name, "circuit breaker cooldown elapsed — transitioning to half-open");
                    state.open = false;
                    state.opened_at = None;
                }
            }
        }

        self.update(name, state.clone());
        state.open
    }

    /// Record a successful invocation.
    pub fn record_success(&self, name: &str) {
        let mut state = self.state_mut(name);
        let now = Instant::now();
        state.successes.push_back(now);
        if state.open {
            info!(name, "circuit breaker closed after success");
            state.open = false;
            state.opened_at = None;
        }
        self.update(name, state);
    }

    /// Record a failed invocation.
    pub fn record_failure(&self, name: &str) {
        let mut state = self.state_mut(name);
        let now = Instant::now();
        state.failures.push_back(now);

        // Evict old failures before checking threshold
        while let Some(t) = state.failures.front() {
            if now.duration_since(*t) > self.window {
                state.failures.pop_front();
            } else {
                break;
            }
        }

        if !state.open && state.failures.len() as u32 >= self.failure_threshold {
            warn!(name, failures = state.failures.len(), "circuit breaker OPENED");
            state.open = true;
            state.opened_at = Some(now);
        }

        self.update(name, state);
    }

    /// Get current failure count in the window.
    pub fn failure_count(&self, name: &str) -> usize {
        let state = self.state_mut(name);
        state.failures.len()
    }
}

impl Default for CircuitBreaker {
    fn default() -> Self {
        Self::new()
    }
}

// ---------------------------------------------------------------------------
// run_variant — wrapper with timeout and healing
// ---------------------------------------------------------------------------

/// Run a future with circuit-breaker and retry-budget protection.
///
/// This is the core safety wrapper for every variant invocation:
/// 1. Check if the circuit is open → return `None` immediately
/// 2. Try the future with a timeout
/// 3. Record success or failure
/// 4. Retry up to `budget.max_attempts` times
/// 5. If all attempts fail, return `None`
#[instrument(skip(breaker, f), fields(variant = name))]
pub async fn run_variant<T, F>(
    name: &str,
    budget: RetryBudget,
    breaker: &CircuitBreaker,
    f: impl Fn() -> F,
) -> Option<T>
where
    F: Future<Output = Result<T, ToolError>>,
{
    if breaker.is_open(name) {
        warn!(name, "circuit breaker open — skipping variant");
        return None;
    }

    let mut attempts = 0u32;
    while attempts < budget.max_attempts {
        attempts += 1;
        trace!(attempt = attempts, max = budget.max_attempts, "variant attempt");

        let timed = timeout(budget.per_attempt, f());
        match timed.await {
            Ok(Ok(result)) => {
                breaker.record_success(name);
                debug!(attempts, name, "variant succeeded");
                return Some(result);
            }
            Ok(Err(e)) => {
                warn!(attempts, error = %e, name, "variant failed");
                breaker.record_failure(name);
                if breaker.is_open(name) {
                    break;
                }
            }
            Err(_) => {
                warn!(attempts, timeout = ?budget.per_attempt, name, "variant timed out");
                breaker.record_failure(name);
                if breaker.is_open(name) {
                    break;
                }
            }
        }
    }

    error!(attempts, name, "variant exhausted all attempts");
    None
}

// ---------------------------------------------------------------------------
// VariantLadder — the A→B→C→D chain
// ---------------------------------------------------------------------------

/// A variant ladder holds an ordered list of implementations for a
/// single tool, plus the safety machinery (budget and breaker).
///
/// Invocation walks the ladder from index 0 (best) to N-1 (worst),
/// stopping at the first successful variant.
pub struct VariantLadder<T: Tool> {
    pub tool_name: String,
    pub variants: Vec<Box<dyn Variant<T>>>,
    pub budget: RetryBudget,
    pub breaker: CircuitBreaker,
}

impl<T: Tool> VariantLadder<T> {
    pub fn new(tool_name: String, budget: RetryBudget, breaker: CircuitBreaker) -> Self {
        Self {
            tool_name,
            variants: Vec::new(),
            budget,
            breaker,
        }
    }

    /// Add a variant to the ladder.
    pub fn add_variant(&mut self, v: Box<dyn Variant<T>>) {
        self.variants.push(v);
    }

    /// Invoke the tool via the ladder.
    ///
    /// Tries each variant in order, applying `run_variant` with the
    /// shared circuit breaker and per-variant retry budget.
    #[instrument(skip(self, input, ctx), fields(tool = %self.tool_name))]
    pub async fn invoke(
        &self,
        input: &T::Input,
        ctx: &ToolCtx,
    ) -> Result<T::Output, ToolError> {
        for (idx, variant) in self.variants.iter().enumerate() {
            let variant_name = format!("{}@{}", self.tool_name, variant.id());
            debug!(idx, variant = %variant.id(), "trying variant");

            let result = run_variant(
                &variant_name,
                self.budget,
                &self.breaker,
                || variant.try_invoke(input, ctx),
            )
            .await;

            if let Some(output) = result {
                info!(idx, variant = %variant.id(), "variant succeeded");
                return Ok(output);
            }
        }

        error!(tool = %self.tool_name, "all variants exhausted");
        Err(ToolError::VariantsExhausted(self.tool_name.clone()))
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};

    #[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, PartialEq)]
    struct TestInput {
        x: i32,
    }

    #[derive(Clone, Debug, Serialize, Deserialize, JsonSchema, PartialEq)]
    struct TestOutput {
        y: i32,
    }

    struct TestTool;

    #[async_trait]
    impl Tool for TestTool {
        const NAME: &'static str = "test.echo";
        const DESCRIPTION: &'static str = "Echo test tool";
        type Input = TestInput;
        type Output = TestOutput;

        fn gbnf() -> &'static str {
            "root ::= '{\"y\": ' [0-9]+ '}'"
        }

        fn variants(&self) -> &[VariantId] {
            static VARIANTS: [VariantId; 2] = [
                VariantId(String::from("v1")),
                VariantId(String::from("v2")),
            ];
            &VARIANTS
        }

        async fn invoke(
            &self,
            input: Self::Input,
            _ctx: &ToolCtx,
        ) -> Result<Self::Output, ToolError> {
            Ok(TestOutput { y: input.x })
        }
    }

    struct SuccessVariant;

    #[async_trait]
    impl Variant<TestTool> for SuccessVariant {
        fn id(&self) -> &VariantId {
            static ID: VariantId = VariantId(String::from("success"));
            &ID
        }
        fn route(&self) -> RouteVariant {
            RouteVariant::Centroid
        }
        async fn try_invoke(
            &self,
            input: &TestInput,
            _ctx: &ToolCtx,
        ) -> Result<TestOutput, ToolError> {
            Ok(TestOutput { y: input.x * 2 })
        }
    }

    struct FailVariant;

    #[async_trait]
    impl Variant<TestTool> for FailVariant {
        fn id(&self) -> &VariantId {
            static ID: VariantId = VariantId(String::from("fail"));
            &ID
        }
        fn route(&self) -> RouteVariant {
            RouteVariant::Defer
        }
        async fn try_invoke(
            &self,
            _input: &TestInput,
            _ctx: &ToolCtx,
        ) -> Result<TestOutput, ToolError> {
            Err(ToolError::InvocationFailed("always fails".into()))
        }
    }

    #[test]
    fn circuit_breaker_starts_closed() {
        let breaker = CircuitBreaker::new();
        assert!(!breaker.is_open("test"));
    }

    #[test]
    fn circuit_breaker_opens_after_threshold() {
        let breaker = CircuitBreaker::with_thresholds(
            Duration::from_secs(60),
            3,
            Duration::from_secs(300),
        );
        for _ in 0..3 {
            breaker.record_failure("test");
        }
        assert!(breaker.is_open("test"));
    }

    #[test]
    fn circuit_breaker_records_success() {
        let breaker = CircuitBreaker::new();
        breaker.record_success("test");
        breaker.record_success("test");
        assert!(!breaker.is_open("test"));
        assert_eq!(breaker.failure_count("test"), 0);
    }

    #[test]
    fn circuit_breaker_heals_after_cooldown() {
        let breaker = CircuitBreaker::with_thresholds(
            Duration::from_secs(60),
            1,
            Duration::from_millis(50),
        );
        breaker.record_failure("test");
        assert!(breaker.is_open("test"));

        std::thread::sleep(Duration::from_millis(100));
        assert!(!breaker.is_open("test"));
    }

    #[test]
    fn circuit_breaker_sliding_window_eviction() {
        let breaker = CircuitBreaker::with_thresholds(
            Duration::from_millis(50),
            2,
            Duration::from_secs(300),
        );
        breaker.record_failure("test");
        std::thread::sleep(Duration::from_millis(60));
        breaker.record_failure("test");
        // First failure is now outside the window, so we only have 1
        assert!(!breaker.is_open("test"));
    }

    #[tokio::test]
    async fn run_variant_success() {
        let breaker = CircuitBreaker::new();
        let budget = RetryBudget::new(Duration::from_secs(1), 1);

        let result: Option<i32> = run_variant("ok", budget, &breaker, || async { Ok(42) }).await;
        assert_eq!(result, Some(42));
        assert!(!breaker.is_open("ok"));
    }

    #[tokio::test]
    async fn run_variant_timeout() {
        let breaker = CircuitBreaker::new();
        let budget = RetryBudget::new(Duration::from_millis(10), 1);

        let result: Option<i32> = run_variant("slow", budget, &breaker, || async {
            tokio::time::sleep(Duration::from_secs(1)).await;
            Ok(42)
        })
        .await;
        assert_eq!(result, None);
        assert_eq!(breaker.failure_count("slow"), 1);
    }

    #[tokio::test]
    async fn run_variant_retry_healing() {
        let breaker = CircuitBreaker::new();
        let budget = RetryBudget::new(Duration::from_millis(100), 3);
        let counter = Arc::new(AtomicUsize::new(0));

        let c = counter.clone();
        let result: Option<i32> = run_variant("heal", budget, &breaker, move || {
            let c = c.clone();
            async move {
                if c.fetch_add(1, Ordering::SeqCst) < 2 {
                    Err(ToolError::InvocationFailed("transient".into()))
                } else {
                    Ok(42)
                }
            }
        })
        .await;

        assert_eq!(result, Some(42));
        assert_eq!(counter.load(Ordering::SeqCst), 3);
    }

    #[tokio::test]
    async fn variant_ladder_fallthrough() {
        let mut ladder: VariantLadder<TestTool> = VariantLadder::new(
            "test.echo".into(),
            RetryBudget::new(Duration::from_secs(1), 2),
            CircuitBreaker::new(),
        );
        ladder.add_variant(Box::new(FailVariant));
        ladder.add_variant(Box::new(SuccessVariant));

        let ctx = ToolCtx {
            agent_id: crate::types::AgentId::new(),
            session_id: crate::types::SessionId::new(),
            trace_id: "t1".into(),
        };

        let result = ladder.invoke(&TestInput { x: 5 }, &ctx).await.unwrap();
        assert_eq!(result.y, 10);
    }

    #[tokio::test]
    async fn variant_ladder_all_fail() {
        let mut ladder: VariantLadder<TestTool> = VariantLadder::new(
            "test.echo".into(),
            RetryBudget::new(Duration::from_secs(1), 1),
            CircuitBreaker::new(),
        );
        ladder.add_variant(Box::new(FailVariant));

        let ctx = ToolCtx {
            agent_id: crate::types::AgentId::new(),
            session_id: crate::types::SessionId::new(),
            trace_id: "t1".into(),
        };

        let result = ladder.invoke(&TestInput { x: 5 }, &ctx).await;
        assert!(matches!(result, Err(ToolError::VariantsExhausted(_))));
    }

    #[test]
    fn retry_budget_default() {
        let b = RetryBudget::default();
        assert_eq!(b.max_attempts, 3);
        assert_eq!(b.per_attempt, Duration::from_secs(5));
    }

    #[test]
    fn variant_id_display() {
        let v = VariantId::new("centroid-v1");
        assert_eq!(v.to_string(), "centroid-v1");
    }
}
