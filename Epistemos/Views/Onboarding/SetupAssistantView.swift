import SwiftUI

// MARK: - Setup Assistant

/// First-run setup wizard that guides the user through essential configuration.
/// Shows automatically on first launch.
/// Steps: 1) Welcome -> 2) Vault -> 3) Foundation -> 4) Done
struct SetupAssistantView: View {
    private static let stepTransition = Animation.spring(response: 0.35, dampingFraction: 0.85)

    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentStep: SetupStep = .welcome

    let onComplete: () -> Void

    private var stepTransitionAnimation: Animation? {
        reduceMotion ? nil : Self.stepTransition
    }

    private var theme: EpistemosTheme { ui.theme }
    private var bodyFont: Font { .system(size: 12, weight: .regular, design: .monospaced) }
    private var captionFont: Font { .system(size: 10, weight: .medium, design: .monospaced) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    ForEach(SetupStep.allCases, id: \.self) { step in
                        Rectangle()
                            .fill(step <= currentStep ? theme.fontAccent : theme.textTertiary.opacity(0.28))
                            .frame(width: 14, height: 6)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 12)

                Group {
                    switch currentStep {
                    case .welcome: welcomeStep
                    case .vault: vaultStep
                    case .model: modelStep
                    case .done: doneStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 40)
            }

            Button("Use App Now") {
                completeSetupNow()
            }
            .font(captionFont)
            .buttonStyle(PixelSetupButtonStyle(theme: theme, prominence: .secondary))
            .padding(.top, 14)
            .padding(.trailing, 16)
        }
        .frame(width: 620, height: 620)
        .background {
            // Owner 2026-07-03: dynamic Metal backdrop (same pixel-art gradient as the
            // landing) instead of a static grid — the onboarding's "static backdrop = fake"
            // tell. Perf-gated (Reduce Motion + window-occluded).
            LiquidMetalSurface(
                base: theme.resolved.background.color,
                accent: theme.resolved.accent.color,
                intensity: 0.14,
                active: !ui.windowOccluded
            )
        }
    }

    // MARK: - Welcome

    @ViewBuilder
    private var welcomeStep: some View {
        VStack(spacing: 20) {
            SetupPixelGlyph(kind: .sigil, tint: theme.fontAccent)
            Text("Welcome to Epistemos")
                .font(AppDisplayTypography.font(size: 24))
                .foregroundStyle(theme.fontAccent)
            Text("Your local-first knowledge engine. Let's get you set up in a few quick steps.")
                .font(bodyFont)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Get Started") {
                withAnimation(stepTransitionAnimation) { currentStep = .vault }
            }
            .buttonStyle(PixelSetupButtonStyle(theme: theme, prominence: .primary))
        }
        .padding(.vertical, 24)
    }

    // MARK: - Vault

    @ViewBuilder
    private var vaultStep: some View {
        VStack(spacing: 16) {
            SetupPixelGlyph(kind: .vault, tint: .blue)
            Text("Connect Your Vault")
                .font(AppDisplayTypography.font(size: 20))
                .foregroundStyle(theme.fontAccent)
            Text("Choose the folder Epistemos should sync with. The app keeps local note bodies and can import from or sync out to Markdown files in your vault.")
                .font(bodyFont)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            if let url = vaultSync.vaultURL {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(theme.success)
                        .frame(width: 8, height: 8)
                    Text(url.lastPathComponent)
                        .font(captionFont)
                }
                .padding()
                .background(.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }

            if let details = vaultSync.visibleVaultImportDetails {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        if vaultSync.vaultImportProgress != nil {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(details.compactStatusMessage)
                            .font(captionFont)
                            .foregroundStyle(theme.textPrimary)
                    }
                    if let fraction = details.progressFraction, vaultSync.vaultImportProgress != nil {
                        ProgressView(value: fraction)
                    }
                    Text(details.inventorySummary)
                        .font(captionFont)
                        .foregroundStyle(theme.textSecondary)
                    Text("Result: \(details.mutationSummary). Diagnostics: \(details.issueSummary).")
                        .font(captionFont)
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(12)
                .background(theme.card.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Skip") { withAnimation(stepTransitionAnimation) { currentStep = .model } }
                    .buttonStyle(PixelSetupButtonStyle(theme: theme, prominence: .secondary))
                // SS-C/SS-E "derive-don't-ask": offer the auto-derived default vault
                // (~/Documents/Epistemos via FirstRunBootstrap.defaultVaultURL — which
                // was DEAD code, never invoked) as a one-tap "it just works" path,
                // instead of forcing the NSOpenPanel. The manual chooser stays.
                if vaultSync.vaultURL == nil {
                    Button("Use Default") { useDefaultVault() }
                        .buttonStyle(PixelSetupButtonStyle(theme: theme, prominence: .primary))
                }
                Button(vaultSync.vaultURL != nil ? "Change Vault" : "Select Vault Folder") {
                    selectVaultFolder()
                }
                .buttonStyle(PixelSetupButtonStyle(theme: theme, prominence: .primary))
                Button(vaultSync.vaultURL == nil ? "Skip Vault" : "Next") {
                    withAnimation(stepTransitionAnimation) { currentStep = .model }
                }
                    .buttonStyle(PixelSetupButtonStyle(theme: theme, prominence: .primary))
            }
        }
        .padding(.vertical, 24)
    }

    // MARK: - Foundation

    @ViewBuilder
    private var modelStep: some View {
        VStack(spacing: 16) {
            SetupPixelGlyph(kind: .vault, tint: .purple)
            Text("Foundation Features")
                .font(AppDisplayTypography.font(size: 20))
                .foregroundStyle(theme.fontAccent)
            Text("Epistemos keeps the native foundation focused on vault sync, fast search, provenance, skills, tools, and MCP connections. Model chat runs through the connected provider surfaces.")
                .font(bodyFont)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                statusRow("Vault sync", done: true)
                statusRow("Fast search", done: true)
                statusRow("Skills, tools, and MCP", done: true)
                statusRow("Provenance foundation", done: true)
            }
            .padding()
            .background(theme.card.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            Spacer()

            HStack(spacing: 12) {
                Button("Skip") { withAnimation(stepTransitionAnimation) { currentStep = .done } }
                    .buttonStyle(PixelSetupButtonStyle(theme: theme, prominence: .secondary))
                Button("Next") { withAnimation(stepTransitionAnimation) { currentStep = .done } }
                    .buttonStyle(PixelSetupButtonStyle(theme: theme, prominence: .primary))
            }
        }
        .padding(.vertical, 24)
    }

    // MARK: - Done

    @ViewBuilder
    private var doneStep: some View {
        VStack(spacing: 20) {
            SetupPixelGlyph(kind: .check, tint: theme.success)
            Text("You're All Set!")
                .font(AppDisplayTypography.font(size: 24))
                .foregroundStyle(theme.fontAccent)

            VStack(alignment: .leading, spacing: 8) {
                statusRow("Vault", done: vaultSync.vaultURL != nil)
                statusRow("Foundation", done: true)
            }

            Text("You can change any of these in Settings at any time.")
                .font(captionFont)
                .foregroundStyle(theme.textTertiary)

            // DISC-11: teach the key shortcuts at the perfect first-run moment.
            Text("Tip: ⌘N new note · ⌘K commands · ⌘2 your notes")
                .font(captionFont)
                .foregroundStyle(theme.textSecondary)

            Spacer()

            Button("Start Using Epistemos") {
                completeSetupNow()
            }
            .buttonStyle(PixelSetupButtonStyle(theme: theme, prominence: .primary))
        }
        .padding(.vertical, 24)
    }

    // MARK: - Helpers

    private func statusRow(_ name: String, done: Bool) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(done ? theme.success : theme.textTertiary.opacity(0.4))
                .frame(width: 8, height: 8)
            Text(name)
                .font(bodyFont)
        }
    }

    /// SS-C/SS-E: connect the auto-derived default vault (~/Documents/Epistemos)
    /// without an NSOpenPanel — the "it just works" path. The default may not exist
    /// yet (NSOpenPanel always returns an existing folder), so create it first; then
    /// connect via the same path a picked empty folder takes (assess → switch →
    /// bootstrap → persist).
    private func useDefaultVault() {
        let url = FirstRunBootstrap.defaultVaultURL()
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        VaultConnectionActions.connectSelectedVault(url: url, vaultSync: vaultSync)
    }

    private func selectVaultFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder for your Epistemos vault"
        panel.prompt = "Use as Vault"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        VaultConnectionActions.connectSelectedVault(url: url, vaultSync: vaultSync)
    }

    private func completeSetupNow() {
        UserDefaults.standard.set(true, forKey: "epistemos.setupComplete")
        ui.needsSetup = false
        onComplete()
    }
}

// MARK: - Setup Step

enum SetupStep: Int, CaseIterable, Comparable {
    case welcome = 0
    case vault = 1
    case model = 2
    case done = 3

    static func < (lhs: SetupStep, rhs: SetupStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

private struct PixelSetupBackground: View {
    let theme: EpistemosTheme

    var body: some View {
        ZStack {
            theme.resolved.background.color
            VStack(spacing: 10) {
                ForEach(0..<7, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(0..<10, id: \.self) { column in
                            Rectangle()
                                .fill(theme.fontAccent.opacity((row + column).isMultiple(of: 3) ? 0.045 : 0.02))
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(24)
        }
    }
}

private struct SetupPixelGlyph: View {
    enum Kind {
        case sigil
        case vault
        case chip
        case cloud
        case check
    }

    let kind: Kind
    let tint: Color

    var body: some View {
        Canvas { context, size in
            let cell = floor(min(size.width, size.height) / 12)
            let origin = CGPoint(
                x: floor((size.width - cell * 12) / 2),
                y: floor((size.height - cell * 12) / 2)
            )
            for block in blocks {
                let rect = CGRect(
                    x: origin.x + CGFloat(block.x) * cell,
                    y: origin.y + CGFloat(block.y) * cell,
                    width: CGFloat(block.w) * cell,
                    height: CGFloat(block.h) * cell
                )
                context.fill(Path(rect), with: .color(block.isAccent ? .white.opacity(0.75) : tint))
            }
        }
        .frame(width: 88, height: 88)
        .accessibilityHidden(true)
    }

    private var blocks: [(x: Int, y: Int, w: Int, h: Int, isAccent: Bool)] {
        switch kind {
        case .sigil:
            [
                (2, 2, 8, 2, false), (2, 4, 2, 6, false), (5, 4, 4, 2, false),
                (5, 7, 3, 2, false), (2, 10, 8, 1, false), (8, 6, 2, 4, false),
                (4, 6, 2, 1, true), (4, 8, 2, 1, true)
            ]
        case .vault:
            [
                (2, 3, 8, 5, false), (1, 8, 10, 2, false), (3, 2, 6, 1, false),
                (3, 4, 6, 1, true), (8, 6, 1, 1, true)
            ]
        case .chip:
            [
                (3, 3, 6, 6, false), (1, 4, 2, 1, false), (1, 7, 2, 1, false),
                (9, 4, 2, 1, false), (9, 7, 2, 1, false), (4, 1, 1, 2, false),
                (7, 1, 1, 2, false), (4, 9, 1, 2, false), (7, 9, 1, 2, false),
                (5, 5, 2, 2, true)
            ]
        case .cloud:
            [
                (3, 5, 7, 3, false), (2, 6, 9, 2, false), (4, 3, 3, 2, false),
                (7, 4, 3, 2, false), (4, 6, 4, 1, true)
            ]
        case .check:
            [
                (2, 6, 2, 2, false), (4, 8, 2, 2, false), (6, 6, 2, 2, false),
                (8, 4, 2, 2, false), (9, 3, 1, 1, false), (4, 8, 1, 1, true)
            ]
        }
    }
}

private struct PixelSetupButtonStyle: ButtonStyle {
    enum Prominence {
        case primary
        case secondary
    }

    let theme: EpistemosTheme
    let prominence: Prominence

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .textCase(.uppercase)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .foregroundStyle(foreground(isPressed: configuration.isPressed))
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(background(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(theme.fontAccent.opacity(0.55), lineWidth: 1)
            )
    }

    private func foreground(isPressed: Bool) -> Color {
        switch prominence {
        case .primary:
            isPressed ? theme.resolved.background.color.opacity(0.75) : theme.resolved.background.color
        case .secondary:
            isPressed ? theme.fontAccent.opacity(0.65) : theme.fontAccent
        }
    }

    private func background(isPressed: Bool) -> Color {
        switch prominence {
        case .primary:
            isPressed ? theme.fontAccent.opacity(0.78) : theme.fontAccent
        case .secondary:
            isPressed ? theme.fontAccent.opacity(0.14) : theme.fontAccent.opacity(0.06)
        }
    }
}
