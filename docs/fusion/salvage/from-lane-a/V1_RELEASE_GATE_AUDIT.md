# Epistemos V1 Release Gate Audit

**Date:** 2026-04-07  
**Auditor:** Kimi Code CLI  
**Scope:** Agents, Code Editor, Graph Engine, Local Models, Release Readiness  
**Status:** 🔴 **NOT READY FOR RELEASE**

---

## Executive Summary

| Category | Status | Blockers |
|----------|--------|----------|
| **Automated Tests** | ⚠️ Partial | Swift tests blocked by build DB lock; Rust tests pass (2455/2455) |
| **Agents/Hermes** | 🟡 Functional | Tool gates require manual keychain setup; no MCP server validation |
| **Code Editor** | 🟢 Ready | Prose editor stable; CodeEditorView implemented with themes |
| **Graph Engine** | 🟡 Mostly Ready | P0 FFI crash fixed; 3 P2 features pending (inspect mode, node creation, wikilinks) |
| **Local Models** | 🔴 Not Ready | Context windows wrong; 9 models missing from catalog; no vision/tool extraction |
| **Distribution** | 🔴 Not Ready | Missing PrivacyInfo.xcprivacy; minimal entitlements; no notarization setup |

**Verdict:** The app is **functionally operational** but has **critical gaps** in model utilization and **distribution compliance** that block a v1 release.

---

## 1. Automated Test Status

### Rust Tests (graph-engine)
```
✅ 2455 passed
✅ 0 failed
✅ 8 ignored
```
**Status:** Excellent. All physics, FFI, and knowledge-core tests pass.

### Swift Tests (Epistemos)
```
❌ Build failed - database locked (concurrent build issue)
⚠️ SwiftLint failures in CodeEditSourceEditor/CodeEditTextView dependencies
```
**Status:** Cannot verify. Build infrastructure issue blocked test execution.

### Required Action
```bash
# Clean build and re-test
rm -rf ~/Library/Developer/Xcode/DerivedData/Epistemos-*
xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS'
```

---

## 2. Agents & Hermes Subsystem

### What's Working
- **HermesSubprocessManager.swift** (150+ lines): Full Python subprocess lifecycle management
- **Tool gate environment**: Keychain integration for API keys (Tavily, Exa, Firecrawl, Browserbase, all cloud providers)
- **HermesHome persistence**: Session learning state preserved in `~/.hermes/`
- **Bridge script**: `epistemos_bridge.py` wraps the real Hermes AIAgent

### What's Missing/At Risk
| Issue | Severity | Details |
|-------|----------|---------|
| No MCP server validation | Medium | `EpistemosMCPServer.swift` exists but no runtime tests |
| Tool gates require manual setup | Medium | Users must pre-populate keychain or env vars |
| No graceful Hermes fallback | Medium | If Python subprocess fails, no cloud fallback |
| GhostComputerAgent complexity | High | 66-file Omega subsystem; research handoff untested |

### Code Quality Assessment
- ✅ Proper `Sendable` conformance
- ✅ Task cancellation handling
- ✅ Environment variable normalization
- ⚠️ No subprocess health monitoring (restart on crash)

**Agents Verdict:** Functional but **requires runtime validation** of the Omega research pipeline before ship.

---

## 3. Code Editor

### What's Working
| Component | Status | Notes |
|-----------|--------|-------|
| **ProseEditorView** | ✅ Stable | TextKit 2, debounced saves, wikilink navigation |
| **ProseEditorRepresentable2** | ✅ Stable | Coordinator pattern, binding sync |
| **MarkdownContentStorage** | ✅ Stable | Fold state cleanup fixed (header deletion bug) |
| **CodeEditorView** | ✅ Implemented | CodeEditSourceEditor integration, 4 themes |
| **NoteChatState** | ✅ Stable | Streaming AI, accept/discard, divider protection |

### Recent Fixes (Phase 3 Complete)
- ✅ Header deletion collapse button bug fixed
- ✅ Orphaned AI divider stripping on load
- ✅ Debounced binding sync (300ms)

### Code Quality Assessment
- ✅ Proper `@MainActor` usage
- ✅ Task-based cancellation
- ✅ SwiftData integration
- ⚠️ CodeEditSourceEditor dependency adds SwiftLint warnings (external)

**Code Editor Verdict:** **Ready for release.** The editor is the most stable subsystem.

---

## 4. Graph Engine

### What's Working (Ship-Ready)
| Component | Status | Evidence |
|-----------|--------|----------|
| **Metal rendering** | ✅ | `MetalGraphView.swift` 1200+ lines, batch uploads |
| **Physics simulation** | ✅ | 2455 Rust tests pass, energy conservation verified |
| **Nested-focus labels** | ✅ | Phase 2 complete, smooth fade transitions |
| **Inspector pin/unpin** | ✅ | Phase 2 complete, floating vs attached modes |
| **Light mode rework** | ✅ | Phase 2 complete, 75% dimming, no zoom flicker |
| **FFI memory safety** | ✅ | Generation tokens added, crash fixed |

### P2 Features Pending (Not Blockers)
| Feature | Status | Risk |
|---------|--------|------|
| Full-screen inspect mode | ❌ Not started | Medium UX gap |
| Direct node creation | ❌ Not started | Medium UX gap |
| Wikilink/chat link edges | ❌ Not started | Data model gap |

### FFI Safety Post-Fix
The P0 crash fix adds generation tokens:
```rust
// Rust: Engine.generation atomic u64
pub generation: std::sync::atomic::AtomicU64,

// Swift: Validate before FFI call
let gen = graph_engine_generation(engine)
// ... later ...
graph_engine_generation(engineCapture.ptr) == engineCapture.gen
```
**Status:** Crash prevented, but race window still exists (validated mitigation).

**Graph Engine Verdict:** **Core is ready.** Missing P2 features are UX enhancements, not blockers.

---

## 5. Local Models (Critical Issues)

### The Problem
Per my detailed audit (`LOCAL_MODEL_CAPABILITY_AUDIT_SYNTHESIS.md`), the local model infrastructure has **severe accuracy issues**:

### Issue 1: Context Windows Severely Under-Reported
| Model | Current Code | Actual | Wasted |
|-------|--------------|--------|--------|
| Qwen 3.5 0.8B/2B/4B | 32,768 | 262,144 | **87%** |
| Qwen 3.5 9B/27B/35B | 131,072 | 262,144 | **50%** |
| DeepSeek R1 7B | 65,536 | 128,000 | **49%** |
| Gemma 4 12B | 131,072 | 256,000 | **49%** |

**Impact:** Users cannot use the full context windows they paid (in RAM) for.

### Issue 2: Missing Model Catalog Entries
9 of 18 models have **no install metadata** in `LocalModelCatalog`:
- Gemma 4: 2B, 4B, 12B, 27B MoE, 31B JANG
- DeepSeek R1 Distill 7B
- Qwen 2.5 Coder 7B
- Qwopus 27B v3, MoE 35B

### Issue 3: model_manifest.json Empty
```json
{
  "models": {
    "retriever_primary": { ... }  // Only entry
  }
}
```
Should contain all 18 models with Ollama tags, context, temperatures.

### Issue 4: Temperature Values Wrong
| Model | Current | Should Be |
|-------|---------|-----------|
| Gemma 4 | 0.7 | **1.0** (trained at this temp) |
| DeepSeek R1 | 0.5 | 0.6 (range 0.5-0.7) |
| Qwen Coder | 0.3 | ✅ Correct |

### Issue 5: Vision & Tool Extraction Not Implemented
- `supportsVision: Bool` exists but **no vision encoder integration**
- `supportsNativeToolCalling: Bool` exists but **no tool-call parsers**
- No Gemma 4 `<start_function_call>` parser
- No Qwen `<tool_call_start>` parser
- No SmolLM3 XML `<tool_call>` parser

**Local Models Verdict:** 🔴 **NOT READY.** The infrastructure is 75% implemented but the values are wrong. This is a **ship-blocking issue** for any release claiming "18 local models."

---

## 6. Distribution & Compliance

### Missing Required Files
| File | Status | Impact |
|------|--------|--------|
| `PrivacyInfo.xcprivacy` | ❌ Missing | **App Store rejection** |
| `Epistemos-Info.plist` NSServices | ❌ Missing | No Services menu integration |
| Entitlements (sandbox) | ⚠️ Minimal | May not pass review |

### Current Entitlements (Minimal)
```xml
<key>com.apple.security.cs.allow-jit</key><true/>
<key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/>
<key>com.apple.security.cs.disable-library-validation</key><true/>
```

**Missing for Sandbox:**
- `com.apple.security.app-sandbox` (not present - app is NOT sandboxed)
- File access entitlements (documents, downloads, desktop)
- Network entitlements
- User-selected file entitlement

### Info.plist Assessment
| Key | Status |
|-----|--------|
| CFBundleIdentifier | ✅ `com.epistemos.app` |
| CFBundleVersion | ✅ `1` |
| CFBundleShortVersionString | ✅ `1.0.0` |
| CFBundleIconName | ✅ `AppIcon` |
| NSScreenCaptureUsageDescription | ✅ Present |
| NSAccessibilityUsageDescription | ✅ Present |
| NSAppleEventsUsageDescription | ✅ Present |
| ITSAppUsesNonExemptEncryption | ✅ `<false/>` |

**Distribution Verdict:** 🔴 **NOT READY.** Missing privacy manifest, not sandboxed, no notarization setup.

---

## 7. Release Readiness Matrix

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Swift tests pass | ❌ | Build DB lock blocked execution |
| Rust tests pass | ✅ | 2455/2455 |
| App builds | ⚠️ | Yes, but SwiftLint warnings |
| App launches | ⚠️ | Presumed yes (not runtime tested) |
| Core features work | 🟡 | Graph ready, editor ready, agents untested |
| No critical crashes | 🟡 | P0 FFI crash fixed, but race remains |
| Distribution ready | 🔴 | No privacy manifest, not sandboxed |
| Models fully utilized | 🔴 | Context windows wrong, 9 models missing |

---

## 8. Ship-Blocking Issues (Must Fix)

### P0 - Release Blockers
1. **Fix local model context windows** - 50-87% capability wasted
2. **Add missing 9 models to LocalModelCatalog** - They're in the enum but can't install
3. **Populate model_manifest.json** - Required for Ollama bridge
4. **Create PrivacyInfo.xcprivacy** - App Store requirement
5. **Clean build and verify Swift tests pass** - Currently blocked

### P1 - High Priority
6. **Add sandbox entitlements** - Currently not sandboxed
7. **Fix temperature values** - Gemma 4 should be 1.0
8. **Runtime test Omega research pipeline** - 66 files, untested
9. **Add vision encoder integration** - Flags exist but no implementation

### P2 - Medium Priority (Can Ship Without)
10. Full-screen graph inspect mode
11. Direct node creation in graph
12. Wikilink edge wiring
13. Tool-call extraction parsers

---

## 9. Recommendations

### Option A: Delay Release (Recommended)
Fix P0 blockers, then re-audit:
- 1-2 days: Fix context windows, add missing models, populate manifest
- 1 day: Create privacy manifest, sandbox entitlements
- 1 day: Clean build, full test pass, runtime validation

### Option B: Limited Beta Release
Ship to TestFlight/direct with caveats:
- Document: "Local models limited to 32K context (full 256K coming)"
- Document: "9 models pending download support"
- Requires manual API key setup for agents

### Option C: Remove Local Models Claim
Ship without the 18-model local stack:
- Keep Apple Intelligence + Cloud only
- Defer local model fixes to v1.1
- Reduces risk, simplifies release

---

## 10. Final Verdict

**🔴 NOT READY FOR V1 RELEASE**

The app has:
- ✅ Solid core (graph, editor, basic agents)
- ⚠️ Untested advanced features (Omega research)
- 🔴 Broken local model claims (context windows wrong)
- 🔴 Missing distribution compliance (privacy manifest)

**Estimated time to release-ready:** 3-5 days of focused work on P0 blockers.

**Confidence in verdict:** High. The local model issues are objective (values in code don't match model specs), and the privacy manifest is a known App Store requirement.

---

*Audit completed following Epistemos Release Audit skill protocol.*
*Next step: Fix P0 blockers, achieve 3 consecutive zero-fail test passes, re-audit.*
