# Epistemos Omega — Feature Completion Spec
## Architectural Hardening Extracted from OpenClaw Agent Runtime
> **For Claude Code.** Each feature is a self-contained unit. Build them in order.
> Reference: OpenClaw commit `main` @ 2026-03-25. Source files cited per feature.

---

## Ground Rules for Claude

1. **Do NOT port TypeScript.** Rewrite every algorithm in idiomatic Swift 6.
2. **All new files** go in `Epistemos/Omega/Safety/` (new directory).
3. **All state classes** use `@MainActor @Observable`. No `ObservableObject`.
4. **All tests** use Swift Testing (`@Suite`, `@Test`, `#expect`). No XCTest.
5. **No force unwraps, no `try!`.** Guard everything.
6. **Read the file before you edit it.** Always.
7. These features wire into `OrchestratorState.executePlan()` — they do NOT replace it, they augment it.

---

## Feature 1: Tool Loop Detection

**OpenClaw Reference**: `src/agents/tool-loop-detection.ts` (624 lines)

### What It Does
Detects when the agent gets stuck calling the same tool with the same arguments repeatedly, or oscillating between two tool calls (ping-pong pattern). Has three escalation levels: warning → critical → circuit breaker.

### Architecture

```
[OrchestratorState.executeStep()]
        ↓
[ToolLoopDetector.recordCall(toolName, params)]
        ↓
[ToolLoopDetector.check() → .ok | .warning(msg) | .critical(msg)]
        ↓ if .warning:
[Inject warning into next LLM prompt: "You're stuck, try something else"]
        ↓ if .critical:
[Abort plan execution, surface error to user via ExecutionProgressView]
```

### Implementation

#### [NEW] `Epistemos/Omega/Safety/ToolLoopDetector.swift`

```swift
@MainActor @Observable
final class ToolLoopDetector {
    // --- Configuration ---
    let historySize: Int = 30            // Sliding window
    let warningThreshold: Int = 5        // Warn after N identical calls
    let criticalThreshold: Int = 10      // Abort after N identical calls
    let circuitBreakerThreshold: Int = 15 // Hard stop

    // --- State ---
    private(set) var history: [ToolCallRecord] = []
    private(set) var lastResult: DetectionResult = .ok

    struct ToolCallRecord {
        let toolName: String
        let argsHash: String     // SHA-256 of stable-sorted JSON args
        var resultHash: String?  // SHA-256 of tool result (set after completion)
        let timestamp: Date
    }

    enum DetectionResult {
        case ok
        case warning(String)
        case critical(String)
    }

    enum DetectorKind: String {
        case genericRepeat
        case pollNoProgress     // Same tool+args, same result repeatedly
        case pingPong           // Alternating between two tool+args patterns
        case circuitBreaker     // Global hard stop
    }
}
```

**Core algorithms to implement:**

1. **`recordCall(toolName: String, args: [String: Any])`**
   - Compute `argsHash` = SHA-256 of deterministic JSON serialization of args (sort keys alphabetically at every nesting level).
   - Append `ToolCallRecord` to `history`.
   - If `history.count > historySize`, remove oldest entry.

2. **`recordOutcome(toolName: String, args: [String: Any], result: String)`**
   - Find the most recent unfinished record matching `toolName` + `argsHash`.
   - Set its `resultHash` = SHA-256 of `result`.

3. **`check(toolName: String, args: [String: Any]) -> DetectionResult`**
   - **Generic Repeat**: Count entries in `history` where `toolName` AND `argsHash` match. If ≥ `warningThreshold`, return `.warning`.
   - **Poll No Progress**: Walk history backwards. Count consecutive entries where `toolName`, `argsHash`, AND `resultHash` all match. If ≥ `criticalThreshold`, return `.critical`. If ≥ `warningThreshold`, return `.warning`.
   - **Ping-Pong**: Check if the last N entries alternate between exactly 2 distinct `argsHash` values. Walk backwards counting alternations. If ≥ `warningThreshold` AND all `resultHash` values for each side are identical (no progress), return `.warning`. If ≥ `criticalThreshold` with no progress, return `.critical`.
   - **Circuit Breaker**: If any no-progress streak ≥ `circuitBreakerThreshold`, return `.critical` unconditionally.

4. **`reset()`** — Clear history. Call after user edits plan or provides new input.

### Wiring

In `OrchestratorState.executeStep()`, **before** dispatching each tool call:
```swift
let detection = loopDetector.check(toolName: step.tool, args: step.args)
switch detection {
case .warning(let msg):
    // Inject into next LLM context: "SYSTEM WARNING: \(msg)"
    log.warning("Tool loop warning: \(msg)")
case .critical(let msg):
    // Abort plan execution
    throw OmegaError.toolLoopDetected(msg)
case .ok:
    break
}
```

**After** each tool call completes:
```swift
loopDetector.recordOutcome(toolName: step.tool, args: step.args, result: resultString)
```

### Tests — `EpistemosTests/ToolLoopDetectorTests.swift`

| Test | Setup | Expectation |
|------|-------|-------------|
| `noLoopReturnsOk` | 3 different tool calls | `.ok` |
| `genericRepeatWarns` | Same tool+args 5 times | `.warning` |
| `pollNoProgressCritical` | Same tool+args+result 10 times | `.critical` containing "no progress" |
| `pingPongDetection` | Alternate A/B 6 times with same results | `.warning` containing "ping-pong" |
| `circuitBreakerFires` | Same tool+args+result 15 times | `.critical` containing "circuit breaker" |
| `resetClearsHistory` | Fill history, reset, check | `.ok` |
| `slidingWindowEvicts` | Add 35 entries | `history.count == 30` |
| `differentResultsNoWarning` | Same tool+args but different results each time | `.ok` |

---

## Feature 2: Context Budget Manager

**OpenClaw Reference**: `src/agents/compaction.ts` (465 lines), `src/agents/context-window-guard.ts` (75 lines)

### What It Does
Tracks cumulative token usage across multi-step plan execution. When approaching the model's context window limit, proactively summarizes earlier steps to free budget. Prevents the LLM from receiving truncated context (which causes hallucination and tool call failures).

### Architecture

```
[OrchestratorState] owns [ContextBudgetManager]
        ↓
Each step: manager.trackUsage(promptTokens, completionTokens)
        ↓
If usage > 70% of contextWindow:
    manager.requestCompaction() → summarize old steps → replace history
        ↓
If usage > 90%:
    WARN user, reduce plan scope
```

### Implementation

#### [NEW] `Epistemos/Omega/Safety/ContextBudgetManager.swift`

```swift
@MainActor @Observable
final class ContextBudgetManager {
    // --- Configuration ---
    let contextWindowTokens: Int       // From HardwareTierManager model config
    let compactionThreshold: Double = 0.70  // Trigger compaction at 70%
    let warningThreshold: Double = 0.90     // Warn user at 90%
    let safetyMargin: Double = 1.2          // 20% buffer for token estimation inaccuracy

    // --- State ---
    private(set) var totalPromptTokens: Int = 0
    private(set) var totalCompletionTokens: Int = 0
    private(set) var stepSummaries: [StepSummary] = []
    private(set) var compactedSummary: String? = nil
    private(set) var compactionCount: Int = 0

    struct StepSummary {
        let stepIndex: Int
        let toolName: String
        let promptTokens: Int
        let completionTokens: Int
        let resultSnippet: String   // First 500 chars of tool result
        let timestamp: Date
    }

    var usageRatio: Double {
        Double(totalPromptTokens + totalCompletionTokens) / Double(contextWindowTokens)
    }

    var needsCompaction: Bool { usageRatio >= compactionThreshold }
    var isWarning: Bool { usageRatio >= warningThreshold }
}
```

**Key methods:**

1. **`trackUsage(stepIndex: Int, toolName: String, promptTokens: Int, completionTokens: Int, resultSnippet: String)`**
   - Accumulate totals.
   - Append to `stepSummaries`.
   - Check thresholds and return status.

2. **`compact(using inferenceService: MLXInferenceService) async throws`**
   - Take oldest 60% of `stepSummaries`.
   - Build a prompt: "Summarize these tool execution results into a concise context paragraph. Preserve: active task status, decisions made, key outputs, error states."
   - Call inference to generate summary.
   - Replace old summaries with `compactedSummary`.
   - Reset token counters proportionally.

3. **`buildContextPrefix() -> String`**
   - If `compactedSummary` exists, prepend it to the current step context.
   - Format: `"[Previous execution context]\n\(compactedSummary)\n\n[Current step]"`

4. **`estimateTokens(_ text: String) -> Int`**
   - Simple heuristic: `text.utf8.count / 4` (same as OpenClaw's `chars/4`).
   - Apply `safetyMargin`: multiply estimate by 1.2.

### Wiring

In `OrchestratorState`, after each step completes:
```swift
budgetManager.trackUsage(
    stepIndex: currentStepIndex,
    toolName: step.tool,
    promptTokens: response.promptTokenCount,
    completionTokens: response.completionTokenCount,
    resultSnippet: String(result.prefix(500))
)

if budgetManager.needsCompaction {
    try await budgetManager.compact(using: inferenceService)
}
```

### Tests — `EpistemosTests/ContextBudgetManagerTests.swift`

| Test | Expectation |
|------|-------------|
| `initialStateIsClean` | `usageRatio == 0`, `needsCompaction == false` |
| `trackingAccumulatesTokens` | After 3 steps, totals are sum |
| `compactionTriggersAt70Percent` | `needsCompaction == true` at 70% |
| `warningAt90Percent` | `isWarning == true` at 90% |
| `compactReducesHistory` | After compact, stepSummaries shrinks, compactedSummary is non-nil |
| `tokenEstimationHasSafetyMargin` | `estimateTokens("hello") > 1` |
| `contextPrefixIncludesCompacted` | After compact, `buildContextPrefix()` contains summary text |

---

## Feature 3: Execution Checkpoint & Resume

**OpenClaw Reference**: `src/agents/session-transcript-repair.ts` (523 lines)

### What It Does
Persists step completion state during plan execution so that if the app crashes or the user force-quits mid-plan, the agent can resume from the last completed step instead of starting over.

### Architecture

```
[OrchestratorState.executePlan()]
        ↓ before each step:
[CheckpointManager.markStepStarted(stepIndex)]
        ↓ after each step:
[CheckpointManager.markStepCompleted(stepIndex, result)]
        ↓
[Serialized to UserDefaults or JSON file in App Support]

On next launch:
[CheckpointManager.loadCheckpoint(planId)] → resume from step N+1
```

### Implementation

#### [NEW] `Epistemos/Omega/Safety/ExecutionCheckpointManager.swift`

```swift
@MainActor @Observable
final class ExecutionCheckpointManager {
    private let checkpointDir: URL  // ~/Library/Application Support/Epistemos/checkpoints/

    struct Checkpoint: Codable {
        let planId: String
        let planDescription: String
        var steps: [StepCheckpoint]
        var lastCompletedIndex: Int
        var createdAt: Date
        var updatedAt: Date

        struct StepCheckpoint: Codable {
            let index: Int
            let toolName: String
            let status: StepStatus
            var resultSnippet: String?
            var error: String?
            var startedAt: Date?
            var completedAt: Date?
        }

        enum StepStatus: String, Codable {
            case pending
            case running
            case completed
            case failed
            case skipped
        }
    }

    private(set) var activeCheckpoint: Checkpoint? = nil
    private(set) var hasResumableExecution: Bool = false
}
```

**Key methods:**

1. **`createCheckpoint(planId: String, steps: [TaskStep], description: String)`**
   - Create `Checkpoint` with all steps as `.pending`.
   - Write to `checkpointDir/\(planId).json`.

2. **`markStepStarted(_ index: Int)`**
   - Update step status to `.running`, set `startedAt`.
   - Write to disk (atomic write via temp file + rename).

3. **`markStepCompleted(_ index: Int, result: String)`**
   - Update step status to `.completed`, set `resultSnippet` (first 1000 chars), set `completedAt`.
   - Update `lastCompletedIndex`.
   - Write to disk.

4. **`markStepFailed(_ index: Int, error: String)`**
   - Update step status to `.failed`, set `error`.
   - Write to disk.

5. **`loadCheckpoint(planId: String) -> Checkpoint?`**
   - Read from disk. If found and `lastCompletedIndex < steps.count - 1`, set `hasResumableExecution = true`.

6. **`resumeExecution() -> Int`**
   - Returns `lastCompletedIndex + 1` (the step to resume from).

7. **`clearCheckpoint(planId: String)`**
   - Delete the checkpoint file. Call after plan completes successfully.

8. **`cleanupStaleCheckpoints(olderThan hours: Int = 24)`**
   - Delete checkpoint files older than N hours.

### Wiring

In `OrchestratorState.executePlan()`:
```swift
// At start:
checkpointManager.createCheckpoint(planId: plan.id, steps: plan.steps, description: plan.goal)

// Check for resume:
if let checkpoint = checkpointManager.loadCheckpoint(planId: plan.id),
   checkpointManager.hasResumableExecution {
    let resumeIndex = checkpointManager.resumeExecution()
    startFromStep = resumeIndex  // Skip already-completed steps
}

// Around each step:
checkpointManager.markStepStarted(stepIndex)
do {
    let result = try await executeStep(step)
    checkpointManager.markStepCompleted(stepIndex, result: result)
} catch {
    checkpointManager.markStepFailed(stepIndex, error: error.localizedDescription)
    throw error
}

// After full success:
checkpointManager.clearCheckpoint(planId: plan.id)
```

In `AppBootstrap`, on launch:
```swift
// Check for interrupted executions
let checkpointManager = ExecutionCheckpointManager()
if checkpointManager.hasResumableExecution {
    // Surface in UI: "Would you like to resume your interrupted task?"
}
```

### Tests — `EpistemosTests/ExecutionCheckpointManagerTests.swift`

| Test | Expectation |
|------|-------------|
| `createWritesToDisk` | File exists at expected path |
| `markCompletedUpdatesIndex` | `lastCompletedIndex` increments |
| `loadAfterCrash` | Write 3 steps completed, reload → `resumeExecution() == 3` |
| `clearRemovesFile` | After clear, file doesn't exist |
| `staleCleanup` | Old checkpoint gets deleted |
| `atomicWriteDoesntCorrupt` | Write during read doesn't produce invalid JSON |

---

## Feature 4: Agent Depth Limiter

**OpenClaw Reference**: `src/agents/subagent-depth.ts` (177 lines)

### What It Does
Prevents infinite delegation loops when agents spawn sub-tasks that spawn further sub-tasks. Enforces a maximum recursion depth.

### Implementation

#### [NEW] `Epistemos/Omega/Safety/AgentDepthLimiter.swift`

```swift
@MainActor @Observable
final class AgentDepthLimiter {
    let maxDepth: Int = 3

    private(set) var currentDepth: Int = 0
    private var depthStack: [String] = []  // Stack of plan IDs

    var canDelegate: Bool { currentDepth < maxDepth }

    func pushExecution(planId: String) throws {
        guard canDelegate else {
            throw OmegaError.maxAgentDepthExceeded(
                "Cannot spawn sub-task: depth \(currentDepth) >= max \(maxDepth). " +
                "Delegation chain: \(depthStack.joined(separator: " → "))"
            )
        }
        depthStack.append(planId)
        currentDepth = depthStack.count
    }

    func popExecution() {
        guard !depthStack.isEmpty else { return }
        depthStack.removeLast()
        currentDepth = depthStack.count
    }

    func reset() {
        depthStack.removeAll()
        currentDepth = 0
    }
}
```

### Wiring

In `OrchestratorState.executePlan()`:
```swift
try depthLimiter.pushExecution(planId: plan.id)
defer { depthLimiter.popExecution() }
// ... execute plan steps ...
```

### Tests — `EpistemosTests/AgentDepthLimiterTests.swift`

| Test | Expectation |
|------|-------------|
| `initialDepthIsZero` | `currentDepth == 0`, `canDelegate == true` |
| `pushIncrements` | After push, `currentDepth == 1` |
| `maxDepthBlocks` | 3 pushes → `canDelegate == false` |
| `popDecrements` | Push + pop → `currentDepth == 0` |
| `exceedThrows` | 4th push throws `maxAgentDepthExceeded` |
| `delegationChainInError` | Error message contains plan IDs |

---

## Feature 5: Memory Recall Diversification (MMR)

**OpenClaw Reference**: `src/memory/mmr.ts` (215 lines)

### What It Does
When `AgentGraphMemory.recall()` retrieves memories for context injection, raw fuzzy search often returns near-duplicate results (e.g., 5 nodes about "Swift concurrency"). MMR re-ranks results to balance relevance with diversity, ensuring the agent gets a broader context picture.

### Algorithm

```
MMR Score = λ × relevance - (1 - λ) × max_similarity_to_already_selected

Where:
- λ = 0.7 (favor relevance, mild diversity push)
- relevance = normalized fuzzy search score [0, 1]
- similarity = Jaccard similarity of tokenized node content
```

### Implementation

#### [NEW] `Epistemos/Omega/Safety/MMRReranker.swift`

```swift
struct MMRReranker {
    let lambda: Double = 0.7

    struct ScoredItem {
        let id: String
        let score: Double
        let content: String
    }

    /// Tokenize text into lowercase alphanumeric tokens
    static func tokenize(_ text: String) -> Set<String> {
        // Regex: [a-z0-9_]+
        let pattern = /[a-z0-9_]+/
        let lower = text.lowercased()
        return Set(lower.matches(of: pattern).map { String($0.output) })
    }

    /// Jaccard similarity ∈ [0, 1]
    static func jaccardSimilarity(_ a: Set<String>, _ b: Set<String>) -> Double {
        guard !a.isEmpty || !b.isEmpty else { return 1.0 }
        guard !a.isEmpty, !b.isEmpty else { return 0.0 }
        let intersection = a.intersection(b).count
        let union = a.union(b).count
        return Double(intersection) / Double(union)
    }

    /// Re-rank items using MMR
    func rerank(_ items: [ScoredItem]) -> [ScoredItem] {
        guard items.count > 1 else { return items }

        // Pre-tokenize
        let tokenCache = Dictionary(uniqueKeysWithValues: items.map { ($0.id, Self.tokenize($0.content)) })

        // Normalize scores to [0, 1]
        let maxScore = items.map(\.score).max() ?? 1.0
        let minScore = items.map(\.score).min() ?? 0.0
        let range = maxScore - minScore

        func normalize(_ score: Double) -> Double {
            range == 0 ? 1.0 : (score - minScore) / range
        }

        var selected: [ScoredItem] = []
        var remaining = Set(items.map(\.id))

        while !remaining.isEmpty {
            var bestId: String?
            var bestMMR = -Double.infinity

            for id in remaining {
                guard let item = items.first(where: { $0.id == id }) else { continue }
                let relevance = normalize(item.score)
                let itemTokens = tokenCache[id] ?? []

                var maxSim = 0.0
                for sel in selected {
                    let selTokens = tokenCache[sel.id] ?? []
                    maxSim = max(maxSim, Self.jaccardSimilarity(itemTokens, selTokens))
                }

                let mmr = lambda * relevance - (1 - lambda) * maxSim
                if mmr > bestMMR || (mmr == bestMMR && item.score > (items.first { $0.id == bestId }?.score ?? -.infinity)) {
                    bestMMR = mmr
                    bestId = id
                }
            }

            guard let chosen = bestId, let item = items.first(where: { $0.id == chosen }) else { break }
            selected.append(item)
            remaining.remove(chosen)
        }

        return selected
    }
}
```

### Wiring

In `AgentGraphMemory.recall()`, after fuzzy search returns raw results:
```swift
let raw = graphStore.fuzzySearch(query: query, limit: limit * 2)  // Over-fetch
let scored = raw.map { MMRReranker.ScoredItem(id: $0.id, score: $0.score, content: $0.body) }
let diversified = MMRReranker().rerank(scored)
return Array(diversified.prefix(limit))  // Trim to requested limit
```

### Tests — `EpistemosTests/MMRRerankerTests.swift`

| Test | Expectation |
|------|-------------|
| `emptyInputReturnsEmpty` | `rerank([]) == []` |
| `singleItemReturned` | `rerank([x]) == [x]` |
| `identicalContentsDemoted` | 3 items with same content → not all at top |
| `diverseContentPromoted` | Item with unique tokens ranked higher than duplicate |
| `lambdaOneIsRelevanceOnly` | `lambda = 1.0` → sorted by score descending |
| `lambdaZeroIsDiversityOnly` | `lambda = 0.0` → maximally diverse selection |
| `jaccardIdenticalIs1` | `jaccardSimilarity(a, a) == 1.0` |
| `jaccardDisjointIs0` | `jaccardSimilarity({"a"}, {"b"}) == 0.0` |
| `tokenizeNormalizesCase` | `tokenize("Hello WORLD") == {"hello", "world"}` |

---

## Feature 6: Execution Transcript Repair

**OpenClaw Reference**: `src/agents/session-transcript-repair.ts` (523 lines)

### What It Does
When the LLM generates malformed tool calls (missing IDs, orphaned results, duplicated results), the transcript must be repaired before resuming conversation or persisting. Without this, subsequent LLM calls fail with "unexpected tool_use_id" errors.

### Implementation

#### [NEW] `Epistemos/Omega/Safety/TranscriptRepair.swift`

```swift
struct TranscriptRepair {
    struct ToolCall {
        let id: String
        let name: String
        let args: String
    }

    struct ToolResult {
        let toolCallId: String
        let content: String
        var isError: Bool = false
    }

    struct RepairReport {
        var repairedMessages: [OrchestratorState.ExecutionLog]
        var insertedSyntheticResults: Int = 0
        var droppedDuplicates: Int = 0
        var droppedOrphans: Int = 0
    }

    /// Repair a transcript ensuring every tool call has exactly one matching result.
    static func repair(_ logs: [OrchestratorState.ExecutionLog]) -> RepairReport {
        var report = RepairReport(repairedMessages: [])
        var seenResultIds = Set<String>()

        var i = 0
        while i < logs.count {
            let log = logs[i]

            // For tool-call logs, find and pair their results
            guard case .toolCall(let call) = log.entry else {
                // Drop orphaned tool results (result without preceding call)
                if case .toolResult(let result) = log.entry {
                    if seenResultIds.contains(result.toolCallId) {
                        report.droppedDuplicates += 1
                    } else {
                        report.droppedOrphans += 1
                    }
                } else {
                    report.repairedMessages.append(log)
                }
                i += 1
                continue
            }

            report.repairedMessages.append(log)

            // Look ahead for matching result
            var foundResult = false
            for j in (i + 1)..<logs.count {
                if case .toolResult(let result) = logs[j].entry,
                   result.toolCallId == call.id {
                    if !seenResultIds.contains(result.toolCallId) {
                        seenResultIds.insert(result.toolCallId)
                        report.repairedMessages.append(logs[j])
                        foundResult = true
                    } else {
                        report.droppedDuplicates += 1
                    }
                    break
                }
            }

            // Insert synthetic error result if no match found
            if !foundResult {
                let synthetic = OrchestratorState.ExecutionLog(
                    entry: .toolResult(ToolResult(
                        toolCallId: call.id,
                        content: "[Epistemos] Missing tool result — synthetic error inserted for transcript repair.",
                        isError: true
                    )),
                    timestamp: Date()
                )
                report.repairedMessages.append(synthetic)
                report.insertedSyntheticResults += 1
                seenResultIds.insert(call.id)
            }

            i += 1
        }

        return report
    }
}
```

### Wiring

Call `TranscriptRepair.repair()` in two places:
1. **Before resuming** from a checkpoint (to clean up interrupted transcripts).
2. **Before context injection** when building the next LLM prompt from execution history.

### Tests — `EpistemosTests/TranscriptRepairTests.swift`

| Test | Expectation |
|------|-------------|
| `cleanTranscriptUnchanged` | Paired call/result passes through |
| `missingResultGetsSynthetic` | Call without result → synthetic error inserted |
| `duplicateResultDropped` | Two results for same call → second dropped |
| `orphanResultDropped` | Result without preceding call → dropped |
| `mixedTranscriptRepaired` | Complex interleaving → clean output |

---

## Build Order

```
1. ToolLoopDetector      — 0 dependencies, pure logic
2. AgentDepthLimiter     — 0 dependencies, pure logic
3. MMRReranker           — 0 dependencies, pure logic
4. TranscriptRepair      — depends on OrchestratorState types
5. ContextBudgetManager  — depends on MLXInferenceService
6. ExecutionCheckpointManager — depends on OrchestratorState + filesystem
```

## Wiring Order (after all features built)

1. Add all 6 to `AppEnvironment.swift` and `AppBootstrap.swift`.
2. Wire `ToolLoopDetector`, `ContextBudgetManager`, `ExecutionCheckpointManager`, `AgentDepthLimiter` into `OrchestratorState.executePlan()`.
3. Wire `MMRReranker` into `AgentGraphMemory.recall()`.
4. Wire `TranscriptRepair` into checkpoint resume path.

## Verification Plan

```bash
# Build
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5

# Run new tests
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' \
  test -only-testing:EpistemosTests/ToolLoopDetectorTests \
  -only-testing:EpistemosTests/AgentDepthLimiterTests \
  -only-testing:EpistemosTests/MMRRerankerTests \
  -only-testing:EpistemosTests/TranscriptRepairTests \
  -only-testing:EpistemosTests/ContextBudgetManagerTests \
  -only-testing:EpistemosTests/ExecutionCheckpointManagerTests

# Full suite (ensure no regressions)
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test
```

Expected: **BUILD SUCCEEDED**, all new tests pass (6 suites, ~40 tests), no regressions in existing 1403 tests.
