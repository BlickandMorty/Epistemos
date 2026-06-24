import AppKit
#if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
import OsaurusCore
#endif
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// ACT = Epistemos's real chat UI with the Osaurus engine and capability layer
// recalled into it. Epistemos owns the visible landing, toolbar, message bar,
// side panel, recent-chat popover, and settings chrome; Osaurus owns the model,
// streaming, tools, permissions, and management data behind that chrome.

enum LandingToolbarGlyphs {
    static let greetingSymbol = "textformat"
}

enum HomeWindowIdentity {
    static let title = "Epistemos"
    static let sceneIdentifier = "main"

    static func matches(_ window: NSWindow?) -> Bool {
        guard let window else { return false }
        return window.identifier?.rawValue == sceneIdentifier
            || window.title == title
    }

    static func apply(to window: NSWindow) {
        if window.identifier?.rawValue != sceneIdentifier {
            window.identifier = NSUserInterfaceItemIdentifier(sceneIdentifier)
        }
    }

    /// Lock the window's AppKit appearance (and the toolbar's, if present)
    /// to the in-app theme. This is what eliminates the brief flash of an
    /// old theme at the title bar during the landing → main-chat
    /// transition: without this, the title bar paints via the SYSTEM
    /// appearance until the SwiftUI toolbar background materializes (the
    /// 350 ms reveal gate at the bottom of `rootContent`). With an
    /// explicit `NSAppearance(named: …)` set, the title bar always
    /// matches `ui.theme.isDark`.
    @MainActor
    static func applyAppearance(to window: NSWindow, isDark: Bool) {
        let target: NSAppearance? = NSAppearance(named: isDark ? .darkAqua : .aqua)
        if window.appearance != target {
            window.appearance = target
        }
        if let toolbar = window.toolbar, let _ = toolbar.identifier as String? {
            // NSToolbar inherits appearance from its window, so no extra
            // assignment is needed — but stamping the window covers both
            // the title bar and the toolbar surface in one assignment.
            _ = toolbar
        }
    }

    @MainActor
    static func surfaceHomeWindow() {
        NSApp.activate(ignoringOtherApps: true)
        guard let mainWindow = NSApp.windows.first(where: matches) else { return }
        if mainWindow.isMiniaturized {
            mainWindow.deminiaturize(nil)
        }
        mainWindow.orderFrontRegardless()
        mainWindow.makeKeyAndOrderFront(nil)

        Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(50))
            } catch {
                return
            }

            guard let mainWindow = NSApp.windows.first(where: matches) else { return }
            if mainWindow.isMiniaturized {
                mainWindow.deminiaturize(nil)
            }
            mainWindow.orderFrontRegardless()
            mainWindow.makeKeyAndOrderFront(nil)
        }
    }
}

enum HomeWindowInputFocus {
    @MainActor
    static func restoreAfterOverlayDismiss() {
        NSApp.keyWindow?.makeFirstResponder(nil)

        Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(20))
            } catch {
                return
            }

            HomeWindowIdentity.surfaceHomeWindow()
            NSApp.windows.first(where: HomeWindowIdentity.matches)?.makeFirstResponder(nil)
        }
    }
}

enum AppWindowBackdropStyle {
    /// Eighth-pass+2 fix (2026-05-13): the window backdrop ALWAYS routes
    /// through `surfaceVariant(.mainChat)` so it matches whatever surface
    /// the active view is painting. Landing + main chat both map to the
    /// same variant via `surfaceVariant`'s policy:
    ///   .platinumVioletDark → .nocturne for both .landing + .mainChat
    ///   .oled                → .oled    for both .landing + .mainChat
    ///   everything else      → identity
    /// so a single resolution covers both surfaces and eliminates the
    /// "top bar flickers a different theme" the user reported during
    /// landing → main-chat transition. Previously the backdrop painted
    /// the RAW `theme.resolved.background` while landing/chat views
    /// painted their surface-variant colors; on Platinum-violet-dark
    /// the raw theme (purple) and the variant (nocturne grey) differ,
    /// so the system toolbar glass — which tints from the window
    /// background — briefly leaked the purple hue during the SwiftUI
    /// transition before the variant repainted.
    nonisolated static func backgroundToken(
        for theme: EpistemosTheme
    ) -> EpistemosTheme.ResolvedColorToken {
        theme.surfaceVariant(.mainChat).resolved.background
    }

    nonisolated static func background(for theme: EpistemosTheme) -> Color {
        backgroundToken(for: theme).color
    }
}

enum RootViewDestructiveActionSovereignGate {
    enum Target: Equatable {
        case databaseReset
        case vaultDisconnect
    }

    static func requirement(for _: Target) -> SovereignGateRequirement {
        .deviceOwnerAuthentication
    }

    static func reason(for target: Target) -> String {
        switch target {
        case .databaseReset:
            "Reset database and delete saved data."
        case .vaultDisconnect:
            "Disconnect vault from this workspace."
        }
    }
}

#if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
@MainActor
enum ActOsaurusNativePromptPresenter {
    private static var permissionWindow: NSPanel?
    private static var closeObserver: NSObjectProtocol?
    private static var keyMonitor: Any?
    private static var activeResolve: ((EpistemosOsaurusNativeToolPermissionDecision) -> Void)?

    static func install() {
        EpistemosOsaurusManagementBridge.installNativeToolPermissionPresenter { request in
            await presentToolPermission(request)
        }
        EpistemosOsaurusManagementBridge.installNativeProviderCredentialPresenter { request in
            await presentProviderCredential(request)
        }
        EpistemosOsaurusManagementBridge.installNativePairingPresenter { request in
            await presentPairing(request)
        }
    }

    private static func presentToolPermission(
        _ request: EpistemosOsaurusNativeToolPermissionRequest
    ) async -> EpistemosOsaurusNativeToolPermissionDecision {
        guard let bootstrap = AppBootstrap.shared else { return .deny }
        return await withCheckedContinuation { continuation in
            presentToolPermission(
                request,
                theme: bootstrap.uiState.theme.surfaceVariant(.mainChat),
                continuation: continuation
            )
        }
    }

    private static func presentToolPermission(
        _ request: EpistemosOsaurusNativeToolPermissionRequest,
        theme: EpistemosTheme,
        continuation: CheckedContinuation<EpistemosOsaurusNativeToolPermissionDecision, Never>
    ) {
        dismissPermissionWindow()
        var hasResumed = false

        let resolve: (EpistemosOsaurusNativeToolPermissionDecision) -> Void = { decision in
            guard !hasResumed else { return }
            hasResumed = true
            dismissPermissionWindow()
            continuation.resume(returning: decision)
        }
        activeResolve = resolve

        let view = ActNativeToolPermissionPromptView(
            request: request,
            theme: theme,
            onResolve: resolve
        )
        .padding(24)

        let hosting = NSHostingController(rootView: view)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .modalPanel
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .alertPanel
        panel.contentViewController = hosting

        hosting.view.layoutSubtreeIfNeeded()
        let fitting = hosting.view.fittingSize
        let size = NSSize(width: max(fitting.width, 520), height: max(fitting.height, 320))
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let screen {
            let visible = screen.visibleFrame
            let x = visible.origin.x + (visible.width - size.width) / 2
            let y = visible.origin.y + (visible.height - size.height) / 2
            panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: false)
        } else {
            panel.setContentSize(size)
            panel.center()
        }

        permissionWindow = panel

        nonisolated(unsafe) let closeResolve = resolve
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { _ in
            closeResolve(.deny)
        }

        nonisolated(unsafe) let keyResolve = resolve
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 36:
                keyResolve(.allowOnce)
                return nil
            case 53:
                keyResolve(.deny)
                return nil
            default:
                return event
            }
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            panel.makeKey()
            if let contentView = panel.contentView {
                panel.makeFirstResponder(contentView)
            }
        }
    }

    private static func dismissPermissionWindow() {
        activeResolve = nil
        if let observer = closeObserver {
            NotificationCenter.default.removeObserver(observer)
            closeObserver = nil
        }
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        permissionWindow?.orderOut(nil)
        permissionWindow = nil
    }

    private static var providerWindow: NSPanel?
    private static var providerCloseObserver: NSObjectProtocol?
    private static var providerKeyMonitor: Any?

    private static func presentProviderCredential(
        _ request: ProviderCredentialRequest
    ) async -> ProviderCredentialResult? {
        guard supportsNativeProviderCredentialPrompt(request),
              let bootstrap = AppBootstrap.shared
        else { return nil }
        return await withCheckedContinuation { continuation in
            presentProviderCredential(
                request,
                theme: bootstrap.uiState.theme.surfaceVariant(.mainChat),
                continuation: continuation
            )
        }
    }

    private static func supportsNativeProviderCredentialPrompt(_ request: ProviderCredentialRequest) -> Bool {
        request.instructions.authMethod == .apiKey
            || request.instructions.storageAuthType == .apiKey
            || request.instructions.storageAuthType == .none
    }

    private static func presentProviderCredential(
        _ request: ProviderCredentialRequest,
        theme: EpistemosTheme,
        continuation: CheckedContinuation<ProviderCredentialResult?, Never>
    ) {
        dismissProviderWindow()
        var hasResumed = false

        let resolve: (ProviderCredentialResult?) -> Void = { result in
            guard !hasResumed else { return }
            hasResumed = true
            dismissProviderWindow()
            continuation.resume(returning: result)
        }

        let view = ActNativeProviderCredentialPromptView(
            request: request,
            theme: theme,
            onResolve: resolve
        )
        .padding(24)

        let hosting = NSHostingController(rootView: view)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 430),
            styleMask: [.fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .modalPanel
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .alertPanel
        panel.contentViewController = hosting

        hosting.view.layoutSubtreeIfNeeded()
        let fitting = hosting.view.fittingSize
        let size = NSSize(width: max(fitting.width, 560), height: max(fitting.height, 360))
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let screen {
            let visible = screen.visibleFrame
            let x = visible.origin.x + (visible.width - size.width) / 2
            let y = visible.origin.y + (visible.height - size.height) / 2
            panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: false)
        } else {
            panel.setContentSize(size)
            panel.center()
        }

        providerWindow = panel

        nonisolated(unsafe) let closeResolve = resolve
        providerCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { _ in
            closeResolve(.cancelled)
        }

        nonisolated(unsafe) let keyResolve = resolve
        providerKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                keyResolve(.cancelled)
                return nil
            }
            return event
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            panel.makeKey()
            if let contentView = panel.contentView {
                panel.makeFirstResponder(contentView)
            }
        }
    }

    private static func dismissProviderWindow() {
        if let observer = providerCloseObserver {
            NotificationCenter.default.removeObserver(observer)
            providerCloseObserver = nil
        }
        if let monitor = providerKeyMonitor {
            NSEvent.removeMonitor(monitor)
            providerKeyMonitor = nil
        }
        providerWindow?.orderOut(nil)
        providerWindow = nil
    }

    private static var pairingWindow: NSPanel?
    private static var pairingCloseObserver: NSObjectProtocol?
    private static var pairingKeyMonitor: Any?

    private static func presentPairing(
        _ request: EpistemosOsaurusNativePairingRequest
    ) async -> EpistemosOsaurusNativePairingDecision {
        guard let bootstrap = AppBootstrap.shared else { return .deny }
        let decision = await withCheckedContinuation { continuation in
            presentPairing(
                request,
                theme: bootstrap.uiState.theme.surfaceVariant(.mainChat),
                continuation: continuation
            )
        }

        switch decision {
        case .approveTemporary, .approvePermanent:
            let outcome = await bootstrap.sovereignGate.confirm(
                .deviceOwnerAuthentication,
                reason: "Approve pairing with \(request.agentName.isEmpty ? "this remote Osaurus agent" : request.agentName)."
            )
            return outcome == .allowed ? decision : .deny
        case .deny:
            return .deny
        }
    }

    private static func presentPairing(
        _ request: EpistemosOsaurusNativePairingRequest,
        theme: EpistemosTheme,
        continuation: CheckedContinuation<EpistemosOsaurusNativePairingDecision, Never>
    ) {
        dismissPairingWindow()
        var hasResumed = false

        let resolve: (EpistemosOsaurusNativePairingDecision) -> Void = { decision in
            guard !hasResumed else { return }
            hasResumed = true
            dismissPairingWindow()
            continuation.resume(returning: decision)
        }

        let view = ActNativePairingPromptView(
            request: request,
            theme: theme,
            onResolve: resolve
        )
        .padding(24)

        let hosting = NSHostingController(rootView: view)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 370),
            styleMask: [.fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .modalPanel
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .alertPanel
        panel.contentViewController = hosting

        hosting.view.layoutSubtreeIfNeeded()
        let fitting = hosting.view.fittingSize
        let size = NSSize(width: max(fitting.width, 540), height: max(fitting.height, 340))
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let screen {
            let visible = screen.visibleFrame
            let x = visible.origin.x + (visible.width - size.width) / 2
            let y = visible.origin.y + (visible.height - size.height) / 2
            panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: false)
        } else {
            panel.setContentSize(size)
            panel.center()
        }

        pairingWindow = panel

        nonisolated(unsafe) let closeResolve = resolve
        pairingCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { _ in
            closeResolve(.deny)
        }

        nonisolated(unsafe) let keyResolve = resolve
        pairingKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                keyResolve(.deny)
                return nil
            }
            return event
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            panel.makeKey()
            if let contentView = panel.contentView {
                panel.makeFirstResponder(contentView)
            }
        }
    }

    private static func dismissPairingWindow() {
        if let observer = pairingCloseObserver {
            NotificationCenter.default.removeObserver(observer)
            pairingCloseObserver = nil
        }
        if let monitor = pairingKeyMonitor {
            NSEvent.removeMonitor(monitor)
            pairingKeyMonitor = nil
        }
        pairingWindow?.orderOut(nil)
        pairingWindow = nil
    }
}

private struct ActNativeToolPermissionPromptView: View {
    let request: EpistemosOsaurusNativeToolPermissionRequest
    let theme: EpistemosTheme
    let onResolve: (EpistemosOsaurusNativeToolPermissionDecision) -> Void

    private var cleanedDescription: String {
        let trimmed = request.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "This Osaurus tool action needs your approval." : trimmed
    }

    private var prettyArguments: String {
        let trimmed = request.argumentsJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
              )
        else {
            return trimmed
        }
        return String(decoding: pretty, as: UTF8.self)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.resolved.accent.color)
                    .frame(width: 28, height: 28)
                    .background(theme.resolved.accent.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Approve Act Tool")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.resolved.foreground.color)
                    Text(request.toolName)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()
            }

            Text(cleanedDescription)
                .font(.system(size: 13))
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !prettyArguments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Arguments", systemImage: "curlybraces")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.textTertiary)

                    ScrollView([.vertical, .horizontal]) {
                        Text(prettyArguments)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(theme.resolved.foreground.color.opacity(0.9))
                            .textSelection(.enabled)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 148)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(theme.resolved.foreground.color.opacity(theme.isDark ? 0.07 : 0.045))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(theme.border.opacity(0.48), lineWidth: 0.75)
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    onResolve(.deny)
                } label: {
                    Label("Deny", systemImage: "xmark")
                        .frame(minWidth: 80, minHeight: 30)
                }
                .buttonStyle(ActPermissionPanelButtonStyle(theme: theme, role: .secondary))
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    onResolve(.alwaysAllow)
                } label: {
                    Label("Always", systemImage: "checkmark.seal")
                        .frame(minWidth: 98, minHeight: 30)
                }
                .buttonStyle(ActPermissionPanelButtonStyle(theme: theme, role: .secondary))

                Button {
                    onResolve(.allowOnce)
                } label: {
                    Label("Allow", systemImage: "checkmark")
                        .frame(minWidth: 90, minHeight: 30)
                }
                .buttonStyle(ActPermissionPanelButtonStyle(theme: theme, role: .primary))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 430)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.card.opacity(theme.isDark ? 0.96 : 0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.regularMaterial)
                        .opacity(theme.isDark ? 0.14 : 0.36)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.border.opacity(theme.isDark ? 0.56 : 0.42), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(theme.isDark ? 0.34 : 0.18), radius: 24, y: 12)
    }
}

private struct ActPermissionPanelButtonStyle: ButtonStyle {
    enum Role {
        case primary
        case secondary
    }

    let theme: EpistemosTheme
    let role: Role

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(role == .primary ? Color.white : theme.textSecondary)
            .padding(.horizontal, 8)
            .background(background(configuration.isPressed), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(border, lineWidth: 0.75)
            }
    }

    private var border: Color {
        role == .primary ? theme.resolved.accent.color.opacity(0.28) : theme.border.opacity(0.48)
    }

    private func background(_ isPressed: Bool) -> Color {
        switch role {
        case .primary:
            return theme.resolved.accent.color.opacity(isPressed ? 0.74 : 0.94)
        case .secondary:
            return theme.resolved.foreground.color.opacity(isPressed ? 0.10 : 0.055)
        }
    }
}

private struct ActNativeProviderCredentialPromptView: View {
    let request: ProviderCredentialRequest
    let theme: EpistemosTheme
    let onResolve: (ProviderCredentialResult?) -> Void

    @State private var apiKey = ""
    @State private var extraFieldValues: [String: String] = [:]

    private var requiresAPIKey: Bool {
        request.instructions.storageAuthType != .none
    }

    private var canSave: Bool {
        if requiresAPIKey && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        return request.instructions.extraFields
            .filter(\.isRequired)
            .allSatisfy { field in
                !(extraFieldValues[field.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "key.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.resolved.accent.color)
                    .frame(width: 28, height: 28)
                    .background(theme.resolved.accent.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(providerTitle)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.resolved.foreground.color)
                    Text("Stored in Osaurus Keychain")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()
            }

            if let hint = request.instructions.keyFormatHint, !hint.isEmpty {
                Text(hint)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                if requiresAPIKey {
                    fieldLabel("API Key")
                    SecureField("Paste key", text: $apiKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(inputBackground)
                        .overlay(inputBorder)
                } else {
                    Text("This provider can be saved without a key.")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                }

                ForEach(request.instructions.extraFields, id: \.key) { field in
                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel(field.label + (field.isRequired ? "" : " (optional)"))
                        TextField(
                            field.placeholder,
                            text: Binding(
                                get: { extraFieldValues[field.key] ?? "" },
                                set: { extraFieldValues[field.key] = $0 }
                            )
                        )
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(inputBackground)
                        .overlay(inputBorder)

                        if let help = field.helpText, !help.isEmpty {
                            Text(help)
                                .font(.system(size: 11))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    onResolve(.cancelled)
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .frame(minWidth: 92, minHeight: 30)
                }
                .buttonStyle(ActPermissionPanelButtonStyle(theme: theme, role: .secondary))
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    onResolve(.apiKey(key: apiKey.trimmingCharacters(in: .whitespacesAndNewlines), headers: collectedExtraHeaders()))
                } label: {
                    Label("Save", systemImage: "checkmark")
                        .frame(minWidth: 94, minHeight: 30)
                }
                .buttonStyle(ActPermissionPanelButtonStyle(theme: theme, role: .primary))
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(16)
        .frame(width: 460)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.card.opacity(theme.isDark ? 0.96 : 0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.regularMaterial)
                        .opacity(theme.isDark ? 0.14 : 0.36)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.border.opacity(theme.isDark ? 0.56 : 0.42), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(theme.isDark ? 0.34 : 0.18), radius: 24, y: 12)
    }

    private var providerTitle: String {
        switch request.mode {
        case .addNew:
            return "Connect \(request.instructions.displayName)"
        case .rotate:
            return "Update \(request.instructions.displayName)"
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(theme.textTertiary)
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(theme.resolved.foreground.color.opacity(theme.isDark ? 0.07 : 0.045))
    }

    private var inputBorder: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .strokeBorder(theme.border.opacity(0.48), lineWidth: 0.75)
    }

    private func collectedExtraHeaders() -> [String: String]? {
        let pairs = request.instructions.extraFields.compactMap { field -> (String, String)? in
            let value = (extraFieldValues[field.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : (field.key, value)
        }
        return pairs.isEmpty ? nil : Dictionary(uniqueKeysWithValues: pairs)
    }
}

private struct ActNativePairingPromptView: View {
    let request: EpistemosOsaurusNativePairingRequest
    let theme: EpistemosTheme
    let onResolve: (EpistemosOsaurusNativePairingDecision) -> Void

    private var agentName: String {
        let trimmed = request.agentName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Remote Osaurus Agent" : trimmed
    }

    private var shortAddress: String {
        let address = request.connectorAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard address.count > 22 else { return address }
        return "\(address.prefix(10))...\(address.suffix(8))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.resolved.accent.color)
                    .frame(width: 28, height: 28)
                    .background(theme.resolved.accent.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Approve Act Pairing")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.resolved.foreground.color)
                    Text(agentName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("A remote Osaurus agent wants to pair with Epistemos Act.")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textSecondary)
                Text("Approving grants an access credential. Epistemos will ask for device authentication before the pairing is accepted.")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 7) {
                Label("Connector", systemImage: "link")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textTertiary)
                Text(shortAddress)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.resolved.foreground.color.opacity(0.9))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(theme.resolved.foreground.color.opacity(theme.isDark ? 0.07 : 0.045))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(theme.border.opacity(0.48), lineWidth: 0.75)
                    }
            }

            HStack(spacing: 10) {
                Button {
                    onResolve(.deny)
                } label: {
                    Label("Deny", systemImage: "xmark")
                        .frame(minWidth: 84, minHeight: 30)
                }
                .buttonStyle(ActPermissionPanelButtonStyle(theme: theme, role: .secondary))
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    onResolve(.approveTemporary)
                } label: {
                    Label("Allow Once", systemImage: "checkmark")
                        .frame(minWidth: 108, minHeight: 30)
                }
                .buttonStyle(ActPermissionPanelButtonStyle(theme: theme, role: .secondary))

                Button {
                    onResolve(.approvePermanent)
                } label: {
                    Label("Remember", systemImage: "checkmark.seal")
                        .frame(minWidth: 112, minHeight: 30)
                }
                .buttonStyle(ActPermissionPanelButtonStyle(theme: theme, role: .primary))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 450)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.card.opacity(theme.isDark ? 0.96 : 0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.regularMaterial)
                        .opacity(theme.isDark ? 0.14 : 0.36)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.border.opacity(theme.isDark ? 0.56 : 0.42), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(theme.isDark ? 0.34 : 0.18), radius: 24, y: 12)
    }
}
#endif

private struct HomeWindowIdentityObserver: NSViewRepresentable {
    let themeIsDark: Bool

    func makeNSView(context: Context) -> HomeWindowIdentityObserverView {
        let v = HomeWindowIdentityObserverView()
        v.themeIsDark = themeIsDark
        return v
    }

    func updateNSView(_ nsView: HomeWindowIdentityObserverView, context: Context) {
        nsView.themeIsDark = themeIsDark
        nsView.applyWindowIdentity()
    }
}

private final class HomeWindowIdentityObserverView: NSView {
    /// Latest in-app theme darkness flag, pushed from SwiftUI on every
    /// theme change. Stamped onto the window's AppKit appearance so the
    /// title bar / toolbar surface never paints with the system
    /// appearance during the landing → main-chat transition.
    var themeIsDark: Bool = false {
        didSet {
            guard themeIsDark != oldValue else { return }
            applyWindowIdentity()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyWindowIdentity()
    }

    func applyWindowIdentity() {
        guard let window else { return }
        HomeWindowIdentity.apply(to: window)
        HomeWindowIdentity.applyAppearance(to: window, isDark: themeIsDark)
    }
}

// MARK: - Root View
// Top-level container with centered toolbar controls.
// System Liquid Glass toolbar provides the chrome — no custom glass needed.

struct RootView: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(GraphState.self) private var graphState
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync

    /// Set by EpistemosApp when AppBootstrap detected a database error.
    var databaseError: Error?
    /// Callback to reset database and relaunch.
    var onResetDatabase: (() -> Void)?
    @Binding var showQuickCapture: Bool

    @State private var appearanceObserver = SystemAppearanceObserver()
    @State private var showDatabaseAlert = false
    @State private var showGreetingControls = false
    @State private var showWorkspaceSwitcher = false
    @State private var showTimeMachine = false
    @State private var actEntered = ProcessInfo.processInfo.environment["EPI_ACT_ENTERED"] == "1"
    @State private var selectedActSessionId: UUID?
    @State private var pendingActPrompt: PendingActPrompt?

    /// Transition gate: suppresses toolbar reveal during landing→chat animation on Home.
    /// Only delays the *reveal*; hiding is always immediate.
    @State private var homeChatToolbarReady = false

    /// Owner 2026-06-24: the right-side context-panel toggle belongs UP IN THE TOOLBAR (it had migrated to the
    /// composer bar). Shares the SAME AppStorage key as ChatView's `showBrainPanel`, so toggling from the
    /// toolbar and from the panel/composer stay in sync automatically (one UserDefaults key).
    @AppStorage("mainChat.showBrainPanel") private var showActContextPanel = true

    /// True when Home tab is showing an active chat (not landing).
    private var activeHomeChat: Bool {
        ui.homeTab == .home
            && !chat.showLanding
            && !chat.messages.isEmpty
            && !showingActChatSurface
            // Owner 2026-06-24 regression: the ACT LANDING ("Click anywhere") is gated by `actEntered`,
            // independent of `chat.showLanding`/`messages`. With leftover messages, activeHomeChat went true
            // WHILE the act landing rendered → the chat toolbar (back chevron + stale model-output title)
            // leaked onto the landing. The act landing is NOT an active chat.
            && !actLandingSurfaceVisible
    }

    private var embeddedHomeGraphContentVisible: Bool {
        ui.homeTab == .home && ui.homeContent == .graph
    }

    private var embeddedHomeGraphCanvasVisible: Bool {
        embeddedHomeGraphContentVisible && graphState.currentRoute.isCanvas
    }

    private var embeddedHomeGraphNoteVisible: Bool {
        guard embeddedHomeGraphContentVisible else { return false }
        if case .note = graphState.currentRoute { return true }
        return false
    }

    /// True when the user is inside Act chat. The landing and chat surface stay
    /// Epistemos-native; Osaurus is only the model/tool/permission layer below it.
    private var showingActChatSurface: Bool {
        #if EPISTEMOS_APP_STORE
        return false
        #else
        // Owner 2026-06-24: MUST also be in ACT workspace mode. Without this, switching to WORK left
        // `actEntered` true → the act chat toolbar (back chevron + act title) AND the toolbar glass (a white
        // bar at the top of the Work surface) leaked into Work, and a stale act/model title popped into the
        // Work titlebar. Gating on the workspace mode confines the act chrome to act.
        return ui.homeTab == .home
            && WorkspaceModeSelection.current() == .act
            && LocalAgentLoop.shouldRouteActThroughOsaurus()
            && actEntered
        #endif
    }

    private var actLandingSurfaceVisible: Bool {
        #if EPISTEMOS_APP_STORE
        return false
        #else
        return ui.homeTab == .home
            && WorkspaceModeSelection.current() == .act
            && LocalAgentLoop.shouldRouteActThroughOsaurus()
            && !actEntered
        #endif
    }

    private var showLandingToolbarControls: Bool {
        ui.homeTab == .home
            && !embeddedHomeGraphContentVisible
            && (chat.showLanding || chat.messages.isEmpty || actLandingSurfaceVisible)
            && !showingActChatSurface
    }

    private var showEmbeddedGraphToolbarControls: Bool {
        embeddedHomeGraphCanvasVisible
    }

    /// Canonical toolbar glass visibility — deterministic from app state.
    /// For non-Home tabs: always visible.
    /// For Home landing: always hidden.
    /// For Home chat: gated by `homeChatToolbarReady` to suppress transition flash.
    private var toolbarGlassVisible: Bool {
        if ui.homeTab != .home { return true }
        if embeddedHomeGraphContentVisible {
            return embeddedHomeGraphNoteVisible
        }
        if showingActChatSurface { return true }
        return activeHomeChat && homeChatToolbarReady
    }

    var body: some View {
        rootContent
            .modifier(RootWindowLifecycle(ui: ui))
            .modifier(RootWorkspaceEvents(
                showWorkspaceSwitcher: $showWorkspaceSwitcher,
                showTimeMachine: $showTimeMachine,
                showQuickCapture: $showQuickCapture
            ))
    }

    private var rootContent: some View {
        ZStack {
            // Pre-paint the window background so transitions from landing
            // into chat don't briefly flash the old theme surface at the
            // title bar. Use the selected semantic theme in both appearances.
            // `allowsHitTesting(false)` is CRITICAL — without it the Color
            // swallows clicks, breaking every button on the window.
            AppWindowBackdropStyle.background(for: ui.theme)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ContentRouter(
                actEntered: $actEntered,
                selectedActSessionId: $selectedActSessionId,
                pendingActPrompt: $pendingActPrompt
            )
        }
        .background(HomeWindowIdentityObserver(themeIsDark: ui.theme.isDark))
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: activeHomeChat)
        .onAppear(perform: handleAppearanceOnAppear)
        .onDisappear {
            appearanceObserver.stop()
        }
        .onChange(of: ui.readableFontsEnabled) { _, _ in
            // Observing the preference here redraws typography live without
            // restarting the app or resetting graph/navigation view identity.
        }
        .onChange(of: ui.appearanceSyncKey) { _, _ in
            UtilityWindowManager.shared.syncTheme(uiState: ui)
            HologramController.shared.syncTheme(ui)
        }
        .toolbar {
            // Back button — during an active home chat or after entering Act from the landing.
            if !embeddedHomeGraphContentVisible && ui.homeTab == .home && (activeHomeChat || showingActChatSurface) {
                ToolbarItem(placement: .navigation) {
                    Button {
                        if showingActChatSurface {
                            actEntered = false
                            selectedActSessionId = nil
                            pendingActPrompt = nil
                        } else {
                            chat.goHome()
                        }
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .accessibilityLabel("Back to Home")
                    .help("Back to Home")
                }
            }
            if showingActChatSurface {
                ToolbarItem(placement: .principal) {
                    modelToolbarButton(title: actToolbarTitle)
                }
                .sharedBackgroundVisibility(.hidden)
            } else if showLandingToolbarControls
                || showEmbeddedGraphToolbarControls
                || (!embeddedHomeGraphContentVisible && activeHomeChat)
            {
                ToolbarItem(placement: .principal) {
                    rootToolbarControls
                }
                .sharedBackgroundVisibility(
                    (ui.homeTab == .home && activeHomeChat)
                        ? .hidden : .automatic
                )
            }
            if showingActChatSurface {
                ToolbarItem(placement: .primaryAction) {
                    ControlGroup {
                        historyToolbarButton
                        actContextPanelToolbarButton
                        settingsToolbarButton
                        actMiniChatToolbarButton
                        actExportToolbarButton
                    }
                }
            }
        }
        .navigationTitle("")
        // Toolbar glass: hidden on home landing, visible for active home chat.
        // Canonical rule is derived from app state (deterministic).
        // `homeChatToolbarReady` only gates the Home landing→chat reveal to avoid flash.
        .toolbarBackgroundVisibility(
            toolbarGlassVisible ? .automatic : .hidden,
            for: .windowToolbar
        )
        .onChange(of: activeHomeChat) { _, isActive in
            if isActive {
                // Delay reveal until HomeRouter's landing→chat animation settles.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    homeChatToolbarReady = true
                }
            } else {
                // Hide immediately when returning to landing.
                homeChatToolbarReady = false
            }
        }
        // Chat sidebar is now a popover on the toolbar button (above)
        .overlay(alignment: .bottom) {
            if let message = ui.toastMessage {
                ToastOverlay(message: message, type: ui.toastType) {
                    ui.dismissToast()
                }
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.25), value: ui.toastMessage)
            }
        }
        .overlay(alignment: .top) {
            if vaultSync.isIndexing || vaultSync.vaultActivityMessage != nil {
                VaultActivityStatusOverlay(
                    message: vaultSync.vaultActivityMessage ?? "Loading vault...",
                    progress: vaultSync.vaultImportProgress
                )
                .padding(.top, 18)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(
            minWidth: WindowPresentationPolicy.mainWindowMinimumSize.width,
            minHeight: WindowPresentationPolicy.mainWindowMinimumSize.height
        )
        .background {
            Button(action: openSettingsWindow) {}
                .keyboardShortcut("s", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
        }
        // Setup screen — shown after a full reset (covers everything)
        .overlay {
            if ui.needsSetup {
                SetupView()
                    .transition(.opacity)
            }
        }
        .overlay {
            if let issue = vaultSync.recoveryIssue,
               issue.blocksWorkspaceInteraction {
                VaultRecoveryOverlay(
                    issue: issue,
                    isRecovering: vaultSync.isRecoveringLocalState,
                    rebuildAction: {
                        guard let vaultURL = issue.snapshot.vaultURL else { return }
                        Task { _ = await vaultSync.recoverFromVault(at: vaultURL) }
                    },
                    chooseVaultAction: {
                        VaultConnectionActions.selectVaultFolder(notesUI: notesUI, vaultSync: vaultSync)
                    },
                    disconnectAction: {
                        VaultConnectionActions.disconnect(notesUI: notesUI, vaultSync: vaultSync)
                    }
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if let databaseError {
                DatabaseRecoveryOverlay(
                    error: databaseError,
                    resetAction: requestDatabaseResetAuthorization,
                    quitAction: { NSApp.terminate(nil) }
                )
                .transition(.opacity)
            }
        }
        .animation(Motion.smooth, value: ui.needsSetup)
        .onAppear(perform: handleDatabaseCheck)
        .alert("Database Recovery Required", isPresented: $showDatabaseAlert) {
            Button("Reset Database", role: .destructive) {
                requestDatabaseResetAuthorization()
            }
            Button("Quit") { NSApp.terminate(nil) }
        } message: {
            Text("The database could not be loaded. This recovery session is not durable. Normal notes, chat, capture, vault sync, and .epdoc writes are blocked until the database is reset or repaired.\n\n\(databaseError?.localizedDescription ?? "")")
        }
    }

    private func requestDatabaseResetAuthorization() {
        let target = RootViewDestructiveActionSovereignGate.Target.databaseReset

        Task { @MainActor in
            let outcome = await AppBootstrap.shared?.sovereignGate.confirm(
                RootViewDestructiveActionSovereignGate.requirement(for: target),
                reason: RootViewDestructiveActionSovereignGate.reason(for: target)
            ) ?? .denied(.authenticationFailed)

            guard outcome == .allowed else {
                if databaseError != nil {
                    showDatabaseAlert = true
                }
                return
            }

            onResetDatabase?()
        }
    }

    private func handleDatabaseCheck() {
        if databaseError != nil {
            showDatabaseAlert = true
        }
    }

    private func handleAppearanceOnAppear() {
        appearanceObserver.onAppearanceChange = { @MainActor isDark in
            guard ui.isSystemDark != isDark else { return }
            ui.isSystemDark = isDark
        }
        appearanceObserver.start()
    }

    private var rootToolbarControls: some View {
        HStack(spacing: 10) {
            if showLandingToolbarControls || showEmbeddedGraphToolbarControls {
                // Keep the pill mounted on the graph — a principal ToolbarItem is load-bearing
                // for the window's curved corners. Settings shows in every pill state; greeting
                // and recent chats stay with Home/Act page chrome, and the recent control is a
                // single route-aware button instead of separate landing/chat implementations.
                ControlGroup {
                    settingsToolbarButton
                    if !embeddedHomeGraphContentVisible {
                        landingGreetingToolbarButton
                        historyToolbarButton
                    }
                }
                .animation(.easeOut(duration: 0.28), value: embeddedHomeGraphContentVisible)
            }

            if activeHomeChat {
                modelToolbarButton(title: chat.chatTitle)
            }
        }
        .frame(minWidth: 160, minHeight: 28)
        .fixedSize()
    }

    private var settingsToolbarButton: some View {
        Button(action: openContextualSettingsWindow) {
            Label("Settings", systemImage: "gearshape")
        }
        .accessibilityLabel("Settings")
        .help("Settings (⌘S)")
    }

    private var actToolbarTitle: String {
        let title = chat.chatTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? "Act" : title
    }

    @ViewBuilder
    private func modelToolbarButton(title: String? = nil) -> some View {
        let resolvedTitle = title ?? chat.chatTitle ?? ""
        MotionTitle(
            text: resolvedTitle,
            font: .system(size: 16, weight: .semibold, design: .rounded),
            color: ui.theme.textPrimary
        )
            .id(resolvedTitle)
            .lineLimit(1)
            .truncationMode(.middle)
            .fixedSize()
            .accessibilityLabel("Chat title")
    }

    private func openSettingsWindow() {
        UtilityWindowManager.shared.show(.settings)
        NSApp.activate()
    }

    private func openContextualSettingsWindow() {
        openSettingsWindow()
        #if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
        if showingActChatSurface || actLandingSurfaceVisible {
            NotificationCenter.default.post(name: .showActOsaurusSettings, object: nil)
        }
        #endif
    }

    private var landingGreetingToolbarButton: some View {
        Button {
            showGreetingControls.toggle()
        } label: {
            Label("Greeting", systemImage: LandingToolbarGlyphs.greetingSymbol)
        }
        .help("Adjust greeting behavior")
        .popover(isPresented: $showGreetingControls) {
            LandingGreetingControlsView()
                .frame(width: 320)
                .padding(16)
                .preferredColorScheme(ui.preferredColorScheme)
        }
    }

    private var historyToolbarButton: some View {
        @Bindable var ui = ui
        return Button {
            ui.toggleChatSidebar()
        } label: {
            Label("History", systemImage: "sidebar.left")
        }
        .accessibilityLabel("Chat History")
        .help("Chat History (⇧⌘H)")
        .popover(isPresented: $ui.showChatSidebar) {
            historyPopoverContent
                .frame(width: 300, height: 500)
                .preferredColorScheme(ui.preferredColorScheme)
        }
    }

    private var actMiniChatToolbarButton: some View {
        Button(action: openCurrentActInMiniChat) {
            Label("Open in Mini Chat", systemImage: "arrow.up.right.square")
        }
        .accessibilityLabel("Open Act in Mini Chat")
        .help("Open Act in Mini Chat")
    }

    private var actExportToolbarButton: some View {
        Button(action: exportCurrentActTranscript) {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .accessibilityLabel("Export Act Chat")
        .help("Export Act Chat")
        .disabled(chat.messages.isEmpty)
    }

    /// Owner 2026-06-24: the side (context) panel toggle, restored to the toolbar (was only on the composer bar).
    /// Toggles the shared `mainChat.showBrainPanel` AppStorage so it stays in sync with the panel + composer.
    private var actContextPanelToolbarButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                showActContextPanel.toggle()
            }
        } label: {
            Label(
                showActContextPanel ? "Hide Context Panel" : "Show Context Panel",
                systemImage: "sidebar.right"
            )
        }
        .accessibilityLabel(showActContextPanel ? "Hide context panel" : "Show context panel")
        .help(showActContextPanel ? "Hide context panel" : "Show context panel")
    }

    private func openCurrentActInMiniChat() {
        if let activeChatId = chat.activeChatId {
            MiniChatWindowController.shared.openChat(
                activeChatId,
                preferredOperatingMode: .agent
            )
        } else {
            MiniChatWindowController.shared.openNewChat(preferredOperatingMode: .agent)
        }
    }

    private func exportCurrentActTranscript() {
        guard !chat.messages.isEmpty else { return }
        ChatTextExportSupport.save(
            actTranscriptMarkdown(),
            suggestedFilename: "act-chat-\(Date().formatted(.iso8601.year().month().day())).md",
            contentType: .plainText
        )
    }

    private func actTranscriptMarkdown() -> String {
        let title = chat.chatTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let heading = title.isEmpty ? "Act Chat Export" : title
        let lines = chat.messages.map { message in
            let role = message.role == .user ? "You" : "Assistant"
            return "## \(role)\n\n\(ChatPresentationFormatter.displayContent(for: message))"
        }
        return "# \(heading)\n\n\(lines.joined(separator: "\n\n---\n\n"))"
    }

    @ViewBuilder
    private var historyPopoverContent: some View {
        if showingActChatSurface || actLandingSurfaceVisible {
            ChatSidebarView {
                pendingActPrompt = nil
                withAnimation(.easeOut(duration: 0.28)) {
                    actEntered = true
                }
            }
        } else {
            ChatSidebarView()
        }
    }
}

private struct PendingActPrompt {
    let id = UUID()
    let text: String
    var contextAttachments: [ContextAttachment] = []
    var fileAttachments: [FileAttachment] = []
}

struct ActEpistemosChatSurface: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(OrchestratorState.self) private var orchestrator
    @Environment(InferenceState.self) private var inference

    let sessionId: UUID?
    let initialPrompt: String?
    let initialPromptId: UUID?
    var initialContextAttachments: [ContextAttachment] = []
    var initialFileAttachments: [FileAttachment] = []
    let onInitialPromptConsumed: () -> Void
    var onCurrentSessionChanged: (UUID?) -> Void = { _ in }

    @State private var consumedInitialPromptId: UUID?

    var body: some View {
        ChatView(
            actUsesOsaurus: true,
            availableOperatingModesOverride: [.agent],
            composerMode: .osaurusAct,
            showsToolbarControls: false,
            onOpenActConfiguration: openActConfiguration
        )
        .background(AppWindowBackdropStyle.background(for: ui.theme).ignoresSafeArea())
        .onAppear {
            loadRequestedSessionIfNeeded()
            publishCurrentSession()
        }
        .onChange(of: sessionId) { _, _ in
            loadRequestedSessionIfNeeded()
            publishCurrentSession()
        }
        .onChange(of: chat.activeChatId) { _, _ in
            publishCurrentSession()
        }
        .task(id: initialPromptId) {
            await submitInitialPromptIfNeeded()
        }
    }

    private func loadRequestedSessionIfNeeded() {
        guard let sessionId else { return }
        let chatId = sessionId.uuidString
        guard chat.activeChatId != chatId else { return }
        AppBootstrap.shared?.loadChat(chatId: chatId)
        loadLegacyOsaurusTranscriptIfNeeded(sessionId)
    }

    private func loadLegacyOsaurusTranscriptIfNeeded(_ sessionId: UUID) {
        #if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
        let chatId = sessionId.uuidString
        guard chat.activeChatId != chatId || chat.messages.isEmpty,
              let transcript = EpistemosOsaurusSessionBridge.loadTranscript(id: sessionId)
        else { return }

        let messages = transcript.messages.compactMap { message -> ChatMessage? in
            switch message.role {
            case .user:
                return ChatMessage(
                    id: message.id.uuidString,
                    chatId: chatId,
                    role: .user,
                    content: message.content,
                    createdAt: message.createdAt ?? .now
                )
            case .assistant:
                return ChatMessage(
                    id: message.id.uuidString,
                    chatId: chatId,
                    role: .assistant,
                    content: ActOsaurusVisibleStreamFilter.visibleStoredText(from: message.content),
                    createdAt: message.createdAt ?? message.completedAt ?? .now,
                    authoredByProviderID: "act",
                    authoredByModelID: transcript.selectedModel,
                    resolvedModelLabel: actResolvedModelLabel(for: transcript.selectedModel),
                    thinkingTrace: message.thinking.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? nil
                        : message.thinking,
                    thinkingDurationSeconds: message.thinkingDuration
                )
            case .tool, .system:
                return nil
            }
        }

        chat.setCurrentChat(chatId)
        chat.chatTitle = Self.cleanActChatTitle(transcriptTitle: transcript.title, messages: messages)
        chat.loadMessages(messages)
        #endif
    }

    /// Derive a CLEAN act chat title for the titlebar (owner 2026-06-24 regression: the model's streamed
    /// self-intro leaked into the window title). Osaurus auto-titles a session from its content — often the
    /// ASSISTANT response — so never use it raw. Prefer the FIRST USER message (the standard chat-title
    /// convention), single-line + capped; fall back to a sanitized transcript title, then "Act".
    private static func cleanActChatTitle(transcriptTitle: String, messages: [ChatMessage]) -> String {
        func sanitize(_ raw: String) -> String {
            let firstLine = raw.split(whereSeparator: \.isNewline).first.map(String.init) ?? raw
            let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count > 48 else { return trimmed }
            return String(trimmed.prefix(48)).trimmingCharacters(in: .whitespaces) + "…"
        }
        if let firstUser = messages.first(where: { $0.role == .user })?.content {
            let userTitle = sanitize(firstUser)
            if !userTitle.isEmpty { return userTitle }
        }
        let fallback = sanitize(transcriptTitle)
        return fallback.isEmpty ? "Act" : fallback
    }

    private func actResolvedModelLabel(for selectedModel: String?) -> String {
        guard let selectedModel = selectedModel?.trimmingCharacters(in: .whitespacesAndNewlines),
              !selectedModel.isEmpty
        else { return "Act" }
        return "Act · \(selectedModel)"
    }

    private func submitInitialPromptIfNeeded() async {
        guard let initialPromptId,
              consumedInitialPromptId != initialPromptId
        else { return }
        consumedInitialPromptId = initialPromptId
        loadRequestedSessionIfNeeded()

        for attachment in initialContextAttachments {
            chat.addContextAttachment(attachment)
        }
        for attachment in initialFileAttachments {
            chat.addAttachment(attachment)
        }

        let prompt = initialPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        onInitialPromptConsumed()
        guard !prompt.isEmpty else { return }

        MainChatSubmissionRouter.submit(
            prompt,
            operatingMode: .agent,
            chat: chat,
            orchestrator: orchestrator,
            inference: inference,
            forceActOsaurus: true
        )
        publishCurrentSession()
    }

    private func publishCurrentSession() {
        if let activeChatId = chat.activeChatId,
           let activeUUID = UUID(uuidString: activeChatId) {
            onCurrentSessionChanged(activeUUID)
        } else {
            onCurrentSessionChanged(sessionId)
        }
    }

    private func openActConfiguration() {
        // OWNER 2026-06-24 (REVERSAL, confirmed): the native-recoded Act settings (ActCloneSettingsView)
        // "don't really work" + got messy. Use the REAL Osaurus settings, reskinned native. showActSettings()
        // applies the source skin + cream/native ThemeManager tokens (persist:false) then presents the full
        // Osaurus ManagementView (HF marketplace, agent creation, themes, all tabs + animations) — the working
        // settings the native re-code was missing. See memory project_act_settings_use_osaurus_reskinned_2026_06_24.
        NSApp.activate()
        #if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
        EpistemosOsaurusManagementBridge.showActSettings()
        #else
        UtilityWindowManager.shared.show(.settings)
        NotificationCenter.default.post(name: .showActOsaurusSettings, object: nil)
        #endif
    }
}

struct LocalModelToolbarMenu: View {
    private enum MenuSelection: Identifiable, Equatable {
        case appleIntelligence
        case inProcess(LocalModelDescriptor)
        case cloud(CloudTextModelID)

        var id: String {
            switch self {
            case .appleIntelligence:
                "apple-intelligence"
            case .inProcess(let descriptor):
                "mlx:\(descriptor.id)"
            case .cloud(let model):
                "cloud:\(model.rawValue)"
            }
        }
    }

    private enum SplitToolbarPopover: Hashable {
        case mode
        case model
        case routing
        case effort
        case nativeControls
    }

    var variant: NativeControlVariant = .toolbar
    var overrideTitle: String? = nil
    var overrideFont: Font? = nil
    var operatingMode: Binding<EpistemosOperatingMode>? = nil
    var availableOperatingModes: [EpistemosOperatingMode]? = nil
    var isTemporaryChatEnabled: Binding<Bool>? = nil
    /// Main chat passes `true` so the composer gets the full split
    /// toolbar (Mode · Model · Routing · Effort · Native Controls).
    /// Landing, mini chat, note chat, and graph chat leave this `false`
    /// so the surface shows one compact popover trigger ("Fast · Qwen")
    /// instead of five separate buttons. Routing/effort/native controls
    /// only make sense on main chat; the other surfaces delegate to
    /// Settings for those.
    var preferSplitToolbarControls: Bool = false
    /// When the host renders its own flat inline runtime picker (the main-chat
    /// composer, owner 2026-06-18), the split toolbar's floating model button is
    /// redundant — hide it so there is exactly one model picker. Default off so
    /// every other surface keeps the model button unchanged.
    var hidesModelButton: Bool = false

    @Environment(UIState.self) private var ui
    @Environment(InferenceState.self) private var inference
    @Environment(LocalModelManager.self) private var localModelManager
    @Environment(CompanionState.self) private var companionState
    @State private var isPresented = false
    @State private var activeSplitPopover: SplitToolbarPopover?
    @State private var showsLocalModels = false
    @State private var showsCloudProviderOptions = false
    @State private var showsActiveCloudModelOptions = false
    /// Simplified picker: collapses Routing / per-model details / cloud setup /
    /// Temporary Chat behind one "Advanced" disclosure so the default popover is
    /// just the three Epistemos efforts + a Cloud toggle.
    @State private var showsAdvancedRuntimeOptions = false
    @State private var aboutSelection: ChatModelSelection?
    /// P7.6 — remembers the tier (Fast/Think/Code) to return to when the user
    /// flips the Chat/Act depth toggle back to Chat.
    @State private var lastTierMode: EpistemosOperatingMode = .fast
    @State private var localModelSubtitleCache: [String: String] = [:]

    private var theme: EpistemosTheme { ui.theme }

    private var installedSelectableModels: [LocalModelDescriptor] {
        let selectableIDs = Set(inference.releaseSelectableInstalledLocalTextModelIDs)
        return localModelManager.textDescriptors.filter { descriptor in
            selectableIDs.contains(descriptor.id)
        }
    }

    private var installableSelectableModels: [LocalModelDescriptor] {
        // Simplified lineup: the chat picker does NOT offer the legacy MLX
        // install catalog (Qwen / DeepSeek / Llama / Mistral / 35B flagships).
        // The foundation GGUF models are offered separately via
        // gemmaQATRouteIntegrationCandidates + the Settings foundation package,
        // so this stays empty and the picker is simple. Reversible via
        // EPISTEMOS_SIMPLIFIED_LINEUP=0.
        if EpistemosFoundationLineup.simplifiedLineupActive {
            return []
        }
        let shippedModelIDs = Set(LocalModelCatalog.shippedModelIDs)
        return localModelManager.textDescriptors.filter { descriptor in
            localModelManager.installRecords[descriptor.id] == nil
                && shippedModelIDs.contains(descriptor.id)
                && inference.hardwareCapabilitySnapshot.supports(descriptor: descriptor)
                && (LocalTextModelID(rawValue: descriptor.id)?.isReleaseValidatedForInteractiveChat ?? true)
        }
    }

    private var selectedDescriptor: LocalModelDescriptor? {
        if case .localMLX(let modelID) = inference.preferredChatModelSelection,
           let descriptor = LocalModelCatalog.descriptor(for: modelID),
           installedSelectableModels.contains(descriptor) {
            return descriptor
        }
        if let modelID = inference.activeLocalTextModelID,
           let descriptor = LocalModelCatalog.descriptor(for: modelID),
           installedSelectableModels.contains(descriptor) {
            return descriptor
        }
        return installedSelectableModels.first
    }

    private var selectedMenuItem: MenuSelection? {
        if inference.preferredChatModelSelection == .appleIntelligence {
            return .appleIntelligence
        }
        if case .cloud(let model) = inference.preferredChatModelSelection {
            return .cloud(model)
        }
        if let descriptor = selectedDescriptor {
            return .inProcess(descriptor)
        }
        return nil
    }

    private var usesAutomaticCloudRoute: Bool {
        inference.chatAutoRouteActive
    }

    private var automaticRouteSummary: String {
        if let operatingMode {
            return inference.chatSurfaceRouteDescription(for: operatingMode.wrappedValue).summary
        }
        if let provider = inference.preferredAutoRouteCloudProvider {
            return "Fast stays local-first, while higher-capability chat modes can escalate through \(provider.displayName)."
        }
        return "Connect a cloud provider to let higher-capability chat modes escalate beyond the local runtime."
    }

    private var displayedCloudProvider: CloudModelProvider? {
        inference.activeCloudProvider ?? inference.preferredAutoRouteCloudProvider
    }

    private var usesSplitToolbarControls: Bool {
        preferSplitToolbarControls && operatingMode != nil && overrideTitle == nil
    }

    private var currentOperatingMode: EpistemosOperatingMode? {
        operatingMode.map { sanitizedDisplayedOperatingMode($0.wrappedValue) }
    }

    private var currentRouteDescription: ChatSurfaceRouteDescription? {
        guard let currentOperatingMode else { return nil }
        return inference.chatSurfaceRouteDescription(for: currentOperatingMode)
    }

    private var currentEffectiveSelection: ChatModelSelection? {
        guard let currentOperatingMode else { return nil }
        return inference.effectiveChatSurfaceSelection(for: currentOperatingMode)
    }

    private var currentRuntimeNeedsSetup: Bool {
        guard let currentOperatingMode else { return false }
        return !inference.isChatSurfaceRuntimeReady(for: currentOperatingMode)
    }

    private var runtimeSetupSummary: String {
        "Install a local model, connect a cloud provider, or enable Apple Intelligence before sending."
    }

    private var currentEffectiveCloudModel: CloudTextModelID? {
        guard case .cloud(let model) = currentEffectiveSelection else { return nil }
        return model
    }

    private var currentDisplayedReasoningTier: ChatReasoningTier {
        guard let currentOperatingMode else { return inference.chatReasoningTier }
        return inference.sanitizedReasoningTier(
            inference.chatReasoningTier,
            for: currentOperatingMode
        )
    }

    private var supportsRuntimeEffortButton: Bool {
        guard let currentOperatingMode,
              !inference.availableReasoningTiers(for: currentOperatingMode).isEmpty,
              let model = currentEffectiveCloudModel else {
            return false
        }
        return model.supportsNativeReasoningEffortControl
    }

    private var supportsProviderNativeControlsButton: Bool {
        currentEffectiveCloudModel?.supportsProviderNativeFeatureControls ?? false
    }

    private var labelText: String {
        if let overrideTitle { return overrideTitle }
        if let operatingMode,
           !inference.isChatSurfaceRuntimeReady(for: operatingMode.wrappedValue) {
            return "\(operatingMode.wrappedValue.displayName) · Set Up Model"
        }
        // Simplified picker on a LOCAL selection: the button shows the Epistemos
        // effort (tier) and NEVER the backing model — "Epistemos Fast", not
        // "Fast · Gemma 4 12B". Cloud / Apple Intelligence selections fall through
        // and keep their honest model label.
        if hidesLocalModelLabel, let operatingMode {
            return operatingMode.wrappedValue.epistemosModelTier?.displayName
                ?? operatingMode.wrappedValue.displayName
        }
        let selectedModelLabel: String
        if let operatingMode {
            selectedModelLabel = inference.chatSurfaceRouteDescription(
                for: operatingMode.wrappedValue
            ).headline
        } else if usesAutomaticCloudRoute {
            selectedModelLabel = "Auto Route"
        } else {
            selectedModelLabel = switch selectedMenuItem {
            case .appleIntelligence:
                "Apple Intelligence"
            case .cloud(let model):
                model.compactDisplayName
            case .inProcess(let descriptor):
                LocalTextModelID(rawValue: descriptor.id)?.compactDisplayName ?? descriptor.displayName
            case nil:
                "Select Model"
            }
        }
        guard let operatingMode else { return selectedModelLabel }
        return "\(operatingMode.wrappedValue.displayName) · \(selectedModelLabel)"
    }

    private var labelFont: Font {
        if let overrideFont { return overrideFont }
        switch variant {
        case .toolbar:
            return Font.system(size: 14, weight: .medium)
        case .content:
            return Font.system(size: 13.5, weight: .medium)
        }
    }

    private var disclosureWidth: CGFloat {
        NativeControlSystem.reservedWidth(
            for: [
                "Apple Intelligence Tools",
                "GPT-4o Thinking",
                "GPT-4o Pro",
                "Gemini 2.5 Pro Tools",
                "Qwen 35B Thinking",
            ],
            variant: variant,
            includesDisclosureGlyph: true
        )
    }

    private var modeDisclosureWidth: CGFloat {
        NativeControlSystem.reservedWidth(
            for: displayedOperatingModes.map(\.displayName),
            variant: variant,
            includesDisclosureGlyph: true
        )
    }

    private var modelDisclosureWidth: CGFloat {
        NativeControlSystem.reservedWidth(
            for: [
                "Apple Intelligence",
                "GPT-4o",
                "Qwen 34B",
                "DeepSeek R1 7B",
                "Auto Route",
            ],
            variant: variant,
            includesDisclosureGlyph: true
        )
    }

    private var effortDisclosureWidth: CGFloat {
        NativeControlSystem.reservedWidth(
            for: ["Standard", "Extended", "Extra High", "Heavy", "Max"],
            variant: variant,
            includesDisclosureGlyph: true
        )
    }

    private var nativeControlsDisclosureWidth: CGFloat {
        NativeControlSystem.reservedWidth(
            for: ["OpenAI", "Claude", "Google"],
            variant: variant,
            includesDisclosureGlyph: true
        )
    }

    private var buttonSystemImage: String {
        if isTemporaryChatEnabled?.wrappedValue == true {
            return "eye.slash.fill"
        }
        if currentRuntimeNeedsSetup {
            return "exclamationmark.triangle"
        }
        if let operatingMode {
            return operatingMode.wrappedValue.systemImage
        }
        if usesAutomaticCloudRoute {
            return "arrow.triangle.branch"
        }
        switch selectedMenuItem {
        case .appleIntelligence:
            return "apple.intelligence"
        case .cloud:
            return "cloud.fill"
        case .inProcess, .none:
            return "memorychip"
        }
    }

    private var modelButtonTitle: String {
        if currentRuntimeNeedsSetup {
            return "Set Up Model"
        }
        return currentRouteDescription?.headline ?? labelText
    }

    private var modelButtonSystemImage: String {
        if currentRuntimeNeedsSetup {
            return "exclamationmark.triangle"
        }
        return currentRouteDescription?.systemImage ?? buttonSystemImage
    }

    /// Simplified lineup + a LOCAL selection: collapse the model button to an
    /// icon (no "Qwen 3 4B" / "Gemma 4 12B" text). The Fast/Think/Code mode
    /// button already conveys the local model, so the picker reads effort-first;
    /// a tap still opens the full popover (foundation models + cloud) so cloud
    /// stays reachable. Cloud / Apple Intelligence selections keep their label.
    private var hidesLocalModelLabel: Bool {
        guard EpistemosFoundationLineup.simplifiedLineupActive,
              !currentRuntimeNeedsSetup else {
            return false
        }
        if let selection = currentRouteDescription?.selection,
           case .localMLX = selection {
            return true
        }
        return false
    }

    private var routeButtonTitle: String {
        if currentRuntimeNeedsSetup {
            return "No Model"
        }
        guard let route = currentRouteDescription else { return "Routing" }
        if route.usesAutomaticRouting {
            return "Auto Route"
        }
        switch route.selection {
        case .cloud:
            return "Cloud Route"
        case .appleIntelligence, .localMLX:
            return "Local Route"
        }
    }

    private var effortButtonTitle: String {
        guard let currentOperatingMode else { return "Effort" }
        return inference.reasoningTierLabel(
            for: currentDisplayedReasoningTier,
            operatingMode: currentOperatingMode
        )
    }

    private var nativeControlsButtonTitle: String {
        guard let provider = currentEffectiveCloudModel?.provider else { return "Native" }
        return inference.runtimeControlTitle(for: provider)
    }

    private var nativeControlsButtonSystemImage: String {
        currentEffectiveCloudModel?.provider.systemImage ?? "slider.horizontal.3"
    }

    private var selectedModeSummary: String {
        if currentRuntimeNeedsSetup {
            return runtimeSetupSummary
        }
        // Simplified picker on a LOCAL selection: describe the effort tier
        // ("Quick answers — Gemma 4, sized to the task"), not a pinned model
        // size, so the summary never reads "runs directly on Gemma 4 12B".
        if hidesLocalModelLabel, let operatingMode {
            return operatingMode.wrappedValue.helpText
        }
        if let operatingMode {
            return inference.chatSurfaceRouteDescription(for: operatingMode.wrappedValue).summary
        }
        if usesAutomaticCloudRoute {
            return automaticRouteSummary
        }
        return "Choose the model that should power this surface."
    }

    private var noLocalModelsText: String {
        if inference.releaseHiddenInstalledLocalTextModelCount > 0 {
            return "\(inference.releaseHiddenInstalledLocalTextModelCount) installed local model\(inference.releaseHiddenInstalledLocalTextModelCount == 1 ? " is" : "s are") hidden from the release picker because they are not release-ready yet."
        }
        return inference.appleIntelligenceAvailable
            ? "Apple Intelligence is available, but the prepared or installed local runtime becomes the primary path as soon as it is ready."
            : "No supported local runtimes are available yet."
    }

    private var gemmaQATRouteIntegrationCandidates: [GemmaQATRuntimeCandidate] {
        GemmaQATRuntimeLadder.productRouteIntegrationCandidates
    }

    private var localModelSubtitleInputsFingerprint: String {
        let visibleModelIDs = (installedSelectableModels + installableSelectableModels)
            .map(\.id)
            .sorted()
            .joined(separator: ",")
        let preparedOrInstalledIDs = inference.installedLocalTextModelIDs
            .union(inference.preparedLocalTextModelIDs)
            .sorted()
            .joined(separator: ",")
        return "\(visibleModelIDs)|\(preparedOrInstalledIDs)"
    }

    private var qwen3UnifiedPickerPairAvailableForSubtitles: Bool {
        let preparedOrInstalledIDs = inference.installedLocalTextModelIDs
            .union(inference.preparedLocalTextModelIDs)
        return preparedOrInstalledIDs.contains(LocalTextModelID.qwen3_4B4Bit.rawValue)
            && preparedOrInstalledIDs.contains(LocalTextModelID.qwen3_4BThinking25074Bit.rawValue)
    }

    @MainActor
    private func sanitizeReleaseLocalSelectionIfNeeded() {
        guard case .localMLX(let modelID) = inference.preferredChatModelSelection,
              let model = LocalTextModelID(rawValue: modelID),
              !model.isReleaseValidatedForInteractiveChat,
              let fallback = inference.releaseSelectableInstalledLocalTextModelIDs.first else {
            return
        }
        inference.setPreferredChatModelSelection(.localMLX(fallback))
    }

    @MainActor
    private func syncReasoningTierToDisplayedModeIfNeeded() {
        guard let currentOperatingMode else { return }
        let sanitized = inference.sanitizedReasoningTier(
            inference.chatReasoningTier,
            for: currentOperatingMode
        )
        guard sanitized != inference.chatReasoningTier else { return }
        inference.setChatReasoningTier(sanitized, for: currentOperatingMode)
    }

    @MainActor
    private func syncModelPickerDisclosureState() {
        switch selectedMenuItem {
        case .appleIntelligence, .inProcess:
            showsLocalModels = true
            showsCloudProviderOptions = false
            showsActiveCloudModelOptions = false
        case .cloud:
            showsLocalModels = false
            showsCloudProviderOptions = true
            showsActiveCloudModelOptions = true
        case nil:
            showsLocalModels = false
            showsCloudProviderOptions = false
            showsActiveCloudModelOptions = false
        }
    }

    @MainActor
    private func refreshLocalModelSubtitleCache() {
        let qwen3UnifiedPickerPairAvailable = qwen3UnifiedPickerPairAvailableForSubtitles
        var subtitles: [String: String] = [:]
        for model in installedSelectableModels + installableSelectableModels {
            subtitles[model.id] = Self.staticLocalModelSubtitle(
                for: model,
                qwen3UnifiedPickerPairAvailable: qwen3UnifiedPickerPairAvailable
            )
        }
        localModelSubtitleCache = subtitles
    }

    private var displayedOperatingModes: [EpistemosOperatingMode] {
        let modes = availableOperatingModes ?? inference.availableOperatingModes
        return modes.isEmpty ? [.fast] : modes
    }

    private func sanitizedDisplayedOperatingMode(_ mode: EpistemosOperatingMode) -> EpistemosOperatingMode {
        guard displayedOperatingModes.contains(mode) else {
            return displayedOperatingModes.first ?? .fast
        }
        return mode
    }

    private func popoverBinding(_ popover: SplitToolbarPopover) -> Binding<Bool> {
        Binding(
            get: { activeSplitPopover == popover },
            set: { isPresented in
                activeSplitPopover = isPresented ? popover : nil
            }
        )
    }

    var body: some View {
        Group {
            if overrideTitle != nil {
                titleLabel
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .help(labelText)
                    .accessibilityLabel(labelText)
            } else if usesSplitToolbarControls {
                splitToolbarControls
            } else {
                // When the surface opted out of split toolbar controls
                // (mini/note/graph chat), size the single popover button to
                // fit the actual label rather than reserving worst-case
                // "Apple Intelligence Agent" width. The stable-width
                // reservation still applies when a split-toolbar caller
                // falls through this branch (e.g. via `overrideTitle`).
                let usesCompactNaturalWidth = operatingMode != nil
                    && overrideTitle == nil
                    && !preferSplitToolbarControls
                AnchoredPopoverButton(
                    title: labelText,
                    systemImage: buttonSystemImage,
                    isPresented: $isPresented,
                    isActive: isTemporaryChatEnabled?.wrappedValue == true,
                    variant: variant,
                    showsLabelWhenCollapsed: true,
                    helpText: selectedModeSummary,
                    accessibilityLabel: labelText,
                    idealPopoverWidth: variant == .toolbar ? 340 : 360,
                    contentPadding: 12,
                    stableWidth: usesCompactNaturalWidth ? nil : disclosureWidth
                ) {
                    runtimePopover
                }
                .fixedSize()
            }
        }
        .task(id: inference.preferredChatModelSelection.rawValue) {
            sanitizeReleaseLocalSelectionIfNeeded()
            syncModelPickerDisclosureState()
        }
        .task(id: currentOperatingMode?.rawValue ?? "none") {
            syncReasoningTierToDisplayedModeIfNeeded()
        }
        .task(id: activeSplitPopover == .model) {
            guard activeSplitPopover == .model else { return }
            syncModelPickerDisclosureState()
        }
        .task(id: localModelSubtitleInputsFingerprint) {
            refreshLocalModelSubtitleCache()
        }
    }

    @ViewBuilder
    private var splitToolbarControls: some View {
        HStack(spacing: 6) {
            if let operatingMode = currentOperatingMode {
                AnchoredPopoverButton(
                    title: operatingMode.displayName,
                    systemImage: operatingMode.systemImage,
                    isPresented: popoverBinding(.mode),
                    isActive: false,
                    variant: variant,
                    showsLabelWhenCollapsed: true,
                    helpText: operatingMode.helpText,
                    accessibilityLabel: "\(operatingMode.displayName) mode",
                    idealPopoverWidth: variant == .toolbar ? 300 : 320,
                    contentPadding: 12,
                    stableWidth: modeDisclosureWidth
                ) {
                    modePopover
                }
                .fixedSize()
            }

            if !hidesModelButton {
                AnchoredPopoverButton(
                    title: modelButtonTitle,
                    systemImage: modelButtonSystemImage,
                    isPresented: popoverBinding(.model),
                    isActive: false,
                    variant: variant,
                    showsLabelWhenCollapsed: !hidesLocalModelLabel,
                    helpText: selectedModeSummary,
                    accessibilityLabel: "\(modelButtonTitle) model",
                    idealPopoverWidth: variant == .toolbar ? 340 : 360,
                    contentPadding: 12,
                    stableWidth: hidesLocalModelLabel ? nil : modelDisclosureWidth
                ) {
                    modelPopover
                }
                .fixedSize()
            }

            AnchoredPopoverButton(
                title: routeButtonTitle,
                systemImage: "arrow.triangle.branch",
                isPresented: popoverBinding(.routing),
                isActive: false,
                variant: variant,
                showsLabelWhenCollapsed: false,
                helpText: selectedModeSummary,
                accessibilityLabel: routeButtonTitle,
                idealPopoverWidth: variant == .toolbar ? 340 : 360,
                contentPadding: 12
            ) {
                routingPopover
            }
            .fixedSize()

            if supportsRuntimeEffortButton {
                AnchoredPopoverButton(
                    title: effortButtonTitle,
                    systemImage: "slider.horizontal.3",
                    isPresented: popoverBinding(.effort),
                    isActive: false,
                    variant: variant,
                    showsLabelWhenCollapsed: true,
                    helpText: "Adjust model-native reasoning effort for this mode.",
                    accessibilityLabel: "\(effortButtonTitle) effort",
                    idealPopoverWidth: variant == .toolbar ? 280 : 300,
                    contentPadding: 12,
                    stableWidth: effortDisclosureWidth
                ) {
                    effortPopover
                }
                .fixedSize()
            }

            if supportsProviderNativeControlsButton {
                AnchoredPopoverButton(
                    title: nativeControlsButtonTitle,
                    systemImage: nativeControlsButtonSystemImage,
                    isPresented: popoverBinding(.nativeControls),
                    isActive: false,
                    variant: variant,
                    showsLabelWhenCollapsed: true,
                    helpText: "Provider-native controls for the current cloud model.",
                    accessibilityLabel: "\(nativeControlsButtonTitle) controls",
                    idealPopoverWidth: variant == .toolbar ? 320 : 340,
                    contentPadding: 12,
                    stableWidth: nativeControlsDisclosureWidth
                ) {
                    nativeControlsPopover
                }
                .fixedSize()
            }

            if isTemporaryChatEnabled != nil {
                temporaryChatButton
            }

            settingsButton
        }
    }

    @ViewBuilder
    private var modePopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let operatingMode = currentOperatingMode {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mode")
                        .font(.system(size: 13, weight: .semibold))
                    Text(operatingMode.helpText)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(displayedOperatingModes, id: \.rawValue) { option in
                    selectionRow(
                        title: option.displayName,
                        subtitle: modeSubtitle(for: option, isEnabled: true),
                        systemImage: option.systemImage,
                        isSelected: currentOperatingMode == option,
                        isEnabled: true
                    ) {
                        if let operatingMode {
                            let sanitizedMode = sanitizedDisplayedOperatingMode(option)
                            operatingMode.wrappedValue = sanitizedMode
                            inference.setChatReasoningTier(
                                inference.chatReasoningTier,
                                for: sanitizedMode
                            )
                        }
                        activeSplitPopover = nil
                    }
                }
            }
        }
        .animation(
            .easeInOut(duration: 0.15),
            value: displayedOperatingModes.map(\.rawValue).joined(separator: "|")
        )
    }

    @ViewBuilder
    private var modelPopover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Model")
                        .font(.system(size: 13, weight: .semibold))
                    Text(selectedModeSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    popoverSectionTitle("Models")
                    localModelsDisclosure(closeAction: {
                        activeSplitPopover = nil
                    })

                    pickerCloudSection
                }

                agentSwitcherSection
            }
        }
        .frame(width: 320, height: 380, alignment: .topLeading)
        .popover(item: $aboutSelection) { selection in
            ModelAboutSheet(selection: selection)
        }
    }

    /// In-chat agent switcher: activate any Companion (agent) directly from the
    /// model picker. The active Companion's system instruction + persona already
    /// flow into the chat (AppBootstrap wires activeCompanionInstructionProvider
    /// into the pipeline), so switching here changes how the chat behaves — your
    /// agents are now reachable from the chat, not just the Landing farm.
    @ViewBuilder
    private var agentSwitcherSection: some View {
        if !companionState.roster.isEmpty {
            Divider()
                .padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 8) {
                popoverSectionTitle("Agents")
                selectionRow(
                    title: "No agent (base)",
                    subtitle: "Plain chat with the selected model.",
                    systemImage: "person",
                    isSelected: companionState.activeCompanionID == nil
                ) {
                    companionState.deactivate()
                    activeSplitPopover = nil
                }
                ForEach(companionState.roster) { entry in
                    selectionRow(
                        title: entry.name,
                        subtitle: entry.tagline.isEmpty ? "Custom agent" : entry.tagline,
                        systemImage: "sparkles",
                        isSelected: companionState.activeCompanionID == entry.id
                    ) {
                        companionState.activate(entry.id)
                        activeSplitPopover = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var routingPopover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Routing")
                        .font(.system(size: 13, weight: .semibold))
                    Text(selectedModeSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }

                routingSection
            }
        }
    }

    @ViewBuilder
    private var effortPopover: some View {
        if let currentOperatingMode,
           let model = currentEffectiveCloudModel {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reasoning Effort")
                        .font(.system(size: 13, weight: .semibold))
                    Text(
                        "\(inference.runtimeProviderDisplayName(for: model.provider)) controls for \(currentOperatingMode.displayName) mode."
                    )
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(inference.availableReasoningTiers(for: currentOperatingMode), id: \.self) { tier in
                        selectionRow(
                            title: inference.reasoningTierLabel(
                                for: tier,
                                operatingMode: currentOperatingMode
                            ),
                            subtitle: tier.summary,
                            systemImage: currentOperatingMode.systemImage,
                            isSelected: currentDisplayedReasoningTier == tier,
                            isEnabled: true
                        ) {
                            inference.setChatReasoningTier(tier, for: currentOperatingMode)
                            activeSplitPopover = nil
                        }
                    }
                }
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var nativeControlsPopover: some View {
        if let model = currentEffectiveCloudModel {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(nativeControlsButtonTitle) Controls")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Provider-native options for \(model.displayName).")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textTertiary)
                    }

                    providerNativeControls(for: model)
                }
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var temporaryChatButton: some View {
        ToolbarCapsuleButton(
            title: nil,
            systemImage: isTemporaryChatEnabled?.wrappedValue == true ? "eye.slash.fill" : "eye.slash",
            variant: variant,
            role: .toolbarUtility,
            isActive: isTemporaryChatEnabled?.wrappedValue == true,
            helpText: isTemporaryChatEnabled?.wrappedValue == true
                ? "Temporary chat is on"
                : "Temporary chat is off",
            accessibilityLabel: "Temporary chat"
        ) {
            isTemporaryChatEnabled?.wrappedValue.toggle()
        }
    }

    @ViewBuilder
    private func providerNativeControls(for model: CloudTextModelID) -> some View {
        switch model.provider {
        case .openAI:
            VStack(alignment: .leading, spacing: 10) {
                if model.supportsNativeReasoningEffortControl,
                   let currentOperatingMode,
                   !inference.availableReasoningTiers(for: currentOperatingMode).isEmpty {
                    SettingsDescriptionText(
                        text: "Use the Effort button for Low, Medium, High, or Extra High Codex effort. OpenAI tool toggles live here."
                    )
                }
                Toggle(
                    "Enable Web Search",
                    isOn: Binding(
                        get: { inference.openAIWebSearchEnabled },
                        set: { inference.setOpenAIWebSearchEnabled($0) }
                    )
                )
                Toggle(
                    "Enable Code Interpreter",
                    isOn: Binding(
                        get: { inference.openAICodeInterpreterEnabled },
                        set: { inference.setOpenAICodeInterpreterEnabled($0) }
                    )
                )
            }

        case .anthropic:
            VStack(alignment: .leading, spacing: 10) {
                if model.supportsNativeReasoningEffortControl {
                    SettingsDescriptionText(
                        text: "Use the Effort button for Low, Medium, High, or Max adaptive thinking effort. Adaptive Thinking can still be disabled entirely for Anthropic chat turns."
                    )
                }
                if !model.nativeReasoningModes.isEmpty {
                    Toggle(
                        "Enable Adaptive Thinking",
                        isOn: Binding(
                            get: { inference.anthropicAdaptiveThinkingEnabled },
                            set: { inference.setAnthropicAdaptiveThinkingEnabled($0) }
                        )
                    )
                }
                Toggle(
                    "Enable Web Search",
                    isOn: Binding(
                        get: { inference.anthropicWebSearchEnabled },
                        set: { inference.setAnthropicWebSearchEnabled($0) }
                    )
                )
                Toggle(
                    "Enable Web Fetch (single URL)",
                    isOn: Binding(
                        get: { inference.anthropicWebFetchEnabled },
                        set: { inference.setAnthropicWebFetchEnabled($0) }
                    )
                )
                Toggle(
                    "Enable Code Execution (Python sandbox)",
                    isOn: Binding(
                        get: { inference.anthropicCodeExecutionEnabled },
                        set: { inference.setAnthropicCodeExecutionEnabled($0) }
                    )
                )
            }

        case .google:
            VStack(alignment: .leading, spacing: 10) {
                if model.supportsNativeReasoningEffortControl,
                   let currentOperatingMode,
                   !inference.availableReasoningTiers(for: currentOperatingMode).isEmpty {
                    SettingsDescriptionText(
                        text: "Use the Effort button for \(currentOperatingMode.displayName.lowercased()) thinking depth. Grounding lives here."
                    )
                }
                Toggle(
                    "Enable Grounding with Google Search",
                    isOn: Binding(
                        get: { inference.googleGroundingEnabled },
                        set: { inference.setGoogleGroundingEnabled($0) }
                    )
                )
            }

        case .zai, .kimi, .minimax, .deepseek:
            EmptyView()
        }
    }

    @ViewBuilder
    private var settingsButton: some View {
        ToolbarCapsuleButton(
            title: nil,
            systemImage: "gearshape",
            variant: variant,
            role: .toolbarUtility,
            isActive: false,
            helpText: "Open AI settings",
            accessibilityLabel: "AI settings"
        ) {
            openSettings()
            activeSplitPopover = nil
        }
    }

    @ViewBuilder
    private var runtimePopover: some View {
        Group {
            if EpistemosFoundationLineup.simplifiedLineupActive {
                simplifiedRuntimePopover
            } else {
                legacyRuntimePopover
            }
        }
        .popover(item: $aboutSelection) { selection in
            ModelAboutSheet(selection: selection)
        }
    }

    /// Simplified picker (owner 2026-06-16): the default popover is just the
    /// three Epistemos efforts — Fast / Think / Code — plus one Cloud toggle.
    /// Routing, per-model details, cloud provider/model setup, and Temporary
    /// Chat fold away under a single collapsed "Advanced" disclosure, so the
    /// chooser reads as "pick an effort," not "configure a runtime."
    // MARK: - P1.11 rebuilt runtime picker (explicit Fast/Think/Code picks)

    /// Live inputs for `EpistemosRuntimePicker`, read off `InferenceState`. Free
    /// memory comes from the same monitor the composer's memory blocker uses, so
    /// the picker's gating matches what will actually load.
    private var runtimePickerEnvironment: EpistemosRuntimePicker.Environment {
        let bytes = LocalInferenceMemoryPressureMonitor.availableMemoryBytes()
        let freeGB = bytes > 0 ? Int(bytes / 1_073_741_824) : 0
        // SS-CHATPICKER P0 — offer the user's installed (∪ prepared) models, filtered by the owner's
        // advertised set, so installed models outside the fixed lineup are clickable picks.
        let installed = inference.installedLocalTextModelIDs.union(inference.preparedLocalTextModelIDs)
        let store = AdvertisedModelStore()
        return .init(
            installedModelIDs: installed,
            freeMemoryGB: freeGB,
            appleIntelligenceAvailable: inference.appleIntelligenceAvailable,
            additionalPicks: RuntimePickerExtraPicksBuilder.picks(
                installedIDs: installed,
                advertised: store.effectiveAdvertised(fullCatalog: installed),
                isCustomized: store.isCustomized
            )
        )
    }

    private func runtimePickerOperatingMode(for tier: EpistemosModelTier) -> EpistemosOperatingMode {
        switch tier {
        case .fast: return .fast
        case .think: return .thinking
        case .code: return .pro
        }
    }

    private func isRuntimePickSelected(_ option: EpistemosRuntimePicker.Option) -> Bool {
        if option.isAppleIntelligence {
            return inference.preferredChatModelSelection == .appleIntelligence
        }
        return inference.preferredChatModelSelection == .localMLX(option.id)
    }

    /// Select a pick: set the tier's operating mode + pin the model. A
    /// not-installed / memory-blocked pick routes to Settings (the honest path to
    /// install or free memory) instead of silently switching.
    private func selectRuntimePick(_ option: EpistemosRuntimePicker.Option) {
        guard option.isSelectable else {
            openSettings()
            isPresented = false
            return
        }
        let mode = runtimePickerOperatingMode(for: option.tier)
        operatingMode?.wrappedValue = mode
        lastTierMode = mode
        if option.isAppleIntelligence {
            inference.setPreferredChatModelSelection(.appleIntelligence)
        } else {
            inference.setPreferredChatModelSelection(.localMLX(option.id))
        }
        isPresented = false
    }

    /// The rebuilt picker body: explicit per-tier model picks, each honestly
    /// gated (installed + fits memory) with the blocker shown inline. Replaces
    /// the old Fast/Think/Code mode-rows + the separate Apple Intelligence
    /// section (Apple Intelligence is now a Fast pick).
    @ViewBuilder
    private var foundationPickerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(EpistemosModelTier.allCases, id: \.rawValue) { tier in
                VStack(alignment: .leading, spacing: 8) {
                    popoverSectionTitle(tier.shortName)
                    ForEach(EpistemosRuntimePicker.options(for: tier, environment: runtimePickerEnvironment)) { option in
                        selectionRow(
                            title: option.title,
                            subtitle: option.blockedReason ?? tier.tagline,
                            systemImage: option.isAppleIntelligence ? "apple.intelligence" : tier.systemImage,
                            isSelected: isRuntimePickSelected(option),
                            isEnabled: option.isSelectable
                        ) {
                            selectRuntimePick(option)
                        }
                    }
                }
            }
        }
    }

    private var simplifiedRuntimePopover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Epistemos AI")
                        .font(.system(size: 13, weight: .semibold))
                    Text(selectedModeSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }

                depthToggleSection

                // P1.11 — explicit per-tier model picks (Fast = Gemma sizes +
                // Apple Intelligence; Think = VibeThinker + Qwen 3 8B; Code =
                // coder), driven by EpistemosRuntimePicker with honest gating.
                // Replaces the old Tier mode-rows + the separate Apple
                // Intelligence section.
                foundationPickerSection

                cloudToggleSection

                DisclosureGroup(isExpanded: $showsAdvancedRuntimeOptions) {
                    VStack(alignment: .leading, spacing: 14) {
                        routingSection
                        VStack(alignment: .leading, spacing: 8) {
                            popoverSectionTitle("Models")
                            localModelsDisclosure(closeAction: {
                                isPresented = false
                            })
                        }
                        pickerCloudSection
                        if let isTemporaryChatEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                popoverSectionTitle("Conversation")
                                selectionRow(
                                    title: "Temporary Chat",
                                    subtitle: isTemporaryChatEnabled.wrappedValue
                                        ? "This conversation stays in memory only and will not be saved."
                                        : "Turns off chat persistence for this thread.",
                                    systemImage: isTemporaryChatEnabled.wrappedValue ? "eye.slash.fill" : "eye.slash",
                                    isSelected: isTemporaryChatEnabled.wrappedValue
                                ) {
                                    isTemporaryChatEnabled.wrappedValue.toggle()
                                }
                            }
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    disclosureTitle(
                        title: "Advanced",
                        subtitle: "Routing, model details, cloud setup"
                    )
                }

                Divider()

                Button("Open Settings") {
                    openSettings()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.resolved.accent.color)
            }
        }
    }

    /// Cloud as ONE clean on/off. When on, the provider + model detail live in
    /// Advanced (pickerCloudSection); when off, chat stays on-device. Honest:
    /// the subtitle names the active provider+model, or nudges to setup.
    @ViewBuilder
    private var cloudToggleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            popoverSectionTitle("Cloud")
            Toggle(isOn: Binding(
                get: { inference.cloudModelsEnabled },
                set: { isOn in
                    inference.setCloudModelsEnabled(isOn)
                    if isOn { showsAdvancedRuntimeOptions = true }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use cloud models")
                        .font(.system(size: 12.5, weight: .semibold))
                    Text(cloudToggleSubtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .toggleStyle(.switch)
        }
    }

    private var cloudToggleSubtitle: String {
        if let provider = displayedCloudProvider,
           inference.configuredCloudProviders.contains(provider) {
            return "\(provider.displayName) • \(inference.preferredCloudModel(for: provider).compactDisplayName)"
        }
        if inference.cloudModelsEnabled {
            return "Connect a provider in Settings → Inference"
        }
        return "Chat stays on-device. Turn on to route to GPT, Claude, and more."
    }

    /// P7.6 — the Chat/Act depth toggle (the cowork "how it works" axis). Chat is
    /// conversational on the selected tier; Act runs the multi-step agent loop
    /// (`operatingMode == .agent`). Honest gating: Act is only enabled when an
    /// agent route exists (`.agent` in the available modes — cloud/Pro); else it's
    /// disabled with the real reason, never faking agent capability for local.
    @ViewBuilder
    private var depthToggleSection: some View {
        if let operatingMode {
            let actAvailable = CoworkChatMode.actAvailable(in: displayedOperatingModes)
            let current = CoworkChatMode.current(for: operatingMode.wrappedValue)
            VStack(alignment: .leading, spacing: 8) {
                popoverSectionTitle("Mode")
                selectionRow(
                    title: CoworkChatMode.chat.displayName,
                    subtitle: "Conversational — answers on your selected tier.",
                    systemImage: CoworkChatMode.chat.systemImage,
                    isSelected: current == .chat,
                    isEnabled: true
                ) {
                    operatingMode.wrappedValue = CoworkChatMode.chat.operatingMode(rememberedTier: lastTierMode)
                }
                selectionRow(
                    title: CoworkChatMode.act.displayName,
                    subtitle: actAvailable
                        ? "Multi-step agent loop — uses tools, memory, and skills."
                        : CoworkChatMode.actUnavailableReason,
                    systemImage: CoworkChatMode.act.systemImage,
                    isSelected: current == .act,
                    isEnabled: actAvailable
                ) {
                    operatingMode.wrappedValue = .agent
                }
            }
        }
    }

    private var appleIntelligenceSelected: Bool {
        inference.preferredChatModelSelection == .appleIntelligence
    }

    @ViewBuilder
    private var legacyRuntimePopover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Runtime")
                        .font(.system(size: 13, weight: .semibold))
                    Text(selectedModeSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }

                if let operatingMode {
                    VStack(alignment: .leading, spacing: 8) {
                        popoverSectionTitle("Mode")
                        ForEach(displayedOperatingModes, id: \.rawValue) { option in
                            selectionRow(
                                title: option.displayName,
                                subtitle: modeSubtitle(for: option, isEnabled: true),
                                systemImage: option.systemImage,
                                isSelected: operatingMode.wrappedValue == option,
                                isEnabled: true
                            ) {
                                let sanitizedMode = sanitizedDisplayedOperatingMode(option)
                                operatingMode.wrappedValue = sanitizedMode
                                inference.setChatReasoningTier(
                                    inference.chatReasoningTier,
                                    for: sanitizedMode
                                )
                                isPresented = false
                            }
                        }
                    }
                    .animation(
                        .easeInOut(duration: 0.15),
                        value: displayedOperatingModes.map(\.rawValue).joined(separator: "|")
                    )
                }

                routingSection

                VStack(alignment: .leading, spacing: 8) {
                    popoverSectionTitle("Models")
                    localModelsDisclosure(closeAction: {
                        isPresented = false
                    })

                    // Cloud section — drastically simplified. Picker shows
                    // ONE cloud row (the user's preferred cloud model),
                    // never the full multi-provider + multi-model catalog.
                    // To change which cloud model is preferred, users go
                    // to Settings → Inference. Two things only here:
                    //   1. A single selectable row for the preferred cloud
                    //      model (tap to switch the next turn to cloud)
                    //   2. A "Change in Settings" link
                    // If no cloud provider is configured, show a compact
                    // hint linking to setup.
                    pickerCloudSection
                }

                if let isTemporaryChatEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        popoverSectionTitle("Conversation")
                        selectionRow(
                            title: "Temporary Chat",
                            subtitle: isTemporaryChatEnabled.wrappedValue
                                ? "This conversation stays in memory only and will not be saved."
                                : "Turns off chat persistence for this thread.",
                            systemImage: isTemporaryChatEnabled.wrappedValue ? "eye.slash.fill" : "eye.slash",
                            isSelected: isTemporaryChatEnabled.wrappedValue
                        ) {
                            isTemporaryChatEnabled.wrappedValue.toggle()
                        }
                    }
                }

                Divider()

                Button("Open Settings") {
                    openSettings()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.resolved.accent.color)
            }
        }
    }

    @ViewBuilder
    private func popoverSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
    }

    @ViewBuilder
    private func disclosureTitle(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(theme.textTertiary)
        }
    }

    private var localModelsDisclosureSubtitle: String {
        let gemmaCount = gemmaQATRouteIntegrationCandidates.count
        if installableSelectableModels.isEmpty {
            let base = installedSelectableModels.isEmpty
                ? "On-device"
                : "\(installedSelectableModels.count) installed"
            return gemmaCount == 0 ? base : "\(base) • \(gemmaCount) Gemma pending"
        }
        let base = "\(installedSelectableModels.count) installed • \(installableSelectableModels.count) available"
        return gemmaCount == 0 ? base : "\(base) • \(gemmaCount) Gemma pending"
    }

    @ViewBuilder
    private func localModelsDisclosure(
        closeAction: @escaping () -> Void
    ) -> some View {
        DisclosureGroup(
            isExpanded: $showsLocalModels,
            content: {
                VStack(alignment: .leading, spacing: 6) {
                    localModelRows(closeAction: closeAction)
                }
            },
            label: {
                disclosureTitle(
                    title: "Local Models",
                    subtitle: localModelsDisclosureSubtitle
                )
            }
        )
    }

    @ViewBuilder
    private func localModelRows(
        closeAction: @escaping () -> Void
    ) -> some View {
        if inference.appleIntelligenceAvailable {
            selectionRow(
                title: "Apple Intelligence",
                subtitle: "Optional Apple on-device runtime for simple fallback work.",
                systemImage: "apple.intelligence",
                isSelected: selectedMenuItem == .appleIntelligence
            ) {
                inference.setPreferredChatModelSelection(.appleIntelligence)
                closeAction()
            }
        }

        if installedSelectableModels.isEmpty {
            if EpistemosFoundationLineup.simplifiedLineupActive {
                // Fresh state: no local model yet. Point straight at the
                // one-tap foundation install instead of a dead-end message.
                selectionRow(
                    title: "Set up Epistemos AI",
                    subtitle: "Download the foundation package (Gemma · VibeThinker · coder) to chat on-device.",
                    systemImage: "arrow.down.circle",
                    isSelected: false
                ) {
                    openSettings()
                    closeAction()
                }
            } else {
                Text(noLocalModelsText)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.leading, 4)
                    .padding(.top, 2)
            }
        } else {
            ForEach(installedSelectableModels, id: \.id) { model in
                HStack(spacing: 0) {
                    selectionRow(
                        title: inference.localModelPickerDisplayName(for: model.id),
                        subtitle: localModelSubtitleWithAgentBadge(for: model),
                        systemImage: "memorychip",
                        isSelected: selectedMenuItem == .inProcess(model)
                    ) {
                        inference.setPreferredChatModelSelection(.localMLX(model.id))
                        closeAction()
                    }

                    Button {
                        aboutSelection = .localMLX(model.id)
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Model details")
                }
            }
        }

        if !installableSelectableModels.isEmpty {
            Divider()
                .padding(.vertical, 4)

            ForEach(installableSelectableModels, id: \.id) { model in
                selectionRow(
                    title: inference.localModelPickerDisplayName(for: model.id),
                    subtitle: "Available to install • \(localModelSubtitleWithAgentBadge(for: model))",
                    systemImage: "arrow.down.circle",
                    isSelected: false
                ) {
                    openSettings()
                    closeAction()
                }
            }
        }

        gemmaQATRouteLaneRows(closeAction: closeAction)
    }

    @ViewBuilder
    private func gemmaQATRouteLaneRows(
        closeAction: @escaping () -> Void
    ) -> some View {
        // Simplified lineup: the chat picker hides the GGUF route-lane
        // diagnostics jargon (packet evidence / route-integration cursor /
        // Open Diagnostics) — that belongs in Settings, not the model picker.
        // Keeps the picker simple.
        if !gemmaQATRouteIntegrationCandidates.isEmpty,
           !EpistemosFoundationLineup.simplifiedLineupActive {
            Divider()
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 3) {
                Text("Gemma QAT GGUF route lanes")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Text("E2B, E4B, and 12B have packet evidence, but stay read-only until \(GemmaQATRuntimeLadder.productRouteIntegrationCursor) wires a live route.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)

            ForEach(gemmaQATRouteIntegrationCandidates) { candidate in
                gemmaQATRouteLaneStatusRow(candidate)
            }

            selectionRow(
                title: "Open Diagnostics",
                subtitle: "Review GGUF receipts, WRV, and route integration status in Settings.",
                systemImage: "wrench.and.screwdriver",
                isSelected: false
            ) {
                openSettings()
                closeAction()
            }
        }
    }

    @ViewBuilder
    private func gemmaQATRouteLaneStatusRow(
        _ candidate: GemmaQATRuntimeCandidate
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: gemmaQATRouteLaneIcon(for: candidate.stage))
                .font(.system(size: variant == .toolbar ? 12 : 13, weight: .semibold))
                .foregroundStyle(theme.resolved.accent.color)
                .frame(width: 14, height: 14)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.displayName)
                    .font(.system(size: variant == .toolbar ? 12.5 : 13, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.leading)
                Text("\(candidate.routeIntegrationStatusLabel) • \(candidate.expectedByteCountLabel) • \(candidate.runtimeLane)")
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.textTertiary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.muted.opacity(theme.isDark ? 0.24 : 0.52))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.border.opacity(0.36), lineWidth: 0.6)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(candidate.displayName), \(candidate.routeIntegrationStatusLabel)")
        .help("Gemma QAT route evidence is present, but live chat selection is still gated.")
    }

    private func gemmaQATRouteLaneIcon(for stage: GemmaQATRuntimeStage) -> String {
        switch stage {
        case .firstRuntimeHarness:
            return "bolt.horizontal.circle"
        case .nextScaleLane:
            return "arrow.up.right.circle"
        case .proFlagshipCandidate:
            return "crown"
        case .specialistCoderFineTune:
            return "chevron.left.forwardslash.chevron.right"
        case .reasoningSpecialist:
            return "brain"
        case .moeFlagshipCandidate:
            return "square.stack.3d.up"
        case .liquidGeneralMoe:
            return "drop"
        case .gemmaTwelveBLowMemory:
            return "rectangle.compress.vertical"
        }
    }

    @ViewBuilder
    private var cloudProviderSelectionRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(CloudModelProvider.preferredOrder, id: \.rawValue) { provider in
                let selection = AIProviderSelection(cloudProvider: provider)
                selectionRow(
                    title: provider.displayName,
                    subtitle: providerSelectionSubtitle(for: provider),
                    systemImage: provider.systemImage,
                    isSelected: displayedCloudProvider == provider
                ) {
                    inference.setCloudModelsEnabled(true)
                    inference.setActiveAIProvider(selection)
                }
            }

            selectionRow(
                title: "Local Only",
                subtitle: "Keep chat on-device. Auto-route can only escalate again after you reactivate a cloud workspace.",
                systemImage: "memorychip",
                isSelected: inference.activeAIProvider == .localOnly && displayedCloudProvider == nil
            ) {
                inference.setChatAutoRouteToCloud(false)
                inference.setActiveAIProvider(.localOnly)
            }
        }
    }

    @ViewBuilder
    private var routingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            popoverSectionTitle("Routing")

            if let operatingMode {
                routeSummaryCard(for: inference.chatSurfaceRouteDescription(for: operatingMode.wrappedValue))
            }

            Toggle(isOn: Binding(
                get: { inference.cloudAutoFallback },
                set: { inference.setCloudAutoFallback($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fallback on failure")
                    Text("If the chosen cloud model errors, try the fallback chain instead of surfacing the first failure immediately.")
                        .font(.caption)
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .toggleStyle(.switch)
        }
    }

    @ViewBuilder
    private func routeSummaryCard(for route: ChatSurfaceRouteDescription) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: route.systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.resolved.accent.color)
                .frame(width: 14, height: 14)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(route.operatingMode.displayName) -> \(route.headline)")
                    .font(.system(size: 12, weight: .semibold))
                Text(route.summary)
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.muted.opacity(theme.isDark ? 0.28 : 0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.border.opacity(0.45), lineWidth: 0.6)
        )
    }

    @ViewBuilder
    private func selectionRow(
        title: String,
        subtitle: String,
        systemImage: String,
        isSelected: Bool,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: variant == .toolbar ? 12 : 13, weight: .semibold))
                    .frame(width: 14, height: 14)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: variant == .toolbar ? 12.5 : 13, weight: .semibold))
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(theme.textTertiary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.resolved.accent.color)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(NativeCardButtonStyle(cornerRadius: 12))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
    }

    private func modeSubtitle(for option: EpistemosOperatingMode, isEnabled: Bool) -> String {
        guard isEnabled else {
            switch option {
            case .thinking:
                return "This model does not expose verified thinking mode."
            case .pro:
                return "This model does not expose a verified pro-grade cloud route."
            case .agent:
                return "This model cannot run the current visible tools/runtime path."
            case .fast:
                return option.helpText
            }
        }
        return option.helpText
    }

    private func localModelSubtitle(for model: LocalModelDescriptor) -> String {
        localModelSubtitleCache[model.id] ?? Self.staticLocalModelSubtitle(
            for: model,
            qwen3UnifiedPickerPairAvailable: false
        )
    }

    private func localModelSubtitleWithAgentBadge(for model: LocalModelDescriptor) -> String {
        let badge = RuntimeRouter.agentCapabilityBadgeData(forLocalModelID: model.id)
        return "Agent \(badge.title) • \(localModelSubtitle(for: model))"
    }

    private static func staticLocalModelSubtitle(
        for model: LocalModelDescriptor,
        qwen3UnifiedPickerPairAvailable: Bool
    ) -> String {
        guard let modelID = LocalTextModelID(rawValue: model.id) else {
            return "On-device model"
        }

        var features: [String] = []
        let supportsThinking = modelID.supportsThinkingMode
            || (qwen3UnifiedPickerPairAvailable && modelID == .qwen3_4B4Bit)
        if supportsThinking {
            features.append("Thinking")
        }
        if modelID.canRunLocalAgentLoop {
            features.append("Tools")
        }
        let featureSummary = features.isEmpty ? "Fast only" : features.joined(separator: " • ")
        return "\(featureSummary) • Chat \(modelID.minimumRecommendedInteractiveMemoryGB) GB+"
    }

    private func providerSelectionSubtitle(for provider: CloudModelProvider) -> String {
        let status = inference.configuredCloudProviders.contains(provider)
            ? inference.cloudValidationState(for: provider).statusBadge
            : (provider.supportsAccountConnection ? "Account setup" : "API key setup")
        return "\(provider.modelSummary) • \(status)"
    }

    private func cloudModelSubtitle(for model: CloudTextModelID) -> String {
        let provider = model.provider
        let routeSummary = inference.chatAutoRouteToCloud
            ? "Used when the stack escalates"
            : "Runs directly when selected"
        let configuration = inference.configuredCloudProviders.contains(provider)
            ? "Ready"
            : "Finish setup"
        return "\(provider.displayName) • \(routeSummary) • \(configuration)"
    }

    /// Cloud provider + model controls rendered in the runtime popover.
    /// When auto-route is on, choosing a cloud model configures the
    /// escalation target without forcing the current chat off local.
    @ViewBuilder
    private var pickerCloudSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            popoverSectionTitle("Cloud")

            if inference.isCloudPickBlockedByFocus {
                // AR4 (Wave 14 Focus filters) — surface the
                // `forceLocalModelsOnly` axis so the user knows their
                // active Focus is suppressing cloud picks; the actual
                // collapse to local happens in `setPreferredChatModelSelection`.
                Label("Focus: Local-only — cloud picks fall back to local",
                      systemImage: "moon.zzz")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(theme.textSecondary.opacity(0.06), in: Capsule())
            }

            DisclosureGroup(
                isExpanded: $showsCloudProviderOptions,
                content: { cloudProviderSelectionRows },
                label: {
                    disclosureTitle(
                        title: "Cloud Provider",
                        subtitle: cloudProviderDisclosureSubtitle
                    )
                }
            )

            if let provider = displayedCloudProvider,
               inference.configuredCloudProviders.contains(provider) {
                DisclosureGroup(
                    isExpanded: $showsActiveCloudModelOptions,
                    content: {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(inference.cloudModels(for: provider), id: \.rawValue) { model in
                                selectionRow(
                                    title: model.displayName,
                                    subtitle: cloudModelSubtitle(for: model),
                                    systemImage: provider.systemImage,
                                    isSelected: isCloudModelSelected(model)
                                ) {
                                    // Always commit the user's explicit pick to
                                    // `preferredChatModelSelection` so the next
                                    // turn actually routes to this cloud model.
                                    // Previously the auto-route branch only
                                    // updated `preferredCloudModel` (the
                                    // auto-route default), leaving the chat
                                    // primary on whatever local model the user
                                    // had previously selected — that's the
                                    // "I picked GPT-4o but got DeepSeek R1 7B
                                    // memory error" regression users hit on
                                    // 2026-04-20. Also refresh the
                                    // auto-route cloud preference so the
                                    // chosen model is the fallback when the
                                    // user later switches back to local.
                                    inference.setCloudModelsEnabled(true)
                                    inference.setPreferredCloudModel(model)
                                    inference.setPreferredChatModelSelection(.cloud(model))
                                    isPresented = false
                                }
                            }
                        }
                    },
                    label: {
                        disclosureTitle(
                            title: "Cloud Model",
                            subtitle: cloudAccessSubtitle
                        )
                    }
                )
            } else {
                Text("Connect a cloud provider in Settings → Inference to give the chat stack a cloud escalation path.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.leading, 4)
            }

        }
    }

    private func isCloudModelSelected(_ model: CloudTextModelID) -> Bool {
        if inference.chatAutoRouteToCloud {
            return inference.preferredCloudModel(for: model.provider) == model
        }
        return selectedMenuItem == .cloud(model)
    }

    private var cloudAccessSubtitle: String {
        guard let provider = displayedCloudProvider else {
            return "Local Only"
        }
        let preferredModel = inference.preferredCloudModel(for: provider)
        let validation = inference.cloudValidationState(for: provider)
        if inference.configuredCloudProviders.contains(provider) {
            return "\(preferredModel.compactDisplayName) • \(validation.statusBadge)"
        }
        return "Finish setup to unlock"
    }

    private var cloudProviderDisclosureSubtitle: String {
        guard let provider = displayedCloudProvider else {
            return "Choose a provider"
        }
        if inference.configuredCloudProviders.contains(provider) {
            return "\(provider.displayName) • Active stack"
        }
        if provider.supportsAccountConnection {
            return "\(provider.displayName) • Account first"
        }
        return "\(provider.displayName) • API key"
    }

    private func openSettings() {
        UtilityWindowManager.shared.show(.settings)
        NSApp.activate()
    }

    @ViewBuilder
    private var titleLabel: some View {
        HStack(spacing: 5) {
            if overrideTitle != nil {
                TypewriterASCIIRippleText(
                    text: labelText,
                    font: labelFont,
                    color: theme.textSecondary,
                    configuration: .init(duration: 0.55, spread: 1.25, waveThreshold: 2.2, characterMultiplier: 2)
                )
            } else {
                ASCIIRippleText(
                    text: labelText,
                    font: labelFont,
                    color: theme.textSecondary,
                    configuration: .init(duration: 0.55, spread: 1.25, waveThreshold: 2.2, characterMultiplier: 2)
                )
            }
        }
        .fixedSize()
    }
}


private struct DatabaseRecoveryOverlay: View {
    let error: Error
    let resetAction: () -> Void
    let quitAction: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Database Recovery Required")
                        .font(.system(size: 22, weight: .semibold))

                    Text("This recovery session is not durable.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)

                    Text("Notes, chat, capture, vault sync, and .epdoc writes are disabled until the database is reset or the store is repaired and Epistemos is relaunched.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(error.localizedDescription)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                HStack(spacing: 12) {
                    Button("Reset Database", role: .destructive) {
                        resetAction()
                    }

                    Button("Quit") {
                        quitAction()
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 620, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 28, y: 12)
            .padding(32)
        }
    }
}


private struct VaultActivityStatusOverlay: View {
    let message: String
    let progress: VaultImportProgressSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                if let fraction = progress?.progressFraction {
                    ProgressView(value: fraction)
                        .frame(width: 92)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(message)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if let progress {
                Text("\(progress.mutationSummary) · \(progress.inventorySummary)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
        .accessibilityLabel(message)
    }
}


private struct VaultRecoveryOverlay: View {
    @State private var isVaultDisconnectAuthorizationInFlight = false

    let issue: VaultRecoveryIssue
    let isRecovering: Bool
    let rebuildAction: () -> Void
    let chooseVaultAction: () -> Void
    let disconnectAction: () -> Void

    private func requestVaultDisconnectAuthorization() {
        guard !isVaultDisconnectAuthorizationInFlight else { return }

        let target = RootViewDestructiveActionSovereignGate.Target.vaultDisconnect
        isVaultDisconnectAuthorizationInFlight = true

        Task { @MainActor in
            defer { isVaultDisconnectAuthorizationInFlight = false }

            let outcome = await AppBootstrap.shared?.sovereignGate.confirm(
                RootViewDestructiveActionSovereignGate.requirement(for: target),
                reason: RootViewDestructiveActionSovereignGate.reason(for: target)
            ) ?? .denied(.authenticationFailed)

            guard outcome == .allowed else { return }

            disconnectAction()
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.26)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("Vault Rebuild Needed")
                    .font(.system(size: 22, weight: .semibold))

                Text(issue.detailText)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                HStack(spacing: 12) {
                    Button(isRecovering ? "Rebuilding…" : "Rebuild Local State") {
                        rebuildAction()
                    }
                    .disabled(isRecovering || !issue.snapshot.isVaultReadable)

                    Button("Choose Vault Folder") {
                        chooseVaultAction()
                    }
                    .disabled(isRecovering)

                    Button("Disconnect Vault", role: .destructive) {
                        requestVaultDisconnectAuthorization()
                    }
                    .disabled(isRecovering || isVaultDisconnectAuthorizationInFlight)
                }
            }
            .padding(24)
            .frame(maxWidth: 620, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.16), radius: 28, y: 12)
            .padding(32)
        }
    }
}

// MARK: - Home Tab

enum HomeTab: String, CaseIterable {
    case home

    var label: String {
        switch self {
        case .home: "Home"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        }
    }
}

private enum RuntimeAuditRootFlags {
    static let rootShellMinimalContentKey = "EPI_HOME_WINDOW_ROOT_SHELL_MINIMAL_CONTENT"

    static var rootShellMinimalContentEnabled: Bool {
        ProcessInfo.processInfo.environment[rootShellMinimalContentKey] == "1"
    }
}

private struct AuditRootShellMinimalContentView: View {
    var body: some View {
        VStack {
            Button("test") {
                RuntimeDiagnostics.recordLifecycleEvent("root_shell_button_pressed")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ContentRouter: View {
    @Binding var actEntered: Bool
    @Binding var selectedActSessionId: UUID?
    @Binding var pendingActPrompt: PendingActPrompt?

    var body: some View {
        if RuntimeAuditRootFlags.rootShellMinimalContentEnabled {
            AuditRootShellMinimalContentView()
        } else {
            HomeRouter(
                actEntered: $actEntered,
                selectedActSessionId: $selectedActSessionId,
                pendingActPrompt: $pendingActPrompt
            )
        }
    }
}

// MARK: - Home Router
// Separate view so the Chat/Landing switch doesn't affect the outer ZStack.
// Uses withAnimation at call-site (submitQuery/clearMessages) for the transition.

private struct HomeRouter: View {
    @Environment(ChatState.self) private var chat
    @Environment(UIState.self) private var ui
    // 0.49b: the live vault so Work's fusion MCP server roots at the app vault (skills/context bridge).
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var actEntered: Bool
    @Binding var selectedActSessionId: UUID?
    @Binding var pendingActPrompt: PendingActPrompt?

    /// act↔work surface toggle (owner: "a toggle to open work"). Act keeps the
    /// Epistemos landing/chat surface and routes model/tool capability through
    /// Osaurus underneath; Work enters OpenCode's native terminal. Persisted via
    /// `WorkspaceModeSelection`.
    @State private var workspaceMode: WorkspaceModeKind = WorkspaceModeSelection.current()

    /// D2 (owner P0, addendum §1886 + landing→blur→act flow): Act shows the
    /// Epistemos `LandingView` first. Background/search-tile interaction reveals
    /// the centered search stage; submitting enters the Epistemos chat surface
    /// with Osaurus capability routed underneath. Per-session: false on launch
    /// (landing first), true once entered.
    // VERIFY HOOK: env `EPI_ACT_ENTERED=1` starts in the Act chat chrome for render checks.
    /// The work terminal roots at the user's home by default.
    private static var workWorkspaceURL: URL { URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true) }

    /// Show chat when messages exist AND user hasn't navigated to landing.
    private var showChat: Bool { !chat.messages.isEmpty && !chat.showLanding }

    /// 0.42: the Work surface's recent-chats entry point. Presents the SAME unified `ChatSidebarView`
    /// (Act + Work two-section list, 0.48b) the act surface uses via the shared `ui.showChatSidebar` flag —
    /// so Work gets a recent-chat bar without a second store. Tapping a Work row reopens via `.openWorkSession`.
    private var workRecentChatsButton: some View {
        @Bindable var ui = ui
        return Button {
            ui.toggleChatSidebar()
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 30)
                .background(.ultraThinMaterial, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(12)
        .help("Recent Chats (Act + Work)")
        .accessibilityLabel("Recent Chats")
        .popover(isPresented: $ui.showChatSidebar) {
            ChatSidebarView()
                .frame(width: 300, height: 500)
                .preferredColorScheme(ui.preferredColorScheme)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // ACT = Epistemos chat/search surface backed by Osaurus capability.
            // WORK = OpenCode's native terminal. The act↔work toggle switches
            // the surface.
            Group {
                #if EPISTEMOS_APP_STORE
                // MAS: act-only — the SwiftTerm/OpenCode work terminal is Pro-only.
                if showChat {
                    ChatView().transition(.blurFade())
                } else {
                    LandingView().transition(.blurFade())
                }
                #else
                if workspaceMode == .work {
                    // 0.49b: hand Work the live Epistemos vault so its fusion MCP server roots there —
                    // the work agent gets the app's vault notes + `skills/` as first-class MCP context
                    // (cwd stays the workspace for shell ops). nil vault → bundled shell uses the default.
                    WorkTerminalHostView(
                        workspace: Self.workWorkspaceURL,
                        epistemosVaultRoot: vaultSync.vaultURL)
                        .transition(.blurFade())
                        // 0.42: Work-side access to the UNIFIED recent-chats popover (owner: "work should have a
                        // recent chat bar") — same ChatSidebarView the act surface uses, with its Act + Work
                        // sections. One recent-chats system, surfaced on both modes.
                        .overlay(alignment: .topLeading) { workRecentChatsButton }
                } else if LocalAgentLoop.shouldRouteActThroughOsaurus() {
                    // Epistemos LandingView FIRST -> centered search -> submit -> Epistemos chat.
                    if actEntered {
                        actEpistemosChatSurface
                            .transition(.blurFade())
                    } else {
                        LandingView(onSubmitActPrompt: { prompt in
                            selectedActSessionId = nil
                            pendingActPrompt = PendingActPrompt(text: prompt)
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.32)) {
                                actEntered = true
                            }
                        })
                        .transition(.blurFade())
                    }
                } else if showChat {
                    ChatView().transition(.blurFade())
                } else {
                    LandingView().transition(.blurFade())
                }
                #endif
            }

            #if !EPISTEMOS_APP_STORE
            // Persistent act↔work toggle so the user can switch from launch/landing;
            // hidden during an active act chat so it never overlays the thread.
            if !(workspaceMode == .act && (LocalAgentLoop.shouldRouteActThroughOsaurus() && actEntered)) {
                WorkspaceModeToggle(mode: $workspaceMode)
                    .padding(.top, 10)
            }
            #endif
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: showChat)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: workspaceMode)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: actEntered)
        .onReceive(NotificationCenter.default.publisher(for: .openActOsaurusSession)) { notification in
            guard let sessionId = notification.object as? UUID else { return }
            WorkspaceModeSelection.select(.act)
            workspaceMode = .act
            selectedActSessionId = sessionId
            pendingActPrompt = nil
            ui.setActivePanel(.home)
            ui.homeTab = .home
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.28)) {
                actEntered = true
            }
            HomeWindowIdentity.surfaceHomeWindow()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openWorkSession)) { _ in
            // 0.48b-part2: reopen a Work session from the recent-chats popover → flip to .work (mirrors the act
            // reopen above). The work surface relaunches at its workspace; the worker row is a session marker.
            WorkspaceModeSelection.select(.work)
            workspaceMode = .work
            ui.setActivePanel(.home)
            ui.homeTab = .home
            HomeWindowIdentity.surfaceHomeWindow()
        }
        .onReceive(NotificationCenter.default.publisher(for: .submitActOsaurusPrompt)) { notification in
            guard let request = notification.object as? ActOsaurusPromptRequest else { return }
            let prompt = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prompt.isEmpty else { return }
            WorkspaceModeSelection.select(.act)
            workspaceMode = .act
            selectedActSessionId = nil
            pendingActPrompt = PendingActPrompt(
                text: prompt,
                contextAttachments: request.contextAttachments,
                fileAttachments: request.fileAttachments
            )
            selectedActSessionId = request.sessionId
            ui.setActivePanel(.home)
            ui.homeTab = .home
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.28)) {
                actEntered = true
            }
            HomeWindowIdentity.surfaceHomeWindow()
        }
    }

    @ViewBuilder
    private var actEpistemosChatSurface: some View {
        #if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
        ActEpistemosChatSurface(
            sessionId: selectedActSessionId,
            initialPrompt: pendingActPrompt?.text,
            initialPromptId: pendingActPrompt?.id,
            initialContextAttachments: pendingActPrompt?.contextAttachments ?? [],
            initialFileAttachments: pendingActPrompt?.fileAttachments ?? [],
            onInitialPromptConsumed: {
                pendingActPrompt = nil
            },
            onCurrentSessionChanged: { sessionId in
                selectedActSessionId = sessionId
            }
        )
        #else
        ChatView()
        #endif
    }

}

// MARK: - Workspace Mode Toggle

/// Clean act↔work surface toggle (owner: "a toggle to open work"). A capsule
/// segmented control — NO armed-dot / "experimental" framing (that was the drift;
/// act + work are both live now). Persists the choice via `WorkspaceModeSelection`.
private struct WorkspaceModeToggle: View {
    @Binding var mode: WorkspaceModeKind

    var body: some View {
        HStack(spacing: 2) {
            ForEach(WorkspaceModeKind.allCases, id: \.self) { candidate in
                let selected = candidate == mode
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { mode = candidate }
                    WorkspaceModeSelection.select(candidate)
                } label: {
                    Text(candidate == .act ? "Act" : "Work")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(selected ? Color.primary.opacity(0.10) : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Wallpaper

struct WallpaperView: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        ui.wallpaperBackground
            .ignoresSafeArea()
    }
}

private struct LandingGreetingControlsView: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui
        VStack(alignment: .leading, spacing: 14) {
            Text("Greeting")
                .font(.system(size: 14, weight: .semibold))

            Toggle("Animate typewriter", isOn: $ui.landingGreetingTypewriterEnabled)

            Text("Custom greetings and timing live in Settings > Landing.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Setup View
// Full-screen welcome shown after a Reset Everything.
// Minimal: logo, welcome message, "Get Started" to dismiss.

struct SetupView: View {
    @Environment(UIState.self) private var ui

    @State private var overlayOpacity: Double = 0
    @State private var displayText = ""
    @State private var typingDone = false
    @State private var buttonOpacity: Double = 0

    private var theme: EpistemosTheme { ui.theme }
    private let fullText = "Welcome to Epistemos..."
    private var displayFont: Font { AppDisplayTypography.font(size: 38) }

    var body: some View {
        ZStack {
            // Solid background
            theme.resolved.background.color
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Typewriter greeting — app display font, same style as LiquidGreeting
                HStack(alignment: .center, spacing: 0) {
                    Text(displayText)
                        .font(displayFont)
                        .foregroundStyle(theme.fontAccent)
                        .fixedSize(horizontal: true, vertical: true)
                }
                .frame(minHeight: 80)
                .shadow(color: theme.fontAccent.opacity(0.12), radius: 8)

                Spacer()
                    .frame(height: 60)

                // "press me to start" — fades in after typing completes
                Button {
                    withAnimation(Motion.smooth) {
                        UserDefaults.standard.set(true, forKey: "epistemos.setupComplete")
                        ui.needsSetup = false
                    }
                } label: {
                    Text("press me to start")
                        .font(AppDisplayTypography.font(size: 14))
                        .foregroundStyle(theme.fontAccent.opacity(0.7))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(theme.fontAccent.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .opacity(buttonOpacity)

                Spacer()

                // Subtitle at the bottom
                Text("install a local qwen model in Settings to get started")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                    .opacity(buttonOpacity)
                    .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(overlayOpacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.4)) { overlayOpacity = 1 }
        }
        .task {
            // Small initial delay
            try? await Task.sleep(for: .milliseconds(600))

            // Type out the full text — same natural timing as LiquidGreeting
            for i in 1...fullText.count {
                guard !Task.isCancelled else { break }
                displayText = String(fullText.prefix(i))

                let ch = displayText.last ?? " "
                var delay: Double = Double.random(in: 50...80)

                if ".!?".contains(ch) { delay += Double.random(in: 200...400) }
                else if ",;:".contains(ch) { delay += Double.random(in: 80...160) }
                else if ch == " " && Double.random(in: 0...1) < 0.08 { delay += Double.random(in: 60...120) }

                // Natural stutter
                if Double.random(in: 0...1) < 0.10 { delay += Double.random(in: 120...250) }
                if Double.random(in: 0...1) < 0.03 { delay += Double.random(in: 350...600) }

                if i <= 2 { delay += 100 }

                let safeDelay = delay.isFinite ? max(0, delay) : 0
                try? await Task.sleep(for: .milliseconds(Int(safeDelay)))
            }

            // Typing done — fade in the button
            typingDone = true
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeIn(duration: 0.8)) {
                buttonOpacity = 1
            }
        }
    }
}

private struct RootWindowLifecycle: ViewModifier {
    let ui: UIState

    func body(content: Content) -> some View {
        content
            .onAppear {
                updateWindowOcclusion()
                Task { @MainActor in
                    do {
                        try await Task.sleep(for: .milliseconds(150))
                    } catch {
                        return
                    }
                    updateWindowOcclusion()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didMiniaturizeNotification)) { note in
                if let w = note.object as? NSWindow, HomeWindowIdentity.matches(w) {
                    updateWindowOcclusion(window: w)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didDeminiaturizeNotification)) { note in
                if let w = note.object as? NSWindow, HomeWindowIdentity.matches(w) {
                    updateWindowOcclusion(window: w)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
                if let w = note.object as? NSWindow, HomeWindowIdentity.matches(w) {
                    updateWindowOcclusion(window: w)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
                if let w = note.object as? NSWindow, HomeWindowIdentity.matches(w) {
                    updateWindowOcclusion(window: w)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                updateWindowOcclusion()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                updateWindowOcclusion()
            }
    }

    private func updateWindowOcclusion(window: NSWindow? = nil) {
        let homeWindow = window ?? NSApp.windows.first(where: HomeWindowIdentity.matches)
        guard let homeWindow else {
            ui.windowOccluded = true
            return
        }
        ui.windowOccluded = !NSApp.isActive
            || !homeWindow.isVisible
            || homeWindow.isMiniaturized
            || !homeWindow.isKeyWindow
    }
}

private struct RootWorkspaceEvents: ViewModifier {
    @Binding var showWorkspaceSwitcher: Bool
    @Binding var showTimeMachine: Bool
    @Binding var showQuickCapture: Bool

    func body(content: Content) -> some View {
        content
            .overlay { workspaceOverlays }
            .background { workspaceKeyboardShortcuts }
            .onKeyPress(.escape, action: handleEscapeKeyPress)
            .animation(nil, value: showWorkspaceSwitcher)
            .animation(nil, value: showTimeMachine)
            .animation(nil, value: showQuickCapture)
            .onReceive(NotificationCenter.default.publisher(for: .toggleWorkspaceSwitcher)) { _ in
                showWorkspaceSwitcher.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleTimeMachine)) { _ in
                showTimeMachine.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showSaveWorkspacePanel)) { _ in
                QuitSavePanelController.showSave()
            }
    }

    private func handleEscapeKeyPress() -> KeyPress.Result {
        if showQuickCapture { showQuickCapture = false; HomeWindowInputFocus.restoreAfterOverlayDismiss(); return .handled }
        if showWorkspaceSwitcher { showWorkspaceSwitcher = false; return .handled }
        if showTimeMachine { showTimeMachine = false; return .handled }
        return .ignored
    }

    @ViewBuilder
    private var workspaceOverlays: some View {
        if showWorkspaceSwitcher {
            WorkspaceSwitcherOverlay(isPresented: $showWorkspaceSwitcher)
        }
        if showTimeMachine {
            TimeMachineView(isPresented: $showTimeMachine)
        }
        if showQuickCapture {
            QuickCaptureView(isPresented: $showQuickCapture)
        }
    }

    @ViewBuilder
    private var workspaceKeyboardShortcuts: some View {
        Button(action: { showWorkspaceSwitcher.toggle() }) {}
            .keyboardShortcut("w", modifiers: [.command, .control])
            .frame(width: 0, height: 0).opacity(0).allowsHitTesting(false)

        Button(action: { showTimeMachine.toggle() }) {}
            .keyboardShortcut("t", modifiers: [.command, .control])
            .frame(width: 0, height: 0).opacity(0).allowsHitTesting(false)

        Button(action: { QuitSavePanelController.showSave() }) {}
            .keyboardShortcut("s", modifiers: [.command, .control])
            .frame(width: 0, height: 0).opacity(0).allowsHitTesting(false)
    }
}
