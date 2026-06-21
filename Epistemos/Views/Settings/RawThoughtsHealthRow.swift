import SwiftUI

// MARK: - RawThoughtsHealthRow
//
// SS-GE (owner 2026-06-21): the owner "didn't see raw thoughts in the vault,
// wasn't sure it's still a thing." Raw Thoughts V0 records each model run's raw
// thinking + tool calls into <vault>/Raw Thoughts/, but the per-vault sidebar
// surface hides entirely when the emitter flag is off (canon), so a user with
// the flag off sees nothing at all. This read-only Diagnostics row makes the
// feature discoverable + honest: whether it's recording, how to turn it on, and
// where to browse runs — WITHOUT flipping the default-off emitter flag or adding
// a do-nothing toggle. It reads RawThoughtsState's static helpers only (no
// @Environment dependency), so it can live in Settings with no launch-crash risk.

@MainActor
public struct RawThoughtsHealthRow: View {

    @State private var enabled: Bool = RawThoughtsState.isEmissionEnabled

    public init() {}

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "brain")
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Raw Thoughts (V0)")
                    .font(.system(size: 13, weight: .medium))
                Text(RawThoughtsState.diagnosticStatus(isEnabled: enabled))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            // Off is a deliberate opt-in, not an error → a neutral circle, never a
            // red xmark (which would misread as "broken").
            Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(enabled ? AnyShapeStyle(Color.green) : AnyShapeStyle(Color.secondary))
                .font(.system(size: 16))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear { enabled = RawThoughtsState.isEmissionEnabled }
    }
}
