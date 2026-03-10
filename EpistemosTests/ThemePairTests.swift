import Foundation
import Testing
@testable import Epistemos

@Suite("ThemePair Dock Icon")
struct ThemePairTests {

    @Test("Magnolia resolves to the new ash-rose light and nocturne dark themes")
    func magnoliaPairMapping() {
        #expect(ThemePair.magnolia.lightTheme == .magnolia)
        #expect(ThemePair.magnolia.darkTheme == .nocturne)
        #expect(ThemePair.magnolia.resolved(isDark: false) == .magnolia)
        #expect(ThemePair.magnolia.resolved(isDark: true) == .nocturne)
        #expect(EpistemosTheme.magnolia.usesNativeWindowBlur)
        #expect(EpistemosTheme.nocturne.usesNativeWindowBlur)
        #expect(!EpistemosTheme.light.usesNativeWindowBlur)
    }

    @Test("Classic does not require a runtime dock icon override")
    func classicResourceMapping() {
        #expect(ThemePair.classic.dockIconResourceName(isDark: false) == nil)
        #expect(ThemePair.classic.dockIconResourceName(isDark: true) == nil)
    }

    @Test("Magnolia, Warmth, and Ember do not require runtime dock icon overrides")
    func alternatePairsUseAdaptiveResources() {
        #expect(ThemePair.magnolia.dockIconResourceName(isDark: false) == nil)
        #expect(ThemePair.magnolia.dockIconResourceName(isDark: true) == nil)
        #expect(ThemePair.warmth.dockIconResourceName(isDark: false) == nil)
        #expect(ThemePair.warmth.dockIconResourceName(isDark: true) == nil)
        #expect(ThemePair.ember.dockIconResourceName(isDark: false) == nil)
        #expect(ThemePair.ember.dockIconResourceName(isDark: true) == nil)
    }

    @MainActor
    @Test("UIState defaults to Magnolia when no pair is stored")
    func uiStateDefaultsToMagnolia() {
        let defaults = UserDefaults.standard
        let key = "epistemos.theme.pair"
        let previous = defaults.string(forKey: key)
        defer {
            if let previous {
                defaults.set(previous, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.removeObject(forKey: key)

        let uiState = UIState()
        #expect(uiState.activePair == .magnolia)
    }

    @Test("Icon composer package carries dark and tinted variants")
    func iconComposerSupportsDarkAndTinted() throws {
        let json = try loadIconComposerJSON()
        #expect(json.contains("\"appearance\" : \"dark\""))
        #expect(json.contains("\"appearance\" : \"tinted\""))
    }

    @Test("Bundle plist points at the icon composer asset")
    func bundlePlistUsesIconComposerFile() throws {
        let plist = try loadBundlePlist()
        #expect(plist["CFBundleIdentifier"] as? String == "com.epistemos.app")
        #expect(plist["CFBundleIconName"] as? String == "AppIcon")
        #expect(plist["CFBundleIconFile"] == nil)
    }

    @Test("Project uses AppIcon.icon as the primary app icon source")
    func projectUsesIconComposerFile() throws {
        let pbxproj = try loadProjectFile()
        #expect(pbxproj.contains("AppIcon.icon */ = {isa = PBXFileReference; lastKnownFileType = folder.iconcomposer.icon;"))
        #expect(pbxproj.contains("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;"))
    }

    private func loadIconComposerJSON() throws -> String {
        let iconURL = repoRootURL().appendingPathComponent("Epistemos/AppIcon.icon/icon.json")
        return try String(contentsOf: iconURL)
    }

    private func loadBundlePlist() throws -> [String: Any] {
        let plistURL = repoRootURL().appendingPathComponent("Epistemos-Info.plist")
        let data = try Data(contentsOf: plistURL)
        return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    private func loadProjectFile() throws -> String {
        try String(contentsOf: repoRootURL().appendingPathComponent("Epistemos.xcodeproj/project.pbxproj"))
    }

    private func repoRootURL() -> URL {
        let testsFileURL = URL(fileURLWithPath: #filePath)
        return testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
    }
}
