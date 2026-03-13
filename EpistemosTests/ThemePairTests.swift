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
    @Test("UIState defaults to Platinum when no pair is stored")
    func uiStateDefaultsToPlatinum() {
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
        #expect(uiState.activePair == .platinum)
    }

    @Test("Magnolia uses a rose display accent for app titles and headings")
    func magnoliaUsesRoseDisplayAccent() {
        #expect(EpistemosTheme.magnolia.headingAccentHex == 0xB86F8D)
    }

    @Test("Platinum pair resolves to distinct light and dark variants")
    func platinumPairMapping() {
        #expect(ThemePair.platinum.lightTheme == .platinum)
        #expect(ThemePair.platinum.darkTheme == .platinumDark)
        #expect(ThemePair.platinum.resolved(isDark: false) == .platinum)
        #expect(ThemePair.platinum.resolved(isDark: true) == .platinumDark)
        #expect(!EpistemosTheme.platinum.isDark)
        #expect(EpistemosTheme.platinumDark.isDark)
        #expect(EpistemosTheme.platinum.foregroundHex == 0x000000)
        #expect(EpistemosTheme.platinumDark.foregroundHex == 0xFFFFFF)
        #expect(EpistemosTheme.platinum.markdownHeadingAccentHex == 0x00007B)
        #expect(EpistemosTheme.platinumDark.markdownHeadingAccentHex == 0x7B68EE)
        #expect(EpistemosTheme.platinum.preferredMarkdownLinkHex == 0x00007B)
        #expect(EpistemosTheme.platinumDark.preferredMarkdownLinkHex == nil)
        #expect(MarkdownHeadingDisplay.foregroundHex(for: .platinum, level: 1) == EpistemosTheme.platinum.headingAccentHex)
        #expect(MarkdownHeadingDisplay.foregroundHex(for: .platinum, level: 2) == EpistemosTheme.platinum.markdownHeadingAccentHex)
        #expect(EpistemosTheme.platinum.assistantBubbleForegroundHex == EpistemosTheme.platinum.mutedForegroundHex)
        #expect(EpistemosTheme.platinumDark.assistantBubbleForegroundHex == EpistemosTheme.platinumDark.foregroundHex)
        #expect(EpistemosTheme.platinum.assistantBubbleBackgroundHex == nil)
        #expect(EpistemosTheme.platinumDark.assistantBubbleBackgroundHex == nil)
        #expect(EpistemosTheme.platinum.userBubbleBackgroundHex == 0xD6C2A2)
    }

    @Test("System appearance state reads the global Apple interface style")
    func systemAppearanceStateUsesGlobalInterfaceStyle() {
        #expect(SystemAppearanceState.isDark(globalDomain: nil) == false)
        #expect(SystemAppearanceState.isDark(globalDomain: [:]) == false)
        #expect(SystemAppearanceState.isDark(globalDomain: ["AppleInterfaceStyle": "Dark"]))
        #expect(
            SystemAppearanceState.isDark(globalDomain: ["AppleInterfaceStyle": "Light"]) == false
        )
    }

    @Test("App heading roles use the shared RetroGaming display scale")
    func appHeadingRolesUseSharedDisplayScale() {
        #expect(AppHeadingRole.pageTitle.fontName == "RetroGaming")
        #expect(AppHeadingRole.pageTitle.fontSize == 28)
        #expect(AppHeadingRole.pageTitle.animatesOnFirstAppearance)
        #expect(AppHeadingRole.h1.fontSize == 26)
        #expect(AppHeadingRole.h2.fontSize == 20)
        #expect(AppHeadingRole.h3.fontSize == 16)
        #expect(AppHeadingRole.section.fontSize == 12)
    }

    @Test("Markdown H1 sizing eases down for longer titles without collapsing into H2")
    func markdownH1AdaptiveSizing() {
        let shortSize = MarkdownHeadingDisplay.fontSize(
            for: 1,
            text: "All Things Must Go",
            baseSize: AppHeadingRole.h1.fontSize,
            nextLevelSize: AppHeadingRole.h2.fontSize
        )
        let mediumSize = MarkdownHeadingDisplay.fontSize(
            for: 1,
            text: "A Neuroscientific explanation of determinism in society",
            baseSize: AppHeadingRole.h1.fontSize,
            nextLevelSize: AppHeadingRole.h2.fontSize
        )
        let longSize = MarkdownHeadingDisplay.fontSize(
            for: 1,
            text: "A Neuroscientific explanation of determinism in society across institutions, incentives, and collective mythmaking",
            baseSize: AppHeadingRole.h1.fontSize,
            nextLevelSize: AppHeadingRole.h2.fontSize
        )

        #expect(shortSize == AppHeadingRole.h1.fontSize)
        #expect(shortSize > mediumSize)
        #expect(mediumSize > longSize)
        #expect(longSize > AppHeadingRole.h2.fontSize)
    }

    @Test("Markdown heading display uppercases H1 through H3 only")
    func markdownHeadingDisplayUppercasesFirstThreeLevels() {
        #expect(MarkdownHeadingDisplay.displayText("All Things Must Go", level: 1) == "ALL THINGS MUST GO")
        #expect(MarkdownHeadingDisplay.displayText("Sub Heading", level: 2) == "SUB HEADING")
        #expect(MarkdownHeadingDisplay.displayText("Third Level", level: 3) == "THIRD LEVEL")
        #expect(MarkdownHeadingDisplay.displayText("Fourth Level", level: 4) == "Fourth Level")
    }

    @Test("Icon composer package carries dark and tinted variants")
    func iconComposerSupportsDarkAndTinted() throws {
        let json = try loadIconComposerJSON()
        #expect(json.contains("\"appearance\" : \"dark\""))
        #expect(json.contains("\"appearance\" : \"tinted\""))
        #expect(json.contains("Gemini Generated Image 5 (4).png"))
    }

    @Test("Icon composer package keeps the authored six asset sources")
    func iconComposerKeepsAuthoredAssetSources() throws {
        let assetNames = try FileManager.default.contentsOfDirectory(
            atPath: repoRootURL().appendingPathComponent("Epistemos/AppIcon.icon/Assets").path
        )
        #expect(assetNames.count == 6)
        #expect(assetNames.contains("Gemini Generated Image 5 (4).png"))
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

    @Test("Project retains Rust bridge header wiring")
    func projectRetainsRustBridgeWiring() throws {
        let pbxproj = try loadProjectFile()
        #expect(pbxproj.contains("SWIFT_OBJC_BRIDGING_HEADER = \"Epistemos-Bridging-Header.h\";"))
        #expect(pbxproj.contains("\"\\\"$(SRCROOT)/graph-engine-bridge\\\"\","))
        #expect(pbxproj.contains("\"\\\"$(SRCROOT)/build-rust\\\"\","))
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
