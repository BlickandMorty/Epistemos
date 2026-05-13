import SwiftUI

// MARK: - RuntimeTruthHealthRow
//
// RCA-P1-004 + RCA-P1-005 + RCA-P1-017 + RCA13-P1-002 unified view
// (2026-05-13): single Diagnostics row that shows the user
// "what's actually running right now?" — the source-of-truth view
// the audit register flagged as the load-bearing CLI/tool-truth gap.
//
// Surfaces five honest signals:
//
//   1. **Operating mode**   — Fast / Thinking / Pro / Agent
//      (`EpistemosOperatingMode`). Driven by the user's selector.
//   2. **Active provider**  — Local Qwen / Cloud Claude / Cloud GPT / etc.
//      from `InferenceState.preferredChatModelSelection`.
//   3. **Tool-loop route**  — Direct stream / Rust managed agent / Local
//      pipeline. Maps to whether the turn will invoke tools at all.
//   4. **Capability tier**  — the chat-bubble pill view of "what can
//      this turn do?" (`ChatCapability` enum).
//   5. **CLI presence**     — Pro-only. Linked to CLIDiscoveryHealthRow
//      so users see at a glance which CLI passthroughs are available.
//
// Doctrine: before this row landed, the user had no way to distinguish
// between "I'm on Pro and my request just used the cloud directly
// without tools" vs "I'm on Pro and the agent loop ran with tools" —
// the visible UI only showed model name + mode. The audit register
// (RCA-P1-004) calls this out as the load-bearing tool-truth gap.
// Every other diagnostic row in Settings is a specialized window;
// this one is the universal "what's running now" answer.

@MainActor
public struct RuntimeTruthHealthRow: View {
    @Environment(InferenceState.self) private var inference

    /// Operating mode is stored in `@AppStorage` and read everywhere
    /// via `MainChatOperatingModePreference.defaultsKey`. We mirror
    /// that pattern here so the row's "Mode" line reflects the same
    /// value the user sees in the main chat input bar.
    @AppStorage(MainChatOperatingModePreference.defaultsKey)
    private var operatingModeRaw = EpistemosOperatingMode.fast.rawValue

    public init() {}

    // MARK: - Derived state

    /// Operating mode the user has selected (Fast / Thinking / Pro / Agent).
    private var mode: EpistemosOperatingMode {
        EpistemosOperatingMode(rawValue: operatingModeRaw) ?? .fast
    }

    /// Active provider summary (human-readable).
    private var providerSummary: String {
        switch inference.preferredChatModelSelection {
        case .localMLX(let id):
            return "Local · \(id)"
        case .cloud(let model):
            // `CloudTextModelID` is a raw-string enum
            // (`"openai:gpt-5.4"`, `"anthropic:claude-opus-4-7"` …)
            // so its raw value is the stable provider:model id.
            return "Cloud · \(model.rawValue)"
        case .appleIntelligence:
            return "Apple Intelligence"
        }
    }

    /// Whether the current selection is cloud-hosted.
    private var isCloudProvider: Bool {
        if case .cloud = inference.preferredChatModelSelection { return true }
        if case .appleIntelligence = inference.preferredChatModelSelection { return false }
        return false
    }

    /// Capability tier the chat bubble will surface.
    private var capability: ChatCapability {
        ChatCapability.classify(
            isCloudProvider: isCloudProvider,
            isAgentExecuting: mode == .agent,
            isResearchMode: false,
            isThinkingMode: mode == .thinking
        )
    }

    /// Which tool loop will actually fire on the next turn. Honest
    /// answer per the audit's acceptance criterion — "users see when
    /// tools were used, denied, or unavailable."
    private var toolLoopSummary: ToolLoopSummary {
        switch (mode, isCloudProvider) {
        case (.agent, true):
            return .init(
                label: "Rust managed agent (cloud + tools)",
                detail: "Pro+cloud chat_pro loop — vault_search, vault_read, web_search, etc. dispatched via agent_core",
                isToolEnabled: true,
                systemImage: "sparkles"
            )
        case (.agent, false):
            return .init(
                label: "Local agent loop (on-device + tools)",
                detail: "Local model + Rust agent_core tool dispatch",
                isToolEnabled: true,
                systemImage: "bolt.circle"
            )
        case (.pro, true):
            return .init(
                label: "Cloud chat_pro (bounded tool loop)",
                detail: "Cloud provider + Rust agent_core tool loop with reduced budget",
                isToolEnabled: true,
                systemImage: "tray.full"
            )
        case (.pro, false):
            return .init(
                label: "Local Pro (extended thinking)",
                detail: "On-device model with extended reasoning; no external tools",
                isToolEnabled: false,
                systemImage: "brain.head.profile"
            )
        case (.thinking, _):
            return .init(
                label: "Thinking (direct stream)",
                detail: "Extended reasoning; no tools",
                isToolEnabled: false,
                systemImage: "brain"
            )
        case (.fast, true):
            return .init(
                label: "Cloud direct stream",
                detail: "Provider streaming, no tool loop",
                isToolEnabled: false,
                systemImage: "cloud"
            )
        case (.fast, false):
            return .init(
                label: "Local direct stream",
                detail: "On-device generation, no tools",
                isToolEnabled: false,
                systemImage: "bolt"
            )
        }
    }

    /// User-visible category of work this turn can actually do. Three
    /// classes the audit register settled on:
    ///   - Direct stream  — provider tokens flow into the bubble, no
    ///     vault / file / web operations.
    ///   - Managed agent  — Rust agent_core takes over; vault reads,
    ///     vault writes, web fetch, code execution may all fire.
    ///   - Local pipeline — on-device only; whatever the local model
    ///     can ask for + any local-tier tool wrappers.
    private struct ToolLoopSummary {
        let label: String
        let detail: String
        let isToolEnabled: Bool
        let systemImage: String
    }

    // MARK: - View

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title bar
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Runtime truth")
                        .font(.system(size: 13, weight: .semibold))
                    Text("What's actually running right now")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Mode + Provider grid
            VStack(alignment: .leading, spacing: 4) {
                runtimeRow(
                    label: "Mode",
                    value: mode.rawValue.capitalized,
                    systemImage: "slider.horizontal.3"
                )
                runtimeRow(
                    label: "Provider",
                    value: providerSummary,
                    systemImage: isCloudProvider ? "cloud.fill" : "bolt.fill"
                )
                runtimeRow(
                    label: "Capability",
                    value: "\(capability.displayName) — \(capability.shortExplanation)",
                    systemImage: capability.iconSystemName
                )
                runtimeRow(
                    label: "Tool loop",
                    value: toolLoopSummary.label,
                    detail: toolLoopSummary.detail,
                    systemImage: toolLoopSummary.systemImage,
                    accent: toolLoopSummary.isToolEnabled ? .green : .secondary
                )
            }

            #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
            Divider().padding(.vertical, 2)
            Text("CLI passthrough (Pro)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("See the “CLI Discovery” row below for installed-CLI status (claude / codex / gemini / kimi).")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            #else
            Divider().padding(.vertical, 2)
            HStack(spacing: 6) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text("Subprocess CLIs are not available in this build.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            #endif
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func runtimeRow(
        label: String,
        value: String,
        detail: String? = nil,
        systemImage: String,
        accent: Color = .primary
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .center)
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .leading)
                    Text(value)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(accent)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
                if let detail {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .padding(.leading, 76)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
