import AppKit
import SwiftUI

struct CodeFileIconView: View {
    let filePath: String?
    let language: String
    let theme: EpistemosTheme

    var body: some View {
        Group {
            if let icon = CodeFileIconResolver.icon(forFilePath: filePath) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: CodeFileIconResolver.fallbackSymbol(for: language))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.resolved.accent.color)
            }
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }
}

enum CodeFileIconResolver {
    static func icon(forFilePath filePath: String?) -> NSImage? {
        guard let filePath,
              !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let icon = (NSWorkspace.shared.icon(forFile: filePath).copy() as? NSImage)
            ?? NSWorkspace.shared.icon(forFile: filePath)
        icon.size = NSSize(width: 18, height: 18)
        return icon
    }

    static func fallbackSymbol(for language: String) -> String {
        switch language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "swift":
            "swift"
        case "rust":
            "gearshape.2.fill"
        case "python":
            "curlybraces"
        case "javascript", "typescript":
            "chevron.left.forwardslash.chevron.right"
        case "json":
            "curlybraces.square"
        case "html":
            "safari"
        case "css":
            "paintpalette"
        case "bash":
            "terminal"
        case "go":
            "bolt.horizontal"
        default:
            "doc.text"
        }
    }
}
