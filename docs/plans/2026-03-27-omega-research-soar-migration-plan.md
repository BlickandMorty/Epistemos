# Omega Research Mode & SOAR Migration Plan

**Date:** 2026-03-27
**Status:** APPROVED FOR EXECUTION
**Scope:** Rebuild research as a first-class Omega task type; resurrect SOAR as internal evidence-quality logic

---

## 1. Executive Decision

Research Mode returns as an **Omega task type** routed through `OrchestratorState -> OmegaPlanningService -> TaskGraph -> agent dispatch -> MCPBridge logging`. It is NOT a separate subsystem, NOT a standalone window, and NOT wired into the plain chat pipeline.

SOAR returns as **three stateless Swift structs** (`ResearchComplexityGate`, `ResearchEvidenceScorer`, `ResearchConfidenceState`) plus a **coordinator** (`ResearchOrchestrator`) that sequences the research loop. None of these names appear in ThemePairTests blocked strings. SOAR does NOT return as `SOARDetailView`, `soarService`, `SOARState`, or any chat chrome.

The standard chat path (`ChatInputBar -> ChatState -> PipelineService -> TriageService`) stays untouched. Research enters exclusively through Omega: either via `OmegaPanel`'s TaskInputBar, or by routing from chat/minichat when a `/research` prefix or research-intent keyword is detected. The routing goes to `orchestrator.submitTask()`, not to `PipelineService`.

**Code-now, train-later.** All 7 new tools must be registered, implemented, and manually tested before any training data is generated. The existing TriageService local model (Qwen 3.5 4B) handles planning. No new model is required.

---

## 2. Salvage vs Replace Matrix

### Salvage (behavior preserved, implementation rewritten)

| Old Behavior | Old File | New Implementation |
|---|---|---|
| Web search for research | `EnrichmentController` | `search_web` tool (already exists in SafariAgent) |
| Page text extraction | Enrichment pipeline | New `readpagecontent` tool in SafariAgent |
| Semantic Scholar paper search | `ResearchService.searchPapers()` | New `searchpapers` tool in SafariAgent |
| Edge-of-learnability detection | `SOARDetector.analyzeEdge()` | `ResearchComplexityGate.requiresResearch()` |
| Stepping-stone decomposition | `SOARTeacher.generateCurriculum()` | Research planning prompt block in OmegaInferenceBridge |
| Evidence scoring (Tier 1-5) | `EnrichmentController` Pass 2 preamble | `ResearchEvidenceScorer.tier(for:)` |
| Contradiction detection | `ContradictionDetector` (SOAR) | `analyzecontradiction` tool in NotesAgent |
| Confidence/dissonance tracking | `SOARRewardCalculator` | `ResearchConfidenceState.requiresPause` |
| Pause-and-ask on dead ends | `ResearchPauseHandler` (survived removal) | Wire to `ResearchOrchestrator` (already functional) |
| Structured research note output | `ResearchService` paper review output | `createresearchnote` tool in NotesAgent |
| Save citation with provenance | `PaperEntity.swift` | `savecitation` tool in NotesAgent |
| Collect snippet from source | Enrichment pipeline | `collectsnippet` tool in NotesAgent |
| Epistemic tagging | `[DATA]`/`[MODEL]`/`[UNCERTAIN]`/`[CONFLICT]` tags | Preserved in research planning prompt instructions |
| Multi-round search refinement | `ResearchService.noveltyCheck()` | TaskGraph step iteration + depth escalation |

### Replace (architecture dead, must not return)

| Old Architecture | Why It Died | Enforcement |
|---|---|---|
| `ResearchState.swift` / `ResearchService.swift` | Standalone subsystem outside Omega | `projectDropsStandaloneResearchSubsystem` test |
| `EnrichmentController` wired into `PipelineService` | Polluted standard chat path | `liveRuntimeDropsEnrichmentAndSOARHooks` test |
| `soarService` / `SOARState` in `AppBootstrap` | Separate state outside orchestrator | `liveRuntimeDropsEnrichmentAndSOARHooks` test |
| `SOARDetailView` / `case soar` in Settings | Legacy chat chrome | `settingsAndLandingDropAnalyticalChatChrome` test |
| `EpistemicLensPanel` / `ReflectionCard` / `TruthAssessmentCard` | Enrichment-era cards | `chatChromeDropsEnrichmentPanels` test |
| `ResearchModeControl` struct in ChatInputBar | Standalone research UI | `chatSurfacesDropResearchModeControl` test |
| Hidden "research assistant" system prompts | Persona injection | `userFacingAISurfacesDropHiddenPersonas` test |
| `isDeepBrief` / `onGoDeepGenerate` in DailyBriefState | Two-pass brief scaffolding | `dailyBriefDropsSecondPassScaffolding` test |
| 6-pass sequential LLM enrichment | Too slow, context-expensive | Architectural decision |
| 15+ LLM calls per SOAR session | Impractical for local models | Architectural decision |
| Fake time-based progress UI (`ResearchThinkingView`) | Deceptive, disconnected from actual work | Architectural decision |
| Brace-matching JSON extraction heuristic | Fragile; constrained decoding (Omega 11) replaces this | Architectural decision |
| Heuristic confidence estimation ("however" = -0.05) | Unreliable proxies | Architectural decision |

### Discard (no equivalent needed)

| Old Component | Why Not Needed |
|---|---|
| `ResearchIntents.swift` (Siri shortcuts) | Defer until research mode is stable; Siri intents are a polish item |
| `ResearchView.swift` (1400-line monolithic tab view) | OmegaPanel already provides the execution surface |
| `ResearchThinkingView.swift` (fake progress) | `ExecutionProgressView` shows real step-by-step progress |
| `SOARTeacher` template stones (10 pedagogical patterns) | Planning prompt replaces this with LLM-generated decomposition |
| `SOARStudent` heuristic metrics | ToolResult confidence from agents replaces this |
| `EnrichmentController` Pass 3-6 (layman, reflection, arbitration, truth assessment) | Single `createresearchnote` tool produces structured output |

---

## 3. What To Add To The Product Roadmap

### Omega Phase Update

| Phase | Addition | Rationale |
|---|---|---|
| Omega 18.5 (new) | **Research Mode MVP** | Tools + orchestrator + planning prompt + OmegaPanel wiring |
| Omega 19 | Research traces in ODIA training | After tools are manually tested |
| Omega 20 | Research LoRA adapter | After traces accumulate from real usage |

### Roadmap Items

1. **7 new Omega tools** registered in `OmegaToolRegistry` (Phase 1)
2. **`ResearchOrchestrator`** coordinator for multi-pass research loops (Phase 1)
3. **3 SOAR structs** for complexity gating, evidence scoring, confidence tracking (Phase 1)
4. **Research planning prompt block** in `OmegaInferenceBridge` (Phase 1)
5. **Chat/MiniChat routing** to Omega for research-intent queries (Phase 2)
6. **OmegaPanel quick action** for research (Phase 2)
7. **Research training data generation** (Phase 3, train-later)
8. **KTO feedback wiring** for research notes (Phase 3, train-later)

---

## 4. Code-Now vs Train-Later Split

### Code-Now (deterministic, no model dependency)

| Priority | Item | Rationale |
|---|---|---|
| P0 | Register 7 new tools in `OmegaToolRegistry` | Tools must exist before anything else |
| P0 | Implement `readpagecontent` in Rust (`osascript.rs`) | Core data acquisition capability |
| P0 | Implement `searchpapers` in SafariAgent | Academic search via Semantic Scholar URL |
| P0 | Implement `collectsnippet`, `savecitation`, `createresearchnote` in NotesAgent | Core research output tools |
| P0 | Implement `analyzecontradiction`, `scoreevidence` in NotesAgent | Evidence quality tools |
| P1 | `ResearchEvidenceScorer` (URL-to-tier, deterministic) | No LLM needed |
| P1 | `ResearchConfidenceState` (confidence accumulator) | No LLM needed |
| P1 | `ResearchComplexityGate` (wraps `TriageService.complexityScore`) | No LLM needed |
| P1 | `ResearchOrchestrator` (coordinates multi-pass loop) | Core coordinator |
| P1 | Research planning prompt block in `OmegaInferenceBridge` | Enables LLM to plan research |
| P2 | Wire `ResearchOrchestrator` into `OrchestratorState.submitTask()` | Route research tasks |
| P2 | Chat/MiniChat `/research` prefix routing | Entry points |
| P2 | OmegaPanel quick action button | Discoverability |
| P2 | Bootstrap wiring in `AppBootstrap` | Lifecycle management |
| P2 | Test assertions for tool registration + complexity gate | Safety net |

### Train-Later (after tools ship and are manually tested)

| Priority | Item | Rationale |
|---|---|---|
| P3 | `taskType: "research"` label in `StructuredODIATrace` | Training data labeling |
| P3 | `generateResearchWorkflowExamples()` in training data generator | Synthetic training data |
| P3 | KTO feedback wiring for research notes | User preference signal |
| P3 | Research category in `fill_training_gaps.py` | Gap coverage |
| P3 | Nightly ODIA training with research traces | Model improvement |

### Never (enforced by tests)

- Restore `ResearchState.swift`, `ResearchService.swift`, `ResearchIntents.swift`, `PaperEntity.swift`, `ResearchTypes.swift`
- Wire `soarService` or `EnrichmentController` into `PipelineService`
- Create `SOARDetailView`, `EpistemicLensPanel`, or confidence overlay UI
- Inject hidden "research assistant" system prompts
- Add `ResearchModeControl` struct to ChatInputBar or LandingView

---

## 5. Target Runtime Architecture

### Task Flow

```
User intent
    -> Chat/MiniChat detects "/research" prefix or research keywords
    -> orchestrator.submitTask("research: [query]")

OR

    -> OmegaPanel TaskInputBar: "research [query]"
    -> orchestrator.submitTask("research: [query]")

THEN

OrchestratorState.submitTask()
    -> ResearchComplexityGate.requiresResearch(query) [optional fast-path gate]
    -> OmegaPlanningService.generatePlan()
        -> OmegaInferenceBridge.buildPlanningPrompt() [injects research planning block]
        -> TriageService.generateRawLocal() [Qwen 3.5 4B, thinking mode]
    -> ToolCallParser.parse() -> [AgentStep]
    -> TaskGraph populated with research-specific steps

OrchestratorState.executePlan()
    -> For each ready step:
        -> ConfirmationGate (low-risk auto-proceed)
        -> Agent dispatch (SafariAgent or NotesAgent)
        -> MCPBridge.logExecution() [full trace to SQLite]
        -> contextualizedStep() pipes output to dependent steps
        -> If confidence < 0.8: ResearchPauseHandler fires
    -> ResearchOrchestrator monitors ResearchConfidenceState
        -> If overall confidence < 0.45 after pass: request depth escalation
        -> If contradictions found: trigger analyzecontradiction tool
    -> Final step: createresearchnote -> note auto-opens in editor
```

### Component Map

```
OmegaPanel (UI, existing)
    +-- TaskInputBar ---------- "research: [query]" entry point (existing)
    +-- ExecutionProgressView -- shows step-by-step research progress (existing)
    +-- ResearchRequestView ---- pause-and-ask (existing, functional)
    +-- ConfirmationSheet ------ for medium/high-risk steps (existing)

OrchestratorState (runtime coordinator, existing)
    +-- OmegaPlanningService --- detects "research:" task type (extend)
    |       +-- ResearchComplexityGate --- gates entry (NEW)
    +-- TaskGraph --------------- DAG of research steps (existing)
    +-- ResearchOrchestrator ---- coordinates research loop (NEW)
    |       +-- ResearchConfidenceState -- tracks evidence quality (NEW)
    |       +-- ResearchEvidenceScorer --- URL-to-confidence tier (NEW)
    +-- ConfirmationGate -------- low-risk steps auto-proceed (existing)
    +-- ResearchPauseHandler ---- surfaces knowledge gaps (existing)

Agent Layer
    +-- SafariAgent
    |       +-- search_web ----------- (existing)
    |       +-- open_url ------------- (existing)
    |       +-- get_page_url --------- (existing)
    |       +-- get_page_title ------- (existing)
    |       +-- readpagecontent ------ (NEW)
    |       +-- searchpapers --------- (NEW)
    +-- NotesAgent
    |       +-- create_note ---------- (existing)
    |       +-- edit_note ------------ (existing)
    |       +-- search_notes --------- (existing)
    |       +-- list_notes ----------- (existing)
    |       +-- collectsnippet ------- (NEW)
    |       +-- savecitation --------- (NEW)
    |       +-- createresearchnote --- (NEW)
    |       +-- analyzecontradiction - (NEW)
    |       +-- scoreevidence -------- (NEW)

Rust Tool Layer (omega-mcp)
    +-- osascript.rs --- extend with getpagetext AppleScript call (NEW)

Training Pipeline (existing, extend later)
    +-- MCPBridge ------------ logs every research tool call (existing)
    +-- TrainingScheduler ---- ODIA nightly training (existing)
    +-- ReasoningTraceLogger - think/critique traces (existing)
```

### Data Flow Between Steps

The existing `contextualizedStep()` method in `OrchestratorState` (lines 224-267) already handles dependency injection:

```
Step 1: search_web(query: "transformer attention vs Mamba-2")
    -> output: search results page loaded

Step 2: readpagecontent(maxLength: 4000)  [depends on Step 1]
    -> _context: [{step_description: "search...", output: "..."}]
    -> output: extracted page text

Step 3: collectsnippet(text: "...", sourceUrl: "...")  [depends on Step 2]
    -> _context: [{step_description: "read...", output: "...text..."}]
    -> output: snippet saved to session note

Step 4: scoreevidence(url: "https://arxiv.org/...", sourceType: "arxiv")
    -> output: {tier: "arxivPreprint", confidence: 0.70}

Step 5: search_web(query: "Mamba-2 selective scan limitations")  [sub-question 2]
    -> output: search results

Step 6: readpagecontent(maxLength: 4000)  [depends on Step 5]
    -> output: page text

Step 7: collectsnippet(...)  [depends on Step 6]
    -> output: second snippet saved

Step 8: analyzecontradiction(snippetA: "...", snippetB: "...")  [depends on Steps 3, 7]
    -> _context: [{output from step 3}, {output from step 7}]
    -> output: {verdict: "contradict", explanation: "..."}

Step 9: createresearchnote(question: "...", findings: "...", contradictions: [...])
    -> output: note created, auto-opens in editor
```

---

## 6. Tool Contract Plan

### 6a. Existing Tools (no changes needed)

| Tool | Agent | Schema | Status |
|---|---|---|---|
| `search_web` | safari | `{query: string}` | Exists, verified |
| `open_url` | safari | `{url: string}` | Exists, verified |
| `get_page_url` | safari | `{}` | Exists, verified |
| `get_page_title` | safari | `{}` | Exists, verified |
| `create_note` | notes | `{title: string, body?: string}` | Exists, verified |
| `edit_note` | notes | `{id: string, body?: string}` | Exists, verified |
| `search_notes` | notes | `{query: string}` | Exists, verified |
| `list_notes` | notes | `{}` | Exists, verified |

### 6b. New SafariAgent Tools

**`readpagecontent`**
```json
{
  "name": "readpagecontent",
  "agent": "safari",
  "description": "Extract the visible text content of Safari's current tab. Use after open_url or search_web.",
  "schemaJson": {
    "type": "object",
    "properties": {
      "maxLength": {
        "type": "integer",
        "description": "Max characters to return, default 4000"
      }
    }
  },
  "destructive": false,
  "requiresConfirmation": false
}
```
**Rust implementation:** Extend `osascript.rs` with `tool_get_page_text()` that executes:
```applescript
tell application "Safari" to return (do JavaScript "document.body.innerText" in current tab of first window)
```
Truncate result to `maxLength` characters. Return `{success: true, text: "...", charCount: N}`.

**`searchpapers`**
```json
{
  "name": "searchpapers",
  "agent": "safari",
  "description": "Search academic papers on Semantic Scholar. Returns titles, authors, year, citation count.",
  "schemaJson": {
    "type": "object",
    "properties": {
      "query": {"type": "string"},
      "limit": {"type": "integer", "description": "Max results, default 5"},
      "yearMin": {"type": "integer", "description": "Minimum publication year"}
    },
    "required": ["query"]
  },
  "destructive": false,
  "requiresConfirmation": false
}
```
**Implementation:** Swift-side in SafariAgent. Constructs Semantic Scholar API URL (`https://api.semanticscholar.org/graph/v1/paper/search?query=...&fields=title,authors,year,citationCount,externalIds,abstract&limit=5`). Uses `URLSession` directly (no browser needed). Parses JSON response. Returns structured results array. Falls back to `search_web` + `open_url` to `scholar.google.com` if API fails.

**Decision:** `searchpapers` should be Swift-side HTTP, not osascript. The old `ResearchService` used `URLSession` for Semantic Scholar and it worked well. No reason to route through Safari.

### 6c. New NotesAgent Tools

**`collectsnippet`**
```json
{
  "name": "collectsnippet",
  "agent": "notes",
  "description": "Save a quoted passage from a source into a research session note",
  "schemaJson": {
    "type": "object",
    "properties": {
      "text": {"type": "string"},
      "sourceUrl": {"type": "string"},
      "sourceTitle": {"type": "string"},
      "sessionNoteId": {"type": "string"}
    },
    "required": ["text", "sourceUrl"]
  },
  "destructive": false,
  "requiresConfirmation": false
}
```
**Implementation:** If `sessionNoteId` provided, append snippet as blockquote to existing note via `edit_note` path. If not, create a new session note via `create_note` path and return its ID. Snippet format: `> {text}\n> -- [{sourceTitle}]({sourceUrl})\n\n`.

**`savecitation`**
```json
{
  "name": "savecitation",
  "agent": "notes",
  "description": "Save a formal citation to the vault: title, authors, URL, publication date",
  "schemaJson": {
    "type": "object",
    "properties": {
      "title": {"type": "string"},
      "authors": {"type": "string"},
      "url": {"type": "string"},
      "date": {"type": "string"},
      "sessionNoteId": {"type": "string"}
    },
    "required": ["title", "url"]
  },
  "destructive": false,
  "requiresConfirmation": false
}
```
**Implementation:** Appends formatted citation to session note's `## Citations` section. Format: `- {authors} ({date}). [{title}]({url})`. Deduplicates by URL within the note body before appending.

**`createresearchnote`**
```json
{
  "name": "createresearchnote",
  "agent": "notes",
  "description": "Create a structured research note with question, findings, evidence, contradictions, and citations sections",
  "schemaJson": {
    "type": "object",
    "properties": {
      "question": {"type": "string"},
      "findings": {"type": "string"},
      "evidence": {"type": "array", "items": {"type": "string"}},
      "contradictions": {"type": "array", "items": {"type": "string"}},
      "citations": {"type": "array", "items": {"type": "string"}}
    },
    "required": ["question", "findings"]
  },
  "destructive": false,
  "requiresConfirmation": false
}
```
**Implementation:** Creates a new `SDPage` via `vaultSync.createPage()` with structured markdown body:
```markdown
# {question}

## Findings
{findings}

## Evidence
- {evidence[0]}
- {evidence[1]}
...

## Contradictions
- {contradictions[0]}
...

## Citations
- {citations[0]}
...
```
Returns `{success: true, pageId: "...", title: "Research: {question}"}`. The note is a normal vault note -- searchable, editable, graph-linked via wikilinks.

**`analyzecontradiction`**
```json
{
  "name": "analyzecontradiction",
  "agent": "notes",
  "description": "Compare two text snippets and return whether they agree, contradict, or are orthogonal",
  "schemaJson": {
    "type": "object",
    "properties": {
      "snippetA": {"type": "string"},
      "snippetB": {"type": "string"},
      "sessionNoteId": {"type": "string"}
    },
    "required": ["snippetA", "snippetB"]
  },
  "destructive": false,
  "requiresConfirmation": false
}
```
**Implementation:** Two-tier approach:
1. **Deterministic heuristic first:** Check for direct negation patterns (e.g., "$X is Y" vs "$X is not Y"), numerical contradictions (differing quantities for same subject). Fast, no LLM call.
2. **LLM fallback:** If heuristic is inconclusive, call `triageService.generateRawLocal()` with a two-passage contradiction prompt. Parse response for verdict: `agree` / `contradict` / `orthogonal` with explanation.

Returns `{verdict: "contradict", explanation: "...", confidence: 0.85}`.

**`scoreevidence`**
```json
{
  "name": "scoreevidence",
  "agent": "notes",
  "description": "Score the reliability of a source: arxiv preprint, peer-reviewed, news, blog, primary data",
  "schemaJson": {
    "type": "object",
    "properties": {
      "url": {"type": "string"},
      "sourceType": {
        "type": "string",
        "enum": ["arxiv", "peer_reviewed", "news", "blog", "primary", "unknown"]
      }
    },
    "required": ["url"]
  },
  "destructive": false,
  "requiresConfirmation": false
}
```
**Implementation:** Purely deterministic. Uses `ResearchEvidenceScorer.tier(for:)` (URL pattern matching). Returns `{tier: "arxivPreprint", confidence: 0.70, domain: "arxiv.org"}`. No LLM call.

### 6d. Tool Count Summary

| Agent | Existing | New | Total |
|---|---|---|---|
| Safari | 4 | 2 | 6 |
| Notes | 4 | 5 | 9 |
| File | 5 | 0 | 5 |
| Terminal | 1 | 0 | 1 |
| Automation | 6 | 0 | 6 |
| **Total** | **20** | **7** | **27** |

---

## 7. SOAR Redesign Plan

SOAR lives as **Swift orchestration logic** -- three stateless structs plus a coordinator. None of these are agents, services, or UI components. They are internal logic called by `OrchestratorState` and `ResearchOrchestrator`.

### 7a. ResearchComplexityGate (Edge-of-Learnability)

**Location:** `Epistemos/Omega/ResearchComplexityGate.swift` (NEW)

**Purpose:** Determines whether a query warrants a multi-step research plan or can be answered by normal chat.

**Logic:**
```
Input: query string
Output: Bool (requiresResearch)

1. Check explicit prefix: "research", "find evidence", "investigate", "what does the literature say"
   -> If match: return true

2. Calculate complexity via TriageService (already exists):
   - Uses existing baseComplexity + queryComplexity scoring
   - Threshold: score >= 0.55 (between "moderate" and "heavy")

3. Check research-intent keywords: "sources", "contradicts", "evidence", "peer-reviewed",
   "studies show", "according to", "citation", "paper", "literature"
   -> If 2+ keywords: return true

4. Default: return false
```

**Key design choice:** This gate is ADVISORY. It's used by chat/minichat routing to suggest Omega, but users can always submit directly to OmegaPanel's TaskInputBar without gating.

**What it preserves from old SOAR:** `SOARDetector.analyzeEdge()` concept -- the "edge of learnability" probe. Simplified from the old system's 15+ heuristic signals to a clean 3-check gate.

### 7b. Stepping-Stone Decomposition (Planning Prompt)

**Location:** Extension to `OmegaInferenceBridge.buildPlanningPrompt()` in `OmegaInferenceBridge.swift`

**Purpose:** When task description starts with "research:", inject a research-specific planning block that instructs the planner to decompose into sub-questions before tool calls.

**Planning Block:**
```
RESEARCH TASK RULES:
1. Decompose the research question into 2-5 sub-questions that together answer the main question.
2. For each sub-question, plan this sequence: search_web -> readpagecontent -> collectsnippet.
3. For academic topics, use searchpapers instead of search_web for at least one sub-question.
4. After collecting snippets from 2+ sources, use scoreevidence for each source URL.
5. If two snippets appear to conflict, use analyzecontradiction to compare them.
6. End with createresearchnote to synthesize all findings.
7. Total steps: minimum 6, maximum 20. Never plan more than 3 consecutive web reads without a collectsnippet.
8. Use savecitation for any source that contributes to the final note.
```

**What it preserves from old SOAR:** `SOARTeacher.generateCurriculum()` concept -- decomposing hard problems into sub-questions. But instead of generating a curriculum of pedagogical exercises, it generates a task graph of concrete tool calls.

### 7c. ResearchEvidenceScorer (Evidence Quality)

**Location:** `Epistemos/Omega/ResearchEvidenceScorer.swift` (NEW)

**Purpose:** Deterministic URL-to-confidence-tier mapping. No LLM call. Called by `scoreevidence` tool.

**Tiers (preserving old EnrichmentController's evidence hierarchy):**

| Tier | Confidence | URL Patterns |
|---|---|---|
| `primaryData` | 0.95 | `.gov`, official datasets, WHO, CDC |
| `peerReviewed` | 0.85 | `doi.org`, `pubmed`, `nature.com`, `science.org`, `springer.com`, `wiley.com`, `.edu` with `/publications/` |
| `arxivPreprint` | 0.70 | `arxiv.org`, `biorxiv.org`, `medrxiv.org`, `ssrn.com` |
| `news` | 0.50 | `nytimes`, `reuters`, `bbc`, `apnews`, `washingtonpost` |
| `blog` | 0.30 | `medium.com`, `substack.com`, `wordpress.com`, `blogspot` |
| `unknown` | 0.20 | Everything else |

**Recency modifier (optional, from old SOAR's Recency dimension):**
- If URL contains year >= current year - 1: +0.05
- If URL contains year <= current year - 5: -0.05
- Applied only when year is extractable from URL path

### 7d. ResearchConfidenceState (Confidence/Dissonance Tracking)

**Location:** `Epistemos/Omega/ResearchConfidenceState.swift` (NEW)

**Purpose:** Accumulates evidence quality and contradiction data during a research session. Determines when to pause for user input.

**State:**
```swift
struct ResearchConfidenceState {
    var snippets: [(text: String, url: String, confidence: Double)] = []
    var contradictions: [(a: String, b: String, verdict: String)] = []

    var overallConfidence: Double  // average of snippet confidences
    var hasDissonance: Bool        // !contradictions.isEmpty
    var requiresPause: Bool        // overallConfidence < 0.45 || (snippets.count < 2 && hasDissonance)
}
```

**What it preserves from old SOAR:** `SOARRewardCalculator`'s weighted confidence/entropy/dissonance tracking. Simplified from 4 dimensions with float weights to a clear threshold check. The old system's reward signal (`0.40 * deltaConfidence + 0.25 * deltaEntropy + 0.20 * deltaDissonance + 0.15 * deltaHealth`) was over-engineered for local models. The new system uses straightforward confidence averaging and a binary dissonance flag.

### 7e. ResearchOrchestrator (Coordinator)

**Location:** `Epistemos/Omega/ResearchOrchestrator.swift` (NEW)

**Purpose:** Coordinates the research loop within OrchestratorState. Monitors confidence, triggers pauses, handles depth escalation.

**Responsibilities:**
1. Initialize `ResearchConfidenceState` when a research task begins
2. After each `collectsnippet` or `scoreevidence` result: update confidence state
3. After each `analyzecontradiction` result: update contradiction list
4. If `requiresPause`: call `orchestrator.researchPause.requestResearch()` with specific questions derived from the low-confidence or contradiction state
5. If user responds with scope extension: append new steps to `TaskGraph` (depth escalation)
6. Before `createresearchnote` step: inject accumulated evidence/contradiction data into step arguments via `_context`

**Depth escalation logic:**
- After first pass completes (all initial steps done except `createresearchnote`):
  - If `overallConfidence < 0.45`: pause and ask user if deeper search is needed
  - If user says yes: generate additional search steps and insert before `createresearchnote`
  - Maximum 2 escalation rounds (prevents infinite loops)

### 7f. SOAR Location Summary

| SOAR Concept | New Type | Location | Invoked By |
|---|---|---|---|
| Edge-of-learnability | `ResearchComplexityGate` | `Epistemos/Omega/` | Chat/MiniChat routing logic |
| Stepping-stone decomposition | Planning prompt block | `OmegaInferenceBridge` | `buildPlanningPrompt()` when task starts with "research:" |
| Evidence scoring | `ResearchEvidenceScorer` | `Epistemos/Omega/` | `scoreevidence` tool in NotesAgent |
| Contradiction detection | `analyzecontradiction` tool | NotesAgent | Tool call in research plan |
| Confidence/dissonance | `ResearchConfidenceState` | `Epistemos/Omega/` | `ResearchOrchestrator` |
| Depth escalation | `ResearchOrchestrator` | `Epistemos/Omega/` | Mid-execution confidence check |
| Pause-and-ask | `ResearchPauseHandler` | Existing | `ResearchOrchestrator` when `requiresPause` |

---

## 8. Persistence and Telemetry Plan

### 8a. What Gets Logged (existing MCPBridge, no schema changes needed)

Every research tool call already flows through `MCPBridge.logExecution()` which records:
- `id` (UUID)
- `timestamp` (ISO8601)
- `toolName` (String)
- `argumentsJson` (String)
- `resultJson` (String)
- `durationMs` (Integer)
- `success` (Boolean)

This is sufficient for auditing and training data extraction. The `resultJson` field captures SOAR scores, contradiction verdicts, and evidence tiers as part of the tool's return payload.

**No SQLite schema migration is needed for Phase 1.** The existing schema captures everything.

### 8b. What Gets Logged Additionally (Phase 3, train-later)

For training data generation, add these to `StructuredODIATrace`:
- `taskType: String` -- "research" for research tasks, "general" for others
- This is a Swift-side label, not a database column. It's added when converting MCPBridge execution logs to ODIA training format.

### 8c. Research Session Persistence

| Data | Storage | Notes |
|---|---|---|
| Research snippets | Vault note (via `collectsnippet`) | Normal `SDPage`, synced by `VaultSyncService` |
| Citations | Vault note (via `savecitation`) | Appended to session note body, deduplicated by URL |
| Final research note | Vault note (via `createresearchnote`) | Structured markdown, auto-indexed by FTS5 |
| Tool execution log | `omega-executions.db` via MCPBridge | SQLite, queryable for auditing |
| ODIA training traces | `TrainingScheduler.pendingODIATraces` | In-memory until nightly flush |
| Evidence scores | `ResearchConfidenceState` (in-memory) | Not persisted; recomputed per session |
| Contradiction results | `ResearchConfidenceState` (in-memory) | Also captured in tool execution log |

### 8d. Trace Chain for a Research Task

```
MCPBridge.logExecution():
  { toolName: "search_web",          args: {query: "..."}, success: true, durationMs: 1200 }
  { toolName: "readpagecontent",     args: {maxLength: 4000}, success: true, durationMs: 800 }
  { toolName: "scoreevidence",       args: {url: "..."}, success: true, result: {tier: "arxivPreprint", confidence: 0.70} }
  { toolName: "collectsnippet",      args: {text: "...", sourceUrl: "..."}, success: true }
  { toolName: "search_web",          args: {query: "..."}, success: true }
  { toolName: "readpagecontent",     args: {maxLength: 4000}, success: true }
  { toolName: "collectsnippet",      args: {text: "...", sourceUrl: "..."}, success: true }
  { toolName: "analyzecontradiction", args: {snippetA: "...", snippetB: "..."}, result: {verdict: "contradict"} }
  { toolName: "createresearchnote",  args: {question: "...", findings: "..."}, success: true }
```

Each entry is independently queryable via `MCPBridge.recentExecutionsJson(limit:)`.

---

## 9. UI Integration Plan

### 9a. OmegaPanel (existing, minimal changes)

**No new views.** The existing OmegaPanel already has everything:

- `TaskInputBar` -- user types "research: [query]" (existing)
- `ExecutionProgressView` -- shows each tool step with status, agent, duration (existing)
- `ResearchRequestView` -- surfaces pause questions when confidence is low (existing)
- `ConfirmationSheet` -- gates high-risk operations (existing)

**One addition:** Add a quick action button to the idle view's suggestion list:
```swift
// In OmegaPanel idleView quickActionButtons:
quickActionButton("Research a topic", icon: "magnifyingglass") {
    currentTaskDescription = "research: "
    // Focus TaskInputBar with prefix
}
```

This is a single line change in the quick actions array.

### 9b. ExecutionProgressView Enhancement (optional, Phase 2)

For research-specific steps, optionally show:
- SOAR score badge next to `scoreevidence` steps (green/yellow/red based on tier)
- Contradiction verdict badge next to `analyzecontradiction` steps
- Snippet preview (first 100 chars) next to `collectsnippet` steps

These are cosmetic enhancements, not blockers. The existing progress view already shows tool name + result, which is sufficient for Phase 1.

### 9c. Chat/MiniChat Routing (Phase 2)

**ChatInputBar routing (in `ChatView.swift`):**
```
In the onSubmit callback, before calling chat.submitQuery(query):
1. Check if query starts with "/research " or "research: "
2. If yes: call orchestrator.submitTask(query) instead
3. Open OmegaPanel if not already visible
```

This does NOT add a `ResearchModeControl` struct (which is blocked by tests). It's a simple string prefix check in the existing `onSubmit` closure.

**MiniChatView routing (same pattern):**
```
In the send() method, before streaming:
1. Check if input starts with "/research " or "research: "
2. If yes: call orchestrator.submitTask(input) instead
3. Show toast: "Research task submitted to Omega"
```

### 9d. Research Note Auto-Open (Phase 2)

After `createresearchnote` succeeds, its result includes `pageId`. The `ResearchOrchestrator` calls `NoteWindowManager.openNote(pageId:)` to auto-open the research note in the editor.

### 9e. What NOT to build

- No separate Research panel / window / tab bar
- No `ResearchModeControl` toggle in ChatInputBar (blocked by test)
- No confidence overlays or evidence grade badges in chat chrome (blocked by test)
- No `SOARDetailView` in Settings (blocked by test)
- No fake progress animations (old `ResearchThinkingView` pattern)

---

## 10. Test Impact and Migration Plan

### 10a. Tests That Block Old Feature Shape (must remain passing)

| Test | File | What It Blocks | Risk from New Work |
|---|---|---|---|
| `chatSurfacesDropResearchModeControl` | ThemePairTests:843 | `struct ResearchModeControl`, "Ask a research question" in ChatView/ChatInputBar/LandingView | **LOW** -- we add string prefix routing, not a struct |
| `settingsAndLandingDropAnalyticalChatChrome` | ThemePairTests:855 | `case soar`, `SOARDetailView`, `Confidence:`, `evidence grades` in Settings/Landing | **NONE** -- new SOAR logic is in `Epistemos/Omega/`, not Settings |
| `liveRuntimeDropsEnrichmentAndSOARHooks` | ThemePairTests:867 | `EnrichmentController`, `soarService`, `skipEnrichment`, `onEnriched`, `cancelAllEnrichment` in PipelineService/ChatCoordinator/ChatState/AppBootstrap/AppEnvironment/AppCoordinator/EngineTypes/EventBus | **NONE** -- new code is in `Epistemos/Omega/`, not in any of these files |
| `chatChromeDropsEnrichmentPanels` | ThemePairTests:904 | `EpistemicLensPanel`, `ReflectionCard`, `TruthAssessmentCard`, `ConsensusReportCard` in MessageBubble/pbxproj | **NONE** -- research output goes to vault notes, not chat chrome |
| `projectDropsStandaloneResearchSubsystem` | ThemePairTests:1367 | `ResearchState.swift`, `ResearchService.swift`, `ResearchIntents.swift`, `PaperEntity.swift`, `ResearchTypes.swift` in pbxproj; `researchState`, `researchService` in AppBootstrap; `ResearchTopicIntent`, `FindGapsIntent`, `FactCheckIntent` in ShortcutsProvider | **NONE** -- new files are named `ResearchOrchestrator`, `ResearchEvidenceScorer`, `ResearchConfidenceState`, `ResearchComplexityGate` -- none of these are blocked |
| `dailyBriefDropsSecondPassScaffolding` | ThemePairTests:1443 | `isDeepBrief`, `onGoDeepGenerate`, `requestGoDeep` in DailyBriefState/LandingView/AppCoordinator | **NONE** -- research mode is separate from DailyBriefState |
| `userFacingAISurfacesDropHiddenPersonas` | ThemePairTests:1462 | `"research assistant"` in intents/views/TriageService; various hidden persona strings | **MEDIUM** -- must ensure research planning prompt does NOT contain "research assistant" literal. Use "You are a precise task planner" (already the default) |

### 10b. New Tests to Add

**File:** `EpistemosTests/ResearchModeTests.swift` (NEW)

```
@Suite("Research Mode")
struct ResearchModeTests {

    // Tool registration
    @Test func researchToolsAreRegistered()
        // Verify OmegaToolRegistry.all contains all 7 new tools

    // Complexity gate
    @Test func complexityGateRoutesResearchQueries()
        // "research transformer architectures" -> true
        // "what time is it" -> false
        // "find evidence for claim X" -> true
        // "hello" -> false

    // Evidence scorer
    @Test func evidenceScorerTiersAreCorrect()
        // arxiv.org -> .arxivPreprint (0.70)
        // nature.com -> .peerReviewed (0.85)
        // medium.com -> .blog (0.30)
        // random.com -> .unknown (0.20)

    // Confidence state
    @Test func confidenceStatePausesOnLowEvidence()
        // 1 snippet at 0.30 -> requiresPause = true
        // 3 snippets at 0.80 -> requiresPause = false
        // 2 snippets + contradiction -> check threshold

    // No hidden personas
    @Test func researchPlanningPromptHasNoHiddenPersonas()
        // Read OmegaInferenceBridge.swift
        // Verify no "research assistant" string
        // Verify no "You are a research" string

    // Blocked names don't reappear
    @Test func newFilesDoNotUseBlockedNames()
        // Verify pbxproj does NOT contain:
        // ResearchState.swift, ResearchService.swift, ResearchIntents.swift,
        // PaperEntity.swift, ResearchTypes.swift
}
```

### 10c. Existing Test Suite Impact

**ThemePairTests:** All 7 blocking tests remain passing. New files use non-blocked names.

**Build verification:** Run `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test` after each phase.

**Manual integration test (per CLAUDE.md Golden Rule 8):**
1. Build and launch app
2. Open OmegaPanel, type "research: transformer attention vs Mamba-2"
3. Watch execution progress -- verify each tool step appears
4. Check Console.app logs for errors/warnings
5. Verify research note appears in vault after completion
6. Verify no regressions in standard chat path

---

## 11. File-by-File Implementation Sequence

### Phase 1: Tools + SOAR Logic (Days 1-5)

| Order | File | Action | Dependencies |
|---|---|---|---|
| 1 | `omega-mcp/src/osascript.rs` | Add `tool_get_page_text()` -- AppleScript to extract `document.body.innerText` from Safari | None |
| 2 | `Epistemos/Omega/ResearchEvidenceScorer.swift` | NEW file -- URL-to-tier mapping struct, purely deterministic | None |
| 3 | `Epistemos/Omega/ResearchConfidenceState.swift` | NEW file -- confidence accumulator struct, `requiresPause` logic | None |
| 4 | `Epistemos/Omega/ResearchComplexityGate.swift` | NEW file -- wraps existing complexity scoring with research-intent keywords | TriageService (existing) |
| 5 | `Epistemos/Omega/Agents/SafariAgent.swift` | Add `readpagecontent` case -- calls Rust `tool_get_page_text()`, truncates to maxLength | Step 1 |
| 6 | `Epistemos/Omega/Agents/SafariAgent.swift` | Add `searchpapers` case -- URLSession to Semantic Scholar API, fallback to search_web | None |
| 7 | `Epistemos/Omega/Agents/NotesAgent.swift` | Add `collectsnippet` case -- append blockquote to session note or create new | None |
| 8 | `Epistemos/Omega/Agents/NotesAgent.swift` | Add `savecitation` case -- append formatted citation, deduplicate by URL | None |
| 9 | `Epistemos/Omega/Agents/NotesAgent.swift` | Add `createresearchnote` case -- structured markdown note creation | None |
| 10 | `Epistemos/Omega/Agents/NotesAgent.swift` | Add `analyzecontradiction` case -- heuristic + LLM fallback for contradiction detection | TriageService (existing) |
| 11 | `Epistemos/Omega/Agents/NotesAgent.swift` | Add `scoreevidence` case -- delegates to `ResearchEvidenceScorer` | Step 2 |
| 12 | `Epistemos/Omega/MCPBridge.swift` | Register all 7 new tools in `OmegaToolRegistry.all` with schemas | Steps 5-11 |

### Phase 2: Orchestration + Wiring (Days 6-8)

| Order | File | Action | Dependencies |
|---|---|---|---|
| 13 | `Epistemos/Omega/ResearchOrchestrator.swift` | NEW file -- coordinates multi-pass research loop, monitors confidence, handles depth escalation | Steps 2, 3, 4 |
| 14 | `Epistemos/Omega/Orchestrator/OmegaInferenceBridge.swift` | Extend `buildPlanningPrompt()` -- inject research planning block when task starts with "research:" | None |
| 15 | `Epistemos/Omega/Orchestrator/OrchestratorState.swift` | Add `researchOrchestrator: ResearchOrchestrator?` property; call in `submitTask()` when research task type detected; hook into execution loop for confidence monitoring | Step 13 |
| 16 | `Epistemos/App/AppBootstrap.swift` | Create `ResearchOrchestrator` instance, inject into `OrchestratorState` | Steps 13, 15 |
| 17 | `Epistemos/Views/Chat/ChatView.swift` | In `onSubmit` callback: detect "/research " prefix, route to `orchestrator.submitTask()` instead of `chat.submitQuery()` | Step 15 |
| 18 | `Epistemos/Views/MiniChat/MiniChatView.swift` | In `send()` method: detect "/research " prefix, route to `orchestrator.submitTask()` | Step 15 |
| 19 | `Epistemos/Views/Omega/OmegaPanel.swift` | Add "Research a topic" quick action button to idle view | None |

### Phase 3: Tests (Day 9)

| Order | File | Action | Dependencies |
|---|---|---|---|
| 20 | `EpistemosTests/ResearchModeTests.swift` | NEW file -- tool registration tests, complexity gate tests, evidence scorer tests, confidence state tests, no-hidden-persona tests | Steps 1-19 |
| 21 | Run full test suite | `xcodebuild test` -- verify ThemePairTests still pass | Step 20 |
| 22 | Manual integration test | Build, launch, exercise research via OmegaPanel, check Console.app logs | Step 21 |

### Phase 4: Training Follow-Up (Days 10-14, after manual testing)

| Order | File | Action | Dependencies |
|---|---|---|---|
| 23 | `Epistemos/KnowledgeFusion/SyntheticData/generate_epistemos_training_data.py` | Add `generateResearchWorkflowExamples()` -- layer 16, ODIA format, all 7 research tools | Steps 1-22 verified |
| 24 | `Epistemos/KnowledgeFusion/SyntheticData/fill_training_gaps.py` | Add research category to gap filler | Step 23 |
| 25 | `Epistemos/KnowledgeFusion/Alignment/TrainingScheduler.swift` | Add `taskType: "research"` label to ODIA trace ingestion | Step 23 |
| 26 | `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` | Wire `KnowledgeFusionViewModel.logFeedback()` to note accept for research notes (enables KTO signal) | Step 23 |

---

## 12. Risk Register

### HIGH RISK

| Risk | Impact | Mitigation |
|---|---|---|
| `userFacingAISurfacesDropHiddenPersonas` test fails if research planning prompt contains "research assistant" | Build fails | Use existing "You are a precise task planner" system prompt. Grep for "research assistant" before commit. |
| `readpagecontent` AppleScript fails on some Safari states (no tab, PDF, reader mode) | Tool returns error, research task stalls | Return graceful error with `success: false` and descriptive `error` field. ResearchOrchestrator treats as low-confidence and continues. |
| Semantic Scholar API rate-limits or changes response format | `searchpapers` fails silently | Implement fallback to `search_web` with `site:scholar.google.com`. Cache results per-session. Parse with `FlexValue` enum (proven in old ResearchService). |
| Research planning prompt causes Qwen 3.5 4B to generate invalid JSON | Plan generation fails, task aborts | Existing fallback: Rust heuristic planner. Also: constrained decoding (Omega 11) grammar-guides JSON output. Test with 10+ research prompts during Phase 3. |
| `contextualizedStep()` _context injection exceeds token limit for long research sessions | Later steps get truncated context | Truncate each _context entry to 2000 chars. Research planning prompt limits to max 20 steps. |
| NotesAgent `collectsnippet` creates duplicate session notes if `sessionNoteId` not tracked across steps | Multiple fragmented notes | `ResearchOrchestrator` tracks session note ID after first `collectsnippet` and injects it into subsequent step arguments. |

### MEDIUM RISK

| Risk | Impact | Mitigation |
|---|---|---|
| `analyzecontradiction` LLM fallback produces unreliable verdicts with Qwen 3.5 4B | False contradiction flags, unnecessary pauses | Heuristic-first design reduces LLM dependency. Constrained decoding enforces `{verdict: "agree"/"contradict"/"orthogonal"}` output. |
| Adding `researchOrchestrator` property to OrchestratorState changes its observable surface | SwiftUI views re-evaluate unnecessarily | Make property optional and non-@Observable (plain stored property, not published). |
| Chat/MiniChat prefix routing intercepts legitimate queries starting with "research" | User types "research shows that..." and gets routed to Omega | Require exact prefix "/research " (with slash) for chat routing. OmegaPanel TaskInputBar accepts "research:" without slash. |

### LOW RISK

| Risk | Impact | Mitigation |
|---|---|---|
| New tool registrations increase LLM planning prompt size | Slightly longer planning time | 7 new tools add ~350 tokens to prompt. Well within Qwen 3.5 4B context window. |
| `ResearchEvidenceScorer` URL patterns miss new domains | Some sources scored as "unknown" | Conservative default (0.20 confidence). Can extend patterns incrementally. |
| Quick action button in OmegaPanel causes layout shift | Minor UI annoyance | Test on all window sizes. Button follows existing pattern. |

---

## 13. Recommended First Milestone

**Milestone: "Research Mode MVP" -- vertical slice from tool to note**

**Definition of Done:**
1. User opens OmegaPanel, types "research: transformer attention vs Mamba-2"
2. OrchestratorState detects "research:" prefix, injects research planning block
3. LLM generates multi-step plan with search -> read -> collect -> score -> synthesize steps
4. ExecutionProgressView shows each step executing in real-time
5. `search_web` finds sources, `readpagecontent` extracts text, `collectsnippet` saves quotes
6. `scoreevidence` assigns confidence tiers to each source
7. If contradictions detected: `analyzecontradiction` flags them
8. `createresearchnote` produces structured markdown note in vault
9. Note auto-opens in editor with Question / Findings / Evidence / Contradictions / Citations sections
10. All tool calls logged in `omega-executions.db` via MCPBridge
11. All ThemePairTests pass
12. Console.app shows zero errors/warnings during the flow

**Estimated scope:** Phase 1 + Phase 2 (Steps 1-19) = ~8 working days

**What this proves:**
- Research execution flows through Omega pipeline end-to-end
- SOAR evidence scoring works deterministically
- Contradiction detection produces useful results
- Research notes are structured and vault-compatible
- No test regressions
- No enrichment pipeline pollution of standard chat

---

## 14. Recommended Training Follow-Up After Runtime Stabilizes

### When to Start Training

Only after:
1. Phase 1-3 complete (tools + orchestration + tests passing)
2. At least 10 manual research sessions executed successfully
3. `omega-executions.db` contains real research traces (not synthetic)
4. ResearchOrchestrator handles edge cases (API failures, low-confidence, contradictions) gracefully

### What the Model Should Learn

The existing TriageService local model (Qwen 3.5 4B) should learn to:
1. **Generate better research plans.** Currently relies on the research planning prompt block. Future: model natively outputs optimal research step sequences.
2. **Call tools in correct order.** search -> read -> collect -> score -> analyze -> synthesize.
3. **Decompose research questions.** Break "X vs Y" into sub-questions that can be independently answered.
4. **Recognize when to escalate.** Low-confidence results should trigger additional search steps.

### Training Data Flow

```
Real research sessions execute
    -> MCPBridge.logExecution() logs every tool call to SQLite
    -> TrainingScheduler.ingestODIATraces() receives StructuredODIATrace with taskType: "research"
    -> ReasoningTraceLogger.logReasoningChain() captures think/critique traces
    -> Nightly: TrainingScheduler.onODIASchedulerFired()
    -> StructuredODIATraceGenerator.toJSONL() + reasoningLines merged
    -> QLoRA training on active adapter (rank 16, lr 2e-5, max 300 iterations)
```

### Training Data Format (matches existing ODIA)

```json
{
  "messages": [
    {"role": "system", "content": "You are a precise task planner. Output ONLY valid JSON array..."},
    {"role": "user", "content": "research: transformer attention mechanisms vs Mamba-2 selective scan"},
    {"role": "assistant", "content": "[{\"description\":\"Search for transformer attention papers\",\"agent\":\"safari\",\"tool\":\"search_web\",\"arguments\":{\"query\":\"transformer attention mechanisms 2024 2025\"},\"risk\":\"low\"},{\"description\":\"Extract page content\",\"agent\":\"safari\",\"tool\":\"readpagecontent\",\"arguments\":{\"maxLength\":4000},\"risk\":\"low\",\"dependsOn\":[0]}...]"}
  ],
  "category": "research",
  "taskType": "research"
}
```

### Synthetic Training Data Generation (Phase 4, Step 23)

Add `generateResearchWorkflowExamples()` to `generate_epistemos_training_data.py`:
- 50 research queries covering diverse topics (science, technology, history, medicine, philosophy)
- Each query mapped to a gold-standard research plan (6-15 steps)
- Plans use all 7 research tools in correct dependency order
- Include edge cases: academic-only queries (use `searchpapers`), contradiction-heavy topics, single-source topics

### KTO Feedback Signal (Phase 4, Step 26)

Wire `KnowledgeFusionViewModel.logFeedback()` (currently has zero callers) to research notes:
- When user keeps a research note (does not delete within 24 hours): positive KTO signal
- When user deletes or archives immediately: negative KTO signal
- When user edits substantially (>30% change): neutral (no signal)

This provides a clean preference signal for the research planning quality.

### Training Non-Negotiables (from CLAUDE.md)

- LoRA rank 16 for Nano (not 8, not 32)
- WSD scheduler, never cosine
- 20% Epistemos app-specific data (research traces count toward this)
- Never fuse adapters into base -- hot-swap via MoLoRA routing
- One variable at a time -- don't change LR + data mix + rank simultaneously
- Deploy on MLX/Metal GPU, NOT ANE

### Timeline

| Week | Activity |
|---|---|
| Week 1-2 | Phase 1-2: Tools + orchestration implemented |
| Week 2 | Phase 3: Tests passing, manual verification |
| Week 3 | Phase 4: Training data generation, scheduler labeling |
| Week 4+ | Accumulate real traces from usage, first ODIA training run with research category |

---

## Appendix A: ThemePairTests Exact Blocked Strings Reference

For quick verification during implementation. These strings must NOT appear in the listed files:

**`chatSurfacesDropResearchModeControl`:**
- ChatView.swift: `"struct ResearchModeControl"`, `"Ask a research question"`
- ChatInputBar.swift: `"ResearchModeControl"`
- LandingView.swift: `"ResearchModeControl"`

**`settingsAndLandingDropAnalyticalChatChrome`:**
- SettingsView.swift: `"case soar"`, `"SOARDetailView"`
- LandingView.swift: `"Confidence:"`, `"confidence scores"`, `"evidence grades"`

**`liveRuntimeDropsEnrichmentAndSOARHooks`:**
- PipelineService.swift: `"EnrichmentController"`, `"soarService"`, `"skipEnrichment"`, `"onEnriched"`, `"cancelAllEnrichment"`
- ChatCoordinator.swift: `"case .enriched"`, `"case .soarEvent"`, `"persistEnrichment("`, `"persistableDualMessage"`
- ChatState.swift: `"EnrichmentController.parseConceptsTag"`, `"enrichMessage("`, `"enrichLastMessage("`
- AppBootstrap.swift: `"let soarState"`, `"let soarService"`, `"cancelAllEnrichment()"`
- AppEnvironment.swift: `".environment(bootstrap.soarState)"`
- AppCoordinator.swift: `".epistemicLens"`, `"cancelAllEnrichment()"`
- EngineTypes.swift: `"case enriched("`, `"case soarEvent("`
- EventBus.swift: `"case soarEvent("`

**`chatChromeDropsEnrichmentPanels`:**
- MessageBubble.swift: `"laymanSummarySections"`, `"EpistemicLensPanel"`, `"ReflectionCard"`, `"TruthAssessmentCard"`, `"ConsensusReportCard"`
- project.pbxproj: `"ConfidenceOverlay.swift"`, `"LearningIntents.swift"`

**`projectDropsStandaloneResearchSubsystem`:**
- project.pbxproj: `"ResearchState.swift"`, `"ResearchService.swift"`, `"ResearchIntents.swift"`, `"PaperEntity.swift"`, `"ResearchTypes.swift"`
- AppBootstrap.swift: `"researchState"`, `"researchService"`
- EpistemosShortcutsProvider.swift: `"ResearchTopicIntent"`, `"FindGapsIntent"`, `"FactCheckIntent"`

**`dailyBriefDropsSecondPassScaffolding`:**
- DailyBriefState.swift: `"isDeepBrief"`, `"onGoDeepGenerate"`, `"requestGoDeep"`, `"deep actionable intelligence report"`, `"research analyst's morning brief"`
- LandingView.swift: `"Go Deeper"`, `"buildGoDeepPrompt"`, `"deep multi-perspective analysis"`
- AppCoordinator.swift: `"onGoDeepGenerate"`
- DailyBriefingIntent.swift: `"daily intelligence brief"`

**`userFacingAISurfacesDropHiddenPersonas`:**
- AnalysisIntents.swift: `"research assistant"`
- NoteActionIntents.swift: `"research assistant"`
- NoteDetailWorkspaceView.swift: `"systemPrompt: mapping.systemPrompt"`, `"You are a writing assistant."`
- NodeInspectorState.swift: `"You are a note analyst"`
- DialogueChatState.swift: `"You are \"\\(activeNodeLabel)\", a character"`, `"You speak in character."`, `"messages.append(Message(role: .assistant, text: profile.openingLine))"`
- HologramNodeInspector.swift: `"p.archetype.title"`, `"p.care.mood.displayName"`, `"p.portrait.symbol"`, `"statMeter(label: \"Focus\""`
- VaultOrganizerView.swift: `"You are a note organization assistant."`
- TriageService.swift: `"let simpleSystem ="`

## Appendix B: New File Names (verified non-blocked)

| New File | Blocked by Any Test? |
|---|---|
| `ResearchOrchestrator.swift` | NO |
| `ResearchEvidenceScorer.swift` | NO |
| `ResearchConfidenceState.swift` | NO |
| `ResearchComplexityGate.swift` | NO |
| `ResearchModeTests.swift` | NO |

None of these names appear in any ThemePairTests blocked string list.

---

*This document is the execution source of truth for the Omega Research Mode & SOAR migration. Do not code without reading this first.*
