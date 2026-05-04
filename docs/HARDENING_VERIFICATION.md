# Production Hardening Verification Checklist

> **Index status**: CANONICAL-OPERATIONAL — Hardening verification protocol; pre-Phase-S ops.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



Verification steps for the 9-phase resilience hardening pass.
Each item maps to a specific audit finding from arc1-arc4.

## Phase 1: FFI Truth Boundary

- [ ] **Panic strategy is unwind**: `grep 'panic = "unwind"' agent_core/Cargo.toml` returns a match
- [ ] **No panic=abort in agent_core**: `grep 'panic = "abort"' agent_core/Cargo.toml` returns NO match
- [ ] **ffi_guard macros exist**: `grep 'ffi_guard_sync!' agent_core/src/bridge.rs` returns matches
- [ ] **Panic payload extraction uses mem::forget**: `grep 'std::mem::forget(payload)' agent_core/src/bridge.rs`
- [ ] **Async FFI uses JoinHandle**: `grep 'tokio::task::spawn' agent_core/src/bridge.rs` returns matches for run_agent_session, pty_spawn, pty_execute
- [ ] **Release cargo check passes**: `cargo check --manifest-path agent_core/Cargo.toml --release`
- [ ] **Dev cargo check passes**: `cargo check --manifest-path agent_core/Cargo.toml`

## Phase 2: Real Supervision

- [ ] **No 30-second polling pretending to be supervision**: `grep -c 'polling' Epistemos/State/AppSupervisor.swift` should be 0
- [ ] **ChildSpec struct exists**: `grep 'struct ChildSpec' Epistemos/State/AppSupervisor.swift`
- [ ] **RestartPolicy enum exists**: `grep 'enum RestartPolicy' Epistemos/State/AppSupervisor.swift`
- [ ] **Sliding window restart intensity**: `grep 'restartWindow' Epistemos/State/AppSupervisor.swift`
- [ ] **Exponential backoff with jitter**: `grep 'jitter' Epistemos/State/AppSupervisor.swift`
- [ ] **rest_for_one escalation**: `grep 'rest_for_one' Epistemos/State/AppSupervisor.swift`
- [ ] **Children are Tasks, not procedural checks**: `grep 'spawnChild' Epistemos/State/AppSupervisor.swift`

## Phase 3: Mode Machine

- [ ] **DegradationReason enum exists**: `grep 'enum DegradationReason' Epistemos/State/AppSupervisor.swift`
- [ ] **ModeMachine class exists**: `grep 'class ModeMachine' Epistemos/State/AppSupervisor.swift`
- [ ] **AsyncStream for reactive UI**: `grep 'AsyncStream<ModeTransition>' Epistemos/State/AppSupervisor.swift`
- [ ] **Recovery hysteresis**: `grep 'recoveryHysteresis' Epistemos/State/AppSupervisor.swift`
- [ ] **forceDegrade escape hatch**: `grep 'func forceDegrade' Epistemos/State/AppSupervisor.swift`
- [ ] **Step-by-step recovery enforcement**: `grep 'step-by-step' Epistemos/State/AppSupervisor.swift`
- [ ] **Severity ranking**: `grep 'func severity' Epistemos/State/AppSupervisor.swift`

## Phase 4: Circuit Breaker

- [ ] **Ring bit buffer**: `grep 'ringBuffer' Epistemos/State/TimeoutUtility.swift`
- [ ] **Rolling failure rate**: `grep 'failureRate' Epistemos/State/TimeoutUtility.swift`
- [ ] **Multi-probe half-open**: `grep 'requiredHalfOpenSuccesses' Epistemos/State/TimeoutUtility.swift`
- [ ] **Thermal pause exemption**: `grep 'recordThermalPause' Epistemos/State/TimeoutUtility.swift`
- [ ] **Domain isolation**: `grep 'let domain' Epistemos/State/TimeoutUtility.swift`
- [ ] **CircuitBreakerOpenError with retryAfter**: `grep 'retryAfter' Epistemos/State/TimeoutUtility.swift`

## Phase 5: ThermalGuard

- [ ] **ThermalGuard actor exists**: `grep 'actor ThermalGuard' Epistemos/State/ThermalGuard.swift`
- [ ] **CheckedContinuation parking**: `grep 'CheckedContinuation' Epistemos/State/ThermalGuard.swift`
- [ ] **acquireClearance API**: `grep 'func acquireClearance' Epistemos/State/ThermalGuard.swift`
- [ ] **Resume on cooling**: `grep 'resumeAllParked' Epistemos/State/ThermalGuard.swift`
- [ ] **Cancel on critical**: `grep 'cancelAllParked' Epistemos/State/ThermalGuard.swift`
- [ ] **ThermalError type**: `grep 'struct ThermalError' Epistemos/State/ThermalGuard.swift`
- [ ] **Started in AppBootstrap**: `grep 'ThermalGuard.shared.start' Epistemos/App/AppBootstrap.swift`

## Phase 6: Token Budget

- [ ] **Token count API usage**: `grep 'tokenCount' Epistemos/Engine/AppleIntelligenceService.swift`
- [ ] **contextSize check**: `grep 'contextSize' Epistemos/Engine/AppleIntelligenceService.swift`
- [ ] **78% budget threshold**: `grep '0.78' Epistemos/Engine/AppleIntelligenceService.swift`
- [ ] **Summarization session**: `grep 'summarizeTranscript' Epistemos/Engine/AppleIntelligenceService.swift`
- [ ] **exceededContextWindowSize catch**: `grep 'exceededContextWindowSize' Epistemos/Engine/AppleIntelligenceService.swift`

## Phase 7: Cross-Cutting Interaction

- [ ] **Thermal pauses don't trip breaker**: `grep 'recordThermalPause' Epistemos/Engine/AppleIntelligenceService.swift`
- [ ] **ThermalGuard clearance before inference**: `grep 'acquireClearance' Epistemos/Engine/AppleIntelligenceService.swift`
- [ ] **Supervisor thermal observation**: `grep 'thermalObserverTask' Epistemos/State/AppSupervisor.swift`
- [ ] **Knowledge store checks EventStore**: `grep 'EventStore.shared' Epistemos/State/AppSupervisor.swift`
- [ ] **Mode machine driven by thermal changes**: `grep 'handleThermalStateChange' Epistemos/State/AppSupervisor.swift`

## Phase 8: Tests

- [ ] **Test file exists**: `ls EpistemosTests/ResilienceHardeningTests.swift`
- [ ] **Circuit breaker tests**: `grep 'CircuitBreakerTests' EpistemosTests/ResilienceHardeningTests.swift`
- [ ] **Mode machine tests**: `grep 'ModeMachineTests' EpistemosTests/ResilienceHardeningTests.swift`
- [ ] **Supervisor OTP tests**: `grep 'SupervisorTests' EpistemosTests/ResilienceHardeningTests.swift`
- [ ] **FFI truth boundary tests**: `grep 'FFITruthBoundaryTests' EpistemosTests/ResilienceHardeningTests.swift`
- [ ] **Xcode build succeeds**: `xcodebuild -scheme Epistemos -destination 'platform=macOS' build`

## Remaining Risks / Intentional Deferrals

1. **Per-domain breaker instances not yet wired**: The circuit breaker now supports domain isolation, but only `inferenceCircuitBreaker` is instantiated. Cloud and vault breakers should be added when those subsystems are stress-tested.
2. **Typestate pattern**: The mode machine uses runtime validation, not compile-time typestate. True noncopyable typestate would require refactoring all consumers. Deferred.
3. **Hierarchical supervisor tree**: Current supervisor is flat (one level). A true OTP tree with nested supervisors and one_for_all strategy is deferred until more children are registered.
4. **Process-level watchdog**: If the entire Rust process aborts (double-panic), there is no launchd/SMAppService restart. Deferred to post-ship.
5. **Token budget for streaming tool calls**: The token budget guard only works for single-turn `respond(to:)`. Multi-turn tool-calling sessions need per-turn budget checks. Deferred.
6. **Intentional subprocess surfaces remain policy-scoped**: Hermes setup/runtime, audio transcription, and Python-backed training helpers still use managed subprocesses outside the local inference path. Keep auditing them as explicit exceptions rather than treating them as inference-sidecar drift.
