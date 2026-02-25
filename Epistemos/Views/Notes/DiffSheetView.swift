import SwiftData
import SwiftUI

// MARK: - DiffSheetView
// GitHub-style diff viewer presented as a sheet.
// Features: unified + split toggle, version picker, context folding,
// chunk navigation, restore-to-version with Cmd+Z undo,
// right-click context menu, open version in new tab.

struct DiffSheetView: View {
    let pageId: String
    let currentTitle: String

    @Environment(UIState.self) private var ui
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var liveBody: String
    @State private var versions: [SDPageVersion] = []
    @State private var selectedVersionId: String?
    @State private var isSplitView = false
    @State private var diff: LineDiff?
    @State private var expandedSections: Set<Int> = []
    @State private var currentChunkIdx = 0
    @State private var scrollTarget: Int?
    @State private var showRestoreAlert = false
    @State private var preRestoreBody: String?
    @State private var restoredNotice = false

    init(pageId: String, currentTitle: String, currentBody: String) {
        self.pageId = pageId
        self.currentTitle = currentTitle
        self._liveBody = State(initialValue: currentBody)
    }

    private var theme: EpistemosTheme { ui.theme }

    private var selectedVersion: SDPageVersion? {
        versions.first { $0.id == selectedVersionId }
    }

    private var sections: [LineDiff.DiffSection] { diff?.sectioned() ?? [] }
    private var chunkStarts: [Int] { diff?.chunkStartIndices ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            diffHeader
            Divider()
            diffContent
        }
        .frame(minWidth: 600, idealWidth: 900, minHeight: 400, idealHeight: 650)
        .background(theme.background)
        .onAppear(perform: loadVersions)
        .alert("Restore Version", isPresented: $showRestoreAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Restore") { restoreVersion() }
        } message: {
            if let v = selectedVersion {
                Text("Replace the current note body with this version from \(versionLabel(v))? The current content will be saved as a new version first.")
            }
        }
        .background {
            // Hidden keyboard shortcuts
            Button("") { undoRestore() }
                .keyboardShortcut("z", modifiers: .command)
                .hidden()
            Button("") { goToNextChunk() }
                .keyboardShortcut(.downArrow, modifiers: .option)
                .hidden()
            Button("") { goToPrevChunk() }
                .keyboardShortcut(.upArrow, modifiers: .option)
                .hidden()
        }
        .overlay(alignment: .bottom) {
            if restoredNotice {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Version restored — ⌘Z to undo")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Header

    private var diffHeader: some View {
        HStack(spacing: 8) {
            // Title + stats
            VStack(alignment: .leading, spacing: 2) {
                Text(currentTitle.isEmpty ? "Untitled" : currentTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.foreground)

                if let diff {
                    HStack(spacing: 8) {
                        Text("+\(diff.stats.added)")
                            .foregroundStyle(DiffColors.addedText(theme))
                        Text("-\(diff.stats.removed)")
                            .foregroundStyle(DiffColors.removedText(theme))
                        if diff.stats.modified > 0 {
                            Text("~\(diff.stats.modified)")
                                .foregroundStyle(theme.amber)
                        }
                    }
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            }

            Spacer()

            // Version picker
            if !versions.isEmpty {
                Picker("Version", selection: $selectedVersionId) {
                    ForEach(versions) { version in
                        Text(versionLabel(version))
                            .tag(Optional(version.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
                .onChange(of: selectedVersionId) { _, _ in
                    expandedSections.removeAll()
                    currentChunkIdx = 0
                    computeDiff()
                }
            }

            // Chunk navigation
            if !chunkStarts.isEmpty {
                HStack(spacing: 0) {
                    Button { goToPrevChunk() } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Previous change (⌥↑)")

                    Text("\(currentChunkIdx + 1)/\(chunkStarts.count)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .frame(minWidth: 28)

                    Button { goToNextChunk() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Next change (⌥↓)")
                }
            }

            // View toggle
            Picker("View", selection: $isSplitView) {
                Image(systemName: "list.bullet").tag(false)
                Image(systemName: "rectangle.split.2x1").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 80)

            // Restore button
            if selectedVersion != nil {
                Button {
                    showRestoreAlert = true
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Restore this version")
            }

            // More menu
            if selectedVersion != nil {
                Menu {
                    Button {
                        openVersionInTab()
                    } label: {
                        Label("Open in New Tab", systemImage: "arrow.up.right.square")
                    }

                    Button {
                        showRestoreAlert = true
                    } label: {
                        Label("Restore to This Version", systemImage: "arrow.counterclockwise")
                    }

                    Divider()

                    Button {
                        copyVersionText()
                    } label: {
                        Label("Copy Version Text", systemImage: "doc.on.doc")
                    }

                    Button {
                        copyDiffSummary()
                    } label: {
                        Label("Copy Diff Summary", systemImage: "doc.text")
                    }

                    Divider()

                    Button(role: .destructive) {
                        deleteSelectedVersion()
                    } label: {
                        Label("Delete This Version", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
            }

            // Close
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Content

    @ViewBuilder
    private var diffContent: some View {
        if let diff, diff.lines.isEmpty == false {
            Group {
                if isSplitView {
                    SplitDiffBody(
                        sections: sections,
                        expandedSections: $expandedSections,
                        scrollTarget: $scrollTarget,
                        theme: theme
                    )
                } else {
                    UnifiedDiffBody(
                        sections: sections,
                        expandedSections: $expandedSections,
                        scrollTarget: $scrollTarget,
                        theme: theme
                    )
                }
            }
            .contextMenu {
                if selectedVersion != nil {
                    Button {
                        openVersionInTab()
                    } label: {
                        Label("Open Version in New Tab", systemImage: "arrow.up.right.square")
                    }

                    Button {
                        showRestoreAlert = true
                    } label: {
                        Label("Restore to This Version", systemImage: "arrow.counterclockwise")
                    }

                    Divider()

                    Button {
                        copyVersionText()
                    } label: {
                        Label("Copy Version Text", systemImage: "doc.on.doc")
                    }

                    Button {
                        copyDiffSummary()
                    } label: {
                        Label("Copy Diff Summary", systemImage: "doc.text")
                    }
                }
            }
        } else if versions.isEmpty {
            emptyState
        } else {
            ProgressView("Computing diff...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundStyle(theme.textSecondary)
            Text("No previous versions")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.foreground)
            Text("Save your note to create the first version snapshot.")
                .font(.system(size: 12))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data

    private func loadVersions() {
        let pid = pageId
        let desc = FetchDescriptor<SDPageVersion>(
            predicate: #Predicate<SDPageVersion> { $0.pageId == pid },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        versions = (try? modelContext.fetch(desc)) ?? []
        selectedVersionId = versions.first?.id
        computeDiff()
    }

    private func computeDiff() {
        guard let version = selectedVersion else {
            diff = nil
            return
        }
        diff = LineDiff.compute(old: version.body, new: liveBody)
    }

    private func versionLabel(_ version: SDPageVersion) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: version.createdAt, relativeTo: .now)
    }

    // MARK: - Chunk Navigation

    private func goToNextChunk() {
        guard !chunkStarts.isEmpty else { return }
        currentChunkIdx = min(currentChunkIdx + 1, chunkStarts.count - 1)
        scrollTarget = chunkStarts[currentChunkIdx]
    }

    private func goToPrevChunk() {
        guard !chunkStarts.isEmpty else { return }
        currentChunkIdx = max(currentChunkIdx - 1, 0)
        scrollTarget = chunkStarts[currentChunkIdx]
    }

    // MARK: - Restore

    private func restoreVersion() {
        guard let version = selectedVersion else { return }

        let desc = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        guard let page = try? modelContext.fetch(desc).first else { return }

        // Save current body as a new version before overwriting
        let snapshot = SDPageVersion(
            pageId: page.id, title: page.title,
            body: page.body, wordCount: page.wordCount
        )
        modelContext.insert(snapshot)

        // Store for Cmd+Z undo
        preRestoreBody = page.body

        // Overwrite page body with the selected version
        page.body = version.body
        page.wordCount = version.body.split(separator: " ").count
        try? modelContext.save()

        // Update live state
        liveBody = version.body
        loadVersions()

        // Show confirmation toast
        withAnimation { restoredNotice = true }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { restoredNotice = false }
        }
    }

    private func undoRestore() {
        guard let oldBody = preRestoreBody else { return }

        let desc = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == pageId })
        guard let page = try? modelContext.fetch(desc).first else { return }

        page.body = oldBody
        page.wordCount = oldBody.split(separator: " ").count
        try? modelContext.save()

        liveBody = oldBody
        preRestoreBody = nil
        loadVersions()
    }

    // MARK: - Actions

    private func openVersionInTab() {
        guard let version = selectedVersion else { return }
        NoteWindowManager.shared.openVersionTab(
            title: version.title,
            body: version.body,
            date: version.createdAt
        )
    }

    private func copyVersionText() {
        guard let version = selectedVersion else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(version.body, forType: .string)
    }

    private func copyDiffSummary() {
        guard let diff else { return }
        var text = "Diff: +\(diff.stats.added) -\(diff.stats.removed)"
        if diff.stats.modified > 0 { text += " ~\(diff.stats.modified)" }
        text += "\n\n"
        for line in diff.lines {
            switch line {
            case .unchanged(let t): text += "  \(t)\n"
            case .added(let t): text += "+ \(t)\n"
            case .removed(let t): text += "- \(t)\n"
            case .modified(let old, let new):
                text += "- \(old)\n+ \(new)\n"
            }
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func deleteSelectedVersion() {
        guard let version = selectedVersion else { return }
        modelContext.delete(version)
        try? modelContext.save()
        loadVersions()
    }
}

// MARK: - Diff Colors

private enum DiffColors {
    static func addedBg(_ theme: EpistemosTheme) -> Color {
        theme.isDark ? Color(hex: 0x1A3A2A).opacity(0.6) : Color(hex: 0xE6FFEC)
    }
    static func removedBg(_ theme: EpistemosTheme) -> Color {
        theme.isDark ? Color(hex: 0x3A1A1A).opacity(0.6) : Color(hex: 0xFFEBE9)
    }
    static func addedWordBg(_ theme: EpistemosTheme) -> Color {
        theme.isDark ? Color(hex: 0x2A5A3A).opacity(0.8) : Color(hex: 0xABF2BC)
    }
    static func removedWordBg(_ theme: EpistemosTheme) -> Color {
        theme.isDark ? Color(hex: 0x5A2A2A).opacity(0.8) : Color(hex: 0xFFD7D5)
    }
    static func addedText(_ theme: EpistemosTheme) -> Color {
        theme.isDark ? Color(hex: 0x56D364) : Color(hex: 0x1A7F37)
    }
    static func removedText(_ theme: EpistemosTheme) -> Color {
        theme.isDark ? Color(hex: 0xF85149) : Color(hex: 0xCF222E)
    }
    static func modifiedBg(_ theme: EpistemosTheme) -> Color {
        theme.isDark ? Color(hex: 0x3A3020).opacity(0.5) : Color(hex: 0xFFF8E1)
    }
}

// MARK: - Collapsed Section Row

private struct CollapsedSectionRow: View {
    let count: Int
    let theme: EpistemosTheme
    let onExpand: () -> Void

    var body: some View {
        Button(action: onExpand) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .medium))
                Text("\(count) unchanged lines")
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(theme.isDark ? Color.white.opacity(0.03) : Color.black.opacity(0.03))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Unified Diff Body

private struct UnifiedDiffBody: View {
    let sections: [LineDiff.DiffSection]
    @Binding var expandedSections: Set<Int>
    @Binding var scrollTarget: Int?
    let theme: EpistemosTheme

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(sections) { section in
                        switch section.kind {
                        case .visible(let items):
                            ForEach(items) { item in
                                UnifiedDiffLine(line: item.line, lineNumber: item.index + 1, theme: theme)
                                    .id(item.index)
                            }
                        case .collapsed(let items):
                            if expandedSections.contains(section.id) {
                                ForEach(items) { item in
                                    UnifiedDiffLine(line: item.line, lineNumber: item.index + 1, theme: theme)
                                        .id(item.index)
                                }
                            } else {
                                CollapsedSectionRow(count: items.count, theme: theme) {
                                    let _ = withAnimation {
                                        expandedSections.insert(section.id)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: scrollTarget) { _, target in
                if let target {
                    withAnimation { proxy.scrollTo(target, anchor: .center) }
                    scrollTarget = nil
                }
            }
        }
    }
}

private struct UnifiedDiffLine: View {
    let line: DiffLineKind
    let lineNumber: Int
    let theme: EpistemosTheme

    var body: some View {
        HStack(spacing: 0) {
            Text("\(lineNumber)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(theme.textSecondary.opacity(0.5))
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 8)

            Text(prefix)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(prefixColor)
                .frame(width: 16)

            lineContent
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(bgColor)
    }

    private var prefix: String {
        switch line {
        case .unchanged: " "
        case .added: "+"
        case .removed: "-"
        case .modified: "~"
        }
    }

    private var prefixColor: Color {
        switch line {
        case .unchanged: theme.textSecondary
        case .added: DiffColors.addedText(theme)
        case .removed: DiffColors.removedText(theme)
        case .modified: theme.amber
        }
    }

    private var bgColor: Color {
        switch line {
        case .unchanged: .clear
        case .added: DiffColors.addedBg(theme)
        case .removed: DiffColors.removedBg(theme)
        case .modified: DiffColors.modifiedBg(theme)
        }
    }

    @ViewBuilder
    private var lineContent: some View {
        switch line {
        case .unchanged(let text), .added(let text), .removed(let text):
            Text(text)
                .foregroundStyle(theme.foreground)
        case .modified(let old, let new):
            VStack(alignment: .leading, spacing: 2) {
                WordHighlightedText(text: old, side: .removed, otherText: new, theme: theme)
                WordHighlightedText(text: new, side: .added, otherText: old, theme: theme)
            }
        }
    }
}

// MARK: - Split Diff Body

private struct SplitDiffBody: View {
    let sections: [LineDiff.DiffSection]
    @Binding var expandedSections: Set<Int>
    @Binding var scrollTarget: Int?
    let theme: EpistemosTheme

    var body: some View {
        HStack(spacing: 0) {
            sideView(side: .old)
            Divider()
            sideView(side: .new)
        }
    }

    private func sideView(side: SplitDiffLine.Side) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(sections) { section in
                        switch section.kind {
                        case .visible(let items):
                            ForEach(items) { item in
                                SplitDiffLine(line: item.line, side: side, lineNumber: item.index + 1, theme: theme)
                                    .id(item.index)
                            }
                        case .collapsed(let items):
                            if expandedSections.contains(section.id) {
                                ForEach(items) { item in
                                    SplitDiffLine(line: item.line, side: side, lineNumber: item.index + 1, theme: theme)
                                        .id(item.index)
                                }
                            } else {
                                CollapsedSectionRow(count: items.count, theme: theme) {
                                    let _ = withAnimation {
                                        expandedSections.insert(section.id)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: scrollTarget) { _, target in
                if let target {
                    withAnimation { proxy.scrollTo(target, anchor: .center) }
                    // Only nil out from one side to avoid double-clearing
                    if side == .old { scrollTarget = nil }
                }
            }
        }
    }
}

private struct SplitDiffLine: View {
    let line: DiffLineKind
    let side: Side
    let lineNumber: Int
    let theme: EpistemosTheme

    enum Side { case old, new }

    var body: some View {
        HStack(spacing: 0) {
            Text("\(lineNumber)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(theme.textSecondary.opacity(0.5))
                .frame(width: 32, alignment: .trailing)
                .padding(.trailing, 4)

            content
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(bgColor)
    }

    @ViewBuilder
    private var content: some View {
        switch line {
        case .unchanged(let text):
            Text(text).foregroundStyle(theme.foreground)
        case .added(let text):
            if side == .new {
                Text(text).foregroundStyle(theme.foreground)
            } else {
                Text(" ").foregroundStyle(.clear)
            }
        case .removed(let text):
            if side == .old {
                Text(text).foregroundStyle(theme.foreground)
            } else {
                Text(" ").foregroundStyle(.clear)
            }
        case .modified(let old, let new):
            if side == .old {
                WordHighlightedText(text: old, side: .removed, otherText: new, theme: theme)
            } else {
                WordHighlightedText(text: new, side: .added, otherText: old, theme: theme)
            }
        }
    }

    private var bgColor: Color {
        switch line {
        case .unchanged: .clear
        case .added: side == .new ? DiffColors.addedBg(theme) : .clear
        case .removed: side == .old ? DiffColors.removedBg(theme) : .clear
        case .modified: side == .old ? DiffColors.removedBg(theme) : DiffColors.addedBg(theme)
        }
    }
}

// MARK: - Word-Level Highlighting

private struct WordHighlightedText: View {
    let text: String
    let side: HighlightSide
    let otherText: String
    let theme: EpistemosTheme

    enum HighlightSide { case added, removed }

    var body: some View {
        let (removedRanges, addedRanges) = LineDiff.wordDiffs(
            old: side == .removed ? text : otherText,
            new: side == .added ? text : otherText
        )
        let ranges = side == .removed ? removedRanges : addedRanges
        let color = side == .removed ? DiffColors.removedWordBg(theme) : DiffColors.addedWordBg(theme)

        Text(highlighted(text: text, ranges: ranges.map(\.range), color: color))
            .foregroundStyle(theme.foreground)
    }

    private func highlighted(text: String, ranges: [Range<String.Index>], color: Color) -> AttributedString {
        var attr = AttributedString(text)
        for range in ranges {
            if let attrRange = Range(range, in: attr) {
                attr[attrRange].backgroundColor = color
            }
        }
        return attr
    }
}

// MARK: - Read-Only Version View
// Opened in a new tab via "Open in New Tab" from the diff sheet.
// Shows the version body as read-only text with a toolbar.

struct ReadOnlyVersionView: View {
    let title: String
    let versionBody: String
    let dateLabel: String

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.isEmpty ? "Untitled" : title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.foreground)
                    Text("Version from \(dateLabel)")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()

                Text("\(versionBody.split(separator: " ").count) words")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(versionBody, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Copy version text")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Body
            ScrollView(.vertical, showsIndicators: true) {
                Text(versionBody)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .textSelection(.enabled)
            }
        }
        .background(theme.background)
        .frame(minWidth: 400, minHeight: 300)
    }
}
