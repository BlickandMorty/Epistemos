import Testing

@Suite("MarkEdit vendor script (Plan 2 Stage 5)")
nonisolated struct MarkEditVendorScriptTests {
    @Test("vendor script pins MarkEdit and prunes only incompatible app shell")
    func vendorScriptPinsAndPrunesOnlyShellItems() throws {
        let script = try loadMirroredSourceTextFile("scripts/vendor_markedit.sh")

        #expect(script.contains("https://github.com/MarkEdit-app/MarkEdit.git"))
        #expect(script.contains("7d56e2e64322e983c43aa789bc08e238860f0069"))
        #expect(script.contains("LocalPackages/MarkEdit"))
        #expect(script.contains("This is vendored source, not a git submodule or worktree."))
        #expect(script.contains("rm -rf \"${tmp_dir}/.git\""))

        let requiredDropPaths = [
            "MarkEditMac/Sources/Main/Application",
            "MarkEditMac/Sources/Main/AppDocumentController.swift",
            "MarkEdit.xcodeproj",
            "MarkEditMac/Info.entitlements",
            "FinderExtension",
            "PreviewExtension",
        ]
        for path in requiredDropPaths {
            #expect(script.contains("\"" + path + "\""), "vendor script must explicitly prune \(path)")
        }

        #expect(script.contains("Harvest MAS-safe document-type/build-settings hardening"))
        #expect(script.contains("--replace"))
        #expect(script.contains("--print-plan"))
    }
}
