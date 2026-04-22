import SwiftUI

// MARK: - Model About Sheet
// Compact capability overview for any model (local or cloud).

struct ModelAboutSheet: View {
    let selection: ChatModelSelection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                capabilitiesSection
                specsSection
                fileTypesSection
            }
            .padding(16)
        }
        .frame(width: 320)
        .frame(maxHeight: 420)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: headerIcon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(headerTint)
                .frame(width: 32, height: 32)
                .background(Circle().fill(headerTint.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(selection.displayName)
                    .font(.headline)
                HStack(spacing: 6) {
                    if let family = familyBadge {
                        badge(family, tint: .secondary)
                    }
                    if let size = sizeBadge {
                        badge(size, tint: .secondary)
                    }
                    if isSSM {
                        badge("SSM", tint: .blue)
                    }
                    if isMoE {
                        badge("MoE", tint: .purple)
                    }
                }
            }
        }
    }

    // MARK: - Capabilities

    private var capabilitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Capabilities")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ], spacing: 6) {
                capRow("Vision", supported: selection.activeSupportsVision, icon: "eye")
                capRow("Thinking", supported: supportsThinking, icon: "brain.head.profile")
                capRow("Tools", supported: supportsAgent, icon: "cpu")
                capRow("Tool Calling", supported: supportsNativeTools, icon: "wrench.and.screwdriver")
            }
        }
    }

    private func capRow(_ label: String, supported: Bool, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: supported ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: 11))
                .foregroundStyle(supported ? .green : Color.secondary.opacity(0.5))
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(supported ? .primary : Color.secondary.opacity(0.5))
            Text(label)
                .font(.caption)
                .foregroundStyle(supported ? .primary : Color.secondary.opacity(0.5))
            Spacer()
        }
    }

    // MARK: - Specs

    private var specsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Specifications")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            specRow("Context Window", value: formatTokens(selection.activeMaxContextTokens))

            if case .localMLX(let id) = selection, let model = LocalTextModelID(rawValue: id) {
                let descriptor = LocalModelCatalog.descriptor(for: id)
                specRow("Architecture", value: model.isSSM ? "SSM" : (model.isMoE ? "MoE Transformer" : "Transformer"))
                specRow("Temperature", value: String(format: "%.1f", model.optimalTemperature))
                if model.supportsThinkingMode, let thinkTemp: Float = model.thinkingTemperature {
                    specRow("Thinking Temp", value: String(format: "%.1f", thinkTemp))
                }
                specRow("Top-p", value: String(format: "%.2f", model.optimalTopP))
                specRow("KV Cache", value: "\(model.optimalKVCacheSize)")
                specRow("Chat Memory", value: "\(model.minimumRecommendedInteractiveMemoryGB) GB+")
                if let descriptor {
                    specRow("Model Files", value: descriptor.approximateDownloadLabel)
                }
                if model.canRunLocalAgentLoop {
                    specRow(
                        "Tool Tier",
                        value: model.agentToolTier.rawValue
                            .replacingOccurrences(of: "f", with: "F")
                            .replacingOccurrences(of: "r", with: "R")
                    )
                }
            } else if case .cloud(let model) = selection {
                specRow("Provider", value: model.providerDisplayName)
                specRow("Best For", value: model.aboutSheetPurposeSummary)
                specRow("Modes", value: model.aboutSheetModeSummary)
                specRow("Output", value: model.aboutSheetStructuredOutputSummary)
                specRow("API ID", value: model.vendorModelID)
            }
        }
    }

    private func specRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - File Types

    private var fileTypesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Supported Files")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                let types = selection.activeSupportedFileTypes
                fileChip("Text", supported: types.contains(.text), icon: "doc.text")
                fileChip("PDF", supported: types.contains(.pdf), icon: "doc.richtext")
                fileChip("CSV", supported: types.contains(.csv), icon: "tablecells")
                fileChip("Images", supported: types.contains(.image), icon: "photo")
            }
        }
    }

    private func fileChip(_ label: String, supported: Bool, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(label)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(supported ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.06))
        )
        .foregroundStyle(supported ? .primary : Color.secondary.opacity(0.4))
        .overlay(
            Capsule().strokeBorder(
                supported ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.1),
                lineWidth: 0.5
            )
        )
    }

    // MARK: - Helpers

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.1)))
            .foregroundStyle(tint)
    }

    private func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            return "\(tokens / 1_000_000)M tokens"
        }
        if tokens >= 1_000 {
            return String(format: "%.1fK tokens", Double(tokens) / 1_000)
        }
        return "\(tokens) tokens"
    }

    private var headerIcon: String {
        switch selection {
        case .appleIntelligence: "apple.logo"
        case .localMLX: "desktopcomputer"
        case .cloud: "cloud"
        }
    }

    private var headerTint: Color {
        switch selection {
        case .appleIntelligence: .orange
        case .localMLX: .blue
        case .cloud: .purple
        }
    }

    private var familyBadge: String? {
        switch selection {
        case .localMLX(let id):
            return LocalTextModelID(rawValue: id)?.familyName
        case .cloud(let model):
            return model.aboutSheetBadge
        case .appleIntelligence:
            return nil
        }
    }

    private var sizeBadge: String? {
        guard case .localMLX(let id) = selection,
              let model = LocalTextModelID(rawValue: id) else { return nil }
        if model.isMoE {
            return String(format: "%.0fB active", model.activeParametersBillions)
        }
        return nil
    }

    private var isMoE: Bool {
        guard case .localMLX(let id) = selection else { return false }
        return LocalTextModelID(rawValue: id)?.isMoE ?? false
    }

    private var isSSM: Bool {
        guard case .localMLX(let id) = selection else { return false }
        return LocalTextModelID(rawValue: id)?.isSSM ?? false
    }

    private var supportsThinking: Bool {
        guard case .localMLX(let id) = selection else {
            if case .cloud(let m) = selection {
                return m.supportedOperatingModes.contains(.thinking)
            }
            return false
        }
        return LocalTextModelID(rawValue: id)?.supportsThinkingMode ?? false
    }

    private var supportsAgent: Bool {
        guard case .localMLX(let id) = selection else {
            if case .cloud(let m) = selection {
                return m.supportedOperatingModes.contains(.agent)
            }
            return false
        }
        return LocalTextModelID(rawValue: id)?.canRunLocalAgentLoop ?? false
    }

    private var supportsNativeTools: Bool {
        guard case .localMLX(let id) = selection else {
            if case .cloud = selection { return true }
            return false
        }
        return LocalTextModelID(rawValue: id)?.supportsNativeToolCalling ?? false
    }
}
