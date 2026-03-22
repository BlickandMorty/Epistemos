import AppKit

// MARK: - EditableTransclusionView
// Editable NSTextView overlay for ((block-ref)) transclusions.
// Replaces TransclusionOverlayView with a fully editable inline editor.
// Edits fire onEdit callback which routes through BTK as UpdateBlock ops.

final class EditableTransclusionView: NSView, NSTextViewDelegate {

    let blockId: String
    let sourcePageId: String

    /// Fired when user edits the transclusion content. (blockId, newContent)
    var onEdit: ((String, String) -> Void)?

    private let textView: NSTextView
    private let scrollView: NSScrollView
    private let accentBar = NSView()

    /// Suppresses onEdit during programmatic content updates.
    private var isSetting = false

    init(blockId: String, sourcePageId: String) {
        self.blockId = blockId
        self.sourcePageId = sourcePageId

        // Build text view inside a non-scrolling scroll view (for NSTextView hosting).
        let sv = NSScrollView()
        sv.hasVerticalScroller = false
        sv.hasHorizontalScroller = false
        sv.borderType = .noBorder
        sv.drawsBackground = false
        self.scrollView = sv

        let tv = NSTextView()
        tv.isEditable = true
        tv.isSelectable = true
        tv.isRichText = false
        tv.drawsBackground = false
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.textContainerInset = NSSize(width: 0, height: 2)
        tv.textContainer?.lineFragmentPadding = 0
        tv.textContainer?.widthTracksTextView = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        self.textView = tv

        sv.documentView = tv

        super.init(frame: .zero)

        tv.delegate = self
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        wantsLayer = true
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        layer?.backgroundColor = isDark
            ? NSColor.controlAccentColor.withAlphaComponent(0.05).cgColor
            : NSColor.controlAccentColor.withAlphaComponent(0.04).cgColor
        layer?.cornerRadius = 6

        // Accent bar (left border).
        accentBar.wantsLayer = true
        accentBar.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.5).cgColor
        accentBar.layer?.cornerRadius = 1.5
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accentBar)

        // Text view styling.
        let font = NSFont.systemFont(ofSize: 13)
        textView.font = font
        textView.textColor = isDark
            ? .white.withAlphaComponent(0.7)
            : .black.withAlphaComponent(0.65)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            accentBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            accentBar.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            accentBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            accentBar.widthAnchor.constraint(equalToConstant: 3),

            scrollView.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])
    }

    // MARK: - Content API (matches TransclusionOverlayView)

    func setContent(_ text: String) {
        isSetting = true
        textView.string = text
        isSetting = false
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    func setMissing() {
        isSetting = true
        textView.string = "Block not found"
        textView.textColor = .systemRed.withAlphaComponent(0.6)
        textView.isEditable = false
        isSetting = false
    }

    /// Set provenance tooltip showing which page owns the source block.
    func setProvenance(pageTitle: String) {
        toolTip = "from [[\(pageTitle)]]"
    }

    // MARK: - Intrinsic Size

    override var intrinsicContentSize: NSSize {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return NSSize(width: NSView.noIntrinsicMetric, height: 32)
        }
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        return NSSize(width: NSView.noIntrinsicMetric, height: usedRect.height + 8)
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        guard !isSetting else { return }
        onEdit?(blockId, textView.string)
    }

    // MARK: - Hit Test
    // Unlike TransclusionOverlayView, we DO accept mouse events for editing.
    // Default hitTest behavior is correct — no override needed.
}
