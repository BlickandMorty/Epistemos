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
4. `docs/AGENT_FUSION_RESEARCH_PROMPT.md` — Research analyzing 8 open-source agent projects (Hermes, GoClaw, Phantom, OpenSwarm, Claw Code, CodeNano, OpenClaw, Hermes IDE)
4b. **CRITICAL:** Read `1-RESEARCH` section in VISION_BACKLOG.md — Advisory Council findings: minimize orchestration tax, MCP as spine, selective 5-pattern adoption only, the Fusion Penalty, competitive moat = knowledge layer not agent runtime
5. `docs/BEST_OF_CLAW_AND_OPENCLAW.md` — historical pattern source; many items now implemented, cross-check with `docs/AGENT_PROGRESS.md`
6. `docs/FUSED_AGENT_ENGINEERING_REPORT.md` — Root cause analysis + upgrade path for the agent system
7. `docs/HERMES_INTEGRATION_RESEARCH.md` — 40-file deep study of hermes-agent internals
8. `docs/HERMES_PARITY_REPORT.md` — What hermes-agent can do vs what Epistemos exposes
9. `docs/AGENT_INTEGRATION_SESSION_PLAN.md` — Step-by-step plan for wiring agent features
10. `docs/AGENT_DEEP_VERIFICATION_MANUAL.md` — Verification procedures for agent system
11. `docs/IMPLEMENTATION_PROMPTS.md` — 8 paste-ready implementation prompts (tool gates, auto-discovery, agent loop, skills, iMessage, NightBrain, streams, release)

### Tier 3: Architecture, Deep Analysis & Vision
12. `docs/EPISTEMOS_FUSED_v3.md` — Complete 8-phase build spec for the full app
13. `docs/epistemos-deep-analysis.md` — Deep architectural analysis of the entire codebase
14. `docs/CLOUD_KNOWLEDGE_DISTILLATION_SPEC.md` — Per-model vault knowledge compilation
15. `docs/VISION_BACKLOG.md` — **COMPLETE 13-tier, 100+ item feature inventory with phases A→I→H**
16. `docs/CONTROL_PLANE_RESEARCH.md` — **CRITICAL**: Why the app feels disconnected. The fix: GUI control plane. MCP as spine.
17. `docs/MASTER_SESSION_PROMPT.md` — Original master session context
18. `docs/MASTER_SESSION_PROMPT_v2.md` — Five Engines, anti-drift rules, architecture map

### Tier 4: Research Foundation
19. `~/arc/arc2.md` — PRIMARY: Canonical pattern integrity audit (7 areas: OTP, FSM, breaker, FFI, Foundation Models, ThermalGuard, cross-cutting risks)
17. `~/arc/arc6.md` — PRIMARY: Hardening implementation authority
18. `~/arc/arc7.txt` — Typestate, zero-allocation circuit breakers, noncopyable FFI handles
19. `~/arc/harn2.txt` — Meta-Harness integration (tripartite architecture, bootstrap packets, completion checkers)
20. `~/arc/harn3.txt` — Meta-Harness detailed implementation blueprint (trace storage, proposer loop, evaluation strategy)
21. `~/stateful-rotor-implementation-reference.md` — Quantization pipeline, concurrency model, Apple Silicon optimization, Metal kernel patterns
22. `~/EPISTEMOS-RESEARCH-REFERENCE.md` — Complete 50+ paper research synthesis (rotation matrices, KV cache, search architecture)
23. `~/Downloads/files (9)/AGENT_ADVISORY_COUNCIL.md` — 5-expert verdict: orchestration tax, MCP as spine, selective 5-pattern adoption, Fusion Penalty
24. `~/Downloads/files (9)/UNIFIED_RESEARCH_SYNTHESIS.md` — 8-project fusion analysis: performance budgets, competitive moat = knowledge layer

### Tier 5: Zero-Corruption, Hardening & Living Vault
23. `~/Downloads/release/FINAL DOCS/1. CORRUPTION/ZERO_CORRUPTION_SPEC.md` — F_FULLFSYNC, BLAKE3, atomic writes, WAL, Unicode NFC, 7-layer integrity. **BINDING CONTRACT.**
24. `~/Downloads/release/FINAL DOCS/2. final hardening/reference research/EPISTEMOS_HARDENING_IMPL_GUIDE.md` — Bookmark defense, TextKit2, adversarial filenames, viewport
25. `~/Downloads/release/FINAL DOCS/3. MUST READS/ANTI_DRIFT_SYSTEM.md` — 5-layer defense against context drift. Post-compaction hooks, sprint sessions, audit prompts
26. `~/Downloads/release/EPISTEMOS_CODEX_RECURSIVE_MASTER_v4.md` — Recursive hardening prompt: 25-doc scan, gap analysis, REF-01 through REF-16, triage card
27. `~/Downloads/last feature after new agents/LIVING_VAULT_ARCHITECTURE.md` — Living Vault: diff engine, memory classifier, Ebbinghaus decay, context compiler, multi-vault registry, agent graph visualizer
28. `~/Downloads/last feature after new agents/sprint-omega-5-living-vault.md` — Sprint tasks for Living Vault implementation
29. `~/Downloads/last feature after new agents/OPERATOR_MANUAL.md` — 3-prompt operator workflow

### Tier 6: Verification & Operational Protocols
34. `docs/SESSION_BOOTSTRAP_PROMPT.md` — Lists all harness/hardening files to verify, build commands, Swift 6.2 gotchas
35. `docs/HARDENING_VERIFICATION.md` — 52-item grep-based verification checklist for all 8 phases
36. `docs/VERIFICATION_PROTOCOL.md` — Detailed verification steps for each hardening phase
37. `docs/PERPLEXITY_DEEP_AUDIT_PROMPT.md` — Deep audit prompt for external verification

### Tier 7: Key Implementation Files (verify these are correct)
38. `Epistemos/State/PowerGuard.swift` — 3-tier power mode (eco defaults ON)
39. `Epistemos/State/ThermalGuard.swift` — Centralized thermal authority with continuation parking
40. `Epistemos/State/AppSupervisor.swift` — OTP supervisor, ModeMachine, BreakerRegistry
41. `Epistemos/State/TimeoutUtility.swift` — Per-domain circuit breakers, UInt64 bit ring, execute<T>()
42. `Epistemos/Engine/AppleIntelligenceService.swift` — FoundationModels with breaker pattern
43. `Epistemos/Agent/HermesMCPClient.swift` — MCP client with timeout fixes
44. `Epistemos/Agent/HermesSubprocessManager.swift` — Auth detection, keychain mappings
45. `Epistemos/App/AppBootstrap.swift` — PowerGuard init, shader lock, Hermes gate
46. `agent_core/src/bridge.rs` — FFI truth boundary, ffi_guard macros
47. `Epistemos/Views/Graph/MetalGraphView.swift` — 60fps cap, calmer physics, quality level sync
48. `Epistemos/Graph/GraphState.swift` — Performance mode default, PowerGuard quality override
49. `Epistemos/Engine/TriageService.swift` — Query routing between providers and local models

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

Work through phases A→I→H as defined in the execution order at the bottom of VISION_BACKLOG.md.

**PHASE I (Rust Agent Migration) is MANDATORY before Phase J.** The shipped app must be pure Swift + Rust + Metal. No Python subprocess, no venv, no pip. The agent becomes a Rust dylib loaded via UniFFI (5-15MB, <10ms cold start, zero-copy IPC). See VISION_BACKLOG.md Phase I for the 7-step migration plan.

**Unified Substrate (`docs/UNIFIED_SUBSTRATE_RESEARCH.md` — READ THIS).** The 5 Laws and 4-sprint substrate plan derived from 3 independent research dossiers. NOT a separate phase — weaves into every phase. Key directives:
- **Law 1:** Measure before you cut (Instruments profiling required for any architecture PR)
- **Law 2:** substrate-core is a NEW Rust crate (slotmap entity store), not a refactor of existing code
- **Law 3:** Identity unification first (EntityID as u64 via C ABI, migrate notes first)
- **Law 4:** UniFFI stays until profiling proves hotspots need C ABI
- **Law 5:** Python out-of-process immediately (no-regret, saves 15-25MB)
- Sprint 0 (audit) runs during Phase A. Sprint 1 (EntityID + Python) runs during Phase B. Sprint 2-3 weave into Phases C-D. By Phase I, the substrate is operational.

**Execution order: A → B → C → D → E → F → G → I → H (release).**

**BEFORE STARTING EACH PHASE:** Read the "Research Documents Index" section in `docs/VISION_BACKLOG.md`. Every phase has specific research documents, executive advice, and key insights listed. Read the relevant ones for that phase before writing any code. This ensures every architectural decision is grounded in the research, not guessed.

**CRITICAL ENGINEERING NOTES:**

**Cloud provider overhaul (Tier -1 in VISION_BACKLOG):** The app switches from showing ALL providers' models to ONE active provider at a time. Default is OpenAI with OAuth sign-in (zero API keys — like Xcode). Anthropic requires API key (OAuth killed Feb 2026). Model selector only shows active provider's models + local. Each provider gets native controls (OpenAI: thinking/pro/fast; Anthropic: extended thinking toggle + budget; Google: grounding). Read the full spec in VISION_BACKLOG.md Tier -1.

**Open-source patterns (§1-OPEN-SOURCE in VISION_BACKLOG):** 15 patterns evaluated from 8 projects (Hermes, GoClaw, Phantom, OpenSwarm, Claw Code, CodeNano, OpenClaw, Hermes IDE). Concrete table of what to steal vs skip. Firecrawl enable is one Settings field away (Phase A). CodeNano 17-tool audit in Phase C. Runtime tool creation and session lifecycle in Phase C. Agent teams in Phase F. Everything else is STUDY ONLY or ALREADY BUILT.

**Smart triage audit (-1I in VISION_BACKLOG):** Before building the new triage, Codex MUST audit the current routing logic in: `TriageService.swift`, `PipelineService.swift`, `InferenceState.swift`, `AppleIntelligenceService.swift`, `MLXInferenceService.swift`, `HermesSubprocessManager.swift`, `FallbackChainResolver.swift`. Report what exists, what's broken, what's missing. Then implement the 4-tier chat triage (cloud → secondary cloud → Apple Intelligence → local MLX with complexity routing) and 4-tier agent triage (cloud → secondary cloud → local 9B only → reject with actionable message). Apple Intelligence is NEVER used for agents.

**Disabled node types:** Source (type 3), Quote (type 5), and Person are DISABLED. Do NOT create, render, or wire them. They stay in engine code but must be disconnected from all production paths (GraphBuilder, EntityExtractor, filters, lenses). Only re-enable if the user explicitly says so. See `3-GRAPH` in VISION_BACKLOG.md.

**Immersive mode performance:** Adding floating panels, Contextual Shadows, blur, haptics must NOT degrade fps. NSPanels for isolation, force injection for shadows, early-exit shader for blur. Profile before/after each feature. Reject anything that drops fps by >5%. See `3-PRIME` performance mandate in VISION_BACKLOG.md.

**Graph bugs (fix FIRST in Phase B — confirmed by 4 independent analyses):**
1. sRGB pixel format: `BGRA8Unorm` → `BGRA8Unorm_sRGB` in `renderer.rs` (one line)
2. Precompile .metallib: `xcrun metal` + `xcrun metallib` at build time, load via `new_library_with_data()` — eliminates startup shader compilation and AppBootstrap file-lock workaround
3. Link force pipeline bubble: CPU link forces serialize with GPU N-body — overlap or move to compute shader
4. Louvain clustering: rebuild is not incremental — should only re-cluster affected communities
5. TBDR glow: evaluate Dual Kawase blur for Apple Silicon tile-based architecture
6. Color space: verify all color uniforms are linear before passing to shaders

**SDF labels (research-validated, 4 reports agree — build after bugs):**
- Font: SF Pro Text, Atlas: MTSDF 512×512, `-size 32`, `-pxrange 6`
- Focal point: `cameraoffset` already in uniforms — zero new FFI needed
- Physics: already velocity Verlet (d3-style) — tune parameters only, don't change integrator
- Label cost: <0.5ms — effectively free
- Read `docs/GRAPH_SDF_LABEL_RESEARCH_PROMPT.md` for full 7-section research + architecture challenge

When implementing Phase B (graph-first) and Phase D (Knowledge Brick), read the `4-ENGINEERING` section in VISION_BACKLOG.md first. It specifies isolation architecture (NSPanel floating panels, NSHostingView tab swapping, @Observable state persistence) to prevent layout interference and frame drops. Research the best implementation approach before building — the spec provides a recommended starting point, not a rigid mandate. Profile first, then decide.

## MANDATORY POST-PHASE AUDIT PROTOCOL

**After completing EVERY phase (A through H), you MUST run a full audit before starting the next phase.** This is non-negotiable. Skipping audits between phases is how drift compounds into architectural rot.

### Audit Procedure (run after each phase completes)

**Step 1: Build verification**
```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
cargo test --manifest-path agent_core/Cargo.toml
xcodegen generate  # ensure project file is in sync
```

**Step 2: Hardening verification (grep checklist from HARDENING_VERIFICATION.md)**
Run ALL grep commands from `docs/HARDENING_VERIFICATION.md`. Every single one. Report any failures.

**Step 3: Zero-corruption verification**
```bash
# F_FULLFSYNC present on all durable writes
grep -rn 'F_FULLFSYNC\|fcntl.*51' --include="*.swift" --include="*.rs" | wc -l
# No try? on file writes
grep -rn 'try?' --include="*.swift" Epistemos/Sync/NoteFileStorage.swift | wc -l  # should be 0
# catch_unwind on all FFI exports
grep -rn 'ffi_guard_sync!\|ffi_guard_value!\|catch_unwind' --include="*.rs" agent_core/src/bridge.rs | wc -l
# No force unwraps in production
grep -rn 'try!\|\.unwrap()' --include="*.swift" Epistemos/ | grep -v Test | grep -v mock | wc -l  # should be 0
```

**Step 4: Anti-drift verification**
- [ ] No sidecar processes for inference: `grep -rn 'Process()\|NSTask\|posix_spawn' --include="*.swift" | grep -v test | wc -l` → 0
- [ ] No fake SDKs: `grep -rn 'import Anthropic\b\|import OpenAI\b' --include="*.swift" | wc -l` → 0
- [ ] API keys in Keychain only: `grep -rn 'UserDefaults.*[Aa]pi[Kk]ey' --include="*.swift" | wc -l` → 0
- [ ] @Observable not ObservableObject: `grep -rn 'ObservableObject' --include="*.swift" Epistemos/ | grep -v test | wc -l` → 0
- [ ] PowerGuard integration intact: `grep -rn 'PowerGuard.shared' --include="*.swift" | wc -l` → should be 10+

**Step 5: Continuation safety verification**
```bash
# All CheckedContinuations have cancellation handlers or timeouts
grep -rn 'withCheckedContinuation\|withCheckedThrowingContinuation' --include="*.swift" Epistemos/ | wc -l
# Compare against withTaskCancellationHandler count — should be similar
grep -rn 'withTaskCancellationHandler' --include="*.swift" Epistemos/ | wc -l
```

**Step 6: Performance spot-check**
- [ ] MetalGraphView frame skip counter present for 60fps cap
- [ ] KnowledgeCoreBridge polling uses PowerGuard.ringPollInterval
- [ ] No new `DispatchQueue.main.sync` calls (deadlock risk)
- [ ] No new blocking FFI calls on @MainActor

**Step 7: Architectural coherence**
Re-read these 3 documents and verify no drift from canonical patterns:
1. `docs/CONTROL_PLANE_RESEARCH.md` — is the app becoming a control plane or drifting back to "chat wrapper"?
2. `~/Downloads/release/FINAL DOCS/1. CORRUPTION/ZERO_CORRUPTION_SPEC.md` — are new file writes using the atomic protocol?
3. `~/Downloads/release/FINAL DOCS/3. MUST READS/ANTI_DRIFT_SYSTEM.md` — are the 5 defense layers intact?

**Step 8: Write audit report**
After each phase audit, append to `docs/AUDIT_LOG.md`:
```markdown
## Phase {X} Audit — {date}
- Build: PASS/FAIL
- Hardening grep: {N}/{total} passed
- Zero-corruption: {checklist results}
- Anti-drift: {checklist results}
- Continuations: {safe/unsafe count}
- Performance: {spot-check results}
- Coherence: {drift detected? what?}
- Issues found: {list}
- Issues fixed: {list}
- VERDICT: PASS — proceed to Phase {X+1} / FAIL — fix before proceeding
```

**DO NOT START THE NEXT PHASE UNTIL THE AUDIT PASSES.** If any check fails, fix it before moving on. This is how we maintain the "zero-corruption, zero-drift, zero-regression" guarantee.

---

## ANTI-DRIFT SYSTEM (MANDATORY — Re-read if context compacts)

These rules exist because coding agents systematically drift toward simplified implementations. Violating ANY of these is a bug.

### Engineering Philosophy (Non-Negotiable)
1. **Zero-copy by default.** Every FFI boundary, every IPC path, every buffer: audit for unnecessary copies. Apple Silicon UMA means zero-copy is achievable everywhere — `MTLResourceOptions.storageModeShared`, mmap, shared memory rings.
2. **Typestate over runtime checks.** When a state transition is critical (model lifecycle, PTY handle, vault connection), enforce it at the type level. Use `~Copyable` in Swift 6, `PhantomData` in Rust.
3. **Atomic writes or no writes.** File writes use: temp file → `F_FULLFSYNC` → rename → `F_FULLFSYNC` parent dir. Never `try?` on user data writes.
4. **Lock-free on hot paths.** Circuit breakers use `UInt64.nonzeroBitCount` (single CPU cycle). Ring buffers use atomic cursors. Graph physics yields, never blocks.
5. **Bit-level where it matters.** `popcount` over array scans. `#[repr(align(128))]` for Apple Silicon L1 cache lines. ManagedBuffer for co-located header + elements.
6. **Honest capability gating.** If a local model can't do tool calling reliably, don't fake it. If ANE can't run Mamba-2 selective scan, say so.
7. **Privacy first, cloud opt-in.** All inference local by default. API keys in Keychain, never UserDefaults. No telemetry without consent.

### Builder Reference Patterns (from EPISTEMOS_BUILDER_REFERENCE.md)
These are the canonical code patterns. Use them VERBATIM — do not reinvent:
- **REF-01:** Bookmark three-layer defense (validate → resolve → recover)
- **REF-02:** Hardened file write (temp → F_FULLFSYNC → rename → F_FULLFSYNC parent)
- **REF-03:** Paste sanitization (strip U+FFFC, limit size, plain text fallback)
- **REF-04:** IME guard (keyCode 229, hasMarkedText, firstRect override)
- **REF-05:** AI streaming mutation guard (page ID by value, not reference)
- **REF-06:** Undo grouping (beginUndoGrouping/endUndoGrouping on every programmatic mutation)
- **REF-07:** Viewport highlight guard (defer invalidation to next run loop)
- **REF-08:** FFI catch_unwind (on EVERY `#[uniffi::export]` function)
- **REF-09:** NaN sanitization + Barnes-Hut θ=0.8 (never O(n²) with 500+ nodes)
- **REF-10:** Metal render hardening (occlusion gate, drawable nil guard, command buffer error handler)
- **REF-11:** SwiftData migration safety (lightweight migration, integrity check on launch)
- **REF-12:** Adversarial filename normalization (NFC ingestion, NFD+casefold paths)
- **REF-13:** Wikilink parser (spaces, emoji, case-insensitive)
- **REF-14:** MetricKit crash reporting
- **REF-15:** Graph node lifecycle (dangling edge cleanup on delete)
- **REF-16:** Startup integrity check (sample SDPage records, verify bodies)

### Zero-Corruption Layers (from ZERO_CORRUPTION_SPEC.md)
1. `F_FULLFSYNC` on all durable writes (macOS `fsync` does NOT guarantee flush)
2. Atomic write protocol (temp → fsync → rename → fsync parent)
3. BLAKE3 integrity checksums (xattr + DB dual storage)
4. WAL hardening (synchronous=FULL, integrity_check on launch)
5. Merkle tree self-healing (future)
6. Unicode normalization barrier (NFC on ingestion, NFD+casefold for paths)
7. Recovery snapshots (version capture before destructive ops)

### Research Grounding (read these for deeper context on ANY decision)
| Topic | Document | Location |
|-------|----------|----------|
| Quantization pipeline | `~/stateful-rotor-implementation-reference.md` | ButterflyQuant, TurboQuant, Kitty, PM-KVQ |
| 50+ paper synthesis | `~/EPISTEMOS-RESEARCH-REFERENCE.md` | Rotation matrices, KV cache, search, Apple Silicon |
| Zero-copy masterclass | `~/Downloads/unsorted research/Epistemos Zero-Copy Zero-Latency Implementation Masterclass.md` | UMA, mmap, shared memory, FlatBuffers |
| Self-healing architecture | `~/Downloads/Architecting a Resilient Self-Healing macOS PKM.md` | Circuit breakers, supervision, thermal |
| Recursive hardening | `~/Downloads/release/EPISTEMOS_CODEX_RECURSIVE_MASTER_v4.md` | 25-doc scan, gap analysis, triage card |
| Hardening impl guide | `~/Downloads/release/FINAL DOCS/2. final hardening/reference research/EPISTEMOS_HARDENING_IMPL_GUIDE.md` | Bookmark defense, TextKit2, adversarial filenames |
| Zero-corruption spec | `~/Downloads/release/FINAL DOCS/1. CORRUPTION/ZERO_CORRUPTION_SPEC.md` | F_FULLFSYNC, BLAKE3, Merkle, WAL, Unicode |
| Living Vault | `~/Downloads/last feature after new agents/LIVING_VAULT_ARCHITECTURE.md` | Vault decay, GC, classifier, git-as-journal |
| Operator manual | `~/Downloads/last feature after new agents/OPERATOR_MANUAL.md` | 3-prompt workflow, deployment, monitoring |
| Anti-drift system | `~/Downloads/release/FINAL DOCS/3. MUST READS/ANTI_DRIFT_SYSTEM.md` | 5-layer defense against context drift |
| Deep diagnostics | `~/Epistemos Deep Diagnostics Custom Logging and Real-Time Self-Healing Architecture.md` | Structured logging, self-healing, runtime diagnostics |
| Keystroke telemetry | `~/Epistemos Keystroke Telemetry Input-Driven Hardening Runtime Perfection.md` | Input pipeline hardening, IME, paste |
| Next-gen research mode | `~/Downloads/unsorted research/Epistemos Next-Generation Research Mode Migration Blueprint.md` | Research pipeline, multi-source synthesis |

### Triage Card (Symptom → Root Cause → Fix)
| User reports... | Root cause | Fix |
|---|---|---|
| Notes "disappeared" after OS update | Bookmark revoked | VaultBookmarkValidator (REF-01) |
| Freeze after sleep/wake | Bookmark resolution on main thread | resolveBookmarkWithTimeout |
| AI text in wrong note | Callback uses ref not captured ID | Mutation guard (REF-05) |
| Japanese typing broken | keyCode 229 / firstRect wrong | IME guard (REF-04) |
| Graph crash on empty vault | Nil engine handle | withEngine guard |
| GPU timeout / fan spinning | Occlusion gate broken / NaN | Metal hardening (REF-09/10) |
| EXC_BAD_INSTRUCTION in Rust | Panic crossed FFI | catch_unwind (REF-08) |
| Silent save failure on full disk | try? swallowing ENOSPC | try? audit (REF-02) |
| Save succeeded but data gone | fsync doesn't flush on macOS | F_FULLFSYNC |

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
