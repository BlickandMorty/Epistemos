import SwiftUI

// MARK: - Liquid Glass Template Suggestion Overlay

struct TemplateSuggestionOverlay: View {
    let isVisible: Bool
    let onSelect: (NoteTemplate) -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ZStack {
            if isVisible {
                // Scrim — click to dismiss
                Color.black.opacity(0.22)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { dismiss() }

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start with a template")
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("Choose a structure, or start blank below.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(action: dismiss) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }

                        // Template grid
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(Array(NoteTemplates.all.enumerated()), id: \.element.id) { index, template in
                                TemplateCard(template: template, index: index, appeared: appeared) {
                                    onSelect(template)
                                }
                            }
                        }

                        // Start blank link
                        Button(action: dismiss) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc")
                                    .font(.subheadline)
                                Text("Start with a blank page")
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(.ultraThinMaterial, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(28)
                }
                .frame(maxWidth: 520, maxHeight: 560)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .animation(Motion.page, value: isVisible)
        .onChange(of: isVisible) { _, visible in
            if visible {
                withAnimation(Motion.smooth) { appeared = true }
            } else {
                appeared = false
            }
        }
        .onAppear {
            if isVisible {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    withAnimation(Motion.smooth) { appeared = true }
                }
            }
        }
    }

    private func dismiss() {
        withAnimation(Motion.page) { onDismiss() }
    }
}

// MARK: - Template Card — Liquid Glass + Physics Hover

private struct TemplateCard: View {
    let template: NoteTemplate
    let index: Int
    let appeared: Bool
    let action: () -> Void

    @State private var isHovering = false
    @State private var isPressed = false
    /// Cursor position within the card for tilt calculation.
    @State private var hoverLocation: CGPoint = .zero

    /// Tilt angle derived from cursor position (±3°).
    private var tiltX: Double {
        guard isHovering else { return 0 }
        return (hoverLocation.y - 0.5) * -6
    }
    private var tiltY: Double {
        guard isHovering else { return 0 }
        return (hoverLocation.x - 0.5) * 6
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                // Icon + title row
                HStack(spacing: 8) {
                    Image(systemName: template.icon)
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(template.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(template.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Divider().opacity(0.3)

                // Content preview — shows what you'll actually get
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(template.preview, id: \.self) { line in
                        previewLine(line)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(
                        color: .black.opacity(isHovering ? 0.18 : 0.08),
                        radius: isHovering ? 16 : 8,
                        y: isHovering ? 8 : 4
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        .linearGradient(
                            colors: [
                                .white.opacity(isHovering ? 0.5 : 0.3),
                                .white.opacity(isHovering ? 0.2 : 0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
            // Physics-textured hover: 3D tilt follows cursor, spring-based settle
            .rotation3DEffect(.degrees(tiltX), axis: (x: 1, y: 0, z: 0))
            .rotation3DEffect(.degrees(tiltY), axis: (x: 0, y: 1, z: 0))
            .scaleEffect(isPressed ? 0.97 : (isHovering ? 1.03 : 1.0))
        }
        .buttonStyle(.plain)
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                // Normalize to 0…1 within the card bounds.
                withAnimation(Motion.micro) { isHovering = true }
                hoverLocation = CGPoint(
                    x: min(max(location.x / 200, 0), 1),
                    y: min(max(location.y / 140, 0), 1)
                )
            case .ended:
                withAnimation(Motion.smooth) {
                    isHovering = false
                    hoverLocation = CGPoint(x: 0.5, y: 0.5)
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(Motion.micro) { isPressed = true } }
                .onEnded { _ in withAnimation(Motion.snap) { isPressed = false } }
        )
        // Staggered entrance — each card springs in offset from the previous
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .scaleEffect(appeared ? 1 : 0.88)
        .animation(
            .spring(response: 0.45, dampingFraction: 0.72).delay(Double(index) * 0.06),
            value: appeared
        )
    }

    // MARK: Preview Line Rendering

    @ViewBuilder
    private func previewLine(_ line: String) -> some View {
        if line.hasPrefix("# ") {
            Text(line.dropFirst(2))
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary.opacity(0.8))
                .lineLimit(1)
        } else if line.hasPrefix("## ") {
            Text(line.dropFirst(3))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.6))
                .lineLimit(1)
        } else if line.hasPrefix("- [ ] ") {
            HStack(spacing: 4) {
                Image(systemName: "square")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Text(line.dropFirst(6))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } else {
            Text(line)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
