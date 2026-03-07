import AppKit
import PDFKit
import UniformTypeIdentifiers

// MARK: - XML Escaping

extension String {
    /// Escapes the five XML special characters: & < > " '
    var xmlEscaped: String {
        var result = self
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&apos;")
        return result
    }

    /// Strips common Markdown syntax, returning plain text.
    var markdownStripped: String {
        var s = self

        // Bold: **text** or __text__
        s = s.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: #"__(.+?)__"#, with: "$1", options: .regularExpression)

        // Italic: *text* or _text_  (single markers, after bold is removed)
        s = s.replacingOccurrences(of: #"\*(.+?)\*"#, with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\b_(.+?)_\b"#, with: "$1", options: .regularExpression)

        // Strikethrough: ~~text~~
        s = s.replacingOccurrences(of: #"~~(.+?)~~"#, with: "$1", options: .regularExpression)

        // Inline code: `code`
        s = s.replacingOccurrences(of: #"`(.+?)`"#, with: "$1", options: .regularExpression)

        // Links: [text](url)
        s = s.replacingOccurrences(of: #"\[(.+?)\]\(.+?\)"#, with: "$1", options: .regularExpression)

        // Headings: lines starting with # (up to 6 levels)
        s = s.replacingOccurrences(of: #"(?m)^#{1,6}\s+"#, with: "", options: .regularExpression)

        return s
    }
}

// MARK: - WriterExportService

/// A namespace for document export functionality. No instances — all methods are static.
@MainActor
enum WriterExportService {

    // MARK: - Main Entry Point

    static func export(
        format: ExportFormat,
        title: String,
        body: String,
        formatState: WriterFormatState
    ) {
        switch format {
        case .pdf:
            exportPDF(title: title, body: body, formatState: formatState)
        case .docx:
            exportDOCX(title: title, body: body, formatState: formatState)
        case .plainText:
            exportPlainText(title: title, body: body)
        case .markdown:
            exportMarkdown(title: title, body: body)
        }
    }

    // MARK: - PDF Export

    /// Generates a PDFDocument from the given body and format state.
    /// Used by both the file export path and the preview.
    static func generatePDFDocument(
        body: String,
        formatState: WriterFormatState
    ) -> PDFDocument? {
        // Create a temporary TextKit stack for clean PDF rendering
        let storage = NSTextStorage(string: body.markdownStripped)
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = false
        storage.addLayoutManager(layoutManager)

        let pageSize = formatState.pageSize.size
        let textAreaSize = formatState.textAreaSize
        let marginPoints = formatState.margins.points

        // Apply formatting
        let font = NSFont(name: formatState.fontFamily, size: formatState.fontSize)
            ?? NSFont.systemFont(ofSize: formatState.fontSize)
        let paraStyle = NSMutableParagraphStyle()
        let baselineSpacing = font.pointSize * (formatState.lineSpacing.multiplier - 1.0)
        paraStyle.lineSpacing = baselineSpacing
        paraStyle.alignment = formatState.alignment
        if formatState.firstLineIndent > 0 {
            paraStyle.firstLineHeadIndent = formatState.firstLineIndent
        }
        // Paragraph spacing for double-newline breaks
        paraStyle.paragraphSpacing = font.pointSize * 0.5

        let fullRange = NSRange(location: 0, length: storage.length)
        storage.addAttributes([
            .font: font,
            .foregroundColor: NSColor.black,
            .paragraphStyle: paraStyle,
        ], range: fullRange)

        // Create text containers until all text is laid out
        var containers: [NSTextContainer] = []
        var allLaidOut = false
        while !allLaidOut {
            let container = NSTextContainer(size: textAreaSize)
            container.widthTracksTextView = false
            container.heightTracksTextView = false
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            containers.append(container)
            layoutManager.ensureLayout(for: container)

            let glyphRange = layoutManager.glyphRange(for: container)
            let charRange = layoutManager.characterRange(
                forGlyphRange: glyphRange, actualGlyphRange: nil)
            if charRange.location + charRange.length >= storage.length
                || glyphRange.length == 0
            {
                allLaidOut = true
            }
        }

        // Render to PDF
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        let pdfData = NSMutableData()

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return nil }

        for (index, container) in containers.enumerated() {
            let glyphRange = layoutManager.glyphRange(for: container)
            guard glyphRange.length > 0 || index == 0 else { continue }

            context.beginPDFPage(nil)

            // Flip coordinates: CoreGraphics origin is bottom-left,
            // NSLayoutManager drawing expects top-left.
            context.translateBy(x: 0, y: pageSize.height)
            context.scaleBy(x: 1, y: -1)

            let graphicsContext = NSGraphicsContext(cgContext: context, flipped: true)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = graphicsContext

            // White page background
            NSColor.white.setFill()
            NSRect(origin: .zero, size: pageSize).fill()

            // Draw text at margin offset
            let origin = NSPoint(x: marginPoints, y: marginPoints)
            layoutManager.drawBackground(forGlyphRange: glyphRange, at: origin)
            layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: origin)

            // Page number
            if formatState.showPageNumbers {
                let pageNum = index + 1
                let numStr: String
                if !formatState.runningHead.isEmpty {
                    numStr = "\(formatState.runningHead) \(pageNum)"
                } else {
                    numStr = "\(pageNum)"
                }
                let numFont = NSFont(name: formatState.fontFamily, size: formatState.fontSize - 2)
                    ?? NSFont.systemFont(ofSize: formatState.fontSize - 2)
                let numAttrs: [NSAttributedString.Key: Any] = [
                    .font: numFont,
                    .foregroundColor: NSColor.black,
                ]
                let attrStr = NSAttributedString(string: numStr, attributes: numAttrs)
                let size = attrStr.size()

                // Position based on format state
                let pos = formatState.pageNumberPosition
                let y: CGFloat
                let x: CGFloat

                switch pos {
                case .topLeft, .topCenter, .topRight:
                    y = (marginPoints - size.height) / 2
                case .bottomLeft, .bottomCenter, .bottomRight:
                    y = pageSize.height - marginPoints + (marginPoints - size.height) / 2
                }

                switch pos {
                case .topLeft, .bottomLeft:
                    x = marginPoints
                case .topCenter, .bottomCenter:
                    x = (pageSize.width - size.width) / 2
                case .topRight, .bottomRight:
                    x = pageSize.width - marginPoints - size.width
                }

                attrStr.draw(at: NSPoint(x: x, y: y))
            }

            // Header text
            if !formatState.headerText.isEmpty {
                let headerAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont(name: formatState.fontFamily, size: formatState.fontSize - 2)
                        ?? NSFont.systemFont(ofSize: formatState.fontSize - 2),
                    .foregroundColor: NSColor.black,
                ]
                let attrStr = NSAttributedString(string: formatState.headerText, attributes: headerAttrs)
                let size = attrStr.size()
                let x = (pageSize.width - size.width) / 2
                let y = (marginPoints - size.height) / 2
                attrStr.draw(at: NSPoint(x: x, y: y))
            }

            // Footer text
            if !formatState.footerText.isEmpty {
                let footerAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont(name: formatState.fontFamily, size: formatState.fontSize - 2)
                        ?? NSFont.systemFont(ofSize: formatState.fontSize - 2),
                    .foregroundColor: NSColor.black,
                ]
                let attrStr = NSAttributedString(string: formatState.footerText, attributes: footerAttrs)
                let size = attrStr.size()
                let x = (pageSize.width - size.width) / 2
                let y = pageSize.height - marginPoints + (marginPoints - size.height) / 2
                attrStr.draw(at: NSPoint(x: x, y: y))
            }

            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
        }

        context.closePDF()
        return PDFDocument(data: pdfData as Data)
    }

    private static func exportPDF(
        title: String,
        body: String,
        formatState: WriterFormatState
    ) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(title).pdf"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let pdfDocument = generatePDFDocument(body: body, formatState: formatState)
            else { return }
            pdfDocument.write(to: url)
        }
    }

    // MARK: - DOCX Export

    private static func exportDOCX(
        title: String,
        body: String,
        formatState: WriterFormatState
    ) {
        let docxType = UTType(filenameExtension: "docx") ?? .data
        let panel = NSSavePanel()
        panel.allowedContentTypes = [docxType]
        panel.nameFieldStringValue = "\(title).docx"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            let fm = FileManager.default
            let tmpDir = fm.temporaryDirectory
                .appendingPathComponent("epistemos-docx-\(UUID().uuidString)")

            do {
                // Create directory structure
                let wordDir = tmpDir.appendingPathComponent("word")
                let relsDir = tmpDir.appendingPathComponent("_rels")
                let wordRelsDir = wordDir.appendingPathComponent("_rels")

                try fm.createDirectory(at: wordRelsDir, withIntermediateDirectories: true)
                try fm.createDirectory(at: relsDir, withIntermediateDirectories: true)

                // [Content_Types].xml
                let contentTypes = """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
                  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
                  <Default Extension="xml" ContentType="application/xml"/>
                  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
                  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
                </Types>
                """
                try contentTypes.write(
                    to: tmpDir.appendingPathComponent("[Content_Types].xml"),
                    atomically: true, encoding: .utf8)

                // _rels/.rels
                let topRels = """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
                </Relationships>
                """
                try topRels.write(
                    to: relsDir.appendingPathComponent(".rels"),
                    atomically: true, encoding: .utf8)

                // word/_rels/document.xml.rels
                let wordRels = """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
                </Relationships>
                """
                try wordRels.write(
                    to: wordRelsDir.appendingPathComponent("document.xml.rels"),
                    atomically: true, encoding: .utf8)

                // word/styles.xml
                let fontName = formatState.fontFamily.xmlEscaped
                let halfPoints = Int(formatState.fontSize * 2)
                let lineSpacingTwips = Int(formatState.lineSpacing.multiplier * 240)

                let stylesXML = """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                  <w:docDefaults>
                    <w:rPrDefault>
                      <w:rPr>
                        <w:rFonts w:ascii="\(fontName)" w:hAnsi="\(fontName)"/>
                        <w:sz w:val="\(halfPoints)"/>
                        <w:szCs w:val="\(halfPoints)"/>
                      </w:rPr>
                    </w:rPrDefault>
                    <w:pPrDefault>
                      <w:pPr>
                        <w:spacing w:line="\(lineSpacingTwips)" w:lineRule="auto"/>
                      </w:pPr>
                    </w:pPrDefault>
                  </w:docDefaults>
                </w:styles>
                """
                try stylesXML.write(
                    to: wordDir.appendingPathComponent("styles.xml"),
                    atomically: true, encoding: .utf8)

                // word/document.xml
                let indentTwips = Int(formatState.firstLineIndent * 20)
                let alignment: String = {
                    switch formatState.alignment {
                    case .center:    return "center"
                    case .right:     return "right"
                    case .justified: return "both"
                    default:         return "left"
                    }
                }()

                let pageWidthTwips = Int(formatState.pageSize.size.width * 20)
                let pageHeightTwips = Int(formatState.pageSize.size.height * 20)
                let marginTwips = Int(formatState.margins.points * 20)

                // Split body into paragraphs on double-newline
                let paragraphs = body.components(separatedBy: "\n\n")
                let paragraphsXML = paragraphs.map { para in
                    let escapedText = para.markdownStripped.xmlEscaped
                    return """
                          <w:p>
                            <w:pPr>
                              <w:ind w:firstLine="\(indentTwips)"/>
                              <w:jc w:val="\(alignment)"/>
                            </w:pPr>
                            <w:r><w:t xml:space="preserve">\(escapedText)</w:t></w:r>
                          </w:p>
                    """
                }.joined(separator: "\n")

                let documentXML = """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                  <w:body>
                \(paragraphsXML)
                    <w:sectPr>
                      <w:pgSz w:w="\(pageWidthTwips)" w:h="\(pageHeightTwips)"/>
                      <w:pgMar w:top="\(marginTwips)" w:right="\(marginTwips)" w:bottom="\(marginTwips)" w:left="\(marginTwips)"/>
                    </w:sectPr>
                  </w:body>
                </w:document>
                """
                try documentXML.write(
                    to: wordDir.appendingPathComponent("document.xml"),
                    atomically: true, encoding: .utf8)

                // Zip from within the temp directory so paths are root-relative
                let process = Process()
                process.currentDirectoryURL = tmpDir
                process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                process.arguments = ["-r", "-q", url.path, "."]
                try process.run()
                process.waitUntilExit()

                // Clean up temp directory
                try? fm.removeItem(at: tmpDir)

            } catch {
                // Clean up on failure
                try? fm.removeItem(at: tmpDir)
            }
        }
    }

    // MARK: - Plain Text Export

    private static func exportPlainText(title: String, body: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(title).txt"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let plainText = body.markdownStripped
                try? plainText.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    // MARK: - Markdown Export

    private static func exportMarkdown(title: String, body: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(title).md"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? body.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
