import Foundation
import OSLog

public enum EpistemosVisibleReadAloudSurface: String, CaseIterable, Sendable {
    case landingHome
    case juneLatestAssistantReply
    case proseNoteBody
    case codeEditor
    case epdocSelection
    case quickCapture
    case meetingTranscript
    case htmlWorkspaceSource

    var label: String {
        switch self {
        case .landingHome:
            return "home screen"
        case .juneLatestAssistantReply:
            return "June latest assistant reply"
        case .proseNoteBody:
            return "note body"
        case .codeEditor:
            return "code editor"
        case .epdocSelection:
            return "selected document text"
        case .quickCapture:
            return "Quick Capture text"
        case .meetingTranscript:
            return "meeting transcript"
        case .htmlWorkspaceSource:
            return "HTML Workspace source"
        }
    }
}

@MainActor
final class EpistemosVisibleReadAloudRegistry {
    typealias Provider = @MainActor () -> String?

    static let shared = EpistemosVisibleReadAloudRegistry()

    private var providers: [EpistemosVisibleReadAloudSurface: Provider] = [:]
    private var activeSurface: EpistemosVisibleReadAloudSurface?

    private init() {}

    func register(
        _ surface: EpistemosVisibleReadAloudSurface,
        activate: Bool = true,
        provider: @escaping Provider
    ) {
        providers[surface] = provider
        if activate {
            activeSurface = surface
        }
    }

    func unregister(_ surface: EpistemosVisibleReadAloudSurface) {
        providers.removeValue(forKey: surface)
        if activeSurface == surface {
            activeSurface = providers.keys.first
        }
    }

    func markActive(_ surface: EpistemosVisibleReadAloudSurface) {
        if providers[surface] != nil {
            activeSurface = surface
        }
    }

    func visibleText(
        preferred surface: EpistemosVisibleReadAloudSurface? = nil
    ) -> (surface: EpistemosVisibleReadAloudSurface, text: String)? {
        let orderedSurfaces: [EpistemosVisibleReadAloudSurface]
        if let surface {
            orderedSurfaces = [surface]
        } else if let activeSurface {
            orderedSurfaces = [activeSurface] + EpistemosVisibleReadAloudSurface.allCases.filter { $0 != activeSurface }
        } else {
            orderedSurfaces = EpistemosVisibleReadAloudSurface.allCases
        }

        for candidate in orderedSurfaces {
            guard let provider = providers[candidate],
                  let raw = provider()?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else {
                continue
            }
            return (candidate, raw)
        }
        return nil
    }
}

@MainActor
enum EpistemosReadAloudDiagnostics {
    private static let log = Logger(subsystem: "com.epistemos", category: "Speech.ReadAloud")

    static func showUnavailableToast(_ message: String? = nil) {
        let resolved = message ?? EpistemosSpeechSynthesizer.textToSpeechStatusMessage()
        AppBootstrap.shared?.uiState.showToast(resolved, type: .warning)
        log.warning("Read-aloud unavailable: \(resolved, privacy: .public)")
    }

    static func showFailureToast(_ message: String) {
        AppBootstrap.shared?.uiState.showToast(message, type: .error)
        log.error("Read-aloud failed: \(message, privacy: .public)")
    }

    static func showNoVisibleTextToast(surface: EpistemosVisibleReadAloudSurface? = nil) {
        let subject = surface?.label ?? "current surface"
        AppBootstrap.shared?.uiState.showToast("Nothing readable on the \(subject).", type: .info)
        log.notice("Read-aloud skipped; no visible text for \(subject, privacy: .public)")
    }

    static func showExcerptToast(surface: EpistemosVisibleReadAloudSurface) {
        AppBootstrap.shared?.uiState.showToast(
            "Reading the first visible passage from the \(surface.label). Select text for a narrower read.",
            type: .info
        )
        log.notice("Read-aloud excerpted long visible text for \(surface.rawValue, privacy: .public)")
    }

    static func showQueuedToast(surface: EpistemosVisibleReadAloudSurface? = nil) {
        let subject = surface?.label ?? "selection"
        AppBootstrap.shared?.uiState.showToast(
            "Preparing Kokoro read-aloud for the \(subject)...",
            type: .info
        )
        log.notice("Read-aloud queued for \(subject, privacy: .public)")
    }

    static func showInputExcerptToast() {
        AppBootstrap.shared?.uiState.showToast(
            "Reading the first supported passage. Select text for a narrower read.",
            type: .info
        )
        log.notice("Read-aloud excerpted long text without a registered surface")
    }
}
