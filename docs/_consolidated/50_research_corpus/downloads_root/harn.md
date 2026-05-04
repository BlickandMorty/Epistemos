# Meta-Harness → Epistemos: Implementation-Grade Integration Architecture

**A production blueprint for embedding harness evolution into a Swift + Rust + macOS AI app**

***

## 1. Executive Verdict

**Is Meta-Harness beneficial for Epistemos?**
Yes — but in a specific, bounded form. The paper's deepest contribution is not the outer optimization loop; it is the discovery that **full trace access beats compressed summaries by an enormous margin** — a 50.0 vs 34.6 median accuracy, on the same proposer budget, from raw filesystem access vs. scores-only. That insight is portable to any system that logs agent runs. The loop that drives improvement from those traces is powerful, but requires scored task suites and infrastructure that Epistemos should build toward, not start with.

**In what form?**
A two-layer adoption:
- **Layer 1 (immediately actionable):** Implement the environment bootstrap packet, full JSONL trace logging, and the Anthropic initializer+coding agent pattern. These require no scored task suite and no proposer loop — they make the agent immediately better.
- **Layer 2 (build toward):** A developer-only Harness Lab that stores traces, hosts task suites, and eventually runs a proposer (Claude Code) against the full trace history to propose harness edits. This is infrastructure for self-improvement that becomes valuable as the task suite matures.

**What is the highest-ROI way to adopt it?**
In ranked order:
1. **Environment bootstrap packet** — eliminates 2–4 wasted turns per task, zero new infrastructure
2. **JSONL trace logging** — makes everything else possible; the foundation of the flywheel
3. **Feature list / task decomposition** (JSON) — prevents false completion, preserves multi-session continuity
4. **Progress file + session handoff** — enables context continuity across Foundation Models session recycles
5. **Harness Lab trace store** — offline repository for later proposer-driven improvement
6. **Proposer loop** — when you have 10+ hand-curated tasks and enough traces to diagnose failures

***

## 2. What Meta-Harness Actually Is

### The Core Intellectual Contribution

Meta-Harness is an **outer-loop harness optimizer** built on a single key insight: harness engineering failures have long causal chains that cannot be diagnosed from scalar scores or summaries — they require raw execution traces. The method is:

1. Initialize a candidate population from existing strong harnesses
2. Run each candidate against a scored task set, log **full execution traces** to a filesystem
3. Let a coding agent (Claude Code) read the filesystem — source code, scores, traces — via `grep` and `cat`
4. The agent proposes a new candidate harness by reasoning over prior failures
5. Repeat

The proposer reads a median of 82 files per iteration, split roughly equally between source code (41%) and raw traces (40%). The non-Markovian access pattern — inspecting majority of history rather than just recent candidates — is what separates it from all prior text optimizers. Every other method (OPRO, TextGrad, AlphaEvolve, GEPA) compresses feedback to 0.002–0.026 MTok/iter. Meta-Harness uses 10 MTok/iter.

**Ablation results confirm that raw traces are the key ingredient:**

| Proposer input | Median accuracy | Best accuracy |
|---|---|---|
| Scores only | 34.6 | 41.3 |
| Scores + summary | 34.9 | 38.7 |
| Full traces (Meta-Harness) | **50.0** | **56.7** |

Summaries hurt — they remove diagnostically relevant detail. The raw trace is what enables causal reasoning.

**The discovery that directly applies to Epistemos:** In the TerminalBench-2 run, the winning harness improvement (iteration 7 after 6 regressions) was not a structural change — it was adding an **environment bootstrap packet** that gathered system state before the agent's first turn, eliminating the 2–4 exploratory turns agents typically spend discovering what tools and files are available.

### What Is Benchmark-Specific Scaffolding (Do Not Import)

| Component | Why it stays | Epistemos alternative |
|---|---|---|
| Docker container execution | Harbor/TerminalBench-specific | Native macOS subprocess with entitlements |
| Python single-file harness format | Terminus-KIRA convention | Swift actor-based harness |
| Binary pass/fail on 89 tasks | TerminalBench-2 specific | Multi-level rubric scoring |
| 60 harness / 20 iteration budget | Tuned for benchmark contest | Start with 10 tasks / 5 iterations |
| Cryptanalysis / bioinformatics tasks | Terminal benchmark specific | Coding / research / note-synthesis |
| Pareto frontier logic | Multi-objective only needed for accuracy/token tradeoffs | Optional later |

### What Is Portable (Core Design Patterns)

1. **Filesystem-as-memory for the proposer** — structure agent history so a coding agent can navigate it with grep/cat
2. **Full traces beat summaries** — JSONL per task, never compress before proposer access
3. **Environment bootstrap packet** — snapshot system state before first agent turn
4. **Code-space search** — modify harness code (system prompts, tool definitions, retrieval logic, completion checkers), not just prompt text
5. **No imposed search structure** — give the proposer filesystem access and let it decide what to read
6. **Causal diagnosis over prior runs** — the proposer can identify confounded edits only by comparing raw traces from multiple runs
7. **Initializer + coding agent split** — different prompts for first session vs. continuations

***

## 3. Best Architecture for Epistemos

```
╔═══════════════════════════════════════════════════════════════════╗
║  PRODUCTION RUNTIME                                               ║
║  ┌─────────────────────────────────────────────────────────────┐  ║
║  │ Active Harness (versioned, promoted)                        │  ║
║  │ - SystemPromptStore (per domain: coding/research/terminal)  │  ║
║  │ - ToolPolicyStore (tool definitions, activation rules)      │  ║
║  │ - CompletionChecker (per task type)                         │  ║
║  │ - BootstrapPacketBuilder (assembles before first turn)      │  ║
║  │ - ProgressStore (progress.json + session handoff files)     │  ║
║  └──────────────────────┬──────────────────────────────────────┘  ║
║                         │ writes traces during runs               ║
╚═════════════════════════╪═════════════════════════════════════════╝
                          ▼
╔═══════════════════════════════════════════════════════════════════╗
║  TRACE COLLECTION LAYER                                           ║
║  ┌─────────────────────────────────────────────────────────────┐  ║
║  │ TraceCollector actor                                        │  ║
║  │ - Non-blocking JSONL append                                 │  ║
║  │ - Per-task trace file                                       │  ║
║  │ - Environment packet snapshot                               │  ║
║  │ - Outcome + completion decision                             │  ║
║  └──────────────────────┬──────────────────────────────────────┘  ║
║                         │                                          ║
╚═════════════════════════╪═════════════════════════════════════════╝
                          ▼
╔═══════════════════════════════════════════════════════════════════╗
║  HARNESS LAB (developer-only, internal R&D subsystem)            ║
║  ┌─────────────────────────────────────────────────────────────┐  ║
║  │ HarnessRegistry — versioned harness definitions             │  ║
║  │ TaskSuite — task instances + expected outcomes              │  ║
║  │ TraceStore — indexed JSONL trace corpus                     │  ║
║  │ EvaluationRunner — runs candidate vs task suite             │  ║
║  │ ProposerOrchestrator — invokes Claude Code with FS access   │  ║
║  │ PromotionPipeline — diff + review + regression + promote    │  ║
║  └─────────────────────────────────────────────────────────────┘  ║
╚═══════════════════════════════════════════════════════════════════╝
```

### Production Runtime Harness

The production harness is the versioned, promoted configuration that agents execute against in the live app. It consists of:
- **SystemPromptStore:** Domain-partitioned system prompts (coding, research, terminal, note-synthesis), versioned as plain Swift files or JSON templates stored in the app bundle but overridable from `~/Library/Application Support/Epistemos/harness/`
- **ToolPolicyStore:** Which tools are active for which task types, tool definition text, tool activation heuristics
- **BootstrapPacketBuilder:** Assembles the environment snapshot before the agent's first turn (detailed in Section 7)
- **CompletionChecker:** Per-task-type done verification (detailed in Section 8)
- **ProgressStore:** Reads/writes `epistemos-progress.json` for session continuity across FoundationModels session recycles

### Harness Lab (Internal R&D Subsystem)

The Harness Lab is a **developer-only** subsystem, not a user-facing feature. It runs offline, is not on the hot path, and requires explicit developer invocation. It consists of:
- **HarnessRegistry:** Stores harness versions as directories (`candidate_001/`, `candidate_002/`), each containing harness definition files and a `metadata.json` with scores and ancestry
- **TaskSuite:** A curated set of tasks with expected outcomes, split into search set (used during optimization) and held-out test set (used only at promotion decision)
- **TraceStore:** The filesystem-based corpus of JSONL traces from production runs and evaluation runs; structured for grep/cat access
- **EvaluationRunner:** Spawns an isolated subprocess to run a candidate harness against the task suite; writes results back to the registry
- **ProposerOrchestrator:** Invokes Claude Code (or another coding agent) as a subprocess with a minimal skill prompt pointing it at the TraceStore and HarnessRegistry
- **PromotionPipeline:** Diffs candidate vs. current production harness, runs regression check on test set, requires human approval, atomically swaps production harness

### Replay / Eval Subsystem

The replay engine enables running any prior task against any candidate harness version for regression testing:
```
replay(taskId: String, harnessVersion: String) -> EvalResult
```
This calls `EvaluationRunner` with fixed seeds (deterministic environment) and logs a new trace file. The `EvalResult` includes: pass/fail, score, trace path, delta from baseline.

### Promotion Pipeline (Human-in-the-Loop)

```
Candidate harness
    │
    ▼
EvaluationRunner (search set)
    │
    ├── Regression check: no task degrades by >10%?
    │       └── fail → reject candidate
    ▼
EvaluationRunner (test set, held-out)
    │
    ├── Improvement check: average score improves by >5%?
    │       └── fail → reject candidate
    ▼
HarnessLabUI diff view (developer reviews code changes)
    │
    ├── Review → approve/reject
    │       └── reject → back to search
    ▼
PromotionPipeline.promote(candidateId)
    │
    └── Atomically replaces production harness files
        Writes promotion event to harness audit log
```

***

## 4. What to Build First

### Minimum Viable Integration (This Month)

These five changes require no scored task suite, no proposer loop, no new infrastructure — just disciplined implementation:

**1. `BootstrapPacketBuilder` (highest ROI, lowest cost)**
Build a Swift struct that assembles a pre-task context snapshot. Target: 800–1200 tokens. Inject at the top of the first turn's system context. This alone eliminates the 2–4 "what environment am I in?" turns that plague every agent task.

**2. JSONL trace logging via `TraceCollector` actor**
Non-blocking append of every tool call, model output, and state update to a per-task JSONL file. This is the foundation that makes everything else possible. Without traces, you cannot improve the harness. Traces also serve as the primary debugging tool for agent failures.

**3. `epistemos-progress.json` session handoff**
Write a structured JSON file at the end of every agent session describing: what was accomplished, what failed, what the next session should focus on, current task list state. Read this at the start of every new session (including after FoundationModels session recycles). This directly solves the context continuity problem.

**4. Task decomposition in JSON (not Markdown)**
When an agent is given a multi-step task, have the initializer phase write a `features.json` / `tasks.json` with `{ "description": "...", "passes": false }` entries. Mark entries `true` only after explicit verification. Use Anthropic's finding that JSON is more resistant to accidental model overwriting than Markdown.

**5. Initializer / coding agent prompt split**
For multi-session tasks, use a different system prompt for the first session (initializer: sets up structure, writes progress file, creates task list) vs. subsequent sessions (coding agent: reads progress, picks one task, verifies before marking done, commits checkpoint). This is the most impactful structural change Anthropic discovered for long-running agents.

### Fastest Path to Value

```
Week 1: BootstrapPacketBuilder + TraceCollector actor (zero infrastructure)
Week 2: epistemos-progress.json + initializer/coding split
Week 3: Task decomposition JSON pattern
Week 4: Basic TraceStore on disk (structured filesystem, no proposer yet)
```

### Safest Path to Value

The safest adoption sequence adds one gate: never modify production harness without human review. Build the Harness Lab as read-only first — only store and inspect traces. Only run proposer experiments on the dev/staging machine, never on the user's machine. Only promote changes via a deliberate developer action in the Harness Lab UI.

***

## 5. Detailed Implementation Blueprint

### Filesystem Layout

```
~/Library/Application Support/Epistemos/
├── harness/
│   ├── production/
│   │   ├── v1.0.0/
│   │   │   ├── system_prompts/
│   │   │   │   ├── coding.md
│   │   │   │   ├── research.md
│   │   │   │   ├── terminal.md
│   │   │   │   └── note_synthesis.md
│   │   │   ├── tool_policies/
│   │   │   │   ├── coding.json
│   │   │   │   └── research.json
│   │   │   ├── completion_checkers/
│   │   │   │   ├── coding.json
│   │   │   │   └── research.json
│   │   │   └── metadata.json    # version, promoted_at, promoted_by, scores
│   │   └── current -> v1.0.0/  # symlink
│   └── lab/                     # developer-only
│       ├── candidates/
│       │   ├── candidate_001/
│       │   │   ├── harness/ (same structure as production/v1.0.0/)
│       │   │   ├── scores.json
│       │   │   └── ancestry.json   # parent candidate IDs
│       │   ├── candidate_002/
│       │   └── ...
│       ├── task_suite/
│       │   ├── search/              # 10-20 tasks
│       │   │   ├── task_001.json
│       │   │   └── ...
│       │   └── held_out/            # 5-10 tasks, never seen by proposer
│       │       └── ...
│       ├── pareto_frontier.json
│       └── search_log.jsonl         # iteration-by-iteration search history
├── traces/
│   ├── production/
│   │   ├── 2026-04-01/
│   │   │   ├── task_abc123.jsonl
│   │   │   └── task_def456.jsonl
│   │   └── ...
│   └── evaluation/
│       ├── candidate_001/
│       │   ├── task_001.jsonl
│       │   └── ...
│       └── ...
└── sessions/
    ├── session_xyz789/
    │   ├── bootstrap_packet.json
    │   ├── features.json
    │   ├── progress.json
    │   └── artifacts/           # diffs, outputs, files created
    └── ...
```

### JSONL Trace Format

Each line is one structured event:

```jsonc
// Tool call event
{"ts": "2026-04-01T12:00:01Z", "type": "tool_call", "session_id": "xyz", 
 "task_id": "abc123", "harness_version": "v1.0.0", "turn": 3,
 "tool": "bash", "input": "cargo test --workspace", "duration_ms": 1420,
 "output": "running 48 tests\n...\ntest result: ok", "exit_code": 0}

// Model output event
{"ts": "2026-04-01T12:00:02Z", "type": "model_output", "session_id": "xyz",
 "task_id": "abc123", "turn": 3, "provider": "cloud",
 "tokens_used": 847, "completion_id": "cmpl_abc",
 "content": "The tests pass. Marking feature #3 as complete."}

// Completion decision event
{"ts": "2026-04-01T12:00:05Z", "type": "completion_check", 
 "session_id": "xyz", "task_id": "abc123",
 "checker": "coding", "method": "test_runner",
 "passed": true, "evidence": "48/48 tests pass, smoke test OK"}

// Session handoff event
{"ts": "2026-04-01T12:00:10Z", "type": "session_handoff",
 "session_id": "xyz", "task_id": "abc123",
 "completed_features": ["f001", "f003"],
 "next_priority": "f002",
 "context_summary": "...",
 "git_commit": "a3f9b2c"}
```

### TraceCollector Actor (Swift)

```swift
actor TraceCollector {
    private let baseDir: URL
    private var fileHandles: [String: FileHandle] = [:]
    
    init(baseDir: URL) {
        self.baseDir = baseDir
    }
    
    // Non-blocking: caller does not await, fire-and-forget
    nonisolated func record(_ event: TraceEvent) {
        Task {
            await _record(event)
        }
    }
    
    private func _record(_ event: TraceEvent) {
        let taskId = event.taskId
        let handle = fileHandle(for: taskId)
        guard let line = try? JSONEncoder().encode(event),
              let newline = "\n".data(using: .utf8) else { return }
        handle.write(line)
        handle.write(newline)
    }
    
    private func fileHandle(for taskId: String) -> FileHandle {
        if let existing = fileHandles[taskId] { return existing }
        let dateDir = ISO8601DateFormatter.string(from: Date(), 
            timeZone: .current, formatOptions: .withFullDate)
        let dir = baseDir.appending(path: "traces/production/\(dateDir)")
        try? FileManager.default.createDirectory(at: dir, 
            withIntermediateDirectories: true)
        let path = dir.appending(path: "\(taskId).jsonl")
        FileManager.default.createFile(atPath: path.path, contents: nil)
        let handle = try! FileHandle(forWritingTo: path)
        handle.seekToEndOfFile()
        fileHandles[taskId] = handle
        return handle
    }
    
    func closeAll() {
        fileHandles.values.forEach { try? $0.close() }
        fileHandles.removeAll()
    }
}
```

### ProposerOrchestrator (Swift)

```swift
actor ProposerOrchestrator {
    private let harnessLabDir: URL
    private let traceDir: URL
    
    // Skill prompt tells Claude Code where to look — minimal instruction
    private let skillPrompt = """
    You are optimizing the Epistemos agent harness.
    
    Harness Lab structure:
    - Candidate harnesses: \(harnessLabDir.path)/candidates/
    - Execution traces: \(traceDir.path)/
    - Current best harness: \(harnessLabDir.path)/pareto_frontier.json
    - Search log: \(harnessLabDir.path)/search_log.jsonl
    
    Your task:
    1. Inspect prior candidates and their traces via grep/cat
    2. Identify the most important failure modes
    3. Propose a new candidate harness by writing to candidates/candidate_NNN/
    4. Document your reasoning in candidates/candidate_NNN/proposal.md
    
    Rules:
    - Do NOT modify the held_out task suite
    - Do NOT modify production harness (harness/production/)
    - Do NOT read or hardcode specific task answers
    - Write harness changes as Swift template files or JSON configs only
    """
    
    func runProposalIteration(iterationN: Int) async throws {
        // Invoke Claude Code subprocess with filesystem access to lab dir
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/claude")
        process.arguments = [
            "--allowedTools", "bash,Read,Write,Edit,Glob,Grep",
            "--permission-prompt-tool", "bash",
            "-p", skillPrompt
        ]
        process.currentDirectoryURL = harnessLabDir
        
        // Capture and log output
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        // Log the iteration
        appendSearchLog(iteration: iterationN, 
                        exitCode: process.terminationStatus)
    }
    
    private func appendSearchLog(iteration: Int, exitCode: Int32) {
        let entry = SearchLogEntry(
            ts: ISO8601DateFormatter().string(from: Date()),
            iteration: iteration,
            exitCode: exitCode
        )
        // Append to search_log.jsonl
    }
}
```

***

## 6. Swift / Rust / macOS Implementation Strategy

### What Swift Owns

Swift actors are the right coordination layer for anything that needs to integrate with the app lifecycle, UI, and async Swift concurrency:

| Component | Type | Reason |
|---|---|---|
| `TraceCollector` | actor | Non-blocking write, lifecycle-bound to app |
| `BootstrapPacketBuilder` | struct + async func | Fast, stateless, data from multiple actors |
| `HarnessRegistry` | actor | Versioned state, serialization |
| `EvaluationRunner` | actor | Subprocess lifecycle, cancellation |
| `ProposerOrchestrator` | actor | Long-running subprocess management |
| `PromotionPipeline` | actor | Atomic state transition, audit log |
| `CompletionChecker` | protocol + implementations | Pluggable per task type |
| `ProgressStore` | struct | Simple JSON read/write |

### What Rust Owns

Rust is the right layer for performance-sensitive indexing and computation that doesn't need to be main-thread-friendly:

| Component | Interface | Reason |
|---|---|---|
| Trace file indexer | `#[uniffi::export]` | Fast grep over large JSONL corpus |
| Semantic search embedder | `#[uniffi::export]` | CPU-intensive, benefits from Rust perf |
| Trace compressor | Internal | ZSTD compression for old traces |
| Fast JSONL parser | Internal | High-throughput trace replay |

### UniFFI Boundaries

```rust
// trace_search: grep-equivalent over the full trace corpus
#[uniffi::export]
pub fn trace_search(
    trace_dir: String,
    query: String,
    max_results: u32,
) -> Result<Vec<TraceMatch>, TraceError>;

// compute_embedding: for semantic similarity search over traces
#[uniffi::export]  
pub fn compute_embedding(text: String) -> Result<Vec<f32>, EmbedError>;

// index_traces: pre-index a directory of JSONL files for fast search
#[uniffi::export]
pub fn index_traces(trace_dir: String) -> Result<IndexStats, TraceError>;
```

### Subprocess Isolation for Candidate Harnesses

Candidate harnesses in the Harness Lab run in an isolated subprocess using `Process` with restricted entitlements. This prevents a buggy candidate harness from affecting the production app state:

```swift
// EvaluationRunner: isolated subprocess per candidate
let evalProcess = Process()
evalProcess.executableURL = epistemosEvalBinaryURL  // separate binary
evalProcess.arguments = [
    "--harness", candidateDir.path,
    "--task-suite", taskSuiteDir.path,
    "--output", resultDir.path
]
// No sandbox inheritance from main app process
```

The eval binary is a minimal Swift executable that loads the candidate harness, runs tasks, and writes results. It has no access to the user's vault, notes, or production services.

### Local vs. Cloud Model Routing in Harness Lab

- **Proposer loop (Claude Code):** Always cloud — requires frontier coding model capability
- **Candidate harness evaluation:** Uses the same routing as production (local MLX or cloud based on capability tokens and thermal state)
- **LLM-as-judge scoring:** Can use FoundationModels locally for simple rubrics, cloud for complex rubrics
- **Bootstrap packet assembly:** Local only — reads filesystem, no model call

***

## 7. Environment Bootstrap Packet Design

### Exact Fields

```swift
struct BootstrapPacket: Codable, Sendable {
    // ── WORKSPACE ──────────────────────────────────────────────────
    let workingDirectory: String          // pwd — canonical path
    let projectName: String?              // name of Swift pkg / Cargo workspace
    let fileTreeSummary: String           // depth-2 tree, max 50 entries, exclude .build .git
    let openFiles: [String]               // currently visible in editor, max 5
    
    // ── TASK CONTEXT ────────────────────────────────────────────────
    let taskType: TaskType                // .coding | .research | .terminal | .noteSynthesis
    let taskObjective: String             // high-level goal
    let sessionNumber: Int               // 1 = first, >1 = continuation
    let progressSummary: String?         // nil on session 1; from progress.json on continuations
    let pendingTaskCount: Int?           // from features.json
    
    // ── TOOL AVAILABILITY ──────────────────────────────────────────
    let availableTools: [String]         // active MCP tools / tool names
    let activeCapability: Capability     // .cloud | .local | .readOnly
    
    // ── RUNTIME ENVIRONMENT ────────────────────────────────────────
    let languageRuntimes: [RuntimeInfo]  // swift, cargo, node, python versions if present
    let packageManagers: [String]        // detected: spm, cargo, npm, pip
    let repoState: RepoState?           // branch, last commit hash, uncommitted changes count
    
    // ── VAULT CONTEXT ──────────────────────────────────────────────
    let activeVault: String?            // vault name if open
    let relevantDocumentSummaries: [String]?  // top-3 relevant notes, 50 words each
    
    // ── RESOURCE STATE ─────────────────────────────────────────────
    let thermalLevel: ThermalLevel      // .nominal | .fair | .serious | .critical
    let localModelAvailable: Bool
    let availableMemoryGB: Double
    
    // ── HARNESS VERSION ────────────────────────────────────────────
    let harnessVersion: String          // "v1.0.0" — for trace correlation
}
```

### Refresh Rules

| Trigger | Action |
|---|---|
| Task starts | Build fresh packet (always) |
| Session recycles (Foundation Models) | Rebuild packet + read progress.json |
| Thermal state changes | Update `thermalLevel` field in current packet |
| Never | During a running task turn (stability > freshness within a task) |

### Token Budget Guidance

Target: **800–1,200 tokens** for the full packet. The file tree summary is the highest-risk field for blowout — enforce a hard cap of 50 entries at depth 2, filtering out build artifacts, `.git`, `.build`, `DerivedData`. The relevant document summaries are capped at 50 words each, max 3 documents. If vault context would push the packet over 1,500 tokens, omit it.

The packet is injected as the first block of the system prompt for session 1, or prepended to the user turn for session N.

### Failure Modes to Prevent

- **Stale tree after file creation:** Rebuild at task start, not at app launch
- **Leaked credentials in env dump:** Never include `env` vars, API keys, or keychain references
- **Vault context noise:** Only include documents with >0.7 cosine similarity to the task objective
- **Thermal false positives:** Only report `serious`/`critical` — `nominal` and `fair` are silent
- **Too-long progress summary:** Cap at 300 tokens; LLM-summarize if longer

***

## 8. Completion-Check Design

### The Core Anti-Pattern: Visual Completion

The most dangerous failure mode in agents is declaring a task complete based on visual inspection of code rather than execution verification. Anthropic's research shows this as a primary failure mode: "Claude tended to make code changes, and even do testing with unit tests or curl commands against a development server, but would fail to recognize that the feature didn't work end-to-end".

### Per-Task-Type Completion Logic

**Coding tasks:**
```swift
struct CodingCompletionChecker: CompletionChecker {
    func verify(task: AgentTask, workingDir: URL) async -> CompletionResult {
        // 1. Compile check — must succeed with zero errors
        let buildResult = try await runProcess("swift build --configuration release", cwd: workingDir)
        guard buildResult.exitCode == 0 else {
            return .failed("Build failed: \(buildResult.output.suffix(500))")
        }
        
        // 2. Test suite — must pass all tests that existed before this task
        let testResult = try await runProcess("swift test --parallel", cwd: workingDir)
        guard testResult.exitCode == 0 else {
            return .failed("Tests failed: \(testResult.output.suffix(500))")
        }
        
        // 3. Feature-specific verification from features.json
        let features = try loadFeatures(workingDir)
        let targetFeature = features.first { $0.id == task.targetFeatureId }
        guard let feature = targetFeature else {
            return .failed("Target feature not found in features.json")
        }
        
        // 4. End-to-end smoke test if available
        if feature.smokeTestCommand != nil {
            let smokeResult = try await runProcess(feature.smokeTestCommand!, cwd: workingDir)
            guard smokeResult.exitCode == 0 else {
                return .failed("Smoke test failed")
            }
        }
        
        return .passed(evidence: "Build: OK, Tests: \(testResult.testCount) passed, Smoke: OK")
    }
}
```

**Terminal tasks:**
```swift
struct TerminalCompletionChecker: CompletionChecker {
    func verify(task: AgentTask, workingDir: URL) async -> CompletionResult {
        // 1. Expected output pattern match (regex or exact)
        guard let expectedPattern = task.expectedOutputPattern else {
            return .skipped("No output pattern defined — human review required")
        }
        // Run verification command + pattern match
        let verifyResult = try await runProcess(task.verificationCommand, cwd: workingDir)
        let matches = verifyResult.output.range(of: expectedPattern, options: .regularExpression) != nil
        
        // 2. File existence check if task creates files
        let fileChecks = task.expectedOutputFiles?.allSatisfy { file in
            FileManager.default.fileExists(atPath: workingDir.appending(path: file).path)
        } ?? true
        
        guard matches && fileChecks else {
            return .failed("Output pattern did not match or expected files missing")
        }
        return .passed(evidence: "Pattern matched: \(expectedPattern)")
    }
}
```

**Research tasks:**
```swift
struct ResearchCompletionChecker: CompletionChecker {
    func verify(task: AgentTask, workingDir: URL) async -> CompletionResult {
        // 1. Citation verification — all cited sources actually accessed in trace
        let traceEvents = try loadTraceEvents(for: task.id)
        let accessedUrls = traceEvents.filter { $0.type == .toolCall && $0.tool == "web_search" }
                                      .compactMap { $0.query }
        let citedSources = try extractCitations(from: task.outputDocument)
        let uncited = citedSources.filter { !accessedUrls.contains($0) }
        guard uncited.isEmpty else {
            return .failed("Citations present without evidence of source access: \(uncited)")
        }
        
        // 2. Minimum evidence threshold
        guard traceEvents.filter({ $0.type == .toolCall }).count >= task.minimumToolCalls else {
            return .failed("Insufficient source investigation — too few tool calls")
        }
        
        // 3. LLM-as-judge for research quality (optional, async)
        if task.requiresQualityJudge {
            let score = try await judgeResearchQuality(task.outputDocument, rubric: task.rubric)
            guard score >= task.minimumQualityScore else {
                return .failed("Quality score \(score) below threshold \(task.minimumQualityScore)")
            }
        }
        return .passed(evidence: "\(accessedUrls.count) sources accessed, quality check passed")
    }
}
```

**Note synthesis tasks:**
```swift
struct NoteSynthesisCompletionChecker: CompletionChecker {
    func verify(task: AgentTask, workingDir: URL) async -> CompletionResult {
        // 1. All referenced documents were actually read (from trace)
        let traceEvents = try loadTraceEvents(for: task.id)
        let readDocs = traceEvents.filter { $0.type == .toolCall && $0.tool == "read_note" }
                                  .compactMap { $0.noteId }
        let referencedDocs = try extractNoteReferences(from: task.outputNote)
        let unread = referencedDocs.filter { !readDocs.contains($0) }
        guard unread.isEmpty else {
            return .failed("Notes referenced but not read: \(unread)")
        }
        
        // 2. Output note was actually written to vault
        guard vault.noteExists(task.outputNoteId) else {
            return .failed("Output note was not saved to vault")
        }
        return .passed(evidence: "\(readDocs.count) notes read, output saved")
    }
}
```

### Anti-Fake-Finish Strategies

1. **Force evidence-based completion:** The completion checker requires a `evidence: String` field in every `CompletionResult`. The evidence must contain artifact data (test counts, pattern matches, file checksums) — not agent opinion.
2. **JSON feature list, not Markdown:** Agents are less likely to overwrite or corrupt JSON files.
3. **Git checkpoint before marking done:** Require a git commit before a feature can be marked `passes: true`.
4. **Smoke test before new work:** Run the smoke test at session *start*, not just at task end. This catches regressions from prior sessions.
5. **Separate verifier from implementer:** The completion checker code is not part of the harness being optimized — it is a hard constraint. This prevents the proposer from "optimizing" completion checking into trivial pass-through.

***

## 9. Trace Storage and Replay Architecture

### Filesystem vs. DB vs. Hybrid

The paper's key design choice — exposing full history through a filesystem so the proposer can grep/cat — drives the storage decision. The filesystem is non-negotiable for proposer access. A database is valuable for metadata query (score filtering, ancestry tracking). The correct architecture is **hybrid**:

| Layer | Technology | Purpose |
|---|---|---|
| Raw traces | JSONL files on filesystem | Proposer grep/cat access; human readability; append-only safety |
| Trace index | SQLite (via GRDB) | Fast query: "all traces where task_id=X and outcome=fail" |
| Harness versions | Filesystem directories | Direct inspection; diff-friendly |
| Scores + metadata | SQLite | Pareto frontier, ranking, ancestry tracking |
| Semantic search | Rust-based embedding index | "Find traces similar to this failure" |

**Old trace rotation:** Traces older than 90 days that are not referenced by any held-out task eval get compressed (ZSTD) and moved to a cold archive directory. The index retains the metadata even after compression.

**Maximum footprint:** Enforce a 5GB soft limit on the `traces/` directory. Production traces from one year at 2 tasks/day at ~50KB/trace averages ~36MB/year — well within budget. Evaluation traces for the Harness Lab are the larger concern (60 candidates × 20 tasks × ~200KB = ~240MB per search run).

### Artifact Layout Per Task

```
sessions/session_abc123/
├── bootstrap_packet.json      # environment snapshot at task start
├── features.json              # task decomposition (JSON, not Markdown)
├── progress.json              # session handoff data
├── artifacts/
│   ├── initial_state.patch    # git diff before task started
│   ├── final_state.patch      # git diff after task completed
│   └── output.md             # primary output document (research/synthesis)
└── trace.jsonl                # full execution trace (append-only)
```

### Replay Execution

```swift
struct ReplayEngine {
    func replay(
        taskId: String,
        harnessVersion: String,
        seed: UInt64 = 42  // for reproducibility
    ) async throws -> ReplayResult {
        // 1. Load task definition and bootstrap packet from archive
        let task = try taskSuite.task(id: taskId)
        let packet = try sessionStore.bootstrapPacket(sessionId: task.originalSessionId)
        
        // 2. Set up isolated environment (subprocess with no access to live vault)
        let sandbox = try SandboxEnvironment(seed: seed)
        try sandbox.restore(from: task.initialState)
        
        // 3. Load candidate harness
        let harness = try harnessRegistry.harness(version: harnessVersion)
        
        // 4. Run with trace logging
        let traceOutput = URL(...)
        let result = try await AgentRunner(
            harness: harness,
            environment: sandbox,
            traceOutput: traceOutput
        ).run(task: task, bootstrapPacket: packet)
        
        // 5. Run completion checker
        let completion = try await harness.completionChecker.verify(task: task, workingDir: sandbox.root)
        
        return ReplayResult(
            taskId: taskId,
            harnessVersion: harnessVersion,
            outcome: completion,
            tracePath: traceOutput,
            deltaFromBaseline: scoreStore.delta(taskId: taskId, 
                                                candidateVersion: harnessVersion,
                                                baselineVersion: "production")
        )
    }
}
```

***

## 10. Evaluation Strategy

### Task Suite Design

**Search set (10–20 tasks initially):** These are the tasks the proposer and its proposed candidates are evaluated against. Start with tasks that represent the most common Epistemos use cases: Swift refactoring, Rust FFI repair, research note synthesis, terminal automation. Cover failure modes you have already observed in production traces.

**Held-out test set (5–10 tasks):** The proposer and its candidates never see these tasks. They are used only when deciding whether to promote a candidate to production. Rotate tasks from held-out to search set every 4–6 weeks to prevent the search set from being fully memorized.

**Task construction rule:** A task is valid if and only if there is an unambiguous, automatically verifiable success condition. Research tasks need a rubric (enforced by LLM-as-judge); coding tasks need tests; terminal tasks need output patterns.

### Scoring

| Task type | Primary scorer | Fallback |
|---|---|---|
| Coding | Test suite pass rate | Build error count |
| Terminal | Output pattern match + file existence | Exit code |
| Research | LLM-as-judge rubric (1–5) | Citation verification |
| Note synthesis | Source coverage + LLM quality judge | Output note length |

**Regression threshold:** A candidate must not degrade any single search-set task by more than 10% relative to the current production harness. A regression on a previously-perfect task (100% → 90%) is treated as a hard block.

**Promotion threshold:** Average test-set score must improve by ≥5% over production harness, with no regressions on any test-set task.

### Preventing Overfitting

The paper notes: "Overfitting in code space is also more inspectable: brittle if-chains or hard-coded class mappings are visible on inspection in a way that weight-space overfitting is not". For Epistemos:

1. **Code review as overfitting detection:** The PromotionPipeline diff view should flag any conditional logic that references specific task IDs or specific output strings
2. **OOD generalization test:** Before promotion, run the candidate on 2–3 real production traces from unrelated recent sessions, not from the task suite
3. **Regex audit:** Automated scan of proposed harness code for task-specific strings (file names, project names, expected outputs)
4. **Holdout rotation schedule:** Prevents any task from staying in holdout forever, which would allow overfitting to the held-out set via iteration count

***

## 11. Risks and Anti-Patterns

### Overfitting to Benchmarks
**Symptom:** Candidate harness scores improve on task suite but user-reported quality drops. **Cause:** Task suite is too narrow or proposer found brittle shortcuts. **Prevention:** OOD generalization test before every promotion; task suite rotation every 6 weeks.

### Product/Runtime Contamination
**Symptom:** Harness Lab runs affect production agent behavior during an active user session. **Cause:** Shared actor state or shared filesystem paths between production and lab. **Prevention:** Strict path separation between `harness/production/` and `harness/lab/`; Harness Lab runs in an isolated subprocess with no access to the app's actor system.

### Self-Modifying Production Behavior
The Gödel Agent pattern (recursive self-modification) is seductive but dangerous without hard gates. For Epistemos, this is the single most important safety rule: **the Harness Lab must never automatically promote a candidate to production.** Every promotion requires a deliberate human action in the Harness Lab UI, triggered only after review and regression check. The system can propose; humans decide.

### Cost Explosion
A proposer loop using Claude Code + Opus-4.6 at ~10 MTok/iter × 20 iterations can cost $200–500 per search run at current API prices. This is not a user-facing feature. **Prevention:** Rate-limit proposer invocations; offer a "local proposer" mode using local MLX models for exploratory iterations (lower quality, zero cost) before graduating to cloud proposer; enforce maximum $50/month hard limit in ProposerOrchestrator.

### Thermal / Performance Hazards
Evaluation runs that invoke local MLX inference will generate significant thermal load. **Prevention:** EvaluationRunner checks `ThermalGuard` before spawning; all Harness Lab runs are gated by `AppCapability.local` being available; enforce maximum 1 concurrent evaluation subprocess.

### Excessive Complexity Before Value
The Harness Lab is future infrastructure. Building it before you have working trace logging, a working bootstrap packet, and at least 5 production agent task completions to analyze is premature. The minimum viable version is a directory of JSONL files and a script to grep them — not a full actor-based subsystem.

### Fake Completion Propagation
If your `CompletionChecker` implementations are too permissive (e.g., accept agent self-reporting), the task suite scores will be inflated. A proposed harness can "improve" by making the agent more confidently wrong. **Prevention:** CompletionChecker implementations must be based on external verification (compile results, test output, file existence) — never on the model's self-assessment.

***

## 12. Final Recommendation

### What to Do Now (This Month)

**Priority 1: BootstrapPacketBuilder** — implement the environment snapshot struct and inject it before every agent task's first turn. Use the exact field list in Section 7. Target 800–1,200 tokens. This is a net improvement with zero risk.

**Priority 2: TraceCollector actor** — non-blocking JSONL append of every tool call and model output during agent execution. Use the format in Section 5. This is the single most important infrastructure investment — it enables everything else.

**Priority 3: progress.json + session handoff** — implement session continuity by writing a handoff file at the end of every agent session (success or failure), and reading it at the start of the next session. This directly improves multi-turn task quality.

**Priority 4: JSON task decomposition** — for any multi-step agent task, have the initializer phase produce `features.json` with `"passes": false` on all items. Use JSON not Markdown.

**Priority 5: CompletionChecker implementations** — at minimum for coding tasks (build + test) and terminal tasks (output pattern). Block agent from marking a task done without evidence.

### What to Defer (Next Quarter)

- Full HarnessRegistry with versioning
- EvaluationRunner with subprocess isolation
- Task suite with held-out set
- ProposerOrchestrator (Claude Code integration)
- PromotionPipeline with regression check

Defer until you have: (a) working trace logging for at least 30 production task runs, (b) at least 10 manually curated task definitions with clear success criteria.

### The Elite Later-Stage System

1. **Harness Lab UI** — developer-only SwiftUI panel showing: trace browser, candidate comparison, diff viewer, regression chart, promotion button
2. **Semantic trace search** (Rust FFI) — "find traces similar to this failure" via embedding search
3. **Proposer loop** — Claude Code with filesystem access to the full trace corpus, running offline against the task suite
4. **Per-domain harnesses** — separate harness versions for coding, research, terminal, note-synthesis, with independent evolution tracks
5. **Trace-driven fine-tuning** — export successful traces as training data for local MLX model fine-tuning on Epistemos-specific tasks
6. **Continuous improvement flywheel** — production traces → trace store → nightly eval → proposer iteration → human review → promotion → production (closed loop, as described in the NVIDIA data flywheel pattern)

### The Brutally Honest Assessment

The trace-first flywheel described by Meta-Harness and validated by NVIDIA's production deployment is one of the highest-ROI architectural patterns available for an agent system in 2026. But it requires **accurate traces as the foundation.** If your traces are incomplete, or your completion checkers are permissive, the signal is corrupted and the proposer will optimize for the wrong thing.

Build the foundation (tracing, bootstrap packet, completion checking) with the same rigor you applied to circuit breakers and typestate. The Harness Lab is the reward you get after the foundation is solid.