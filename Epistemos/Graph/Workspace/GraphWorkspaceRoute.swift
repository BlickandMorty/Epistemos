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
}
