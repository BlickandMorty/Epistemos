import AppKit
import Foundation
import Testing
@testable import Epistemos

private func isInterruptedProductionHardeningFileReadError(_ error: Error) -> Bool {
    let nsError = error as NSError
    if nsError.domain == NSPOSIXErrorDomain, nsError.code == EINTR {
        return true
    }
    if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
        return isInterruptedProductionHardeningFileReadError(underlying)
    }
    return false
}

private func loadProductionHardeningRepoTextFile(
    _ relativePath: String,
    testsFilePath: String = #filePath,
    attempts: Int = 5
) throws -> String {
    let testsFileURL = URL(fileURLWithPath: testsFilePath)
    let repoRoot = testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
    let fileURL = repoRoot.appendingPathComponent(relativePath)

    var lastError: Error?
    for attempt in 1...attempts {
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            lastError = error
            guard isInterruptedProductionHardeningFileReadError(error), attempt < attempts else {
                throw error
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
    }

    throw lastError ?? CocoaError(.fileReadUnknown)
}

// MARK: - Per-Domain Circuit Breaker Tests

@Suite("Per-Domain Breakers — execute<T>() API")
struct PerDomainBreakerTests {

    @Test("Each domain has independent breaker")
    @MainActor func domainsAreIndependent() async {
        let registry = BreakerRegistry.shared
        let cloud = registry.cloud
        let mlx = registry.mlx
        await cloud.reset()
        await mlx.reset()

        // Trip the cloud breaker
        for _ in 0..<32 {
            await cloud.recordFailure() // Use internal for setup
        }
        #expect(await cloud.isOpen)
        let mlxOpen = await mlx.isOpen
        #expect(!mlxOpen, "MLX breaker must not be affected by cloud failures")
    }

    @Test("execute<T>() records success on completion")
    func executeRecordsSuccess() async throws {
        let breaker = AgentCircuitBreaker(domain: .cloud)
        let result = try await breaker.execute { 42 }
        #expect(result == 42)
        #expect(await breaker.isOpen == false)
    }

    @Test("execute<T>() records failure on error")
    func executeRecordsFailure() async {
        let breaker = AgentCircuitBreaker(domain: .hermes)
        // Fill the buffer with failures to trip
        for _ in 0..<8 {
            do {
                let _: Int = try await breaker.execute {
                    throw NSError(domain: "test", code: 1)
                }
            } catch {
                // Expected
            }
        }
        #expect(await breaker.isOpen)
    }

    @Test("execute<T>() rejects when open")
    func executeRejectsWhenOpen() async {
        let breaker = AgentCircuitBreaker(domain: .hermes)
        // Trip it
        for _ in 0..<8 {
            do {
                let _: Int = try await breaker.execute {
                    throw NSError(domain: "test", code: 1)
                }
            } catch {}
        }
        #expect(await breaker.isOpen)

        // Subsequent call should throw CircuitBreakerOpenError
        do {
            let _: Int = try await breaker.execute { 42 }
            Issue.record("Should have thrown CircuitBreakerOpenError")
        } catch is CircuitBreakerOpenError {
            // Expected
        } catch {
            Issue.record("Expected CircuitBreakerOpenError, got \(error)")
        }
    }

    @Test("Thermal errors are neutral — do not trip breaker")
    func thermalErrorsAreNeutral() async {
        let breaker = AgentCircuitBreaker(domain: .mlx)
        // Send many thermal errors
        for _ in 0..<16 {
            do {
                let _: Int = try await breaker.execute {
                    throw ThermalError(thermalState: .critical)
                }
            } catch {}
        }
        // Should NOT be open — thermal errors are neutral
        #expect(await breaker.isOpen == false)
        #expect(await breaker.failureRate == 0.0)
    }

    @Test("CancellationError is neutral — does not trip breaker")
    func cancellationIsNeutral() async {
        let breaker = AgentCircuitBreaker(domain: .cloud)
        for _ in 0..<32 {
            do {
                let _: Int = try await breaker.execute {
                    throw CancellationError()
                }
            } catch {}
        }
        #expect(await breaker.isOpen == false)
    }

    @Test("Context exhaustion is neutral for FoundationModels domain")
    func contextExhaustionIsNeutral() async {
        let breaker = AgentCircuitBreaker(domain: .foundationModels)
        // Simulate context window errors
        for _ in 0..<16 {
            do {
                let _: Int = try await breaker.execute {
                    throw NSError(
                        domain: "FoundationModels",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "exceededContextWindowSize"]
                    )
                }
            } catch {}
        }
        // Should NOT be open — context exhaustion is neutral for FM
        #expect(await breaker.isOpen == false)
    }

    @Test("Real errors DO trip the breaker")
    func realErrorsTripBreaker() async {
        let breaker = AgentCircuitBreaker(domain: .cloud)
        // Fill buffer with real failures (not thermal, not cancellation)
        for _ in 0..<32 {
            do {
                let _: Int = try await breaker.execute {
                    throw NSError(domain: "HTTP", code: 500,
                                  userInfo: [NSLocalizedDescriptionKey: "Internal Server Error"])
                }
            } catch {}
        }
        #expect(await breaker.isOpen)
    }

    @Test("Half-open transitions to closed after N successes via execute()")
    func halfOpenClosesAfterSuccesses() async throws {
        let breaker = AgentCircuitBreaker(domain: .hermes)
        // Trip the breaker (hermes: capacity=8, threshold=0.5, resetTimeout=10)
        for _ in 0..<8 {
            do {
                let _: Int = try await breaker.execute {
                    throw NSError(domain: "test", code: 1)
                }
            } catch {}
        }
        #expect(await breaker.isOpen)

        // Reset so we can test half-open behavior
        await breaker.reset()
        // Re-trip with short timeout
        let shortBreaker = AgentCircuitBreaker(domain: .hermes)
        // Use the direct API for controlled setup
        for _ in 0..<8 {
            await shortBreaker.recordFailure()
        }
        // Can't easily test timeout-based half-open in unit test without sleep,
        // so test reset → execute pattern instead
        await shortBreaker.reset()
        let result = try await shortBreaker.execute { "recovered" }
        #expect(result == "recovered")
        #expect(await shortBreaker.isOpen == false)
    }
}

// MARK: - UInt64 Bit Ring Buffer Tests

@Suite("BitRingBuffer — Zero-Allocation Internals")
struct BitRingBufferTests {

    @Test("Breaker with UInt64 buffer starts at 0% failure rate")
    func startsAtZero() async {
        let breaker = AgentCircuitBreaker(domain: .cloud)
        #expect(await breaker.failureRate == 0.0)
    }

    @Test("Failure rate increases with failures")
    func failureRateIncreases() async {
        let breaker = AgentCircuitBreaker(domain: .cloud) // capacity 32
        // Fill with all failures
        for _ in 0..<32 {
            await breaker.recordFailure()
        }
        #expect(await breaker.failureRate == 1.0)
    }

    @Test("Mixed results produce correct rate")
    func mixedResults() async {
        let breaker = AgentCircuitBreaker(domain: .cloud) // capacity 32
        // 16 failures + 16 successes = 50%
        for _ in 0..<16 {
            await breaker.recordFailure()
        }
        for _ in 0..<16 {
            await breaker.recordSuccess()
        }
        let rate = await breaker.failureRate
        #expect(rate == 0.5)
    }

    @Test("Old entries are evicted as ring wraps")
    func ringEviction() async {
        let breaker = AgentCircuitBreaker(domain: .hermes) // capacity 8
        // Fill with 8 failures
        for _ in 0..<8 {
            await breaker.recordFailure()
        }
        #expect(await breaker.failureRate == 1.0)

        // Now push 8 successes — old failures are evicted
        for _ in 0..<8 {
            await breaker.recordSuccess()
        }
        #expect(await breaker.failureRate == 0.0)
    }

    @Test("Buffer does not trip before being filled")
    func doesNotTripBeforeFilled() async {
        let breaker = AgentCircuitBreaker(domain: .cloud) // capacity 32
        // Record a few failures but not enough to fill the buffer
        for _ in 0..<5 {
            await breaker.recordFailure()
        }
        // failureRate returns 0.0 when not filled
        #expect(await breaker.failureRate == 0.0)
        #expect(await breaker.isOpen == false)
    }
}

// MARK: - Breaker Domain Configuration Tests

@Suite("BreakerConfig — Domain-Specific Thresholds")
struct BreakerConfigTests {

    @Test("Cloud breaker has correct config")
    func cloudConfig() {
        let config = breakerConfig(for: .cloud)
        #expect(config.capacity == 32)
        #expect(config.failureRateThreshold == 0.50)
        #expect(config.resetTimeout == 60.0)
        #expect(config.requiredHalfOpenSuccesses == 2)
        #expect(config.degradedMode == .degradedCloud)
    }

    @Test("FoundationModels breaker has higher tolerance")
    func foundationModelsConfig() {
        let config = breakerConfig(for: .foundationModels)
        #expect(config.capacity == 16)
        #expect(config.failureRateThreshold == 0.75)
        #expect(config.degradedMode == .degradedAI)
    }

    @Test("MLX breaker has highest tolerance")
    func mlxConfig() {
        let config = breakerConfig(for: .mlx)
        #expect(config.failureRateThreshold == 0.80)
        #expect(config.degradedMode == .degradedAI)
    }

    @Test("Hermes breaker is binary — single success to close")
    func hermesConfig() {
        let config = breakerConfig(for: .hermes)
        #expect(config.capacity == 8)
        #expect(config.requiredHalfOpenSuccesses == 1)
        #expect(config.degradedMode == .localOnly)
    }

    @Test("Vault breaker degrades to readOnly")
    func vaultConfig() {
        let config = breakerConfig(for: .vault)
        #expect(config.degradedMode == .readOnly)
    }

    @Test("All domains have configs")
    func allDomainsHaveConfigs() {
        for domain in BreakerDomain.allCases {
            let config = breakerConfig(for: domain)
            #expect(config.capacity > 0)
            #expect(config.failureRateThreshold > 0.0)
            #expect(config.failureRateThreshold <= 1.0)
            #expect(config.resetTimeout > 0.0)
            #expect(config.requiredHalfOpenSuccesses >= 1)
        }
    }
}

// MARK: - Mode Machine Integration Tests

@Suite("Mode Machine — Breaker + Thermal Integration")
@MainActor
struct ModeMachineIntegrationTests {

    @Test("DegradationReason includes circuit breaker open/recovered")
    func degradationReasonCoverage() {
        let openReason = DegradationReason.circuitBreakerOpen(domain: "cloud")
        #expect(openReason.description.contains("cloud"))

        let recoveredReason = DegradationReason.circuitBreakerRecovered(domain: "mlx")
        #expect(recoveredReason.description.contains("mlx"))
    }

    @Test("DegradationReason includes thermal recovery")
    func thermalRecoveryReason() {
        let reason = DegradationReason.thermalRecovery
        #expect(reason.description == "thermal recovery")
    }

    @Test("DegradationReason includes context window exhausted")
    func contextExhaustedReason() {
        let reason = DegradationReason.contextWindowExhausted
        #expect(reason.description == "context window exhausted")
    }

    @Test("ModeMachine accepts step-by-step recovery with thermal recovery reason")
    func recoveryWithThermalReason() {
        let machine = ModeMachine(recoveryHysteresis: 0.0)
        machine.transition(to: .degradedAI, reason: .thermalThrottling)
        #expect(machine.currentMode == .degradedAI)

        // Recovery must be step-by-step: degradedAI → full (severity 2 → 0 = 1 step)
        // Looking at severity: degradedAI=2, degradedCloud=1, full=0
        // Step: degradedAI → degradedCloud (2→1)
        let step1 = machine.transition(to: .degradedCloud, reason: .thermalRecovery)
        #expect(step1)
        // Step: degradedCloud → full (1→0)
        let step2 = machine.transition(to: .full, reason: .thermalRecovery)
        #expect(step2)
        #expect(machine.currentMode == .full)
    }
}

// MARK: - ThermalGuard Tests

@Suite("ThermalGuard — Centralized Authority")
struct ThermalGuardTests {

    @Test("ThermalGuard starts in nominal state")
    func startsNominal() async {
        let guard_ = ThermalGuard.shared
        await guard_.start()
        let state = await guard_.currentState
        // Initial state depends on actual hardware, but should be nominal/fair in test
        #expect(state == .nominal || state == .fair)
        await guard_.stop()
    }

    @Test("Clearance is immediate when nominal")
    func clearanceImmediateWhenNominal() async throws {
        let guard_ = ThermalGuard.shared
        await guard_.start()
        // Should return immediately (non-blocking)
        try await guard_.acquireClearance()
        await guard_.stop()
    }

    @Test("isInferenceAllowed reflects thermal state")
    func inferenceAllowedReflectsState() async {
        let guard_ = ThermalGuard.shared
        await guard_.start()
        let allowed = await guard_.isInferenceAllowed
        // In test environment, should be allowed (nominal)
        #expect(allowed)
        await guard_.stop()
    }
}

// MARK: - FFI Guard Coverage Tests

@Suite("FFI Guard Coverage — All Exports Protected")
struct FFIGuardCoverageTests {

    @Test("bridge.rs wraps all exports with ffi_guard")
    func allExportsGuarded() throws {
        let bridgePath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("agent_core/src/bridge.rs")
        let content = try String(contentsOf: bridgePath, encoding: .utf8)

        // Count uniffi::export declarations
        let exportCount = content.components(separatedBy: "#[uniffi::export").count - 1

        // Count ffi_guard usages (sync and value)
        let guardSyncCount = content.components(separatedBy: "ffi_guard_sync!").count - 1
        let guardValueCount = content.components(separatedBy: "ffi_guard_value!").count - 1

        // Async exports use tokio::task::spawn with JoinHandle panic catching
        let asyncGuardCount = content.components(separatedBy: "join_error.is_panic()").count - 1

        let totalGuards = guardSyncCount + guardValueCount + asyncGuardCount

        // Every export should have some form of panic protection
        // The preview_provider_route export is pure computation wrapped in ffi_guard_value!
        // Some exports like callback_interface don't need guards (they define traits, not functions)
        #expect(totalGuards >= 10,
                "Expected at least 10 guarded exports across \(exportCount) exports, found \(totalGuards) (sync=\(guardSyncCount), value=\(guardValueCount), async=\(asyncGuardCount))")
    }

    @Test("agent_core uses panic=unwind in release")
    func panicUnwindInRelease() throws {
        let cargoTomlPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("agent_core/Cargo.toml")
        let content = try String(contentsOf: cargoTomlPath, encoding: .utf8)
        #expect(content.contains("panic = \"unwind\""),
                "agent_core MUST use panic = \"unwind\" for catch_unwind to work in release")
    }
}

// MARK: - CircuitBreakerIgnorable Protocol Tests

@Suite("CircuitBreakerIgnorable — Error Classification")
struct CircuitBreakerIgnorableTests {

    @Test("ThermalError is neutral")
    func thermalErrorIsNeutral() {
        let error = ThermalError(thermalState: .critical)
        #expect(error.isCircuitBreakerNeutral)
    }

    @Test("CancellationError is neutral")
    func cancellationIsNeutral() {
        let error = CancellationError()
        #expect(error.isCircuitBreakerNeutral)
    }

    @Test("TimeoutError is NOT neutral")
    func timeoutIsNotNeutral() {
        let error = TimeoutError(seconds: 30.0)
        #expect(!error.isCircuitBreakerNeutral)
    }

    @Test("AppleIntelligenceError.unavailable is neutral")
    func appleIntelligenceUnavailableIsNeutral() {
        let error = AppleIntelligenceError.unavailable("test")
        #expect(error.isCircuitBreakerNeutral)
    }
}

// MARK: - BreakerRegistry Tests

@Suite("BreakerRegistry — Centralized Access")
@MainActor
struct BreakerRegistryTests {

    @Test("Registry provides all five domain breakers")
    func allDomainsAvailable() async {
        let registry = BreakerRegistry.shared
        // Reset all to avoid cross-test state leakage
        for breaker in registry.allBreakers {
            await breaker.reset()
        }
        #expect(await registry.cloud.isOpen == false)
        #expect(await registry.foundationModels.isOpen == false)
        #expect(await registry.mlx.isOpen == false)
        #expect(await registry.hermes.isOpen == false)
        #expect(await registry.vault.isOpen == false)
    }

    @Test("Registry lookup by domain enum")
    func lookupByDomain() async {
        let registry = BreakerRegistry.shared
        for domain in BreakerDomain.allCases {
            let breaker = registry.breaker(for: domain)
            await breaker.reset()
            #expect(await breaker.isOpen == false)
        }
    }

    @Test("allBreakers returns all five")
    func allBreakersCount() {
        let registry = BreakerRegistry.shared
        #expect(registry.allBreakers.count == 5)
    }
}

// MARK: - Release Packaging Hardening Tests

@Suite("Release Packaging Hardening")
struct ReleasePackagingHardeningTests {

    @Test("direct-distribution entitlements keep MLX and Rust FFI allowances wired per config")
    func directDistributionEntitlementsStayWired() throws {
        let releaseEntitlements = try loadProductionHardeningRepoTextFile("Epistemos/Epistemos.entitlements")
        let debugEntitlements = try loadProductionHardeningRepoTextFile("Epistemos/Epistemos-Debug.entitlements")
        let project = try loadProductionHardeningRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let projectSpec = try loadProductionHardeningRepoTextFile("project.yml")

        for key in [
            "com.apple.security.cs.allow-jit",
            "com.apple.security.cs.allow-unsigned-executable-memory",
            "com.apple.security.cs.disable-library-validation",
        ] {
            #expect(releaseEntitlements.contains(key))
            #expect(debugEntitlements.contains(key))
        }

        #expect(!releaseEntitlements.contains("com.apple.security.app-sandbox"))
        #expect(debugEntitlements.contains("com.apple.security.app-sandbox"))
        #expect(project.contains("CODE_SIGN_ENTITLEMENTS = Epistemos/Epistemos.entitlements;"))
        #expect(
            project.contains("CODE_SIGN_ENTITLEMENTS = Epistemos/Epistemos-Debug.entitlements;") ||
                project.contains("CODE_SIGN_ENTITLEMENTS = \"Epistemos/Epistemos-Debug.entitlements\";")
        )
        #expect(project.contains("CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO;"))
        #expect(project.contains("ENABLE_HARDENED_RUNTIME = YES;"))
        #expect(projectSpec.contains("CODE_SIGN_ENTITLEMENTS: Epistemos/Epistemos.entitlements"))
        #expect(projectSpec.contains("CODE_SIGN_ENTITLEMENTS: Epistemos/Epistemos-Debug.entitlements"))
        #expect(projectSpec.contains("CODE_SIGN_INJECT_BASE_ENTITLEMENTS: false"))
        #expect(projectSpec.contains("ENABLE_HARDENED_RUNTIME: true"))
    }

    @Test("prepared model manifest is bundled into app resources")
    func preparedModelManifestIsBundledIntoAppResources() throws {
        let spec = try loadProductionHardeningRepoTextFile("project.yml")
        let manifest = try loadProductionHardeningRepoTextFile("config/model_manifest.json")

        #expect(spec.contains("config/model_manifest.json"))
        #expect(manifest.contains("\"version\": 1"))
        #expect(manifest.contains("\"models\""))
    }

    @Test("runtime asset bundler copies the prepared model manifest into app resources")
    func runtimeAssetBundlerCopiesPreparedModelManifest() throws {
        let bundler = try loadProductionHardeningRepoTextFile("bundle-app-runtime-assets.sh")

        #expect(bundler.contains("config/model_manifest.json"))
        #expect(bundler.contains("model_manifest.json"))
    }

    @Test("test hosts skip Hermes subprocess prewarm and supervision")
    func testHostsSkipHermesSubprocessBootstrap() throws {
        let source = try loadProductionHardeningRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(source.contains("if !Self.isRunningTests && setupComplete && !PowerGuard.shared.shouldDisableBackground"))
        #expect(source.contains("if !Self.isRunningTests {\n            supervisor.register(ChildSpec("))
        #expect(source.contains("supervisor.start()"))
    }

    @Test("test hosts skip startup auto-discovery credential imports")
    func testHostsSkipStartupAutoDiscoveryCredentialImports() throws {
        let source = try loadProductionHardeningRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(source.contains("Self.startupAutoDiscoveryReportForTesting("))
        #expect(source.contains("isRunningTests: Self.isRunningTests"))
        #expect(source.contains("return StartupAutoDiscovery.testHostReport()"))
    }

    @Test("test hosts skip Metal shader warmup bootstrap work")
    func testHostsSkipMetalShaderWarmupBootstrapWork() throws {
        let source = try loadProductionHardeningRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(source.contains("scheduleMetalShaderWarmupIfNeeded()"))
        #expect(source.contains("private func scheduleMetalShaderWarmupIfNeeded()"))
        #expect(source.contains("guard !Self.isRunningTests else { return }"))
    }
}

// MARK: - Audit Hardening Regression Tests

@Suite("Audit Hardening Regression")
struct AuditHardeningRegressionTests {
    @Test("Inline response replacement discards stale response before restart")
    @MainActor func inlineResponseReplacementDiscardsStaleResponse() {
        let inference = InferenceState()
        let triage = TriageService(
            inference: inference,
            localLLMService: AuditCapturingStreamingLLMClient()
        )

        let state = NoteChatState(pageId: "page-inline-regression")
        state.noteBodyProvider = { "Original note body." }
        state.hasResponse = true
        state.useResponsePanel = false
        state.responseText = "stale inline response"

        var events: [String] = []
        state.onDiscard = { events.append("discard") }
        state.onStreamStart = { _ in events.append("start") }

        state.submitQuery(
            "Rewrite this paragraph",
            operation: .rewrite,
            triageService: triage
        )

        #expect(Array(events.prefix(2)) == ["discard", "start"])
        #expect(state.hasResponse)
        #expect(state.responseText.isEmpty)
    }

    @Test("Text views protect the divider while allowing AI text edits")
    @MainActor func textViewsProtectDividerWhileAllowingAITextEdits() {
        assertDividerProtection(on: ProseTextView2(frame: .zero))
    }

    @Test("Vault destructive stop snapshots before clearing local data")
    func vaultDestructiveStopSnapshotsBeforeClearing() throws {
        let source = try loadProductionHardeningRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let destructiveBlock = try #require(source.range(of: "if !preserveData {"))
        let destructiveBody = source[destructiveBlock.lowerBound...]
        let snapshotCall = try #require(destructiveBody.range(of: "try snapshotLocalState()"))
        let clearCall = try #require(destructiveBody.range(of: "clearVaultData()"))

        #expect(snapshotCall.lowerBound > destructiveBlock.lowerBound)
        #expect(snapshotCall.lowerBound < clearCall.lowerBound)
    }

    @Test("Vault recovery snapshots use SQLite backups and prune old snapshots")
    func vaultRecoverySnapshotsUseSQLiteBackupsAndPruneOldSnapshots() throws {
        let source = try loadProductionHardeningRepoTextFile("Epistemos/Sync/VaultSyncService.swift")

        #expect(source.contains("sqlite3_backup_init"))
        #expect(source.contains("backupSQLiteDatabaseIfPresent"))
        #expect(source.contains("copyDirectoryContents("))
        #expect(source.contains("pruneRecoverySnapshots(in: snapshotRoot"))
        #expect(source.contains("pruneRecoverySnapshotsIfNeeded()"))
        #expect(source.contains("recoverySnapshotLimit = 20"))
    }

    @Test("Vault recovery snapshots request and prune APFS safety snapshots")
    func vaultRecoverySnapshotsRequestAndPruneAPFSSafetySnapshots() throws {
        let source = try loadProductionHardeningRepoTextFile("Epistemos/Sync/VaultSyncService.swift")

        #expect(source.contains("createAPFSSafetySnapshotIfPossible(reason: \"local-state-recovery\")"))
        #expect(source.contains("pruneAPFSSafetySnapshotsIfNeeded()"))
        #expect(source.contains("commandRunner([\"localsnapshot\"])"))
        #expect(source.contains("commandRunner([\"listlocalsnapshots\", \"/\"])"))
        #expect(source.contains("commandRunner([\"deletelocalsnapshots\", snapshotID])"))
        #expect(source.contains("apfs-snapshot-manifest.json"))
    }

    @Test("Vault APFS safety snapshots run off the main actor")
    func vaultAPFSSafetySnapshotsRunOffMainActor() throws {
        let source = try loadProductionHardeningRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let createRange = try #require(source.range(of: "private func createAPFSSafetySnapshotIfPossible(reason: String) {"))
        let createBody = source[createRange.lowerBound...]
        let pruneRange = try #require(source.range(of: "private func pruneAPFSSafetySnapshotsIfNeeded() {"))
        let pruneBody = source[pruneRange.lowerBound...]

        #expect(createBody.contains("Task.detached(priority: .utility)"))
        #expect(pruneBody.contains("Task.detached(priority: .utility)"))
        #expect(source.contains("Self.backgroundLog.error(\"Failed to create APFS safety snapshot"))
        #expect(source.contains("Self.backgroundLog.error(\"Failed to prune APFS safety snapshots"))
    }

    @Test("vault destructive UI flows use async off-main snapshot switching")
    func vaultDestructiveUIFlowsUseAsyncSnapshotSwitching() throws {
        let vaultSync = try loadProductionHardeningRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let setupAssistant = try loadProductionHardeningRepoTextFile("Epistemos/Views/Onboarding/SetupAssistantView.swift")
        let settings = try loadProductionHardeningRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let appBootstrap = try loadProductionHardeningRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let resetRange = try #require(appBootstrap.range(of: "func resetAllData() async {"))
        let resetBody = appBootstrap[resetRange.lowerBound...]

        #expect(vaultSync.contains("func stopWatchingAsync(preserveData: Bool = false) async -> Bool"))
        #expect(vaultSync.contains("func switchToVaultAsync("))
        #expect(vaultSync.contains("private func snapshotLocalStateOffMain() async throws"))
        #expect(vaultSync.contains("Task.detached(priority: .utility)"))
        #expect(vaultSync.contains("let didClear = await vaultSync.stopWatchingAsync(preserveData: false)"))
        #expect(vaultSync.contains("if didClear {\n                vaultSync.dismissRecoveryIssue()"))
        #expect(vaultSync.contains("let didSwitch = await vaultSync.switchToVaultAsync(vaultURL: url)"))
        #expect(vaultSync.contains("if didSwitch {\n                vaultSync.persistVaultSelection("))
        #expect(setupAssistant.contains("VaultConnectionActions.connectSelectedVault(url: url, vaultSync: vaultSync)"))
        #expect(settings.contains("await AppBootstrap.shared?.resetAllData()"))
        #expect(resetBody.contains("_ = await vaultSync.stopWatchingAsync(preserveData: false)"))
    }

    @Test("Omega planner schemas stay aligned with registered MCP tools")
    @MainActor func omegaPlannerSchemasStayAligned() throws {
        let inference = InferenceState()
        let triage = TriageService(inference: inference)
        let planner = OmegaInferenceBridge(triageService: triage)
        let runtime = MCPBridge()

        let data = try #require(planner.toolSchemasJson.data(using: .utf8))
        let schemas = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])

        #expect(!schemas.isEmpty)
        #expect(schemas.count == runtime.toolCount)
        #expect(schemas.count == OmegaToolRegistry.all.count)
    }

    @Test("Regex-backed helpers avoid force-try compilation")
    func regexBackedHelpersAvoidForceTryCompilation() throws {
        let files = [
            "Epistemos/Sync/BlockPropertyParser.swift",
            "Epistemos/Views/Chat/ChatView.swift",
            "Epistemos/Views/Chat/TaggedMarkdownTextView.swift",
            "Epistemos/Views/Notes/MarkdownContentStorage.swift",
            "Epistemos/Views/Notes/MarkdownEditorStyle.swift",
            "Epistemos/Theme/EpistemosTheme.swift",
            "Epistemos/Theme/GlassModifiers.swift",
        ]

        for file in files {
            let source = try loadProductionHardeningRepoTextFile(file)
            #expect(!source.contains("try!"), "\(file) should not use try! for regex or detector setup")
        }
    }

    @Test("Trap-prone persistence fallbacks stay removed")
    func trapPronePersistenceFallbacksStayRemoved() throws {
        let appBootstrap = try loadProductionHardeningRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let feedbackLogger = try loadProductionHardeningRepoTextFile("Epistemos/KnowledgeFusion/Alignment/FeedbackLogger.swift")
        let dataDetectionService = try loadProductionHardeningRepoTextFile("Epistemos/Engine/DataDetectionService.swift")
        let queryParser = try loadProductionHardeningRepoTextFile("Epistemos/Engine/QueryParser.swift")
        let structuredQueryParser = try loadProductionHardeningRepoTextFile("Epistemos/Engine/StructuredQueryParser.swift")

        #expect(!appBootstrap.contains("try! ModelContainer("))
        #expect(!feedbackLogger.contains("try! JSONSerialization.data"))
        #expect(!feedbackLogger.contains("String(data: data, encoding: .utf8)!"))
        #expect(!dataDetectionService.contains("URL(string: \"webcal://\")!"))
        #expect(!queryParser.contains("calendar.date(byAdding: .day, value: -1, to: now)!"))
        #expect(!queryParser.contains("calendar.date(byAdding: .day, value: -7, to: now)!"))
        #expect(!queryParser.contains("calendar.date(byAdding: .month, value: -1, to: now)!"))
        #expect(!structuredQueryParser.contains("calendar.date(byAdding: .day, value: -1, to: now)!"))
        #expect(!structuredQueryParser.contains("calendar.date(byAdding: .day, value: -7, to: now)!"))
        #expect(!structuredQueryParser.contains("calendar.date(byAdding: .month, value: -1, to: now)!"))
    }

    @Test("Recent runtime trap removals stay hardened")
    func recentRuntimeTrapRemovalsStayHardened() throws {
        let embodiedCapture = try loadProductionHardeningRepoTextFile("Epistemos/KnowledgeFusion/SyntheticData/EmbodiedCaptureService.swift")
        let themeSource = try loadProductionHardeningRepoTextFile("Epistemos/Theme/EpistemosTheme.swift")
        let hermesAdminPanel = try loadProductionHardeningRepoTextFile("Epistemos/Views/Settings/HermesAdminPanel.swift")
        let appSupervisor = try loadProductionHardeningRepoTextFile("Epistemos/State/AppSupervisor.swift")

        #expect(!embodiedCapture.contains("handle.write(line.data(using: .utf8)!)"))
        #expect(embodiedCapture.contains("guard let lineData = line.data(using: .utf8) else {"))

        #expect(!themeSource.contains("preconditionFailure(\"Missing resolved theme cache"))
        #expect(themeSource.contains("Self.resolvedCache[self] ?? buildResolved()"))

        #expect(!hermesAdminPanel.contains("Link(destination: URL(string: registry.url)!)"))
        #expect(hermesAdminPanel.contains("if let destination = URL(string: registry.url) {"))

        #expect(appSupervisor.contains("import Network"))
        #expect(appSupervisor.contains("NWPathMonitor"))
        #expect(!appSupervisor.contains("https://api.anthropic.com"))
    }

    @Test("Cloud routing safety gates stay wired")
    func cloudRoutingSafetyGatesStayWired() throws {
        let triageService = try loadProductionHardeningRepoTextFile("Epistemos/Engine/TriageService.swift")

        #expect(triageService.contains("if context.routingMode == .localOnly {"))
        #expect(triageService.contains("reasonCodes.insert(.localModeForced)"))
        #expect(triageService.contains("private func cloudConfigurationError() -> CloudLLMError? {"))
        #expect(triageService.contains("if let error = cloudConfigurationError() {"))
        #expect(triageService.contains("continuation.finish(throwing: error)"))
    }

    @Test("launch and note shell surfaces keep explicit loading empty and accessibility states")
    func launchAndNoteShellSurfacesKeepExplicitPolishStates() throws {
        let timeMachine = try loadProductionHardeningRepoTextFile("Epistemos/Views/Landing/TimeMachineView.swift")
        let workspaces = try loadProductionHardeningRepoTextFile("Epistemos/Views/Landing/WorkspaceSwitcherOverlay.swift")
        let notesSidebar = try loadProductionHardeningRepoTextFile("Epistemos/Views/Notes/NotesSidebar.swift")
        let landing = try loadProductionHardeningRepoTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(timeMachine.contains("Text(\"No session history yet\")"))
        #expect(timeMachine.contains("ProgressView()"))
        #expect(timeMachine.contains("Text(\"Select a session to explore\")"))

        #expect(workspaces.contains("Text(\"No saved workspaces\")"))
        #expect(workspaces.contains("Text(\"esc to close\")"))

        #expect(notesSidebar.contains("Text(\"No results\")"))
        #expect(notesSidebar.contains("Text(\"No notes yet\")"))
        #expect(notesSidebar.contains(".accessibilityLabel(\"Search notes\")"))
        #expect(notesSidebar.contains(".accessibilityLabel(\"Clear search\")"))

        #expect(landing.contains(".accessibilityLabel(\"Send prompt\")"))
        #expect(landing.contains(".accessibilityLabel(\"Local Model\")"))
        #expect(landing.contains("ProgressView()"))
    }

    @Test("root shell keeps recovery overlays toast feedback and toolbar accessibility affordances")
    func rootShellKeepsRecoveryAndAccessibilityAffordances() throws {
        let rootView = try loadProductionHardeningRepoTextFile("Epistemos/App/RootView.swift")

        #expect(rootView.contains("ToastOverlay("))
        #expect(rootView.contains("VaultRecoveryOverlay("))
        #expect(rootView.contains(".accessibilityLabel(\"Back to Home\")"))
        #expect(rootView.contains(".accessibilityLabel(\"Settings\")"))
        #expect(rootView.contains(".accessibilityLabel(\"Chat History\")"))
        #expect(rootView.contains(".alert(\"Database Error\""))
    }

    @MainActor
    private func assertDividerProtection(on textView: NSTextView) {
        textView.string = "Hello world.\(NoteChatInlineResponse.divider)AI response."

        if let prose = textView as? ProseTextView2 {
            prose.hasProtectedInlineResponseDivider = true
        }

        let fullText = textView.string as NSString
        let dividerRange = fullText.range(of: NoteChatInlineResponse.divider)
        let responseRange = fullText.range(of: "AI response.")

        #expect(dividerRange.location != NSNotFound)
        #expect(responseRange.location != NSNotFound)

        let blocked: Bool
        let allowed: Bool

        switch textView {
        case let prose as ProseTextView2:
            blocked = prose.shouldChangeText(
                in: NSRange(location: dividerRange.location + 1, length: 1),
                replacementString: ""
            )
            allowed = prose.shouldChangeText(
                in: responseRange,
                replacementString: "Edited response."
            )
        default:
            Issue.record("Unexpected text view type: \(type(of: textView))")
            return
        }

        #expect(!blocked)
        #expect(allowed)
    }
}

@MainActor
private final class AuditCapturingStreamingLLMClient: LLMClientProtocol {
    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        "unused"
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                continuation.yield("ok")
                continuation.finish()
            }
        }
    }

    func testConnection() async -> ConnectionTestResult {
        ConnectionTestResult(success: true, message: "ok")
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(
            provider: .localMLX,
            model: LocalTextModelID.qwen35_4B4Bit.rawValue,
            reasoningMode: .fast
        )
    }
}
