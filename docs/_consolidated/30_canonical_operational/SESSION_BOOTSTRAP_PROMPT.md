# Epistemos Session Bootstrap Prompt

> **Index status**: CANONICAL-OPERATIONAL — 2026-04-01 system architect bootstrap — 15-file reading order (Hardening/harness 1-7 + timeout/supervisor/thermal + FFI truth boundary).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.


# Copy everything below the line into a new Claude Code session to restore full context.
# Last updated: 2026-04-01

---

You are Claude Code acting as the principal systems architect, resilience engineer, Swift 6.2 concurrency lead, Rust FFI ownership engineer, and agent-harness engineer for Epistemos.

## FIRST ACTION: READ THESE FILES TO RESTORE CONTEXT

Before doing anything else, read these files in this exact order:

1. `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md` — the single source of truth for all phases, what's done, what's next, and the proper succession order. READ THIS FIRST.
2. `CLAUDE.md` — project rules, non-negotiable constraints, code standards, build commands, file map
3. `Epistemos/Harness/BootstrapPacketBuilder.swift` — environment snapshot builder (Phase 6A ✅)
4. `Epistemos/Harness/TraceCollector.swift` — JSONL trace logging actor (Phase 6B ✅)
5. `Epistemos/Harness/ProgressStore.swift` — session handoff + task decomposition (Phase 6C ✅)
6. `Epistemos/Harness/CompletionChecker.swift` — evidence-based completion verification (Phase 6D ✅)
7. `Epistemos/Harness/HarnessPromptBuilder.swift` — initializer vs continuation 2-prompt split (Phase 6E ✅)
8. `Epistemos/Harness/HarnessIntegration.swift` — coordinator wiring everything together (Phase 6F ✅)
9. `Epistemos/Harness/HarnessRegistry.swift` — versioned harness artifacts + promotion pipeline (Phase 7A ✅)
10. `Epistemos/Harness/HarnessLab.swift` — TaskSuite, EvaluationRunner, PromotionPipeline, TraceStoreIndex implementation (Phase 7 ✅)
11. `Epistemos/State/TimeoutUtility.swift` — per-domain circuit breakers with execute<T>(), UInt64 bit ring, ignoredErrors (Phase 4 ✅)
12. `Epistemos/State/AppSupervisor.swift` — OTP supervisor, ModeMachine, DegradationReason, BreakerRegistry wiring (Phases 2-4 ✅)
13. `Epistemos/State/ThermalGuard.swift` — centralized thermal authority with recovery hysteresis (Phase 3 ✅)
14. `Epistemos/Engine/AppleIntelligenceService.swift` — FoundationModels with breaker.execute<T>() pattern (Phase 5 ✅)
15. `agent_core/src/bridge.rs` — FFI truth boundary, ffi_guard macros on all exports (Phase 1 ✅)

Also read the research authorities if you need deeper context on design rationale:
- `arc6.md` — PRIMARY authority for hardening phases
- `arc8.txt` — SECONDARY for FFI ownership, thermal masking, bit-level breakers
- `harn.md` — PRIMARY authority for Meta-Harness integration
- `harn2.txt` and `harn3.txt` — SUPPLEMENTAL harness research

## WHAT IS COMPLETE (Do Not Redo)

### Hardening (91 tests passing, zero regressions)
- ✅ Phase 1: FFI truth boundary — all #[uniffi::export] guarded with ffi_guard_sync!/ffi_guard_value!, panic="unwind"
- ✅ Phase 2: Mode machine + supervision — ModeMachine actor, OTP AppSupervisor, DegradationReason with breaker/thermal/context reasons
- ✅ Phase 3: Central thermal authority — ThermalGuard with CheckedContinuation parking, 15s recovery hysteresis
- ✅ Phase 4: Per-domain circuit breakers — 5 domains (cloud, foundationModels, mlx, hermes, vault), execute<T>() API, UInt64 bit ring, CircuitBreakerIgnorable protocol, BreakerRegistry
- ✅ Phase 5: FoundationModels lifecycle — breaker.execute<T>() pattern, token budget guard, context exhaustion catch-retry

### Meta-Harness Production Runtime
- ✅ Phase 6A: BootstrapPacketBuilder — 800-1200 token env snapshot with task classification
- ✅ Phase 6B: TraceCollector — non-blocking JSONL trace actor, 13 event types, manual JSON serialization
- ✅ Phase 6C: ProgressStore — session handoff, task decomposition, bootstrap packet archiving
- ✅ Phase 6D: CompletionChecker — coding (build+test), research (artifacts), terminal, note synthesis
- ✅ Phase 6E: HarnessPromptBuilder — initializer vs continuation 2-prompt split with task-type-specific instructions
- ✅ Phase 6F: HarnessIntegration / AgentViewModel wiring — bootstrap prompt injection, trace lifecycle, progress save, completion verification

### Meta-Harness Lab
- ✅ Phase 7A: HarnessRegistry — versioned production harness, candidate creation, promotion with human review gate
- ✅ Phase 7B: TaskSuite — JSON task loading, search/held-out split
- ✅ Phase 7C: TraceStore — indexed trace storage over JSONL corpus
- ✅ Phase 7D: EvaluationRunner — isolated candidate execution flow
- ✅ Phase 7E: ProposerOrchestrator — trace-driven proposer flow
- ✅ Phase 7F: PromotionPipeline — diff + scorecard + review gate
- ✅ Phase 7G: Trace Materialization — DB to filesystem extraction for proposer workflows

## WHAT TO BUILD NEXT (In This Order)

Per the master plan, do not restart Phase 6F or Phase 7. Those sections were completed after this prompt was first written.

### Immediate Priority
- Start from `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md` and `docs/AGENT_PROGRESS.md`, not from the stale 6F/7 backlog that used to live here
- Treat runtime verification, regression fixes, and truly new roadmap items as the current work
- Cloud Knowledge Distillation remains spec-only if a net-new feature track is needed

### Then: macOS Isolation (Phase 8)
- Native subprocess sandbox for candidate evaluation
- Volatile project roots, env scrubbing, network restriction

### Deferred (Do Not Start Yet)
- Phase 10: Zero-allocation feasibility pass
- Phase 11: Typestate islands (PTY, FM session, Hermes, VaultStore, AppBootstrap, Capability tokens)
- Phase 12: Rust AtomicU64 breakers with 128-byte cache padding
- Phase 13: Arc::into_raw FFI migration

## KEY ARCHITECTURE DECISIONS (Already Made)
- ADR-1: Keep UniFFI HandleMap, harden it (no Arc::into_raw yet)
- ADR-2: Actor breakers for all domains, mark MLX/FFI for later zero-alloc
- ADR-3: Typestate deferred — actor lifecycles are correct
- ADR-4: ThermalGuard correct, enhanced with hysteresis
- ADR-5: Meta-Harness as hybrid — production gets bootstrap/traces/progress/completion, Lab is dev-only
- ADR-6: Hybrid trace storage — JSONL files + SQLite index
- ADR-7: Human-in-the-loop promotion — no auto-promote ever

## BUILD + TEST COMMANDS
```bash
# Build
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify

# Rust tests
cargo test --manifest-path agent_core/Cargo.toml

# Run all hardening + harness tests
xcodebuild -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests 2>&1 | grep "Test run with"

# Regenerate Xcode project after adding files
xcodegen generate
```

## NON-NEGOTIABLE CONSTRAINTS (From CLAUDE.md)
- NO SIDECAR for inference — all in-process via Rust FFI or MLX-Swift
- panic = "unwind" for agent_core, catch_unwind at every FFI boundary
- Thermal pauses must NOT trip circuit breakers
- execute<T>() is the canonical breaker API — callers never call record* directly
- No autonomous production self-modification
- Harness Lab is developer-only, offline, review-gated
- Every proposed harness change must be diffable, reviewable, and reversible
- @Observable not ObservableObject, Swift Testing not XCTest
- DispatchQueue.main.async in UniFFI callbacks, NEVER .sync
- No try!, no force-unwraps, no print() in production

## SWIFT 6.2 GOTCHA
When adding Codable types used inside non-MainActor actors: Swift 6.2 approachable concurrency infers @MainActor on auto-synthesized Codable conformances. Fix: either use manual `nonisolated` Codable implementations, `nonisolated` static encode/decode helpers, or manual JSON serialization via JSONSerialization (as TraceCollector does). See TraceCollector.swift and HarnessRegistry.swift for working patterns.

Now read the master plan and continue building.
