import Testing
import Foundation
@testable import Epistemos

/// Osaurus P3.0 Act import — Seam A / S2 guard. Locks the smallest real vendored
/// seam: ProvenanceGate (MIT direct_import), the MAS/Pro boundary (vendored Osaurus
/// + the runtime bridge are Pro-only; the gate + row are always-compiled), and the
/// honest INERT posture (no fake runtime).
@Suite("Osaurus Act seam (P3.0 S2) — vendored, Pro-gated, boundary intact")
struct ActOsaurusSeamTests {

    @Test("gate flag is honest + off by default")
    func gateHonest() {
        #expect(ActOsaurusGateStatus.flagName == "EPISTEMOS_ACT_OSAURUS_V0")
        #expect(ActOsaurusGateStatus.isEnabled("1"))
        #expect(ActOsaurusGateStatus.isEnabled(" On "))
        #expect(!ActOsaurusGateStatus.isEnabled(nil))
        #expect(!ActOsaurusGateStatus.isEnabled("0"))
        let off = ActOsaurusGateStatus.status(environment: [:])
        #expect(!off.isActive)
        // Honest copy either names the flag (Pro build) or says "Pro only" (MAS).
        #expect(off.detail.contains("EPISTEMOS_ACT_OSAURUS_V0") || off.headline.contains("Pro only"))
    }

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

    @Test("S4: factory-resolved act bridge runTurnInProcess refuses HONESTLY by default — never cloud")
    func s4FactoryRunTurnInProcessHonest() async {
        // Flag off → the inert bridge is resolved; an OsaurusCore turn must throw honestly,
        // never a silent cloud/GPT route (owner #1). This is the canonical act-turn API.
        let bridge = ActOsaurusBridgeFactory.resolve(environment: [:])
        do {
            _ = try await bridge.runTurnInProcess(messages: [], maxTokens: 16)
            Issue.record("expected an honest throw — act must never silently route to cloud")
        } catch let error as ActOsaurusError {
            #expect(error == .serverNotEnabled)
        } catch {
            Issue.record("wrong error type: \(error)")
        }
    }
    #endif
}
