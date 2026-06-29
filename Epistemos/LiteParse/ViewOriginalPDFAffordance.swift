import SwiftUI

nonisolated enum LiteParseSourcePDFLink {
    static func resolve(
        vaultURL: URL?,
        relativePath rawRelativePath: String?,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> URL? {
        guard let vaultURL,
              let rawRelativePath else {
            return nil
        }

        let relativePath = rawRelativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/") else {
            return nil
        }

        let pathParts = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !pathParts.contains("..") else {
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
            Button {
                openOriginalPDF(originalPDFURL)
            } label: {
                Label("View original PDF", systemImage: "doc.richtext")
            }
            .help(originalPDFURL.lastPathComponent)
        }
    }
}
