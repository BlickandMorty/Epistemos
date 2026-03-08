import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - DocumentFormatBar
// Lightweight formatting toolbar for document mode.
// Actions target the live DocumentTextView directly instead of relying on the
// responder chain, which breaks easily once SwiftUI buttons steal focus.

struct DocumentFormatBar: View {
    weak var textView: DocumentTextView?
    let theme: EpistemosTheme

    var body: some View {
        HStack(spacing: 2) {
            Group {
                formatButton(icon: "bold", tooltip: "Bold") {
                    withTextView { $0.toggleBold() }
                }
                formatButton(icon: "italic", tooltip: "Italic") {
                    withTextView { $0.toggleItalic() }
                }
                formatButton(icon: "underline", tooltip: "Underline") {
                    withTextView { $0.toggleUnderline() }
                }
                formatButton(icon: "strikethrough", tooltip: "Strikethrough") {
                    withTextView { $0.toggleStrikethrough() }
                }
            }

            Divider().frame(height: 16).padding(.horizontal, 4)

            Menu {
                Button("Body") { applyHeading(level: 0) }
                Button("Heading 1") { applyHeading(level: 1) }
                Button("Heading 2") { applyHeading(level: 2) }
                Button("Heading 3") { applyHeading(level: 3) }
            } label: {
                Label("Heading", systemImage: "textformat.size")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 100)

            Divider().frame(height: 16).padding(.horizontal, 4)

            Group {
                formatButton(icon: "text.alignleft", tooltip: "Align Left") {
                    withTextView { $0.setParagraphAlignment(.left) }
                }
                formatButton(icon: "text.aligncenter", tooltip: "Center") {
                    withTextView { $0.setParagraphAlignment(.center) }
                }
                formatButton(icon: "text.alignright", tooltip: "Align Right") {
                    withTextView { $0.setParagraphAlignment(.right) }
                }
            }

            Divider().frame(height: 16).padding(.horizontal, 4)

            Group {
                formatButton(icon: "list.bullet", tooltip: "Bullet List") {
                    insertList(ordered: false)
                }
                formatButton(icon: "list.number", tooltip: "Numbered List") {
                    insertList(ordered: true)
                }
                formatButton(icon: "tablecells", tooltip: "Insert Table") {
                    insertTable()
                }
                formatButton(icon: "photo", tooltip: "Insert Image") {
                    insertImage()
                }
            }

            Spacer()

            formatButton(icon: "textformat", tooltip: "Fonts") {
                withTextView { tv in
                    NSFontManager.shared.target = tv
                    NSFontManager.shared.orderFrontFontPanel(nil)
                    NSFontPanel.shared.makeKeyAndOrderFront(nil)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.glassBg)
        .overlay(
            Rectangle()
                .fill(theme.border.opacity(0.5))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Button Helper

    private func formatButton(icon: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(ThemedToolbarButtonStyle(theme: theme))
        .help(tooltip)
    }

    private func withTextView(_ action: (DocumentTextView) -> Void) {
        guard let tv = textView else { return }
        tv.window?.makeFirstResponder(tv)
        action(tv)
    }

    // MARK: - Heading

    private func applyHeading(level: Int) {
        guard let tv = textView, let ts = tv.textStorage else { return }
        let range = tv.selectedRange()
        let paraRange = (tv.string as NSString).paragraphRange(for: range)

        let fontSize: CGFloat
        let weight: NSFont.Weight
        switch level {
        case 1: fontSize = 28; weight = .bold
        case 2: fontSize = 22; weight = .semibold
        case 3: fontSize = 18; weight = .medium
        default: fontSize = 16; weight = .regular
        }
        let font = NSFont.systemFont(ofSize: fontSize, weight: weight)

        ts.beginEditing()
        ts.addAttribute(.font, value: font, range: paraRange)
        ts.endEditing()
    }

    // MARK: - Lists

    private func insertList(ordered: Bool) {
        withTextView { tv in
            let prefix = ordered ? "1. " : "\u{2022} "
            tv.insertText(prefix, replacementRange: tv.selectedRange())
        }
    }

    // MARK: - Table

    static func insertTable(into tv: DocumentTextView, foregroundColor: NSColor) {
        guard let ts = tv.textStorage else { return }
        let table = NSTextTable()
        table.numberOfColumns = 3

        let result = NSMutableAttributedString()
        let font = NSFont.systemFont(ofSize: 14)

        for row in 0..<3 {
            for col in 0..<3 {
                let block = NSTextTableBlock(
                    table: table,
                    startingRow: row, rowSpan: 1,
                    startingColumn: col, columnSpan: 1)
                block.setWidth(1.0, type: .absoluteValueType, for: .border)
                block.setBorderColor(.separatorColor)
                block.setContentWidth(100, type: .absoluteValueType)

                let style = NSMutableParagraphStyle()
                style.textBlocks = [block]
                let cellText = row == 0 ? "Header" : "Cell"
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .paragraphStyle: style,
                    .foregroundColor: foregroundColor
                ]
                result.append(NSAttributedString(string: "\(cellText)\n", attributes: attrs))
            }
        }

        let insertPos = tv.selectedRange().location
        ts.beginEditing()
        ts.insert(result, at: insertPos)
        ts.endEditing()
    }

    private func insertTable() {
        withTextView { tv in
            Self.insertTable(into: tv, foregroundColor: NSColor(theme.foreground))
        }
    }

    // MARK: - Image

    private func insertImage() {
        guard let tv = textView else { return }
        tv.window?.makeFirstResponder(tv)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url,
                  let image = NSImage(contentsOf: url) else { return }
            let attachment = NSTextAttachment()
            let cell = NSTextAttachmentCell(imageCell: image)
            attachment.attachmentCell = cell
            let attrStr = NSAttributedString(attachment: attachment)
            tv.insertText(attrStr, replacementRange: tv.selectedRange())
        }
    }
}
