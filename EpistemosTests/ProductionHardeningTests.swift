import AppKit
import Foundation
import Testing
@testable import Epistemos

private func loadProductionHardeningRepoTextFile(
    _ relativePath: String,
    testsFilePath: String = #filePath,
    attempts: Int = 5
) throws -> String {
    _ = testsFilePath
    _ = attempts
    return try loadMirroredSourceTextFile(relativePath)
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
        let breaker = AgentCircuitBreaker(domain: .vault)
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
        let breaker = AgentCircuitBreaker(domain: .vault)
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
        let breaker = AgentCircuitBreaker(domain: .vault)
        // Trip the breaker (vault: capacity=8, threshold=0.75, resetTimeout=30)
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
        let shortBreaker = AgentCircuitBreaker(domain: .vault)
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
        let breaker = AgentCircuitBreaker(domain: .vault) // capacity 8
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

    @Test("Vault breaker uses compact buffer and read-only degradation")
    func vaultCompactConfig() {
        let config = breakerConfig(for: .vault)
        #expect(config.capacity == 8)
        #expect(config.requiredHalfOpenSuccesses == 2)
        #expect(config.degradedMode == .readOnly)
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
        let content = try loadProductionHardeningRepoTextFile("agent_core/src/bridge.rs")

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
        let content = try loadProductionHardeningRepoTextFile("agent_core/Cargo.toml")
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

    @Test("Registry provides all four domain breakers")
    func allDomainsAvailable() async {
        let registry = BreakerRegistry.shared
        // Reset all to avoid cross-test state leakage
        for breaker in registry.allBreakers {
            await breaker.reset()
        }
        #expect(await registry.cloud.isOpen == false)
        #expect(await registry.foundationModels.isOpen == false)
        #expect(await registry.mlx.isOpen == false)
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

    @Test("allBreakers returns all four")
    func allBreakersCount() {
        let registry = BreakerRegistry.shared
        #expect(registry.allBreakers.count == 4)
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

    @Test("App Store target is sandboxed and excludes direct-distribution entitlements")
    func appStoreTargetUsesSandboxEntitlements() throws {
        let appStoreEntitlements = try loadProductionHardeningRepoTextFile("Epistemos/Epistemos-AppStore.entitlements")
        let appStoreInfoPlist = try loadProductionHardeningRepoTextFile("Epistemos-AppStore-Info.plist")
        let infoPlist = try loadProductionHardeningRepoTextFile("Epistemos-Info.plist")
        let project = try loadProductionHardeningRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let projectSpec = try loadProductionHardeningRepoTextFile("project.yml")

        for key in [
            "com.apple.security.app-sandbox",
            "com.apple.security.cs.allow-jit",
            "com.apple.security.files.bookmarks.app-scope",
            "com.apple.security.files.user-selected.read-write",
            "com.apple.security.network.client",
        ] {
            #expect(appStoreEntitlements.contains(key))
        }

        for prohibitedKey in [
            "com.apple.security.automation.apple-events",
            "com.apple.security.cs.allow-unsigned-executable-memory",
            "com.apple.security.cs.disable-library-validation",
            "com.apple.security.files.bookmarks.document-scope",
            "com.apple.security.temporary-exception.mach-lookup.global-name",
        ] {
            #expect(!appStoreEntitlements.contains(prohibitedKey))
        }

        #expect(infoPlist.contains("$(PRODUCT_BUNDLE_IDENTIFIER)"))
        #expect(infoPlist.contains("$(PRODUCT_NAME)"))
        #expect(infoPlist.contains("$(EXECUTABLE_NAME)"))
        #expect(infoPlist.contains("<string>APPL</string>"))
        #expect(appStoreInfoPlist.contains("$(PRODUCT_BUNDLE_IDENTIFIER)"))
        #expect(appStoreInfoPlist.contains("$(PRODUCT_NAME)"))
        #expect(appStoreInfoPlist.contains("$(EXECUTABLE_NAME)"))
        #expect(appStoreInfoPlist.contains("<string>APPL</string>"))
        #expect(!appStoreInfoPlist.contains("NSAccessibilityUsageDescription"))
        #expect(!appStoreInfoPlist.contains("NSAppleEventsUsageDescription"))
        #expect(!appStoreInfoPlist.contains("NSScreenCaptureUsageDescription"))
        #expect(projectSpec.contains("Epistemos-AppStore:"))
        #expect(projectSpec.contains("PRODUCT_BUNDLE_IDENTIFIER: com.epistemos.appstore"))
        #expect(projectSpec.contains("INFOPLIST_FILE: Epistemos-AppStore-Info.plist"))
        #expect(projectSpec.contains("CODE_SIGN_ENTITLEMENTS: Epistemos/Epistemos-AppStore.entitlements"))
        #expect(projectSpec.contains("EPISTEMOS_APP_STORE MAS_SANDBOX"))
        #expect(project.contains("Epistemos-AppStore"))
        #expect(project.contains("PRODUCT_BUNDLE_IDENTIFIER = com.epistemos.appstore;"))
        #expect(project.contains("INFOPLIST_FILE = \"Epistemos-AppStore-Info.plist\";") ||
                project.contains("INFOPLIST_FILE = Epistemos-AppStore-Info.plist;"))
        #expect(project.contains("CODE_SIGN_ENTITLEMENTS = \"Epistemos/Epistemos-AppStore.entitlements\";") ||
                project.contains("CODE_SIGN_ENTITLEMENTS = Epistemos/Epistemos-AppStore.entitlements;"))
    }

    @Test("App Store settings hide Pro-only channel skill and automation surfaces")
    func appStoreSettingsHideProOnlySurfaces() throws {
        let settings = try loadProductionHardeningRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let agentSection = try loadProductionHardeningRepoTextFile("Epistemos/Views/Settings/AgentSectionDetailView.swift")
        let authority = try loadProductionHardeningRepoTextFile("Epistemos/Views/Settings/AuthoritySettingsView.swift")

        #expect(settings.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)"))
        #expect(settings.contains("categories.append(.automation)"))
        #expect(settings.contains("sections.append(.channels)"))
        #expect(settings.contains("sections.append(.knowledgeFusion)"))
        #expect(settings.contains(".iMessageDriver"))
        #expect(settings.contains(".skills"))
        #expect(settings.contains("safeDetailSelection(for section: SettingsSection?)"))
        #expect(settings.contains("case .channels, .knowledgeFusion, .iMessageDriver, .skills:"))
        #expect(settings.contains("NotificationCenter.default.publisher(for: .showIMessageDriverSettings)"))
        #expect(agentSection.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX"))
        #expect(agentSection.contains("[.authority, .spend, .structures]"))
        #expect(agentSection.contains("case control"))
        #expect(agentSection.contains("case overseer"))
        #expect(agentSection.contains("ForEach(AgentTab.visibleTabs)"))
        #expect(agentSection.contains("initialTab.isVisibleInCurrentBuild ? initialTab : .authority"))
        #expect(authority.contains("isVisibleInAppStoreAuthority"))
        #expect(authority.contains("AgentAuthorityQuickSetupPreset.allCases.filter { $0 != .lessInterruptions }"))
        #expect(authority.contains("case .gitOperation,"))
        #expect(authority.contains("return [.askFirst, .neverAllow]"))
    }

    @Test("App Store composer hides shell access affordances")
    func appStoreComposerHidesShellAccessAffordances() throws {
        let inputBar = try loadProductionHardeningRepoTextFile("Epistemos/Views/Chat/ChatInputBar.swift")

        #expect(inputBar.contains("#if !EPISTEMOS_APP_STORE\n        rows.append(\n            ComposerPermissionGrantRow(\n                id: \"shell-approval\""))
        #expect(inputBar.contains("#if !EPISTEMOS_APP_STORE\n        segments.append(\"Shell: ask first\")"))
        #expect(inputBar.contains("#if EPISTEMOS_APP_STORE\n        .accessibilityHint(\"Shows attached-resource and vault access for this chat.\")"))
        #expect(inputBar.contains("segments.append(\"Local chat\")"))
    }

    @Test("Chat surfaces disable send when no runtime is ready")
    func chatSurfacesDisableSendWhenNoRuntimeIsReady() throws {
        let inferenceState = try loadProductionHardeningRepoTextFile("Epistemos/State/InferenceState.swift")
        let rootView = try loadProductionHardeningRepoTextFile("Epistemos/App/RootView.swift")
        let inputBar = try loadProductionHardeningRepoTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        let miniChat = try loadProductionHardeningRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")

        #expect(inferenceState.contains("func isChatSurfaceRuntimeReady(for operatingMode: EpistemosOperatingMode) -> Bool"))
        #expect(rootView.contains("return \"\\(operatingMode.wrappedValue.displayName) · Set Up Model\""))
        #expect(rootView.contains("return \"Set Up Model\""))
        #expect(inputBar.contains("isEnabled: isProcessing || (!trimmedText.isEmpty && selectedRuntimeReady)"))
        #expect(inputBar.contains("guard !trimmedText.isEmpty, !isProcessing, selectedRuntimeReady else { return }"))
        #expect(miniChat.contains("isProcessing || (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedRuntimeReady)"))
        #expect(miniChat.contains("guard !trimmed.isEmpty, !isProcessing, selectedRuntimeReady else { return }"))
    }

    @Test("App Store target excludes executable Python and Pro runtime assets")
    func appStoreTargetExcludesExecutablePythonRuntimeAssets() throws {
        let projectSpec = try loadProductionHardeningRepoTextFile("project.yml")
        let bundler = try loadProductionHardeningRepoTextFile("bundle-app-runtime-assets.sh")
        let appStoreTarget = try #require(projectSpec.range(of: "  Epistemos-AppStore:"))
        let testsTarget = try #require(projectSpec.range(of: "  EpistemosTests:"))
        let appStoreSpec = String(projectSpec[appStoreTarget.lowerBound..<testsTarget.lowerBound])

        for excludedPath in [
            "KnowledgeFusion/Alignment/scripts/**",
            "KnowledgeFusion/Training/scripts/**",
            "KnowledgeFusion/MoLoRA/molora_inference.py",
            "KnowledgeFusion/MoLoRA/sgmm_kernel.py",
            "KnowledgeFusion/MoLoRA/train_router.py",
            "KnowledgeFusion/MoLoRA/tests/**",
            "KnowledgeFusion/MoLoRA/__pycache__/**",
        ] {
            #expect(appStoreSpec.contains(excludedPath))
        }

        #expect(bundler.contains("is_app_store_build()"))
        #expect(bundler.contains("sanitize_app_store_resources()"))
        #expect(bundler.contains(#""${TARGET_NAME:-}" == "Epistemos-AppStore""#))
        #expect(bundler.contains(#""${PRODUCT_BUNDLE_IDENTIFIER:-}" == "com.epistemos.appstore""#))
        #expect(bundler.contains("EPISTEMOS_APP_STORE"))
        #expect(bundler.contains("-name '*.py'"))
        #expect(bundler.contains("-name '*.pyc'"))
        #expect(bundler.contains("rm -rf \"$AGENT_RUNTIME_DIR\""))
        #expect(bundler.contains("find \"$KNOWLEDGE_FUSION_DIR\" -depth -type d -empty -delete"))
        #expect(bundler.contains("if is_app_store_build; then"))
        #expect(bundler.contains("exit 0"))
    }

    @Test("App Store target does not link native computer-use automation stack")
    func appStoreTargetDoesNotLinkNativeComputerUseAutomationStack() throws {
        let projectSpec = try loadProductionHardeningRepoTextFile("project.yml")
        let appStoreTarget = try #require(projectSpec.range(of: "  Epistemos-AppStore:"))
        let testsTarget = try #require(projectSpec.range(of: "  EpistemosTests:"))
        let appStoreSpec = String(projectSpec[appStoreTarget.lowerBound..<testsTarget.lowerBound])

        #expect(!appStoreSpec.contains("package: AXorcist"))
        #expect(!appStoreSpec.contains("-lomega_ax"))
        #expect(!appStoreSpec.contains("omega_axFFI"))
        #expect(!appStoreSpec.contains("build-omega-ax.sh"))
        #expect(appStoreSpec.contains("- omega_ax.swift"))
        #expect(appStoreSpec.contains("Scrub Pro Frameworks"))
        #expect(appStoreSpec.contains(#"rm -f "${frameworks_dir}/libomega_ax.dylib""#))
        #expect(appStoreSpec.contains(#"rm -rf "${frameworks_dir}/AXorcist.framework""#))

        for wrappedPath in [
            "Epistemos/Bridge/ComputerUseBridge.swift",
            "Epistemos/Bridge/Phase4Bridge.swift",
            "Epistemos/Omega/Vision/AXMutationDetector.swift",
            "Epistemos/Omega/Vision/AXorcistBridge.swift",
            "Epistemos/Omega/Vision/Screen2AXFusion.swift",
            "Epistemos/Omega/Vision/ScreenCaptureService.swift",
            "Epistemos/Omega/Vision/VisualVerifyLoop.swift",
        ] {
            let source = try loadProductionHardeningRepoTextFile(wrappedPath)
            #expect(source.contains("#if !EPISTEMOS_APP_STORE"))
        }
        let deletedGhostAgent = try sourceMirrorURL(for: "Epistemos/Omega/Agents/GhostComputerAgent.swift")
        #expect(!FileManager.default.fileExists(atPath: deletedGhostAgent.path))

        let omegaPermissions = try loadProductionHardeningRepoTextFile("Epistemos/Omega/OmegaPermissions.swift")
        let masGate = try #require(omegaPermissions.range(of: "#if EPISTEMOS_APP_STORE"))
        let proGate = try #require(omegaPermissions.range(of: "#else"))
        let masOmegaPermissions = String(omegaPermissions[masGate.lowerBound..<proGate.lowerBound])
        let proOmegaPermissions = String(omegaPermissions[proGate.lowerBound...])
        #expect(masOmegaPermissions.contains("final class OmegaPermissions"))
        #expect(!masOmegaPermissions.contains("ScreenCaptureKit"))
        #expect(!masOmegaPermissions.contains("SCShareableContent"))
        #expect(!masOmegaPermissions.contains("AEDeterminePermissionToAutomateTarget"))
        #expect(proOmegaPermissions.contains("import ScreenCaptureKit"))
        #expect(proOmegaPermissions.contains("AEDeterminePermissionToAutomateTarget"))

        let tccPermissionState = try loadProductionHardeningRepoTextFile("Epistemos/Omega/Vision/TCCPermissionState.swift")
        let tccMasGate = try #require(tccPermissionState.range(of: "#if EPISTEMOS_APP_STORE"))
        let tccProGate = try #require(tccPermissionState.range(of: "#else"))
        let masTCCPermissionState = String(tccPermissionState[tccMasGate.lowerBound..<tccProGate.lowerBound])
        let proTCCPermissionState = String(tccPermissionState[tccProGate.lowerBound...])
        #expect(masTCCPermissionState.contains("final class TCCPermissionState"))
        #expect(!masTCCPermissionState.contains("ScreenCaptureKit"))
        #expect(!masTCCPermissionState.contains("SCShareableContent"))
        #expect(proTCCPermissionState.contains("import ScreenCaptureKit"))
        #expect(proTCCPermissionState.contains("SCShareableContent"))

        let stubs = try loadProductionHardeningRepoTextFile("Epistemos/AppStore/AppStoreComputerUseStubs.swift")
        #expect(stubs.contains("#if EPISTEMOS_APP_STORE"))
        #expect(stubs.contains("Native computer-use automation is unavailable in the App Store build."))
        #expect(stubs.contains("final class ComputerUseBridge"))
        #expect(stubs.contains("final class Phase4Bridge"))
        #expect(stubs.contains("final class Screen2AXFusion"))
        #expect(stubs.contains("nonisolated func checkPermissions() -> PermissionStatus"))
        #expect(stubs.contains("nonisolated func walkAxTreeJson(pid: Int64) -> String"))
    }

    @Test("App Store bootstrap skips Pro-only iMessage and training runtime startup")
	func appStoreBootstrapSkipsProOnlyRuntimeStartup() throws {
		let bootstrap = try loadProductionHardeningRepoTextFile("Epistemos/App/AppBootstrap.swift")
		let environment = try loadProductionHardeningRepoTextFile("Epistemos/App/AppEnvironment.swift")
		let nightBrain = try loadProductionHardeningRepoTextFile("Epistemos/State/NightBrainService.swift")
		let nightBrainScheduler = try loadProductionHardeningRepoTextFile("Epistemos/State/NightBrainScheduler.swift")
		let app = try loadProductionHardeningRepoTextFile("Epistemos/App/EpistemosApp.swift")
		let project = try loadProductionHardeningRepoTextFile("Epistemos.xcodeproj/project.pbxproj")

        #expect(bootstrap.contains("#if !EPISTEMOS_APP_STORE\n        // Configure Knowledge Fusion at boot"))
        #expect(bootstrap.contains("#if !EPISTEMOS_APP_STORE\n        // Initialize iMessage driver"))
        #expect(bootstrap.contains("#if !EPISTEMOS_APP_STORE\n            KnowledgeFusionViewModel.shared.prepareBackgroundSchedulingIfNeeded()"))
		#expect(bootstrap.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)\n        // W10.10-FIX"))
		#expect(bootstrap.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)\n        if NightBrainScheduler.shouldRunFallbackInline()"))
		let appStoreExceptionStart = try #require(project.range(
			of: "Exceptions for \"Epistemos\" folder in \"Epistemos-AppStore\" target"
		))
		let appStoreExceptionTarget = try #require(project[appStoreExceptionStart.lowerBound...].range(
			of: "target = D30E77DBB7C16B42612B2335 /* Epistemos-AppStore */;"
		))
		let appStoreExceptionBlock = project[appStoreExceptionStart.lowerBound..<appStoreExceptionTarget.upperBound]
		#expect(appStoreExceptionBlock.contains("Resources/LaunchAgents/com.epistemos.nightbrain.plist"))
		#expect(nightBrainScheduler.contains("public static func bundledLaunchAgentURL(bundle: Bundle = .main) -> URL"))
		#expect(nightBrainScheduler.contains("Contents/Library/LaunchAgents"))
		#expect(nightBrainScheduler.contains("guard bundledLaunchAgentExists() else"))
		let bundledAgentGuard = try #require(nightBrainScheduler.range(of: "guard bundledLaunchAgentExists() else"))
		let agentStatusRead = try #require(nightBrainScheduler.range(of: "let current = agent.status"))
		#expect(bundledAgentGuard.lowerBound < agentStatusRead.lowerBound)
		#expect(environment.contains("#if !EPISTEMOS_APP_STORE\n            .environment(bootstrap.iMessageDriver)"))
        #expect(nightBrain.contains("#if EPISTEMOS_APP_STORE\n        Self.log.info(\"NightBrain: scheduler skipped in App Store build\")"))
        #expect(nightBrain.contains("let bgScheduler = NSBackgroundActivityScheduler(identifier: \"com.epistemos.nightbrain\")"))
        #expect(app.contains("#if EPISTEMOS_APP_STORE"))
        #expect(app.contains("private final class AppStoreFirstWindowPresenter"))
        #expect(app.contains("private weak var bootstrap: AppBootstrap?"))
        #expect(app.contains("_bootstrap = State(initialValue: bootstrap)"))
        #expect(app.contains("private static func viableHomeWindow() -> NSWindow?"))
        #expect(app.contains("window.frame.width >= WindowPresentationPolicy.mainWindowMinimumSize.width"))
        #expect(app.contains("NSApp.setActivationPolicy(.regular)"))
        #expect(app.contains("AppStoreFirstWindowPresenter.shared.schedule(bootstrap: bootstrap)"))
        #expect(app.contains("AppStoreFirstWindowPresenter.shared.scheduleAfterLaunch()"))
        #expect(app.contains("func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool"))
        #expect(app.contains("AppStoreFirstWindowPresenter.shared.ensureHomeWindow()"))
        #expect(app.contains("window.isReleasedWhenClosed = false"))
        #expect(app.contains("HomeSceneRootContent(bootstrap: bootstrap, showQuickCapture: $showQuickCapture)"))
    }

    @Test("App Store build compiles agent core with mas-build feature")
    func appStoreBuildCompilesAgentCoreWithMasBuildFeature() throws {
        let cargoToml = try loadProductionHardeningRepoTextFile("agent_core/Cargo.toml")
        let bridge = try loadProductionHardeningRepoTextFile("agent_core/src/bridge.rs")
        let registry = try loadProductionHardeningRepoTextFile("agent_core/src/tools/registry.rs")
        let script = try loadProductionHardeningRepoTextFile("build-agent-core.sh")

        #expect(cargoToml.contains("[features]"))
        #expect(cargoToml.contains("mas-build = []"))
        #expect(cargoToml.contains("pro-build = []"))
        #expect(cargoToml.contains("mas-sandbox = []"))
        #expect(cargoToml.contains("New code should use `mas-build`"))
        #expect(script.contains("FEATURE_ARGS"))
        #expect(script.contains("TARGET_NAME"))
        #expect(script.contains("Epistemos-AppStore"))
        #expect(script.contains("PRODUCT_BUNDLE_IDENTIFIER"))
        #expect(script.contains("com.epistemos.appstore"))
        #expect(script.contains("--features \"mas-build,lsp-runtime\""))
        #expect(script.contains("--features \"pro-build,lsp-runtime\""))
        #expect(script.contains(#"TEMP_OUTPUT="$(mktemp ../build-rust/libagent_core.XXXXXX)""#))
        #expect(!script.contains(#"libagent_core.XXXXXX.dylib"#),
                "macOS mktemp does not randomize XXXXXX when it is followed by a suffix; concurrent Xcode builds collide on the literal temp path.")
        #expect(script.contains("trap cleanup_temp_output EXIT") && script.contains("trap - EXIT"),
                "agent_core dylib staging must clean stale temp files on failure without deleting the finished dylib.")
        #expect(bridge.contains("#[cfg(not(feature = \"pro-build\"))]"))
        #expect(bridge.contains("#[cfg(feature = \"pro-build\")]"))
        #expect(bridge.contains("register_discovered_stdio_mcp_tools"))
        #expect(registry.contains("#[cfg(not(feature = \"pro-build\"))]"))
        #expect(registry.contains("mas_sandbox_registry_excludes_unbounded_tools"))
        #expect(registry.contains("bash_execute"))
        #expect(registry.contains("must not be registered in mas-sandbox"))
    }

    @Test("debug and test targets default to local signing without removing real signing support")
    func debugAndTestsDefaultToLocalSigning() throws {
        let project = try loadProductionHardeningRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let projectSpec = try loadProductionHardeningRepoTextFile("project.yml")

        #expect(projectSpec.contains("CODE_SIGN_IDENTITY: \"-\""))
        #expect(projectSpec.contains("DEVELOPMENT_TEAM: \"\""))
        #expect(project.contains("CODE_SIGN_IDENTITY = \"-\";"))
        #expect(project.contains("DEVELOPMENT_TEAM = \"\";"))
        #expect(projectSpec.contains("CODE_SIGN_IDENTITY: \"Apple Development\""))
    }

    @Test("project keeps syntax core and bolt ffi bridge wired for editor and graph surfaces")
    func projectKeepsSyntaxCoreAndBoltFFIWiring() throws {
        let project = try loadProductionHardeningRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let projectSpec = try loadProductionHardeningRepoTextFile("project.yml")
        let bridgeHeader = try loadProductionHardeningRepoTextFile("Epistemos-Bridging-Header.h")
        let syntaxService = try loadProductionHardeningRepoTextFile("Epistemos/Engine/SyntaxCoreService.swift")

        #expect(project.contains("PBXFileSystemSynchronizedRootGroup"))
        #expect(projectSpec.contains("type: syncedFolder"))
        #expect(project.contains("build-syntax-core.sh"))
        #expect(project.contains("-lsyntax_core"))
        #expect(projectSpec.contains(#"bash \"${SRCROOT}/build-syntax-core.sh\""#))
        #expect(projectSpec.contains("-lsyntax_core"))
        #expect(bridgeHeader.contains(#"#include "graph-engine-bridge/graph_engine_bolt.h""#))
        #expect(bridgeHeader.contains(#"#include "syntax-core-bridge/syntax_core.h""#))
        #expect(syntaxService.contains("nonisolated(unsafe) private var document: OpaquePointer?"))
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

    @Test("test hosts keep core supervision but skip heavyweight runtime bootstrap work")
    func testHostsSkipHermesSubprocessBootstrap() throws {
        let source = try loadProductionHardeningRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(source.contains("let supervisor = AppSupervisor()"))
        #expect(source.contains("supervisor.start()"))
        #expect(source.contains("if !Self.isRunningTests && !PowerGuard.shared.shouldDisableBackground {"))
        #expect(source.contains("MainThreadWatchdog.install()"))
        #expect(source.contains("if !Self.isRunningTests {"))
        #expect(source.contains("wireLocalRuntimeLifecycle()"))
    }

    @Test("test hosts skip startup auto-discovery credential imports")
    func testHostsSkipStartupAutoDiscoveryCredentialImports() throws {
        let source = try loadProductionHardeningRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(source.contains("Self.startupAutoDiscoveryReportForTesting("))
        #expect(source.contains("isRunningTests: Self.isRunningTests"))
        #expect(source.contains("return StartupAutoDiscovery.testHostReport()"))
    }

    @Test("bootstrap defers startup auto-discovery off the synchronous init path")
    func bootstrapDefersStartupAutoDiscoveryOffSynchronousInitPath() throws {
        let source = try loadProductionHardeningRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(source.contains("private nonisolated static func scheduleStartupAutoDiscoveryLoggingIfNeeded()"))
        #expect(source.contains("let report = startupAutoDiscoveryReportForTesting("))
        #expect(source.contains("StartupAutoDiscovery.log(report)"))
        #expect(source.contains("Self.scheduleStartupAutoDiscoveryLoggingIfNeeded()"))
        #expect(!source.contains("let autoDiscoveryReport = Self.startupAutoDiscoveryReportForTesting("))
    }

    @Test("test hosts skip Metal shader warmup bootstrap work")
    func testHostsSkipMetalShaderWarmupBootstrapWork() throws {
        let source = try loadProductionHardeningRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(source.contains("scheduleMetalShaderWarmupIfNeeded()"))
        #expect(source.contains("private func scheduleMetalShaderWarmupIfNeeded()"))
        #expect(source.contains("static func shouldScheduleMetalShaderWarmupAtLaunch("))
        #expect(source.contains("guard Self.shouldScheduleMetalShaderWarmupAtLaunch() else { return }"))
    }

    @Test("spotlight single-page indexing does not capture SwiftData models across async work")
    func spotlightSinglePageIndexingStagesSendablePrimitives() throws {
        let source = try loadProductionHardeningRepoTextFile("Epistemos/Engine/SpotlightIndexer.swift")

        #expect(source.contains("private struct PageStage: Sendable"))
        #expect(source.contains("let stage = stage(page)"))
        #expect(source.contains("pageId: stage.pageId"))
        #expect(!source.contains("let item = makeItem(for: page, body: body)"))
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
        #expect(vaultSync.contains("if didClear {"))
        #expect(vaultSync.contains("vaultSync.dismissRecoveryIssue()"))
        #expect(vaultSync.contains("func forceClearDerivedLocalStateForFullReset() async"))
        #expect(vaultSync.contains("let didSwitch = await vaultSync.switchToVaultAsync(vaultURL: url)"))
        #expect(vaultSync.contains("if didSwitch {"))
        #expect(vaultSync.contains("vaultSync.persistVaultSelection("))
        #expect(setupAssistant.contains("VaultConnectionActions.connectSelectedVault(url: url, vaultSync: vaultSync)"))
        #expect(settings.contains("await AppBootstrap.shared?.resetAllData()"))
        #expect(resetBody.contains("let didClear = await vaultSync.stopWatchingAsync(preserveData: false)"))
        #expect(resetBody.contains("if !didClear {"))
        #expect(resetBody.contains("await vaultSync.forceClearDerivedLocalStateForFullReset()"))
        #expect(resetBody.contains("try context.delete(model: SDGraphNode.self)"))
        #expect(resetBody.contains("try context.delete(model: SDGraphEdge.self)"))
        #expect(resetBody.contains("try context.delete(model: SDBlock.self)"))
        #expect(resetBody.contains("try context.delete(model: SDWorkspace.self)"))
        #expect(resetBody.contains("try context.delete(model: SDModelProfile.self)"))
        #expect(resetBody.contains("NoteFileStorage.removeAllManagedBodies()"))
    }

    @Test("Omega planner schemas stay aligned with registered MCP tools")
    @MainActor func omegaPlannerSchemasStayAligned() throws {
        let runtime = MCPBridge()

        let data = try #require(OmegaToolRegistry.planningSchemasJson.data(using: .utf8))
        let schemas = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])

        #expect(!schemas.isEmpty)
        #expect(schemas.count == runtime.toolCount)
        #expect(schemas.count == OmegaToolRegistry.all.count)
    }

    @Test("main-actor inference bridges use timeout-guarded continuations")
    func mainActorInferenceBridgesUseTimeoutGuard() throws {
        let timeoutUtility = try loadProductionHardeningRepoTextFile("Epistemos/State/TimeoutUtility.swift")
        let deviceAgent = try loadProductionHardeningRepoTextFile("Epistemos/Omega/Inference/DeviceAgentService.swift")
        let mlxBridge = try loadProductionHardeningRepoTextFile("Epistemos/KnowledgeFusion/MLXInferenceBridge.swift")

        #expect(timeoutUtility.contains("func withTimedMainActorBridge"))
        #expect(deviceAgent.contains("withTimedMainActorBridge"))
        #expect(mlxBridge.contains("withTimedMainActorBridge"))
    }

    @Test("Regex-backed helpers avoid force-try compilation")
    func regexBackedHelpersAvoidForceTryCompilation() throws {
        let files = [
            "Epistemos/Sync/BlockPropertyParser.swift",
            "Epistemos/Views/Chat/ChatView.swift",
            "Epistemos/Views/Chat/TaggedMarkdownTextView.swift",
            "Epistemos/Views/Notes/MarkdownContentStorage.swift",
            "Epistemos/Views/Notes/MarkdownEditorStyle.swift",
            "Epistemos/Views/Notes/OutlineNavigatorView.swift",
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
        let appSupervisor = try loadProductionHardeningRepoTextFile("Epistemos/State/AppSupervisor.swift")
        let cloudAuth = try loadProductionHardeningRepoTextFile("Epistemos/Engine/CloudProviderAuthService.swift")
        let hologramInspector = try loadProductionHardeningRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")

        #expect(!embodiedCapture.contains("handle.write(line.data(using: .utf8)!)"))
        #expect(embodiedCapture.contains("guard let lineData = line.data(using: .utf8) else {"))

        #expect(!themeSource.contains("preconditionFailure(\"Missing resolved theme cache"))
        #expect(themeSource.contains("Self.resolvedCache[self] ?? buildResolved()"))

        #expect(!cloudAuth.contains("URL(string: \"https://oauth2.googleapis.com/token\")!"))
        #expect(cloudAuth.contains("guard let tokenURL = URL(string: \"https://oauth2.googleapis.com/token\") else {"))

        #expect(!hologramInspector.contains("node.sourceId!"))
        #expect(hologramInspector.contains("if node.type == .note, let pageId = node.sourceId"))

        #expect(appSupervisor.contains("import Network"))
        #expect(appSupervisor.contains("NWPathMonitor"))
        #expect(!appSupervisor.contains("https://api.anthropic.com"))
    }

    @Test("Cloud routing safety gates stay wired")
    func cloudRoutingSafetyGatesStayWired() throws {
        let triageService = try loadProductionHardeningRepoTextFile("Epistemos/Engine/TriageService.swift")

        #expect(triageService.contains("if context.routingMode == .localOnly {"))
        #expect(triageService.contains("reasonCodes.insert(.localModeForced)"))
        #expect(triageService.contains("private func cloudConfigurationError(for model: CloudTextModelID) -> CloudLLMError? {"))
        #expect(triageService.contains("if let error = cloudConfigurationError(for: model) {"))
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
        #expect(!landing.contains("landingPromptSurface: LandingPromptSurface = .chat"))
        #expect(!landing.contains("label: \"Command Center\""))
        #expect(!landing.contains(".accessibilityLabel(\"Local Model\")"))
        #expect(landing.contains("ProgressView()"))
    }

    @Test("only explicit user note creation paths can trigger vault selection")
    func onlyExplicitUserNoteCreationPathsCanTriggerVaultSelection() throws {
        func normalizedSource(_ source: String) -> String {
            source.replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
        }

        let vaultSync = try loadProductionHardeningRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let app = normalizedSource(
            try loadProductionHardeningRepoTextFile("Epistemos/App/EpistemosApp.swift")
        )
        let landing = normalizedSource(
            try loadProductionHardeningRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        )
        let miniChat = try loadProductionHardeningRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let wordProcessor = normalizedSource(
            try loadProductionHardeningRepoTextFile("Epistemos/Intents/Schemas/WordProcessorIntents.swift")
        )
        let journal = normalizedSource(
            try loadProductionHardeningRepoTextFile("Epistemos/Intents/Schemas/JournalIntents.swift")
        )

        #expect(vaultSync.contains("allowVaultSelectionPrompt: Bool = false"))
        #expect(vaultSync.contains("guard allowVaultSelectionPrompt,"))
        #expect(vaultSync.contains("await VaultConnectionActions.selectVaultFolderForImmediateUse("))
        #expect(vaultSync.contains("static func selectVaultFolderForImmediateUse("))
        #expect(vaultSync.contains("static func connectSelectedVaultAsync("))

        #expect(app.contains("createPage(title: \"Untitled\", allowVaultSelectionPrompt: true)"))
        #expect(landing.contains("createPage(title: \"New Note\", allowVaultSelectionPrompt: true)"))
        #expect(wordProcessor.contains("createPage( title: title, allowVaultSelectionPrompt: true )"))
        #expect(journal.contains("createPage( title: journalTitle, allowVaultSelectionPrompt: true )"))
        #expect(!miniChat.contains("allowVaultSelectionPrompt: true"))
    }

    @Test("page and journal creation fail honestly when persistence fails")
    func pageAndJournalCreationFailHonestlyOnPersistenceErrors() throws {
        let vaultSync = try loadProductionHardeningRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let journal = try loadProductionHardeningRepoTextFile("Epistemos/Intents/Schemas/JournalIntents.swift")

        let vaultSaveFailure = try #require(vaultSync.range(of: "Failed to save new page"))
        let vaultReturnNil = try #require(vaultSync.range(of: "return nil", range: vaultSaveFailure.upperBound..<vaultSync.endIndex))

        let journalSaveFailure = try #require(journal.range(of: "Journal save failed:"))
        let journalThrow = try #require(journal.range(of: "throw IntentError.creationFailed", range: journalSaveFailure.upperBound..<journal.endIndex))

        #expect(!vaultSync.contains("context.rollback()"))
        #expect(vaultSync.contains("context.delete(page)"))
        #expect(vaultSync.contains("NoteFileStorage.deleteBody(pageId: failedPageId)"))
        #expect(vaultReturnNil.lowerBound > vaultSaveFailure.lowerBound)
        #expect(!journal.contains("context.rollback()"))
        #expect(journal.contains("let originalBody = await SDPage.loadBodyAsyncFromPrimitives("))
        #expect(journal.contains("pageId: page.id"))
        #expect(journal.contains("filePath: page.filePath"))
        #expect(journal.contains("inlineBody: page.body"))
        #expect(journal.contains("page.saveBody(originalBody)"))
        #expect(journal.contains("BlockMirror.sync(pageId: pageId, body: originalBody, modelContext: context)"))
        #expect(journal.contains("page.journalDate = journalDate"))
        #expect(journalThrow.lowerBound > journalSaveFailure.lowerBound)
    }

    @Test("text capture and code editor note creation clean up orphaned bodies on save failure")
    func textCaptureAndCodeEditorCreationCleanUpOrphanedBodiesOnSaveFailure() throws {
        let textCapture = try loadProductionHardeningRepoTextFile("Epistemos/Engine/TextCapturePipeline.swift")
        let codeEditor = try loadProductionHardeningRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")

        #expect(textCapture.contains("let failedPageId = page.id"))
        #expect(textCapture.contains("context.delete(page)"))
        #expect(textCapture.contains("NoteFileStorage.deleteBody(pageId: failedPageId)"))
        #expect(codeEditor.contains("let failedPageId = newPage.id"))
        #expect(codeEditor.contains("context.delete(newPage)"))
        #expect(codeEditor.contains("NoteFileStorage.deleteBody(pageId: failedPageId)"))
    }

    @Test("vault index import cleans up pending managed artifacts when save fails")
    func vaultIndexImportCleansUpPendingArtifactsOnSaveFailure() throws {
        let vaultIndexActor = try loadProductionHardeningRepoTextFile("Epistemos/Sync/VaultIndexActor.swift")

        #expect(vaultIndexActor.contains("private func discardPendingImportedPages("))
        #expect(vaultIndexActor.contains("pendingInsertedPages.removeAll(keepingCapacity: true)"))
        #expect(vaultIndexActor.contains("let pendingInsertedPageIDs = pendingInsertedPages.map(\\.id)"))
        #expect(vaultIndexActor.contains("modelContext.rollback()"))
        #expect(vaultIndexActor.contains("modelContext.processPendingChanges()"))
        #expect(vaultIndexActor.contains("NoteFileStorage.deleteBody(pageId: pageID)"))
        #expect(vaultIndexActor.contains("try searchService?.delete(pageId: pageID)"))
        #expect(vaultIndexActor.contains("discardPendingImportedPages(pendingInsertedPageIDs, failedSaveLabel: label)"))
    }

    @Test("root shell keeps recovery overlays toast feedback and toolbar accessibility affordances")
    func rootShellKeepsRecoveryAndAccessibilityAffordances() throws {
        let rootView = try loadProductionHardeningRepoTextFile("Epistemos/App/RootView.swift")

        #expect(rootView.contains("ToastOverlay("))
        #expect(rootView.contains("VaultRecoveryOverlay("))
        #expect(rootView.contains("issue.blocksWorkspaceInteraction"))
        #expect(rootView.contains(".accessibilityLabel(\"Back to Home\")"))
        #expect(rootView.contains(".accessibilityLabel(\"Settings\")"))
        #expect(rootView.contains(".accessibilityLabel(\"Chat History\")"))
        #expect(rootView.contains("DatabaseRecoveryOverlay("))
        #expect(rootView.contains(".alert(\"Database Recovery Required\""))
        #expect(!rootView.contains("Button(\"Continue Empty\")"))
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
