import SwiftUI

struct ViewOriginalPDFAffordance: View {
    let page: SDPage
    let vaultURL: URL?
    var openOriginalPDF: (URL) -> Void = { _ in }

    private var originalPDFURL: URL? {
        guard page.frontMatter["source_kind"] == "pdf",
              let relativePath = page.frontMatter["source_pdf"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !relativePath.isEmpty,
              let vaultURL else {
            return nil
        }
        let url = vaultURL.appendingPathComponent(relativePath, isDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
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
