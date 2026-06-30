import SwiftUI

@MainActor
struct VoiceSettingsDetailView: View {
    var body: some View {
        Form {
            VoicePreferencesSection()

            #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
            KokoroVoiceProSettingsSection()
            #endif
        }
    }
}

#if DEBUG
#Preview("VoiceSettingsDetailView") {
    VoiceSettingsDetailView()
        .frame(width: 560, height: 640)
}
#endif
