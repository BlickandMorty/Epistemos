//! Goose=WORK seam (R-GOOSE, Seam B). The Rust-side seam the Swift `WorkBackend`
//! drives via UniFFI once block/goose (Apache-2.0) is vendored into agent_core as the
//! Work engine. ISOLATED by construction: nothing in the `agent_loop` / `agent_runtime`
//! (Chat / Act) path references this module, so the GOOSE GUARDRAIL (Chat/Act
//! UNCHANGED) holds. Always-compiled + INERT; the real Goose engine is the gated
//! vendor (the heavy follow-on). REAL APIs ONLY — no fake capability, no silent
//! fallback to the Chat/Act engine.

/// Flag that arms the Goose Work seam (mirrors the Swift `EPISTEMOS_WORK_GOOSE_V0`).
pub const WORK_GOOSE_FLAG: &str = "EPISTEMOS_WORK_GOOSE_V0";

/// ProvenanceGate posture for the vendored block/goose source (Goose S2).
pub const GOOSE_VENDOR_LICENSE: &str = "Apache-2.0";
pub const GOOSE_VENDOR_SOURCE: &str = "block/goose";

/// ✅ PERMANENT CLEAN-ROOM HOME (owner 2026-06-21, Architecture C FINALIZED): the work ENGINE is
/// OpenCode (headless Bun, own process), NOT a vendored Goose crate. The heavy `goose` crate is
/// DELIBERATELY NOT vendored — that avoids the confirmed 179-dep / reqwest-0.12-vs-0.13.2 / 660MB
/// build-red saga (see docs/research/GOOSE_FULL_CLONE_INTEGRATION_COST_2026_06_21.md). Goose's
/// genuinely-unique HARDENING bits live HERE as the permanent in-tree clean-room Rust, surfaced as
/// work-loop TOOLS beneath the OpenCode engine: `RetryManager`/`RepetitionGuard` (test-and-fix +
/// loop-safety) + `recipe` (parameterized tasks — VERIFY vs OpenCode's own command/agent config,
/// drop if duplicated). These are KEPT, GOOSE-GUARDRAIL-isolated (Chat/Act unchanged), NEVER deleted.
///
/// DROPPED under Architecture C: Goose `permission` (OpenCode, a coding agent, has its own file/shell
/// permission gating → the leaf-port was a duplicate). `SourceRoot`/`message::Role` remain as the
/// thin first-party seam types the work request/transcript use.
///
/// Vendored block/goose types (Apache-2.0, ProvenanceGate `direct_import`) — kept as the clean-room
/// home; the GOOSE GUARDRAIL (Chat/Act unchanged) holds.
pub mod vendored_goose {
    //! Provenance: github.com/block/goose (Apache-2.0), crates/goose/src/source_roots.rs.
    //! `direct_import` — the type body between the VERBATIM markers is byte-for-byte
    //! from upstream; the `pub mod` wrapper + this header are the only additions.
    //! See docs/GOOSE_S2_EXTRACTION_PLAN_2026_06_19.md.

    // --- BEGIN VERBATIM (block/goose, Apache-2.0) ---
    use std::path::PathBuf;

    #[derive(Debug, Clone, PartialEq, Eq)]
    pub struct SourceRoot {
        pub path: PathBuf,
        pub writable: bool,
    }

    impl SourceRoot {
        pub fn read_only(path: PathBuf) -> Self {
            Self {
                path,
                writable: false,
            }
        }
    }
    // --- END VERBATIM ---

    // DROPPED under Architecture C (owner 2026-06-21): the Goose `permission` leaf-port
    // (Permission/PrincipalType/PermissionConfirmation) is removed — OpenCode (the work engine) has
    // its own file/shell permission gating, so the vendored Goose permission types were a duplicate.

    /// Vendored block/goose recipe-PARAMETER types (Goose S4) — the typed inputs a
    /// Work recipe/task declares (key + input type + requirement + default + options).
    /// A self-contained (serde-only) leaf; lets `WorkRequest` carry typed parameters.
    pub mod recipe {
        //! Provenance: github.com/block/goose (Apache-2.0),
        //! crates/goose/src/recipe/mod.rs.
        //! `direct_import` with documented adaptations: (1) the upstream `ToSchema`
        //! derive + `use utoipa` are DROPPED (agent_core has no `utoipa`); (2) the
        //! `Display` impls (which used `serde_json::to_string(self).unwrap()`) are
        //! OMITTED — a convenience not needed for the Work seam, and `.unwrap()`
        //! violates the project no-force-unwrap rule; (3) `PartialEq` is ADDED (not
        //! upstream), plus `Eq` where the field types allow (the parameter types; NOT
        //! `Settings`, whose `temperature: Option<f32>` isn't `Eq`) — additive only,
        //! wire-form unchanged. Every struct field + enum variant + the serde
        //! `rename_all = "snake_case"` is byte-for-byte upstream.

        // --- BEGIN VERBATIM (block/goose, Apache-2.0; ToSchema+Display trimmed, Eq added) ---
        use serde::{Deserialize, Serialize};

        #[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq)]
        #[serde(rename_all = "snake_case")]
        pub enum RecipeParameterRequirement {
            Required,
            Optional,
            UserPrompt,
        }

        #[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq)]
        #[serde(rename_all = "snake_case")]
        pub enum RecipeParameterInputType {
            String,
            Number,
            Boolean,
            Date,
            /// File parameter that imports content from a file path.
            /// Cannot have default values to prevent importing sensitive user files.
            File,
            Select,
        }

        #[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq)]
        pub struct RecipeParameter {
            pub key: String,
            pub input_type: RecipeParameterInputType,
            pub requirement: RecipeParameterRequirement,
            pub description: String,
            #[serde(skip_serializing_if = "Option::is_none")]
            pub default: Option<String>,
            #[serde(skip_serializing_if = "Option::is_none")]
            pub options: Option<Vec<String>>,
        }

        /// A Work task's model SETTINGS — provider / model / temperature / turn budget.
        /// `PartialEq` only (no `Eq`): `temperature: Option<f32>` isn't `Eq`.
        #[derive(Serialize, Deserialize, Debug, Clone, PartialEq)]
        pub struct Settings {
            #[serde(skip_serializing_if = "Option::is_none")]
            pub goose_provider: Option<String>,

            #[serde(skip_serializing_if = "Option::is_none")]
            pub goose_model: Option<String>,

            #[serde(skip_serializing_if = "Option::is_none")]
            pub temperature: Option<f32>,

            #[serde(skip_serializing_if = "Option::is_none")]
            pub max_turns: Option<usize>,
        }
        // --- END VERBATIM ---
    }

    /// `RetryConfig` — the deterministic test-and-fix self-correction policy (Goose S7).
    /// This is the owner's "deterministic test-and-fix self-correction loop" Goose pillar
    /// as a typed, validated config.
    ///
    /// VERBATIM from block/goose `crates/goose/src/agents/types.rs`: the struct fields, the
    /// `SuccessCheck` enum + its serde `tag = "type"` wire-form (incl. the `"shell"` alias),
    /// the two default-timeout constants, and the `validate()` rules are byte-for-byte
    /// upstream. Two faithful adaptations: the `utoipa::ToSchema` derive is dropped
    /// (agent_core has no utoipa dep; the seam needs only serde), and `PartialEq` is added
    /// (so it composes into `WorkRequest`'s `PartialEq`). MAS-SAFE: the `on_failure` /
    /// `Shell { command }` strings are only CARRIED here — the inert seam executes nothing;
    /// running the success-check / cleanup shell commands is the future Pro-gated engine lane.
    pub mod retry {
        use serde::{Deserialize, Serialize};

        // --- BEGIN VERBATIM (block/goose agents/types.rs; ToSchema dropped, PartialEq added) ---
        /// Default timeout for retry operations (5 minutes)
        pub const DEFAULT_RETRY_TIMEOUT_SECONDS: u64 = 300;

        /// Default timeout for on_failure operations (10 minutes - longer for on_failure tasks)
        pub const DEFAULT_ON_FAILURE_TIMEOUT_SECONDS: u64 = 600;

        /// Configuration for retry logic in recipe execution
        #[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
        pub struct RetryConfig {
            /// Maximum number of retry attempts before giving up
            pub max_retries: u32,
            /// List of success checks to validate recipe completion
            pub checks: Vec<SuccessCheck>,
            /// Optional shell command to run on failure for cleanup
            #[serde(skip_serializing_if = "Option::is_none")]
            pub on_failure: Option<String>,
            /// Timeout in seconds for individual shell commands (default: 300 seconds)
            #[serde(skip_serializing_if = "Option::is_none")]
            pub timeout_seconds: Option<u64>,
            /// Timeout in seconds for on_failure commands (default: 600 seconds)
            #[serde(skip_serializing_if = "Option::is_none")]
            pub on_failure_timeout_seconds: Option<u64>,
        }

        impl RetryConfig {
            /// Validates the retry configuration values
            pub fn validate(&self) -> Result<(), String> {
                if self.max_retries == 0 {
                    return Err("max_retries must be greater than 0".to_string());
                }

                if let Some(timeout) = self.timeout_seconds {
                    if timeout == 0 {
                        return Err("timeout_seconds must be greater than 0 if specified".to_string());
                    }
                }

                if let Some(on_failure_timeout) = self.on_failure_timeout_seconds {
                    if on_failure_timeout == 0 {
                        return Err(
                            "on_failure_timeout_seconds must be greater than 0 if specified".to_string(),
                        );
                    }
                }

                Ok(())
            }
        }

        /// A single success check to validate recipe completion
        #[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
        #[serde(tag = "type")]
        pub enum SuccessCheck {
            /// Execute a shell command and check its exit status
            #[serde(alias = "shell")]
            Shell {
                /// The shell command to execute
                command: String,
            },
        }
        // --- END VERBATIM ---
    }

    /// Vendored block/goose conversation message layer (Goose Phase W0, next leaf). goose's
    /// `Message.role` is `rmcp::model::Role` (the MCP SDK re-export); this leaf matches rmcp's
    /// wire form EXACTLY — `#[serde(rename_all = "camelCase")]` → `User`→"user",
    /// `Assistant`→"assistant". Grounded: block/goose @d2a921a7
    /// (`crates/goose-providers/src/conversation/message.rs`), rmcp Role in rust-sdk
    /// `crates/rmcp/src/model.rs`. The engine layer (S4+) consumes it; the seam stays inert.
    pub mod message {
        use serde::{Deserialize, Serialize};

        // --- BEGIN VERBATIM (rmcp::model::Role, re-exported by block/goose) ---
        #[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
        #[serde(rename_all = "camelCase")]
        pub enum Role {
            User,
            Assistant,
        }
        // --- END VERBATIM ---
    }
}

/// First-party typed Work REQUEST (NOT vendored — the seam contract the Swift
/// `WorkBackend` hands across UniFFI). Carries the objective + the workspace roots the
/// engine operates on (the vendored block/goose `SourceRoot`). Permission posture is the
/// OpenCode engine's own concern under Architecture C (the Goose `permission` leaf was
/// dropped). The engine layer consumes this; until then `run_work_session` stays inert.
// `Eq` is intentionally NOT derived: `settings` embeds the vendored `Settings`, whose
// `temperature: Option<f32>` isn't `Eq`. `PartialEq` (sufficient for tests + callers)
// is kept; nothing compares whole `WorkRequest`s for `Eq`.
#[derive(Debug, Clone, PartialEq)]
pub struct WorkRequest {
    pub objective: String,
    pub source_roots: Vec<vendored_goose::SourceRoot>,
    /// The typed parameters this Work task declares (vendored block/goose recipe
    /// parameters — Goose S4). Empty by default; the engine layer consumes them.
    pub parameters: Vec<vendored_goose::recipe::RecipeParameter>,
    /// The Work task's model settings (vendored block/goose recipe `Settings` — Goose
    /// S5): provider / model / temperature / turn budget. `None` = engine defaults.
    pub settings: Option<vendored_goose::recipe::Settings>,
    /// The deterministic test-and-fix self-correction policy (vendored block/goose
    /// `RetryConfig` — Goose S7): the retry budget + the success checks the engine re-runs
    /// after each attempt + the optional cleanup command. `None` = no automated retry. The
    /// engine layer consumes it; the inert seam never executes the checks / `on_failure`.
    pub retry: Option<vendored_goose::retry::RetryConfig>,
}

impl WorkRequest {
    /// A read-only request over the given roots with no declared parameters and the
    /// engine's default model settings. Permission posture is the OpenCode engine's
    /// concern under Architecture C (the Goose permission leaf was dropped).
    pub fn read_only(objective: impl Into<String>, roots: Vec<vendored_goose::SourceRoot>) -> Self {
        Self {
            objective: objective.into(),
            source_roots: roots,
            parameters: Vec::new(),
            settings: None,
            retry: None,
        }
    }
}

/// First-party typed Work RESULT (NOT vendored) — what a completed Work session
/// returns: an honest summary + the files the engine touched.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WorkResult {
    pub summary: String,
    pub files_touched: Vec<std::path::PathBuf>,
}

/// Honest errors for a Work session — no engine wired, or the run failed. The caller
/// surfaces these; the seam NEVER silently falls back to the Chat/Act engine.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum WorkError {
    EngineNotWired,
    RunFailed(String),
}

impl std::fmt::Display for WorkError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            WorkError::EngineNotWired => write!(f, "Goose Work engine not wired"),
            WorkError::RunFailed(m) => write!(f, "Work run failed: {m}"),
        }
    }
}
impl std::error::Error for WorkError {}

/// Loop-safety guard for the Work engine's tool calls (Goose S6) — blocks a tool call
/// when the SAME call (name + args) repeats CONSECUTIVELY more than `max_repetitions`
/// times, so a Work session can't spin forever on one action. Also tracks per-tool
/// total counts.
///
/// ProvenanceGate `clean_room_rewrite` of the block/goose `RepetitionInspector`
/// algorithm (Apache-2.0, crates/goose/src/tool_monitor.rs): the consecutive-repeat
/// detection + per-tool counting are the SAME algorithm, re-expressed against a
/// first-party tool-call shape (name + `serde_json::Value` args) so it pulls NO
/// `rmcp` / `async_trait` / internal-goose deps. This is a FIRST-PARTY type — NOT a
/// vendored verbatim import — and uses no force-unwrap (the project rule the upstream
/// `.unwrap()` would have violated).
#[derive(Debug, Default)]
pub struct RepetitionGuard {
    max_repetitions: Option<u32>,
    last_call: Option<(String, serde_json::Value)>,
    repeat_count: u32,
    call_counts: std::collections::HashMap<String, u32>,
}

impl RepetitionGuard {
    pub fn new(max_repetitions: Option<u32>) -> Self {
        Self {
            max_repetitions,
            last_call: None,
            repeat_count: 0,
            call_counts: std::collections::HashMap::new(),
        }
    }

    /// Record a tool call. Returns `true` if it may proceed, `false` if it exceeds the
    /// consecutive-repetition limit (the engine should stop / change tack). With
    /// `max_repetitions == None` it never blocks (only counts).
    pub fn check(&mut self, name: &str, args: &serde_json::Value) -> bool {
        *self.call_counts.entry(name.to_string()).or_insert(0) += 1;

        let max = match self.max_repetitions {
            None => {
                self.last_call = Some((name.to_string(), args.clone()));
                self.repeat_count = 1;
                return true;
            }
            Some(max) => max,
        };

        match &self.last_call {
            Some((last_name, last_args)) if last_name == name && last_args == args => {
                self.repeat_count += 1;
                if self.repeat_count > max {
                    return false;
                }
            }
            _ => {
                self.repeat_count = 1;
            }
        }

        self.last_call = Some((name.to_string(), args.clone()));
        true
    }

    /// Total times a given tool has been called this session.
    pub fn call_count(&self, name: &str) -> u32 {
        self.call_counts.get(name).copied().unwrap_or(0)
    }

    /// Clear all repetition state (e.g. between Work sessions).
    pub fn reset(&mut self) {
        self.last_call = None;
        self.repeat_count = 0;
        self.call_counts.clear();
    }
}

/// Outcome of one self-correction retry evaluation (Goose S8).
///
/// ProvenanceGate `clean_room_rewrite` of block/goose `agents::retry::RetryResult`
/// (Apache-2.0): the SAME four deterministic outcomes, re-expressed as a first-party enum.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RetryResult {
    /// No retry configuration → retry logic skipped.
    Skipped,
    /// All success checks passed on this attempt → no retry needed.
    SuccessChecksPassed,
    /// `attempts >= max_retries` already → cannot retry further.
    MaxAttemptsReached,
    /// Checks failed and attempts remain → a retry was performed.
    Retried,
}

/// The deterministic driver of the test-and-fix self-correction loop (Goose S8) — it turns
/// the vendored [`vendored_goose::retry::RetryConfig`] (S7) into working control flow.
///
/// ProvenanceGate `clean_room_rewrite` of block/goose `agents::retry::{RetryManager,
/// handle_retry_logic}` (agents/retry.rs, Apache-2.0): the attempt counter + the EXACT
/// decision sequence are re-expressed against a first-party shape. Upstream's
/// `handle_retry_logic` is async and EXECUTES shell commands (`execute_success_checks` /
/// `execute_on_failure_command`); here the side effects are HOISTED OUT — the caller passes
/// in whether this attempt's checks passed and an `on_failure` callback — so this seam runs
/// NOTHING itself (MAS-safe; the real shell execution is the future Pro engine lane, per
/// APP-NATIVE-BY-EMBEDDING: embed the control flow, gate the un-sandboxable execution).
/// No force-unwrap (the project rule upstream's `.await?` paths sidestep differently).
#[derive(Debug, Default)]
pub struct RetryManager {
    attempts: u32,
}

impl RetryManager {
    pub fn new() -> Self {
        Self { attempts: 0 }
    }

    /// The number of retries performed so far.
    pub fn attempts(&self) -> u32 {
        self.attempts
    }

    /// Reset the attempt counter (e.g. between Work sessions) — upstream `reset_attempts`.
    pub fn reset(&mut self) {
        self.attempts = 0;
    }

    /// Evaluate the next self-correction step, mirroring upstream `handle_retry_logic`'s
    /// control flow byte-for-byte: no config → `Skipped`; this attempt's checks all passed
    /// → `SuccessChecksPassed`; `attempts >= max_retries` → `MaxAttemptsReached`; otherwise
    /// run the `on_failure` cleanup (if the config declares one), increment the attempt
    /// counter, and return `Retried`. `checks_passed` is supplied by the caller (it ran the
    /// success checks); `on_failure` is the caller's cleanup hook (the real shell exec in
    /// the Pro lane, or a no-op). This function executes no shell itself.
    pub fn evaluate(
        &mut self,
        config: Option<&vendored_goose::retry::RetryConfig>,
        checks_passed: bool,
        mut on_failure: impl FnMut(&str),
    ) -> RetryResult {
        let Some(config) = config else {
            return RetryResult::Skipped;
        };
        if checks_passed {
            return RetryResult::SuccessChecksPassed;
        }
        if self.attempts >= config.max_retries {
            return RetryResult::MaxAttemptsReached;
        }
        if let Some(cmd) = &config.on_failure {
            on_failure(cmd);
        }
        self.attempts += 1;
        RetryResult::Retried
    }
}

/// Executes the SIDE-EFFECTING parts of the self-correction loop (Goose S9): running the
/// success checks + the on_failure cleanup. Behind a trait so the deterministic
/// [`RetryManager`] runs NOTHING itself — the MAS build carries only this interface + test
/// mocks; the REAL shell implementation ([`ShellRetryExecutor`]) is `pro-build`-only because
/// subprocess execution is outside the MAS sandbox. This is the APP-NATIVE-BY-EMBEDDING
/// split made concrete: the deterministic control flow ships everywhere; the un-sandboxable
/// execution is gated to the Pro lane.
pub trait RetryExecutor {
    /// Run every success check; returns `true` only if ALL pass (upstream
    /// `execute_success_checks` semantics). An empty check list trivially passes. `timeout_seconds` is
    /// `RetryConfig.timeout_seconds` — a per-check wall-clock bound (a hung check counts as a failure).
    fn run_success_checks(
        &mut self,
        checks: &[vendored_goose::retry::SuccessCheck],
        timeout_seconds: Option<u64>,
    ) -> bool;
    /// Run the on_failure cleanup command (best-effort; the loop proceeds regardless). `timeout_seconds`
    /// is `RetryConfig.on_failure_timeout_seconds` (a hung cleanup is killed, not waited on forever).
    fn run_on_failure(&mut self, command: &str, timeout_seconds: Option<u64>);
}

/// Drive ONE self-correction cycle: run this attempt's checks via `exec`, then evaluate the
/// next step via `manager` (which invokes `exec`'s on_failure on the `Retried` path). Pure
/// orchestration over the injected executor — the seam itself spawns nothing; `exec` owns
/// every side effect. With no `config` the checks are skipped entirely (the cycle is
/// `Skipped`), matching upstream's "no retry config → skip" short-circuit.
pub fn drive_retry_cycle(
    manager: &mut RetryManager,
    config: Option<&vendored_goose::retry::RetryConfig>,
    exec: &mut dyn RetryExecutor,
) -> RetryResult {
    let checks_passed = match config {
        Some(c) => exec.run_success_checks(&c.checks, c.timeout_seconds),
        None => false, // evaluate(None, …) returns Skipped regardless of this value
    };
    // The on_failure command honors its OWN timeout (on_failure_timeout_seconds), captured here so the
    // fixed `FnMut(&str)` closure shape can pass it through to the executor.
    let on_failure_timeout = config.and_then(|c| c.on_failure_timeout_seconds);
    manager.evaluate(config, checks_passed, |cmd| {
        exec.run_on_failure(cmd, on_failure_timeout)
    })
}

/// Run one shell command in a HARDENED subprocess (`crate::security::harden_cli_subprocess_std` →
/// env_clear + the canonical allowlist/denylist + process group). `true` iff it exits 0. When
/// `timeout_seconds` is set, the command is bounded by wall-clock: it's polled to its deadline and KILLED
/// on overrun (returning `false`) — a hung success-check / cleanup can no longer block the work retry cycle
/// forever (`std::process` has no built-in timeout, so we poll `try_wait`). NOT pro-gated: the timeout logic
/// is the valuable, testable part and spawns no privileged work itself; only `ShellRetryExecutor` (which
/// wires it into the Goose retry seam) is Pro-only.
pub(crate) fn run_shell_with_timeout(command: &str, timeout_seconds: Option<u64>) -> bool {
    let mut cmd = std::process::Command::new("/bin/sh");
    cmd.arg("-c").arg(command);
    crate::security::harden_cli_subprocess_std(&mut cmd);

    let Some(secs) = timeout_seconds else {
        // No bound → blocking wait (the historical behavior).
        return matches!(cmd.status(), Ok(status) if status.success());
    };
    let mut child = match cmd.spawn() {
        Ok(c) => c,
        Err(_) => return false,
    };
    let deadline = std::time::Instant::now() + std::time::Duration::from_secs(secs);
    loop {
        match child.try_wait() {
            Ok(Some(status)) => return status.success(),
            Ok(None) => {
                if std::time::Instant::now() >= deadline {
                    let _ = child.kill();
                    let _ = child.wait();
                    return false; // timed out → counts as a failed check
                }
                std::thread::sleep(std::time::Duration::from_millis(50));
            }
            Err(_) => return false,
        }
    }
}

/// Pro-gated REAL executor: runs each success-check / on_failure shell command via
/// `run_shell_with_timeout` (hardened subprocess + wall-clock bound). Subprocess execution is outside the
/// MAS sandbox, so this is `pro-build`-only; the MAS build has the trait + mocks but never this impl.
#[cfg(feature = "pro-build")]
#[derive(Debug, Default)]
pub struct ShellRetryExecutor;

#[cfg(feature = "pro-build")]
impl RetryExecutor for ShellRetryExecutor {
    fn run_success_checks(
        &mut self,
        checks: &[vendored_goose::retry::SuccessCheck],
        timeout_seconds: Option<u64>,
    ) -> bool {
        checks.iter().all(|check| match check {
            vendored_goose::retry::SuccessCheck::Shell { command } => {
                run_shell_with_timeout(command, timeout_seconds)
            }
        })
    }

    fn run_on_failure(&mut self, command: &str, timeout_seconds: Option<u64>) {
        let _ = run_shell_with_timeout(command, timeout_seconds); // best-effort cleanup; result ignored
    }
}

fn flag_is_armed(raw: Option<&str>) -> bool {
    matches!(
        raw.map(|s| s.trim().to_ascii_lowercase()).as_deref(),
        Some("1") | Some("true") | Some("yes") | Some("on")
    )
}

/// Whether the Goose Work seam is armed (the env flag is set). Arming only opts in;
/// it does NOT wire an engine — the engine is the gated vendor.
pub fn is_armed() -> bool {
    flag_is_armed(std::env::var(WORK_GOOSE_FLAG).ok().as_deref())
}

/// The honest seam: run a Work session against the Goose engine for the given typed
/// `WorkRequest` (objective + the workspace roots it indexes / diffs + the default
/// permission posture — all real vendored/first-party types). Until the engine layer
/// is vendored, this is INERT — it returns `EngineNotWired` (NEVER a silent fallback
/// to Chat/Act). The real engine replaces this body and returns a `WorkResult`.
pub fn run_work_session(_request: &WorkRequest) -> Result<WorkResult, WorkError> {
    Err(WorkError::EngineNotWired)
}

/// FFI: the Work-seam status as JSON, for the Swift `WorkBackend` to read across the
/// UniFFI boundary. Honest — reports armed (the flag) + that the engine is not yet
/// wired. This is the first concrete UniFFI seam for the Goose Work extraction.
#[uniffi::export]
pub fn work_backend_status_json() -> String {
    format!(
        "{{\"armed\":{},\"engine_wired\":false,\"flag\":\"{}\"}}",
        is_armed(),
        WORK_GOOSE_FLAG
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn flag_parsing_is_honest() {
        assert!(flag_is_armed(Some("1")));
        assert!(flag_is_armed(Some(" On ")));
        assert!(flag_is_armed(Some("true")));
        assert!(!flag_is_armed(None));
        assert!(!flag_is_armed(Some("0")));
        assert!(!flag_is_armed(Some("")));
    }

    #[test]
    fn inert_seam_refuses_honestly_never_falls_back() {
        // No engine wired → honest EngineNotWired, NEVER a silent fallback to Chat/Act.
        let req = WorkRequest::read_only(
            "do a thing",
            vec![vendored_goose::SourceRoot::read_only(std::path::PathBuf::from("/tmp/ws"))],
        );
        assert_eq!(run_work_session(&req), Err(WorkError::EngineNotWired));
    }

    // (Removed: the `vendored_permission_*` test — the Goose permission leaf was dropped under
    // Architecture C; OpenCode owns work-engine permissioning.)

    #[test]
    fn vendored_message_role_wire_form_matches_upstream() {
        use vendored_goose::message::Role;
        // goose's `Message.role` is `rmcp::model::Role`, which is `#[serde(rename_all = "camelCase")]`
        // over User/Assistant (single-word camelCase = lowercase). Match the wire form byte-for-byte.
        assert_eq!(serde_json::to_string(&Role::User).unwrap(), "\"user\"");
        assert_eq!(serde_json::to_string(&Role::Assistant).unwrap(), "\"assistant\"");
        assert_eq!(serde_json::from_str::<Role>("\"user\"").unwrap(), Role::User);
        assert_eq!(serde_json::from_str::<Role>("\"assistant\"").unwrap(), Role::Assistant);
    }

    #[test]
    fn work_request_read_only_is_well_formed() {
        // Under Architecture C the Goose permission leaf is dropped (OpenCode owns work-engine
        // permissioning); the first-party request just carries the objective + roots + (empty)
        // parameters/settings/retry.
        let req = WorkRequest::read_only("x", vec![]);
        assert_eq!(req.objective, "x");
        assert!(req.source_roots.is_empty());
        assert!(req.parameters.is_empty());
        assert!(req.settings.is_none());
        assert!(req.retry.is_none());
    }

    #[test]
    fn vendored_goose_source_root_is_usable() {
        // The first vendored block/goose type compiles + behaves (read_only → !writable).
        let root = vendored_goose::SourceRoot::read_only(std::path::PathBuf::from("/repo"));
        assert_eq!(root.path, std::path::PathBuf::from("/repo"));
        assert!(!root.writable);
        assert_eq!(GOOSE_VENDOR_LICENSE, "Apache-2.0");
        assert_eq!(GOOSE_VENDOR_SOURCE, "block/goose");
    }

    #[test]
    fn status_json_reports_engine_not_wired() {
        let json = work_backend_status_json();
        assert!(json.contains("\"engine_wired\":false"));
        assert!(json.contains(WORK_GOOSE_FLAG));
    }

    #[test]
    fn vendored_recipe_parameter_wire_form_matches_upstream() {
        use vendored_goose::recipe::{
            RecipeParameter, RecipeParameterInputType, RecipeParameterRequirement,
        };
        // serde snake_case wire form is byte-identical to upstream (the derive is preserved).
        assert_eq!(
            serde_json::to_string(&RecipeParameterInputType::Boolean).unwrap(),
            "\"boolean\""
        );
        assert_eq!(
            serde_json::to_string(&RecipeParameterInputType::File).unwrap(),
            "\"file\""
        );
        assert_eq!(
            serde_json::to_string(&RecipeParameterRequirement::UserPrompt).unwrap(),
            "\"user_prompt\""
        );
        // RecipeParameter round-trips through serde unchanged; the optional fields keep
        // their upstream `skip_serializing_if = "Option::is_none"` behavior.
        let param = RecipeParameter {
            key: "target".to_string(),
            input_type: RecipeParameterInputType::Select,
            requirement: RecipeParameterRequirement::Required,
            description: "which target".to_string(),
            default: None,
            options: Some(vec!["a".to_string(), "b".to_string()]),
        };
        let json = serde_json::to_string(&param).unwrap();
        assert!(!json.contains("\"default\"")); // None is skipped
        assert!(json.contains("\"options\"")); // Some is present
        let back: RecipeParameter = serde_json::from_str(&json).unwrap();
        assert_eq!(back, param);
    }

    #[test]
    fn work_request_carries_typed_parameters() {
        use vendored_goose::recipe::{
            RecipeParameter, RecipeParameterInputType, RecipeParameterRequirement,
        };
        // A fresh read-only request declares NO parameters (empty by default).
        let mut req = WorkRequest::read_only("do a thing", vec![]);
        assert!(req.parameters.is_empty());
        // ...and can carry the vendored typed parameters the engine layer will consume.
        req.parameters.push(RecipeParameter {
            key: "path".to_string(),
            input_type: RecipeParameterInputType::File,
            requirement: RecipeParameterRequirement::Optional,
            description: "input file".to_string(),
            default: None,
            options: None,
        });
        assert_eq!(req.parameters.len(), 1);
        assert_eq!(req.parameters[0].key, "path");
        // Still inert — carrying parameters never wires an engine or falls back.
        assert_eq!(run_work_session(&req), Err(WorkError::EngineNotWired));
    }

    #[test]
    fn vendored_recipe_settings_round_trips() {
        use vendored_goose::recipe::Settings;
        // Upstream `skip_serializing_if` skips the None fields; the set ones round-trip.
        let settings = Settings {
            goose_provider: Some("anthropic".to_string()),
            goose_model: None,
            temperature: Some(0.2),
            max_turns: Some(8),
        };
        let json = serde_json::to_string(&settings).unwrap();
        assert!(!json.contains("goose_model")); // None skipped
        assert!(json.contains("goose_provider"));
        assert!(json.contains("temperature"));
        let back: Settings = serde_json::from_str(&json).unwrap();
        assert_eq!(back, settings);
    }

    #[test]
    fn work_request_carries_model_settings() {
        use vendored_goose::recipe::Settings;
        // A fresh request uses the engine's default settings (None).
        let mut req = WorkRequest::read_only("x", vec![]);
        assert!(req.settings.is_none());
        // ...and can declare the vendored model settings the engine layer will consume.
        req.settings = Some(Settings {
            goose_provider: Some("local".to_string()),
            goose_model: Some("gemma".to_string()),
            temperature: None,
            max_turns: Some(4),
        });
        assert_eq!(req.settings.as_ref().unwrap().goose_model.as_deref(), Some("gemma"));
        // Still inert — carrying settings never wires an engine or falls back.
        assert_eq!(run_work_session(&req), Err(WorkError::EngineNotWired));
    }

    #[test]
    fn vendored_retry_config_validate_matches_upstream() {
        use vendored_goose::retry::{RetryConfig, SuccessCheck};
        // Upstream rule set (block/goose agents/types.rs `validate()`): max_retries>0 and
        // any *specified* timeout>0. A valid config passes; each zero is rejected with the
        // EXACT upstream message (locks byte-faithful behaviour).
        let ok = RetryConfig {
            max_retries: 3,
            checks: vec![SuccessCheck::Shell { command: "cargo test".into() }],
            on_failure: None,
            timeout_seconds: Some(60),
            on_failure_timeout_seconds: Some(120),
        };
        assert!(ok.validate().is_ok());

        let zero_retries = RetryConfig { max_retries: 0, ..ok.clone() };
        assert_eq!(zero_retries.validate().unwrap_err(), "max_retries must be greater than 0");

        let zero_timeout = RetryConfig { timeout_seconds: Some(0), ..ok.clone() };
        assert_eq!(
            zero_timeout.validate().unwrap_err(),
            "timeout_seconds must be greater than 0 if specified"
        );

        let zero_onfail = RetryConfig { on_failure_timeout_seconds: Some(0), ..ok.clone() };
        assert_eq!(
            zero_onfail.validate().unwrap_err(),
            "on_failure_timeout_seconds must be greater than 0 if specified"
        );
    }

    #[test]
    fn vendored_retry_success_check_wire_form_matches_upstream() {
        use vendored_goose::retry::SuccessCheck;
        // Upstream serde: internally `tag = "type"` (so `{"type":"Shell","command":"…"}`),
        // with lowercase `"shell"` accepted as an alias on deserialize.
        let check = SuccessCheck::Shell { command: "pytest -q".into() };
        let json = serde_json::to_string(&check).unwrap();
        assert!(json.contains("\"type\":\"Shell\""));
        assert!(json.contains("\"command\":\"pytest -q\""));
        assert_eq!(serde_json::from_str::<SuccessCheck>(&json).unwrap(), check);
        let aliased: SuccessCheck =
            serde_json::from_str(r#"{"type":"shell","command":"pytest -q"}"#).unwrap();
        assert_eq!(aliased, check);
    }

    #[test]
    fn vendored_retry_config_round_trips_and_skips_none() {
        use vendored_goose::retry::{
            RetryConfig, SuccessCheck, DEFAULT_ON_FAILURE_TIMEOUT_SECONDS,
            DEFAULT_RETRY_TIMEOUT_SECONDS,
        };
        // The upstream default-timeout constants are preserved verbatim.
        assert_eq!(DEFAULT_RETRY_TIMEOUT_SECONDS, 300);
        assert_eq!(DEFAULT_ON_FAILURE_TIMEOUT_SECONDS, 600);
        let cfg = RetryConfig {
            max_retries: 2,
            checks: vec![SuccessCheck::Shell { command: "make check".into() }],
            on_failure: None,
            timeout_seconds: None,
            on_failure_timeout_seconds: None,
        };
        let json = serde_json::to_string(&cfg).unwrap();
        // `skip_serializing_if = "Option::is_none"` drops the unset fields.
        assert!(!json.contains("on_failure"));
        assert!(!json.contains("timeout_seconds"));
        let back: RetryConfig = serde_json::from_str(&json).unwrap();
        assert_eq!(back, cfg);
    }

    #[test]
    fn work_request_carries_retry_policy() {
        use vendored_goose::retry::{RetryConfig, SuccessCheck};
        // A fresh request has no automated retry.
        let mut req = WorkRequest::read_only("fix the failing tests", vec![]);
        assert!(req.retry.is_none());
        // ...and can carry the deterministic self-correction policy the engine layer runs.
        req.retry = Some(RetryConfig {
            max_retries: 3,
            checks: vec![SuccessCheck::Shell { command: "cargo test".into() }],
            on_failure: Some("git checkout .".into()),
            timeout_seconds: Some(300),
            on_failure_timeout_seconds: None,
        });
        assert!(req.retry.as_ref().unwrap().validate().is_ok());
        assert_eq!(req.retry.as_ref().unwrap().max_retries, 3);
        // Still inert — carrying a retry policy never wires an engine or falls back.
        assert_eq!(run_work_session(&req), Err(WorkError::EngineNotWired));
    }

    fn retry_cfg(max_retries: u32, on_failure: Option<&str>) -> vendored_goose::retry::RetryConfig {
        vendored_goose::retry::RetryConfig {
            max_retries,
            checks: vec![],
            on_failure: on_failure.map(|s| s.to_string()),
            timeout_seconds: None,
            on_failure_timeout_seconds: None,
        }
    }

    #[test]
    fn retry_manager_skips_without_config() {
        // Upstream: no retry_config → Skipped (no counter movement, no cleanup).
        let mut mgr = RetryManager::new();
        let mut cleanups = 0u32;
        assert_eq!(mgr.evaluate(None, false, |_| cleanups += 1), RetryResult::Skipped);
        assert_eq!(mgr.attempts(), 0);
        assert_eq!(cleanups, 0);
    }

    #[test]
    fn retry_manager_success_short_circuits_without_cleanup() {
        // checks passed → SuccessChecksPassed, never increments, never runs on_failure.
        let cfg = retry_cfg(2, Some("cleanup"));
        let mut mgr = RetryManager::new();
        let mut cleanups = 0u32;
        assert_eq!(
            mgr.evaluate(Some(&cfg), true, |_| cleanups += 1),
            RetryResult::SuccessChecksPassed
        );
        assert_eq!(mgr.attempts(), 0);
        assert_eq!(cleanups, 0);
    }

    #[test]
    fn retry_manager_retries_and_runs_on_failure_when_attempts_remain() {
        // attempts(0) < max(2) + checks failed → Retried, increment to 1, on_failure ran.
        let cfg = retry_cfg(2, Some("git checkout ."));
        let mut mgr = RetryManager::new();
        let mut cleanups: Vec<String> = vec![];
        assert_eq!(
            mgr.evaluate(Some(&cfg), false, |c| cleanups.push(c.to_string())),
            RetryResult::Retried
        );
        assert_eq!(mgr.attempts(), 1);
        assert_eq!(cleanups, vec!["git checkout .".to_string()]);
    }

    #[test]
    fn retry_manager_stops_at_max_attempts_without_cleanup_or_increment() {
        // max_retries = 1: one retry, then the next failure is MaxAttemptsReached.
        let cfg = retry_cfg(1, Some("cleanup"));
        let mut mgr = RetryManager::new();
        let mut cleanups = 0u32;
        assert_eq!(mgr.evaluate(Some(&cfg), false, |_| cleanups += 1), RetryResult::Retried);
        assert_eq!(mgr.attempts(), 1);
        // 1 >= 1 → MaxAttemptsReached: NO further increment, NO cleanup.
        assert_eq!(
            mgr.evaluate(Some(&cfg), false, |_| cleanups += 1),
            RetryResult::MaxAttemptsReached
        );
        assert_eq!(mgr.attempts(), 1);
        assert_eq!(cleanups, 1); // only the single retry ran cleanup
    }

    #[test]
    fn retry_manager_drives_a_full_self_correction_loop_then_succeeds() {
        // fail, fail, then pass → Retried, Retried, SuccessChecksPassed (2 retries used).
        let cfg = retry_cfg(3, None);
        let mut mgr = RetryManager::new();
        assert_eq!(mgr.evaluate(Some(&cfg), false, |_| {}), RetryResult::Retried);
        assert_eq!(mgr.evaluate(Some(&cfg), false, |_| {}), RetryResult::Retried);
        assert_eq!(mgr.evaluate(Some(&cfg), true, |_| {}), RetryResult::SuccessChecksPassed);
        assert_eq!(mgr.attempts(), 2);
        // reset clears the counter for the next Work session.
        mgr.reset();
        assert_eq!(mgr.attempts(), 0);
    }

    struct MockExec {
        check_result: bool,
        checks_ran: u32,
        cleanups: Vec<String>,
    }
    impl MockExec {
        fn new(check_result: bool) -> Self {
            Self { check_result, checks_ran: 0, cleanups: vec![] }
        }
    }
    impl RetryExecutor for MockExec {
        fn run_success_checks(
            &mut self,
            _checks: &[vendored_goose::retry::SuccessCheck],
            _timeout_seconds: Option<u64>,
        ) -> bool {
            self.checks_ran += 1;
            self.check_result
        }
        fn run_on_failure(&mut self, command: &str, _timeout_seconds: Option<u64>) {
            self.cleanups.push(command.to_string());
        }
    }

    #[test]
    fn run_shell_with_timeout_kills_a_hung_command() {
        use std::time::Instant;
        // A command that would hang for 30s is KILLED at the 1s bound and reported as failed — fast.
        let start = Instant::now();
        let ok = run_shell_with_timeout("sleep 30", Some(1));
        let elapsed = start.elapsed();
        assert!(!ok, "a timed-out command must count as failed");
        assert!(elapsed.as_secs() < 5, "must kill near the deadline, took {elapsed:?}");
    }

    #[test]
    fn run_shell_with_timeout_runs_fast_commands() {
        assert!(run_shell_with_timeout("true", Some(5)), "exit 0 → success");
        assert!(!run_shell_with_timeout("false", Some(5)), "exit 1 → failure");
        // No bound → blocking wait still works (historical behavior preserved).
        assert!(run_shell_with_timeout("true", None));
    }

    #[test]
    fn drive_retry_cycle_succeeds_when_checks_pass() {
        let cfg = retry_cfg(2, Some("cleanup"));
        let mut mgr = RetryManager::new();
        let mut exec = MockExec::new(true);
        assert_eq!(
            drive_retry_cycle(&mut mgr, Some(&cfg), &mut exec),
            RetryResult::SuccessChecksPassed
        );
        assert_eq!(exec.checks_ran, 1);
        assert!(exec.cleanups.is_empty());
        assert_eq!(mgr.attempts(), 0);
    }

    #[test]
    fn drive_retry_cycle_retries_and_runs_cleanup_when_checks_fail() {
        let cfg = retry_cfg(2, Some("git checkout ."));
        let mut mgr = RetryManager::new();
        let mut exec = MockExec::new(false);
        assert_eq!(
            drive_retry_cycle(&mut mgr, Some(&cfg), &mut exec),
            RetryResult::Retried
        );
        assert_eq!(exec.checks_ran, 1);
        assert_eq!(exec.cleanups, vec!["git checkout .".to_string()]);
        assert_eq!(mgr.attempts(), 1);
    }

    #[test]
    fn drive_retry_cycle_stops_at_max_without_cleanup() {
        let cfg = retry_cfg(1, Some("cleanup"));
        let mut mgr = RetryManager::new();
        let mut exec = MockExec::new(false);
        // First failed cycle retries (attempts → 1, one cleanup).
        assert_eq!(drive_retry_cycle(&mut mgr, Some(&cfg), &mut exec), RetryResult::Retried);
        // Second: 1 >= max(1) → MaxAttemptsReached, NO further cleanup or increment.
        assert_eq!(
            drive_retry_cycle(&mut mgr, Some(&cfg), &mut exec),
            RetryResult::MaxAttemptsReached
        );
        assert_eq!(exec.cleanups.len(), 1);
        assert_eq!(mgr.attempts(), 1);
    }

    #[test]
    fn drive_retry_cycle_skips_without_config_and_never_runs_checks() {
        let mut mgr = RetryManager::new();
        let mut exec = MockExec::new(false);
        assert_eq!(drive_retry_cycle(&mut mgr, None, &mut exec), RetryResult::Skipped);
        assert_eq!(exec.checks_ran, 0); // no config → checks never run
        assert!(exec.cleanups.is_empty());
    }

    #[cfg(feature = "pro-build")]
    #[test]
    fn shell_retry_executor_runs_real_hardened_checks() {
        use vendored_goose::retry::SuccessCheck;
        let mut exec = ShellRetryExecutor;
        // `true` exits 0 → check passes; `false` exits 1 → fails (real hardened subprocess).
        assert!(exec.run_success_checks(&[SuccessCheck::Shell { command: "true".into() }], None));
        assert!(!exec.run_success_checks(&[SuccessCheck::Shell { command: "false".into() }], None));
        // ALL-must-pass: one failing check fails the whole set.
        assert!(!exec.run_success_checks(&[
            SuccessCheck::Shell { command: "true".into() },
            SuccessCheck::Shell { command: "false".into() },
        ], None));
        // An empty check list trivially passes; on_failure is best-effort + never panics.
        assert!(exec.run_success_checks(&[], None));
        exec.run_on_failure("true", None);
    }

    #[test]
    fn repetition_guard_blocks_consecutive_repeats() {
        let mut guard = RepetitionGuard::new(Some(2));
        let args = serde_json::json!({"path": "a"});
        assert!(guard.check("read", &args)); // 1st
        assert!(guard.check("read", &args)); // 2nd (repeat_count 2, not > 2)
        assert!(!guard.check("read", &args)); // 3rd consecutive identical → blocked
    }

    #[test]
    fn repetition_guard_resets_on_a_different_call() {
        let mut guard = RepetitionGuard::new(Some(1));
        let a = serde_json::json!({"x": 1});
        let b = serde_json::json!({"y": 2});
        assert!(guard.check("read", &a)); // rc=1
        assert!(!guard.check("read", &a)); // rc=2 > 1 → blocked
        assert!(guard.check("write", &b)); // a different call resets the streak → allowed
    }

    #[test]
    fn repetition_guard_none_never_blocks_but_counts() {
        let mut guard = RepetitionGuard::new(None);
        let args = serde_json::json!({});
        for _ in 0..50 {
            assert!(guard.check("loop", &args));
        }
        assert_eq!(guard.call_count("loop"), 50);
        assert_eq!(guard.call_count("never"), 0);
    }

    #[test]
    fn repetition_guard_args_distinguish_calls() {
        let mut guard = RepetitionGuard::new(Some(1));
        assert!(guard.check("read", &serde_json::json!({"f": "a"})));
        // same name, DIFFERENT args → not a consecutive repeat → allowed
        assert!(guard.check("read", &serde_json::json!({"f": "b"})));
        // now the b-args repeats → blocked (rc=2 > 1)
        assert!(!guard.check("read", &serde_json::json!({"f": "b"})));
    }

    #[test]
    fn repetition_guard_reset_clears_state() {
        let mut guard = RepetitionGuard::new(Some(1));
        let args = serde_json::json!({});
        assert!(guard.check("read", &args));
        assert!(!guard.check("read", &args)); // blocked
        guard.reset();
        assert_eq!(guard.call_count("read"), 0);
        assert!(guard.check("read", &args)); // fresh again after reset
    }
}
