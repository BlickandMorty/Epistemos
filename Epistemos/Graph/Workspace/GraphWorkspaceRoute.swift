import Foundation

/// Defines the declarative navigation state within the Epistemos graph workspace.
/// Handled locally by `GraphState` instead of bloating the global App Router.
enum GraphWorkspaceRoute: Equatable, Sendable {
    /// The primary 3D visualizer interaction view.
    case canvas
    /// A graph-native editor surface for a specific document node.
    case note(id: String)
    /// A graph-native file tree surface for a specific directory node.
    case folder(id: String)

    var isCanvas: Bool {
        if case .canvas = self { return true }
        return false
    }

    /// Stable string key for FFI serialization (Rust `GraphContext.graph_route`).
    var serializationKey: String {
        switch self {
        case .canvas: "canvas"
        case .note(let id): "note:\(id)"
        case .folder(let id): "folder:\(id)"
        }
    }
}

extension Notification.Name {
    /// Posted by `GraphState` whenever the graph workspace route history
    /// advances, retreats, or is replaced. Observers in the Hologram overlay
    /// layer use this to toggle the SwiftUI page host's hit-testing so the
    /// Metal canvas receives mouse events while on `.canvas`.
    static let graphRouteDidChange = Notification.Name("epistemos.graphRouteDidChange")

    /// Posted by `GraphState.graphViewLocation.didSet` when the user
    /// changes the "where does Cmd+G open the graph" setting. The
    /// home content router (`UIState.homeContent`) listens so it can
    /// close the embedded graph when the user flips to `.miniPanel`
    /// mid-session.
    static let graphViewLocationDidChange = Notification.Name("epistemos.graphViewLocationDidChange")
}
