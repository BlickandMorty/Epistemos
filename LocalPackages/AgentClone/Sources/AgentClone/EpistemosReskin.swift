import SwiftUI
import AppKit

/// Epistemos reskin palette + fonts for the embedded agent UI.
///
/// The goal is the owner's old ChatView ontology: theme-aware, sparse, flat
/// OpenCode-like chrome while assistant prose stays in the transcript renderer.
/// Colors are injected from the host Epistemos theme at mount via
/// `configure(...)`, falling back to native macOS semantic colors when unset.
///
/// USAGE
///   • User/composer/tool chrome → `AgentSkin.mono(size, weight)`.
///   • Short labels / titles → `AgentSkin.pixel(size)`.
///   • Theme-aware palette → `AgentSkin.bg / .surface / .border / .text / .textDim / .accent`.
///
/// Semantic STATUS colors (green=running, red=error, yellow/orange=warning) are intentionally
/// NOT defined here — those live in `AgentViewModel/Core/Colors.swift` and stay vivid.
public enum AgentSkin {

    // MARK: - Fonts

    /// Monospaced user/composer/tool chrome. Assistant prose is rendered elsewhere.
    public static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Slightly heavier monospaced label font for compact chrome.
    public static func pixel(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }

    // MARK: - Theme-aware palette (injected from Epistemos; native-semantic defaults)

    nonisolated(unsafe) public static var bg: Color = Color(nsColor: .windowBackgroundColor)
    nonisolated(unsafe) public static var surface: Color = Color(nsColor: .controlBackgroundColor)
    nonisolated(unsafe) public static var border: Color = Color(nsColor: .separatorColor)
    nonisolated(unsafe) public static var text: Color = Color(nsColor: .labelColor)
    nonisolated(unsafe) public static var textDim: Color = Color(nsColor: .secondaryLabelColor)
    nonisolated(unsafe) public static var accent: Color = Color.accentColor
    nonisolated(unsafe) public static var nsText: NSColor = .labelColor
    nonisolated(unsafe) public static var nsTextDim: NSColor = .secondaryLabelColor

    /// Inject the host Epistemos theme so the embedded UI matches the active app theme.
    @MainActor
    public static func configure(
        bg: Color,
        surface: Color,
        border: Color,
        text: Color,
        textDim: Color,
        accent: Color
    ) {
        Self.bg = bg
        Self.surface = surface
        Self.border = border
        Self.text = text
        Self.textDim = textDim
        Self.accent = accent
        Self.nsText = NSColor(text)
        Self.nsTextDim = NSColor(textDim)
    }

    // MARK: - Radius (compact AppKit chat chrome — no liquid-glass pilliness)

    public static let radius: CGFloat = 5
}
