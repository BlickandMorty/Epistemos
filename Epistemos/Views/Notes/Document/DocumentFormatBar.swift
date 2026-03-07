import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - DocumentFormatBar
// Toolbar for Document mode (TextKit 2 WYSIWYG). Covers typography,
// headings, alignment, and DOCX import/export.

struct DocumentFormatBar: View {

    @Bindable var formatState: DocumentFormatState
    let isDark: Bool
    let onApplyFormat: () -> Void
    let onImportDOCX: () -> Void
    let onExportDOCX: () -> Void

    // MARK: Static Font Lists

    private static let preferredFonts: [String] = [
        "New York", "Times New Roman", "Palatino", "Georgia",
        "Garamond", "Arial", "Calibri", "Courier New", "Cambria"
    ].filter { NSFont(name: $0, size: 12) != nil }

    private static let systemFonts: [String] = NSFontManager.shared
        .availableFontFamilies
        .filter { !preferredFonts.contains($0) }
        .sorted()

    private static let fontSizes: [CGFloat] = [10, 11, 12, 13, 14, 16, 18, 20, 24, 28, 32, 36]

    // MARK: Body

    var body: some View {
        HStack(spacing: 6) {
            headingPicker
            Divider().frame(height: 20)
            typographyGroup
            Divider().frame(height: 20)
            alignmentPicker
            Spacer()
            importExportGroup
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.separator)
                .frame(height: 0.5)
        }
    }

    // MARK: - Heading Picker

    private var headingPicker: some View {
        Picker("Style", selection: $formatState.headingLevel) {
            ForEach(DocumentFormatState.HeadingLevel.allCases, id: \.self) { level in
                Text(level.rawValue).tag(level)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 110)
        .labelsHidden()
        .onChange(of: formatState.headingLevel) { _, _ in onApplyFormat() }
    }

    // MARK: - Typography Group

    private var typographyGroup: some View {
        HStack(spacing: 4) {
            fontPicker
            fontSizePicker
            boldToggle
            italicToggle
            underlineToggle
            strikethroughToggle
        }
    }

    private var fontPicker: some View {
        Picker("Font", selection: $formatState.fontFamily) {
            if !Self.preferredFonts.isEmpty {
                Section("Preferred") {
                    ForEach(Self.preferredFonts, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
            }
            Section("System") {
                ForEach(Self.systemFonts, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
        }
        .pickerStyle(.menu)
        .frame(width: 150)
        .labelsHidden()
        .onChange(of: formatState.fontFamily) { _, _ in onApplyFormat() }
    }

    private var fontSizePicker: some View {
        Picker("Size", selection: $formatState.fontSize) {
            ForEach(Self.fontSizes, id: \.self) { size in
                Text("\(Int(size))").tag(size)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 50)
        .labelsHidden()
        .onChange(of: formatState.fontSize) { _, _ in onApplyFormat() }
    }

    private var boldToggle: some View {
        Toggle(isOn: $formatState.isBold) {
            Text("B").bold()
        }
        .toggleStyle(.button)
        .frame(width: 24, height: 24)
        .onChange(of: formatState.isBold) { _, _ in onApplyFormat() }
    }

    private var italicToggle: some View {
        Toggle(isOn: $formatState.isItalic) {
            Text("I").italic()
        }
        .toggleStyle(.button)
        .frame(width: 24, height: 24)
        .onChange(of: formatState.isItalic) { _, _ in onApplyFormat() }
    }

    private var underlineToggle: some View {
        Toggle(isOn: $formatState.isUnderline) {
            Text("U").underline()
        }
        .toggleStyle(.button)
        .frame(width: 24, height: 24)
        .onChange(of: formatState.isUnderline) { _, _ in onApplyFormat() }
    }

    private var strikethroughToggle: some View {
        Toggle(isOn: $formatState.isStrikethrough) {
            Text("S").strikethrough()
        }
        .toggleStyle(.button)
        .frame(width: 24, height: 24)
        .onChange(of: formatState.isStrikethrough) { _, _ in onApplyFormat() }
    }

    // MARK: - Alignment

    private var alignmentPicker: some View {
        Picker("Alignment", selection: $formatState.alignment) {
            Image(systemName: "text.alignleft").tag(NSTextAlignment.left)
            Image(systemName: "text.aligncenter").tag(NSTextAlignment.center)
            Image(systemName: "text.alignright").tag(NSTextAlignment.right)
            Image(systemName: "text.justify").tag(NSTextAlignment.justified)
        }
        .pickerStyle(.segmented)
        .frame(width: 140)
        .labelsHidden()
        .onChange(of: formatState.alignment) { _, _ in onApplyFormat() }
    }

    // MARK: - Import / Export

    private var importExportGroup: some View {
        HStack(spacing: 4) {
            Button {
                onImportDOCX()
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderless)
            .help("Import DOCX")

            Button {
                onExportDOCX()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderless)
            .help("Export DOCX")
        }
    }
}
