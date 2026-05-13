import AppKit

// MARK: - TransclusionOverlayView (DEAD CODE — superseded 2026-05-13)
//
// RCA2-P3-001 fix-pass: this view was replaced by
// `EditableTransclusionView` (see that file's header for the comparison).
// Grep across the Epistemos Swift sources returns ZERO live call sites:
// only `EditableTransclusionView` references it in its own header
// comment to explain what it superseded. Retained here only so a future
// commit that wants the read-only style can fork it, but it is NOT in
// any production rendering path and should be considered archival.
//
// Visual overlay showing the content of a referenced block ((id)).
// Renders as a subtle card with left accent border + tinted background.
// Non-interactive — clicks pass through for navigation handling.

final class TransclusionOverlayView: NSView {

    let blockId: String
    private let contentLabel = NSTextField(wrappingLabelWithString: "")
    private let accentBar = NSView()

    init(blockId: String) {
        self.blockId = blockId
        super.init(frame: .zero)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    private func setupViews() {
        wantsLayer = true
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        layer?.backgroundColor = isDark
            ? NSColor.white.withAlphaComponent(0.04).cgColor
            : NSColor.black.withAlphaComponent(0.03).cgColor
        layer?.cornerRadius = 6

        // Accent bar (left border).
        accentBar.wantsLayer = true
        accentBar.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.5).cgColor
        accentBar.layer?.cornerRadius = 1.5
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accentBar)

        // Content label.
        contentLabel.font = .systemFont(ofSize: 11)
        contentLabel.textColor = isDark
            ? .white.withAlphaComponent(0.55)
            : .black.withAlphaComponent(0.55)
        contentLabel.isEditable = false
        contentLabel.isSelectable = false
        contentLabel.isBordered = false
        contentLabel.backgroundColor = .clear
        contentLabel.lineBreakMode = .byTruncatingTail
        contentLabel.maximumNumberOfLines = 3
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentLabel)

        NSLayoutConstraint.activate([
            accentBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            accentBar.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            accentBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            accentBar.widthAnchor.constraint(equalToConstant: 3),

            contentLabel.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 8),
            contentLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            contentLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            contentLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])

        // Initial height — width is set externally by TransclusionOverlayManager.
        // Don't set width here since frame is zero at init time.
    }

    func setContent(_ text: String) {
        contentLabel.stringValue = text
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    func setMissing() {
        contentLabel.stringValue = "Block not found"
        contentLabel.textColor = .systemRed.withAlphaComponent(0.6)
    }

    override var intrinsicContentSize: NSSize {
        let labelSize = contentLabel.intrinsicContentSize
        return NSSize(width: NSView.noIntrinsicMetric, height: labelSize.height + 8)
    }

    // Pass through mouse events so the text view handles them (click-to-navigate).
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
