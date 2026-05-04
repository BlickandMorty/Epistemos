import SwiftUI

/// 4-step Companion creation wizard. Per Simulation v1.6 Invariant
/// I-10, every cosmetic choice maps to a functional ModelProfile —
/// body grammar selects the silhouette + animation vocabulary, accent
/// color drives chat surface tinting, persona prompt augments the
/// system prompt for chats run under this companion.
///
/// Steps:
///   1. Body grammar (Block / Sage / Orb / Hermes Snake)
///   2. Name + tagline
///   3. Accent color + persona prompt
///   4. Confirm + create
///
/// Confirm calls `companionState.createCompanion(...)` directly — no
/// Sovereign Gate prompt for creation (Reversible action class per
/// doctrine §A.7; the user can delete the companion freely after).
struct CompanionCreationFlow: View {
    @Bindable var companionState: CompanionState
    var theme: EpistemosTheme
    var onDismiss: () -> Void = {}

    @State private var step: Int = 0
    @State private var bodyKind: CompanionBodyKind = .orb
    @State private var name: String = ""
    @State private var tagline: String = ""
    @State private var accentHex: String = "#7BA8E0"
    @State private var personaPrompt: String = ""

    private let presetAccents: [String] = [
        "#7BA8E0",  // soft blue
        "#9C8FE5",  // lavender (Sage default)
        "#E5A87B",  // warm amber
        "#7BE5A8",  // mint
        "#E57BB1",  // pink
        "#A8E57B",  // lime
        "#7BE5DD",  // teal
        "#E5C97B",  // gold
    ]

    var body: some View {
        VStack(spacing: 0) {
            stepHeader
            Divider().opacity(0.18)
            content
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
                .frame(minHeight: 280)
            Divider().opacity(0.18)
            footer
        }
        .frame(width: 520)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.resolved.accent.color.opacity(0.20), lineWidth: 0.6)
        )
    }

    // MARK: - Header / Footer

    private var stepHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.resolved.accent.color)
            Text("New Companion")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<4) { idx in
                    Circle()
                        .fill(idx == step
                              ? theme.resolved.accent.color
                              : theme.textTertiary.opacity(0.25))
                        .frame(width: 6, height: 6)
                }
            }
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textTertiary.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if step > 0 {
                Button("Back") { step -= 1 }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                    .font(.system(size: 12, weight: .medium))
            }
            Spacer()
            if step < 3 {
                Button {
                    step += 1
                } label: {
                    HStack(spacing: 4) {
                        Text("Next")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(theme.resolved.accent.color.opacity(canAdvance ? 0.15 : 0.06))
                    )
                    .foregroundStyle(canAdvance
                                     ? theme.resolved.accent.color
                                     : theme.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(!canAdvance)
            } else {
                Button {
                    submit()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Create")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(theme.resolved.accent.color))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var canAdvance: Bool {
        switch step {
        case 0: return true
        case 1: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return true
        default: return true
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: bodyStep
        case 1: nameStep
        case 2: accentStep
        case 3: confirmStep
        default: EmptyView()
        }
    }

    private var bodyStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("Choose a body", subtitle: "Each grammar shapes the silhouette and animation vocabulary.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(CompanionBodyKind.allCases, id: \.self) { kind in
                    Button {
                        bodyKind = kind
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: kind.systemImageName)
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(bodyKind == kind ? theme.resolved.accent.color : theme.textSecondary)
                                .frame(height: 36)
                            Text(kind.displayName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(theme.textPrimary)
                            Text(kind.hint)
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(theme.textTertiary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(bodyKind == kind
                                      ? theme.resolved.accent.color.opacity(0.10)
                                      : theme.resolved.foreground.color.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(bodyKind == kind
                                        ? theme.resolved.accent.color.opacity(0.40)
                                        : .clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("Name + tagline", subtitle: "What do they answer to? One short tagline makes them recognizable.")
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                TextField("", text: $name, prompt: Text("e.g. Sage, Quill, Nova"))
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Tagline (optional)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                TextField("", text: $tagline, prompt: Text("e.g. \"reflective companion\""))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var accentStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("Accent + persona", subtitle: "Color tints chat surfaces tied to this companion. Persona augments the system prompt.")
            VStack(alignment: .leading, spacing: 6) {
                Text("Accent")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                HStack(spacing: 10) {
                    ForEach(presetAccents, id: \.self) { hex in
                        Button {
                            accentHex = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex) ?? .gray)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(accentHex == hex
                                                ? theme.textPrimary
                                                : .clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Persona prompt (optional)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                TextEditor(text: $personaPrompt)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 80, maxHeight: 120)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(theme.resolved.foreground.color.opacity(0.04))
                    )
            }
        }
    }

    private var confirmStep: some View {
        let preview = CompanionRosterEntry(from: CompanionModel(
            name: name.isEmpty ? "Untitled" : name,
            tagline: tagline,
            bodyKind: bodyKind,
            accentHex: accentHex,
            personaPrompt: personaPrompt
        ))
        return VStack(alignment: .center, spacing: 16) {
            stepTitle("Confirm", subtitle: "This is how they'll appear in the Farm.")
            CompanionView(entry: preview, size: 96)
            VStack(alignment: .leading, spacing: 4) {
                Text("Body: \(bodyKind.displayName)")
                Text("Accent: \(accentHex)")
                if !personaPrompt.isEmpty {
                    Text("Persona: \(personaPrompt.prefix(80))…")
                        .lineLimit(2)
                }
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func stepTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
            Text(subtitle)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(theme.textTertiary)
        }
    }

    private func submit() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let trimmedPersona = personaPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = companionState.createCompanion(
            name: trimmedName,
            tagline: tagline.trimmingCharacters(in: .whitespacesAndNewlines),
            bodyKind: bodyKind,
            accentHex: accentHex,
            personaPrompt: trimmedPersona.isEmpty ? nil : trimmedPersona
        )
        onDismiss()
    }
}
