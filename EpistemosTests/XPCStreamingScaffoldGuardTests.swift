import Testing
import Foundation
@testable import Epistemos

/// RCA-P1-018 verdict-pin guard for V2.4 XPC streaming.
///
/// **Verdict** (per `Epistemos/XPC/ProviderServiceStreamingProtocol.swift`
/// + `docs/V2_4_AND_V3_2_DESIGN_2026_05_05.md` + the audit register):
///
///   1. The production live `ProviderXPC` service ships ONE method:
///      `classifySurface(_:withReply:)`. The streaming protocol
///      surface (`ProviderServiceStreamingProtocol`) is scaffold only;
///      no production code instantiates it or its mock. The actual
///      XPC service launch + entitlement provisioning is V2.4
///      production work that requires paid Apple Developer Program
///      signing.
///   2. The mock implementation `MockProviderServiceStreaming` exists
///      so tests can validate the protocol's two-stage handshake
///      contract; production code paths must not instantiate it.
///   3. The audit acceptance criterion ("Production streaming is
///      complete, or the feature is hidden/gated/labeled as scaffold")
///      is met today via the explicit doctrine note + the gap between
///      protocol declaration and production caller.
///
/// This suite pins all three invariants programmatically. If a future
/// commit wires `MockProviderServiceStreaming(...)` into a production
/// editor / chat / settings path before resolving the V2.4
/// service-launch and entitlement work, the gate fires.
///
/// Lift conditions:
///   a) Ship the real V2.4 XPC service launch + entitlements (paid
///      Apple Developer Program), wire production callers to it,
///      then update this gate to assert the production wiring exists.
///   b) Delete the scaffold (`ProviderServiceStreamingProtocol` +
///      `MockProviderServiceStreaming`) if the V2.4 design is
///      abandoned.
///
/// Doctrine §7 lane: XPC track — provider streaming drift gate.
@Suite("RCA-P1-018 XPC Streaming Scaffold Guard")
struct XPCStreamingScaffoldGuardTests {

    /// Production editor / chat / provider files that MUST NOT
    /// instantiate the V2.4 streaming mock or the live streaming
    /// protocol. If any of these grows a `MockProviderServiceStreaming(`
    /// or `ProviderServiceStreamingProtocol` reference, the gate
    /// fires and demands the V2.4 acceptance criteria be revisited
    /// before the wiring lands.
    private static let candidateProductionFiles = [
        "Epistemos/Engine/PipelineService.swift",
        "Epistemos/App/ChatCoordinator.swift",
        "Epistemos/Engine/AnswerPacketEmitter.swift",
        "Epistemos/Bridge/StreamingDelegate.swift",
    ]

    @Test("ProviderServiceStreamingProtocol retains the SCAFFOLD ONLY doctrine note")
    func streamingProtocolRetainsScaffoldDoctrine() throws {
        // If a future refactor drops the explicit SCAFFOLD ONLY
        // header, the protocol's gap becomes invisible. Pin the
        // note so renaming / restructuring surfaces in code review.
        let source = try loadMirroredSourceTextFile(
            "Epistemos/XPC/ProviderServiceStreamingProtocol.swift"
        )
        #expect(source.contains("SCAFFOLD ONLY"),
            "ProviderServiceStreamingProtocol must retain its SCAFFOLD ONLY header documenting the V2.4 production gap")
        #expect(source.contains("RCA13 P1-018") || source.contains("RCA-P1-018"),
            "ProviderServiceStreamingProtocol must cross-reference the RCA-P1-018 verdict")
        #expect(source.contains("NO production caller"),
            "ProviderServiceStreamingProtocol must retain the explicit no-production-caller acknowledgement")
    }

    @Test("Production code does not instantiate MockProviderServiceStreaming")
    func mockIsNotInstantiatedInProduction() throws {
        for relativePath in Self.candidateProductionFiles {
            let source = try loadMirroredSourceTextFile(relativePath)
            #expect(!source.contains("MockProviderServiceStreaming("),
                "\(relativePath) must not instantiate MockProviderServiceStreaming — see RCA-P1-018; the V2.4 production XPC service is still doctrine-only and must land before mocks cross into production code paths")
        }
    }

    @Test("Walking Epistemos/* confirms no production constructor of the streaming mock")
    func walkProductionTreeForMockConstructor() throws {
        // Exempt the protocol declaration file (which mentions the
        // mock by name in its doctrine comment but doesn't construct
        // it). All other `.swift` files under Epistemos/ must NOT
        // construct `MockProviderServiceStreaming(`.
        let productionRoot = try sourceMirrorURL(for: "Epistemos")
        let enumerator = FileManager.default.enumerator(
            at: productionRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        let exemptPaths: Set<String> = [
            "Epistemos/XPC/MockProviderServiceStreaming.swift",
        ]

        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let absolute = url.standardizedFileURL.path
            guard let range = absolute.range(of: "/Epistemos/") else { continue }
            let relativeWithLeadingSlash = String(absolute[range.lowerBound...])
            let relative = String(relativeWithLeadingSlash.dropFirst())
            if exemptPaths.contains(relative) { continue }

            let source: String
            do {
                source = try String(contentsOf: url, encoding: .utf8)
            } catch {
                continue
            }
            #expect(!source.contains("MockProviderServiceStreaming("),
                "\(relative) constructor-invokes MockProviderServiceStreaming — see RCA-P1-018 for the lift conditions before wiring streaming mocks into production")
        }
    }

    @Test("ProviderServiceProtocol surface remains narrow (classifySurface only)")
    func providerServiceProtocolStaysNarrow() throws {
        // Pin the live XPC service's narrow Swift-side surface:
        // `ProviderServiceProtocol` declares exactly one method,
        // `classifySurface(_:withReply:)`. If a future commit adds a
        // streaming-related method to the protocol without first
        // landing the V2.4 XPC service launch + entitlements, the
        // gate fires.
        //
        // We pin the protocol surface (in Epistemos/XPC/) rather than
        // the service implementation (in XPCServices/ProviderXPC/)
        // because the source mirror covers `Epistemos/**` reliably;
        // the XPCServices/ tree lives outside the mirror and resolving
        // its path from the test runtime is brittle. The protocol is
        // the actual contract — implementations must conform to it,
        // so locking the protocol locks the surface.
        let source = try loadMirroredSourceTextFile(
            "Epistemos/XPC/AgentServiceProtocol.swift"
        )
        #expect(source.contains("func classifySurface"),
            "ProviderServiceProtocol must keep `classifySurface` as the canonical entry point")
        // Negative pin: the protocol must NOT gain streaming method
        // signatures. The pattern catches both Codable-payload
        // streaming and chunk-based streaming.
        let forbiddenStreamingSignatures = [
            "func openStreamingSession",
            "func writeStreamChunk",
            "func consumeStreamRing",
        ]
        for signature in forbiddenStreamingSignatures {
            #expect(!source.contains(signature),
                "ProviderServiceProtocol must not gain `\(signature)` until V2.4 XPC service launch + entitlements land — see RCA-P1-018")
        }
    }
}
