import AppKit

// MARK: - DocumentImportExport
// Native DOCX and PDF import/export using NSAttributedString.

enum DocumentImportExport {

    /// Import a rich text file (.docx, .rtf, .rtfd, .txt, .md) and return attributed string.
    static func importDocument(from url: URL) throws -> NSAttributedString {
        try NSAttributedString(url: url, options: [:], documentAttributes: nil)
    }

    /// Export attributed string to DOCX data.
    static func exportDOCX(_ content: NSAttributedString) throws -> Data {
        let range = NSRange(location: 0, length: content.length)
        return try content.data(from: range, documentAttributes: [
            .documentType: NSAttributedString.DocumentType.officeOpenXML
        ])
    }

    /// Export attributed string to PDF data using NSTextView rendering.
    static func exportPDF(_ content: NSAttributedString, pageSize: NSSize = NSSize(width: 612, height: 792)) -> Data? {
        let contentWidth = pageSize.width - 144  // 72pt margins
        let tv = NSTextView(frame: NSRect(origin: .zero, size: NSSize(
            width: contentWidth,
            height: 10000
        )))
        tv.textStorage?.setAttributedString(content)
        tv.textContainer?.containerSize = NSSize(width: contentWidth, height: .greatestFiniteMagnitude)
        tv.layoutManager?.ensureLayout(forCharacterRange: NSRange(location: 0, length: content.length))

        if let lm = tv.layoutManager, let tc = tv.textContainer {
            let usedRect = lm.usedRect(for: tc)
            tv.frame = NSRect(origin: .zero, size: NSSize(
                width: contentWidth,
                height: usedRect.height + 144
            ))
        }

        return tv.dataWithPDF(inside: tv.bounds)
    }
}
