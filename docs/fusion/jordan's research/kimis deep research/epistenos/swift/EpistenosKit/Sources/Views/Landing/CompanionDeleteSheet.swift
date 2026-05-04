import SwiftUI

// ---------------------------------------------------------------------------
// MARK: - CompanionDeleteSheet
// ---------------------------------------------------------------------------

/// A confirmation sheet for permanently deleting a companion.
///
/// Delete is classified as **Destructive** per doctrine §4.2, therefore it
/// routes through `SovereignGate` with `.deviceOwnerAuthentication`.
/// On success the companion fades and shrinks out over 0.3 s (unless
/// reduced motion is enabled).
///
/// An `AgentProvenanceEvent` with `kind = .vault_archived` is emitted on
/// deletion for audit purposes.
public struct CompanionDeleteSheet: View {
    let companion: CompanionModel
    @Environment(CompanionState.self) private var companionState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isGating = false
    @State private var isDeleting = false
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    @State private var errorMessage: String?

    public init(companion: CompanionModel) {
        self.companion = companion
    }

    public var body: some View {
        VStack(spacing: 24) {
            warningIcon
                .frame(width: 48, height: 48)
                .scaleEffect(scale)
                .opacity(opacity)

            VStack(spacing: 8) {
                Text("Delete \"\(companion.name)\"?")
                    .font(.title3.bold())
                Text("This cannot be undone. The companion and its history will be permanently removed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }

            if isGating {
                ProgressView()
                    .scaleEffect(1.0)
                    .padding(.vertical, 4)
            }

            HStack(spacing: 12) {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Delete", role: .destructive) {
                    performDelete()
                }
                .disabled(isGating || isDeleting)
                .keyboardShortcut(.return, modifiers: [.command, .shift])
            }
        }
        .padding(32)
        .frame(minWidth: 380, minHeight: 240)
        .onAppear {
            if reduceMotion {
                scale = 1.0
                opacity = 1.0
            }
        }
    }

    // MARK: - Warning Icon

    @ViewBuilder
    private var warningIcon: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.12))
                .frame(width: 48, height: 48)
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.red)
        }
    }

    // MARK: - Delete Action

    private func performDelete() {
        guard !isGating, !isDeleting else { return }
        isGating = true
        errorMessage = nil

        Task { @MainActor in
            do {
                try await SovereignGate.shared.gate(
                    requirement: .deviceOwnerAuthentication,
                    reason: "Delete companion \"\(companion.name)\"? This cannot be undone."
                ) { [weak self] in
                    guard let self else { return }
                    await executeDeleteAnimation()
                }
            } catch is SovereignGateError {
                isGating = false
                errorMessage = "Authentication required to delete."
            } catch {
                isGating = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func executeDeleteAnimation() async {
        isGating = false
        isDeleting = true

        if !reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) {
                scale = 0.1
                opacity = 0.0
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        do {
            try await companionState.deleteCompanion(companion)
            dismiss()
        } catch {
            // Rollback animation on failure
            if !reduceMotion {
                withAnimation(.easeIn(duration: 0.2)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
            isDeleting = false
            errorMessage = error.localizedDescription
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - Preview
// ---------------------------------------------------------------------------

#if DEBUG
#Preview {
    let companion = CompanionModel(
        name: "Amber",
        baseProfile: "default",
        cosmeticConfig: CosmeticConfig(colorTheme: "amber", avatarShape: "orb", idleBreathingRate: 1.0)
    )
    return CompanionDeleteSheet(companion: companion)
        .environment(CompanionState())
        .frame(width: 420, height: 300)
}
#endif
