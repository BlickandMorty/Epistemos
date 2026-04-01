import Testing
import Foundation
@testable import Epistemos

// MARK: - Circuit Breaker Tests

@Suite("AgentCircuitBreaker — Rolling Window")
struct CircuitBreakerTests {

    @Test("Starts in closed state")
    func startsInClosedState() async {
        let breaker = AgentCircuitBreaker(
            domain: "test",
            bufferSize: 10,
            failureRateThreshold: 0.5,
            resetTimeout: 5.0,
            requiredHalfOpenSuccesses: 3
        )
        let open = await breaker.isOpen
        #expect(!open)
    }

    @Test("Opens after failure rate exceeds threshold")
    func opensOnHighFailureRate() async {
        let breaker = AgentCircuitBreaker(
            domain: "test",
            bufferSize: 6,
            failureRateThreshold: 0.5,
            resetTimeout: 60.0,
            requiredHalfOpenSuccesses: 2
        )
        // Fill half the buffer (minimum before checking rate)
        await breaker.recordFailure()
        await breaker.recordFailure()
        await breaker.recordFailure()
        // 3 failures in 3 calls = 100% failure rate, threshold is 50%
        let open = await breaker.isOpen
        #expect(open)
    }

    @Test("Does not open below failure threshold")
    func staysClosedBelowThreshold() async {
        let breaker = AgentCircuitBreaker(
            domain: "test",
            bufferSize: 10,
            failureRateThreshold: 0.5,
            resetTimeout: 60.0,
            requiredHalfOpenSuccesses: 2
        )
        // 2 failures, 3 successes = 40% failure rate, threshold is 50%
        await breaker.recordFailure()
        await breaker.recordFailure()
        await breaker.recordSuccess()
        await breaker.recordSuccess()
        await breaker.recordSuccess()
        let open = await breaker.isOpen
        #expect(!open)
    }

    @Test("Half-open requires multiple consecutive successes")
    func halfOpenRequiresMultipleSuccesses() async {
        let breaker = AgentCircuitBreaker(
            domain: "test",
            bufferSize: 4,
            failureRateThreshold: 0.5,
            resetTimeout: 0.1, // Very short for test
            requiredHalfOpenSuccesses: 3
        )
        // Trip the breaker
        await breaker.recordFailure()
        await breaker.recordFailure()
        #expect(await breaker.isOpen)

        // Wait for reset timeout
        try? await Task.sleep(for: .milliseconds(150))

        // Should be half-open now
        #expect(!await breaker.isOpen)

        // One success is not enough
        await breaker.recordSuccess()
        let state1 = await breaker.currentState
        if case .closed = state1 {
            Issue.record("Should not be closed after 1 success, needs 3")
        }

        // Two successes still not enough
        await breaker.recordSuccess()

        // Third success should close it
        await breaker.recordSuccess()
        let state2 = await breaker.currentState
        if case .closed = state2 {
            // Expected
        } else {
            Issue.record("Should be closed after 3 consecutive successes")
        }
    }

    @Test("Half-open failure returns to open")
    func halfOpenFailureReturnsToOpen() async {
        let breaker = AgentCircuitBreaker(
            domain: "test",
            bufferSize: 4,
            failureRateThreshold: 0.5,
            resetTimeout: 0.1,
            requiredHalfOpenSuccesses: 3
        )
        // Trip the breaker
        await breaker.recordFailure()
        await breaker.recordFailure()
        #expect(await breaker.isOpen)

        // Wait for reset
        try? await Task.sleep(for: .milliseconds(150))
        #expect(!await breaker.isOpen) // half-open

        // Failure in half-open → back to open
        await breaker.recordFailure()
        #expect(await breaker.isOpen)
    }

    @Test("Thermal pause does not count as failure")
    func thermalPauseDoesNotCountAsFailure() async {
        let breaker = AgentCircuitBreaker(
            domain: "test",
            bufferSize: 6,
            failureRateThreshold: 0.5,
            resetTimeout: 60.0,
            requiredHalfOpenSuccesses: 2
        )
        // Record many thermal pauses — should not trip
        for _ in 0..<20 {
            await breaker.recordThermalPause()
        }
        let open = await breaker.isOpen
        #expect(!open)
        let rate = await breaker.failureRate
        #expect(rate == 0.0)
    }

    @Test("Reset clears all state")
    func resetClearsState() async {
        let breaker = AgentCircuitBreaker(
            domain: "test",
            bufferSize: 4,
            failureRateThreshold: 0.5,
            resetTimeout: 60.0,
            requiredHalfOpenSuccesses: 2
        )
        // Trip it
        await breaker.recordFailure()
        await breaker.recordFailure()
        #expect(await breaker.isOpen)

        // Reset
        await breaker.reset()
        #expect(!await breaker.isOpen)
        #expect(await breaker.failureRate == 0.0)
    }

    @Test("Legacy initializer works with old threshold semantics")
    func legacyInitializer() async {
        let breaker = AgentCircuitBreaker(failureThreshold: 3, resetTimeout: 30.0)
        // Should not be open initially
        #expect(!await breaker.isOpen)
    }
}

// MARK: - Mode Machine Tests

@Suite("ModeMachine — Typed Degradation")
@MainActor
struct ModeMachineTests {

    @Test("Starts in full mode")
    func startsInFullMode() {
        let machine = ModeMachine(recoveryHysteresis: 0.0)
        #expect(machine.currentMode == .full)
        #expect(machine.currentReason == nil)
    }

    @Test("Degradation transitions apply immediately")
    func degradationIsImmediate() {
        let machine = ModeMachine(recoveryHysteresis: 0.0)
        let applied = machine.transition(to: .degradedAI, reason: .inferenceUnavailable)
        #expect(applied)
        #expect(machine.currentMode == .degradedAI)
        if case .inferenceUnavailable = machine.currentReason {
            // Expected
        } else {
            Issue.record("Reason should be .inferenceUnavailable")
        }
    }

    @Test("Can skip levels when degrading")
    func canSkipLevelsDegrading() {
        let machine = ModeMachine(recoveryHysteresis: 0.0)
        let applied = machine.transition(to: .readOnly, reason: .knowledgeStoreCorrupted)
        #expect(applied)
        #expect(machine.currentMode == .readOnly)
    }

    @Test("Recovery requires step-by-step")
    func recoveryIsStepByStep() {
        let machine = ModeMachine(recoveryHysteresis: 0.0)
        // Degrade to readOnly
        machine.transition(to: .readOnly, reason: .knowledgeStoreCorrupted)
        // Try to jump straight to full — should be rejected
        let applied = machine.transition(to: .full, reason: nil)
        #expect(!applied)
        #expect(machine.currentMode == .readOnly)
    }

    @Test("Recovery hysteresis blocks premature recovery")
    func hysteresisBlocksRecovery() {
        let machine = ModeMachine(recoveryHysteresis: 10.0) // 10 second hysteresis
        machine.transition(to: .degradedAI, reason: .inferenceUnavailable)
        // Immediately try to recover — should be blocked by hysteresis
        let applied = machine.transition(to: .full, reason: nil)
        #expect(!applied)
        #expect(machine.currentMode == .degradedAI)
    }

    @Test("forceDegrade bypasses hysteresis")
    func forceDegradeBypassesRules() {
        let machine = ModeMachine(recoveryHysteresis: 0.0)
        machine.forceDegrade(
            to: .localOnly,
            reason: .crashLoopEscalation(childId: "hermes")
        )
        #expect(machine.currentMode == .localOnly)
    }

    @Test("forceDegrade rejected if target is less severe")
    func forceDegradeRejectedIfBetter() {
        let machine = ModeMachine(recoveryHysteresis: 0.0)
        machine.transition(to: .readOnly, reason: .knowledgeStoreCorrupted)
        // forceDegrade to a better mode should be rejected
        machine.forceDegrade(to: .degradedAI, reason: .inferenceUnavailable)
        #expect(machine.currentMode == .readOnly) // unchanged
    }

    @Test("No-op transition returns false")
    func noopTransition() {
        let machine = ModeMachine(recoveryHysteresis: 0.0)
        let applied = machine.transition(to: .full, reason: nil)
        #expect(!applied) // Already in .full
    }
}

// MARK: - Supervisor Tests

@Suite("AppSupervisor — OTP Semantics")
@MainActor
struct SupervisorTests {

    @Test("Supervisor starts and stops cleanly")
    func startsAndStops() {
        let supervisor = AppSupervisor(healthCheckInterval: 300) // Long interval for test
        supervisor.start()
        supervisor.stop()
        // No crash = success
    }

    @Test("Permanent child is restarted after failure")
    func permanentChildRestarted() async throws {
        var runCount = 0
        let supervisor = AppSupervisor(healthCheckInterval: 300)
        supervisor.register(ChildSpec(
            id: "test-permanent",
            policy: .permanent,
            restartWindow: 60.0,
            maxRestarts: 3,
            factory: { @Sendable in
                await MainActor.run { runCount += 1 }
                if await MainActor.run(body: { runCount }) <= 2 {
                    throw NSError(domain: "test", code: 1)
                }
                // Third run succeeds and stays alive
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(1))
                }
            }
        ))
        supervisor.start()
        // Wait for restarts
        try await Task.sleep(for: .seconds(5))
        supervisor.stop()
        #expect(runCount >= 2, "Permanent child should have been restarted at least once")
    }

    @Test("Temporary child is never restarted")
    func temporaryChildNotRestarted() async throws {
        var runCount = 0
        let supervisor = AppSupervisor(healthCheckInterval: 300)
        supervisor.register(ChildSpec(
            id: "test-temporary",
            policy: .temporary,
            restartWindow: 60.0,
            maxRestarts: 3,
            factory: { @Sendable in
                await MainActor.run { runCount += 1 }
                throw NSError(domain: "test", code: 1)
            }
        ))
        supervisor.start()
        try await Task.sleep(for: .seconds(2))
        supervisor.stop()
        #expect(runCount == 1, "Temporary child should run exactly once")
    }

    @Test("Transient child not restarted on clean exit")
    func transientChildCleanExit() async throws {
        var runCount = 0
        let supervisor = AppSupervisor(healthCheckInterval: 300)
        supervisor.register(ChildSpec(
            id: "test-transient",
            policy: .transient,
            restartWindow: 60.0,
            maxRestarts: 3,
            factory: { @Sendable in
                await MainActor.run { runCount += 1 }
                // Clean exit (no throw)
            }
        ))
        supervisor.start()
        try await Task.sleep(for: .seconds(2))
        supervisor.stop()
        #expect(runCount == 1, "Transient child should not restart on clean exit")
    }

    @Test("Crash loop triggers escalation and degrades mode")
    func crashLoopEscalation() async throws {
        let supervisor = AppSupervisor(healthCheckInterval: 300)
        supervisor.register(ChildSpec(
            id: "crasher",
            policy: .permanent,
            restartWindow: 10.0,
            maxRestarts: 2, // Low threshold for quick escalation
            factory: { @Sendable in
                throw NSError(domain: "test", code: 1)
            }
        ))
        supervisor.start()
        // Wait for crash loop to exhaust restarts and escalate
        try await Task.sleep(for: .seconds(8))
        supervisor.stop()
        // After escalation, the subsystem should be marked down
        let status = supervisor.subsystemStatus["crasher"]
        #expect(status == false, "Crashed child should be marked as down")
    }
}

// MARK: - Rust FFI Tests

@Suite("FFI Truth Boundary")
struct FFITruthBoundaryTests {

    @Test("agent_core compiled with panic=unwind")
    func panicUnwindInCargoToml() throws {
        let cargoTomlPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("agent_core/Cargo.toml")
        let content = try String(contentsOf: cargoTomlPath, encoding: .utf8)
        #expect(content.contains("panic = \"unwind\""),
                "agent_core MUST use panic = \"unwind\" for catch_unwind to work in release builds")
        #expect(!content.contains("panic = \"abort\""),
                "agent_core MUST NOT use panic = \"abort\" — it makes catch_unwind a no-op")
    }

    @Test("bridge.rs contains ffi_guard macros")
    func bridgeHasFfiGuardMacros() throws {
        let bridgePath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("agent_core/src/bridge.rs")
        let content = try String(contentsOf: bridgePath, encoding: .utf8)
        #expect(content.contains("ffi_guard_sync!"),
                "bridge.rs must use ffi_guard_sync! macro for sync FFI exports")
        #expect(content.contains("panic_payload_to_string"),
                "bridge.rs must have panic payload extraction")
        #expect(content.contains("std::mem::forget(payload)"),
                "bridge.rs must forget panic payload to prevent re-panic from Drop")
    }
}
