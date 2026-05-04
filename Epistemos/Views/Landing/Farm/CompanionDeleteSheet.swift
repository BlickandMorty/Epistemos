import SwiftUI

/// Soft-delete sheet (Invariant I-12). Routes through the canonical
/// SovereignGate (`Epistemos/Sovereign/SovereignGate.swift`) — single
/// LAContext owner per doctrine §A.7. Touch ID prompt explains exactly
/// what's being authorized; reduce-motion-friendly fade animation.
///
/// Soft delete = sets `archivedAt` on the CompanionModel; the
/// companion moves to trash and is restorable until the user
/// explicitly purges from the Restore sheet.
struct CompanionDeleteSheet: View {
    let entry: CompanionRosterEntry
    @Bindable var companionState: CompanionState
    let sovereignGate: SovereignGate
    var theme: EpistemosTheme
    var onDismiss: () -> Void = {}

    @State private var phase: Phase = .confirm
    @State private var errorMessage: String? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Phase: Equatable {
        case confirm
        case authenticating
        case fading
        case done
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(theme.resolved.accent.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Move \(entry.name) to trash?")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                    Text("Restorable from the trash chip until you purge.")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

            HStack(spacing: 16) {
                CompanionView(entry: entry, size: 64)
                    .opacity(phase == .fading ? 0 : 1)
                    .scaleEffect(phase == .fading ? 0.65 : 1.0)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.45), value: phase)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Body: \(entry.bodyKind.displayName)")
                    if !entry.tagline.isEmpty {
                        Text(entry.tagline)
                    }
                    Text("Created \(entry.createdAt.formatted(date: .abbreviated, time: .shortened))")
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)

            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.resolved.accent.color.opacity(0.85))
                    .padding(.horizontal, 18)
            }

            Divider().opacity(0.18)

            HStack(spacing: 10) {
                Button("Cancel") { onDismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                if phase == .authenticating {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small).scaleEffect(0.8)
                        Text("Touch ID…")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.textSecondary)
                    }
                } else {
                    Button {
                        Task { await confirmAndArchive() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                            Text("Move to trash")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(theme.resolved.accent.color))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(phase != .confirm)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .frame(width: 460)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.resolved.accent.color.opacity(0.20), lineWidth: 0.6)
        )
    }

    @MainActor
    private func confirmAndArchive() async {
        phase = .authenticating
        errorMessage = nil

        // Sovereign Gate — Sensitive class (15-min biometric grace).
        // Reason string explains exactly what's being authorized so
        // the LAContext prompt is honest. Single LAContext owner per
        // doctrine §A.7 — never re-implement biometric here.
        let outcome = await sovereignGate.confirm(
            .biometric(category: SovereignGateCategory(rawValue: "companion_archive")),
            reason: "Move companion '\(entry.name)' to trash"
        )

        switch outcome {
        case .allowed:
            phase = .fading
            // Brief fade-out so the user sees the orb dissolve before
            // the sheet snaps shut. Pure cosmetic; the SwiftData
            // archive call below is what actually moves the companion
            // to trash.
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 480))
            companionState.archive(entry.id)
            phase = .done
            onDismiss()

        case .denied(let reason):
            phase = .confirm
            switch reason {
            case .missingReason:
                errorMessage = "Sovereign Gate: missing reason."
            case .authenticationFailed:
                errorMessage = "Authentication failed. Try again."
            }
        }
    }
}
