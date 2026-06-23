//
//  EpistemosOsaurusSourceSkin.swift
//  OsaurusCore
//
//  Source-level Epistemos skin for the cloned Osaurus chat surface.
//

import SwiftUI

@MainActor
final class EpistemosOsaurusSourceSkin: ObservableObject {
    static let shared = EpistemosOsaurusSourceSkin()

    @Published private(set) var activeTokens: EpistemosOsaurusThemeTokens?
    @Published private(set) var activeTheme: CustomizableTheme?

    var isActive: Bool { activeTheme != nil }
    var accessibilitySummary: String {
        guard let tokens = activeTokens else { return "inactive" }
        return [
            tokens.id,
            tokens.isDark ? "dark" : "light",
            tokens.primaryBackground,
            tokens.inputBackground,
            tokens.accentColor,
            tokens.monoFont,
        ].joined(separator: " | ")
    }

    private init() {}

    func apply(_ tokens: EpistemosOsaurusThemeTokens) {
        guard activeTokens?.signature != tokens.signature else { return }
        activeTokens = tokens
        activeTheme = CustomizableTheme(config: tokens.customTheme)
    }
}
