# Codex Handoff — Dead Code Cleanup
**Date:** 2026-03-28
**Author:** Owner (via Claude audit)
**Scope:** Remove ghost code left by the SOAR migration and enrichment-era architecture. No new features. No refactors beyond the specific items listed.

---

## Context

This app went through a major architecture migration. The original system had:
- `EnrichmentController` — 6-pass sequential LLM enrichment wired into the chat pipeline
- `SOARState` / `soarService` — standalone research subsystem
- `SOARDetailView` — its own settings chrome
- `DualMessage` — enrichment-era struct for `rawAnalysis`, uncertainty tags, layman explanation, truth assessment
- `TruthAssessmentCard`, `EpistemicLensPanel`, `ReflectionCard` — enrichment UI panels

All of that was deleted and replaced by the Omega research architecture. But deletion wasn't clean — structural remnants remain in types, query routing, pipeline events, and model persistence. These are what you are here to remove.

---

## Items to Remove

### 1. Dead query intent: `.metaAnalytical`

**Files:**
- `Epistemos/Engine/QueryAnalyzer.swift` — line 65, the regex pattern `("\\b(meta.?analy|pool|systematic review|across studies|heterogeneity)\\b", .metaAnalytical)`
- `Epistemos/Engine/QueryAnalyzer.swift` — line 156, the `isMetaAnalytical` local variable and line 184 where it's set on the result struct
- `Epistemos/Models/EngineTypes.swift` — line 81 `var isMetaAnalytical: Bool` on the analysis result struct, and line 115 `case metaAnalytical = "meta_analytical"` on the `QueryIntent` enum

**Why:** `.metaAnalytical` is detected by `QueryAnalyzer` but nothing in the codebase acts on it. The Bayesian pooling / meta-analysis math it was supposed to trigger was never built. It is a dead signal that adds noise to the type system. No test, no handler, no UI references it.

**What to check after:** `QueryAnalyzer` tests must still pass. Removing the field from the analysis result struct may require updating test fixture initializers — fix those too.

---

### 2. Dead placeholder: `explicitThinkingRequested(in:)`

**File:** `Epistemos/Engine/TriageService.swift` — around line 1201
```swift
private static func explicitThinkingRequested(in text: String) -> Bool {
    _ = text
    return false
}
```

**Why:** This function always returns `false`. The `_ = text` confirms it is a stub that was never implemented. The call sites at lines 1158 and 1195 pass `localReasoningMode == .thinking` directly — which already correctly captures the intent. Remove the dead function and inline the expression at both call sites (it is already inlined; the function is just dead weight).

**What to check after:** `explicitThinkingRequested` is referenced as a property name on `TriageProfile` (line 125) — that field is real and used. Only the private static *function* with the same name is dead. Do not remove the struct field.

---

### 3. Empty `rawAnalysis` in `PipelineService.completed`

**File:** `Epistemos/Engine/PipelineService.swift` — around line 100
```swift
.completed(
    DualMessage(rawAnalysis: "", uncertaintyTags: [], modelVsDataFlags: []),
    nil
)
```

**Why:** `rawAnalysis` is always emitted as an empty string. `uncertaintyTags` and `modelVsDataFlags` are always empty arrays. The enrichment pipeline that populated these was removed. `DualMessage` is now a hollow struct being passed through the event just to satisfy a type signature.

**Fix:** Check every consumer of the `.completed` event. If nothing reads `rawAnalysis`, `uncertaintyTags`, or `modelVsDataFlags` in any meaningful way, collapse `DualMessage` to just carry what's actually used, or remove it from the `.completed` event signature entirely and update all pattern-match sites.

---

### 4. Enrichment-era persistence fields on `SDMessage`

**File:** `Epistemos/Models/SDMessage.swift` — around line 24
```swift
var dualMessageData: Data?      // Encoded DualMessage (rawAnalysis + uncertainty + layman)
var truthAssessmentData: Data?  // Encoded TruthAssessment
```

**Why:** These were SwiftData-persisted fields for the enrichment pipeline output. The enrichment pipeline is gone. `dualMessageData` is never written to with real content. `truthAssessmentData` has no writer anywhere in the current codebase.

**Fix:** Remove both fields from the SwiftData model. This is a schema migration — add a `@available` migration or a lightweight migration schema version so existing databases don't crash. Check `SDMessage` usages for any reads of these fields and remove those too.

**What to check after:** Run `xcodebuild test` — SwiftData schema changes can cause test failures if in-memory stores aren't updated. Fix any test fixtures that initialize `SDMessage` with these fields.

---

### 5. Agent operating mode shown in UI but routes same as Fast

**File:** `Epistemos/Views/MiniChat/MiniChatView.swift` — around line 1081, `case .agent` handling
**Also check:** `OperatingModeSelectorView`, `ChatInputBar`, anywhere `.agent` appears in mode lists

**Why:** Per the release audit (item #2): "Agent mode shown in UI but routes same as Fast mode." The `case .agent` branch in `MiniChatView` adds the user message then shows a `handoffMessage` — but the actual inference path is identical to Fast. This misleads the user.

**Fix:** Either (a) hide `.agent` from `availableOperatingModes` the same way unsupported modes are hidden for models that don't support them — until Omega agent routing is properly wired to this surface, or (b) route `.agent` submissions to `orchestrator.submitTask()` instead of the standard pipeline, which is what they should do. Option (a) is the minimal fix. Option (b) is the correct fix but larger scope — owner's call.

---

### 6. `AppStoreHelper.GatewayConnection` TODO stub

**File:** `Epistemos/Omega/Distribution/AppStoreHelper.swift` — around line 165
```swift
static func connect(socketPath: String, authToken: String) async throws -> GatewayConnection {
    // TODO: Actual UDS connection + auth handshake
    throw GatewayError.helperNotInstalled
}
```

**Why:** This is a documented stub that always throws. The MAS distribution path was decided against (direct distribution only, see `2026-03-28-distribution-decision-and-compliance-report.md`). This gateway is never going to be used for v1.

**Fix:** If the entire `AppStoreHelper` MAS gateway path is dead for v1, remove `GatewayConnection` and `connect(socketPath:authToken:)`. Keep only the parts of `AppStoreHelper` that serve direct distribution (license checking, update checking if any). If the whole file is dead, remove it and update `project.yml`.

---

## Rules for This Cleanup

1. **Read every file before touching it.** Do not change code you haven't read.
2. **Remove only what's listed.** Do not refactor adjacent code, rename things, or improve style.
3. **Fix all call sites.** When removing a field or function, find and fix every reference. Use `xcodebuild build` to confirm zero errors before running tests.
4. **Run the full test suite after each item.** `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test`. 2,631 Swift tests must pass. Fix any test that referenced the removed code — but only fix, don't rewrite.
5. **One commit per item.** Keeps the git history clean and makes regressions easy to bisect.
6. **No new abstractions.** If removing a field requires updating 8 call sites, update 8 call sites. Don't add a migration helper unless SwiftData literally requires it.

---

## What NOT to Touch

- `ResearchEvidenceScorer`, `ResearchComplexityGate`, `ResearchConfidenceState` — these are the *live* successors to SOAR. They look minimal but they are intentional.
- `DualBrainRouter` and the `brain2DeviceANE` case — this is planned architecture (Ω19), not dead code.
- The `cloud` case in `TriageDecision` — this is live and used. Do not remove.
- `Screen2AXService` placeholder comment — the vision integration is planned (Ω13+), the placeholder comment is honest documentation.
- `MoLoRAInferenceService` — it references a Python script that may or may not be bundled yet. The Swift side is correct; leave it.
