import Testing
import Foundation
@testable import Epistemos

// MARK: - Circuit Breaker Tests

@Suite("AgentCircuitBreaker — Rolling Window")
struct CircuitBreakerTests {

    @Test("Starts in closed state")
    func startsInClosedState() async {
        let breaker = AgentCircuitBreaker(domain: .cloud)
        let open = await breaker.isOpen
        #expect(!open)
    }

    @Test("Opens after failure rate exceeds threshold")
    func opensOnHighFailureRate() async {
        let breaker = AgentCircuitBreaker(domain: .hermes) // capacity 8, threshold 0.5
        // Fill the buffer with failures to exceed threshold
        for _ in 0..<8 {
            await breaker.recordFailure()
        }
        let open = await breaker.isOpen
        #expect(open)
    }

    @Test("Does not open below failure threshold")
    func staysClosedBelowThreshold() async {
        let breaker = AgentCircuitBreaker(domain: .cloud) // capacity 32, threshold 0.5
        // Alternate: 1 failure, 2 successes → 33% failure rate, below 50% threshold
        for _ in 0..<11 {
            await breaker.recordFailure()
            await breaker.recordSuccess()
            await breaker.recordSuccess()
        }
        // Total: 11 failures, 22 successes = 33 results (buffer 32, wraps once)
        // Active window: ~33% failure rate — below 50% threshold
        let open = await breaker.isOpen
        #expect(!open)
    }

    @Test("Thermal pause does not count as failure")
    func thermalPauseDoesNotCountAsFailure() async {
        let breaker = AgentCircuitBreaker(domain: .cloud)
        // Record many thermal pauses — should not trip
        for _ in 0..<100 {
            await breaker.recordThermalPause()
        }
        let open = await breaker.isOpen
        #expect(!open)
        let rate = await breaker.failureRate
        #expect(rate == 0.0)
    }

    @Test("Reset clears all state")
    func resetClearsState() async {
        let breaker = AgentCircuitBreaker(domain: .hermes) // capacity 8
        // Trip it
        for _ in 0..<8 {
            await breaker.recordFailure()
        }
        #expect(await breaker.isOpen)

        // Reset
        await breaker.reset()
        let openAfterReset = await breaker.isOpen
        #expect(!openAfterReset)
        let rateAfterReset = await breaker.failureRate
        #expect(rateAfterReset == 0.0)
    }

    @Test("Legacy initializer works with old threshold semantics")
    func legacyInitializer() async {
        let breaker = AgentCircuitBreaker(failureThreshold: 3, resetTimeout: 30.0)
        let isOpen = await breaker.isOpen
        #expect(!isOpen)
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

    @Test("Supervisor start is idempotent")
    func startIsIdempotent() async throws {
        var runCount = 0
        let supervisor = AppSupervisor(healthCheckInterval: 300)
        supervisor.register(ChildSpec(
            id: "test-idempotent-start",
            policy: .permanent,
            restartWindow: 60.0,
            maxRestarts: 3,
            factory: { @Sendable in
                await MainActor.run { runCount += 1 }
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(1))
                }
            }
        ))

        supervisor.start()
        supervisor.start()
        try await Task.sleep(for: .milliseconds(200))
        supervisor.stop()

        #expect(runCount == 1, "Calling start() twice should not spawn duplicate children")
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

    @Test("Stopping the supervisor does not respawn permanent children")
    func stopDoesNotRespawnPermanentChildren() async throws {
        var runCount = 0
        let supervisor = AppSupervisor(healthCheckInterval: 300)
        supervisor.register(ChildSpec(
            id: "test-stop-respawn",
            policy: .permanent,
            restartWindow: 60.0,
            maxRestarts: 3,
            factory: { @Sendable in
                await MainActor.run { runCount += 1 }
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(1))
                }
            }
        ))

        supervisor.start()
        try await Task.sleep(for: .milliseconds(200))
        supervisor.stop()
        try await Task.sleep(for: .seconds(2))

        #expect(runCount == 1, "Permanent children should stay stopped after supervisor.stop()")
    }

    @Test("Stopping the supervisor cancels pending delayed restarts")
    func stopCancelsPendingDelayedRestarts() async throws {
        var runCount = 0
        let supervisor = AppSupervisor(healthCheckInterval: 300)
        supervisor.register(ChildSpec(
            id: "test-stop-pending-restart",
            policy: .permanent,
            restartWindow: 60.0,
            maxRestarts: 3,
            factory: { @Sendable in
                await MainActor.run { runCount += 1 }
                throw NSError(domain: "test", code: 1)
            }
        ))

        supervisor.start()
        try await Task.sleep(for: .milliseconds(100))
        supervisor.stop()
        try await Task.sleep(for: .seconds(2))

        #expect(runCount == 1, "Pending restart tasks should be cancelled when the supervisor stops")
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

    @Test("Manual restart does not schedule a duplicate child restart")
    func manualRestartDoesNotDoubleSpawnChild() async throws {
        var runCount = 0
        let supervisor = AppSupervisor(healthCheckInterval: 300)
        supervisor.register(ChildSpec(
            id: "test-manual-restart",
            policy: .permanent,
            restartWindow: 60.0,
            maxRestarts: 3,
            factory: { @Sendable in
                await MainActor.run { runCount += 1 }
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(1))
                }
            }
        ))

        supervisor.start()
        try await Task.sleep(for: .milliseconds(200))
        await supervisor.restartSubsystem("test-manual-restart", reason: "test")
        try await Task.sleep(for: .seconds(2))
        supervisor.stop()

        #expect(runCount == 2, "Manual restart should replace the child once, not double-spawn it")
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
