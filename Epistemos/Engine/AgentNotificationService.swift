import Foundation
import UserNotifications
import os

// MARK: - Agent Notification Service
// Three channels: macOS notification center, in-app badges, voice (via VoiceEngine).
// Per-agent notification settings with category toggles.

@MainActor @Observable
final class AgentNotificationService {

    // MARK: - Notification Category

    enum Category: String, Sendable, CaseIterable {
        case taskComplete
        case error
        case needsApproval
        case proactiveInsight
        case connectionFound
    }

    // MARK: - Agent Notification Config

    struct NotificationConfig: Sendable {
        var macOSEnabled = true
        var inAppEnabled = true
        var voiceEnabled = false
        var enabledCategories: Set<Category> = Set(Category.allCases)
    }

    // MARK: - State

    private(set) var configs: [AgentID: NotificationConfig] = [:]
    private(set) var badges: [AgentID: Int] = [:]
    private(set) var isAuthorized = false

    init() {
        for agent in AgentID.allCases {
            configs[agent] = NotificationConfig()
            badges[agent] = 0
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            Log.engine.info("AgentNotificationService: authorization \(granted ? "granted" : "denied")")
        } catch {
            Log.engine.error("AgentNotificationService: authorization failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Send Notification

    func notify(
        agent: AgentID,
        category: Category,
        title: String,
        body: String,
        voiceEngine: VoiceEngine? = nil
    ) async {
        guard let config = configs[agent] else { return }
        guard config.enabledCategories.contains(category) else { return }

        // Channel 1: macOS notification center
        if config.macOSEnabled && isAuthorized {
            let content = UNMutableNotificationContent()
            content.title = "\(agent.displayName): \(title)"
            content.body = body
            content.sound = .default
            content.categoryIdentifier = "agent.\(agent.rawValue).\(category.rawValue)"

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )

            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                Log.engine.error("AgentNotificationService: failed to deliver notification: \(error.localizedDescription)")
            }
        }

        // Channel 2: In-app badge
        if config.inAppEnabled {
            badges[agent, default: 0] += 1
        }

        // Channel 3: Voice (Chatterbox TTS)
        if config.voiceEnabled, let voiceEngine, voiceEngine.isReady {
            await voiceEngine.speak("\(title). \(body)", as: agent)
        }
    }

    // MARK: - Badge Management

    func clearBadge(for agent: AgentID) {
        badges[agent] = 0
    }

    func clearAllBadges() {
        for agent in AgentID.allCases {
            badges[agent] = 0
        }
    }

    func totalBadgeCount() -> Int {
        badges.values.reduce(0, +)
    }

    // MARK: - Config

    func setMacOSEnabled(_ enabled: Bool, for agent: AgentID) {
        configs[agent]?.macOSEnabled = enabled
    }

    func setInAppEnabled(_ enabled: Bool, for agent: AgentID) {
        configs[agent]?.inAppEnabled = enabled
    }

    func setVoiceEnabled(_ enabled: Bool, for agent: AgentID) {
        configs[agent]?.voiceEnabled = enabled
    }

    func setCategoryEnabled(_ category: Category, enabled: Bool, for agent: AgentID) {
        if enabled {
            configs[agent]?.enabledCategories.insert(category)
        } else {
            configs[agent]?.enabledCategories.remove(category)
        }
    }
}
