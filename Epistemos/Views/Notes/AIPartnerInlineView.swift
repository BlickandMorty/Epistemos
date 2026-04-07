// AIPartnerInlineView.swift
//
// Inline AI suggestion rendering for the code editor.
// Shows ghost text suggestions directly in the editor, similar to GitHub Copilot.
// Uses NSTextView's inline prediction system for native feel.
//
// 2026-04-07.

import SwiftUI
import AppKit

// MARK: - Inline Suggestion Model

/// Represents an inline code suggestion from the AI partner
struct InlineSuggestion: Identifiable {
    let id = UUID()
    let text: String
    let type: SuggestionType
    let range: NSRange?        // Where to insert/replace
    let confidence: Double     // 0.0 to 1.0
    let context: SuggestionContext
    let timestamp = Date()
    
    enum SuggestionType {
        case completion      // Continue current line
        case insertion       // Insert at cursor
        case replacement     // Replace selection
        case multiLine       // Block of code
        case refactor        // Restructuring suggestion
        
        var icon: String {
            switch self {
            case .completion: return "arrow.right"
            case .insertion: return "plus"
            case .replacement: return "arrow.2.squarepath"
            case .multiLine: return "doc.text"
            case .refactor: return "wand.and.stars"
            }
        }
        
        var description: String {
            switch self {
            case .completion: return "Complete"
            case .insertion: return "Insert"
            case .replacement: return "Replace"
            case .multiLine: return "Add"
            case .refactor: return "Refactor"
            }
        }
    }
    
    struct SuggestionContext: Sendable {
        let relatedNoteIds: [String]
        let semanticScore: Float
        let contextLines: [String]
        let source: String  // Which AI model provided this
    }
}

// MARK: - Ghost Text Renderer

/// Renders ghost text (faded suggestion) in the editor
final class GhostTextRenderer {
    static let shared = GhostTextRenderer()
    
    private init() {}
    
    /// Creates an attributed string with ghost text styling
    func createGhostText(_ text: String, font: NSFont, color: NSColor) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color.withAlphaComponent(0.5),
            .backgroundColor: NSColor.clear
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }
    
    /// Creates a highlighted range showing AI context
    func highlightContextRange(
        in textView: NSTextView,
        range: NSRange,
        color: NSColor,
        label: String?
    ) {
        let effectiveRange = NSIntersectionRange(range, NSRange(location: 0, length: textView.string.count))
        guard effectiveRange.length > 0 else { return }

        // Create a custom background highlight
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // Get the glyph range for the character range
        let glyphRange = layoutManager.glyphRange(forCharacterRange: effectiveRange, actualCharacterRange: nil)

        // Get the bounding rect
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        // Create highlight overlay
        let highlightView = ContextHighlightView(frame: boundingRect)
        highlightView.fillColor = color.withAlphaComponent(0.15)
        highlightView.borderColor = color.withAlphaComponent(0.5)
        highlightView.label = label
        
        // Add to text view
        textView.addSubview(highlightView)
        
        // Animate in
        highlightView.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            highlightView.animator().alphaValue = 1
        }
    }
    
    /// Removes all context highlights
    func removeAllHighlights(from textView: NSTextView) {
        textView.subviews.compactMap { $0 as? ContextHighlightView }.forEach { $0.removeFromSuperview() }
    }
}

// MARK: - Context Highlight View

/// Visual indicator showing which code context the AI is using
final class ContextHighlightView: NSView {
    var fillColor: NSColor = .systemBlue.withAlphaComponent(0.15)
    var borderColor: NSColor = .systemBlue.withAlphaComponent(0.5)
    var label: String?
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw rounded rectangle
        let path = NSBezierPath(roundedRect: bounds, xRadius: 3, yRadius: 3)
        fillColor.setFill()
        path.fill()
        
        borderColor.setStroke()
        path.lineWidth = 1
        path.stroke()
        
        // Draw label if provided
        if let label = label {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9),
                .foregroundColor: borderColor
            ]
            let attributedString = NSAttributedString(string: label, attributes: attributes)
            let stringSize = attributedString.size()
            
            let labelRect = NSRect(
                x: bounds.maxX - stringSize.width - 4,
                y: bounds.minY - stringSize.height - 2,
                width: stringSize.width + 8,
                height: stringSize.height + 4
            )
            
            let labelPath = NSBezierPath(roundedRect: labelRect, xRadius: 2, yRadius: 2)
            NSColor.controlBackgroundColor.setFill()
            labelPath.fill()
            
            attributedString.draw(at: NSPoint(x: labelRect.minX + 4, y: labelRect.minY + 2))
        }
    }
}

// MARK: - Inline Suggestion View (SwiftUI)

/// SwiftUI view for displaying inline suggestions as an overlay
struct InlineSuggestionOverlay: View {
    let suggestion: InlineSuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void
    let onViewAlternatives: () -> Void
    
    @State private var isHovered = false
    @State private var showDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Suggestion content
            suggestionContent
            
            // Context info (if showing details)
            if showDetails {
                contextDetails
            }
            
            // Action bar
            actionBar
        }
        .background(.ultraThinMaterial)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var suggestionContent: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: suggestion.type.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)
                .background(iconColor.opacity(0.1))
                .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 6) {
                // Type label
                Text(suggestion.type.description)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                // Suggestion text (formatted as code)
                Text(suggestion.text)
                    .font(.system(size: 13, design: .monospaced))
                    .lineSpacing(2)
                    .foregroundStyle(.primary)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    )
            }
            
            Spacer()
            
            // Confidence indicator
            ConfidenceIndicator(confidence: suggestion.confidence)
        }
        .padding(12)
    }
    
    private var contextDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                
                Text("Context from \(suggestion.context.relatedNoteIds.count) related notes")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("Semantic score: \(String(format: "%.2f", suggestion.context.semanticScore))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
    
    private var actionBar: some View {
        HStack(spacing: 8) {
            // Accept button
            Button {
                onAccept()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Tab")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            
            // Dismiss button
            Button {
                onDismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                    Text("Esc")
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Spacer()
            
            // Show details toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDetails.toggle()
                }
            } label: {
                Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .help("Show context details")
            
            // View alternatives
            if suggestion.type == .multiLine || suggestion.type == .refactor {
                Button {
                    onViewAlternatives()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.stack")
                            .font(.system(size: 10))
                        Text("Alternatives")
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
    }
    
    private var iconColor: Color {
        switch suggestion.type {
        case .completion: return .blue
        case .insertion: return .green
        case .replacement: return .orange
        case .multiLine: return .purple
        case .refactor: return .pink
        }
    }
    
    private var borderColor: Color {
        iconColor.opacity(0.3)
    }
}

// MARK: - Confidence Indicator

struct ConfidenceIndicator: View {
    let confidence: Double
    
    var body: some View {
        VStack(spacing: 2) {
            Text(percentage)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            
            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 3)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(confidence), height: 3)
                }
            }
            .frame(width: 32, height: 3)
        }
        .frame(width: 40)
    }
    
    private var percentage: String {
        Int(confidence * 100).description
    }
    
    private var color: Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Retro Styled AI Response Box

/// AI response with retro terminal aesthetic
struct RetroAIResponseBox: View {
    let title: String
    let content: String
    let actions: [AIResponseAction]
    let onDismiss: () -> Void
    
    @State private var isHovered = false
    @State private var showTypingEffect = false
    
    struct AIResponseAction {
        let id: String
        let title: String
        let icon: String
        let handler: () -> Void
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with retro styling
            header
            
            // Content with retro font
            contentView
            
            // Actions
            if !actions.isEmpty {
                actionBar
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.purple.opacity(0.5),
                                    Color.cyan.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: .purple.opacity(0.1), radius: 20, x: 0, y: 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3).delay(0.1)) {
                showTypingEffect = true
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var header: some View {
        HStack(spacing: 8) {
            // Retro pixel-style icon
            Image(systemName: "cpu.fill")
                .font(.system(size: 12))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Spacer()
            
            // Status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("ACTIVE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(4)
            
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.05),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var contentView: some View {
        Text(content)
            .font(.system(size: 13, design: .monospaced))
            .lineSpacing(4)
            .foregroundStyle(.primary)
            .opacity(showTypingEffect ? 1 : 0)
            .padding(12)
    }
    
    private var actionBar: some View {
        HStack(spacing: 8) {
            ForEach(actions.prefix(3), id: \.id) { action in
                Button {
                    action.handler()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: action.icon)
                            .font(.system(size: 10))
                        Text(action.title)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
}

// MARK: - Preview

#Preview("Inline Suggestion") {
    InlineSuggestionOverlay(
        suggestion: InlineSuggestion(
            text: "func calculateSimilarity(_ a: [Float], _ b: [Float]) -> Float {\n    var dotProduct: Float = 0\n    vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))\n    return dotProduct\n}",
            type: .multiLine,
            range: nil,
            confidence: 0.87,
            context: InlineSuggestion.SuggestionContext(
                relatedNoteIds: ["note-1", "note-2"],
                semanticScore: 0.92,
                contextLines: ["// GPU acceleration", "import Accelerate"],
                source: "AI Partner"
            )
        ),
        onAccept: {},
        onDismiss: {},
        onViewAlternatives: {}
    )
    .frame(width: 400)
    .padding()
}

#Preview("Retro AI Response") {
    RetroAIResponseBox(
        title: "AI PARTNER",
        content: "I noticed you're implementing vector operations. Based on your vault notes about GPU acceleration, I suggest using Accelerate framework's vDSP functions for better performance.",
        actions: [
            .init(id: "apply", title: "Apply", icon: "checkmark", handler: {}),
            .init(id: "explain", title: "Explain", icon: "text.bubble", handler: {}),
            .init(id: "dismiss", title: "Dismiss", icon: "xmark", handler: {})
        ],
        onDismiss: {}
    )
    .frame(width: 400)
    .padding()
}

#Preview("Confidence Indicator") {
    VStack(spacing: 16) {
        ConfidenceIndicator(confidence: 0.92)
        ConfidenceIndicator(confidence: 0.65)
        ConfidenceIndicator(confidence: 0.32)
    }
    .padding()
}
