import SwiftUI

// ---------------------------------------------------------------------------
// MARK: - CompanionCreationFlow
// ---------------------------------------------------------------------------

/// Wizard-style companion creation flow.
///
/// Four steps: Name → Profile → Cosmetics → Confirm. The flow is presented
/// as a sheet and calls `CompanionState.createCompanion()` on save.
public struct CompanionCreationFlow: View {
    @Environment(CompanionState.self) private var companionState
    @Environment(\.dismiss) private var dismiss

    @State private var step: CreationStep = .name
    @State private var name: String = ""
    @State private var selectedProfile: String = "default"
    @State private var cosmetics: CosmeticConfig = CosmeticConfig(
        colorTheme: "amber",
        avatarShape: "orb",
        idleBreathingRate: 1.0
    )
    @State private var isSaving = false
    @State private var errorMessage: String?

    enum CreationStep: CaseIterable {
        case name, profile, cosmetics, confirm

        var title: String {
            switch self {
            case .name:      return "Name"
            case .profile:   return "Profile"
            case .cosmetics: return "Cosmetics"
            case .confirm:   return "Confirm"
            }
        }
    }

    private let profiles = [
        ("default",  "General-purpose companion", "person.fill"),
        ("research", "Prioritises citations and evidence", "books.vertical.fill"),
        ("coding",   "Assists with code and architecture", "curlybraces"),
        ("creative", "Explores lateral connections", "paintbrush.fill")
    ]

    private let themes = [
        ("amber",  Color(red: 1.0, green: 0.6, blue: 0.0)),
        ("teal",   Color(red: 0.0, green: 0.6, blue: 0.6)),
        ("violet", Color(red: 0.5, green: 0.2, blue: 0.8)),
        ("rose",   Color(red: 0.9, green: 0.3, blue: 0.4)),
        ("slate",  Color(red: 0.4, green: 0.4, blue: 0.5))
    ]

    private let shapes = ["orb", "shard", "pulse"]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            stepIndicator
                .padding(.top, 16)
                .padding(.horizontal, 24)

            Divider()
                .padding(.vertical, 12)

            contentView
                .padding(.horizontal, 24)

            Spacer()

            Divider()

            buttonBar
                .padding(16)
        }
        .frame(minWidth: 480, minHeight: 420)
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(CreationStep.allCases, id: \.self) { s in
                let isActive = s == step
                let isPast = stepIndex(of: s) < stepIndex(of: step)
                Circle()
                    .fill(isActive ? Color.accentColor : (isPast ? Color.green : Color.secondary.opacity(0.3)))
                    .frame(width: 10, height: 10)
                if s != .confirm {
                    Rectangle()
                        .fill(isPast ? Color.green.opacity(0.5) : Color.secondary.opacity(0.15))
                        .frame(height: 2)
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch step {
        case .name:
            nameStep
        case .profile:
            profileStep
        case .cosmetics:
            cosmeticsStep
        case .confirm:
            confirmStep
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What should we call this companion?")
                .font(.headline)

            TextField("Name (max 32 characters)", text: $name)
                .textFieldStyle(.roundedBorder)
                .onChange(of: name) { _, newValue in
                    if newValue.count > 32 {
                        name = String(newValue.prefix(32))
                    }
                }

            Text("\(name.count)/32")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a base profile")
                .font(.headline)

            ForEach(profiles, id: \.0) { profile in
                HStack(spacing: 12) {
                    Image(systemName: profile.2)
                        .foregroundStyle(selectedProfile == profile.0 ? Color.accentColor : .secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.0.capitalized)
                            .font(.body)
                        Text(profile.1)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if selectedProfile == profile.0 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.accent)
                    }
                }
                .padding(10)
                .background(selectedProfile == profile.0 ? Color.accentColor.opacity(0.1) : Color.clear)
                .cornerRadius(8)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedProfile = profile.0
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    private var cosmeticsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Personalise appearance")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Colour")
                    .font(.subheadline)
                HStack(spacing: 12) {
                    ForEach(themes, id: \.0) { theme in
                        Circle()
                            .fill(theme.1)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: cosmetics.colorTheme == theme.0 ? 3 : 0)
                            )
                            .shadow(color: theme.1.opacity(0.4), radius: 4)
                            .onTapGesture {
                                cosmetics.colorTheme = theme.0
                            }
                            .accessibilityLabel("\(theme.0) theme")
                            .accessibilityAddTraits(.isButton)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Shape")
                    .font(.subheadline)
                Picker("Shape", selection: $cosmetics.avatarShape) {
                    ForEach(shapes, id: \.self) { shape in
                        Text(shape.capitalized).tag(shape)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Breathing rate")
                    .font(.subheadline)
                Slider(value: $cosmetics.idleBreathingRate, in: 0.5...2.0, step: 0.1) {
                    Text("Rate: \(String(format: "%.1f", cosmetics.idleBreathingRate))×")
                }
            }
        }
    }

    private var confirmStep: some View {
        VStack(alignment: .center, spacing: 20) {
            previewOrb
                .frame(width: 80, height: 80)

            VStack(spacing: 4) {
                Text(name)
                    .font(.title3.bold())
                Text("\(selectedProfile.capitalized) profile")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(cosmetics.colorTheme.capitalized) · \(cosmetics.avatarShape.capitalized)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if isSaving {
                ProgressView()
                    .padding(.top, 8)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var previewOrb: some View {
        switch cosmetics.avatarShape {
        case "shard":
            Diamond()
                .fill(colorForTheme(cosmetics.colorTheme))
                .shadow(color: colorForTheme(cosmetics.colorTheme).opacity(0.4), radius: 8)
        case "pulse":
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            colorForTheme(cosmetics.colorTheme),
                            colorForTheme(cosmetics.colorTheme).opacity(0.4)
                        ]),
                        center: .center,
                        startRadius: 10,
                        endRadius: 40
                    )
                )
        default:
            Circle()
                .fill(colorForTheme(cosmetics.colorTheme))
                .shadow(color: colorForTheme(cosmetics.colorTheme).opacity(0.35), radius: 12)
        }
    }

    // MARK: - Button Bar

    private var buttonBar: some View {
        HStack {
            if step != .name {
                Button("Back") {
                    goBack()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)
            }

            Spacer()

            Button("Cancel", role: .cancel) {
                dismiss()
            }

            Button(step == .confirm ? "Create" : "Next") {
                advance()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
            .disabled(step == .confirm && isSaving)
        }
    }

    // MARK: - Navigation

    private func advance() {
        errorMessage = nil

        switch step {
        case .name:
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "Name cannot be empty."
                return
            }
            step = .profile
        case .profile:
            step = .cosmetics
        case .cosmetics:
            step = .confirm
        case .confirm:
            saveCompanion()
        }
    }

    private func goBack() {
        switch step {
        case .profile:   step = .name
        case .cosmetics: step = .profile
        case .confirm:   step = .cosmetics
        default: break
        }
    }

    private func saveCompanion() {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            do {
                try await companionState.createCompanion(
                    name: name.trimmingCharacters(in: .whitespaces),
                    baseProfile: selectedProfile,
                    cosmetics: cosmetics
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }

    // MARK: - Helpers

    private func stepIndex(of s: CreationStep) -> Int {
        CreationStep.allCases.firstIndex(of: s) ?? 0
    }

    private func colorForTheme(_ theme: String) -> Color {
        switch theme {
        case "amber":  return Color(red: 1.0, green: 0.6, blue: 0.0)
        case "teal":   return Color(red: 0.0, green: 0.6, blue: 0.6)
        case "violet": return Color(red: 0.5, green: 0.2, blue: 0.8)
        case "rose":   return Color(red: 0.9, green: 0.3, blue: 0.4)
        case "slate":  return Color(red: 0.4, green: 0.4, blue: 0.5)
        default:       return Color.accentColor
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - Diamond Shape (re-declared for preview independence)
// ---------------------------------------------------------------------------

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let halfW = rect.width / 2
        let halfH = rect.height / 2
        path.move(to: CGPoint(x: cx, y: cy - halfH))
        path.addLine(to: CGPoint(x: cx + halfW, y: cy))
        path.addLine(to: CGPoint(x: cx, y: cy + halfH))
        path.addLine(to: CGPoint(x: cx - halfW, y: cy))
        path.closeSubpath()
        return path
    }
}

// ---------------------------------------------------------------------------
// MARK: - Preview
// ---------------------------------------------------------------------------

#if DEBUG
#Preview {
    CompanionCreationFlow()
        .environment(CompanionState())
        .frame(width: 520, height: 460)
}
#endif
