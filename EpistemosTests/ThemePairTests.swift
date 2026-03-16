import Foundation
import SwiftUI
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
        #expect(EpistemosTheme.platinum.markdownHeadingAccentHex == 0x111111)
        #expect(EpistemosTheme.platinumDark.markdownHeadingAccentHex == 0xF2F2F2)
        #expect(EpistemosTheme.platinum.preferredMarkdownLinkHex == 0x111111)
        #expect(EpistemosTheme.platinumDark.preferredMarkdownLinkHex == nil)
        #expect(MarkdownHeadingDisplay.foregroundHex(for: .platinum, level: 1) == EpistemosTheme.platinum.headingAccentHex)
        #expect(MarkdownHeadingDisplay.foregroundHex(for: .platinumDark, level: 1) == EpistemosTheme.platinumDark.headingAccentHex)
        #expect(MarkdownHeadingDisplay.foregroundHex(for: .platinum, level: 2) == EpistemosTheme.platinum.markdownHeadingAccentHex)
        #expect(MarkdownHeadingDisplay.foregroundHex(for: .platinumDark, level: 2) == EpistemosTheme.platinumDark.markdownHeadingAccentHex)
        #expect(EpistemosTheme.platinum.assistantBubbleForegroundHex == EpistemosTheme.platinum.mutedForegroundHex)
        #expect(EpistemosTheme.platinumDark.assistantBubbleForegroundHex == EpistemosTheme.platinumDark.foregroundHex)
        #expect(EpistemosTheme.platinum.assistantBubbleBackgroundHex == nil)
        #expect(EpistemosTheme.platinumDark.assistantBubbleBackgroundHex == nil)
        #expect(EpistemosTheme.platinum.userBubbleBackgroundHex == 0x111111)
        #expect(EpistemosTheme.platinum.userBubbleText == Color(hex: 0xF2F2F2).opacity(0.94))
        #expect(EpistemosTheme.platinumDark.userBubbleBackgroundHex == 0x2A2A38)
        #expect(EpistemosTheme.platinumDark.userBubbleText == Color(hex: 0xF2F2F2).opacity(0.94))
    }

    @Test("Platinum Violet pair preserves the accented blue-violet variant")
    func platinumVioletPairMapping() {
        #expect(ThemePair.platinumViolet.lightTheme == .platinumViolet)
        #expect(ThemePair.platinumViolet.darkTheme == .platinumVioletDark)
        #expect(ThemePair.platinumViolet.resolved(isDark: false) == .platinumViolet)
        #expect(ThemePair.platinumViolet.resolved(isDark: true) == .platinumVioletDark)
        #expect(EpistemosTheme.platinumViolet.markdownHeadingAccentHex == 0x00007B)
        #expect(EpistemosTheme.platinumVioletDark.markdownHeadingAccentHex == 0x7B68EE)
        #expect(EpistemosTheme.platinumViolet.preferredMarkdownLinkHex == 0x00007B)
        #expect(EpistemosTheme.platinumVioletDark.preferredMarkdownLinkHex == nil)
        #expect(EpistemosTheme.platinumViolet.accent == Color(hex: 0x000080))
        #expect(EpistemosTheme.platinumVioletDark.accent == Color(hex: 0x7B68EE))
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

    @Test("App heading roles use the shared display scale")
    func appHeadingRolesUseSharedDisplayScale() {
        #expect(AppDisplayTypography.displayFontName == "RetroGaming")
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
        #expect(shortSize - mediumSize >= 2)
        #expect(shortSize - longSize >= 3)
        #expect(longSize > AppHeadingRole.h2.fontSize)
    }

    @Test("Markdown heading display uppercases H1 through H3 only")
    func markdownHeadingDisplayUppercasesFirstThreeLevels() {
        #expect(MarkdownHeadingDisplay.displayText("All Things Must Go", level: 1) == "ALL THINGS MUST GO")
        #expect(MarkdownHeadingDisplay.displayText("Sub Heading", level: 2) == "SUB HEADING")
        #expect(MarkdownHeadingDisplay.displayText("Third Level", level: 3) == "THIRD LEVEL")
        #expect(MarkdownHeadingDisplay.displayText("Fourth Level", level: 4) == "Fourth Level")
    }

    @Test("Markdown heading glow tapers from H1 to H3")
    func markdownHeadingGlowTapersByLevel() {
        #expect(MarkdownHeadingDisplay.glowRadius(for: 1) == 14)
        #expect(MarkdownHeadingDisplay.glowRadius(for: 2) == 10)
        #expect(MarkdownHeadingDisplay.glowRadius(for: 3) == 7)
        #expect(MarkdownHeadingDisplay.glowRadius(for: 4) == 0)
        #expect(MarkdownHeadingDisplay.shadowOpacity(for: .platinumDark, level: 1) == 0.38)
        #expect(MarkdownHeadingDisplay.shadowOpacity(for: .platinumDark, level: 2) == 0.24)
        #expect(MarkdownHeadingDisplay.shadowOpacity(for: .platinumDark, level: 3) == 0.18)
        #expect(MarkdownHeadingDisplay.overlayOpacity(for: .platinumDark, level: 1) == 0.34)
        #expect(MarkdownHeadingDisplay.overlayOpacity(for: .platinumDark, level: 2) == 0.22)
        #expect(MarkdownHeadingDisplay.overlayOpacity(for: .platinumDark, level: 3) == 0.16)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinum, level: 1) != nil)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinum, level: 2) != nil)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinum, level: 3) != nil)
        #expect(MarkdownHeadingDisplay.nsShadow(for: .platinum, level: 4) == nil)
    }

    @Test("Markdown preview heading glow stays softer than the editor heading glow")
    func markdownPreviewHeadingGlowStaysSoft() {
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 1) == 9)
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 2) == 6)
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 3) == 4)
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 4) == 0)
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 1) < MarkdownHeadingDisplay.glowRadius(for: 1))
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 2) < MarkdownHeadingDisplay.glowRadius(for: 2))
        #expect(MarkdownHeadingDisplay.previewGlowRadius(for: 3) < MarkdownHeadingDisplay.glowRadius(for: 3))
        #expect(MarkdownHeadingDisplay.previewOverlayOpacity(for: .platinumDark, level: 1) == 0.2)
        #expect(MarkdownHeadingDisplay.previewOverlayOpacity(for: .platinumDark, level: 2) == 0.12)
        #expect(MarkdownHeadingDisplay.previewOverlayOpacity(for: .platinumDark, level: 3) == 0.09)
    }

    @Test("Regular display mode keeps ripple-capable surfaces but drops retro display typography")
    func regularDisplayModePolicy() {
        #expect(AppDisplayMode.opulent.usesDisplayFont)
        #expect(!AppDisplayMode.opulent.reducesASCIIAnimations)
        #expect(!AppDisplayMode.regular.usesDisplayFont)
        #expect(AppDisplayMode.regular.reducesASCIIAnimations)
    }

    @Test("Regular display mode uses the macOS UI font family")
    func regularDisplayModeUsesMacOSUIFontFamily() {
        let font = AppDisplayTypography.regularUIFont(size: 13)

        #expect(font.fontName.hasPrefix(".SFNS"))
        #expect(AppDisplayTypography.isRegularUIFont(font))
        #expect(AppDisplayTypography.displayFontName == "RetroGaming")
    }

    @Test("Assistant chrome tokens keep the floating surface hierarchy intact")
    func assistantSurfaceMetricsStayCalm() {
        let palette = AssistantSurfaceMetrics.commandPalette
        let popout = AssistantSurfaceMetrics.popout

        #expect(palette.outerRadius == 30)
        #expect(palette.innerRadius == 24)
        #expect(palette.controlRadius == 18)
        #expect(palette.borderWidth == 0.72)
        #expect(palette.showsOuterStroke)
        #expect(palette.outerRadius > palette.innerRadius)
        #expect(palette.innerRadius > palette.controlRadius)
        #expect(popout.showsOuterStroke)
        #expect(popout.outerRadius == palette.outerRadius)
        #expect(popout.contentVerticalPadding > palette.contentVerticalPadding)
        #expect(popout.shadowRadius >= palette.shadowRadius)
    }

    @Test("Floating assistant surfaces follow the light and dark shell contrast rules")
    func floatingAssistantSurfacesUseThemeRelativeTints() {
        #expect(EpistemosTheme.light.floatingSurfaceTint == Color(hex: 0xF2F2F2))
        #expect(EpistemosTheme.tan.floatingSurfaceTint == Color(hex: 0xFBF5EB))
        #expect(EpistemosTheme.sunset.floatingSurfaceTint == Color(hex: 0x161018))
        #expect(EpistemosTheme.ember.floatingSurfaceTint == Color(hex: 0x16100C))
        #expect(EpistemosTheme.nocturne.floatingSurfaceTint == Color(hex: 0x141019))
        #expect(EpistemosTheme.oled.floatingSurfaceTint == Color(hex: 0x2A2A2F))
        #expect(EpistemosTheme.ember.floatingSurfaceTint != EpistemosTheme.ember.background)
        #expect(EpistemosTheme.nocturne.floatingSurfaceTint != EpistemosTheme.nocturne.background)
        #expect(EpistemosTheme.tan.floatingSurfaceTint != EpistemosTheme.tan.glassBg)
    }

    @Test("Main chat layout keeps the composer proportional to the message column")
    func mainChatLayoutStaysProportional() {
        #expect(ChatLayout.mainComposerMaxWidth == 940)
        #expect(ChatLayout.mainComposerHorizontalPadding == 12)
    }

    @Test("Main chat return key submits only when the composer is ready")
    func mainChatReturnSubmitsOnlyWhenReady() {
        #expect(
            ChatComposerKeyHandling.returnBehavior(
                modifierFlags: [],
                trimmedText: "hello",
                isProcessing: false
            ) == .submit
        )
        #expect(
            ChatComposerKeyHandling.returnBehavior(
                modifierFlags: [],
                trimmedText: "   ",
                isProcessing: false
            ) == .ignore
        )
        #expect(
            ChatComposerKeyHandling.returnBehavior(
                modifierFlags: [],
                trimmedText: "hello",
                isProcessing: true
            ) == .ignore
        )
    }

    @Test("Main chat shift return keeps multiline editing and clamps growth")
    func mainChatShiftReturnKeepsMultilineEditing() {
        #expect(
            ChatComposerKeyHandling.returnBehavior(
                modifierFlags: [.shift],
                trimmedText: "hello",
                isProcessing: false
            ) == .insertNewline
        )
        #expect(
            ChatComposerKeyHandling.returnBehavior(
                modifierFlags: [.option],
                trimmedText: "hello",
                isProcessing: false
            ) == .systemDefault
        )
        #expect(ChatComposerInputMetrics.maxVisibleLines == 8)
        #expect(ChatComposerInputMetrics.clampedHeight(for: 0) == ChatComposerInputMetrics.minHeight)
        #expect(
            ChatComposerInputMetrics.clampedHeight(
                for: ChatComposerInputMetrics.maxHeight + 40
            ) == ChatComposerInputMetrics.maxHeight
        )
    }

    @Test("Assistant input chrome stays glass-first without decorative tint or shadow")
    func assistantInputChromePrefersNativeGlass() {
        let input = AssistantGlassInputMetrics.default

        #expect(input.prefersGlassEffect)
        #expect(input.tintOpacity == 0)
        #expect(input.shadowOpacity == 0)
        #expect(input.shadowRadius == 0)
        #expect(input.activeBorderOpacity > input.idleBorderOpacity)
    }

    @Test("Markdown preview block chrome keeps the same dormant to hover surface hierarchy")
    func markdownPreviewBlockChromeMatchesHoverGlassSystem() {
        let metrics = MarkdownPreviewSurfaceMetrics.default

        #expect(metrics.cornerRadius == 0)
        #expect(metrics.borderWidth == 0.55)
        #expect(metrics.contentPadding == 12)
        #expect(metrics.verticalSpacing == 2)
        #expect(metrics.topEdgeWidth == 1)
        #expect(metrics.bottomEdgeWidth == 3)
        #expect(metrics.rightEdgeWidth == 1)
        #expect(MarkdownPreviewSurfaceStyle.borderOpacity(isDark: true) > MarkdownPreviewSurfaceStyle.borderOpacity(isDark: false))
    }

    @Test("Editor block chrome frame keeps the trailing edge flush without clipping content")
    func editorBlockChromeFrameUsesMinimalTrailingInset() {
        let origin = NSPoint(x: 8, y: 0)
        let frame = MarkdownTextStorage.blockChromeFrame(
            textContainerOrigin: origin,
            containerWidth: 600,
            boundsWidth: 700
        )

        let leadingInset = max(MarkdownTextStorage.bodyIndent - 8, 14)
        let availableWidth = min(600, max(0, 700 - (origin.x * 2)))
        let expectedWidth = availableWidth - leadingInset - MarkdownPreviewSurfaceMetrics.default.rightEdgeWidth

        #expect(frame.minX == origin.x + leadingInset)
        #expect(frame.width == expectedWidth)
    }

    @Test("Assistant composer metrics keep the main and compact chat bars aligned")
    func assistantComposerMetricsStayConsistent() {
        let main = AssistantComposerMetrics.mainChat
        let compact = AssistantComposerMetrics.compactChat

        #expect(main.cornerRadius == 18)
        #expect(main.sendButtonSize == 34)
        #expect(main.sendButtonSize < compact.sendButtonSize)
        #expect(main.shadowRadius == 0)
        #expect(main.shadowYOffset == 0)
        #expect(compact.shadowRadius == 0)
        #expect(compact.shadowYOffset == 0)
        #expect(main.borderWidth <= 0.8)
        #expect(compact.cornerRadius > main.cornerRadius)
        #expect(compact.horizontalPadding > main.horizontalPadding)
    }

    @Test("Landing search composer disables decorative glow for a native glass surface")
    func landingSearchComposerDisablesDecorativeGlow() {
        #expect(LandingSearchChromePolicy.showsGlow == false)
    }

    @Test("Bare until pressed chrome stays invisible until press or active selection")
    func bareUntilPressedChromePolicy() {
        #expect(
            NativeControlChromePolicy.bareUntilPressed.showsSurface(
                isHovered: false,
                isPressed: false,
                isActive: false
            ) == false
        )
        #expect(
            NativeControlChromePolicy.bareUntilPressed.showsSurface(
                isHovered: true,
                isPressed: false,
                isActive: false
            ) == false
        )
        #expect(
            NativeControlChromePolicy.bareUntilPressed.showsSurface(
                isHovered: false,
                isPressed: true,
                isActive: false
            )
        )
        #expect(
            NativeControlChromePolicy.bareUntilPressed.showsSurface(
                isHovered: false,
                isPressed: false,
                isActive: true
            )
        )
    }

    @Test("Research control no longer exposes a secondary options box in composer surfaces")
    func researchControlHidesSecondaryOptionsBox() {
        #expect(ResearchModeControl.showsSecondaryOptionsBox == false)
    }

    @Test("Toolbar control metrics stay compact and boxy inside the outer pill")
    func toolbarControlMetricsStayCompactAndBoxy() {
        let toolbar = NativeControlSystem.toolbar

        #expect(toolbar.height == 26)
        #expect(toolbar.cornerRadius == 8)
        #expect(toolbar.minHitWidth == 26)
        #expect(toolbar.cornerRadius < (toolbar.height / 2))
    }

    @Test("Graph force settings panel keeps the wider readable width")
    func graphForceSettingsPanelWidth() {
        #expect(GraphForceSettingsLayout.panelWidth == 320)
    }

    @Test("Assistant source extraction keeps notes and links in a stable unique order")
    func assistantSourceExtractionDeduplicatesNotesAndLinks() {
        let sources = AssistantSourceReference.extract(
            from: """
            See [Paper](https://example.com/paper) and https://example.com/paper plus
            https://notes.example.org/entry for more context.
            """,
            noteTitles: ["Brown Essays", "Brown Essays", "Field Notes"]
        )

        #expect(sources.count == 4)
        #expect(sources[0].kind == .note)
        #expect(sources[0].title == "Brown Essays")
        #expect(sources[1].title == "Field Notes")
        #expect(sources[2].url?.absoluteString == "https://example.com/paper")
        #expect(sources[2].subtitle == "example.com")
        #expect(sources[3].subtitle == "notes.example.org")
    }

    @MainActor
    @Test("UIState restores saved display mode from defaults")
    func uiStateRestoresDisplayMode() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: AppDisplayMode.defaultsKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: AppDisplayMode.defaultsKey)
            } else {
                defaults.removeObject(forKey: AppDisplayMode.defaultsKey)
            }
        }

        defaults.set(AppDisplayMode.regular.rawValue, forKey: AppDisplayMode.defaultsKey)

        let uiState = UIState()
        #expect(uiState.displayMode == .regular)
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
