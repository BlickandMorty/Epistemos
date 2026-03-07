import SwiftUI
import AppKit

// MARK: - ExportFormat

enum ExportFormat: String, CaseIterable, Sendable {
    case pdf
    case docx
    case plainText
    case markdown

    var displayName: String {
        switch self {
        case .pdf:       "PDF"
        case .docx:      "Word (.docx)"
        case .plainText: "Plain Text (.txt)"
        case .markdown:  "Markdown (.md)"
        }
    }

    var fileExtension: String {
        switch self {
        case .pdf:       "pdf"
        case .docx:      "docx"
        case .plainText: "txt"
        case .markdown:  "md"
        }
    }
}

// MARK: - NSTextAlignment + Hashable

extension NSTextAlignment: @retroactive Hashable {}

// MARK: - WriterFormatBar

struct WriterFormatBar: View {

    @Bindable var formatState: WriterFormatState
    let isDark: Bool
    let onExport: (ExportFormat) -> Void

    @Environment(UIState.self) private var ui
    @State private var showTitlePagePopover = false

    // MARK: Static Font Lists

    private static let preferredFonts: [String] = [
        "Times New Roman", "Arial", "Calibri", "Garamond",
        "Courier New", "Georgia", "Palatino", "Cambria"
    ].filter { NSFont(name: $0, size: 12) != nil }

    private static let systemFonts: [String] = NSFontManager.shared
        .availableFontFamilies
        .filter { !preferredFonts.contains($0) }
        .sorted()

    private static let fontSizes: [CGFloat] = [10, 11, 12, 13, 14, 16, 18, 20, 24, 28, 32, 36]

    // MARK: Body

    var body: some View {
        VStack(spacing: 4) {
            row1
            Divider()
            row2
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(ui.theme.glassBg)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ui.theme.glassBorder)
                .frame(height: 1)
        }
    }

    // MARK: - Row 1: Preset | Typography | Paragraph

    private var row1: some View {
        HStack(spacing: 6) {
            presetPicker
            Divider().frame(height: 20)
            typographyGroup
            Divider().frame(height: 20)
            paragraphGroup
        }
    }

    // MARK: - Row 2: Document | Headers | Export

    private var row2: some View {
        HStack(spacing: 6) {
            documentGroup
            Divider().frame(height: 20)
            headersGroup
            Spacer()
            exportMenu
        }
    }

    // MARK: - Preset Picker

    private var presetPicker: some View {
        Picker("Preset", selection: $formatState.activePreset) {
            Text("MLA").tag(AcademicStyle.mla)
            Text("APA").tag(AcademicStyle.apa)
            Text("Chicago").tag(AcademicStyle.chicago)
            if formatState.activePreset == .custom {
                Text("Custom (based on \(formatState.basePreset.displayName))")
                    .tag(AcademicStyle.custom)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 100)
        .labelsHidden()
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
    }

    private var boldToggle: some View {
        Toggle(isOn: $formatState.isBold) {
            Text("B").bold()
        }
        .toggleStyle(.button)
        .frame(width: 24, height: 24)
    }

    private var italicToggle: some View {
        Toggle(isOn: $formatState.isItalic) {
            Text("I").italic()
        }
        .toggleStyle(.button)
        .frame(width: 24, height: 24)
    }

    private var underlineToggle: some View {
        Toggle(isOn: $formatState.isUnderline) {
            Text("U").underline()
        }
        .toggleStyle(.button)
        .frame(width: 24, height: 24)
    }

    private var strikethroughToggle: some View {
        Toggle(isOn: $formatState.isStrikethrough) {
            Text("S").strikethrough()
        }
        .toggleStyle(.button)
        .frame(width: 24, height: 24)
    }

    // MARK: - Paragraph Group

    private var paragraphGroup: some View {
        HStack(spacing: 4) {
            alignmentPicker
            lineSpacingPicker
        }
    }

    private var alignmentPicker: some View {
        Picker("Alignment", selection: $formatState.alignment) {
            Image(systemName: "text.alignleft")
                .tag(NSTextAlignment.left)
            Image(systemName: "text.aligncenter")
                .tag(NSTextAlignment.center)
            Image(systemName: "text.alignright")
                .tag(NSTextAlignment.right)
            Image(systemName: "text.justify")
                .tag(NSTextAlignment.justified)
        }
        .pickerStyle(.segmented)
        .frame(width: 140)
        .labelsHidden()
    }

    private var lineSpacingPicker: some View {
        Picker("Spacing", selection: $formatState.lineSpacing) {
            ForEach(LineSpacing.allCases, id: \.self) { spacing in
                Text(spacing.displayName).tag(spacing)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 70)
        .labelsHidden()
    }

    // MARK: - Document Group

    private var documentGroup: some View {
        HStack(spacing: 4) {
            titlePageControls
            marginsPicker
            pageSizePicker
            spreadToggle
            zoomControl
        }
    }

    private var spreadToggle: some View {
        Toggle(isOn: $formatState.isSpreadView) {
            Label("Book", systemImage: formatState.isSpreadView ? "book.pages.fill" : "book.pages")
        }
        .toggleStyle(.button)
        .help("Two-page book spread")
    }

    private var titlePageControls: some View {
        HStack(spacing: 2) {
            Toggle("Title Page", isOn: $formatState.showTitlePage)
                .toggleStyle(.checkbox)

            Button {
                showTitlePagePopover = true
            } label: {
                Image(systemName: "pencil.circle")
            }
            .buttonStyle(.borderless)
            .disabled(!formatState.showTitlePage)
            .popover(isPresented: $showTitlePagePopover) {
                titlePageForm
            }
        }
    }

    private var titlePageForm: some View {
        Form {
            TextField("Title", text: $formatState.titlePageTitle)
            TextField("Author", text: $formatState.titlePageAuthor)
            TextField("Institution", text: $formatState.titlePageInstitution)
            TextField("Course", text: $formatState.titlePageCourse)
            TextField("Instructor", text: $formatState.titlePageInstructor)
            TextField("Date", text: $formatState.titlePageDate)
        }
        .padding()
        .frame(width: 280)
        .onDisappear {
            formatState.saveTitlePageDefaults()
        }
    }

    private var marginsPicker: some View {
        Picker("Margins", selection: $formatState.margins) {
            ForEach(PageMargins.allCases, id: \.self) { margin in
                Text(margin.displayName).tag(margin)
            }
        }
        .pickerStyle(.menu)
    }

    private var pageSizePicker: some View {
        Picker("Page Size", selection: $formatState.pageSize) {
            ForEach(PageSize.allCases, id: \.self) { size in
                Text(size.displayName).tag(size)
            }
        }
        .pickerStyle(.menu)
    }

    private var zoomControl: some View {
        HStack(spacing: 2) {
            Button {
                formatState.zoomLevel = max(0.5, formatState.zoomLevel - 0.25)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.borderless)

            Text("\(Int(formatState.zoomLevel * 100))%")
                .font(.system(size: 10, design: .monospaced))
                .frame(width: 36)

            Button {
                formatState.zoomLevel = min(2.0, formatState.zoomLevel + 0.25)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.borderless)
        }
        .help("Zoom level")
    }

    // MARK: - Headers Group

    private var headersGroup: some View {
        HStack(spacing: 4) {
            Toggle("Page #s", isOn: $formatState.showPageNumbers)
                .toggleStyle(.checkbox)

            Picker("Position", selection: $formatState.pageNumberPosition) {
                ForEach(PageNumberPosition.allCases, id: \.self) { position in
                    Text(position.displayName).tag(position)
                }
            }
            .pickerStyle(.menu)
            .disabled(!formatState.showPageNumbers)

            TextField("Running Head", text: $formatState.runningHead)
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
        }
    }

    // MARK: - Export Menu

    private var exportMenu: some View {
        Menu {
            ForEach(ExportFormat.allCases, id: \.self) { format in
                Button(format.displayName) {
                    onExport(format)
                }
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .menuStyle(.borderlessButton)
    }
}
