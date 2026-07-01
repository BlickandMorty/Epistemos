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
        #expect(manifest.packagingSummary.contains("web-ui shims=landed"))
        #expect(manifest.packagingSummary.contains("dry-run hook=landed"))
        #expect(manifest.sourceMirrorGuard.requiredExclude == "--exclude='vendor/browser-use/'")
    }

    @Test("gate is honest: off by default and inactive until the staged Pro payload is signed")
    func gateIsHonestUntilStagedProPayloadIsSigned() throws {
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
        #expect(!armed.isActive)
        #expect(armed.headline == "browser-use Pro: signed package missing")
        #expect(armed.detail.contains("staged Pro artifacts are present"))
        #expect(armed.detail.contains("signed BrowserUsePro.bundle"))
        #expect(armed.detail.contains("No automation runtime is launched"))
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
        #expect(message.count <= BrowserUseDiagnostics.maxStatusMessageCharacters)
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

    @Test("diagnostics cap raw status before trim and keep ellipsis inside bound")
    func diagnosticsCapRawStatusBeforeTrim() {
        let message = BrowserUseDiagnostics.statusMessage(
            String(repeating: "x", count: BrowserUseDiagnostics.maxStatusMessageCharacters + 64),
            fallback: "browser-use status"
        )

        #expect(message.count <= BrowserUseDiagnostics.maxStatusMessageCharacters)
        #expect(message.hasSuffix("..."))
    }

    @Test("diagnostics normalize embedded control characters before display")
    func diagnosticsNormalizeEmbeddedControlCharacters() {
        let message = BrowserUseDiagnostics.statusMessage(
            "browser-use\nstatus\tready\u{0007}",
            fallback: "browser-use status"
        )
        let settingsError = BrowserUseSettingsStoreError.invalidFile(
            "settings\nfile\tis\u{0007}invalid"
        )
        let settingsMessage = BrowserUseDiagnostics.statusMessage(
            for: settingsError,
            fallback: "settings load failed"
        )

        #expect(message == "browser-use status ready")
        #expect(settingsMessage == "settings file is invalid")
        #expect(!message.contains("\n"))
        #expect(!settingsMessage.contains("\t"))
        #expect(BrowserUseDiagnostics.safeDomain("NS\nCocoa\tError") == "Error")
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
        #expect(status.detail.contains("web-ui compatibility shim"))
        #expect(status.detail.contains("web-ui dry-run submit hook"))
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

    @Test("manifest artifact paths cannot contain empty path segments")
    func manifestArtifactPathsCannotContainEmptyPathSegments() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-gate-empty-path-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manifestURL = root.appendingPathComponent("VENDOR_MANIFEST.json", isDirectory: false)
        let manifest = Self.packagedManifestJSON.replacingOccurrences(
            of: "\"expected_path\": \"requirements.lock\"",
            with: "\"expected_path\": \"requirements//lock\""
        )
        try Data(manifest.utf8).write(to: manifestURL)

        let status = BrowserUseProGateStatus.status(
            environment: [BrowserUseProGateStatus.flagName: "1"],
            manifestURL: manifestURL
        )

        #expect(!status.isActive)
        #expect(status.headline == "browser-use Pro: packaged payload incomplete")
        #expect(status.detail.contains("requirements.lock has unsafe path requirements//lock"))
        #endif
    }

    @Test("vendor manifest identity and browser boundary must match the Pro contract")
    func vendorManifestIdentityAndBrowserBoundaryMustMatchProContract() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-gate-identity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manifestURL = root.appendingPathComponent("VENDOR_MANIFEST.json", isDirectory: false)
        let manifest = Self.packagedManifestJSON
            .replacingOccurrences(
                of: #""runtime_lane": "pro-developer-id-only""#,
                with: #""runtime_lane": "app-store""#
            )
            .replacingOccurrences(
                of: #"browser-use drives bundled Chromium over CDP; it does not drive Epistemos BrowserView WKWebView"#,
                with: #"browser-use drives the native WKWebView Browser"#
            )
        try Data(manifest.utf8).write(to: manifestURL)

        let status = BrowserUseProGateStatus.status(
            environment: [BrowserUseProGateStatus.flagName: "1"],
            manifestURL: manifestURL
        )

        #expect(!status.isActive)
        #expect(status.headline == "browser-use Pro: vendor manifest invalid")
        #expect(status.detail.contains("manifest runtime lane mismatch"))
        #expect(status.detail.contains("manifest native Browser boundary mismatch"))
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

    @Test("signed BrowserUsePro bundle activates the Pro gate with signed headline")
    func signedBrowserUseProBundleActivatesGateWithSignedHeadline() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-signed-bundle-\(UUID().uuidString)", isDirectory: true)
        let bundleURL = root.appendingPathComponent("BrowserUsePro.bundle", isDirectory: true)
        let payloadRoot = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("BrowserUsePro", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try writeSignedBrowserUseBundleFixture(
            root: root,
            bundleURL: bundleURL,
            payloadRoot: payloadRoot,
            includeInternalSymlink: true
        )

        let status = BrowserUseProGateStatus.status(
            environment: [BrowserUseProGateStatus.flagName: "1"],
            manifestURL: payloadRoot.appendingPathComponent("VENDOR_MANIFEST.json", isDirectory: false)
        )

        #expect(status.isActive)
        #expect(status.headline == "browser-use Pro: signed packaged payload ready")
        #expect(status.detail.contains("Signed BrowserUsePro.bundle verified"))
        #expect(status.detail.contains("Package result verified"))
        #expect(status.detail.contains("browser-use-pro-smoke-suite.sh"))
        #expect(status.detail.contains("native WKWebView Browser"))
        #endif
    }

    @Test("signed BrowserUsePro payload rejects non-printable signing identities")
    func signedBrowserUseProPayloadRejectsNonPrintableSigningIdentities() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-signed-bundle-identity-\(UUID().uuidString)", isDirectory: true)
        let bundleURL = root.appendingPathComponent("BrowserUsePro.bundle", isDirectory: true)
        let payloadRoot = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("BrowserUsePro", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manifest = Self.signatureManifestJSON.replacingOccurrences(
            of: #""signing_identity": "-""#,
            with: #""signing_identity": "\u0007\t\n""#
        )
        try writeSignedBrowserUseBundleFixture(
            root: root,
            bundleURL: bundleURL,
            payloadRoot: payloadRoot,
            signatureManifestJSON: manifest
        )

        let status = BrowserUseProGateStatus.status(
            environment: [BrowserUseProGateStatus.flagName: "1"],
            manifestURL: payloadRoot.appendingPathComponent("VENDOR_MANIFEST.json", isDirectory: false)
        )

        #expect(!status.isActive)
        #expect(status.headline == "browser-use Pro: signed package invalid")
        #expect(status.detail.contains("signature manifest signing identity is empty"))
        #endif
    }

    @Test("signed BrowserUsePro payload rejects symlink escapes")
    func signedBrowserUseProPayloadRejectsSymlinkEscapes() throws {
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-signed-bundle-symlink-\(UUID().uuidString)", isDirectory: true)
        let outsideURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("browser-use-signed-outside-\(UUID().uuidString).txt", isDirectory: false)
        let bundleURL = root.appendingPathComponent("BrowserUsePro.bundle", isDirectory: true)
        let payloadRoot = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("BrowserUsePro", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outsideURL)
        }

        try writeSignedBrowserUseBundleFixture(
            root: root,
            bundleURL: bundleURL,
            payloadRoot: payloadRoot
        )
        try Data("outside\n".utf8).write(to: outsideURL)
        try FileManager.default.createSymbolicLink(
            at: payloadRoot.appendingPathComponent("outside.alias", isDirectory: false),
            withDestinationURL: outsideURL
        )

        let status = BrowserUseProGateStatus.status(
            environment: [BrowserUseProGateStatus.flagName: "1"],
            manifestURL: payloadRoot.appendingPathComponent("VENDOR_MANIFEST.json", isDirectory: false)
        )

        #expect(!status.isActive)
        #expect(status.headline == "browser-use Pro: signed package invalid")
        #expect(status.detail.contains("signature payload symlink resolves outside package"))
        #expect(!status.detail.contains(root.path))
        #endif
    }

    @Test("gate source stays pure and out of other plan ownership")
    func gateSourceStaysPureAndInPlan3Boundary() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/BrowserUsePro/BrowserUseProGateStatus.swift")
        let signedSource = try loadMirroredSourceTextFile("Epistemos/BrowserUsePro/BrowserUseSignedBundleStatus.swift")

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
            "rawBoundedDiagnostic(value, maxCharacters: maxPathDiagnosticLength",
            "limit - 3",
            "BrowserUseDiagnostics",
            "BrowserUseDiagnostics.statusMessage(for: error",
            "rawBoundedDiagnostic(message, maxCharacters: maxStatusMessageCharacters",
            "normalizedDiagnostic(clipped)",
            "String(domain.prefix(maxDomainCharacters))",
            "normalizedDiagnostic(bounded)",
            "BrowserUseSignedBundleStatus",
            "SecStaticCodeCheckValidity",
            "kSecCSCheckNestedCode",
            "kSecCSCheckAllArchitectures",
            "webUIRuntimeCompatibility",
            "webUIDryRunSubmit",
            "expectedDryRunSubmitEnvVar",
            "expectedDryRunSubmitMarker",
            "web-ui compatibility shim",
            "web-ui dry-run submit hook",
            "manifest schema",
            "manifest name mismatch",
            "manifest runtime lane mismatch",
            "manifest native Browser boundary mismatch",
            "signature manifest top-level keys mismatch",
            "normalizedSigningIdentity(",
            "signature manifest signing identity is empty",
            "isSecondPrecisionUTCTimestamp",
            "signature manifest codesign contract mismatch",
            "signed packaged payload ready",
            "signature manifest",
            "unsafe path",
            "omittingEmptySubsequences: false",
            "is a directory at",
            "resolves outside vendor root",
            "packaged payload incomplete",
            "BUILD_MANIFEST.json",
            "sourceMirrorGuard.requiredExclude"
        ] {
            #expect(source.contains(required), "Missing browser-use Pro gate string: \(required)")
        }

        for required in [
            "static let packageResultName = \"PACKAGE_RESULT.json\"",
            "private struct PackageResult",
            "package result top-level keys mismatch",
            "loadPackageResult(",
            "packageResultProblem(",
            "Package result verified",
            "smokeSuiteEntrypoint",
            "maxPayloadEnumerationEntries",
            "visitedEntryCount",
            "signature payload contains too many entries",
            "signature payload symlink resolves outside package",
            "enumerator.skipDescendants()",
            "String(value.prefix(32))",
            "rawBoundedDiagnostic(",
            "maxCharacters: maxStatusMessageCharacters",
            "normalizedDiagnostic(clipped)",
            "limit - 3",
        ] {
            #expect(signedSource.contains(required), "Missing browser-use signed bundle string: \(required)")
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

    private func writeSignedBrowserUseBundleFixture(
        root: URL,
        bundleURL: URL,
        payloadRoot: URL,
        includeInternalSymlink: Bool = false,
        signatureManifestJSON: String = Self.signatureManifestJSON
    ) throws {
        try FileManager.default.createDirectory(at: payloadRoot, withIntermediateDirectories: true)
        try Data(Self.infoPlist.utf8).write(
            to: bundleURL
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("Info.plist", isDirectory: false)
        )
        try Data(Self.packagedManifestJSON.utf8).write(
            to: payloadRoot.appendingPathComponent("VENDOR_MANIFEST.json", isDirectory: false)
        )
        try writeExecutableFixture(
            payloadRoot.appendingPathComponent("epistemos_agent_browser.py", isDirectory: false)
        )
        try Data("env\n".utf8).write(
            to: payloadRoot.appendingPathComponent("epistemos_browser_env.py", isDirectory: false)
        )
        try Data("task\n".utf8).write(
            to: payloadRoot.appendingPathComponent("epistemos_browser_task.py", isDirectory: false)
        )
        try writeExecutableFixture(
            payloadRoot.appendingPathComponent("build-pro-payload.sh", isDirectory: false)
        )
        try writeWebUICompatibilityFixtureFiles(in: payloadRoot)
        try writeTextFixture(
            "web-ui/src/webui/components/browser_use_agent_tab.py",
            in: payloadRoot,
            contents: "dry run hook\n"
        )
        try Data("{\"schema_version\":1}\n".utf8).write(
            to: payloadRoot.appendingPathComponent("BUILD_MANIFEST.json", isDirectory: false)
        )
        try Data("# generated lock\n".utf8).write(
            to: payloadRoot.appendingPathComponent("requirements.lock", isDirectory: false)
        )
        try FileManager.default.createDirectory(
            at: payloadRoot.appendingPathComponent("wheels", isDirectory: true),
            withIntermediateDirectories: true
        )
        try writeWheelhouseFixtureFiles(
            in: payloadRoot.appendingPathComponent("wheels", isDirectory: true)
        )
        try FileManager.default.createDirectory(
            at: payloadRoot.appendingPathComponent("playwright", isDirectory: true),
            withIntermediateDirectories: true
        )
        try writePlaywrightRevisionMarkers(
            in: payloadRoot.appendingPathComponent("playwright", isDirectory: true)
        )
        if includeInternalSymlink {
            try FileManager.default.createSymbolicLink(
                at: payloadRoot.appendingPathComponent("requirements.alias", isDirectory: false),
                withDestinationURL: payloadRoot.appendingPathComponent("requirements.lock", isDirectory: false)
            )
        }
        try Data(signatureManifestJSON.utf8).write(
            to: payloadRoot.appendingPathComponent("SIGNATURE_MANIFEST.json", isDirectory: false)
        )
        try Data(Self.packageResultJSON.utf8).write(
            to: root.appendingPathComponent("PACKAGE_RESULT.json", isDirectory: false)
        )

        try runProcess("/usr/bin/codesign", arguments: [
            "--force",
            "--sign",
            "-",
            bundleURL.path,
        ])
    }

    private func runProcess(_ executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "BrowserUseProGateStatusTests",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: output]
            )
        }
    }

    private func writeWheelhouseFixtureFiles(in wheelhouseURL: URL) throws {
        for index in 0..<177 {
            try Data("wheel \(index)\n".utf8).write(
                to: wheelhouseURL.appendingPathComponent("fixture-\(index).whl", isDirectory: false)
            )
        }
    }

    private func writePlaywrightRevisionMarkers(in playwrightURL: URL) throws {
        for directoryName in [
            "chromium-1223",
            "chromium_headless_shell-1223",
            "ffmpeg-1011",
        ] {
            let directoryURL = playwrightURL.appendingPathComponent(directoryName, isDirectory: true)
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try Data("ok\n".utf8).write(
                to: directoryURL.appendingPathComponent("INSTALLATION_COMPLETE", isDirectory: false)
            )
        }
    }

    private func writeWebUICompatibilityFixtureFiles(in payloadRoot: URL) throws {
        for relativePath in [
            "browser-use/browser_use/browser/browser.py",
            "browser-use/browser_use/browser/context.py",
            "browser-use/browser_use/browser/chrome.py",
            "browser-use/browser_use/browser/utils/__init__.py",
            "browser-use/browser_use/browser/utils/screen_resolution.py",
            "browser-use/browser_use/controller/service.py",
            "browser-use/browser_use/controller/registry/__init__.py",
            "browser-use/browser_use/controller/registry/service.py",
            "browser-use/browser_use/controller/registry/views.py",
            "browser-use/browser_use/controller/views.py",
        ] {
            try writeTextFixture(relativePath, in: payloadRoot, contents: "shim\n")
        }
    }

    private func writeTextFixture(_ relativePath: String, in payloadRoot: URL, contents: String) throws {
        let url = payloadRoot.appendingPathComponent(relativePath, isDirectory: false)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
    }

    private func writeExecutableFixture(_ url: URL) throws {
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
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
          "package_version": "0.13.2",
          "full_clone": true,
          "file_count": 501
        },
        {
          "name": "web-ui",
          "repo": "https://github.com/browser-use/web-ui.git",
          "commit": "61962296c38a0d064e0ba02c827192b7a81d1819",
          "license": "MIT",
          "package_version": null,
          "full_clone": true,
          "file_count": 42
        },
        {
          "name": "cdp-use",
          "repo": "https://github.com/browser-use/cdp-use.git",
          "commit": "a318684daab5ab3a9a516fcab447ed4bdfb92be9",
          "license": "MIT",
          "package_version": "1.4.5",
          "full_clone": true,
          "file_count": 357
        }
      ],
      "packaging_artifacts": {
        "agent_browser_adapter": {
          "status": "landed",
          "expected_paths": [
            "epistemos_agent_browser.py",
            "epistemos_browser_env.py",
            "epistemos_browser_task.py"
          ]
        },
        "web_ui_runtime_compatibility": {
          "status": "landed",
          "expected_paths": [
            "browser-use/browser_use/browser/browser.py",
            "browser-use/browser_use/browser/context.py",
            "browser-use/browser_use/browser/chrome.py",
            "browser-use/browser_use/browser/utils/__init__.py",
            "browser-use/browser_use/browser/utils/screen_resolution.py",
            "browser-use/browser_use/controller/service.py",
            "browser-use/browser_use/controller/registry/__init__.py",
            "browser-use/browser_use/controller/registry/service.py",
            "browser-use/browser_use/controller/registry/views.py",
            "browser-use/browser_use/controller/views.py"
          ]
        },
        "web_ui_dry_run_submit": {
          "status": "landed",
          "expected_path": "web-ui/src/webui/components/browser_use_agent_tab.py",
          "env_var": "EPISTEMOS_BROWSER_USE_WEBUI_DRY_RUN_SUBMIT",
          "marker": "Epistemos browser-use WebUI dry-run task-submit complete"
        },
        "build_script": {
          "status": "landed",
          "expected_path": "build-pro-payload.sh"
        },
        "build_manifest": {
          "status": "generated",
          "expected_path": "BUILD_MANIFEST.json"
        },
        "requirements_lock": {
          "status": "generated",
          "expected_path": "requirements.lock"
        },
        "wheelhouse": {
          "status": "staged",
          "expected_path": "wheels/",
          "file_count": 177
        },
        "playwright_chromium": {
          "status": "staged",
          "expected_path": "playwright/",
          "chromium_revision": "1223",
          "headless_shell_revision": "1223",
          "ffmpeg_revision": "1011"
        }
      }
    }
    """

    private static let signatureManifestJSON = """
    {
      "schema_version": 1,
      "package_name": "BrowserUsePro",
      "runtime_lane": "pro-developer-id-only",
      "signature_type": "ad-hoc",
      "signing_identity": "-",
      "payload_root": "Contents/Resources/BrowserUsePro",
      "file_count": 198,
      "python": "Python 3.11.15",
      "browser_use_version": "0.13.2",
      "component_repos": {
        "browser-use": "https://github.com/browser-use/browser-use.git",
        "web-ui": "https://github.com/browser-use/web-ui.git",
        "cdp-use": "https://github.com/browser-use/cdp-use.git"
      },
      "component_commits": {
        "browser-use": "2454d3e2551705232333c906ded8fc31ab0fc9f2",
        "web-ui": "61962296c38a0d064e0ba02c827192b7a81d1819",
        "cdp-use": "a318684daab5ab3a9a516fcab447ed4bdfb92be9"
      },
      "component_versions": {
        "browser-use": "0.13.2",
        "web-ui": null,
        "cdp-use": "1.4.5"
      },
      "playwright_revisions": {
        "chromium": "1223",
        "chromium_headless_shell": "1223",
        "ffmpeg": "1011"
      },
      "created_utc": "2026-06-30T00:00:00Z",
      "codesign_contract": "BrowserUsePro.bundle must pass codesign --verify --deep --strict before bundling and strict Security.framework validation at runtime."
    }
    """

    private static let packageResultJSON = """
    {
      "schema_version": 1,
      "package_name": "BrowserUsePro",
      "bundle": "BrowserUsePro.bundle",
      "signature_manifest": "BrowserUsePro.bundle/Contents/Resources/BrowserUsePro/SIGNATURE_MANIFEST.json",
      "signature_type": "ad-hoc",
      "python": "Python 3.11.15",
      "codesign_verified": true,
      "smoke_suite_entrypoint": "scripts/browser-use-pro-smoke-suite.sh",
      "smoke_suite_args": ["--signed-bundle", "BrowserUsePro.bundle"],
      "notarization": "not recorded; release notarization remains distribution ops",
      "secrets": "not recorded",
      "created_utc": "2026-06-30T00:00:01Z"
    }
    """

    private static let infoPlist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleIdentifier</key>
      <string>com.epistemos.browserusepro.test</string>
      <key>CFBundleName</key>
      <string>BrowserUsePro</string>
      <key>CFBundlePackageType</key>
      <string>BNDL</string>
      <key>CFBundleVersion</key>
      <string>1</string>
    </dict>
    </plist>
    """
}
