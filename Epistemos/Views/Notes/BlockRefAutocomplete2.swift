import AppKit
import SwiftData

// MARK: - BlockRefAutocomplete2
// TextKit 2 port of BlockRefAutocomplete.
// NSPopover-based autocomplete triggered by typing `((`.
// Shows a searchable list of blocks from the current vault.
// On selection, inserts the block ID and closing `))`.
//
// Geometry: Uses NSTextLayoutManager.textLayoutFragment(for:) + layoutFragmentFrame
// instead of the old TK1 glyph-based geometry path.

final class BlockRefAutocomplete2: NSObject {

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
    /// Called from Coordinator2.textDidChange.
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

    // MARK: - Popover (TextKit 2 geometry)

    private func showPopover(at charIndex: Int) {
        guard let textView,
              let tlm = textView.textLayoutManager,
              let contentStorage = tlm.textContentManager as? NSTextContentStorage,
              let storage = textView.textStorage
        else { return }

        guard storage.length > 0 else { return }
        let safeCharIndex = min(charIndex, storage.length - 1)

        // Convert character offset → NSTextLocation
        guard let docStart = contentStorage.documentRange.location as NSTextLocation?,
              let location = contentStorage.location(docStart, offsetBy: safeCharIndex)
        else { return }

        // Find the layout fragment containing this location
        guard let fragment = tlm.textLayoutFragment(for: location) else { return }

        let fragFrame = fragment.layoutFragmentFrame
        let origin = textView.textContainerOrigin

        // Find the correct line fragment for the cursor position.
        // The old TK1 path used lineFragmentRect(forGlyphAt:) for the specific wrapped line.
        // TK2: iterate textLineFragments to find the one whose characterRange contains
        // the cursor's offset within the paragraph.
        var glyphX: CGFloat = fragFrame.origin.x
        var lineY: CGFloat = fragFrame.origin.y
        var lineHeight: CGFloat = fragFrame.height

        if let elemRange = fragment.textElement?.elementRange {
            let elemStart = contentStorage.offset(from: docStart, to: elemRange.location)
            let offsetInParagraph = safeCharIndex - elemStart

            // Walk line fragments to find the one containing this offset
            for lineFrag in fragment.textLineFragments {
                let lineStart = lineFrag.characterRange.location
                let lineEnd = lineStart + lineFrag.characterRange.length
                if offsetInParagraph >= lineStart && offsetInParagraph <= lineEnd {
                    let localOffset = offsetInParagraph - lineStart
                    glyphX = lineFrag.locationForCharacter(at: localOffset).x
                    lineY = fragFrame.origin.y + lineFrag.typographicBounds.origin.y
                    lineHeight = lineFrag.typographicBounds.height
                    break
                }
            }
        }

        let anchorRect = NSRect(
            x: origin.x + glyphX - 4,
            y: origin.y + lineY,
            width: 8,
            height: max(lineHeight, 16)
        )

        // Create popover with block list using the same AppKit controller structure as before.
        let blocks = fetchBlocks(query: "")
        let listVC = BlockRefListController2(blocks: blocks) { [weak self] selectedBlock in
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
        let candidateBlocks = Array(
            blocks
                .filter { $0.content.count > 10 }
                .prefix(50)
        )

        let pageIds = Set(candidateBlocks.map(\.pageId))
        var pageTitleMap: [String: String] = [:]
        for pageId in pageIds {
            let desc = FetchDescriptor<SDPage>(
                predicate: #Predicate<SDPage> { $0.id == pageId }
            )
            if let page = try? modelContext.fetch(desc).first {
                pageTitleMap[pageId] = page.title
            }
        }

        return candidateBlocks
            .map { block in
                let pageTitle = pageTitleMap[block.pageId] ?? "Unknown"
                return (id: block.id, content: block.content, pageTitle: pageTitle)
            }
    }

    // MARK: - Insertion

    private func insertBlockRef(_ block: (id: String, content: String, pageTitle: String)) {
        guard let textView, let storage = textView.textStorage else { return }
        guard !block.id.isEmpty else { return }

        let str = storage.string as NSString
        let cursor = textView.selectedRange().location

        // Find the opening `((` by scanning backwards from cursor.
        // The user may have typed query text between `((` and selecting from popover,
        // so we replace everything from `((` through cursor with the complete reference.
        var openParenLoc = NSNotFound
        var i = min(cursor, str.length) - 1
        while i >= 1 {
            if str.character(at: i - 1) == 0x28 && str.character(at: i) == 0x28 { // ((
                openParenLoc = i - 1
                break
            }
            i -= 1
        }
        guard openParenLoc != NSNotFound else { return }

        let replaceRange = NSRange(location: openParenLoc, length: cursor - openParenLoc)
        let fullRef = "((" + block.id + "))"
        if textView.shouldChangeText(in: replaceRange, replacementString: fullRef) {
            storage.replaceCharacters(in: replaceRange, with: fullRef)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: openParenLoc + (fullRef as NSString).length, length: 0))
        }
    }
}

// MARK: - BlockRefListController2
// Pure AppKit list controller with no TextKit dependency.

private final class BlockRefListController2: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

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

        searchField.placeholderString = "Search blocks..."
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(searchField)

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
