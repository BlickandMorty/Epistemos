import Foundation

nonisolated enum HTMLWorkspaceRegenerateContextPresentation {
    static func systemImage(for contextKind: String) -> String {
        let kind = contextKind.lowercased()
        if kind.contains("provenance") || kind.contains("claim") { return "checkmark.shield" }
        if kind.contains("pdf") { return "doc.richtext" }
        if kind.contains("meeting") { return "person.2" }
        if kind.contains("web") || kind.contains("clip") { return "globe" }
        if kind.contains("capture") { return "tray.full" }
        if kind.contains("chat") { return "bubble.left.and.text.bubble.right" }
        if kind.contains("graph") || kind.contains("related") { return "point.3.connected.trianglepath.dotted" }
        if kind.contains("folder") { return "folder" }
        return "doc.text"
    }
}
