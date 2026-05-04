# Self-Modifying Agents and Autonomous Software Evolution

**Research Domain:** Landslide Dimension 05 — Self-Modification & Autonomous Evolution  
**Date:** 2026  
**Sources:** 25+ primary sources with inline citations [^N^]

---

## Executive Summary

The frontier of autonomous agent research is shifting from static, pre-trained systems toward **self-modifying agents** that can evolve their own capabilities at runtime. This encompasses five interconnected paradigms: (1) **skill libraries** that accumulate executable code (Voyager), (2) **multi-agent code generation** emulating software teams (MetaGPT), (3) **iterative self-repair** loops that execute, diagnose, and fix code, (4) **LLM-driven genetic search** that treats code as evolvable genotypes (FunSearch), and (5) **on-demand tool creation** where agents manufacture their own tools (LATM/ToolMaker). Each paradigm demands rigorous **safety boundaries** — sandboxes, capability constraints, and sandboxed execution — to prevent runaway behavior. In systems languages like Rust and Swift, these patterns require careful architectural decisions around dynamic loading, WASM sandboxing, and process isolation.

---

## 1. Voyager: The Skill Library Paradigm

### 1.1 Core Architecture

Voyager (Wang et al., 2023) represents a watershed moment in embodied AI: the first **LLM-powered lifelong learning agent** that continuously explores Minecraft, acquires skills, and makes novel discoveries without human intervention [^2601^][^2597^]. Its architecture rests on three pillars:

1. **Automatic Curriculum**: GPT-4 proposes exploration objectives based on the agent's current state and world context, maximizing novelty-driven exploration [^2610^].
2. **Skill Library**: An ever-growing vector database of executable JavaScript code (via Mineflayer API) indexed by embedding of natural-language descriptions [^2608^].
3. **Iterative Prompting Mechanism**: A closed loop of code generation → execution → feedback → refinement [^2615^].

### 1.2 Code as Action Space

Voyager's radical insight is using **code as the action space** instead of low-level motor commands. This choice is deliberate: programs naturally represent temporally extended and compositional actions essential for long-horizon tasks [^2598^]. Each skill (e.g., `craftStoneShovel()`, `combatZombieWithSword()`) is a verifiable, interpretable, reusable JavaScript function [^2614^].

### 1.3 Iterative Prompting with Three Feedback Types

The self-improvement loop incorporates [^2597^]:

- **Environment feedback**: Intermediate execution observations (e.g., "I cannot make an iron chestplate because I need: 7 more iron ingots")
- **Execution errors**: Traceback from the JavaScript interpreter revealing invalid operations or syntax errors
- **Self-verification**: A separate GPT-4 "critic" agent checks task completion and suggests corrections if failed

After up to 4 rounds of refinement, successful programs are **committed to the skill library** and the curriculum proposes the next objective [^2597^].

### 1.4 Skill Library Implementation

The skill library maintains two hash tables [^2608^]:
- Forward index: code snippets indexed by their task descriptions (via embeddings)
- Reverse index: task descriptions indexed by outputs (e.g., "pickaxe" → craft program)

When facing a new task, Voyager queries the top-5 most relevant skills and can **compose simpler programs into complex skills**, compounding capabilities over time and alleviating catastrophic forgetting [^2610^].

### 1.5 Empirical Results

Voyager achieved **3.3× more unique items**, traveled **2.3× longer distances**, and unlocked tech tree milestones **up to 15.3× faster** than prior state-of-the-art [^2601^]. Crucially, it can transfer its skill library to **new Minecraft worlds** and solve novel tasks from scratch [^2615^].

### 1.6 Practical Implications for Rust/Swift

For native implementations:
- **Skill storage**: Use an embedded vector database (e.g., `pgvector` via SQLite extension, or `usearch`) indexed by sentence embeddings
- **Code representation**: Store skills as WASM modules or dynamic library functions rather than raw strings
- **Composition**: Implement a trait-based composition system where skills implement a common `Skill` trait with `execute(&mut State) -> Result` methods
- **Embedding indexing**: Pre-compute embeddings with lightweight local models (e.g., `fastembed-rs`) for offline skill retrieval

---

## 2. MetaGPT: Multi-Agent Code Generation

### 2.1 The Software Company Metaphor

MetaGPT is a multi-agent framework that simulates a complete software company by assigning specialized roles to LLM agents: Product Manager, Architect, Project Manager, Engineer, and QA Engineer [^2591^][^2589^]. The core philosophy is **Code = SOP(Team)** — standard operating procedures are materialized and applied to teams composed of LLMs [^2589^].

### 2.2 Structured Communication Protocol

Agents communicate through **structured outputs** based on requirements set by an assembly-line paradigm. Each agent generates information to prompt the next agent, with handovers that must comply with established standards [^2591^]. This structured output approach "greatly enhances the success rate of target code generation" by reducing hallucination caused by idle chatter between LLMs [^2591^].

### 2.3 Role-Based Agent Responsibilities

| Agent Role | Responsibilities | Output |
|------------|-----------------|--------|
| Product Manager | Interprets user prompt, generates PRD with goals, user stories, competitive analysis | Product Requirement Document |
| Architect | Translates PRD into technical specs, system architecture, interface definitions, sequence diagrams | Design documents |
| Project Manager | Breaks down specs into tasks, assigns to engineers, oversees progress | Task lists, schedules |
| Engineer | Implements tasks by writing code per specifications | Functional code modules |
| QA Engineer | Develops and executes test cases, validates functionality and reliability | Test reports, feedback [^2582^] |

### 2.4 Cost and Performance

MetaGPT takes a **one-line requirement** as input and outputs "user stories, competitive analysis, requirements, data structures, APIs, documents, etc." [^2589^]. Generating one example with analysis costs approximately **$0.20** in GPT-4 API fees; a full project costs around **$2.00** [^2589^].

### 2.5 Practical Implications for Rust/Swift

- **Agent orchestration**: Implement a message-passing system using async channels (`tokio::mpsc` in Rust, `Combine`/`async` in Swift)
- **Structured outputs**: Enforce typed document formats using structs with validation (Serde in Rust, Codable in Swift)
- **SOP encoding**: Represent standard operating procedures as state machines or directed acyclic graphs of agent tasks
- **Assembly-line pattern**: Pipeline data through a sequence of transformation stages, each owned by a specialized agent module

---

## 3. Self-Repairing Code: Execution → Error → Fix → Retry

### 3.1 The Iterative Self-Repair Protocol

The self-repair paradigm replicates how human programmers work: write, run, read errors, iterate. A 2026 study formalizes this protocol [^2577^]:

1. Generate initial code solution `c₀ = M(p)`
2. Execute in sandboxed environment
3. If success → done. If error `e₀` → construct repair prompt with (problem spec, previous code, error message)
4. Generate corrected solution `cᵢ = M(p, cᵢ₋₁, eᵢ₋₁)`
5. Repeat up to N rounds (typically 4 repair rounds = 5 total attempts)

### 3.2 Self-Repair Effectiveness Across Model Scales

The effectiveness of iterative self-repair varies significantly by model capability [^2577^]:
- Strong models (GPT-4, modern MoE architectures) show substantial gains from repair rounds
- Weaker models may introduce new errors during repair — "self-repair is not a silver bullet" [^2577^]
- Dense vs. MoE architectures exhibit different repair dynamics, with MoE models often showing more robust error comprehension

### 3.3 The Self-Correction Decorator Pattern

For production deployment, a practical pattern wraps agent-executed functions with a **self-correction decorator** [^2578^]:

```python
@self_correct(
    max_attempts=3,
    token_budget=4000,
    retryable_errors=(KeyError, ValueError),
    correction_callback=llm_correction,
    agent_id="data-pipeline-agent-01"
)
def transform_data(df):
    # LLM-generated code that may fail
    df["year"] = pd.to_datetime(df["date"]).dt.year
    return df[df["year"] >= 2023]
```

Key components [^2578^]:
- **Instrumentation**: OpenTelemetry spans carrying prompt hashes, attempt numbers, token estimates
- **Error classification**: Dynamic categorization as terminal, retryable-with-mutation, or retryable-without-mutation
- **Mutation**: Feeding error message, traceback, and prior output back into the agent's next prompt
- **Budget enforcement**: Hard boundaries on retry attempts and cumulative token spend
- **Failure storage**: All intermediate code generations (including failures) stored for training signal

### 3.4 Reflexion: Verbal Reinforcement Learning

Reflexion (Shinn et al., NeurIPS 2023) extends self-repair with **episodic memory** [^2644^]. Instead of just retrying, the agent writes a failure analysis in natural language after each attempt. A Self-Reflection model reads the trajectory and reward signal, produces a verbal post-mortem, and appends it to memory. On the next trial, the Actor reads accumulated reflections before acting.

Results: Reflexion + GPT-4 reaches **91%** on HumanEval (up from 80% baseline); on AlfWorld solves **130/134** tasks after 12 trials vs. 108/134 for ReAct baseline [^2644^]. However, Reflexion can hurt performance on tasks requiring "significant diversity and exploration" [^2644^].

### 3.5 Practical Implications for Rust/Swift

- **Error taxonomy**: Define a typed error hierarchy (`AgentError::Retryable`, `AgentError::Terminal`) with structured error contexts
- **Retry backoff**: Implement exponential backoff with jitter for API calls; deterministic retry for compilation errors
- **State preservation**: Serialize intermediate computation state so retries can resume from failure points
- **LLM correction callback**: Use a dedicated reasoning model (e.g., smaller model for error analysis, larger model for code generation) to reduce costs

---

## 4. Genetic Algorithms with LLM as Mutation Operator

### 4.1 LLM_GP: A General Algorithm

The LLM_GP algorithm treats code as variable-length text genotypes and uses an LLM for every evolutionary operator: initialization, evaluation, fitness measurement, selection, crossover, mutation, and replacement [^2590^][^2595^]. Unlike traditional genetic programming that operates on parse trees, LLM_GP evolves executable code sequences directly.

### 4.2 Integration Patterns for LLMs in Genetic Search

Emergent research identifies recurring design patterns [^2583^]:

| Integration Mode | LLM Role |
|-----------------|----------|
| **Mutation Operator** | LLM prompted to produce variation on code block, replacing handcrafted mutation |
| **Crossover/"Mating"** | LLM combines input "genes" (code snippets) into new individuals |
| **Initial Population** | LLM generates tailored candidate pool based on problem objectives |
| **Evolution Reflection** | LLM uses chain-of-thought from past elite solutions to propose refinements |
| **Semantic Filtering** | LLM generates summaries of patches for downstream clustering |
| **Auxiliary Operators** | LLM acts as search/repair operator generating functional program patches |

### 4.3 Key Implementations

- **Gin Java GI toolkit**: Expanded to use GPT-3.5 Turbo for mutation operators, editing blocks of Java code via structured prompts [^2583^]
- **FunSearch**: Evolution of Python priority functions via LLMs for mathematical discovery (detailed in §6)
- **Guided Evolution**: Direct manipulation of model code/architecture "genes" by LLMs with "Evolution of Thought" reflection [^2583^]
- **VRPAgent**: LLMs synthesize removal/reinsertion operators in large neighborhood search, with GA refining based on solution quality and code brevity [^2583^]

### 4.4 Prompt Engineering for Evolution

Successful LLM-driven evolution requires careful prompt design [^2595^]:
- **Template-based**: Structured prompts with slots for parent code, fitness scores, mutation instructions
- **Changing temperature**: Varying sampling temperature between generations to balance exploration/exploitation
- **Chaining**: Multi-step LLM calls where one model proposes mutations and another validates syntax
- **Few-shot**: Providing examples of successful mutations in the prompt context
- **Summarization**: LLM-generated summaries of elite solutions guide future mutation directions

### 4.5 Practical Implications for Rust/Swift

- **Genotype representation**: Use `String` or `TokenStream` (via `proc_macro2`) as genotype; phenotype is the compiled/interpreted result
- **Fitness evaluation**: Run generated code in a sandboxed WASM runtime or separate process with timeout
- **Selection pressure**: Implement tournament selection or fitness-proportionate selection over populations of code candidates
- **Memory management**: In Rust, use `Arc<str>` for immutable genotype strings to enable cheap cloning; in Swift, use `String` with copy-on-write semantics

---

## 5. Hot-Swapping Tools at Runtime

### 5.1 The Hot Reload Landscape

Hot-swapping — updating code without restarting — varies dramatically by language and runtime [^2593^]:

| Environment | Mechanism | Feasibility |
|-------------|-----------|-------------|
| C/C++ | `dlopen()` / dynamic linking | Possible but complex |
| Java/Kotlin | JVM class redefinition (DCEVM), Java agents | Highly feasible via `instrumentation.redefineClasses` [^2579^] |
| Rust | `libloading` crate + dynamic libraries | Feasible with ABI stability concerns [^2600^][^2613^] |
| Web (JS) | Hot Module Replacement (HMR) | Highly efficient via virtual DOM |
| Cloud | Kubernetes rolling updates, Lambda versioning | Container-level replacement |

### 5.2 Rust Hot Reloading with libloading

The `libloading` crate provides a unified interface around OS dynamic library functions (`dlopen`, `dlclose`, `LoadLibraryEx`) [^2613^]. A practical implementation [^2600^]:

```rust
use libloading::{Library, Symbol};

type UpdateFuncT = extern "C" fn(&mut dyn Context) -> ();

pub struct Worker {
    update_func: UpdateFuncT,
    lib: Library,
}

impl Worker {
    pub fn new() -> Self {
        let lib = unsafe { Library::new("libworker.so").unwrap() };
        let symb: Symbol<UpdateFuncT> = unsafe { lib.get(b"hot_update").unwrap() };
        let update_func = *symb.into_raw();
        Self { lib, update_func }
    }
}
```

The `hot-lib-reloader` crate automates this with a `#[hot_module]` macro that watches files via `notify` and reloads on change [^2613^].

### 5.3 WebAssembly as a Safe Plugin Boundary

For agent tool systems, **WebAssembly plugins** offer the strongest safety guarantees [^2627^][^2628^]:

```rust
// Host loads WASM plugin via Wasmtime
let engine = wasmtime::Engine::default();
let module = wasmtime::Module::from_file(&engine, "plugin.wasm")?;
let mut linker = wasmtime::component::Linker::new(&engine);
Plugin::add_to_linker(&mut linker, |state| state)?;
```

Benefits [^2628^]:
- **Security**: Sandboxed execution with controlled interfaces via WIT (WebAssembly Interface Types)
- **Binary compatibility**: Stable binary format enables any language to communicate with any other
- **Resource control**: Fine-grained CPU and memory limits
- **Cross-platform**: Same binary runs on any OS/architecture

Trade-offs [^2634^][^2638^]:
- 1.5×–3× performance overhead vs. native
- Data copying into WASM memory adds latency
- Not all Rust code compiles to WASM (C library dependencies fail)
- WASI targets (p1, p2) are still evolving

### 5.4 The rustant-plugins Architecture

The `rustant-plugins` crate demonstrates a mature dual-mode plugin system [^2626^]:
- **Native plugins**: `.so`/`.dll`/`.dylib` via dynamic loading
- **WASM plugins**: Sandboxed via `wasmi` interpreter

This provides a tiered trust model: untrusted agent-generated tools run in WASM; trusted built-ins run natively.

### 5.5 Swift Dynamic Library Loading

Swift on Apple platforms supports dynamic library loading via `dlopen` [^2642^]:

```swift
import Foundation

func loadFramework(at path: String) throws -> UnsafeMutableRawPointer? {
    guard let handle = dlopen(path, RTLD_NOW) else {
        let error = dlerror().map { String(cString: $0) } ?? "Unknown error"
        throw NSError(domain: "dlopen", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
    }
    return handle
}
```

Using `@_cdecl("exportMyHappyInterface")` on Swift functions creates C-linkable symbols that can be looked up dynamically [^2642^]. For iOS, this requires framework bundling; on macOS, `.dylib` files can be loaded directly.

### 5.6 Practical Implications for Agent Tool Systems

| Approach | Latency | Safety | Complexity | Best For |
|----------|---------|--------|------------|----------|
| Native dynamic loading | Low | Low (same process) | Medium | Trusted, performance-critical tools |
| WASM runtime | Medium | High (sandboxed) | High | Untrusted, agent-generated tools |
| Subprocess (gRPC/stdio) | High | High (OS isolation) | Medium | Heavyweight tools with complex deps |
| JavaScriptCore (Swift) | Medium | Medium | Low | Rapid prototyping, text-processing tools |

---

## 6. FunSearch: LLM-Driven Mathematical Discovery

### 6.1 The Nature Paper (Romera-Paredes et al., Nature 2024)

FunSearch ("searching in the function space") is an evolutionary procedure that pairs a pretrained LLM with a systematic evaluator to make new mathematical discoveries [^2580^][^2581^]. It was the first LLM-based system to discover verifiable new knowledge for a longstanding scientific puzzle — the **cap set problem** in extremal combinatorics, described by Terence Tao as his favorite open question [^2581^].

### 6.2 How FunSearch Works

The algorithm follows an evolutionary loop [^2585^][^2581^]:

1. **User writes a specification**: Problem description in code, including an `evaluate` function and a `solve` function skeleton
2. **Select promising programs**: From a database of previously generated programs
3. **LLM generates improvements**: Google's PaLM 2 (Codey) creatively builds upon selected programs
4. **Automatic evaluation**: Programs are executed and scored by the evaluator
5. **Best programs added to database**: Improving the gene pool for subsequent rounds

### 6.3 Key Innovation: The Evaluator as Guard

FunSearch's critical insight is the **evaluator** that guards against LLM hallucinations [^2581^]. While the LLM proposes creative variations, only programs that pass rigorous automated checking enter the evolutionary database. This "creative core + systematic verifier" architecture is generalizable beyond mathematics.

### 6.4 Results

- **Cap set problem**: Found cap set of size **512** in n=8 dimensions, establishing new state of the art [^2585^]
- **Online bin packing**: Generated heuristics outperforming first-fit and best-fit baselines on Weibull datasets [^2585^]
- **Admissible sets**: Discovered full symmetric admissible set I(15,10) and partial A(24,17) [^2585^]

The system sampled on the order of **10⁶** LLM proposals per problem run [^2585^].

### 6.5 Interpretability Advantage

FunSearch generates **programs that describe how solutions are constructed**, not just solution lists [^2581^]. As mathematician Jordan Ellenberg noted: "The solutions generated by FunSearch are far conceptually richer than a mere list of numbers. When I study them, I learn something." [^2581^]

### 6.6 Practical Implications for Agent Systems

- **Specification pattern**: Define a `Spec` trait with `evaluate(candidate: &Program) -> Score` and `solve(heuristic: &Program) -> Solution`
- **Database architecture**: Use a priority queue or k-d tree indexed by program embeddings for efficient retrieval of "promising" candidates
- **Evaluator sandbox**: Run generated programs in a WASM sandbox or E2B microVM with strict resource limits
- **Diversity maintenance**: Implement novelty search or quality-diversity algorithms to prevent premature convergence

---

## 7. Tool Creation on Demand: LATM, ToolMaker, and CREATOR

### 7.1 LATM: Large Language Models as Tool Makers

LATM (Cai et al., ICLR 2024) introduces a **closed-loop framework** where LLMs create their own reusable tools [^2599^][^2604^]. It has two phases:

1. **Tool Making**: A powerful LLM (GPT-4) crafts tools as Python utility functions for a class of tasks
2. **Tool Using**: A lightweight LLM (GPT-3.5) applies the cached tools for problem-solving

This division of labor spreads the once-off cost of tool-making over multiple instances, reducing average cost while maintaining performance [^2599^]. The framework offers a **functional cache** — storing functionality of request classes rather than natural language responses [^2604^].

### 7.2 ToolMaker: Autonomous Scientific Tool Creation

ToolMaker (2025) autonomously converts scientific code repositories into LLM-compatible tools [^2602^][^2607^]. Given a task description and GitHub URL, it:

1. Clones and explores the repository
2. Installs dependencies in a clean Docker environment
3. Generates a step-by-step implementation plan
4. Writes Python code for the tool
5. Uses closed-loop **self-correction** to iteratively diagnose and fix errors

ToolMaker correctly implements **80%** of 15 diverse computational tasks spanning medical and non-medical domains, substantially outperforming prior software engineering agents [^2607^].

### 7.3 CREATOR and Autonomous Tool Expansion

The broader field of autonomous tool expansion [^2586^][^2588^] includes:

- **CREATOR**: Transforms abstract problems (mathematical reasoning, table processing) into concrete Python scripts, bypassing static API limitations
- **RestGPT**: Uses LLMs to plan and connect multiple RESTful APIs into composite "super tools"
- **ToolMaker (general)**: Agents dynamically synthesize tool code for subtasks and reuse them within the current context

The breakthrough pattern is **decoupling abstract reasoning from concrete execution** — creators generate tools; users execute them [^2586^].

### 7.4 Practical Implications for Rust/Swift

- **Tool registry**: Maintain a `HashMap<String, Box<dyn Tool>>` with JSON Schema validation for each tool's input/output
- **Tool generation pipeline**: LLM generates code → compile to WASM → register in tool registry → execute via sandboxed runtime
- **Caching strategy**: Cache compiled WASM modules by content hash; cache tool definitions by task embedding
- **Fallback chain**: If generated tool fails, fall back to (1) retrieving similar cached tool, (2) simpler decomposition, (3) human escalation

---

## 8. Autopoietic Software Boundaries

### 8.1 The Concept of Autopoiesis

Autopoiesis (from Greek: "self-creation") is a concept from biology (Maturana & Varela) describing systems that continuously regenerate their own components while maintaining their organizational identity. In software, **autopoietic systems** are programs that produce and modify their own code, maintaining operational boundaries that distinguish self from environment.

### 8.2 Computational Autopoiesis

For agent systems, autopoietic principles translate to:

1. **Self-maintenance**: The agent's code evolution mechanisms must preserve core safety invariants
2. **Operational closure**: The agent's modification capabilities form a closed loop — only outputs of the modification system can become inputs to future modifications
3. **Structural coupling**: The agent co-evolves with its environment (tools, APIs, user preferences) while maintaining identity

### 8.3 Boundary Mechanisms

Effective autopoietic software requires **multi-layer boundaries**:

| Boundary Layer | Function | Implementation |
|---------------|----------|----------------|
| **Capability boundary** | What the agent *can* modify | Whitelist of mutable vs. immutable components |
| **Sandbox boundary** | Where generated code *executes* | WASM, microVM, or separate process |
| **Version boundary** | How modifications are *tracked* | Immutable history (Merkle tree), rollback capability |
| **Approval boundary** | Which modifications need *human review* | Risk-scored gating |
| **Termination boundary** | When the system must *halt* | Hard limits on modification depth, resource use |

---

## 9. Self-Modification Safety Constraints

### 9.1 The Autonomy-Security Risk Spectrum

A 2025 survey formalizes how agent capabilities escalate security risks [^2636^]:

> "Greater autonomy does not merely escalate risk — it transforms its nature. Stateless models face prompt injection. Memory introduces delayed vulnerabilities. Planning amplifies subtle misalignments into long-horizon errors. Tool use bridges symbolic flaws with real-world consequences. Reflective capabilities enable self-reinforcing divergence." [^2636^]

| Capability Added | New Risk Introduced |
|----------------|-------------------|
| Memory | Delayed vulnerabilities, context poisoning |
| Planning | Long-horizon misalignment |
| Tool use | Real-world consequence bridging |
| Self-modification | Self-reinforcing divergence |
| Multi-agent coordination | Emergent deception, systemic misalignment [^2636^] |

### 9.2 Sandbox Architecture for Coding Agents

Modern coding agent sandboxes provide five essential boundaries [^1474^][^2629^]:

1. **Filesystem boundary**: Agent reads/writes only working tree; no host access
2. **Process/kernel boundary**: Isolated execution environment with own namespace
3. **Network boundary**: Block unauthorized egress; whitelist per task
4. **Credential boundary**: Secrets never enter VM directly; host-side proxy injection
5. **Resource boundary**: CPU, memory, disk, process count caps

### 9.3 Isolation Technology Comparison

| Technology | Isolation Level | Boot Time | Best For |
|-----------|-----------------|-----------|----------|
| Docker containers | Process (shared kernel) | Milliseconds | Trusted workloads |
| gVisor | Syscall interception | Milliseconds | Multi-tenant SaaS |
| Firecracker microVMs | Hardware (dedicated kernel) | ~125ms | Untrusted code, serverless |
| Kata Containers | Hardware (via VMM) | ~200ms | Regulated industries, zero-trust [^2631^][^2633^] |

### 9.4 E2B: The Agent Sandbox Standard

E2B has become the dominant agent sandbox platform, scaling from 40K to **15 million sandboxes per month** in one year, with ~50% of Fortune 500 companies running agent workloads [^1474^]. It uses **Firecracker microVMs** — the same technology powering AWS Lambda — providing hardware-level isolation per session [^2643^].

Key features [^2645^][^2641^]:
- Ephemeral by default (auto-destroy after execution)
- Persistent mode for stateful agent workflows
- Template-based environment definitions
- MCP (Model Context Protocol) server integration

### 9.5 Agent-Specific Security Patterns

Production coding agents implement layered controls [^2629^]:

```
Layer 1: Sandbox removes host-level trust
Layer 2: Network policy removes unapproved egress
Layer 3: Secret proxies let agent use credentials without reading them
Layer 4: Project-scoped settings version permissions with repo
Layer 5: Read-only subagents for exploration and planning
Layer 6: Human approval for high-consequence actions (deploys, secrets rotation)
```

### 9.6 Safety Constraints for Self-Modifying Agents

For specifically self-modifying systems, additional constraints apply:

| Constraint | Purpose | Mechanism |
|-----------|---------|-----------|
| **Immutable bootstrap** | Core orchestrator cannot modify itself | Loaded before any self-modification capability |
| **Capability attenuation** | Agent cannot grant itself more permissions than it has | Signed capability tokens from external authority |
| **Modification depth limit** | Prevent infinite recursive self-modification | Hard cap on generations of self-modified code |
| **Semantic drift detection** | Detect when agent goals diverge from original | Embedding distance between current and original mission statement |
| **Kill switch** | Guaranteed external termination | Out-of-band signal that bypasses all agent logic |
| **Audit immutability** | All actions logged to tamper-evident store | Merkle chain with external witnesses [^2626^] |

---

## 10. Practical Implementation Patterns in Rust and Swift

### 10.1 Rust: The Agent Evolution Stack

#### Core Crates Ecosystem

| Component | Crate | Purpose |
|-----------|-------|---------|
| Dynamic loading | `libloading` | Runtime `.so`/`.dll` loading |
| Hot reload | `hot-lib-reloader` | File-watching + automatic reload |
| WASM sandbox | `wasmtime`, `wasmi` | Sandboxed plugin execution |
| ABI stability | `abi_stable`, `stabby` | Safe Rust-to-Rust dynamic linking |
| Vector search | `usearch`, `pgvector` | Skill library retrieval |
| Embeddings | `fastembed-rs` | Local sentence embeddings |
| Sandboxed exec | `firecracker-rs` (bindings) | MicroVM orchestration |
| Async runtime | `tokio` | Agent orchestration |
| Serialization | `serde` | Structured agent communication |

#### Rust Architecture Pattern: Tiered Trust Tool System

```rust
// Tier 1: Native built-in tools (highest trust, highest performance)
trait NativeTool: Send + Sync {
    fn execute(&self, input: Value) -> Result<Value, ToolError>;
}

// Tier 2: WASM plugins (medium trust, sandboxed)
struct WasmTool {
    module: wasmtime::Module,
    instance: wasmtime::Instance,
}

impl WasmTool {
    fn from_llm_generated(code: &str, engine: &wasmtime::Engine) -> Result<Self, CompileError> {
        // Compile generated code to WASM
        // Validate against schema
        // Instantiate with resource limits
    }
}

// Tier 3: External sandbox (lowest trust, maximum isolation)
struct SandboxTool {
    sandbox: E2BConnection, // or Firecracker microVM
    timeout: Duration,
}
```

#### Rust Safety Considerations

- **ABI stability**: Rust lacks a stable ABI; use `abi_stable` crate or C FFI for plugins [^2632^]
- **Memory safety**: `unsafe` blocks in dynamic loading must be minimized; prefer WASM for untrusted code
- **Thread safety**: Agent orchestration requires `Send + Sync` bounds on all shared state
- **Resource limits**: Use `cgroups-rs` or WASM fuel metering to cap CPU/memory per tool execution

### 10.2 Swift: The Apple Ecosystem Agent

#### Core Capabilities

| Component | Framework | Purpose |
|-----------|-----------|---------|
| Dynamic loading | `dlopen` + `@_cdecl` | Runtime framework loading [^2642^] |
| JS execution | `JavaScriptCore` | Sandboxed JS tool runtime |
| ML inference | `CoreML`, `MLX Swift` | Local embedding models |
| Async concurrency | Swift `async/await` | Agent task orchestration |
| Structured data | `Codable` | Typed agent communication |
| Sandboxing | `App Sandbox`, `Seatbelt` | Process isolation |

#### Swift Architecture Pattern: JavaScriptCore Tool Engine

```swift
import JavaScriptCore

class JSToolEngine {
    let context: JSContext
    let timeout: TimeInterval
    
    func installTool(name: String, sourceCode: String) throws {
        // Validate source through static analysis
        // Inject safe wrappers for console, fetch (with allowlist)
        // Execute in context with timeout
        context.evaluateScript("""
        (function() {
            \(sourceCode)
            return typeof \(name) !== 'undefined' ? \(name) : null;
        })()
        """)
    }
    
    func executeTool(name: String, input: Codable) throws -> JSValue {
        // Serialize input to JSON
        // Call tool function
        // Validate output against schema
    }
}
```

#### Swift Safety Considerations

- **Code signing**: Dynamic libraries must be signed; ad-hoc signing limits distribution
- **App Store restrictions**: JIT compilation is prohibited; WASM interpreters (not JIT) are viable
- **Sandbox entitlements**: Strict filesystem/network capabilities must be explicitly declared
- **Memory limits**: Use `JSContext` exception handlers and manual memory pressure callbacks

### 10.3 Cross-Platform: WASM as the Universal Tool Format

For maximum portability across Rust, Swift, and other host languages:

1. **Tool generation**: LLM generates code in a supported language (Rust, C, AssemblyScript)
2. **Compilation**: Target WASM with WASI for system interfaces
3. **Distribution**: Tools shipped as `.wasm` binaries with WIT interface definitions
4. **Execution**: Host loads via `wasmtime` (Rust), `wasmer` (multi-language), or `wasmi` (interpreter)
5. **Verification**: Cryptographic hash of WASM binary stored in Merkle chain for audit [^2626^]

---

## 11. Synthesis: A Unified Architecture for Self-Modifying Agents

### 11.1 The Recursive Improvement Loop

Drawing from all surveyed research, a unified self-modifying agent architecture follows this loop:

```
┌─────────────────────────────────────────────────────────────┐
│  1. PERCEIVE: Observe environment state, task requirements  │
│     └─> Retrieve relevant skills from vector database         │
├─────────────────────────────────────────────────────────────┤
│  2. PLAN: Decompose task; identify capability gaps          │
│     └─> If no tool exists, trigger TOOL CREATION            │
├─────────────────────────────────────────────────────────────┤
│  3. GENERATE: LLM writes code (skill or tool)                │
│     └─> Informed by retrieved skills + evolutionary history │
├─────────────────────────────────────────────────────────────┤
│  4. VERIFY: Sandbox execution + automated evaluation         │
│     └─> Pass: commit to library                              │
│     └─> Fail: feed errors to LLM for repair (iterative)      │
├─────────────────────────────────────────────────────────────┤
│  5. EXECUTE: Run verified code in appropriate sandbox tier   │
│     └─> Monitor resource use, network, side effects           │
├─────────────────────────────────────────────────────────────┤
│  6. REFLECT: Generate verbal post-mortem (Reflexion)         │
│     └─> Store in episodic memory for future retrieval       │
├─────────────────────────────────────────────────────────────┤
│  7. EVOLVE: Periodically mutate elite skills (GA loop)       │
│     └─> LLM proposes variations; evaluator selects best     │
└─────────────────────────────────────────────────────────────┘
```

### 11.2 Safety-First Design Principles

1. **Sandbox by default**: All generated code executes in a sandbox; no exceptions
2. **Immutable audit trail**: Every code generation, execution, and modification logged to tamper-evident storage
3. **Capability attenuation**: Agent cannot escalate its own permissions; all capabilities derive from external authority
4. **Graceful degradation**: If self-modification fails, system falls back to last known good configuration
5. **Human-in-the-loop for structural changes**: Modifications to the agent's own architecture require explicit approval
6. **Resource boundedness**: Hard limits on compute, memory, API calls, and recursive modification depth

### 11.3 Research Gaps and Future Directions

- **Formal verification of self-modifying code**: No existing framework can prove safety properties of LLM-generated self-modifications
- **Cross-session memory**: Current systems cap memory at 1–3 experiences; long-term accumulation remains unsolved [^2644^]
- **Autopoietic boundaries in practice**: Theoretical frameworks (Maturana/Varela) lack concrete software implementations
- **Multi-agent self-modification**: When multiple self-modifying agents interact, emergent behaviors become unpredictable
- **Rust/Swift-specific LLM code generation**: Fine-tuned models for safe systems-language code generation are underexplored

---

## References

[^2577^]: "How Many Tries Does It Take? Iterative Self-Repair in LLM Code Generation Across Model Scales and Benchmarks," arXiv:2604.10508, 2026. https://arxiv.org/html/2604.10508v1

[^2578^]: "Error Handling Strategies for Probabilistic Code Execution," SitePoint, 2026. https://www.sitepoint.com/error-handling-strategies-for-probabilistic-code-execution/

[^2579^]: "The Journey to Compose Hot Reload 1.0.0," JetBrains Kotlin Blog, 2026. https://blog.jetbrains.com/kotlin/2026/01/the-journey-to-compose-hot-reload-1-0-0/

[^2580^]: "FunSearch: Mathematical discoveries from program search with large language models," YouTube summary of Nature paper, 2023. https://www.youtube.com/watch?v=Wsl_LVV5zVs

[^2581^]: "Can We Use AI to Discover Better Algorithms?" Richard Suwandi blog, 2025. https://richardcsuwandi.github.io/blog/2025/llm-algorithm-discovery/

[^2582^]: "MetaGPT in Action: Multi-Agent Collaboration," BizThots, 2025. https://bizthots.wordpress.com/metagpt-in-action-multi-agent-collaboration/

[^2583^]: "LLM-Driven Genetic Search," Emergent Mind, 2025. https://www.emergentmind.com/topics/llm-driven-genetic-search

[^2584^]: "MetaGPT - AI Agent," AI Agent Store, 2024. https://aiagentstore.ai/ai-agent/metagpt

[^2585^]: "Mathematical discoveries from program search with large language models," DeepMind Nature paper PDF, 2023. https://storage.googleapis.com/deepmind-media/DeepMind.com/Blog/funsearch-making-new-discoveries-in-mathematical-sciences-using-large-language-models/Mathematical-discoveries-from-program-search-with-large-language-models.pdf

[^2586^]: "The Evolution of Tool Use in LLM Agents (v1)," arXiv:2603.22862, 2026. https://arxiv.org/html/2603.22862v1

[^2588^]: "The Evolution of Tool Use in LLM Agents (v2)," arXiv:2603.22862v2, 2026. https://arxiv.org/html/2603.22862v2

[^2589^]: "MetaGPT: The Multi-Agent Framework," DeepWisdom docs. https://docs.deepwisdom.ai/main/en/guide/get_started/introduction.html

[^2590^]: "Evolving code with a large language model," Springer Nature, 2024. https://link.springer.com/article/10.1007/s10710-024-09494-2

[^2591^]: "What is MetaGPT?" IBM, 2024. https://www.ibm.com/think/topics/metagpt

[^2595^]: "Evolving Code with A Large Language Model," arXiv:2401.07102, 2024. https://arxiv.org/html/2401.07102v1

[^2596^]: "FunSearch.pdf - Computer Science," NYU Davis. https://cs.nyu.edu/~davise/papers/FunSearch.pdf

[^2597^]: "Voyager: An Open-Ended Embodied Agent with Large Language Models," arXiv:2305.16291, 2023. https://arxiv.org/html/2305.16291

[^2598^]: "LLM Agents and Tool Use: How Models Learn to Act," Miraflow AI blog, 2026. https://miraflow.ai/blog/llm-agents-tool-use-how-models-learn-to-act

[^2599^]: "Large Language Models as Tool Makers (LATM)," arXiv:2305.17126, 2023. https://arxiv.org/abs/2305.17126

[^2600^]: "I hotreload Rust and so can you," 2026. https://kampffrosch94.github.io/posts/hotreloading_rust/

[^2601^]: "Voyager: An Open-Ended Embodied Agent with Large Language Models," arXiv, 2023. https://arxiv.org/abs/2305.16291

[^2602^]: "LLM Agents Making Agent Tools (ToolMaker)," ACL Anthology, 2025. https://aclanthology.org/2025.acl-long.1266.pdf

[^2604^]: "Large Language Models as Tool Makers (LATM)," ICLR 2024. https://proceedings.iclr.cc/paper_files/paper/2024/hash/ed91353f700d113e5d848c7e04a858b0-Abstract-Conference.html

[^2605^]: "Improve AI Code Generation Using NVIDIA NeMo Agent Toolkit," NVIDIA Developer Blog, 2025. https://developer.nvidia.com/blog/improve-ai-code-generation-using-nvidia-nemo-agent-toolkit/

[^2606^]: "Large Language Models as Tool Makers (LATM)," OpenReview, 2023. https://openreview.net/forum?id=qV83K9d5WB

[^2607^]: "LLM Agents Making Agent Tools (ToolMaker)," Hugging Face Papers, 2025. https://huggingface.co/papers/2502.11705

[^2608^]: "Meet Voyager, the GPT-4 Powered AI Agent That Plays Minecraft on Its Own," Medium, 2023. https://medium.com/@mysocial81/meet-voyager-the-gpt-4-powered-ai-agent-that-plays-minecraft-on-its-own-e48991ee652b

[^2609^]: "AutoAgent: Fully-Automated and Zero-Code LLM Agent Framework," GitHub. https://github.com/hkuds/autoagent

[^2610^]: "Voyager: An Open-Ended Embodied Agent with Large Language Models," Voyager website, 2023. https://voyager.minedojo.org/

[^2611^]: "GPT-4-Powered Lifelong Learning Agent for Minecraft," 80.lv, 2023. https://80.lv/articles/voyager-gpt-4-powered-lifelong-learning-agent-for-minecraft

[^2612^]: "LLM-Powered Embodied Lifelong Learning SysOp," Curiously Nerdy, 2024. https://curiouslynerdy.com/llm-powered-embodied-lifelong-learning-sysop/

[^2613^]: "Hot Reloading Rust — for Fun and Faster Feedback Cycles," 2022. https://robert.kra.hn/posts/hot-reloading-rust/

[^2614^]: "GitHub - MineDojo/Voyager," 2023. https://github.com/minedojo/voyager

[^2615^]: "Minecraft bot Voyager programs itself using GPT-4," The Decoder, 2023. https://the-decoder.com/minecraft-bot-voyager-programs-itself-using-gpt-4/

[^2626^]: "rustant-plugins crate," lib.rs, 2026. https://lib.rs/crates/rustant-plugins

[^2627^]: "Building a Rust Plugin System," AniLog blog, 2025. https://blog.anirudha.dev/rust-plugin-system/

[^2628^]: "Building Native Plugin Systems with WebAssembly Components," Sy Brand, 2025. https://tartanllama.xyz/posts/wasm-plugins

[^2629^]: "Sandboxes for Coding Agents," Penligent AI, 2026. https://www.penligent.ai/hackinglabs/sandboxes-for-coding-agents/

[^2630^]: "Plugins in Rust: Diving into Dynamic Loading," Nullderef, 2021. https://nullderef.com/blog/plugin-dynload/

[^2631^]: "AI Agent Sandboxing Explained," SoftwareSeni, 2026. https://www.softwareseni.com/ai-agent-sandboxing-explained-why-docker-is-not-enough-and-what-actually-works/

[^2632^]: "Writing a Plugin System in Rust," Rust Users Forum, 2024. https://users.rust-lang.org/t/writing-a-plugin-system-in-rust/119980

[^2633^]: "How to sandbox AI agents in 2026: MicroVMs, gVisor & isolation strategies," Northflank, 2026. https://northflank.com/blog/how-to-sandbox-ai-agents

[^2634^]: "Building a Plugin System for Rust: Native Libraries vs WebAssembly," Kerkour, 2025. https://kerkour.com/rust-plugins

[^2635^]: "A conversation about MIRI strategy," Open Philanthropy, 2013. https://www.openphilanthropy.org/wp-content/uploads/10-27-2013-conversation-about-MIRI-strategy.pdf

[^2636^]: "A Survey on Autonomy-Induced Security Risks in Large Model-Based Agents," arXiv:2506.23844, 2025. https://arxiv.org/html/2506.23844v1

[^2637^]: "OpenAI's Code Execution Runtime & Replicating Sandboxing Infrastructure," ITNEXT, 2024. https://itnext.io/openais-code-execution-runtime-replicating-sandboxing-infrastructure-a2574e22dc3c

[^2638^]: "How to build a plugin system in Rust," Arroyo.dev, 2024. https://www.arroyo.dev/blog/rust-plugin-systems

[^2639^]: "Docker Sandbox vs Native vs DevContainers," Shane De Coninck, 2026. https://shanedeconinck.be/posts/docker-sandbox-coding-agents/

[^2640^]: "Code injection example calling dlopen on macOS," GitHub Gist, 2026. https://gist.github.com/vocaeq/fbac63d5d36bc6e1d6d99df9c92f75dc

[^2641^]: "E2B Sandbox Tools," CrewAI Docs. https://docs.crewai.com/en/tools/ai-ml/e2bsandboxtools

[^2642^]: "Lazy Loading Dynamic Libraries and the Plugin-Architecture on iOS," Medium, 2025. https://medium.com/@cjckytxz/lazy-loading-dynamic-libraries-and-building-plugin-architectures-on-ios-challenge-accepted-a554fccdb84c

[^2643^]: "How Manus Uses E2B to Provide Agents With Virtual Computers," E2B Blog, 2025. https://e2b.dev/blog/how-manus-uses-e2b-to-provide-agents-with-virtual-computers

[^2644^]: "Reflexion: Language Agents That Learn from Mistakes Without Retraining," Bean Labs, 2026. https://beancount.io/bean-labs/research-logs/2026/04/25/reflexion-language-agents-verbal-reinforcement-learning

[^2645^]: "E2B Documentation," E2B. https://e2b.dev/docs

---

*End of Research Document — Landslide Dimension 05: Self-Modification & Autonomous Evolution*
