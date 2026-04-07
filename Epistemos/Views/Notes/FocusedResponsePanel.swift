// FocusedResponsePanel.swift
//
// Full-screen focused panel for AI responses in code editor.
// Blurs the background editor and presents detailed answers with code blocks,
// explanations, and actionable suggestions.
//
// 2026-04-07.

import SwiftUI

// MARK: - Focused Response Panel

struct FocusedResponsePanel: View {
    let response: FocusedCodeResponse
    let onDismiss: () -> Void
    let onApplyCode: (String) -> Void
    let onNavigateToLine: (Int) -> Void
    
    @State private var selectedSection: FocusedCodeResponse.ResponseSection.ID?
    @State private var isCopied = false
    
    var body: some View {
        ZStack {
            // Blurred background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Main panel
            VStack(spacing: 0) {
                // Header
                header
                
                Divider()
                
                // Content
                HStack(spacing: 0) {
                    // Section navigator (left sidebar)
                    sectionNavigator
                    
                    Divider()
                    
                    // Main content
                    mainContent
                }
            }
            .frame(width: 800, height: 600)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.3), radius: 40, x: 0, y: 20)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 16) {
            // AI Icon
            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 24))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.purple.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Response")
                    .font(.system(size: 16, weight: .semibold))
                
                Text(response.query)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Copy all button
            Button {
                copyAllContent()
            } label: {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help("Copy all content")
            
            // Close button
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Section Navigator
    
    private var sectionNavigator: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(response.sections) { section in
                    SectionButton(
                        title: section.title,
                        type: section.type,
                        isSelected: selectedSection == section.id,
                        onTap: {
                            withAnimation {
                                selectedSection = section.id
                            }
                        }
                    )
                }
            }
            .padding(.vertical, 8)
        }
        .frame(width: 180)
        .background(Color.secondary.opacity(0.03))
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary card
                summaryCard
                
                // Sections
                ForEach(response.sections) { section in
                    SectionView(
                        section: section,
                        onApplyCode: onApplyCode
                    )
                    .id(section.id)
                }
                
                // Related code preview
                if !response.relatedCodeRanges.isEmpty {
                    relatedCodeSection
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundStyle(.purple)
                .frame(width: 28, height: 28)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Summary")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Text(response.summary)
                    .font(.system(size: 14))
                    .lineSpacing(1.5)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.purple.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.purple.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Related Code Section
    
    private var relatedCodeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)
                
                Text("Referenced Code")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                Text("\(response.relatedCodeRanges.count) locations")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            
            HStack(spacing: 8) {
                ForEach(0..<min(response.relatedCodeRanges.count, 5), id: \.self) { index in
                    Button {
                        // Navigate to this range
                        onNavigateToLine(index + 1)
                    } label: {
                        Text("Line \(index + 1)")
                            .font(.system(size: 11, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
    }
    
    // MARK: - Actions
    
    private func copyAllContent() {
        let content = response.sections.map { "## \($0.title)\n\n\($0.content)" }.joined(separator: "\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }
}

// MARK: - Section Button

struct SectionButton: View {
    let title: String
    let type: FocusedCodeResponse.ResponseSection.SectionType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(type.color)

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .foregroundStyle(isSelected ? .primary : .secondary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section View

struct SectionView: View {
    let section: FocusedCodeResponse.ResponseSection
    let onApplyCode: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: section.type.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(section.type.color)

                Text(section.title)
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                TypeBadge(type: section.type)
            }

            Text(section.content)
                .font(.system(size: 13))
                .lineSpacing(1.6)
                .foregroundStyle(.primary)

            ForEach(section.codeBlocks) { block in
                CodeBlockView(
                    code: block.code,
                    language: block.language,
                    explanation: block.explanation,
                    onApply: { onApplyCode(block.code) }
                )
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.03))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(section.type.color.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Type Badge

struct TypeBadge: View {
    let type: FocusedCodeResponse.ResponseSection.SectionType

    var body: some View {
        Text(type.label)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(type.color.opacity(0.15))
            .foregroundStyle(type.color)
            .cornerRadius(4)
    }
}

// MARK: - Code Block View

struct CodeBlockView: View {
    let code: String
    let language: String
    let explanation: String?
    let onApply: () -> Void
    
    @State private var isHovered = false
    @State private var isCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 9))
                    Text(language.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                
                Spacer()
                
                // Copy button
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isCopied = false
                    }
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                
                // Apply button
                Button {
                    onApply()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 10))
                        Text("Apply")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.08))
            
            Divider()
            
            // Code
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(size: 12, design: .monospaced))
                    .lineSpacing(1.5)
                    .padding(12)
                    .textSelection(.enabled)
            }
            .background(Color(NSColor.textBackgroundColor))
            
            // Explanation if present
            if let explanation = explanation {
                Divider()
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    
                    Text(explanation)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineSpacing(1.4)
                }
                .padding(12)
                .background(Color.blue.opacity(0.03))
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview

#Preview("Focused Response Panel") {
    let sampleResponse = FocusedCodeResponse(
        query: "How can I optimize this function?",
        summary: "You can improve performance by using Accelerate framework's vDSP functions for vector operations.",
        sections: [
            .init(
                title: "Current Implementation",
                content: "Your current implementation uses a manual loop which is O(n) but not vectorized.",
                type: .explanation,
                codeBlocks: [
                    .init(
                        language: "swift",
                        code: "func sum(_ array: [Float]) -> Float {\n    var result: Float = 0\n    for value in array {\n        result += value\n    }\n    return result\n}",
                        explanation: "This is your current implementation"
                    )
                ]
            ),
            .init(
                title: "Optimized Version",
                content: "Use vDSP_sve for vector sum - it's hardware accelerated.",
                type: .suggestion,
                codeBlocks: [
                    .init(
                        language: "swift",
                        code: "import Accelerate\n\nfunc sum(_ array: [Float]) -> Float {\n    var result: Float = 0\n    vDSP_sve(array, 1, &result, vDSP_Length(array.count))\n    return result\n}",
                        explanation: "~10x faster on large arrays"
                    )
                ]
            ),
            .init(
                title: "Performance Warning",
                content: "Manual loops can be 10-100x slower than vectorized operations on large datasets.",
                type: .warning,
                codeBlocks: []
            )
        ],
        relatedCodeRanges: [NSRange(location: 0, length: 100)]
    )
    
    FocusedResponsePanel(
        response: sampleResponse,
        onDismiss: {},
        onApplyCode: { _ in },
        onNavigateToLine: { _ in }
    )
}
