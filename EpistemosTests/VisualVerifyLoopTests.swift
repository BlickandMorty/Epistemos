import Foundation
import Testing
@testable import Epistemos

@Suite("Visual Verify Loop")
struct VisualVerifyLoopTests {
    @MainActor
    @Test("verify uses screenshot fallback when AX diff is inconclusive")
    func verifyUsesScreenshotFallbackWhenAXDiffIsInconclusive() async throws {
        let axStates = StringSequence(values: [
            #"{"elements":[]}"#,
            #"{"elements":[]}"#,
        ])
        let fingerprints = UInt64Sequence(values: [11, 22])
        let loop = VisualVerifyLoop(
            screenCapture: ScreenCaptureService(),
            axStateProvider: { _ in await axStates.next() ?? "{}" },
            screenshotFingerprintProvider: { _ in await fingerprints.next() },
            semanticVerifier: nil
        )

        let token = await loop.captureBeforeState(appBundleID: "com.example.app")
        #expect(token != nil)

        let result = await loop.verify(
            token: try #require(token),
            expectedOutcome: "Button opens a sheet.",
            appBundleID: "com.example.app"
        )

        #expect(result.method == "AX+screenshot-diff")
        #expect(result.confidence == 0.6)
        #expect(result.stateChanged)
        #expect(loop.successRate == 0.0)
    }

    @MainActor
    @Test("verify prefers semantic verification when Brain 2 succeeds")
    func verifyPrefersSemanticVerificationWhenBrain2Succeeds() async throws {
        let axStates = StringSequence(values: [
            #"{"elements":[{"role":"AXButton"}]}"#,
            #"{"elements":[{"role":"AXButton"},{"role":"AXSheet"}]}"#,
        ])
        let fingerprints = UInt64Sequence(values: [40, 41])
        let loop = VisualVerifyLoop(
            screenCapture: ScreenCaptureService(),
            axStateProvider: { _ in await axStates.next() ?? "{}" },
            screenshotFingerprintProvider: { _ in await fingerprints.next() },
            semanticVerifier: { _, _, _ in
                VisualVerifyLoop.SemanticVerification(
                    confidence: 0.93,
                    method: "Brain2-SharedGPU"
                )
            }
        )

        let token = await loop.captureBeforeState(appBundleID: "com.example.app")
        let result = await loop.verify(
            token: try #require(token),
            expectedOutcome: "Sheet becomes visible.",
            appBundleID: "com.example.app"
        )

        #expect(result.method == "Brain2-SharedGPU")
        #expect(result.confidence == 0.93)
        #expect(result.passed)
        #expect(loop.successRate == 1.0)
    }

    @Test("Omega vision diagnostics redact external errors")
    func omegaVisionDiagnosticsRedactExternalErrors() throws {
        let message = OmegaVisionDiagnostics.externalLogMessage(
            "Vision OCR failed",
            error: NSError(
                domain: "/Users/jojo/PrivateVault/vision.swift",
                code: -77,
                userInfo: [
                    NSLocalizedDescriptionKey: "Vision failed for /Users/jojo/PrivateVault/screenshot.png"
                ]
            )
        )

        #expect(message.contains("Vision OCR failed"))
        #expect(message.contains("code=-77"))
        #expect(message.count <= OmegaVisionDiagnostics.maxLogMessageCharacters)
        for forbidden in [
            "/Users/jojo",
            "PrivateVault",
            "vision.swift",
            "screenshot.png",
        ] {
            #expect(!message.contains(forbidden))
        }

        let source = try loadMirroredSourceTextFile("Epistemos/Omega/Vision/OmegaVisionDiagnostics.swift")
        #expect(source.contains("String(message.prefix(maxLogMessageCharacters + 32))"))
        #expect(source.contains("String(domain.prefix(maxDomainCharacters + 32))"))
    }

    @Test("Omega vision sources do not log raw external errors")
    func omegaVisionSourcesDoNotLogRawExternalErrors() throws {
        for path in [
            "Epistemos/Omega/Vision/ScreenCaptureService.swift",
            "Epistemos/Omega/Vision/Screen2AXFusion.swift",
            "Epistemos/Omega/Vision/VisualVerifyLoop.swift",
        ] {
            let source = try loadMirroredSourceTextFile(path)

            #expect(source.contains("OmegaVisionDiagnostics.externalLogMessage"))
            #expect(!source.contains("error.localizedDescription"))
            #expect(!source.contains("String(describing: error)"))
        }
    }
}

private actor StringSequence {
    private var values: [String]

    init(values: [String]) {
        self.values = values
    }

    func next() -> String? {
        guard !values.isEmpty else { return nil }
        return values.removeFirst()
    }
}

private actor UInt64Sequence {
    private var values: [UInt64]

    init(values: [UInt64]) {
        self.values = values
    }

    func next() -> UInt64? {
        guard !values.isEmpty else { return nil }
        return values.removeFirst()
    }
}
