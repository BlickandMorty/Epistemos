import AppKit
import SwiftUI
import Testing
@testable import Epistemos

@Suite("ResolvedTheme")
struct ResolvedThemeTests {
    @Test("resolved cache returns stable values for every theme case")
    func resolvedCacheReturnsStableValues() {
        for theme in EpistemosTheme.allCases {
            #expect(theme.resolved == theme.resolved)
        }
    }

    @Test("resolved cache matches public theme tokens for key UI surfaces")
    func resolvedCacheMatchesPublicThemeTokens() {
        let themes: [EpistemosTheme] = [.systemLight, .systemDark, .magnolia, .sunset, .platinumVioletDark]

        for theme in themes {
            #expect(theme.resolved.isDark == theme.isDark)
            #expect(theme.resolved.usesNativeWindowBlur == theme.usesNativeWindowBlur)
            #expect(theme.resolved.foregroundHex == theme.foregroundHex)
            #expect(theme.resolved.headingAccentHex == theme.headingAccentHex)
            #expect(theme.resolved.markdownHeadingAccentHex == theme.markdownHeadingAccentHex)
            #expect(theme.resolved.preferredMarkdownLinkHex == theme.preferredMarkdownLinkHex)
            #expect(theme.resolved.muted.color == theme.muted)
            #expect(theme.resolved.mutedForeground.color == theme.mutedForeground)
            #expect(theme.resolved.border.color == theme.border)
            #expect(theme.resolved.glassBg.color == theme.glassBg)
            #expect(theme.resolved.floatingSurfaceTint.color == theme.floatingSurfaceTint)
            #expect(theme.resolved.userBubbleBg.color == theme.userBubbleBg)
            #expect(theme.resolved.userBubbleText.color == theme.userBubbleText)
            #expect(theme.resolved.assistantBubbleForeground.color == theme.assistantBubbleForeground)
            #expect(theme.resolved.assistantBubbleBackground?.color == theme.assistantBubbleBackgroundHex.map { Color(hex: $0) })
            #expect(theme.resolved.preferredMarkdownLink?.color == theme.preferredMarkdownLinkColor)
            #expect(theme.resolved.nsBackground.nsColor == theme.nsBackground)
        }
    }

    @Test("legacy theme compatibility shims are removed")
    func legacyThemeCompatibilityShimsAreRemoved() throws {
        let source = try loadRepoTextFile("Epistemos/Theme/EpistemosTheme.swift")

        #expect(source.contains("nonisolated private static let resolvedCache"))
        #expect(source.contains("nonisolated var resolved: ResolvedTheme"))
        #expect(!source.contains(#"@available(*, deprecated, message: "Use theme.resolved.background.color")"#))
        #expect(!source.contains(#"@available(*, deprecated, message: "Use theme.resolved.foreground.color")"#))
        #expect(!source.contains(#"@available(*, deprecated, message: "Use theme.resolved.accent.color")"#))
        #expect(!source.contains("var background: Color"))
        #expect(!source.contains("var foreground: Color"))
        #expect(!source.contains("var accent: Color"))
    }

    @Test("native button styling paths use resolved theme tokens directly")
    func nativeButtonStylesUseResolvedTokens() throws {
        let source = try loadRepoTextFile("Epistemos/Theme/NativeButtonStyles.swift")

        #expect(source.contains("let resolved = theme.resolved"))
        #expect(source.contains("let accent = resolved.accent.color"))
        #expect(source.contains("let foreground = resolved.foreground.color"))
        #expect(!source.contains("return theme.accent"))
        #expect(!source.contains("return theme.foreground"))
    }

    @Test("editor and shared markdown hot paths use resolved theme tokens directly")
    func hotThemePathsUseResolvedTokens() throws {
        let proseSource = try loadRepoTextFile("Epistemos/Views/Notes/ProseTextView2.swift")
        let storageSource = try loadRepoTextFile("Epistemos/Views/Notes/MarkdownContentStorage.swift")
        let markdownSource = try loadRepoTextFile("Epistemos/Views/Shared/MarkdownTextView.swift")
        let glassSource = try loadRepoTextFile("Epistemos/Theme/GlassModifiers.swift")

        #expect(proseSource.contains("theme.resolved.foreground.nsColor"))
        #expect(!proseSource.contains("NSColor(theme.foreground)"))

        #expect(storageSource.contains("let resolved = theme.resolved"))
        #expect(!storageSource.contains("NSColor(theme.foreground)"))
        #expect(!storageSource.contains("NSColor(theme.fontAccent)"))

        #expect(markdownSource.contains("theme.resolved.background.color"))
        #expect(markdownSource.contains("theme.resolved.foreground.color"))
        #expect(markdownSource.contains("theme.resolved.accent.color"))

        #expect(glassSource.contains("theme.resolved.background.color"))
        #expect(glassSource.contains("theme.resolved.foreground.color"))
        #expect(glassSource.contains("theme.resolved.accent.color"))
    }

    @Test("app source no longer uses direct theme background foreground accent compatibility shims")
    func appSourceAvoidsDirectThemeCompatibilityShims() throws {
        let repoRoot = repoRootURL()
        let appRoot = repoRoot.appendingPathComponent("Epistemos")
        let enumerator = FileManager.default.enumerator(
            at: appRoot,
            includingPropertiesForKeys: nil
        )

        var offenders: [String] = []
        let pattern = #"theme\.(background|foreground|accent)\b"#

        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "swift" else { continue }
            if fileURL.lastPathComponent == "EpistemosTheme.swift" { continue }

            let source = try String(contentsOf: fileURL, encoding: .utf8)
            if source.range(of: pattern, options: .regularExpression) != nil {
                offenders.append(fileURL.path.replacingOccurrences(of: repoRoot.path + "/", with: ""))
            }
        }

        let offenderList = offenders.joined(separator: ", ")
        #expect(offenders.isEmpty, "Direct theme shim reads remain in: \(offenderList)")
    }

    private func repoRootURL() -> URL {
        let testsFileURL = URL(fileURLWithPath: #filePath)
        return testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        try String(
            contentsOf: repoRootURL().appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
