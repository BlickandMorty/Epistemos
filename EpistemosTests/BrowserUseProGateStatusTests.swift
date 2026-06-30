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

    @Test("manifest diagnostics redact path-leaking external errors")
    func manifestDiagnosticsRedactPathLeakingExternalErrors() {
        let privatePath = "/private/var/folders/browser-use/VENDOR_MANIFEST.json"
        let error = NSError(
            domain: privatePath,
            code: 31,
            userInfo: [NSLocalizedDescriptionKey: "failed to read \(privatePath)"]
        )
        let message = BrowserUseDiagnostics.statusMessage(for: error, fallback: "manifest read failed")

        #expect(message.contains("manifest read failed"))
        #expect(message.contains("domain=Error"))
        #expect(message.contains("code=31"))
        #expect(message.count <= BrowserUseDiagnostics.maxStatusMessageCharacters + 3)
        #expect(!message.contains(privatePath))
        #expect(!message.contains("failed to read"))
    }

    @Test("diagnostics preserve bounded browser-use settings errors")
    func diagnosticsPreserveBoundedBrowserUseSettingsErrors() {
        let message = BrowserUseDiagnostics.statusMessage(
            for: BrowserUseSettingsStoreError.invalidFile(
                "browser-use settings file must be a regular file at settings.json"
            ),
            fallback: "settings load failed"
        )

        #expect(message.contains("browser-use settings file must be a regular file at settings.json"))
        #expect(!message.contains("domain="))
    }

    @Test("manifest file envelope rejects symlinks and oversized JSON before decode")
    func manifestFileEnvelopeRejectsSymlinksAndOversizedJSONBeforeDecode() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-gate-envelope-\(UUID().uuidString)", isDirectory: true)
        let outsideManifest = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-outside-manifest-\(UUID().uuidString).json", isDirectory: false)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(Self.packagedManifestJSON.utf8).write(to: outsideManifest)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outsideManifest)
        }

        let symlinkManifest = root.appendingPathComponent("VENDOR_MANIFEST.json", isDirectory: false)
        try FileManager.default.createSymbolicLink(at: symlinkManifest, withDestinationURL: outsideManifest)
        let symlinkStatus = BrowserUseProGateStatus.status(
            environment: [BrowserUseProGateStatus.flagName: "1"],
            manifestURL: symlinkManifest
        )
        #expect(!symlinkStatus.isActive)
        #expect(symlinkStatus.headline == "browser-use Pro: vendor manifest unreadable")
        #expect(symlinkStatus.detail.contains("symlink"))
        #expect(symlinkStatus.detail.contains(symlinkManifest.path) == false)
        #expect(symlinkStatus.detail.contains(root.path) == false)

        let oversizedManifest = root.appendingPathComponent("OVERSIZED_MANIFEST.json", isDirectory: false)
        FileManager.default.createFile(atPath: oversizedManifest.path, contents: Data())
        let handle = try FileHandle(forWritingTo: oversizedManifest)
        try handle.truncate(atOffset: UInt64(BrowserUseVendorManifest.maxManifestBytes + 1))
        try handle.close()

        let oversizedStatus = BrowserUseProGateStatus.status(
            environment: [BrowserUseProGateStatus.flagName: "1"],
            manifestURL: oversizedManifest
        )
        #expect(!oversizedStatus.isActive)
        #expect(oversizedStatus.headline == "browser-use Pro: vendor manifest unreadable")
        #expect(oversizedStatus.detail.contains("exceeds \(BrowserUseVendorManifest.maxManifestBytes) bytes"))
        #endif
    }

    @Test("manifest-staged payload must have the declared artifacts on disk")
    func manifestStagedPayloadMustHaveDeclaredArtifactsOnDisk() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-gate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manifestURL = root.appendingPathComponent("VENDOR_MANIFEST.json", isDirectory: false)
        try Data(Self.packagedManifestJSON.utf8).write(to: manifestURL)

        let status = BrowserUseProGateStatus.status(
            environment: [BrowserUseProGateStatus.flagName: "1"],
            manifestURL: manifestURL
        )

        #expect(!status.isActive)
        #expect(status.headline == "browser-use Pro: packaged payload incomplete")
        #expect(status.detail.contains("requirements.lock"))
        #expect(status.detail.contains("wheelhouse"))
        #expect(status.detail.contains("BUILD_MANIFEST.json"))
        #endif
    }

    @Test("manifest artifact paths cannot escape the vendor root")
    func manifestArtifactPathsCannotEscapeVendorRoot() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-gate-path-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manifestURL = root.appendingPathComponent("VENDOR_MANIFEST.json", isDirectory: false)
        let manifest = Self.packagedManifestJSON.replacingOccurrences(
            of: "\"expected_path\": \"requirements.lock\"",
            with: "\"expected_path\": \"../requirements.lock\""
        )
        try Data(manifest.utf8).write(to: manifestURL)

        let status = BrowserUseProGateStatus.status(
            environment: [BrowserUseProGateStatus.flagName: "1"],
            manifestURL: manifestURL
        )

        #expect(!status.isActive)
        #expect(status.headline == "browser-use Pro: packaged payload incomplete")
        #expect(status.detail.contains("requirements.lock has unsafe path ../requirements.lock"))
        #endif
    }

    @Test("manifest file artifacts must not be directories")
    func manifestFileArtifactsMustNotBeDirectories() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-gate-shape-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manifestURL = root.appendingPathComponent("VENDOR_MANIFEST.json", isDirectory: false)
        try Data(Self.packagedManifestJSON.utf8).write(to: manifestURL)

        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("requirements.lock", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("wheels", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("playwright", isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data("{}".utf8).write(to: root.appendingPathComponent("BUILD_MANIFEST.json", isDirectory: false))

        let status = BrowserUseProGateStatus.status(
            environment: [BrowserUseProGateStatus.flagName: "1"],
            manifestURL: manifestURL
        )

        #expect(!status.isActive)
        #expect(status.headline == "browser-use Pro: packaged payload incomplete")
        #expect(status.detail.contains("requirements.lock is a directory at requirements.lock"))
        #endif
    }

    @Test("manifest artifact symlinks cannot resolve outside the vendor root")
    func manifestArtifactSymlinksCannotResolveOutsideVendorRoot() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-gate-symlink-\(UUID().uuidString)", isDirectory: true)
        let outsideURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-outside-\(UUID().uuidString).lock", isDirectory: false)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("outside lock\n".utf8).write(to: outsideURL)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outsideURL)
        }

        let manifestURL = root.appendingPathComponent("VENDOR_MANIFEST.json", isDirectory: false)
        try Data(Self.packagedManifestJSON.utf8).write(to: manifestURL)

        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("requirements.lock", isDirectory: false),
            withDestinationURL: outsideURL
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("wheels", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("playwright", isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data("{}".utf8).write(to: root.appendingPathComponent("BUILD_MANIFEST.json", isDirectory: false))

        let status = BrowserUseProGateStatus.status(
            environment: [BrowserUseProGateStatus.flagName: "1"],
            manifestURL: manifestURL
        )

        #expect(!status.isActive)
        #expect(status.headline == "browser-use Pro: packaged payload incomplete")
        #expect(status.detail.contains("requirements.lock resolves outside vendor root at requirements.lock"))
        #endif
    }

    @Test("manifest artifacts must not be symlink aliases inside the vendor root")
    func manifestArtifactsMustNotBeSymlinkAliasesInsideVendorRoot() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-gate-inner-symlink-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manifestURL = root.appendingPathComponent("VENDOR_MANIFEST.json", isDirectory: false)
        try Data(Self.packagedManifestJSON.utf8).write(to: manifestURL)

        let realLock = root.appendingPathComponent("real-requirements.lock", isDirectory: false)
        try Data("locked\n".utf8).write(to: realLock)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("requirements.lock", isDirectory: false),
            withDestinationURL: realLock
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("wheels", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("playwright", isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data("{}".utf8).write(to: root.appendingPathComponent("BUILD_MANIFEST.json", isDirectory: false))

        let status = BrowserUseProGateStatus.status(
            environment: [BrowserUseProGateStatus.flagName: "1"],
            manifestURL: manifestURL
        )

        #expect(!status.isActive)
        #expect(status.headline == "browser-use Pro: packaged payload incomplete")
        #expect(status.detail.contains("requirements.lock path must not include symlink component"))
        #expect(status.detail.contains(root.path) == false)
        #endif
    }

    @Test("gate source stays pure and out of other plan ownership")
    func gateSourceStaysPureAndInPlan3Boundary() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/BrowserUsePro/BrowserUseProGateStatus.swift")

        for required in [
            "nonisolated enum BrowserUseProGateStatus",
            "static let flagName = \"EPISTEMOS_BROWSER_USE_PRO_V0\"",
            "struct BrowserUseVendorManifest",
            "maxManifestBytes",
            "readManifestData",
            "validateManifestFile",
            "BrowserUseSymlinkPathGuard.firstSymlinkComponent",
            "open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)",
            "fstat(fd",
            "readToEnd()",
            "data.count <= maxManifestBytes",
            "path must not include symlink component",
            "browser-use vendor manifest must be a regular file",
            "browser-use vendor manifest exceeds",
            "#if EPISTEMOS_APP_STORE || MAS_SANDBOX",
            "No automation runtime is launched",
            "isProPayloadStaged",
            "stagedArtifactProblems(",
            "artifactURL(",
            "pathDiagnostic(",
            "maxPathDiagnosticLength",
            "BrowserUseDiagnostics",
            "BrowserUseDiagnostics.statusMessage(for: error",
            "unsafe path",
            "is a directory at",
            "resolves outside vendor root",
            "packaged payload incomplete",
            "BUILD_MANIFEST.json",
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
        #expect(!source.contains("error.localizedDescription"))
    }

    private static let packagedManifestJSON = """
    {
      "schema_version": 1,
      "name": "plan3-browser-use-pro",
      "runtime_lane": "pro-developer-id-only",
      "mas_safe": false,
      "native_wkwebview_boundary": "browser-use drives bundled Chromium over CDP; it does not drive Epistemos BrowserView WKWebView",
      "source_mirror_guard": {
        "source_of_truth": "project.yml",
        "required_exclude": "--exclude='vendor/browser-use/'",
        "reason": "Python, Playwright, Chromium, and browser-use source must not be copied into MAS SourceMirror resources"
      },
      "components": [
        {
          "name": "browser-use",
          "repo": "https://github.com/browser-use/browser-use.git",
          "commit": "2454d3e2551705232333c906ded8fc31ab0fc9f2",
          "license": "MIT",
          "full_clone": true,
          "file_count": 501
        },
        {
          "name": "web-ui",
          "repo": "https://github.com/browser-use/web-ui.git",
          "commit": "61962296c38a0d064e0ba02c827192b7a81d1819",
          "license": "MIT",
          "full_clone": true,
          "file_count": 42
        },
        {
          "name": "cdp-use",
          "repo": "https://github.com/browser-use/cdp-use.git",
          "commit": "a318684daab5ab3a9a516fcab447ed4bdfb92be9",
          "license": "MIT",
          "full_clone": true,
          "file_count": 357
        }
      ],
      "packaging_artifacts": {
        "requirements_lock": {
          "status": "generated",
          "expected_path": "requirements.lock"
        },
        "wheelhouse": {
          "status": "staged",
          "expected_path": "wheels/"
        },
        "playwright_chromium": {
          "status": "staged",
          "expected_path": "playwright/"
        }
      }
    }
    """
}
