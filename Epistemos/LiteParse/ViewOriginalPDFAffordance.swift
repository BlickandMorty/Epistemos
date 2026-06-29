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

        let lexicalVault = vaultURL.standardizedFileURL
        let lexicalCandidate = lexicalVault
            .appendingPathComponent(relativePath, isDirectory: false)
            .standardizedFileURL
        let lexicalVaultPath = directoryPrefix(for: lexicalVault)
        guard lexicalCandidate.path.hasPrefix(lexicalVaultPath),
              fileExists(lexicalCandidate.path) else {
            return nil
        }

        let resolvedVault = lexicalVault.resolvingSymlinksInPath()
        let resolvedCandidate = lexicalCandidate.resolvingSymlinksInPath()
        let resolvedVaultPath = directoryPrefix(for: resolvedVault)
        guard resolvedCandidate.path.hasPrefix(resolvedVaultPath) else {
            return nil
        }
        return resolvedCandidate
    }

    private static func directoryPrefix(for url: URL) -> String {
        url.path.hasSuffix("/") ? url.path : url.path + "/"
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
