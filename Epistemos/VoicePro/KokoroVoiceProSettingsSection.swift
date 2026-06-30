import SwiftUI

nonisolated enum KokoroVoiceProSettingsModel {
    enum RuntimeChoice: String, CaseIterable, Identifiable, Sendable {
        case appleAVSpeech
        case kokoroProNeural

        var id: String { rawValue }

        var title: String {
            switch self {
            case .appleAVSpeech:
                return "Apple AVSpeech"
            case .kokoroProNeural:
                return "Pro neural voice"
            }
        }
    }

    struct Presentation: Equatable, Sendable {
        let selectedRuntime: RuntimeChoice
        let proRuntimeEnabled: Bool
        let headline: String
        let detail: String
        let badgeTitle: String
    }

    static func presentation(for status: KokoroVoiceGateStatus.Status) -> Presentation {
        switch status.state {
        case .packageReady:
            return Presentation(
                selectedRuntime: .appleAVSpeech,
                proRuntimeEnabled: false,
                headline: status.headline,
                detail: status.detail,
                badgeTitle: "Package ready"
            )
        case .missingModel:
            return Presentation(
                selectedRuntime: .appleAVSpeech,
                proRuntimeEnabled: false,
                headline: status.headline,
                detail: status.detail,
                badgeTitle: "Model required"
            )
        case .unavailable:
            return Presentation(
                selectedRuntime: .appleAVSpeech,
                proRuntimeEnabled: false,
                headline: status.headline,
                detail: status.detail,
                badgeTitle: "Unavailable"
            )
        }
    }
}

@MainActor
struct KokoroVoiceProSettingsSection: View {
    @State private var status = KokoroVoiceGateStatus.status()

    var body: some View {
        let presentation = KokoroVoiceProSettingsModel.presentation(for: status)

        Section("Voice Pro") {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "waveform.badge.sparkles")
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Kokoro-82M")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(presentation.badgeTitle)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill((presentation.proRuntimeEnabled ? Color.green : Color.orange).opacity(0.16))
                            )
                            .foregroundStyle(presentation.proRuntimeEnabled ? .green : .orange)
                    }

                    Picker("Runtime", selection: .constant(presentation.selectedRuntime)) {
                        ForEach(KokoroVoiceProSettingsModel.RuntimeChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(!presentation.proRuntimeEnabled)

                    Text(presentation.headline)
                        .font(.caption.weight(.semibold))
                    Text(presentation.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                status = KokoroVoiceGateStatus.status()
            } label: {
                Label("Refresh Pro voice status", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
    }
}

#if DEBUG
#Preview("KokoroVoiceProSettingsSection") {
    Form {
        KokoroVoiceProSettingsSection()
    }
    .frame(width: 540, height: 260)
}
#endif
