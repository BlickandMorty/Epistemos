# Codex Master Prompt — Epistemos Audit + Continuation

**Paste this ONCE at the start of your first Codex session. It restores full context.**

## STATUS CORRECTION — 2026-04-01

Several items in this prompt became stale after later follow-up work:

- Phase 6F harness wiring is complete
- Phase 7A-7G harness lab work is complete
- The core Hermes/Omega follow-ons from `docs/BEST_OF_CLAW_AND_OPENCLAW.md` are largely implemented; use `docs/AGENT_PROGRESS.md` before assuming tool gates, auto-discovery, skills, cost tracking, stream composition, or NightBrain distillation are still pending
- `EmbeddingService` push-to-Rust work is already off the main actor
- `ResearchPause.swift` already mirrors the `ConfirmationGate` timeout/cancellation pattern
- `VaultSyncService` timers now restart when power mode returns to `.full`
- `DualBrainRouter` only reports dual-brain active when a dedicated ANE backend is actually in use

---

You are the principal systems architect for **Epistemos** — a macOS-native cognitive exoskeleton PKM built on Swift 6 + Rust (UniFFI FFI) + Metal compute shaders. 137K lines Swift, 94K lines Rust, 370 Swift files, 99 Rust files, 115 test files.

## PHASE 1: READ THESE FILES (in this exact order)

Read every file listed below. Do not skip any. Do not summarize — absorb the full content.

### Tier 1: Project Rules & Master Plans
1. `CLAUDE.md` — Non-negotiable constraints, file map, provider matrix, build commands
2. `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md` — THE single source of truth: 13 phases, succession order, what's done, what's next, ADRs
3. `docs/CODEX_HANDOFF.md` — Detailed handoff from the prior Claude session: every change, runtime analysis, audit checklist, research context

### Tier 2: Agent System (Hermes is THE backend — understand this deeply)
4. `docs/BEST_OF_CLAW_AND_OPENCLAW.md` — historical pattern source; many items from this plan are now implemented, so cross-check with `docs/AGENT_PROGRESS.md`
5. `docs/FUSED_AGENT_ENGINEERING_REPORT.md` — Root cause analysis + upgrade path for the agent system
6. `docs/HERMES_INTEGRATION_RESEARCH.md` — 40-file deep study of hermes-agent internals
7. `docs/HERMES_PARITY_REPORT.md` — What hermes-agent can do vs what Epistemos exposes
8. `docs/AGENT_INTEGRATION_SESSION_PLAN.md` — Step-by-step plan for wiring agent features
9. `docs/AGENT_DEEP_VERIFICATION_MANUAL.md` — Verification procedures for agent system
10. `docs/IMPLEMENTATION_PROMPTS.md` — 8 paste-ready implementation prompts (tool gates, auto-discovery, agent loop, skills, iMessage, NightBrain, streams, release)

### Tier 3: Architecture, Deep Analysis & Vision
11. `docs/EPISTEMOS_FUSED_v3.md` — Complete 8-phase build spec for the full app
12. `docs/epistemos-deep-analysis.md` — Deep architectural analysis of the entire codebase
13. `docs/CLOUD_KNOWLEDGE_DISTILLATION_SPEC.md` — Per-model vault knowledge compilation
14. `docs/VISION_BACKLOG.md` — **COMPLETE 8-tier feature inventory**: Hermes v0.6.0 parity, coding features, graph enhancements, sidebar overhaul, multi-agent system, communication channels, optimization, business features
15. `docs/MASTER_SESSION_PROMPT.md` — Original master session context
16. `docs/MASTER_SESSION_PROMPT_v2.md` — Updated: Five Engines, anti-drift rules, remaining work tiers, architecture map

### Tier 4: Research Foundation
16. `~/arc/arc2.md` — PRIMARY: Canonical pattern integrity audit (7 areas: OTP, FSM, breaker, FFI, Foundation Models, ThermalGuard, cross-cutting risks)
17. `~/arc/arc6.md` — PRIMARY: Hardening implementation authority
18. `~/arc/arc7.txt` — Typestate, zero-allocation circuit breakers, noncopyable FFI handles
19. `~/arc/harn2.txt` — Meta-Harness integration (tripartite architecture, bootstrap packets, completion checkers)
20. `~/arc/harn3.txt` — Meta-Harness detailed implementation blueprint (trace storage, proposer loop, evaluation strategy)
21. `~/stateful-rotor-implementation-reference.md` — Quantization pipeline, concurrency model, Apple Silicon optimization, Metal kernel patterns
22. `~/EPISTEMOS-RESEARCH-REFERENCE.md` — Complete 50+ paper research synthesis (rotation matrices, KV cache, search architecture)

### Tier 5: Verification & Operational Protocols
23. `docs/SESSION_BOOTSTRAP_PROMPT.md` — Lists all harness/hardening files to verify, build commands, Swift 6.2 gotchas
24. `docs/HARDENING_VERIFICATION.md` — 52-item grep-based verification checklist for all 8 phases
25. `docs/VERIFICATION_PROTOCOL.md` — Detailed verification steps for each hardening phase
26. `docs/PERPLEXITY_DEEP_AUDIT_PROMPT.md` — Deep audit prompt for external verification

### Tier 6: Key Implementation Files (verify these are correct)
27. `Epistemos/State/PowerGuard.swift` — 3-tier power mode (eco defaults ON)
28. `Epistemos/State/ThermalGuard.swift` — Centralized thermal authority with continuation parking
29. `Epistemos/State/AppSupervisor.swift` — OTP supervisor, ModeMachine, BreakerRegistry
30. `Epistemos/State/TimeoutUtility.swift` — Per-domain circuit breakers, UInt64 bit ring, execute<T>()
31. `Epistemos/Engine/AppleIntelligenceService.swift` — FoundationModels with breaker pattern
32. `Epistemos/Agent/HermesMCPClient.swift` — MCP client with timeout fixes
33. `Epistemos/Agent/HermesSubprocessManager.swift` — Auth detection, keychain mappings
34. `Epistemos/App/AppBootstrap.swift` — PowerGuard init, shader lock, Hermes gate
35. `agent_core/src/bridge.rs` — FFI truth boundary, ffi_guard macros
36. `Epistemos/Views/Graph/MetalGraphView.swift` — 60fps cap, calmer physics, quality level sync
37. `Epistemos/Graph/GraphState.swift` — Performance mode default, PowerGuard quality override

## PHASE 2: FULL AUDIT

After reading all files, perform a comprehensive audit. For each area below, verify the implementation is correct, report any issues found, and fix them.

### 2A. Continuation Safety Audit
Grep for ALL `withCheckedContinuation` and `withCheckedThrowingContinuation` in the Swift codebase. For each occurrence:
- Verify every code path resumes the continuation exactly once
- Verify `withTaskCancellationHandler` wraps any stored continuation
- Verify there is a timeout or cancellation safety net
- `Epistemos/Omega/Orchestrator/ResearchPause.swift` now mirrors the `ConfirmationGate` timeout/cancellation pattern; only reopen it if a fresh continuation regression appears

### 2B. PowerGuard Integration Audit
- Verify eco mode defaults to ON for new installs (check `PowerGuard.init()` and `EpistemosConfig`)
- Verify graph defaults to performance mode for new installs (check `GraphState.performanceModeEnabled`)
- Verify `qualityLevel` returns 2 in eco/lowPower regardless of user preference
- Verify MetalGraphView pushes updated quality level when PowerGuard mode changes
- Verify `VaultSyncService` timers DO restart when returning to `.full` mode (fixed on 2026-04-01)
- Verify NightBrain and Heartbeat canStart() checks work
- Verify ScreenCaptureService blocks startStream() in eco/lowPower

### 2C. Hardening Verification (run the grep checklist)
Execute every grep command from `~/arc/HARDENING_VERIFICATION.md` and verify all 52 items pass. Report any failures.

### 2D. Code Signing Verification
- Verify `embed-and-sign-rust-dylib.sh` strips old sig, passes entitlements, uses --options runtime
- Verify all three build scripts (omega-mcp, omega-ax, epistemos-core) conditionally skip ad-hoc signing inside Xcode
- Build the app and run `codesign --verify --deep --strict`

### 2E. MCP Timeout Verification
- Verify `listTools()` timeout is 5s
- Verify default MCP timeout is 10s
- Verify `removePending` resumes continuation with error on timeout
- Verify `cancelAll()` resumes all pending continuations

### 2F. Cross-Cutting Risk Verification (from arc2 Section 7)
- Verify thermal pauses don't trip circuit breaker (CircuitBreakerIgnorable protocol)
- Verify ThermalGuard acquireClearance() is called before inference in AppleIntelligenceService
- Verify AppSupervisor health check uses EventStore.shared for knowledge store check
- Verify mode machine is driven by thermal state changes

### 2G. Main Thread Hang Investigation
Historical note: the old 3738ms hang correlated with `EmbeddingService: pushed 1017 embeddings (dim=300) to Rust`, but that push path is already off the main actor in current code. Only reopen this if fresh logs show the same hotspot.

### 2H. Layout Recursion
Find the source of `_NSDetectedLayoutRecursion` only if it still reproduces. A current source grep no longer shows production `layoutSubtreeIfNeeded` call sites, so treat the old breadcrumb as historical until a live breakpoint proves otherwise.

## PHASE 3: CONTINUE WITH MASTER PLAN

After the audit is complete and all issues are fixed, continue building. Two parallel tracks:

### Track A: Harness Wiring (from MASTER_HARDENING_AND_HARNESS_PLAN.md)
1. **Do not restart Phase 6F or Phase 7 work** — those items are complete; verify against `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md`
2. **Use Track A for regression work only** — harness lifecycle fixes, trace integrity, progress persistence, and completion checks
3. **Treat Phase 8+ as the next net-new harness/runtime roadmap only after current regressions are clear**

### Track B: Agent System (from BEST_OF_CLAW_AND_OPENCLAW.md)
Most of the core BEST_OF_CLAW follow-ons are already in the tree. Before starting any item below, confirm it is still missing in `docs/AGENT_PROGRESS.md` and the code:
1. **Tool Gates** — already logged/exported in current Hermes integration
2. **Auto-Discovery** — already runs at startup with env/config/keychain precedence
3. **Agent Loop Hardening** — largely shipped across Hermes/Omega sprints
4. **Skills System** — shipped; Hermes admin + progressive disclosure are in tree
5. **Cost Tracking** — shipped
6. **Stream Composition** — shipped
7. **iMessage / other truly unshipped extras** — still candidate future work if desired

### Track C: Cloud Knowledge Distillation (from CLOUD_KNOWLEDGE_DISTILLATION_SPEC.md)
Per-model vaults that compile vault knowledge into structured context files. Lower priority than Tracks A and B but should be scaffolded.

### Track D: Vision Backlog (from VISION_BACKLOG.md — THE BIG PICTURE)
Read `docs/VISION_BACKLOG.md` for the complete **11-tier, 70+ item** feature inventory:
- **Tier 0:** Ship-blocking (notarization, continuation fix, embedding hang)
- **Tier 1:** Hermes v0.6.0 parity (profiles, fallback chains, MCP server mode)
- **Tier 2-4:** Coding features, graph cinema, sidebar overhaul
- **Tier 5-6:** Multi-agent system, communication channels
- **Tier 7-8:** Optimization, business features
- **Tier 9:** Code editor & IDE (CoreText surface, Rust Rope, Tree-sitter, LSP supervisor, BoltFFI)
- **Tier 10:** Control plane architecture (GUI control plane for agent runtime, MCP spine, doctor/update, Paperclip company OS mode)
- **Tier 11:** Zero-copy & performance engineering (noncopyable FFI handles, typestate, capability tokens, Arrow/FlatBuffers IPC)

**KEY INSIGHT (from deep research):** The app won't feel like Hermes/OpenClaw until it becomes a **control plane** that exposes their real primitives (profiles, sessions, skills, tools, cron, gateways, hardening). Hermes v0.6.0 + MCP gives the clean backbone.

Work through phases A→G as defined in the execution order at the bottom of VISION_BACKLOG.md.

## RULES FOR EVERY ACTION

- Always read files before editing them
- Use `@Observable` not `ObservableObject`
- Use Swift Testing (`@Test`, `#expect`) for new tests
- All inference on background actors — never block @MainActor
- No try!, no force-unwraps, no print() in production
- DispatchQueue.main.async in UniFFI callbacks, NEVER .sync
- Do NOT edit .xcodeproj directly — run `xcodegen generate` after adding files
- API keys in macOS Keychain, NEVER UserDefaults
- Stream every token immediately, never buffer
- Preserve thinking blocks + signatures in tool_use responses
- Run verification after each completed task

## BUILD COMMANDS

```bash
# Build
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify

# Rust tests
cargo test --manifest-path agent_core/Cargo.toml

# Regenerate Xcode project
xcodegen generate
```

Now read all the files listed above and begin the audit.
