import AppKit
import SwiftData

// MARK: - BlockRefAutocomplete
// NSPopover-based autocomplete triggered by typing `((`.
// Shows a searchable list of blocks from the current vault.
// On selection, inserts the block ID and closing `))`.

final class BlockRefAutocomplete: NSObject {

    private var popover: NSPopover?
    private weak var textView: NSTextView?
    private var modelContext: ModelContext?

    // MARK: - Setup

    func configure(textView: NSTextView, modelContext: ModelContext) {
        self.textView = textView
        self.modelContext = modelContext
    }

    // MARK: - Trigger Detection

    /// Check if the user just typed `((` and should see autocomplete.
    /// Called from textDidChange.
    func checkTrigger() {
        guard let textView, let storage = textView.textStorage else { return }
        let cursor = textView.selectedRange().location
        guard cursor >= 2 else { return }

        let checkRange = NSRange(location: cursor - 2, length: 2)
        let typed = (storage.string as NSString).substring(with: checkRange)

        if typed == "((" {
            showPopover(at: cursor)
        }
    }

    // MARK: - Popover

    private func showPopover(at charIndex: Int) {
        guard let textView, let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let storage = textView.textStorage
        else { return }

        // Guard empty storage and clamp to valid range.
        guard storage.length > 0 else { return }
        let safeCharIndex = min(charIndex, storage.length - 1)

        // Ensure layout is computed for this position.
        layoutManager.ensureGlyphs(forCharacterRange: NSRange(location: safeCharIndex, length: 1))
        layoutManager.ensureLayout(forCharacterRange: NSRange(location: safeCharIndex, length: 1))

        let glyphIndex = layoutManager.glyphIndexForCharacter(at: safeCharIndex)
        guard glyphIndex != NSNotFound else { return }
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        let glyphLoc = layoutManager.location(forGlyphAt: glyphIndex)
        let origin = textView.textContainerOrigin

        let anchorRect = NSRect(
            x: origin.x + lineRect.origin.x + glyphLoc.x - 4,
            y: origin.y + lineRect.origin.y,
            width: 8,
            height: max(lineRect.height, 16)
        )

        // Create popover with block list.
        let blocks = fetchBlocks(query: "")
        let listVC = BlockRefListController(blocks: blocks) { [weak self] selectedBlock in
            self?.insertBlockRef(selectedBlock)
            self?.dismiss()
        }

        let pop = NSPopover()
        pop.contentViewController = listVC
        pop.behavior = .transient
        pop.contentSize = NSSize(width: 300, height: 200)
        pop.show(relativeTo: anchorRect, of: textView, preferredEdge: .maxY)
        popover = pop
    }

    func dismiss() {
        popover?.close()
        popover = nil
    }

    // MARK: - Block Fetching

    private func fetchBlocks(query: String) -> [(id: String, content: String, pageTitle: String)] {
        guard let modelContext else { return [] }

        var blockDescriptor = FetchDescriptor<SDBlock>(
            sortBy: [SortDescriptor(\SDBlock.updatedAt, order: .reverse)]
        )
        blockDescriptor.fetchLimit = 200
        let blocks = (try? modelContext.fetch(blockDescriptor)) ?? []

        // Fetch page titles — query only the pages we actually need (indexed lookups).
        let pageIds = Set(blocks.map(\.pageId))
        var pageTitleMap: [String: String] = [:]
        for pageId in pageIds {
            let desc = FetchDescriptor<SDPage>(
                predicate: #Predicate<SDPage> { $0.id == pageId }
            )
            if let page = try? modelContext.fetch(desc).first {
                pageTitleMap[pageId] = page.title
            }
        }

        return blocks
            .filter { $0.content.count > 10 } // Only substantial blocks
            .prefix(50)
            .map { block in
                let pageTitle = pageTitleMap[block.pageId] ?? "Unknown"
                return (id: block.id, content: block.content, pageTitle: pageTitle)
            }
    }

    // MARK: - Insertion

    private func insertBlockRef(_ block: (id: String, content: String, pageTitle: String)) {
        guard let textView, let storage = textView.textStorage else { return }

        // Re-derive insertion point from current cursor to avoid stale state.
        let cursor = textView.selectedRange().location
        guard cursor >= 2 else { return }
        let checkRange = NSRange(location: cursor - 2, length: 2)
        guard (storage.string as NSString).substring(with: checkRange) == "((" else { return }

        let insertText = "\(block.id)))"
        let insertRange = NSRange(location: cursor, length: 0)
        if textView.shouldChangeText(in: insertRange, replacementString: insertText) {
            storage.replaceCharacters(in: insertRange, with: insertText)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: cursor + insertText.count, length: 0))
        }
    }
}

// MARK: - BlockRefListController

private final class BlockRefListController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    private var blocks: [(id: String, content: String, pageTitle: String)]
    private let onSelect: ((id: String, content: String, pageTitle: String)) -> Void
    private let tableView = NSTableView()
    private let searchField = NSSearchField()

    private var filteredBlocks: [(id: String, content: String, pageTitle: String)] = []

    init(blocks: [(id: String, content: String, pageTitle: String)],
         onSelect: @escaping ((id: String, content: String, pageTitle: String)) -> Void) {
        self.blocks = blocks
        self.onSelect = onSelect
        self.filteredBlocks = blocks
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))

        // Search field.
        searchField.placeholderString = "Search blocks..."
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(searchField)

        // Table.
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("block"))
        column.title = "Block"
        column.width = 280
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 36
        tableView.doubleAction = #selector(rowDoubleClicked)
        tableView.target = self

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scroll)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),

            scroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 4),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        self.view = container
    }

    @objc private func searchChanged() {
        let query = searchField.stringValue.lowercased()
        if query.isEmpty {
            filteredBlocks = blocks
        } else {
            filteredBlocks = blocks.filter {
                $0.content.lowercased().contains(query) || $0.pageTitle.lowercased().contains(query)
            }
        }
        tableView.reloadData()
    }

    @objc private func rowDoubleClicked() {
        let row = tableView.clickedRow
        guard row >= 0, row < filteredBlocks.count else { return }
        onSelect(filteredBlocks[row])
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int { filteredBlocks.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let block = filteredBlocks[row]
        let cell = NSTableCellView()

        let label = NSTextField(wrappingLabelWithString: "")
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        label.attributedStringValue = {
            let str = NSMutableAttributedString()
            str.append(NSAttributedString(
                string: String(block.content.prefix(60)),
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: isDark ? NSColor.white.withAlphaComponent(0.85) : NSColor.black.withAlphaComponent(0.85)
                ]
            ))
            str.append(NSAttributedString(
                string: "  \(block.pageTitle)",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 10),
                    .foregroundColor: isDark ? NSColor.white.withAlphaComponent(0.35) : NSColor.black.withAlphaComponent(0.35)
                ]
            ))
            return str
        }()
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        return cell
    }

    private var effectiveAppearance: NSAppearance {
        view.effectiveAppearance
    }
}
