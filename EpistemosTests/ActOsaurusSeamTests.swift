import Testing
import Foundation
@testable import Epistemos

/// Osaurus P3.0 Act import — Seam A / S2 guard. Locks the smallest real vendored
/// seam: ProvenanceGate (MIT direct_import), the MAS/Pro boundary (vendored Osaurus
/// + the runtime bridge are Pro-only; the gate + row are always-compiled), and the
/// honest INERT posture (no fake runtime).
@Suite("Osaurus Act seam (P3.0 S2) — vendored, Pro-gated, boundary intact")
struct ActOsaurusSeamTests {

    @Test("gate flag is honest + visible status matches current build route")
    func gateHonest() {
        #expect(ActOsaurusGateStatus.flagName == "EPISTEMOS_ACT_OSAURUS_V0")
        #expect(ActOsaurusGateStatus.isEnabled("1"))
        #expect(ActOsaurusGateStatus.isEnabled(" On "))
        #expect(!ActOsaurusGateStatus.isEnabled(nil))
        #expect(!ActOsaurusGateStatus.isEnabled("0"))
        // Hermetic: read the default (no-override, no-env) status from a CLEAN defaults suite so the
        // host app's PERSISTED `.standard` in-app toggle (set during a real app run) can't pollute
        // this default-state check. The other tests in this file already isolate via a temp suite.
        let suite = "test.act.osaurus.gatehonest.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let status = ActOsaurusGateStatus.status(environment: [:], defaults: defaults)
        #if EPISTEMOS_APP_STORE
        #expect(!status.isActive)
        #expect(status.headline.contains("Pro only"))
        #else
        #expect(status.isActive)
        #expect(status.detail.contains("default Pro route"))
        #endif
    }

    #if !EPISTEMOS_APP_STORE
    @Test("legacy override resolver remains isolated from the default-on router")
    func actOverrideResolutionOrder() {
        let suite = "test.act.osaurus.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let on = [ActOsaurusGateStatus.flagName: "1"]
        #expect(!ActOsaurusGateStatus.resolvedActive(environment: [:], defaults: defaults))
        #expect(ActOsaurusGateStatus.resolvedActive(environment: on, defaults: defaults))
        ActOsaurusGateStatus.setOverride(true, defaults: defaults)
        #expect(ActOsaurusGateStatus.override(defaults: defaults) == true)
        #expect(ActOsaurusGateStatus.resolvedActive(environment: [:], defaults: defaults))
        ActOsaurusGateStatus.setOverride(false, defaults: defaults)
        #expect(!ActOsaurusGateStatus.resolvedActive(environment: on, defaults: defaults))
        ActOsaurusGateStatus.setOverride(nil, defaults: defaults)
        #expect(ActOsaurusGateStatus.override(defaults: defaults) == nil)
        #expect(ActOsaurusGateStatus.resolvedActive(environment: on, defaults: defaults))
        #expect(LocalAgentLoop.shouldRouteActThroughOsaurus(environment: [:]))
    }

    @Test("visible status follows the router, not the retired opt-in toggle")
    func actOverrideStatusReflectsSource() {
        let suite = "test.act.osaurus.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        ActOsaurusGateStatus.setOverride(true, defaults: defaults)
        let on = ActOsaurusGateStatus.status(environment: [:], defaults: defaults)
        #expect(on.isActive)
        #expect(on.detail.contains("legacy in-app override"))

        ActOsaurusGateStatus.setOverride(false, defaults: defaults)
        let off = ActOsaurusGateStatus.status(environment: [ActOsaurusGateStatus.flagName: "1"], defaults: defaults)
        #expect(off.isActive)
        #expect(off.detail.contains("default Pro route"))
    }

    @Test("the router is DEFAULT-ON for Pro: act routes through Osaurus, no toggle")
    func routerDefaultsOnForPro() {
        // Owner 2026-06-22 evening correction: Pro act enters Osaurus by default,
        // with Epistemos home/theme grafts. The router returns true regardless of
        // env flags or prior in-app overrides; Osaurus is not optional on Pro act.
        #expect(LocalAgentLoop.shouldRouteActThroughOsaurus(environment: [:]))
        #expect(LocalAgentLoop.shouldRouteActThroughOsaurus(environment: [ActOsaurusGateStatus.flagName: "0"]))
    }
    #endif

    @Test("ProvenanceGate: vendored Osaurus carries MIT direct_import provenance")
    func provenancePresent() throws {
        let prov = try loadMirroredSourceTextFile("Epistemos/Vendor/Osaurus/OsaurusVendorProvenance.swift")
        #expect(prov.contains("MIT License"))
        #expect(prov.contains("osaurus-ai/osaurus"))
        #expect(prov.contains("direct_import"))
        #expect(prov.contains("Copyright (c) 2026 Osaurus, Inc."))
    }

    @Test("MAS/Pro boundary: vendored Osaurus + the runtime bridge are Pro-gated")
    func boundaryIntact() throws {
        // The vendored Osaurus source never compiles into the MAS build.
        let serverHealth = try loadMirroredSourceTextFile("Epistemos/Vendor/Osaurus/ServerHealth.swift")
        #expect(serverHealth.contains("#if !EPISTEMOS_APP_STORE"))
        #expect(serverHealth.contains("osaurus-ai/osaurus"))     // provenance header
        #expect(serverHealth.contains("VERBATIM"))               // verbatim markers
        // The bridge (drives the Osaurus runtime) is Pro-gated + honestly inert.
        let bridge = try loadMirroredSourceTextFile("Epistemos/ActOsaurus/ActOsaurusBridge.swift")
        #expect(bridge.contains("#if !EPISTEMOS_APP_STORE"))
        #expect(bridge.contains("protocol ActOsaurusBridge"))
        #expect(bridge.contains("var isLive: Bool { false }"))   // never fakes a runtime
    }

    @Test("the gate status + health row are ALWAYS-compiled (MAS can show the honest state)")
    func gateAndRowAlwaysCompiled() throws {
        let gate = try loadMirroredSourceTextFile("Epistemos/ActOsaurus/ActOsaurusGateStatus.swift")
        #expect(gate.contains("nonisolated enum ActOsaurusGateStatus"))
        // The enum itself is NOT wrapped in the Pro-only boundary (so MAS compiles it).
        #expect(!gate.contains("#if !EPISTEMOS_APP_STORE\nnonisolated enum ActOsaurusGateStatus"))
        let row = try loadMirroredSourceTextFile("Epistemos/Views/Settings/ActOsaurusHealthRow.swift")
        #expect(row.contains("struct ActOsaurusHealthRow: View"))
        #expect(row.contains("ActOsaurusGateStatus.status()"))
        // Mounted in the visible substrate health panel.
        let panel = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SubstrateHealthPanel.swift")
        #expect(panel.contains("ActOsaurusHealthRow()"))
    }

    @Test("S3: the bridge publishes the REAL osaurus-pattern endpoint, honestly gated")
    func s3EndpointWiring() throws {
        let bridge = try loadMirroredSourceTextFile("Epistemos/ActOsaurus/ActOsaurusBridge.swift")
        // The real conformer reflects the actual local server (no overclaim).
        #expect(bridge.contains("var localServerEnabled: Bool { LocalModelServer.isEnabled }"))
        #expect(bridge.contains("guard LocalModelServer.isEnabled else { return nil }"))
        #expect(bridge.contains("/v1/chat/completions"))
        #expect(bridge.contains("LocalModelServer.defaultPort"))
        // A second vendored MIT Osaurus seam (adapter_wrap, namespaced for collision).
        let chat = try loadMirroredSourceTextFile("Epistemos/Vendor/Osaurus/OsaurusChatMessage.swift")
        #expect(chat.contains("#if !EPISTEMOS_APP_STORE"))
        #expect(chat.contains("enum OsaurusVendor"))
        #expect(chat.contains("osaurus-ai/osaurus"))
        #expect(chat.contains("adapter_wrap"))
        // The canonical port is exposed (always-compiled) for the bridge.
        let server = try loadMirroredSourceTextFile("Epistemos/Engine/LocalModelServer.swift")
        #expect(server.contains("static let defaultPort: UInt16 = 1337"))
    }

    @Test("S4: runTurn POSTs to the endpoint and throws honest errors — never a cloud fallback")
    func s4RunTurnHonest() throws {
        let bridge = try loadMirroredSourceTextFile("Epistemos/ActOsaurus/ActOsaurusBridge.swift")
        #expect(bridge.contains("func runTurn(model: String, messages: [OsaurusVendor.Message], maxTokens: Int) async throws -> String"))
        #expect(bridge.contains("URLSession.shared.data(for: request)"))
        // Every failure path is an HONEST throw — no silent cloud/GPT escalation.
        #expect(bridge.contains("throw ActOsaurusError.serverNotEnabled"))
        #expect(bridge.contains("ActOsaurusError.transport"))
        #expect(bridge.contains("ActOsaurusError.requestFailed"))
        #expect(bridge.contains("/v1/chat/completions"))
    }

    @Test("S4: act turn runs IN-PROCESS through OsaurusCore CoreModelService — never a cloud fallback")
    func s4InProcessThroughOsaurusCore() throws {
        let bridge = try loadMirroredSourceTextFile("Epistemos/ActOsaurus/ActOsaurusBridge.swift")
        // Drives the REAL linked engine in-process, not the loopback server.
        #expect(bridge.contains("func runTurnInProcess(messages: [OsaurusVendor.Message], maxTokens: Int) async throws -> String"))
        #expect(bridge.contains("OsaurusCore.CoreModelService.shared.generate("))
        // Honest failure: OsaurusCore's own error surfaced; NEVER a silent cloud/GPT route.
        #expect(bridge.contains("OsaurusCore generate failed"))
        #expect(bridge.contains("throw ActOsaurusError.serverNotEnabled"))
    }

    @Test("S4: act health surface shows REAL OsaurusCore engine status (resolveStatus, not a stub)")
    func s4RealOsaurusCoreStatusSurface() throws {
        let bridge = try loadMirroredSourceTextFile("Epistemos/ActOsaurus/ActOsaurusBridge.swift")
        #expect(bridge.contains("func osaurusCoreStatusDescription() async -> String?"))
        #expect(bridge.contains("OsaurusCore.CoreModelService.shared.resolveStatus()"))
        // The visible act health row consumes the REAL engine status (wired to a real front-end).
        let row = try loadMirroredSourceTextFile("Epistemos/Views/Settings/ActOsaurusHealthRow.swift")
        #expect(row.contains("osaurusCoreStatusDescription()"))
    }

    @Test("S4: act dispatch flag-swaps the LocalAgentLoop generator to OsaurusCore (default unchanged)")
    func s4DeviceAgentFlagSwap() throws {
        let svc = try loadMirroredSourceTextFile("Epistemos/Omega/Inference/DeviceAgentService.swift")
        // Flag ON → the act generation closure drives OsaurusCore (the live generation-closure swap).
        #expect(svc.contains("ActOsaurusGenerationHandler.make()"))
        // The flag read is now the SHARED decision `LocalAgentLoop.shouldRouteActThroughOsaurus()`
        // (refactored 2026-06-21 so DeviceAgentService + liveLoop can't diverge — see SharedActComposerTests).
        #expect(svc.contains("LocalAgentLoop.shouldRouteActThroughOsaurus()"))
        // Flag OFF (default) keeps the proven MLX one-shot generator — no silent behavior change.
        #expect(svc.contains("LocalAgentLoop.mlxOneShotGenerator(using: localModelClient)"))
    }

    #if !EPISTEMOS_APP_STORE
    @Test("S3: the INERT bridge stays honest — no endpoint, server not enabled, message round-trips")
    func s3InertBridgeHonest() {
        let inert = InertActOsaurusBridge()
        #expect(inert.openAICompatibleEndpoint == nil)
        #expect(!inert.localServerEnabled)
        #expect(!inert.isLive)
        let msg = inert.makeRequestMessage(role: .user, content: "hello")
        #expect(msg.role == .user)
        #expect(msg.content == "hello")
    }

    @Test("S4: a turn with no running server throws an HONEST error, never a silent cloud route")
    func s4HonestErrorNoServer() async {
        // The inert bridge owns no server → it refuses honestly (owner #1: Act never
        // silently falls back to a cloud/GPT route).
        do {
            _ = try await InertActOsaurusBridge().runTurn(model: "qwen", messages: [], maxTokens: 16)
            Issue.record("expected serverNotEnabled — Act must never silently route to cloud")
        } catch let error as ActOsaurusError {
            #expect(error == .serverNotEnabled)
        } catch {
            Issue.record("wrong error type: \(error)")
        }
    }

    @Test("S4: the real bridge drives the LINKED OsaurusCore in-process (real providers, not the inert stub)")
    func s4OsaurusCoreDrivenInProcess() {
        let bridge = OsaurusActBridge()
        #if canImport(OsaurusCore)
        // OsaurusCore is linked into this (non-AppStore) build → the real bridge reads REAL
        // engine data straight from OsaurusCore.RemoteProviderType (not the inert stub).
        #expect(bridge.isOsaurusCoreLinked)
        #expect(!bridge.osaurusCoreRemoteProviders.isEmpty)
        #else
        #expect(!bridge.isOsaurusCoreLinked)
        #expect(bridge.osaurusCoreRemoteProviders.isEmpty)
        #endif
    }

    @Test("S4: act generation-closure swap drives OsaurusCore via the bridge; flag-off throws HONESTLY")
    func actGenerationClosureHonest() async {
        // The closure LocalAgentLoop runs for act — with the inert bridge it must throw honestly,
        // never a silent cloud route (owner #1). This is the 'generation-closure swap' seam.
        let handler = ActOsaurusGenerationHandler.make(bridge: InertActOsaurusBridge())
        do {
            _ = try await handler("hello", nil, 16, .fast, nil) { _ in }
            Issue.record("expected an honest throw — act must never silently route to cloud")
        } catch let error as ActOsaurusError {
            #expect(error == .serverNotEnabled)
        } catch {
            Issue.record("wrong error type: \(error)")
        }
    }

    @Test("S4: factory-resolved act bridge follows the shared Act route — no split unavailable state")
    func s4FactoryFollowsSharedActRoute() throws {
        // Regression guard: Act's UI route is default-on in Pro, so the bridge factory must use
        // the same shared decision. Using the old raw Osaurus flag here produced an Osaurus-looking
        // chat whose send path still threw "engine isn't available".
        let source = try loadMirroredSourceTextFile("Epistemos/ActOsaurus/ActOsaurusBridge.swift")
        #expect(source.contains("LocalAgentLoop.shouldRouteActThroughOsaurus(environment: environment)"))
        #expect(!source.contains("ActOsaurusGateStatus.isEnabled(environment[ActOsaurusGateStatus.flagName])"))
    }

    @Test("ActOsaurusError surfaces a friendly, actionable message — never a raw 'error 2' code (P0-A)")
    func actOsaurusErrorIsDiagnosable() {
        // Owner 2026-06-22 saw the raw "Epistemos.ActOsaurusError error 2" on a real send.
        // LocalizedError gives every case a friendly, actionable message instead of a bare code.
        let requestFailed = ActOsaurusError.requestFailed(status: 500)
        #expect(requestFailed.errorDescription?.isEmpty == false)
        #expect(requestFailed.errorDescription?.contains("500") == true)
        // The chat-facing message (the one the owner actually sees) is the friendly text, not the code.
        let surfaced = UserFacingChatError.message(from: requestFailed)
        #expect(surfaced.localizedCaseInsensitiveContains("retry"))
        #expect(surfaced.localizedCaseInsensitiveContains("model"))
        #expect(surfaced.contains("error 2") == false)
        // Every case is described (no raw codes anywhere on the act error surface).
        for err in [ActOsaurusError.serverNotEnabled, .transport("boom"), .emptyResponse] {
            #expect(err.errorDescription?.isEmpty == false)
        }
    }
    #endif
}
