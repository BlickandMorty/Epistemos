#if EPISTEMOS_APP_STORE
import SwiftData
import SwiftUI

/// The MAS Agent-room toolbar pill (Plan 1-MAS §7): Home / New Chat /
/// All Chats wrapping the vendored June surface. Mirrors the Pro track's
/// ProAgentNavBar metrics so both builds' chrome reads identically. Drives
/// June via intent events (JuneAgentIntents), never URL reloads; the
/// all-chats sheet presents from here so RootView stays a one-branch mount.
struct JuneAgentNavBar: View {
    let theme: EpistemosTheme
    let onReturnHome: () -> Void

    @State private var showingAllChats = false
    @State private var showingNotes = false
    // Observed so the button flips speaker⇄stop as playback starts/ends. We
    // CONSUME the shared synthesizer (owned by the app-wide voice agent); the
    // June surface never synthesizes or plays audio itself.
    @State private var speech = EpistemosSpeechSynthesizer.shared

    /// Kokoro-ready gate (no AVSpeech fallback): disables the button honestly
    /// when TTS isn't available, per the read-aloud contract.
    private var ttsAvailable: Bool { EpistemosSpeechSynthesizer.isTextToSpeechAvailable() }

    private enum Metrics {
        static let navSlotHeight: CGFloat = 38
        static let leadingWidth: CGFloat = 116
        static let notesWidth: CGFloat = 92
        static let iconSize: CGFloat = 15
    }

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onReturnHome) {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: Metrics.iconSize, weight: .semibold))
                    Text("Epistemos")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
                .frame(width: Metrics.leadingWidth, height: Metrics.navSlotHeight)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textPrimary.opacity(0.92))
            .background(theme.textPrimary.opacity(theme.isDark ? 0.07 : 0.045), in: Capsule())
            .help("Back to Epistemos")
            .accessibilityLabel("Back to Epistemos")

            Button {
                JuneAgentIntents.newSession()
            } label: {
                Image(systemName: "plus.bubble")
                    .font(.system(size: Metrics.iconSize, weight: .semibold))
                    .frame(width: Metrics.navSlotHeight, height: Metrics.navSlotHeight)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textPrimary.opacity(0.92))
            .background(theme.textPrimary.opacity(theme.isDark ? 0.07 : 0.045), in: Capsule())
            .help("New agent session")
            .accessibilityLabel("New agent session")

            Button {
                showingAllChats = true
            } label: {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: Metrics.iconSize, weight: .semibold))
                    .frame(width: Metrics.navSlotHeight, height: Metrics.navSlotHeight)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textPrimary.opacity(0.92))
            .background(theme.textPrimary.opacity(theme.isDark ? 0.07 : 0.045), in: Capsule())
            .help("All agent sessions")
            .accessibilityLabel("All agent sessions")
            .sheet(isPresented: $showingAllChats) {
                JuneAllChatsSheet()
            }

            Button {
                showingNotes = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: Metrics.iconSize, weight: .semibold))
                    Text("Notes")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
                .frame(width: Metrics.notesWidth, height: Metrics.navSlotHeight)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textPrimary.opacity(0.92))
            .background(theme.textPrimary.opacity(theme.isDark ? 0.07 : 0.045), in: Capsule())
            .help("Browse and search notes")
            .accessibilityLabel("Browse and search notes")
            .appKitPopover(isPresented: $showingNotes, behavior: .semitransient) {
                JuneNotesBrowserPopover()
            }

            Button {
                if speech.isSpeaking {
                    speech.stop()
                } else if let text = JuneAgentSurfaceHolder.shared.bridge?.gateway.latestAssistantReply() {
                    // voiceIdentifier defaults to the user's ModelVoicePickerSection
                    // pick (Kokoro on MAS) — never hardcoded here. Audio is
                    // synthesized native-side by the shared engine.
                    _ = speech.speak(text)
                }
            } label: {
                Image(systemName: speech.isSpeaking ? "stop.fill" : "speaker.wave.2")
                    .font(.system(size: Metrics.iconSize, weight: .semibold))
                    .frame(width: Metrics.navSlotHeight, height: Metrics.navSlotHeight)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textPrimary.opacity((ttsAvailable || speech.isSpeaking) ? 0.92 : 0.32))
            .background(theme.textPrimary.opacity(theme.isDark ? 0.07 : 0.045), in: Capsule())
            .disabled(!ttsAvailable && !speech.isSpeaking)
            .help(ttsAvailable ? "Read the latest reply aloud" : EpistemosSpeechSynthesizer.textToSpeechStatusMessage())
            .accessibilityLabel(speech.isSpeaking ? "Stop reading aloud" : "Read the latest reply aloud")
        }
    }
}

private struct JuneNotesBrowserPopover: View {
    private enum Metrics {
        static let width: CGFloat = 380
        static let height: CGFloat = 520
    }

    var body: some View {
        Group {
            if let bootstrap = AppBootstrap.shared {
                NotesBrowserView()
                    .frame(width: Metrics.width, height: Metrics.height)
                    .withAppEnvironment(bootstrap)
                    .modelContainer(bootstrap.modelContainer)
            } else {
                ContentUnavailableView(
                    "Notes Unavailable",
                    systemImage: "note.text",
                    description: Text("Finish app setup to browse notes.")
                )
                .frame(width: Metrics.width, height: 220)
            }
        }
    }
}
#endif
