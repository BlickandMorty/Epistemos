import Foundation
import Testing

@testable import Epistemos

/// Wave 7 follow-up source-guard for the Info.plist registration that
/// makes the `.epdoc` package a Finder-visible document type bound to
/// `EpdocDocument` (NSDocument subclass).
///
/// These tests fail loudly if a future edit drops the UTType / document
/// type / NSDocumentClass dictionaries — that drop would silently
/// remove Open / Save / Versions / Restore / Share Sheet integration
/// without any compiler error, so we pin the contract here.
@Suite("Epdoc Info.plist registration (Wave 7 follow-up)")
nonisolated struct EpdocInfoPlistTests {

    /// Probe both the test bundle and the host (Epistemos.app) Info
    /// dictionary — under xcodebuild test the host bundle is the one
    /// that carries the production keys.
    private static func hostInfo() -> [String: Any]? {
        // The test runs inside the host app under Xcode tests, so
        // Bundle.main IS the Epistemos.app bundle and reading
        // infoDictionary returns the production Info.plist.
        return Bundle.main.infoDictionary
    }

    @Test("Info.plist exports the com.epistemos.epdoc UTType conforming to com.apple.package")
    func exportsEpdocUTType() throws {
        let info = try #require(Self.hostInfo(), "host Info.plist must be readable")
        let exports = try #require(info["UTExportedTypeDeclarations"] as? [[String: Any]],
                                   "UTExportedTypeDeclarations key MUST be present (W7 follow-up)")
        let epdoc = try #require(
            exports.first(where: { ($0["UTTypeIdentifier"] as? String) == "com.epistemos.epdoc" }),
            "UTExportedTypeDeclarations MUST include com.epistemos.epdoc"
        )
        let conforms = try #require(epdoc["UTTypeConformsTo"] as? [String])
        #expect(conforms.contains("com.apple.package"),
                "epdoc MUST conform to com.apple.package — that's what makes it show as a single Finder icon")
        let tags = try #require(epdoc["UTTypeTagSpecification"] as? [String: Any])
        let exts = try #require(tags["public.filename-extension"] as? [String])
        #expect(exts.contains("epdoc"),
                "filename-extension MUST include 'epdoc' so files with that suffix bind to the type")
    }

    @Test("Info.plist binds com.epistemos.epdoc → EpdocDocument via CFBundleDocumentTypes")
    func bindsDocumentTypeToNSDocumentClass() throws {
        let info = try #require(Self.hostInfo())
        let docTypes = try #require(info["CFBundleDocumentTypes"] as? [[String: Any]],
                                    "CFBundleDocumentTypes MUST be declared (W7 follow-up)")
        let epdocEntry = try #require(
            docTypes.first(where: {
                guard let types = $0["LSItemContentTypes"] as? [String] else { return false }
                return types.contains("com.epistemos.epdoc")
            }),
            "CFBundleDocumentTypes MUST include an entry whose LSItemContentTypes contains com.epistemos.epdoc"
        )
        let nsClass = try #require(epdocEntry["NSDocumentClass"] as? String,
                                   "NSDocumentClass binding required so AppKit instantiates EpdocDocument on open")
        // Either the literal $(PRODUCT_MODULE_NAME).EpdocDocument (raw plist
        // template) or the resolved Epistemos.EpdocDocument is acceptable —
        // Xcode substitutes the variable at build time but old caches sometimes
        // surface the unresolved form.
        let acceptable = ["$(PRODUCT_MODULE_NAME).EpdocDocument", "Epistemos.EpdocDocument"]
        #expect(acceptable.contains(nsClass),
                "NSDocumentClass MUST resolve to Epistemos.EpdocDocument; got \(nsClass)")

        let role = epdocEntry["CFBundleTypeRole"] as? String
        #expect(role == "Editor",
                "CFBundleTypeRole MUST be 'Editor' — Epistemos creates + edits .epdoc, not just reads")
        let rank = epdocEntry["LSHandlerRank"] as? String
        #expect(rank == "Owner",
                "LSHandlerRank MUST be 'Owner' so Epistemos becomes the default app for .epdoc bundles")
    }
}
