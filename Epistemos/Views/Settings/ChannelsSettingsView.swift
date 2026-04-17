import os
import SwiftUI

private let channelsSettingsLogger = Logger(subsystem: "Epistemos", category: "ChannelsSettingsView")

struct ChannelsDetailView: View {
    @Environment(ChannelRegistryState.self) private var registry
    @Environment(IMessageDriverService.self) private var driver
    @Environment(VaultSyncService.self) private var vaultSync
    @State private var senderRoutesChannel: ChannelIdentity?
    @State private var relayHealth: [ChannelIdentity: RelayHealthStatus] = [:]
    @State private var relayChecksInFlight: Set<ChannelIdentity> = []
    @State private var iMessageSetupStatus = IMessageNativeSetupDoctor.currentStatus()
    @State private var isRunningIMessageSetup: Bool = false
    @State private var iMessageSetupMessage: String?

    private let tierOptions = [
        ("chat_lite", "Chat Lite"),
        ("chat_pro", "Chat Pro"),
        ("agent", "Agent"),
    ]

    private let promptModeOptions = [
        ("general", "General"),
        ("code", "Code"),
        ("research", "Research"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                driverCard
                permissionDoctorCard

                ForEach(registry.channels) { channel in
                    channelCard(channel)
                }
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .topLeading)
        }
        .sheet(item: $senderRoutesChannel) { channelID in
            if let vaultPath = vaultSync.vaultURL?.path {
                NavigationStack {
                    ChannelSenderRoutesSheet(
                        channel: registry.configuration(for: channelID),
                        vaultPath: vaultPath
                    )
                }
            } else {
                ContentUnavailableView(
                    "No vault configured",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Attach a vault before managing sender routes.")
                )
            }
        }
        .task {
            await refreshIMessageSetupStatus()
        }
    }

    private var headerCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Channel Registry")
                    .font(.title2.weight(.semibold))

                Text("This is the shared control plane for every agent-facing transport. The background driver pulls from the selected inbound channel, while outbound channels keep their own endpoints, routing defaults, and approval posture without needing another agent-loop change.")
                    .foregroundStyle(.secondary)

                if vaultSync.vaultURL == nil {
                    SettingsDescriptionCard(
                        title: "Vault Required For Background Runs",
                        systemImage: "folder.badge.questionmark",
                        text: "Attach a vault to turn on background channel handling. Outbound channel defaults can still be configured now."
                    )
                } else {
                    SettingsDescriptionCard(
                        title: "Sender Routing",
                        systemImage: "person.crop.square.badge.message",
                        text: "iMessage keeps its flagship contact console in Settings → iMessage Driver. Relay-backed channels now share the same sender-route model directly from this control plane."
                    )
                }
            }
        }
    }

    private var driverCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Background Driver")
                    .font(.headline)

                Toggle("Enable background driver", isOn: Binding(
                    get: { driver.isRunning },
                    set: { enabled in
                        if enabled {
                            driver.start()
                        } else {
                            driver.stop()
                        }
                    }
                ))
                .tint(.blue)

                Picker("Inbound driver channel", selection: Binding(
                    get: { registry.driverChannel },
                    set: { registry.driverChannel = $0 }
                )) {
                    ForEach(registry.driverChannelOptions) { channel in
                        Text(channel.id.title).tag(channel.id)
                    }
                }

                HStack(spacing: 16) {
                    HStack {
                        Text("Poll interval")
                        Spacer()
                        Stepper(
                            "\(driver.pollIntervalSeconds)s",
                            value: Binding(
                                get: { driver.pollIntervalSeconds },
                                set: { driver.pollIntervalSeconds = $0 }
                            ),
                            in: 2...60
                        )
                        .frame(maxWidth: 160)
                    }

                    Button("Poll now") {
                        Task { await driver.tickOnce() }
                    }
                    .disabled(!driver.isRunning)
                }

                HStack(spacing: 12) {
                    ChannelStatusPill(
                        title: driver.isRunning ? "Running" : "Stopped",
                        tint: driver.isRunning ? .green : .secondary
                    )
                    ChannelStatusPill(
                        title: "\(driver.processedCount) processed",
                        tint: .blue
                    )
                    if let lastPollAt = driver.lastPollAt {
                        ChannelStatusPill(
                            title: lastPollAt.formatted(date: .omitted, time: .shortened),
                            tint: .secondary
                        )
                    }
                }

                if let error = presentedDriverError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var permissionDoctorCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(permissionDoctorTitle)
                    .font(.headline)

                if registry.driverChannel == .imessage {
                    HStack(spacing: 12) {
                        ChannelStatusPill(
                            title: iMessageSetupStatus.pollingReady ? "Polling Ready" : "Polling Blocked",
                            tint: iMessageSetupStatus.pollingReady ? Color.green : Color.orange
                        )
                        ChannelStatusPill(
                            title: iMessageSetupStatus.replyReady ? "Replies Ready" : "Replies Blocked",
                            tint: iMessageSetupStatus.replyReady ? Color.green : Color.orange
                        )
                    }

                    if let iMessageSetupMessage {
                        Label(iMessageSetupMessage, systemImage: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if isRunningIMessageSetup {
                        ProgressView("Running native iMessage setup…")
                            .controlSize(.small)
                    }
                }

                ForEach(permissionChecks) { check in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: check.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(check.passed ? Color.green : Color.orange)
                            .font(.caption)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.title)
                                .font(.subheadline.weight(.medium))
                            Text(check.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if registry.driverChannel == .imessage {
                    HStack(spacing: 10) {
                        Button("Run Native Setup") {
                            Task { await runNativeSetup() }
                        }
                        .disabled(isRunningIMessageSetup)

                        Button("Open iMessage Driver") {
                            openIMessageSettings()
                        }

                        Button("Refresh setup status") {
                            Task { await refreshIMessageSetupStatus() }
                        }
                        .disabled(isRunningIMessageSetup)

                        Button("Reveal This Epistemos") {
                            IMessageNativeSetupDoctor.revealCurrentApp()
                        }

                        Button("Relaunch Epistemos") {
                            Task { await IMessageNativeSetupDoctor.relaunchCurrentApp() }
                        }
                    }

                    Text(iMessageSetupStatus.currentAppPath)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    @ViewBuilder
    private func channelCard(_ channel: ChannelConfiguration) -> some View {
        let adapter = registry.makeAdapter(for: channel.id)

        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Label(channel.id.title, systemImage: channel.id.systemImage)
                        .font(.headline)
                    Spacer()
                    ChannelStatusPill(title: channel.pairingState.title, tint: .secondary)
                    ChannelStatusPill(
                        title: channel.supportsInboundDriver ? "Inbound + outbound" : "Outbound",
                        tint: channel.supportsInboundDriver ? .green : .blue
                    )
                }

                SettingsDescriptionText(text: channel.id.pairingSummary)

                Toggle("Enable \(channel.id.title)", isOn: binding(
                    for: channel.id,
                    keyPath: \.isEnabled
                ))
                .tint(.blue)

                Picker("Pairing mode", selection: binding(for: channel.id, keyPath: \.pairingState)) {
                    ForEach(channel.availablePairingStates, id: \.self) { pairingState in
                        Text(pairingState.title).tag(pairingState)
                    }
                }
                .frame(maxWidth: 240)

                if !adapter.capabilities.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(adapter.capabilities) { capability in
                            ChannelStatusPill(title: capability.title, tint: capability == .inboundPolling ? .green : .blue)
                        }
                    }
                }

                LabeledContent("Display name") {
                    TextField(
                        "\(channel.id.title) display name",
                        text: binding(for: channel.id, keyPath: \.displayName)
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
                }

                LabeledContent(channel.id.endpointLabel) {
                    TextField(
                        channel.id.endpointLabel,
                        text: binding(for: channel.id, keyPath: \.threadLocator.defaultRecipient)
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 360)
                }

                if channel.id.requiresSubject {
                    LabeledContent("Default subject") {
                        TextField(
                            "Epistemos Reply",
                            text: binding(for: channel.id, keyPath: \.threadLocator.defaultSubject)
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 280)
                    }
                }

                if channel.supportsInboundDriver {
                    Toggle("Resume background driver at launch when this channel is active", isOn: pairingMetadataBinding(
                        for: channel.id,
                        keyPath: \.keepAliveOnLaunch
                    ))
                    .tint(.blue)
                }

                if channel.pairingState == .remoteRelay {
                    Divider()

                    Text("Remote Relay")
                        .font(.subheadline.weight(.medium))

                    LabeledContent("Relay endpoint") {
                        TextField(
                            "https://relay.example.com",
                            text: pairingMetadataBinding(for: channel.id, keyPath: \.relayEndpoint)
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 360)
                    }

                    LabeledContent("Relay credential") {
                        SecureField(
                            "Bearer token or relay secret",
                            text: pairingMetadataBinding(for: channel.id, keyPath: \.relayCredential)
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                    }

                    LabeledContent("Sender identity") {
                        TextField(
                            "Mac mini upstairs",
                            text: pairingMetadataBinding(for: channel.id, keyPath: \.senderIdentity)
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 260)
                    }

                    HStack(spacing: 10) {
                        Button(relayChecksInFlight.contains(channel.id) ? "Checking…" : "Check relay") {
                            Task { await refreshRelayHealth(for: channel) }
                        }
                        .disabled(relayChecksInFlight.contains(channel.id))

                        if let relayStatus = relayHealth[channel.id] {
                            ChannelStatusPill(
                                title: relayStatus.ok ? "Relay healthy" : "Relay issue",
                                tint: relayStatus.ok ? .green : .orange
                            )
                            if let checkedAt = relayStatus.checkedAt {
                                ChannelStatusPill(
                                    title: checkedAt.formatted(date: .omitted, time: .shortened),
                                    tint: .secondary
                                )
                            }
                        }
                    }

                    if let relayStatus = relayHealth[channel.id] {
                        SettingsDescriptionText(text: relayStatus.detail)
                    }

                    if channel.id == .imessage {
                        Toggle("Fall back to native Messages.app when the relay is unavailable", isOn: pairingMetadataBinding(
                            for: channel.id,
                            keyPath: \.enableNativeFallback
                        ))
                        .tint(.orange)
                    }

                    SettingsDescriptionText(text: relayDescription(for: channel))
                    relayOnboardingView(for: channel)
                }

                Divider()

                Text("Routing Defaults")
                    .font(.subheadline.weight(.medium))

                LabeledContent("Preferred model") {
                    TextField(
                        IMessageDriverService.defaultContactModel,
                        text: binding(for: channel.id, keyPath: \.routingPolicy.preferredModel)
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
                }

                HStack(alignment: .top, spacing: 16) {
                    Picker("Tool tier", selection: binding(for: channel.id, keyPath: \.routingPolicy.toolTier)) {
                        ForEach(tierOptions, id: \.0) { option in
                            Text(option.1).tag(option.0)
                        }
                    }
                    .frame(maxWidth: 220)

                    Picker("Prompt mode", selection: binding(
                        for: channel.id,
                        keyPath: \.routingPolicy.promptMode
                    )) {
                        ForEach(promptModeOptions, id: \.0) { option in
                            Text(option.1).tag(option.0)
                        }
                    }
                    .frame(maxWidth: 220)
                }

                Toggle("Auto-approve writes for this channel's default route", isOn: binding(
                    for: channel.id,
                    keyPath: \.routingPolicy.autoApproveWrites
                ))
                .tint(.orange)

                SettingsDescriptionText(
                    text: "This only auto-approves non-vault modification tools. Sensitive local reads plus vault or workspace writes still require an on-device approval surface."
                )

                TextField(
                    "Notes",
                    text: binding(for: channel.id, keyPath: \.notes),
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

                if channel.id != .imessage {
                    Divider()

                    Text("Sender Overrides")
                        .font(.subheadline.weight(.medium))

                    SettingsDescriptionText(
                        text: channel.supportsInboundDriver
                            ? "Specific senders can override the default model, tool tier, prompt mode, and approval posture for \(channel.id.title). Unmapped senders keep using the routing defaults above."
                            : "Finish relay pairing before turning on per-sender routes for \(channel.id.title). Until then, the channel-level defaults above remain the only route."
                    )

                    Button("Manage sender routes") {
                        senderRoutesChannel = channel.id
                    }
                    .disabled(vaultSync.vaultURL == nil || !channel.supportsInboundDriver)
                }
            }
        }
    }

    private var permissionDoctorTitle: String {
        let configuration = registry.configuration(for: registry.driverChannel)
        if configuration.pairingState == .remoteRelay {
            return "\(configuration.id.title) Relay Doctor"
        }
        return "iMessage Permission Doctor"
    }

    private var permissionChecks: [PermissionCheck] {
        let driverConfiguration = registry.configuration(for: registry.driverChannel)

        var checks = [
            PermissionCheck(
                title: "Vault attached",
                detail: vaultSync.vaultURL == nil
                    ? "Attach a vault before background routing can persist sessions and memories."
                    : "Vault ready at \(vaultSync.vaultURL?.lastPathComponent ?? "vault").",
                passed: vaultSync.vaultURL != nil
            )
        ]

        if driverConfiguration.pairingState == .remoteRelay {
            let relayEndpoint = driverConfiguration.pairingMetadata?.relayEndpoint
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let relayCredential = driverConfiguration.pairingMetadata?.relayCredential
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let senderIdentity = driverConfiguration.pairingMetadata?.senderIdentity
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            checks.append(
                PermissionCheck(
                    title: "Relay endpoint configured",
                    detail: relayEndpoint.isEmpty
                        ? "Set a relay endpoint before using \(driverConfiguration.id.title) as an inbound driver."
                        : "Relay endpoint ready at \(relayEndpoint).",
                    passed: !relayEndpoint.isEmpty
                )
            )
            checks.append(
                PermissionCheck(
                    title: "Relay credential configured",
                    detail: relayCredential.isEmpty
                        ? "Add a bearer token or relay secret so the driver can authenticate."
                        : "Relay credential present.",
                    passed: !relayCredential.isEmpty
                )
            )
            checks.append(
                PermissionCheck(
                    title: "Sender identity set",
                    detail: senderIdentity.isEmpty
                        ? "Set a sender identity so the relay can label this Epistemos node."
                        : "Relay sender identity is \(senderIdentity).",
                    passed: !senderIdentity.isEmpty
                )
            )

            if driverConfiguration.id == .imessage,
               driverConfiguration.pairingMetadata?.enableNativeFallback == true {
                checks.append(
                    PermissionCheck(
                        title: "Messages database accessible",
                        detail: iMessageSetupStatus.databaseAccessible
                            ? "chat.db is available for live sqlite reads, so native fallback can poll locally."
                            : "Native fallback is armed, but macOS is still blocking live Messages database opens.",
                        passed: iMessageSetupStatus.databaseAccessible
                    )
                )
                checks.append(
                    PermissionCheck(
                        title: "Messages automation ready",
                        detail: iMessageSetupStatus.messagesAutomationGranted
                            ? "Messages replies can be sent if the relay drops back to the native bridge."
                            : "Messages replies still need Apple Events approval before native fallback can send.",
                        passed: iMessageSetupStatus.messagesAutomationGranted
                    )
                )
                checks.append(
                    PermissionCheck(
                        title: "Messages app available",
                        detail: iMessageSetupStatus.messagesAppAvailable
                            ? "Messages.app is present for native fallback replies."
                            : "Messages.app was not found at the default system location.",
                        passed: iMessageSetupStatus.messagesAppAvailable
                    )
                )
            }

            return checks
        }

        checks.append(
            PermissionCheck(
                title: "Current Epistemos build",
                detail: iMessageSetupStatus.isDebugBuild
                    ? "The current settings window is running inside a Debug build at \(iMessageSetupStatus.currentAppPath). Full Disk Access must be granted to this exact app copy."
                    : "The current settings window is running inside \(iMessageSetupStatus.currentAppPath).",
                passed: true
            )
        )
        checks.append(
            PermissionCheck(
                title: "Another Epistemos copy is also running",
                detail: iMessageSetupStatus.hasMultipleEpistemosBuildsRunning
                    ? "Multiple Epistemos app copies are open right now:\n\(iMessageSetupStatus.runningEpistemosAppPaths.joined(separator: "\n"))"
                    : "Only this Epistemos app copy is currently running, so privacy changes will apply cleanly once it relaunches.",
                passed: !iMessageSetupStatus.hasMultipleEpistemosBuildsRunning
            )
        )
        checks.append(
            PermissionCheck(
                title: "Messages database accessible",
                detail: iMessageSetupStatus.databaseAccessible
                    ? "chat.db is available for live sqlite reads, so the native iMessage poller can see incoming threads."
                    : "chat.db exists, but macOS is still blocking live database opens until Full Disk Access is granted to this exact app copy and it is relaunched.",
                passed: iMessageSetupStatus.databaseAccessible
            )
        )
        checks.append(
            PermissionCheck(
                title: "Messages automation ready",
                detail: iMessageSetupStatus.messagesAutomationGranted
                    ? "Messages replies can be delivered because Apple Events access is already granted."
                    : "Replies are still blocked. Run Native Setup to trigger the Messages automation consent flow.",
                passed: iMessageSetupStatus.messagesAutomationGranted
            )
        )
        checks.append(
            PermissionCheck(
                title: "Messages app available",
                detail: iMessageSetupStatus.messagesAppAvailable
                    ? "Messages.app is present for reply delivery."
                    : "Messages.app was not found at the default system location.",
                passed: iMessageSetupStatus.messagesAppAvailable
            )
        )
        return checks
    }

    private var presentedDriverError: String? {
        if registry.driverChannel == .imessage {
            return IMessageNativeSetupDoctor.presentedDriverError(driver.lastError, status: iMessageSetupStatus)
        }
        guard let error = driver.lastError?.trimmingCharacters(in: .whitespacesAndNewlines),
              !error.isEmpty else {
            return nil
        }
        return error
    }

    private func refreshIMessageSetupStatus() async {
        iMessageSetupStatus = IMessageNativeSetupDoctor.currentStatus()
        if iMessageSetupStatus.nativeBridgeReady {
            iMessageSetupMessage = "Native Messages bridge looks ready."
        } else if iMessageSetupStatus.databaseAccessible {
            iMessageSetupMessage = "Polling is ready. Replies still need the Messages automation approval."
        } else if iMessageSetupStatus.hasMultipleEpistemosBuildsRunning {
            iMessageSetupMessage = "Another Epistemos copy is also running. Grant Full Disk Access to the current build shown here, then relaunch that same copy."
        } else if iMessageSetupStatus.isDebugBuild {
            iMessageSetupMessage = "This Debug build still cannot read chat.db. Grant Full Disk Access to this exact app copy, then relaunch it."
        } else {
            iMessageSetupMessage = "Full Disk Access is still the main blocker for native polling."
        }
    }

    private func runNativeSetup() async {
        isRunningIMessageSetup = true
        iMessageSetupMessage = "Opening Messages and the required privacy panes…"
        defer { isRunningIMessageSetup = false }

        iMessageSetupStatus = await IMessageNativeSetupDoctor.runGuidedSetup()

        if iMessageSetupStatus.databaseAccessible {
            if !driver.isRunning {
                driver.start()
            }
            await driver.tickOnce()
        }

        if iMessageSetupStatus.nativeBridgeReady {
            iMessageSetupMessage = "Native setup finished and the iMessage driver ran a fresh poll."
        } else if iMessageSetupStatus.databaseAccessible {
            iMessageSetupMessage = "Native polling is ready now. One Messages automation approval may still be needed for replies."
        } else if iMessageSetupStatus.hasMultipleEpistemosBuildsRunning {
            iMessageSetupMessage = "System Settings opened, but another Epistemos copy is also running. Grant access to the current build shown here, then relaunch that same copy."
        } else if iMessageSetupStatus.isDebugBuild {
            iMessageSetupMessage = "System Settings opened for Full Disk Access. Grant access to this Debug app copy, then relaunch it before polling again."
        } else {
            iMessageSetupMessage = "System Settings opened for Full Disk Access. After granting access to this Epistemos build, relaunch it, then come back here and press Refresh setup status."
        }
    }

    private func openIMessageSettings() {
        NotificationCenter.default.post(name: .showIMessageDriverSettings, object: nil)
    }

    private func relayDescription(for channel: ChannelConfiguration) -> String {
        if channel.id == .imessage {
            return "Remote relay is live now for iMessage. Native chat.db + Messages.app remains the flagship path, and native fallback can stay armed if you want resilience."
        }
        return "Remote relay upgrades \(channel.id.title) into a full inbound adapter with unread polling, thread continuity, and audit surfaces, all without another agent-loop change."
    }

    @ViewBuilder
    private func relayOnboardingView(for channel: ChannelConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Relay Ops")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(relayOpsSummary(for: channel))
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Server")
                    .font(.caption.weight(.medium))
                Text(serverCommand(for: channel))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }

            if channel.id != .imessage {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Worker")
                        .font(.caption.weight(.medium))
                    Text(workerCommand(for: channel))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                Text("Worker env: \(relayWorkerEnvironmentSummary(for: channel.id))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func relayOpsSummary(for channel: ChannelConfiguration) -> String {
        if channel.id == .imessage {
            return "Use the relay server plus your native iMessage bridge or BlueBubbles-style gateway. External connector workers are only needed for the non-iMessage channels."
        }
        return "Run the relay server anywhere your connector can reach it, then keep one worker alive per paired channel so pending outbox messages drain continuously."
    }

    private func serverCommand(for channel: ChannelConfiguration) -> String {
        let endpoint = channel.pairingMetadata?.relayEndpoint
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let token = channel.pairingMetadata?.relayCredential
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let tokenFlag = token?.isEmpty == false ? " --token \"$EPISTEMOS_CHANNEL_RELAY_TOKEN\"" : ""
        let listenHint: String
        if let endpoint, let url = URL(string: endpoint), let host = url.host, let port = url.port {
            listenHint = "--listen \(host):\(port)"
        } else {
            listenHint = "--listen 0.0.0.0:8787"
        }
        return "epistemos_channel_relay \(listenHint)\(tokenFlag)"
    }

    private func workerCommand(for channel: ChannelConfiguration) -> String {
        let endpoint = channel.pairingMetadata?.relayEndpoint
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let relayFlag: String
        if let endpoint, !endpoint.isEmpty {
            relayFlag = " --relay \(endpoint)"
        } else {
            relayFlag = ""
        }
        let tokenFlag = channel.pairingMetadata?.relayCredential
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false ? " --token \"$EPISTEMOS_CHANNEL_RELAY_TOKEN\"" : ""
        return "epistemos_channel_worker --channel \(channel.id.rawValue)\(relayFlag)\(tokenFlag)"
    }

    private func relayWorkerEnvironmentSummary(for channelID: ChannelIdentity) -> String {
        switch channelID {
        case .imessage:
            return "No generic worker. Use the native bridge or your remote iMessage gateway."
        case .telegram:
            return "TELEGRAM_BOT_TOKEN"
        case .slack:
            return "No extra env if the webhook URL is stored in the channel route."
        case .discord:
            return "No extra env if the webhook URL is stored in the channel route."
        case .whatsapp:
            return "WHATSAPP_ACCESS_TOKEN, WHATSAPP_PHONE_NUMBER_ID, optional WHATSAPP_API_VERSION"
        case .signal:
            return "SIGNAL_CLI_BASE_URL, SIGNAL_ACCOUNT"
        case .email:
            return "SMTP_HOST, SMTP_USERNAME, SMTP_PASSWORD, SMTP_FROM, optional SMTP_PORT"
        }
    }

    private func refreshRelayHealth(for channel: ChannelConfiguration) async {
        guard let relay = channel.relayConfiguration else {
            relayHealth[channel.id] = RelayHealthStatus(
                ok: false,
                detail: "Configure a relay endpoint before running health checks.",
                checkedAt: Date()
            )
            return
        }

        relayChecksInFlight.insert(channel.id)
        defer { relayChecksInFlight.remove(channel.id) }

        do {
            var url = relay.endpoint
            url.appendPathComponent("healthz")

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if !relay.credential.isEmpty {
                request.setValue("Bearer \(relay.credential)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RelayHealthFailure.invalidResponse
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let reason = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                throw RelayHealthFailure.httpStatus(httpResponse.statusCode, reason ?? "unknown")
            }

            let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let pendingOutbox = (payload?["pending_outbox"] as? NSNumber)?.intValue ?? 0
            let threads = (payload?["threads"] as? NSNumber)?.intValue ?? 0
            relayHealth[channel.id] = RelayHealthStatus(
                ok: true,
                detail: "Healthy. \(threads) threads tracked, \(pendingOutbox) pending outbox item(s).",
                checkedAt: Date()
            )
        } catch let error as RelayHealthFailure {
            relayHealth[channel.id] = RelayHealthStatus(
                ok: false,
                detail: error.localizedDescription,
                checkedAt: Date()
            )
        } catch {
            relayHealth[channel.id] = RelayHealthStatus(
                ok: false,
                detail: "Relay check failed: \(error.localizedDescription)",
                checkedAt: Date()
            )
        }
    }

    private func binding<Value>(
        for channelID: ChannelIdentity,
        keyPath: WritableKeyPath<ChannelConfiguration, Value>
    ) -> Binding<Value> {
        Binding(
            get: { registry.configuration(for: channelID)[keyPath: keyPath] },
            set: { newValue in
                registry.update(channelID) { configuration in
                    configuration[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func pairingMetadataBinding<Value>(
        for channelID: ChannelIdentity,
        keyPath: WritableKeyPath<ChannelPairingMetadata, Value>
    ) -> Binding<Value> {
        Binding(
            get: {
                let metadata = registry.configuration(for: channelID).pairingMetadata ?? ChannelPairingMetadata()
                return metadata[keyPath: keyPath]
            },
            set: { newValue in
                registry.update(channelID) { configuration in
                    var metadata = configuration.pairingMetadata ?? ChannelPairingMetadata()
                    metadata[keyPath: keyPath] = newValue
                    configuration.pairingMetadata = metadata
                }
            }
        )
    }
}

private struct PermissionCheck: Identifiable {
    let title: String
    let detail: String
    let passed: Bool

    var id: String { title }
}

private struct RelayHealthStatus {
    let ok: Bool
    let detail: String
    let checkedAt: Date?
}

private enum RelayHealthFailure: LocalizedError {
    case invalidResponse
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Relay check failed because the endpoint did not return an HTTP response."
        case let .httpStatus(status, reason):
            return "Relay returned HTTP \(status): \(reason)"
        }
    }
}

private struct ChannelSenderRoutesSheet: View {
    @Environment(ChannelRegistryState.self) private var registry

    let channel: ChannelConfiguration
    let vaultPath: String

    @State private var routes: [ChannelRouteContact] = []
    @State private var recentThreads: [DriverChannelThreadSummary] = []
    @State private var recentAuditEntries: [DriverChannelAuditEntry] = []
    @State private var isLoading: Bool = false
    @State private var showAddSheet: Bool = false
    @State private var editingRoute: ChannelRouteContact?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    ChannelStatusPill(title: channel.pairingState.title, tint: .blue)
                    ChannelStatusPill(title: "\(routes.count) routes", tint: .secondary)
                    ChannelStatusPill(title: "\(routes.filter(\.autoReply).count) auto-reply", tint: .green)
                    ChannelStatusPill(title: "\(routes.filter(\.autoApprove).count) trusted", tint: .orange)
                }

                if recentThreads.isEmpty {
                    Text("No recent \(channel.id.title) threads are available yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(mappedRecentThreadCount) of the last \(recentThreads.count) threads already map to a specific sender override.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("\(channel.id.title) Sender Control")
            } footer: {
                Text("Relay-backed channels now use the same sender-route model as iMessage. Specific senders override the channel defaults; everyone else falls back to the default route.")
                    .font(.caption)
            }

            Section {
                if routes.isEmpty {
                    Text("No sender routes configured yet.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(routes) { route in
                        Button {
                            editingRoute = route
                        } label: {
                            DriverRouteRow(contact: route)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteRoutes)
                }

                Button {
                    showAddSheet = true
                } label: {
                    Label("Add sender route", systemImage: "plus.circle")
                }
            } header: {
                HStack {
                    Text("Routes")
                    Spacer()
                    if isLoading {
                        ProgressView().controlSize(.small)
                    }
                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("Refresh")
                }
            }

            Section {
                if recentThreads.isEmpty {
                    Text("No recent threads available.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(recentThreads) { thread in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(thread.title)
                                        .font(.headline)
                                    if !thread.subtitle.isEmpty {
                                        Text(thread.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                ChannelStatusPill(
                                    title: isConfiguredThread(thread) ? "Mapped" : "Default Route",
                                    tint: isConfiguredThread(thread) ? .green : .orange
                                )
                            }

                            if thread.lastActivityUnix > 0 {
                                Text(Date(timeIntervalSince1970: TimeInterval(thread.lastActivityUnix)), style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            } header: {
                Text("Recent Threads")
            }

            Section {
                if recentAuditEntries.isEmpty {
                    Text("No recent relay audit entries available.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(recentAuditEntries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.senderID)
                                        .font(.subheadline.weight(.semibold))
                                    Text(entry.preview)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                ChannelStatusPill(
                                    title: entry.isFromMe ? "Outgoing" : "Incoming",
                                    tint: entry.isFromMe ? .blue : .green
                                )
                            }

                            if entry.unix > 0 {
                                Text(Date(timeIntervalSince1970: TimeInterval(entry.unix)), style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            } header: {
                Text("Recent Audit")
            }

            if let errorMessage, !errorMessage.isEmpty {
                Section("Channel status") {
                    Label("Sender routes couldn't load", systemImage: "antenna.radiowaves.left.and.right.slash")
                        .foregroundStyle(.orange)
                        .font(.caption.weight(.semibold))
                    Text("The driver may not be paired yet, or the vault path above is unreachable. Re-pair this channel in Settings → Drivers and try again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DisclosureGroup("Raw error") {
                        Text(errorMessage)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("\(channel.id.title) Sender Routes")
        .sheet(isPresented: $showAddSheet) {
            DriverRouteEditorSheet(
                channelID: channel.id,
                contact: nil,
                vaultPath: vaultPath,
                onSaved: {
                    showAddSheet = false
                    Task { await refresh() }
                },
                onCancelled: { showAddSheet = false }
            )
        }
        .sheet(item: $editingRoute) { route in
            DriverRouteEditorSheet(
                channelID: channel.id,
                contact: route,
                vaultPath: vaultPath,
                onSaved: {
                    editingRoute = nil
                    Task { await refresh() }
                },
                onCancelled: { editingRoute = nil }
            )
        }
        .task {
            await refresh()
        }
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            routes = try await ChannelContactsStore.list(channelID: channel.id, vaultPath: vaultPath)
            let adapter = registry.makeAdapter(for: channel.id)
            recentThreads = try await adapter.listThreads(vaultPath: vaultPath, limit: 8)
            recentAuditEntries = try await adapter.recentAuditEntries(vaultPath: vaultPath, limit: 8)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteRoutes(at offsets: IndexSet) {
        let doomed = offsets.map { routes[$0] }
        Task {
            for route in doomed {
                do {
                    try await ChannelContactsStore.remove(
                        channelID: channel.id,
                        handle: route.handle,
                        vaultPath: vaultPath
                    )
                } catch {
                    channelsSettingsLogger.error("Failed to remove channel route \(route.handle, privacy: .public) for \(channel.id.title, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
            await refresh()
        }
    }

    private var mappedRecentThreadCount: Int {
        recentThreads.filter(isConfiguredThread).count
    }

    private func isConfiguredThread(_ thread: DriverChannelThreadSummary) -> Bool {
        routes.contains { route in
            route.handle == thread.subtitle
                || route.handle == thread.title
                || route.handle == thread.conversationID
        }
    }
}
