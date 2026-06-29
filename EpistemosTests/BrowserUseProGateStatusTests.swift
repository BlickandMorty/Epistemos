import Foundation
import Testing

@testable import Epistemos

@Suite("Plan 3 browser-use Pro gate")
struct BrowserUseProGateStatusTests {
    @Test("vendor manifest loads pinned full-clone source state")
    func vendorManifestLoadsPinnedFullCloneSourceState() throws {
        let manifestURL = try sourceMirrorURL(for: "agent_core/vendor/browser-use/VENDOR_MANIFEST.json")
        let manifest = try BrowserUseVendorManifest.load(from: manifestURL)

        #expect(manifest.schemaVersion == 1)
        #expect(manifest.name == "plan3-browser-use-pro")
        #expect(manifest.runtimeLane == "pro-developer-id-only")
        #expect(!manifest.masSafe)
        #expect(manifest.components.count == 3)
        #expect(manifest.hasExpectedFullClonePins)
        #expect(manifest.pinnedSourceProblems.isEmpty)
        #expect(manifest.isProPayloadStaged)
        #expect(manifest.packagingSummary.contains("requirements.lock=generated"))
        #expect(manifest.packagingSummary.contains("wheels=staged"))
        #expect(manifest.packagingSummary.contains("browser payload=staged"))
        #expect(manifest.sourceMirrorGuard.requiredExclude == "--exclude='vendor/browser-use/'")
    }

    @Test("gate is honest: off by default and live only when Pro payload is staged and armed")
    func gateIsHonestUntilProPayloadIsStagedAndArmed() throws {
        let manifestURL = try sourceMirrorURL(for: "agent_core/vendor/browser-use/VENDOR_MANIFEST.json")

        let off = BrowserUseProGateStatus.status(environment: [:], manifestURL: manifestURL)
        #expect(!off.isActive)

        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        #expect(off.headline.contains("App Store"))
        #expect(off.detail.contains("Pro/Developer ID only"))
        #else
        #expect(off.headline == "browser-use Pro: off")
        #expect(off.detail.contains(BrowserUseProGateStatus.flagName))

        let armed = BrowserUseProGateStatus.status(
            environment: [BrowserUseProGateStatus.flagName: "1"],
            manifestURL: manifestURL
        )
        #expect(armed.isActive)
        #expect(armed.headline == "browser-use Pro: packaged payload ready")
        #expect(armed.detail.contains("packaged Pro runtime are present"))
        #expect(armed.detail.contains("Launch remains user-initiated"))
        #endif
    }

    @Test("missing or invalid manifest never activates the gate")
    func missingOrInvalidManifestNeverActivatesGate() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let missing = BrowserUseProGateStatus.status(
            environment: [BrowserUseProGateStatus.flagName: "1"],
            manifestURL: nil
        )
        #expect(!missing.isActive)
        #expect(missing.headline.contains("manifest missing"))

        let invalidURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-invalid-\(UUID().uuidString).json")
        try Data("{".utf8).write(to: invalidURL)
        defer { try? FileManager.default.removeItem(at: invalidURL) }

        let invalid = BrowserUseProGateStatus.status(
            environment: [BrowserUseProGateStatus.flagName: "1"],
            manifestURL: invalidURL
        )
        #expect(!invalid.isActive)
        #expect(invalid.headline.contains("unreadable"))
        #endif
    }

    @Test("gate source stays pure and out of other plan ownership")
    func gateSourceStaysPureAndInPlan3Boundary() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/BrowserUsePro/BrowserUseProGateStatus.swift")

        for required in [
            "nonisolated enum BrowserUseProGateStatus",
            "static let flagName = \"EPISTEMOS_BROWSER_USE_PRO_V0\"",
            "struct BrowserUseVendorManifest",
            "#if EPISTEMOS_APP_STORE || MAS_SANDBOX",
            "No automation runtime is launched",
            "isProPayloadStaged",
            "sourceMirrorGuard.requiredExclude"
        ] {
            #expect(source.contains(required), "Missing browser-use Pro gate string: \(required)")
        }

        for forbidden in [
            "Process(",
            "NSTask",
            "URLSession",
            "NSWorkspace",
            "GooseSurface",
            "Epistemos/Goose",
            "Epistemos/Agent",
            "HTMLWorkspace",
            "ProseInline",
            "PDFView"
        ] {
            #expect(!source.contains(forbidden), "browser-use Pro gate crossed a forbidden boundary: \(forbidden)")
        }
    }
}
