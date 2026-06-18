import Foundation

/// P6.4 (item 3) — the canonical order + grouping of the Appearance settings
/// pane. Pure + `nonisolated` so the grouping invariants are unit-testable
/// without the SwiftUI Form. `AppearanceDetailContainer.appearanceForm` renders
/// its sections in this exact order; the test locks the declutter intent
/// (look-and-feel sections grouped first, the graph trio contiguous after,
/// nothing duplicated) so a future reorder can't silently re-fragment the pane.
///
/// Decluttering rule: this only ORDERS and GROUPS sections — it never removes
/// one. Every real setting stays reachable.
nonisolated enum AppearanceSection: String, CaseIterable, Sendable {
    case themes
    case customTheme
    case typography
    case editor
    case graphNodeTypes
    case graphPerformance
    case shapedGraph

    /// Which visual group a section belongs to. Look-and-feel (theme, type,
    /// editor) is what users come to "Appearance" for; the graph visuals form a
    /// distinct, contiguous block.
    enum Group: String, Sendable, CaseIterable {
        case lookAndFeel
        case graph
    }

    var group: Group {
        switch self {
        case .themes, .customTheme, .typography, .editor:
            return .lookAndFeel
        case .graphNodeTypes, .graphPerformance, .shapedGraph:
            return .graph
        }
    }

    /// The sections in canonical render order: all look-and-feel sections first,
    /// then the graph trio. (`customTheme` only renders when the custom pair is
    /// active — the order still holds when it's omitted.)
    static let canonical: [AppearanceSection] = [
        .themes, .customTheme, .typography, .editor,
        .graphNodeTypes, .graphPerformance, .shapedGraph,
    ]
}
