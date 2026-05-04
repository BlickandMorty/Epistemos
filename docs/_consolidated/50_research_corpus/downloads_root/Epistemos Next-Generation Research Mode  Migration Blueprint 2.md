# Epistemos Next-Generation Research Mode: Migration Blueprint

## Executive Summary

The old research subsystem and SOAR were removed wholesale — not because the product behavior was wrong, but because the implementation was architecturally incompatible with the Omega tool-calling runtime. The evidence from the live test suite (`ThemePairTests`) makes this explicit: `ResearchState.swift`, `ResearchService.swift`, `SOARDetailView`, `EnrichmentController`, `EpistemicLensPanel`, and every hidden "research assistant" system prompt are now hard-blocked by passing tests. The correct path is not to restore those files — it is to rebuild research *as a first-class Omega task type*, using deterministic tool execution for every step that was previously handled by opaque LLM enrichment chains.

This blueprint gives a precise, file-by-file answer to every question posed.

***

## 1. What the Old Research Mode Did Well

The old research mode encoded three genuinely valuable product behaviors:

- **Structured note creation from web findings.** The user could issue a research intent and receive a structured note — question, findings, citations — already saved in the vault. This closed the loop between browsing and knowledge management.
- **Multi-turn, iterative web traversal.** The enrichment pipeline could follow references across multiple pages, not just the first search result. This was the "depth escalation" behavior — the system recognized that a shallow result required a follow-up query.
- **Pause-and-ask.** When the pipeline hit a dead end (no good sources, conflicting evidence), it surfaced a `ResearchRequest` to the user rather than silently failing or hallucinating. The `ResearchPauseHandler` class — which survived removal — is the direct descendant of this behavior.

## 2. What the Old SOAR System Did Well

SOAR (Socratic, Objective, Adaptive Reasoning) contributed five behaviors that should survive in a new form:

- **Complexity gating.** Before executing, SOAR estimated whether the query was at the "edge of learnability" — too simple to need research, or too ambiguous to proceed without clarification. This prevented the system from launching multi-step pipelines for questions answerable from the vault.
- **Stepping-stone decomposition.** SOAR broke deep research questions into sub-questions, each of which could be independently answered and then composed. This is the right behavior for questions like "What is the current consensus on [topic]?" — they require multiple source passes.
- **Evidence/risk scoring.** Every source was assigned a rough confidence tier (preprint vs. peer-reviewed vs. blog vs. primary data). This directly informed how strongly a finding should be stated in the output note.
- **Contradiction detection.** SOAR compared findings across sources and flagged disagreement. The removed `TruthAssessmentCard` and `ReflectionCard` were the UI artifacts of this logic. The logic itself was valuable.
- **Confidence/dissonance surfacing.** Rather than producing a single confident answer, SOAR could express "two credible sources say opposite things — here is the tension." This made the research output epistemically honest.

## 3. What Should Be Preserved as Product Behavior

The following behaviors should survive, implemented through the Omega tool-calling architecture:

| Behavior | Old Implementation | New Implementation |
|---|---|---|
| Web search | `EnrichmentController` + LLM | `searchweb` tool in SafariAgent |
| Page text extraction | Enrichment pipeline | New `readpagecontent` tool in SafariAgent |
| Save citation | `PaperEntity.swift` (deleted) | New `savecitation` tool in NotesAgent |
| Collect snippet | Enrichment chain | New `collectsnippet` tool in NotesAgent |
| Create structured research note | `ResearchService.swift` (deleted) | New `createresearchnote` tool in NotesAgent |
| Contradiction scan | `TruthAssessmentCard` (deleted) | New `analyzecontradiction` tool |
| Evidence scoring | SOAR confidence logic | New `ResearchEvidenceScorer` service |
| Pause-and-ask | `ResearchPauseHandler` (present) | Wire to research task type |
| Depth escalation | Enrichment pipeline depth | Research plan step count + `ResearchPauseHandler` |
| Stepping-stone decomposition | SOAR planner | Omega planning prompt with research task type |

## 4. What Should Be Discarded as Obsolete Architecture

The following must not be restored, and tests explicitly enforce their absence:

- `ResearchState.swift`, `ResearchService.swift`, `ResearchIntents.swift`, `PaperEntity.swift`, `ResearchTypes.swift` — separate subsystem files blocked by `projectDropsStandaloneResearchSubsystem`.
- `EnrichmentController`, `soarService` wired into `PipelineService` — blocked by `liveRuntimeDropsEnrichmentAndSOARHooks`.
- `EpistemicLensPanel`, `ReflectionCard`, `TruthAssessmentCard`, `ConsensusReportCard` — blocked by `chatChromeDropsEnrichmentPanels`.
- Hidden "research assistant" system prompts injected into note or chat surfaces — blocked by `userFacingAISurfacesDropHiddenPersonas`.
- `SOARDetailView`, `case soar` in Settings — blocked by `settingsAndLandingDropAnalyticalChatChrome`.
- `ResearchModeControl` in ChatInputBar or LandingView — blocked by `chatSurfacesDropResearchModeControl`.
- `isDeepBrief`, `onGoDeepGenerate` in DailyBriefState — blocked by `dailyBriefDropsSecondPassScaffolding`.
- Any separate "enrichment pipeline" that runs outside the Omega tool-execution loop.

**The principle:** nothing that bypasses `OrchestratorState` → `OmegaPlanningService` → `TaskGraph` → agent dispatch is allowed back. All research execution must be visible in `executionLog` and logged to `MCPBridge`.

## 5. How Research Mode Lives Inside Omega

Research mode is a **task type** handled by `OrchestratorState`, not a separate service, state, or surface. The path is:

```
User intent → OrchestratorState.submitTask("research: [query]")
    → OmegaPlanningService (research task type detected)
    → TaskGraph with research-specific step template
    → ConfirmationGate (low risk steps auto-proceed)
    → ResearchOrchestrator (new coordinator, described below)
    → Agent dispatch (SafariAgent, NotesAgent, FileAgent)
    → MCPBridge.logExecution (full trace)
    → ResearchPauseHandler (surface gaps to user)
    → Final note creation via NotesAgent.createresearchnote
```

The `OmegaInferenceBridge.buildPlanningPrompt` already injects all tool schemas into the planning system prompt. A research task type requires only:
1. A new keyword prefix recognized by `OmegaPlanningService` (e.g., `"research:"`, `"find:"`).
2. A research-specific planning prompt block that instructs the planner to decompose into sub-questions before tool calls.
3. A `ResearchOrchestrator` coordinator that sequences the per-question tool call loops.

No new LLM is required. The existing `TriageService` local model performs the planning.

## 6. Architecture Decision: What Form Should Research Take?

**Recommendation: A dedicated Omega task type, surfaced through a hybrid UI.**

The four options are not mutually exclusive, and the right answer uses all four in a layered way:

| Layer | Role |
|---|---|
| **Omega task type** | The execution model. Research tasks are a named class of multi-step plans with a research-specific planning prompt and tool schema subset. This is the primary layer. |
| **OmegaPanel surface** | The primary UI. Research tasks execute inside the existing `OmegaPanel`, which already shows `ExecutionProgressView`, `ConfirmationSheet`, and `ResearchRequestView`. No new panel is needed. |
| **Chat mode entry point** | Secondary entry. Typing `"research [topic]"` or `"/research"` in MiniChatView or ChatInputBar routes to Omega as a task — the same routing used for `"search the web for..."` already in training data. |
| **Result note** | The persistent output. Every research task ends by creating a structured vault note (via `createresearchnote`), which then lives in the normal notes system. |

**What not to build:** a separate Research panel, a ResearchTabBar (blocked by tests), or a standalone Research window. The OmegaPanel already handles everything needed.

## 7. Tool Schema: Required Before Any Training

Every tool below must exist as a registered `OmegaToolDefinition` in `OmegaToolRegistry` before training data is generated. The existing `searchweb` tool satisfies requirement 1.

### 7a. Tools That Already Exist (verify and extend)

```swift
// EXISTING — SafariAgent
OmegaToolDefinition(
    name: "searchweb",
    agent: "safari",
    description: "Search the web via Google in Safari",
    argumentsExample: "{\"query\": \"search terms\"}",
    schemaJson: "{\"type\":\"object\",\"properties\":{\"query\":{\"type\":\"string\"}},\"required\":[\"query\"]}",
    destructive: false, requiresConfirmation: false
)
```

### 7b. New Tools Required in SafariAgent

```swift
OmegaToolDefinition(
    name: "readpagecontent",
    agent: "safari",
    description: "Extract the visible text content of Safari's current tab. Use after openurl or searchweb.",
    argumentsExample: "{\"maxLength\": 4000}",
    schemaJson: "{\"type\":\"object\",\"properties\":{\"maxLength\":{\"type\":\"integer\",\"description\":\"Max characters to return, default 4000\"}}}",
    destructive: false, requiresConfirmation: false
)

OmegaToolDefinition(
    name: "searchpapers",
    agent: "safari",
    description: "Search academic papers on ArXiv or Semantic Scholar",
    argumentsExample: "{\"query\": \"transformer attention mechanisms\", \"source\": \"arxiv\"}",
    schemaJson: "{\"type\":\"object\",\"properties\":{\"query\":{\"type\":\"string\"},\"source\":{\"type\":\"string\",\"enum\":[\"arxiv\",\"semanticscholar\",\"web\"]}},\"required\":[\"query\"]}",
    destructive: false, requiresConfirmation: false
)
```

### 7c. New Tools Required in NotesAgent

```swift
OmegaToolDefinition(
    name: "collectsnippet",
    agent: "notes",
    description: "Save a quoted passage from a source into a research session note",
    argumentsExample: "{\"text\": \"quoted passage\", \"sourceUrl\": \"https://...\", \"sourceTitle\": \"Page Title\", \"sessionNoteId\": \"uuid\"}",
    schemaJson: "{\"type\":\"object\",\"properties\":{\"text\":{\"type\":\"string\"},\"sourceUrl\":{\"type\":\"string\"},\"sourceTitle\":{\"type\":\"string\"},\"sessionNoteId\":{\"type\":\"string\"}},\"required\":[\"text\",\"sourceUrl\"]}",
    destructive: false, requiresConfirmation: false
)

OmegaToolDefinition(
    name: "savecitation",
    agent: "notes",
    description: "Save a formal citation to the vault: title, authors, URL, publication date",
    argumentsExample: "{\"title\": \"Paper Title\", \"authors\": \"Smith et al.\", \"url\": \"https://...\", \"date\": \"2024-01\", \"sessionNoteId\": \"uuid\"}",
    schemaJson: "{\"type\":\"object\",\"properties\":{\"title\":{\"type\":\"string\"},\"authors\":{\"type\":\"string\"},\"url\":{\"type\":\"string\"},\"date\":{\"type\":\"string\"},\"sessionNoteId\":{\"type\":\"string\"}},\"required\":[\"title\",\"url\"]}",
    destructive: false, requiresConfirmation: false
)

OmegaToolDefinition(
    name: "createresearchnote",
    agent: "notes",
    description: "Create a structured research note with question, findings, evidence, contradictions, and citations sections",
    argumentsExample: "{\"question\": \"...\", \"findings\": \"...\", \"evidence\": [...], \"contradictions\": [...], \"citations\": [...]}",
    schemaJson: "{\"type\":\"object\",\"properties\":{\"question\":{\"type\":\"string\"},\"findings\":{\"type\":\"string\"},\"evidence\":{\"type\":\"array\",\"items\":{\"type\":\"string\"}},\"contradictions\":{\"type\":\"array\",\"items\":{\"type\":\"string\"}},\"citations\":{\"type\":\"array\",\"items\":{\"type\":\"string\"}}},\"required\":[\"question\",\"findings\"]}",
    destructive: false, requiresConfirmation: false
)
```

### 7d. New Analysis Tools (can be routed through NotesAgent or a new ResearchAgent)

```swift
OmegaToolDefinition(
    name: "analyzecontradiction",
    agent: "notes",
    description: "Compare two text snippets and return whether they agree, contradict, or are orthogonal",
    argumentsExample: "{\"snippetA\": \"...\", \"snippetB\": \"...\", \"sessionNoteId\": \"uuid\"}",
    schemaJson: "{\"type\":\"object\",\"properties\":{\"snippetA\":{\"type\":\"string\"},\"snippetB\":{\"type\":\"string\"},\"sessionNoteId\":{\"type\":\"string\"}},\"required\":[\"snippetA\",\"snippetB\"]}",
    destructive: false, requiresConfirmation: false
)

OmegaToolDefinition(
    name: "scoreevidence",
    agent: "notes",
    description: "Score the reliability of a source: arxiv preprint, peer-reviewed, news, blog, primary data",
    argumentsExample: "{\"url\": \"https://arxiv.org/...\", \"sourceType\": \"arxiv\"}",
    schemaJson: "{\"type\":\"object\",\"properties\":{\"url\":{\"type\":\"string\"},\"sourceType\":{\"type\":\"string\",\"enum\":[\"arxiv\",\"peer_reviewed\",\"news\",\"blog\",\"primary\",\"unknown\"]}},\"required\":[\"url\"]}",
    destructive: false, requiresConfirmation: false
)
```

### 7e. Rust-side implementations needed

- `readpagecontent` → extend `osascript.rs` with `tell application "Safari" to return (do JavaScript "document.body.innerText" in current tab of first window)`
- `searchpapers` → new Rust tool that constructs an ArXiv or Semantic Scholar URL and calls `toolOpenUrl` + `toolSearchWeb`
- `collectsnippet` / `savecitation` / `createresearchnote` / `analyzecontradiction` / `scoreevidence` → Swift-side logic in NotesAgent (no Rust needed)

## 8. SOAR Repurposed as Research Planning Logic

SOAR must not reappear as a `SOARDetailView` or `soarService` wired into `PipelineService`. It must reappear as a **Swift struct injected into the research planning path**. None of the structs below appear in the blocked test list.

### 8a. Edge-of-Learnability Detection

```swift
// New file: ResearchComplexityGate.swift
struct ResearchComplexityGate {
    /// Returns true if this query warrants a multi-step research plan.
    /// Simple factual queries (score < 0.35) go directly to chat.
    /// Research queries (score >= 0.35) route through OrchestratorState.
    static func requiresResearch(_ query: String) -> Bool {
        let score = TriageService.complexityScore(for: query)
        let hasResearchIntent = query.hasPrefix("research") || 
                                query.hasPrefix("find") ||
                                query.contains("evidence") ||
                                query.contains("contradicts") ||
                                query.contains("sources")
        return score >= 0.35 || hasResearchIntent
    }
}
```

This gates the research path at the chat entry point. It uses `TriageService.complexityScore` which already exists.

### 8b. Stepping-Stone Decomposition

The `OmegaInferenceBridge.buildPlanningPrompt` already constructs a planning prompt. A research task type adds a research-specific block to this prompt:

```swift
// Extension to OmegaInferenceBridge.buildPlanningPrompt
// Insert when taskDescription starts with "research:"
let researchPlanningBlock = """
RESEARCH TASK RULES:
1. Decompose the question into 2-5 sub-questions.
2. For each sub-question: searchweb → readpagecontent → collectsnippet or savecitation.
3. After all sub-questions: analyzecontradiction if sources conflict, then createresearchnote.
4. Total steps: minimum 4, maximum 15. Never plan more than 3 consecutive web reads.
"""
```

### 8c. Contradiction Scan

The `analyzecontradiction` tool (§7d) performs this deterministically. The planning prompt instructs the model to call it when two `collectsnippet` results appear to conflict. The logic inside the tool is simple string comparison + a local LLM call via `TriageService.generateRawLocal` with a two-passage contradiction prompt.

### 8d. Evidence and Risk Scoring

```swift
// New file: ResearchEvidenceScorer.swift
struct ResearchEvidenceScorer {
    enum Tier: String { 
        case primaryData, peerReviewed, arxivPreprint, news, blog, unknown
        var confidence: Double {
            switch self {
            case .primaryData: return 0.95
            case .peerReviewed: return 0.85
            case .arxivPreprint: return 0.70
            case .news: return 0.50
            case .blog: return 0.30
            case .unknown: return 0.20
            }
        }
    }
    
    static func tier(for url: String) -> Tier {
        if url.contains("arxiv.org") { return .arxivPreprint }
        if url.contains("doi.org") || url.contains("pubmed") { return .peerReviewed }
        if url.contains("nature.com") || url.contains("science.org") { return .peerReviewed }
        if url.contains("nytimes") || url.contains("reuters") { return .news }
        return .unknown
    }
}
```

This is deterministic, requires no model call, and feeds directly into the `scoreevidence` tool.

### 8e. Confidence and Dissonance Logic

```swift
// New file: ResearchConfidenceState.swift
struct ResearchConfidenceState {
    var snippets: [(text: String, url: String, confidence: Double)] = []
    var contradictions: [(a: String, b: String, verdict: String)] = []
    
    var overallConfidence: Double {
        guard !snippets.isEmpty else { return 0 }
        return snippets.map(\.confidence).reduce(0, +) / Double(snippets.count)
    }
    
    var hasDissonance: Bool { !contradictions.isEmpty }
    
    /// Returns true when evidence is insufficient and a ResearchPause should fire.
    var requiresPause: Bool {
        overallConfidence < 0.45 || (snippets.count < 2 && !contradictions.isEmpty)
    }
}
```

When `requiresPause` is true, `ResearchOrchestrator` calls `orchestrator.researchPause.requestResearch(questions:context:)` — the existing `ResearchPauseHandler` mechanism already wired to `OmegaPanel`.

### 8f. Research-Depth Escalation

Depth escalation is handled by the step count in the `TaskGraph`. The research planning prompt caps at 15 steps but allows a second planning pass if:
- `ResearchConfidenceState.overallConfidence < 0.45` after the first pass, OR
- `ResearchPauseHandler` receives a user response that extends the scope

The `ResearchOrchestrator` coordinator checks confidence after each sub-question completes and can append new steps to the `TaskGraph` before the final `createresearchnote` step executes.

## 9. Traces to Training Data

The runtime already has a complete trace-to-training pipeline. Research tasks require no new infrastructure — only correct labeling.

### Trace flow:

```
Research task executes
    → MCPBridge.logExecution() — every tool call logged to SQLite
    → TrainingScheduler.pendingODIATraces receives StructuredODIATrace
    → ReasoningTraceLogger.logReasoningChain() — if reasoning loop ran
    → Nightly: TrainingScheduler.onODIASchedulerFired()
    → StructuredODIATraceGenerator.toJSONL() + reasoningLines merged
    → QLoRA training on active adapter
```

### What needs to be added:

1. **Research task label** in `StructuredODIATrace` — add `taskType: "research"` field so research traces can be weighted separately.
2. **Quality signal** — after the user reads the final research note and doesn't discard it, log a positive KTO feedback signal via `KnowledgeFusionViewModel.logFeedback`. This is already wired in principle (the `logFeedback` method exists but has zero callers noted in `KnowledgeFusionViewModel`).
3. **Research-specific training examples** — extend `generate_epistemos_training_data.py` with a `generateResearchWorkflowExamples()` function that generates ODIA traces for the full research pipeline: `searchweb → readpagecontent → collectsnippet → collectsnippet → analyzecontradiction → createresearchnote`.

### Training data format (matches existing ODIA):

```json
{
  "messages": [
    {"role": "system", "content": "You are Epistemos-Nano..."},
    {"role": "user", "content": "research: transformer attention mechanisms vs Mamba-2"},
    {"role": "assistant", "content": "<think>Research task detected. I need to decompose into sub-questions...</think>\n{\"tool\":\"searchweb\",\"arguments\":{\"query\":\"transformer attention mechanisms 2024\"}}"}
  ],
  "category": "research",
  "taskType": "research",
  "layer": 16
}
```

**Critical rule:** Generate training data *after* the tools exist and have been tested manually. Do not generate training data for tools that don't exist yet. Do not train first and fix the app later.

## 10. Tests That Block the Old Feature Shape and Safe Replacements

The following tests must remain passing. They guard against the re-introduction of removed architecture.

### Tests and their exact guards:

| Test | What it blocks | Safe replacement |
|---|---|---|
| `chatSurfacesDropResearchModeControl` | `struct ResearchModeControl` in ChatView/ChatInputBar | Route via `orchestrator.submitTask("research: ...")` — no UI struct needed |
| `settingsAndLandingDropAnalyticalChatChrome` | `case soar`, `SOARDetailView`, `Confidence`, `evidence grades` in Settings/Landing | New SOAR logic lives in `ResearchComplexityGate.swift`, `ResearchEvidenceScorer.swift` — not in Settings |
| `liveRuntimeDropsEnrichmentAndSOARHooks` | `EnrichmentController`, `soarService`, `skipEnrichment`, `onEnriched` in PipelineService | New research coordination in `ResearchOrchestrator.swift`, wired through `OrchestratorState` |
| `chatChromeDropsEnrichmentPanels` | `EpistemicLensPanel`, `ReflectionCard`, `TruthAssessmentCard`, `ConsensusReportCard` | Contradiction/evidence output appears *in the research note* (vault), not in the chat chrome |
| `projectDropsStandaloneResearchSubsystem` | `ResearchState.swift`, `ResearchService.swift`, `ResearchIntents.swift`, `PaperEntity.swift`, `ResearchTypes.swift` in pbxproj | New files: `ResearchOrchestrator.swift`, `ResearchEvidenceScorer.swift`, `ResearchConfidenceState.swift`, `ResearchComplexityGate.swift` — none of these names are blocked |
| `userFacingAISurfacesDropHiddenPersonas` | `"research assistant"` system prompt strings | No system prompt injection — research runs through Omega planning which is already system-prompt-free |
| `dailyBriefDropsSecondPassScaffolding` | `isDeepBrief`, `onGoDeepGenerate` in DailyBriefState | Research mode is entirely separate from DailyBriefState |

### How to add new tests for the new system:

Add these tests to `ThemePairTests` (or a new `ResearchModeTests.swift`):

```swift
// Verify research tools are registered
func researchToolsAreRegistered() {
    let names = OmegaToolRegistry.all.map(\.name)
    expect(names.contains("readpagecontent"))
    expect(names.contains("collectsnippet"))
    expect(names.contains("savecitation"))
    expect(names.contains("createresearchnote"))
    expect(names.contains("analyzecontradiction"))
    expect(names.contains("scoreevidence"))
}

// Verify research complexity gate works
func complexityGateRoutesResearchQueries() {
    expect(ResearchComplexityGate.requiresResearch("research transformer architectures"))
    expect(!ResearchComplexityGate.requiresResearch("what time is it"))
}

// Verify no hidden research system prompts exist
func researchOrchestrationUsesOmegaPlanningOnly() throws {
    let orchestrator = try loadTextFile("Epistemos/Omega/ResearchOrchestrator.swift")
    expect(!orchestrator.contains("You are a research assistant"))
    expect(!orchestrator.contains("research assistant"))
}
```

***

## Final Architecture

### Component Map

```
OmegaPanel (UI)
    ├── TaskInputBar ─── "research: [query]" entry point
    ├── ExecutionProgressView ─── shows step-by-step research progress
    ├── ResearchRequestView ─── pause-and-ask (already wired)
    └── ConfirmationSheet ─── for any medium/high-risk steps

OrchestratorState (runtime coordinator)
    ├── OmegaPlanningService ─── detects "research" task type
    │       └── ResearchComplexityGate ─── gates entry (NEW)
    ├── TaskGraph ─── DAG of research steps
    ├── ResearchOrchestrator ─── (NEW) coordinates research loop
    │       ├── ResearchConfidenceState ─── tracks evidence quality (NEW)
    │       └── ResearchEvidenceScorer ─── URL-to-confidence tier (NEW)
    ├── ConfirmationGate ─── low-risk steps auto-proceed
    └── ResearchPauseHandler ─── surfaces knowledge gaps

Agent Layer
    ├── SafariAgent ─── searchweb (existing) + readpagecontent + searchpapers (NEW)
    └── NotesAgent ─── createnote (existing) + collectsnippet + savecitation
                       + createresearchnote + analyzecontradiction + scoreevidence (NEW)

Rust Tool Layer (omega-mcp)
    └── osascript.rs ─── extend with getpagetext AppleScript call (NEW)

Training Pipeline
    ├── MCPBridge ─── logs every research tool call (existing)
    ├── TrainingScheduler ─── ODIA nightly training (existing)
    ├── ReasoningTraceLogger ─── think/critique traces (existing)
    └── generate_epistemos_training_data.py ─── add research layer 16 (NEW)
```

***

## UI Proposal

Research execution is fully visible in the existing `OmegaPanel`. No new window is required.

**Entry points:**
- `OmegaPanel` → `TaskInputBar`: type `"research [query]"` or `"find evidence for [claim]"`
- `MiniChatView`: typing `"/research [query]"` or natural language that triggers `ResearchComplexityGate`
- Keyboard shortcut: `Cmd+Shift+R` → opens `OmegaPanel` with research prefix pre-filled

**Execution view (inside OmegaPanel ExecutionProgressView):**
- Each step shows: step name + tool icon + status (planning / executing / done / failed)
- Snippet collection steps show a small inline preview of the collected text
- Contradiction detection steps show a two-column diff

**Output:**
- Final research note auto-opens in the note editor after `createresearchnote` succeeds
- Note structure: `# [Question]\n## Findings\n## Evidence\n## Contradictions\n## Citations`
- The note is a normal vault note — searchable, editable, graph-linked

**Research pause UI (existing `ResearchRequestView`):**
- Already shown in `OmegaPanel` when `orchestrator.researchPause.isPaused`
- Shows the question list, accepts user text input, continues execution

***

## Persistence Model

| Data | Storage | Notes |
|---|---|---|
| Research session snippets | Vault note (via `collectsnippet` tool) | Normal `SDPage`, saved by `VaultSyncService` |
| Citations | Vault note (via `savecitation` tool) | Appended to session note body |
| Final research note | Vault note (via `createresearchnote` tool) | Structured markdown, auto-indexed by FTS5 |
| Tool execution log | `omega-executions.db` via `MCPBridge` | SQLite, queried for training |
| ODIA training traces | `TrainingScheduler.pendingODIATraces` | In-memory until nightly flush |
| Evidence scores | `ResearchConfidenceState` (in-memory) | Not persisted — recomputed per session |

***

## Event and Trace Model

Every research task produces the following trace chain in `MCPBridge`:

```
{ toolName: "searchweb",       arguments: {query: "..."}, success: true,  durationMs: 1200 }
{ toolName: "readpagecontent", arguments: {maxLength: 4000}, success: true, durationMs: 800 }
{ toolName: "collectsnippet",  arguments: {text: "...", sourceUrl: "..."}, success: true }
{ toolName: "searchweb",       arguments: {query: "..."}, success: true }  // second sub-question
{ toolName: "readpagecontent", ... }
{ toolName: "collectsnippet",  ... }
{ toolName: "analyzecontradiction", arguments: {snippetA: "...", snippetB: "..."}, ... }
{ toolName: "createresearchnote",   arguments: {question: "...", findings: "..."}, ... }
```

Each entry is a `StructuredODIATrace` with `taskType: "research"`. After nightly training, these become research-execution examples in the LoRA adapter.

***

## SOAR Integration Model

SOAR is reborn as three stateless Swift types, injected into the research planning path:

| SOAR Concept | New Type | Location | Method |
|---|---|---|---|
| Edge-of-learnability | `ResearchComplexityGate` | Called by chat input handler | `requiresResearch(_:)` |
| Stepping-stone decomp | Research planning prompt block | `OmegaInferenceBridge` extension | Injected when task type = research |
| Contradiction scan | `analyzecontradiction` tool | `NotesAgent` | Tool call in research plan |
| Evidence/risk scoring | `ResearchEvidenceScorer` | Called by `scoreevidence` tool | `tier(for:)` |
| Confidence/dissonance | `ResearchConfidenceState` | `ResearchOrchestrator` | `requiresPause` property |
| Depth escalation | `ResearchOrchestrator.appendSteps()` | Mid-execution step injection | Called when confidence < 0.45 |

***

## File-by-File Implementation Sequence

### Phase 1 — Do Now (tools before training, days 1–5)

| Order | File | Action |
|---|---|---|
| 1 | `omega-mcp/src/osascript.rs` | Add `tool_get_page_text()` — AppleScript to extract `document.body.innerText` |
| 2 | `Epistemos/Omega/Agents/SafariAgent.swift` | Add `readpagecontent`, `searchpapers` cases to `execute(step:)` |
| 3 | `Epistemos/Omega/MCPBridge.swift` | Register `readpagecontent`, `searchpapers` in `OmegaToolRegistry.all` |
| 4 | `Epistemos/Omega/Agents/NotesAgent.swift` | Add `collectsnippet`, `savecitation`, `createresearchnote`, `analyzecontradiction`, `scoreevidence` cases |
| 5 | `Epistemos/Omega/MCPBridge.swift` | Register all 5 new NotesAgent tools in `OmegaToolRegistry.all` |
| 6 | `Epistemos/Omega/ResearchEvidenceScorer.swift` | New file — URL-to-tier mapping, no external dependencies |
| 7 | `Epistemos/Omega/ResearchConfidenceState.swift` | New file — confidence accumulator, `requiresPause` logic |
| 8 | `Epistemos/Omega/ResearchComplexityGate.swift` | New file — wraps `TriageService.complexityScore` |
| 9 | `Epistemos/Omega/OmegaInferenceBridge.swift` | Extend `buildPlanningPrompt` to inject research planning block when task starts with `"research"` |
| 10 | `Epistemos/Omega/ResearchOrchestrator.swift` | New file — coordinates multi-pass research loop, calls `ResearchPauseHandler` when `requiresPause` |

### Phase 2 — Do Now (wiring, days 6–8)

| Order | File | Action |
|---|---|---|
| 11 | `Epistemos/App/AppBootstrap.swift` | Create `ResearchOrchestrator`, inject into `OrchestratorState.registerAgents` |
| 12 | `Epistemos/Omega/OrchestratorState.swift` | Add `researchOrchestrator: ResearchOrchestrator?` property, call in `submitTask` when research task type detected |
| 13 | `Epistemos/Views/Chat/ChatInputBar.swift` | Detect `/research` prefix and route to `orchestrator.submitTask` (no new UI struct — no test violation) |
| 14 | `Epistemos/Views/MiniChat/MiniChatView.swift` | Same — detect research intent prefix, route to Omega |
| 15 | `Epistemos/Views/Omega/OmegaPanel.swift` | Add quick action button "Research a topic" to `idleView.quickActionButton` array |

### Phase 3 — Do Later (training data, days 9–12)

| Order | File | Action |
|---|---|---|
| 16 | `generate_epistemos_training_data.py` | Add `generateResearchWorkflowExamples()` — layer 16, ODIA format, all 7 research tools |
| 17 | `fill_training_gaps.py` | Add research category to gap filler |
| 18 | `Epistemos/Training/TrainingScheduler.swift` | Add `taskType: "research"` label to ODIA trace ingestion |
| 19 | `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` | Wire `KnowledgeFusionViewModel.logFeedback` to note accept/discard for research notes (enables KTO) |
| 20 | New: `Tests/ResearchModeTests.swift` | Tool registration tests, complexity gate tests, no-hidden-persona tests |

***

## "Do Now" vs. "Do Later" Split

### Do Now (deterministic code, no model required)

- All 7 new tools registered and implemented (§7b–7d)
- Rust `tool_get_page_text` implementation
- `ResearchEvidenceScorer`, `ResearchConfidenceState`, `ResearchComplexityGate`
- `ResearchOrchestrator` coordinator
- Planning prompt extension in `OmegaInferenceBridge`
- Chat input routing (`/research` prefix)
- OmegaPanel quick action button
- Bootstrap wiring
- New test assertions for tool registration

### Do Later (after tools ship and have been manually tested)

- `generateResearchWorkflowExamples()` in training data generator
- `taskType: "research"` label in ODIA traces
- KTO feedback wiring for research notes
- Nightly ODIA training run with research traces
- `ResearchModeTests.swift` suite expansion

### Never Do

- Restore `ResearchState.swift`, `ResearchService.swift`, or any file blocked by existing tests
- Wire `soarService` or `EnrichmentController` into `PipelineService`
- Create `SOARDetailView`, `EpistemicLensPanel`, or confidence overlay UI
- Inject hidden research assistant system prompts
- Train the model before the tools exist in code