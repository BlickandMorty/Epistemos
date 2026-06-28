import Foundation
import Testing

@Suite("MarkEdit vendor completeness (Plan 2 Stage 5)")
nonisolated struct MarkEditVendorCompletenessTests {
    @Test("vendored MarkEdit keeps full app/editor source without app shell conflicts")
    func vendoredMarkEditKeepsRequiredSource() throws {
        let vendorRoot = try sourceMirrorURL(for: "LocalPackages/MarkEdit/LICENSE")
            .deletingLastPathComponent()
        let fileManager = FileManager.default

        #expect(fileManager.fileExists(atPath: vendorRoot.appendingPathComponent("LICENSE").path))
        #expect(fileManager.fileExists(atPath: vendorRoot.appendingPathComponent("CoreEditor").path))
        #expect(fileManager.fileExists(atPath: vendorRoot.appendingPathComponent("MarkEditCore").path))
        #expect(fileManager.fileExists(atPath: vendorRoot.appendingPathComponent("MarkEditKit").path))
        #expect(fileManager.fileExists(atPath: vendorRoot.appendingPathComponent("MarkEditMac/Sources/Editor/Controllers/EditorViewController.swift").path))

        let forbiddenPaths = [
            ".git",
            "MarkEditMac/Sources/Main/Application",
            "MarkEditMac/Sources/Main/AppDocumentController.swift",
            "MarkEdit.xcodeproj",
            "MarkEditMac/Info.entitlements",
            "FinderExtension",
            "PreviewExtension",
        ]
        for relativePath in forbiddenPaths {
            #expect(!fileManager.fileExists(atPath: vendorRoot.appendingPathComponent(relativePath).path), "\(relativePath) must not be vendored")
        }
        #expect(try nestedGitDirectories(under: vendorRoot).isEmpty)

        let modulePackageURL = vendorRoot.appendingPathComponent("MarkEditMac/Modules/Package.swift")
        let modulePackage = try String(contentsOf: modulePackageURL, encoding: .utf8)
        let requiredModules = [
            "AppKitControls",
            "AppKitExtensions",
            "DiffKit",
            "FileDrop",
            "FileVersion",
            "FontPicker",
            "Previewer",
            "SettingsUI",
            "Statistics",
            "TextBundle",
            "TextCompletion",
        ]
        for module in requiredModules {
            #expect(modulePackage.contains("name: \"\(module)\""), "\(module) must remain declared in Modules/Package.swift")
            #expect(fileManager.fileExists(atPath: vendorRoot.appendingPathComponent("MarkEditMac/Modules/Sources/\(module)").path), "\(module) sources must remain vendored")
        }

        let settingsPanes = [
            "AssistantSettingsView.swift",
            "EditorSettingsView.swift",
            "GeneralSettingsView.swift",
            "SettingTabs.swift",
            "WindowSettingsView.swift",
        ]
        for settingsPane in settingsPanes {
            #expect(fileManager.fileExists(atPath: vendorRoot.appendingPathComponent("MarkEditMac/Sources/Settings/\(settingsPane)").path), "\(settingsPane) must remain vendored")
        }

        #expect(fileManager.fileExists(atPath: vendorRoot.appendingPathComponent("MarkEditMac/Sources/Scripting").path))
        #expect(fileManager.fileExists(atPath: vendorRoot.appendingPathComponent("MarkEditMac/Sources/Shortcuts").path))
        #expect(fileManager.fileExists(atPath: vendorRoot.appendingPathComponent("MarkEditTools/Package.swift").path))
    }

    private func nestedGitDirectories(under rootURL: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return []
        }

        var gitDirectories: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            guard url.lastPathComponent == ".git" else { continue }
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues.isDirectory == true {
                gitDirectories.append(url)
            }
        }
        return gitDirectories
    }
}
