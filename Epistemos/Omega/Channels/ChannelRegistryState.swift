import Foundation
import Observation
import os

nonisolated enum ChannelIdentity: String, CaseIterable, Codable, Identifiable, Sendable {
    case imessage
    case telegram
    case slack
    case discord
    case whatsapp
    case signal
    case email

    var id: String { rawValue }

    var title: String {
        switch self {
        case .imessage: "iMessage"
        case .telegram: "Telegram"
        case .slack: "Slack"
        case .discord: "Discord"
        case .whatsapp: "WhatsApp"
        case .signal: "Signal"
        case .email: "Email"
        }
    }

    var systemImage: String {
        switch self {
        case .imessage: "message.badge.fill"
        case .telegram: "paperplane.fill"
        case .slack: "number.square.fill"
        case .discord: "bubble.left.and.bubble.right.fill"
        case .whatsapp: "phone.badge.waveform.fill"
        case .signal: "dot.radiowaves.left.and.right"
        case .email: "envelope.fill"
        }
    }

    var endpointLabel: String {
        switch self {
        case .imessage: "Default recipient"
        case .telegram: "Default chat ID"
        case .slack: "Webhook URL"
        case .discord: "Webhook URL"
        case .whatsapp: "Phone number"
        case .signal: "Recipient"
        case .email: "Recipient email"
        }
    }

    var pairingSummary: String {
        switch self {
        case .imessage: "Native Messages.app bridge"
        case .telegram: "Direct send or relay-backed inbox"
        case .slack: "Webhook send or relay-backed inbox"
        case .discord: "Webhook send or relay-backed inbox"
        case .whatsapp: "Direct send or relay-backed inbox"
        case .signal: "Direct send or relay-backed inbox"
        case .email: "Mail send or relay-backed inbox"
        }
    }

    var supportsInboundDriver: Bool {
        switch self {
        case .imessage:
            true
        case .telegram, .slack, .discord, .whatsapp, .signal, .email:
            false
        }
    }

    var requiresSubject: Bool {
        self == .email
    }

    var senderRouteLabel: String {
        switch self {
        case .imessage: "Handle (phone, email, chat id)"
        case .telegram: "Sender handle or chat id"
        case .slack: "Slack user id or email"
        case .discord: "Discord user id or handle"
        case .whatsapp: "Phone number"
        case .signal: "Signal number or recipient"
        case .email: "Sender email"
        }
    }

    var senderRoutePlaceholder: String {
        switch self {
        case .imessage: "+15551234567"
        case .telegram: "@alice"
        case .slack: "U12345678"
        case .discord: "alice#0420"
        case .whatsapp: "+15551234567"
        case .signal: "+15551234567"
        case .email: "alice@example.com"
        }
    }
}

nonisolated enum ChannelPairingState: String, CaseIterable, Codable, Sendable {
    case nativeLocal
    case direct
    case webhook
    case remoteRelay

    var title: String {
        switch self {
        case .nativeLocal: "Native"
        case .direct: "Direct"
        case .webhook: "Webhook"
        case .remoteRelay: "Remote Relay"
        }
    }
}

nonisolated struct ChannelPairingMetadata: Codable, Hashable, Sendable {
    var relayEndpoint: String
    var relayCredential: String
    var senderIdentity: String
    var enableNativeFallback: Bool
    var keepAliveOnLaunch: Bool

    init(
        relayEndpoint: String = "",
        relayCredential: String = "",
        senderIdentity: String = "",
        enableNativeFallback: Bool = true,
        keepAliveOnLaunch: Bool = false
    ) {
        self.relayEndpoint = relayEndpoint
        self.relayCredential = relayCredential
        self.senderIdentity = senderIdentity
        self.enableNativeFallback = enableNativeFallback
        self.keepAliveOnLaunch = keepAliveOnLaunch
    }
}

nonisolated struct ChannelThreadLocator: Codable, Hashable, Sendable {
    var defaultRecipient: String
    var defaultSubject: String

    init(defaultRecipient: String = "", defaultSubject: String = "") {
        self.defaultRecipient = defaultRecipient
        self.defaultSubject = defaultSubject
    }
}

nonisolated struct ChannelRoutingPolicy: Codable, Hashable, Sendable {
    var preferredModel: String
    var toolTier: String
    var promptMode: String
    var autoApproveWrites: Bool

    init(
        preferredModel: String = IMessageDriverService.defaultContactModel,
        toolTier: String = "chat_pro",
        promptMode: String = "general",
        autoApproveWrites: Bool = false
    ) {
        self.preferredModel = preferredModel
        self.toolTier = toolTier
        self.promptMode = promptMode
        self.autoApproveWrites = autoApproveWrites
    }
}

nonisolated struct ChannelConfiguration: Codable, Hashable, Identifiable, Sendable {
    let id: ChannelIdentity
    var isEnabled: Bool
    var displayName: String
    var pairingState: ChannelPairingState
    var pairingMetadata: ChannelPairingMetadata?
    var threadLocator: ChannelThreadLocator
    var routingPolicy: ChannelRoutingPolicy
    var notes: String

    var supportsInboundDriver: Bool {
        id.supportsInboundDriver || relayConfiguration != nil
    }

    var availablePairingStates: [ChannelPairingState] {
        switch id {
        case .imessage:
            [.nativeLocal, .remoteRelay]
        case .telegram, .whatsapp, .signal, .email:
            [.direct, .remoteRelay]
        case .slack, .discord:
            [.webhook, .remoteRelay]
        }
    }

    var relayConfiguration: ChannelRelayConfiguration? {
        guard pairingState == .remoteRelay else {
            return nil
        }
        return ChannelRelayConfiguration(metadata: pairingMetadata)
    }
}

private nonisolated struct ChannelRegistrySnapshot: Codable, Sendable {
    var driverChannel: ChannelIdentity
    var channels: [ChannelConfiguration]
}

@MainActor @Observable
final class ChannelRegistryState {
    private static let storageKey = "epistemos.channelRegistry.v1"
    private let logger = Logger(subsystem: "com.epistemos", category: "ChannelRegistry")

    var driverChannel: ChannelIdentity {
        didSet { persist() }
    }

    var channels: [ChannelConfiguration] {
        didSet { persist() }
    }

    private(set) var lastFallbackEvent: DriverChannelFallbackEvent?

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let snapshot = Self.loadSnapshot(from: userDefaults) {
            self.driverChannel = snapshot.driverChannel
            self.channels = Self.mergedWithDefaults(snapshot.channels)
        } else {
            self.driverChannel = .imessage
            self.channels = Self.defaultChannels()
        }
    }

    var driverChannelOptions: [ChannelConfiguration] {
        channels.filter(\.supportsInboundDriver)
    }

    func configuration(for channelID: ChannelIdentity) -> ChannelConfiguration {
        channels.first(where: { $0.id == channelID }) ?? Self.defaultConfiguration(for: channelID)
    }

    func update(_ channelID: ChannelIdentity, mutate: (inout ChannelConfiguration) -> Void) {
        var updated = configuration(for: channelID)
        mutate(&updated)
        if let index = channels.firstIndex(where: { $0.id == channelID }) {
            channels[index] = updated
        } else {
            channels.append(updated)
            channels.sort { $0.id.rawValue < $1.id.rawValue }
        }
    }

    func makeDriverAdapter() -> any DriverChannelAdapting {
        makeAdapter(for: driverChannel)
    }

    func makeAdapter(for channelID: ChannelIdentity) -> any DriverChannelAdapting {
        let configuration = configuration(for: channelID)
        if let relayConfiguration = configuration.relayConfiguration {
            let relayAdapter = RemoteRelayChannelAdapter(
                channelID: channelID.rawValue,
                displayName: configuration.displayName,
                relay: relayConfiguration,
                deliveryMetadata: relayDeliveryMetadata(for: configuration)
            )
            if channelID == .imessage,
               configuration.pairingMetadata?.enableNativeFallback == true {
                return FallbackDriverChannelAdapter(
                    primary: relayAdapter,
                    fallback: IMessageChannelAdapter(),
                    onFallback: { [weak self] event in
                        Task { @MainActor [weak self] in
                            self?.recordFallbackEvent(event)
                        }
                    }
                )
            }
            return relayAdapter
        }
        switch channelID {
        case .imessage:
            return IMessageChannelAdapter()
        case .telegram:
            return TelegramChannelAdapter(chatID: configuration.threadLocator.defaultRecipient)
        case .slack:
            return SlackChannelAdapter(webhookURL: configuration.threadLocator.defaultRecipient)
        case .discord:
            return DiscordChannelAdapter(webhookURL: configuration.threadLocator.defaultRecipient)
        case .whatsapp:
            return WhatsAppChannelAdapter(phoneNumber: configuration.threadLocator.defaultRecipient)
        case .signal:
            return SignalChannelAdapter(recipient: configuration.threadLocator.defaultRecipient)
        case .email:
            return EmailChannelAdapter(
                subject: resolvedEmailSubject(for: configuration),
                recipientEmail: configuration.threadLocator.defaultRecipient
            )
        }
    }

    private func recordFallbackEvent(_ event: DriverChannelFallbackEvent) {
        lastFallbackEvent = event
        logger.notice(
            "Channel fallback activated for \(event.channelID, privacy: .public) op=\(event.operation.rawValue, privacy: .public) primary=\(event.primaryDisplayName, privacy: .public) fallback=\(event.fallbackDisplayName, privacy: .public) reason=\(event.errorDescription, privacy: .public)"
        )
    }

    func makeSendToolCall(
        for channelID: ChannelIdentity,
        message: String,
        recipientOverride: String = ""
    ) throws -> DriverChannelToolCall {
        let configuration = configuration(for: channelID)
        switch channelID {
        case .imessage:
            return try IMessageChannelAdapter().makeSendToolCall(
                message: message,
                recipientID: recipientOverride
            )
        case .telegram:
            return try TelegramChannelAdapter(chatID: configuration.threadLocator.defaultRecipient)
                .makeSendToolCall(message: message, recipientID: recipientOverride)
        case .slack:
            return try SlackChannelAdapter(webhookURL: configuration.threadLocator.defaultRecipient)
                .makeSendToolCall(message: message, recipientID: recipientOverride)
        case .discord:
            return try DiscordChannelAdapter(webhookURL: configuration.threadLocator.defaultRecipient)
                .makeSendToolCall(message: message, recipientID: recipientOverride)
        case .whatsapp:
            return try WhatsAppChannelAdapter(phoneNumber: configuration.threadLocator.defaultRecipient)
                .makeSendToolCall(message: message, recipientID: recipientOverride)
        case .signal:
            return try SignalChannelAdapter(recipient: configuration.threadLocator.defaultRecipient)
                .makeSendToolCall(message: message, recipientID: recipientOverride)
        case .email:
            return try EmailChannelAdapter(
                subject: resolvedEmailSubject(for: configuration),
                recipientEmail: configuration.threadLocator.defaultRecipient
            )
            .makeSendToolCall(message: message, recipientID: recipientOverride)
        }
    }

    private func persist() {
        let snapshot = ChannelRegistrySnapshot(
            driverChannel: driverChannel,
            channels: channels
        )
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        userDefaults.set(data, forKey: Self.storageKey)
    }

    private func resolvedEmailSubject(for configuration: ChannelConfiguration) -> String {
        let subject = configuration.threadLocator.defaultSubject
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return subject.isEmpty ? "Epistemos Reply" : subject
    }

    private func relayDeliveryMetadata(for configuration: ChannelConfiguration) -> [String: String] {
        var metadata: [String: String] = [:]
        if let displayTarget = resolvedRelayDisplayTarget(for: configuration) {
            metadata["display_target"] = displayTarget
        }
        if configuration.id == .email {
            metadata["subject"] = resolvedEmailSubject(for: configuration)
        }
        return metadata
    }

    private func resolvedRelayDisplayTarget(for configuration: ChannelConfiguration) -> String? {
        let displayName = configuration.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayName.isEmpty else {
            return nil
        }
        if configuration.id == .slack || configuration.id == .discord {
            return displayName
        }
        return displayName.caseInsensitiveCompare(configuration.id.title) == .orderedSame
            ? nil
            : displayName
    }

    private static func loadSnapshot(from userDefaults: UserDefaults) -> ChannelRegistrySnapshot? {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(ChannelRegistrySnapshot.self, from: data)
    }

    private static func mergedWithDefaults(_ storedChannels: [ChannelConfiguration]) -> [ChannelConfiguration] {
        return ChannelIdentity.allCases.map { channelID in
            if let stored = storedChannels.first(where: { $0.id == channelID }) {
                return stored
            }
            return defaultConfiguration(for: channelID)
        }
    }

    private static func defaultChannels() -> [ChannelConfiguration] {
        ChannelIdentity.allCases.map(defaultConfiguration(for:))
    }

    private static func defaultConfiguration(for channelID: ChannelIdentity) -> ChannelConfiguration {
        switch channelID {
        case .imessage:
            ChannelConfiguration(
                id: .imessage,
                isEnabled: true,
                displayName: "Messages.app",
                pairingState: .nativeLocal,
                pairingMetadata: ChannelPairingMetadata(
                    relayEndpoint: "",
                    relayCredential: "",
                    senderIdentity: "",
                    enableNativeFallback: true,
                    keepAliveOnLaunch: false
                ),
                threadLocator: ChannelThreadLocator(),
                routingPolicy: ChannelRoutingPolicy(),
                notes: "Reads chat.db locally and replies via Messages.app automation."
            )
        case .telegram:
            ChannelConfiguration(
                id: .telegram,
                isEnabled: false,
                displayName: "Telegram",
                pairingState: .direct,
                pairingMetadata: ChannelPairingMetadata(),
                threadLocator: ChannelThreadLocator(),
                routingPolicy: ChannelRoutingPolicy(),
                notes: "Direct bot delivery is ready now. Remote relay pairing upgrades Telegram into a full inbound driver."
            )
        case .slack:
            ChannelConfiguration(
                id: .slack,
                isEnabled: false,
                displayName: "Slack",
                pairingState: .webhook,
                pairingMetadata: ChannelPairingMetadata(),
                threadLocator: ChannelThreadLocator(),
                routingPolicy: ChannelRoutingPolicy(),
                notes: "Webhook delivery handles outbound alerts today. Remote relay pairing adds inbox polling and thread continuity."
            )
        case .discord:
            ChannelConfiguration(
                id: .discord,
                isEnabled: false,
                displayName: "Discord",
                pairingState: .webhook,
                pairingMetadata: ChannelPairingMetadata(),
                threadLocator: ChannelThreadLocator(),
                routingPolicy: ChannelRoutingPolicy(),
                notes: "Webhook delivery is ready for replies. Remote relay pairing makes Discord usable as an inbound operator channel."
            )
        case .whatsapp:
            ChannelConfiguration(
                id: .whatsapp,
                isEnabled: false,
                displayName: "WhatsApp",
                pairingState: .direct,
                pairingMetadata: ChannelPairingMetadata(),
                threadLocator: ChannelThreadLocator(),
                routingPolicy: ChannelRoutingPolicy(),
                notes: "Direct target routing is ready once provider credentials are in place. Remote relay pairing adds unread polling."
            )
        case .signal:
            ChannelConfiguration(
                id: .signal,
                isEnabled: false,
                displayName: "Signal",
                pairingState: .direct,
                pairingMetadata: ChannelPairingMetadata(),
                threadLocator: ChannelThreadLocator(),
                routingPolicy: ChannelRoutingPolicy(),
                notes: "Trusted outbound flows are ready now. Remote relay pairing brings Signal into the inbound control plane."
            )
        case .email:
            ChannelConfiguration(
                id: .email,
                isEnabled: false,
                displayName: "Email",
                pairingState: .direct,
                pairingMetadata: ChannelPairingMetadata(),
                threadLocator: ChannelThreadLocator(defaultRecipient: "", defaultSubject: "Epistemos Reply"),
                routingPolicy: ChannelRoutingPolicy(),
                notes: "Best for digests and approvals. Remote relay pairing lets email participate in the shared inbox loop."
            )
        }
    }
}
