import SwiftUI

nonisolated enum LiteParseSourcePDFLink {
    private static let maxRelativePathCharacters = 4_096

    static func resolve(
        vaultURL: URL?,
        relativePath rawRelativePath: String?,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> URL? {
        guard let vaultURL,
              let rawRelativePath else {
            return nil
        }

        let boundedRelativePath = String(rawRelativePath.prefix(maxRelativePathCharacters + 1))
        guard boundedRelativePath.count <= maxRelativePathCharacters else {
            return nil
        }
        let relativePath = boundedRelativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/") else {
            return nil
        }

        let pathParts = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !pathParts.contains(where: { $0 == ".." || $0 == "." || $0.isEmpty }) else {
            return nil
        }

        let candidate = vaultURL.standardizedFileURL
            .appendingPathComponent(relativePath, isDirectory: false)
            .standardizedFileURL
        guard Plan3VaultPath.vaultRelativePath(for: candidate, in: vaultURL) != nil,
              fileExists(candidate.path) else {
            return nil
        }
        guard case .match = LiteParsePDFSignature.fileStartsWithPDFMagic(candidate.path) else {
            return nil
        }
        return candidate.resolvingSymlinksInPath()
    }
}

struct ViewOriginalPDFAffordance: View {
    private static let maxFileNameDisplayCharacters = 180

    let page: SDPage
    let vaultURL: URL?
    let openOriginalPDF: (URL) -> Void

    private var originalPDFURL: URL? {
        guard page.frontMatter["source_kind"] == "pdf",
              let url = LiteParseSourcePDFLink.resolve(
                vaultURL: vaultURL,
                relativePath: page.frontMatter["source_pdf"]
              ) else {
            return nil
        }
        return url
    }

    var body: some View {
        if let originalPDFURL {
            ToolbarCapsuleButton(
                title: "View original PDF",
                systemImage: "doc.richtext",
                role: .toolbarUtility,
                chromePolicy: .alwaysSurface,
                helpText: Self.displayFileName(originalPDFURL.lastPathComponent),
                accessibilityLabel: "View original PDF"
            ) {
                openOriginalPDF(originalPDFURL)
            }
        }
    }

    private static func displayFileName(_ fileName: String) -> String {
        let bounded = String(fileName.prefix(maxFileNameDisplayCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "PDF" }
        guard trimmed.count > maxFileNameDisplayCharacters else { return trimmed }
        return String(trimmed.prefix(maxFileNameDisplayCharacters - 3)) + "..."
    }
}
