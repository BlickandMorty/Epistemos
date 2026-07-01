import SwiftUI

@MainActor
struct VoiceSettingsDetailView: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        Form {
            voiceHeader
            VoicePreferencesSection()

            #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
            KokoroVoiceProSettingsSection()
            #endif
        }
    }

    private var voiceHeader: some View {
        HStack(spacing: 10) {
            IntegrationBrandMarkView(brand: .voice, size: 28)
                .foregroundStyle(ui.theme.resolved.accent.color)
            VStack(alignment: .leading, spacing: 2) {
                Text("Voice")
                    .font(.title3.weight(.semibold))
                Text("Speech and dictation runtime")
                    .font(.caption)
                    .foregroundStyle(ui.theme.resolved.mutedForeground.color)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("VoiceSettingsDetailView") {
    VoiceSettingsDetailView()
        .environment(UIState())
        .frame(width: 560, height: 640)
}
#endif
