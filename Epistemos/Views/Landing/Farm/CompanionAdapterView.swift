import SwiftUI

/// Deferred adapter UI for Simulation Mode v1.6.
///
/// The MLX LoRA hot-swap pipeline is not wired for v1, so this scaffold is
/// intentionally not mounted from the Landing Farm context menu. If another
/// caller presents it, it renders an honest deferred state instead of accepting
/// a path and pretending the adapter applied.
struct CompanionAdapterView: View {
    let entry: CompanionRosterEntry
    var theme: EpistemosTheme
    var onDismiss: () -> Void = {}

    private var accent: Color {
        Color(hex: entry.accentHex) ?? .accentColor
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.18)
            stage
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            Divider().opacity(0.18)
            deferredNotice
            footer
        }
        .frame(width: 480)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.22), lineWidth: 0.6)
        )
    }

    // MARK: - Header / Footer

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(accent)
            Text("Adapter Pipeline Deferred - \(entry.name)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
            Spacer()
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
            Spacer()
            Button {
                onDismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                    Text("Done")
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(accent.opacity(0.14)))
                .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Deferred Notice

    private var deferredNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LoRA adapter hot-swap")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
            Text("Deferred for v1 until the MLX adapter loader, file validation, and rollback path are wired.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    // MARK: - Stage (Invariant I-11)

    @ViewBuilder
    private var stage: some View {
        ZStack {
            CompanionView(entry: entry, size: 80)
                .opacity(0.48)

            Circle()
                .stroke(accent.opacity(0.22), lineWidth: 1)
                .frame(width: 132, height: 132)
            Image(systemName: "lock")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accent.opacity(0.8))
                .offset(y: 58)
        }
    }
}
