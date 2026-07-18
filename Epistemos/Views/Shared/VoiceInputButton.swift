import SwiftUI

@MainActor
public final class VoiceInputSessionHandle {
    private var activeLease: VoiceCaptureLease?
    private weak var service: LiveVoiceInputService?

    public init() {}

    public var isActive: Bool {
        guard let activeLease, let service else { return false }
        return service.isOwner(activeLease)
    }

    fileprivate func bind(_ lease: VoiceCaptureLease, service: LiveVoiceInputService) {
        activeLease = lease
        self.service = service
    }

    fileprivate func clear(_ lease: VoiceCaptureLease) {
        guard activeLease == lease else { return }
        activeLease = nil
        service = nil
    }

    public func interrupt() -> String? {
        guard let activeLease, let service, service.isOwner(activeLease) else {
            self.activeLease = nil
            self.service = nil
            return nil
        }
        service.stop(owner: activeLease)
        let transcript = service.consumeTranscript(owner: activeLease)
        service.tearDown(owner: activeLease)
        self.activeLease = nil
        self.service = nil
        return transcript
    }
}

// MARK: - VoiceInputButton (W15.X — Apple-native STT wiring)
//
// Drop-in mirror of `ReadAloudButton` (W9.1) for the speech-to-text direction.
// Uses LiveVoiceInputService so views can offer "tap to dictate" without
// owning the audio lifecycle.
//
// Per the W11.4 Auto/Manual Mode contract: this reusable control treats
// dictation as a manual operation. Surfaces that support automatic
// silence-stop own that policy at their capture-service boundary.
//
// Lifecycle:
//   tap (idle) → recorder starts
//   tap (recording) → recorder stops → transcriber produces final text
//   final result → calls onFinal(text) so the host commits the text into its
//                  model (text field, note body, etc.)
//
// The control is stateful — flips between mic / mic.fill /
// stop.circle.fill depending on phase. Recording pulse color comes
// from the active Epistemos theme so custom palettes stay coherent.

@MainActor
public struct VoiceInputButton: View {

    public enum Style: Sendable, Equatable {
        /// Compact icon-only button; matches toolbar density.
        case icon
        /// Icon + "Dictate" / "Stop" label; matches menu rows.
        case labeled
        /// Icon with a pulsating ring while recording — matches the
        /// system Notes app dictation affordance.
        case iconWithPulse
    }

    public let style: Style
    public let purpose: VoiceCapturePurpose
    public let onPartial: (String) -> Void
    public let onActivityChange: (Bool) -> Void
    public let onInterrupted: (String) -> Void
    public let onFinal: (String) -> Void
    private let sessionHandle: VoiceInputSessionHandle?

    @State private var phase: Phase = .idle
    @State private var streamTask: Task<Void, Never>?
    @State private var service = LiveVoiceInputService.shared
    @State private var activeLease: VoiceCaptureLease?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(UIState.self) private var ui

    public init(
        style: Style = .icon,
        purpose: VoiceCapturePurpose = .editor,
        sessionHandle: VoiceInputSessionHandle? = nil,
        onPartial: @escaping (String) -> Void = { _ in },
        onActivityChange: @escaping (Bool) -> Void = { _ in },
        onInterrupted: @escaping (String) -> Void = { _ in },
        onFinal: @escaping (String) -> Void
    ) {
        self.style = style
        self.purpose = purpose
        self.sessionHandle = sessionHandle
        self.onPartial = onPartial
        self.onActivityChange = onActivityChange
        self.onInterrupted = onInterrupted
        self.onFinal = onFinal
    }

    private enum Phase: Sendable, Equatable {
        case idle
        case requesting     // model download / mic permission in flight
        case recording
        case error(String)
    }

    private static func isActive(_ phase: Phase) -> Bool {
        switch phase {
        case .requesting, .recording:
            return true
        case .idle, .error:
            return false
        }
    }

    public var body: some View {
        nativeButton
        .disabled(phase == .requesting)
        .onChange(of: service.partialTranscript) { _, newValue in
            guard let activeLease,
                  service.isOwner(activeLease),
                  !newValue.isEmpty else { return }
            onPartial(newValue)
        }
        .onChange(of: service.finalTranscript) { _, newValue in
            guard let activeLease,
                  service.isOwner(activeLease),
                  !newValue.isEmpty else { return }
            if let transcript = service.consumeTranscript(owner: activeLease) {
                onFinal(transcript)
                syncPhaseFromService()
            }
        }
        .onChange(of: service.state) { _, _ in
            syncPhaseFromService()
        }
        .onAppear {
            onActivityChange(Self.isActive(phase))
        }
        .onDisappear {
            stopInternal(interrupted: true)
        }
    }

    @ViewBuilder
    private var nativeButton: some View {
        switch style {
        case .icon, .labeled:
            toolbarButton
        case .iconWithPulse:
            ZStack {
                if phase == .recording {
                    recordingPulseRing
                }
                toolbarButton
            }
            .frame(width: 32, height: 32)
        }
    }

    private var toolbarButton: some View {
        ToolbarCapsuleButton(
            title: style == .labeled ? label : nil,
            systemImage: glyph,
            role: controlRole,
            isActive: phase == .recording || phase == .requesting,
            chromePolicy: chromePolicy,
            helpText: help,
            accessibilityLabel: label
        ) {
            toggle()
        }
    }

    private var glyph: String {
        switch phase {
        case .idle:       return "mic"
        case .requesting: return "mic.badge.plus"
        case .recording:  return "stop.circle.fill"
        case .error:      return "mic.slash"
        }
    }

    private var label: String {
        switch phase {
        case .idle:       return "Dictate"
        case .requesting: return "Preparing…"
        case .recording:  return "Stop"
        case .error:      return "Unavailable"
        }
    }

    private var controlRole: NativeControlRole {
        switch phase {
        case .recording:
            return .primaryAction
        case .error:
            return .secondaryGhost
        case .idle, .requesting:
            return .toolbarUtility
        }
    }

    private var chromePolicy: NativeControlChromePolicy {
        switch style {
        case .labeled:
            return .alwaysSurface
        case .icon, .iconWithPulse:
            return phase == .idle ? .bareUntilPressed : .alwaysSurface
        }
    }

    private var help: String {
        switch phase {
        case .idle:                    return "Dictate"
        case .requesting:              return "Preparing voice capture…"
        case .recording:               return "Stop dictation"
        case .error(let msg):          return msg
        }
    }

    @ViewBuilder
    private var recordingPulseRing: some View {
        if reduceMotion || ui.windowOccluded {
            Circle()
                .stroke(ui.theme.resolved.accent.color.opacity(0.28), lineWidth: 1.5)
                .frame(width: 26, height: 26)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let progress = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 1.0)
                Circle()
                    .stroke(ui.theme.resolved.accent.color.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 26, height: 26)
                    .scaleEffect(1.0 + progress)
                    .opacity(1.0 - progress)
            }
        }
    }

    // MARK: - Toggle

    private func toggle() {
        switch phase {
        case .idle, .error:
            startInternal()
        case .recording:
            finishInternal()
        case .requesting:
            break
        }
    }

    private func startInternal() {
        if let activeLease {
            service.tearDown(owner: activeLease)
            sessionHandle?.clear(activeLease)
        }
        let owner = VoiceCaptureLease(purpose: purpose)
        activeLease = owner
        sessionHandle?.bind(owner, service: service)
        transition(to: .requesting)
        streamTask?.cancel()
        streamTask = Task {
            let result = await service.start(owner: owner)
            guard activeLease == owner else {
                service.tearDown(owner: owner)
                sessionHandle?.clear(owner)
                return
            }
            switch result {
            case .started:
                syncPhaseFromService()
            case .busy(let activePurpose):
                sessionHandle?.clear(owner)
                activeLease = nil
                transition(to: .error("Voice capture is already in use by \(activePurpose.displayName)."))
            case .permissionDenied(let message), .unavailable(let message), .failed(let message):
                service.tearDown(owner: owner)
                sessionHandle?.clear(owner)
                activeLease = nil
                transition(to: .error(message))
            case .cancelled:
                service.tearDown(owner: owner)
                sessionHandle?.clear(owner)
                activeLease = nil
                transition(to: .idle)
            }
        }
    }

    private func finishInternal() {
        guard let owner = activeLease else {
            transition(to: .idle)
            return
        }
        transition(to: .requesting)
        streamTask?.cancel()
        streamTask = Task {
            drainAndRelease(owner, terminalPhase: .idle, interrupted: false)
        }
    }

    private func stopInternal(interrupted: Bool) {
        streamTask?.cancel()
        streamTask = nil
        if let owner = activeLease {
            drainAndRelease(owner, terminalPhase: .idle, interrupted: interrupted)
        } else {
            transition(to: .idle)
        }
    }

    private func syncPhaseFromService() {
        guard let activeLease, service.isOwner(activeLease) else { return }
        switch service.state {
        case .idle:
            drainAndRelease(activeLease, terminalPhase: .idle, interrupted: false)
        case .preparing:
            transition(to: .requesting)
        case .recording:
            transition(to: .recording)
        case .unavailable(let message), .error(let message):
            drainAndRelease(activeLease, terminalPhase: .error(message), interrupted: true)
        }
    }

    private func drainAndRelease(
        _ owner: VoiceCaptureLease,
        terminalPhase: Phase,
        interrupted: Bool
    ) {
        service.stop(owner: owner)
        if let transcript = service.consumeTranscript(owner: owner) {
            if interrupted {
                onInterrupted(transcript)
            } else {
                onFinal(transcript)
            }
        }
        service.tearDown(owner: owner)
        sessionHandle?.clear(owner)
        if activeLease == owner {
            activeLease = nil
        }
        transition(to: terminalPhase)
    }

    private func transition(to newPhase: Phase) {
        let wasActive = Self.isActive(phase)
        phase = newPhase
        let isActive = Self.isActive(newPhase)
        if wasActive != isActive {
            onActivityChange(isActive)
        }
    }
}

#if DEBUG
@available(macOS 26.0, *)
#Preview("VoiceInputButton — three styles") {
    VStack(spacing: 16) {
        VoiceInputButton(purpose: .editor,
                         onFinal: { print("FINAL: \($0)") })
        VoiceInputButton(style: .labeled,
                         purpose: .editor,
                         onFinal: { print("FINAL: \($0)") })
        VoiceInputButton(style: .iconWithPulse,
                         purpose: .editor,
                         onPartial: { print("partial: \($0)") },
                         onFinal: { print("FINAL: \($0)") })
    }
    .padding(20)
    .environment(UIState())
}
#endif
