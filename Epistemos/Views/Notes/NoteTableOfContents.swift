import SwiftUI

// MARK: - Table of Contents Item

struct TOCItem: Identifiable, Equatable, Sendable {
    let id = UUID()
    let level: Int          // 1-6 for H1-H6
    let title: String
    let charOffset: Int     // Character offset in the document
    let kind: TOCKind

    enum TOCKind: Equatable, Sendable {
        case heading
        case citation
        case source
        case block   // KnowledgeCore block-outline row (every block, not just headings)
        case notebookTab(tabID: String)
        case embed(referenceID: String, type: String)

        var isPrimaryOutlineItem: Bool {
            switch self {
            case .heading, .notebookTab, .embed:
                true
            case .citation, .source, .block:
                false
            }
        }

        var symbolName: String {
            switch self {
            case .heading:
                "textformat.size"
            case .citation:
                "quote.bubble"
            case .source:
                "link"
            case .block:
                "square.stack.3d.up"
            case .notebookTab:
                "rectangle.on.rectangle"
            case .embed:
                "point.3.connected.trianglepath.dotted"
            }
        }
    }

    static func == (lhs: TOCItem, rhs: TOCItem) -> Bool {
        lhs.level == rhs.level
            && lhs.title == rhs.title
            && lhs.charOffset == rhs.charOffset
            && lhs.kind == rhs.kind
    }
}

// MARK: - Table of Contents Parser

enum TOCParser {

    /// Extract headings (H1-H5), citations, and source links from markdown text.
    nonisolated static func parse(_ markdown: String) -> [TOCItem] {
        var items: [TOCItem] = []
        var charOffset = 0

        let lines = markdown.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Headings: # through #####
            if let level = headingLevel(trimmed), level <= 5 {
                let title = headingTitle(trimmed, level: level)
                if !title.isEmpty {
                    items.append(TOCItem(level: level, title: title, charOffset: charOffset, kind: .heading))
                }
            }

            charOffset += line.utf16.count + 1 // +1 for newline
        }

        items.append(contentsOf: notebookNavigationItems(in: markdown))
        return items.sorted { lhs, rhs in
            if lhs.charOffset == rhs.charOffset { return lhs.level < rhs.level }
            return lhs.charOffset < rhs.charOffset
        }
    }

    nonisolated static func notebookNavigationItems(in markdown: String) -> [TOCItem] {
        var items: [TOCItem] = []
        let manifest = EpdocNotebookManifest.parse(in: markdown)
        if manifest.hasReferenceTabs {
            items.append(
                TOCItem(
                    level: 1,
                    title: EpdocNotebookManifest.bodyTab.title,
                    charOffset: 0,
                    kind: .notebookTab(tabID: EpdocNotebookManifest.bodyTabID)
                )
            )
            for tab in manifest.tabs {
                items.append(
                    TOCItem(
                        level: 1,
                        title: tab.title,
                        charOffset: tab.charOffset,
                        kind: .notebookTab(tabID: tab.id)
                    )
                )
            }
        }

        for embed in EpdocNotebookReferenceParser.blockEmbeds(in: markdown) {
            items.append(
                TOCItem(
                    level: 2,
                    title: embed.title,
                    charOffset: embed.charOffset,
                    kind: .embed(referenceID: embed.id, type: embed.kind.rawValue)
                )
            )
        }

        return items
    }

    /// Extract headings from rich text by scanning font sizes.
    /// H1: >= 26pt, H2: >= 20pt, H3: >= 17pt.
    static func parseRichText(_ attributedText: NSAttributedString) -> [TOCItem] {
        var items: [TOCItem] = []
        let string = attributedText.string as NSString
        let fullRange = NSRange(location: 0, length: string.length)
        guard fullRange.length > 0 else { return items }

        string.enumerateSubstrings(in: fullRange, options: .byParagraphs) {
            substring, paraRange, _, _ in
            guard let substring,
                  !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  paraRange.location < attributedText.length else { return }

            let attrs = attributedText.attributes(at: paraRange.location, effectiveRange: nil)
            guard let font = attrs[.font] as? NSFont else { return }

            let level: Int?
            if font.pointSize >= 26 { level = 1 }
            else if font.pointSize >= 20 { level = 2 }
            else if font.pointSize >= 17 { level = 3 }
            else { level = nil }

            if let level {
                let title = substring.trimmingCharacters(in: .whitespacesAndNewlines)
                items.append(TOCItem(
                    level: level,
                    title: title,
                    charOffset: paraRange.location,
                    kind: .heading
                ))
            }
        }
        return items
    }

    private nonisolated static func headingLevel(_ line: String) -> Int? {
        var count = 0
        for ch in line {
            if ch == "#" { count += 1 }
            else if ch == " " && count > 0 { return count }
            else { return nil }
        }
        return nil
    }

    private nonisolated static func headingTitle(_ line: String, level: Int) -> String {
        let dropped = String(line.dropFirst(level + 1)) // Drop "## " etc.
        return dropped
            .replacingOccurrences(of: "\\*\\*|\\*|`|\\[|\\]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - KnowledgeCore Block Outline (Slice 3 cutover — Option 1)

/// Builds a block-level outline (EVERY block, not just headings) from the shared
/// KnowledgeCore runtime's projection of a page, for the "Blocks" mode of the
/// outline panel. This is the production surface KC drives — its native block
/// model, read on-demand via `pageOutline` (no per-TOC bridge, no re-ingest).
/// Char offsets are resolved against the markdown (UTF-16, matching `TOCParser`)
/// so click-to-scroll works; an unlocatable row falls back to offset 0. Returns
/// `[]` when the runtime is unavailable (flag off) — the panel then keeps headings.
@MainActor
enum KnowledgeCoreBlockOutline {
    static func items(pageId: String, markdown: String) async -> [TOCItem] {
        guard let runtime = AppBootstrap.shared?.knowledgeCoreRuntime else { return [] }
        let rows = await runtime.pageOutline(pageId: pageId)
        guard !rows.isEmpty else { return [] }

        // First-occurrence UTF-16 offset per trimmed line, matching TOCParser's
        // accumulation so navigation lands on the same character positions.
        var offsetByLine: [String: Int] = [:]
        var charOffset = 0
        for line in markdown.components(separatedBy: "\n") {
            let key = line.trimmingCharacters(in: .whitespaces)
            if !key.isEmpty, offsetByLine[key] == nil { offsetByLine[key] = charOffset }
            charOffset += line.utf16.count + 1
        }

        return rows.map { row in
            let trimmed = row.content.trimmingCharacters(in: .whitespaces)
            return TOCItem(
                level: min(max(row.depth + 1, 1), 6),
                title: trimmed.isEmpty ? "—" : trimmed,
                charOffset: offsetByLine[trimmed] ?? 0,
                kind: .block
            )
        }
    }
}

// MARK: - Deterministic Outline Runtime Projection

@MainActor
final class KnowledgeCoreOutlineProjectionState {
    private static var nextPeerId: UInt64 = 31

    private let flags: EpistemosRuntimeFeatureFlags
    private let peerId: UInt64
    private let binding: KnowledgeCoreRuntimeBinding
    private var bridge: KnowledgeCoreBridge?
    private var subscribedPageId: String?
    private var subscriptionId: UInt64?
    private var appliedPayloadCount = 0

    private(set) var items: [TOCItem] = []
    private(set) var lastAppliedTxId: UInt64?
    private(set) var lastApplyResult: KnowledgeCoreRuntimeAdapterApplyResult = .empty
    private(set) var lastError: KnowledgeCoreBridgeError?

    var isEnabled: Bool {
        flags.deterministicKnowledgeCoreRuntime
    }

    init(
        flags: EpistemosRuntimeFeatureFlags = EpistemosRuntimeFeatureFlags.load(),
        peerId: UInt64? = nil
    ) {
        self.flags = flags
        if let peerId {
            self.peerId = peerId
        } else {
            Self.nextPeerId &+= 1
            self.peerId = Self.nextPeerId
        }
        self.binding = KnowledgeCoreRuntimeBinding(flags: flags)
    }

    @discardableResult
    func refresh(
        pageId: String,
        markdown: String,
        fallbackHeadings: [TOCItem]
    ) async -> KnowledgeCoreRuntimeAdapterApplyResult {
        guard isEnabled else {
            lastApplyResult = .empty
            return .empty
        }
        guard let bridge = await resolvedBridge() else {
            lastApplyResult = .empty
            return .empty
        }
        guard await ensureOutlineSubscription(pageId: pageId, bridge: bridge) != nil else {
            lastApplyResult = .empty
            return .empty
        }

        _ = await bridge.ingestDocument(pageId: pageId, format: .markdown, text: markdown)
        lastError = await bridge.lastErrorSnapshot()

        let payloads = await bridge.drainPayloads()
        let appliedBefore = appliedPayloadCount
        let result = binding.apply(payloads)
        lastApplyResult = result

        if appliedPayloadCount > appliedBefore {
            items = fallbackHeadings
        }

        return result
    }

    private func resolvedBridge() async -> KnowledgeCoreBridge? {
        if let bridge {
            return bridge
        }
        guard let bridge = KnowledgeCoreBridge(peerId: peerId) else {
            lastError = KnowledgeCoreBridgeError(
                code: .ring,
                message: "Knowledge-core outline bridge could not be created"
            )
            return nil
        }
        self.bridge = bridge
        return bridge
    }

    private func ensureOutlineSubscription(
        pageId: String,
        bridge: KnowledgeCoreBridge
    ) async -> UInt64? {
        if subscribedPageId == pageId, let subscriptionId {
            return subscriptionId
        }

        if let subscriptionId {
            binding.unregister(subscriptionId: subscriptionId)
            _ = await bridge.unsubscribe(subscriptionId)
        }

        guard let nextSubscriptionId = await bridge.subscribeOutline(pageId: pageId) else {
            lastError = await bridge.lastErrorSnapshot()
            subscribedPageId = nil
            subscriptionId = nil
            return nil
        }

        subscribedPageId = pageId
        subscriptionId = nextSubscriptionId
        binding.register(subscriptionId: nextSubscriptionId) { [weak self] payload in
            self?.recordAppliedOutlinePayload(payload)
        }
        _ = await bridge.drainPayloads()
        lastError = nil
        return nextSubscriptionId
    }

    private func recordAppliedOutlinePayload(_ payload: KnowledgeCorePayloadSnapshot) {
        appliedPayloadCount += 1
        lastAppliedTxId = payload.txId
    }
}

// MARK: - NoteOutlineOverlay
// Hover-triggered glass panel on the right edge showing document outline.

struct NoteOutlineOverlay: View {
    let markdown: String
    let theme: EpistemosTheme
    let onNavigate: (Int) -> Void
    var onNavigateItem: ((TOCItem) -> Void)? = nil
    var externalItems: [TOCItem]? = nil
    /// KC block-outline rows (Slice 3 cutover). When non-empty, a Headings ⇄ Blocks
    /// toggle appears and Blocks mode renders KC's projection. nil/empty → headings only.
    var blockItems: [TOCItem]? = nil

    enum OutlineMode { case headings, blocks }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var items: [TOCItem] = []
    @State private var isHovering = false
    @State private var mode: OutlineMode = .headings

    private var headings: [TOCItem] {
        (externalItems ?? items).filter { $0.kind.isPrimaryOutlineItem }
    }

    private var blocks: [TOCItem] { blockItems ?? [] }
    private var hasBlocks: Bool { !blocks.isEmpty }

    /// What the panel renders: KC blocks in Blocks mode (when available), else headings.
    private var displayedItems: [TOCItem] {
        (mode == .blocks && hasBlocks) ? blocks : headings
    }

    /// The panel shows when there's anything to navigate — headings OR KC blocks.
    private var isVisible: Bool { !headings.isEmpty || hasBlocks }

    var body: some View {
        Group {
            if isVisible {
                VStack {
                    Spacer()

                    HStack(spacing: 0) {
                        if isHovering {
                            outlinePanel
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }

                        // Visible tab indicator on the right edge
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(theme.isDark
                                  ? Color.white.opacity(0.2)
                                  : Color.black.opacity(0.12))
                            .frame(width: 6, height: 40)
                            .overlay {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(theme.isDark
                                                  ? Color.white.opacity(0.3)
                                                  : Color.black.opacity(0.15),
                                                  lineWidth: 0.5)
                            }
                            .padding(.trailing, 8)
                    }
                    .onHover { hovering in
                        withAnimation(reduceMotion ? nil : .smooth(duration: 0.18)) {
                            isHovering = hovering
                        }
                    }

                    Spacer()
                }
                .frame(width: isHovering ? 210 : 6)
                .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: isHovering)
            }
        }
        .task {
            if externalItems == nil { items = TOCParser.parse(markdown) }
        }
        .onChange(of: markdown) {
            if externalItems == nil { items = TOCParser.parse(markdown) }
        }
    }

    private var outlinePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: mode == .blocks && hasBlocks ? "square.stack.3d.up" : "list.bullet")
                    .font(.system(size: 10, weight: .semibold))
                Text("Outline")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                // Headings ⇄ Blocks toggle — only when KC supplies a block outline.
                if hasBlocks {
                    Button {
                        withAnimation(reduceMotion ? nil : .smooth(duration: 0.15)) {
                            mode = (mode == .headings) ? .blocks : .headings
                        }
                    } label: {
                        Text(mode == .blocks ? "Blocks" : "Headings")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Toggle between markdown headings and the KnowledgeCore block outline")
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(displayedItems) { item in
                        Button {
                            if let onNavigateItem {
                                onNavigateItem(item)
                            } else {
                                onNavigate(item.charOffset)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: item.kind.symbolName)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 12)
                                Text(item.title)
                                    .font(.system(size: tocFontSize(for: item.level),
                                                  weight: item.level <= 2 ? .medium : .regular))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 3)
                            .padding(.leading, CGFloat(item.level - 1) * 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 200)
        .frame(maxHeight: 400)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
        .padding(.trailing, 8)
        .padding(.vertical, 40)
    }

    private func tocFontSize(for level: Int) -> CGFloat {
        switch level {
        case 1: 13
        case 2: 12
        case 3: 11
        default: 10.5
        }
    }
}
