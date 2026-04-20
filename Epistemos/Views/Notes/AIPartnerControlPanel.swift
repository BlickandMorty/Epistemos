// AIPartnerControlPanel.swift
//
// Control panel for the AI Coding Partner.
// Provides presets (calm, frequent, aggressive) and granular manual controls
// for suggestion frequency, depth, and context weighting.
//
// 2026-04-07.

import SwiftUI

// MARK: - AI Partner Configuration

private enum DiscreteSliderIndex {
    static func resolve(_ rawValue: Double, count: Int) -> Int? {
        guard count > 0 else { return nil }
        guard rawValue.isFinite else { return nil }
        let upperBound = Double(count - 1)
        return Int(min(max(rawValue.rounded(), 0), upperBound))
    }
}

/// Configuration model for AI partner behavior
struct AIPartnerConfiguration: Codable, Equatable {
    var mode: InteractionMode
    
    // Granular controls (used when mode == .manual)
    var suggestionFrequency: Frequency
    var insightDepth: InsightDepth
    var contextWindowSize: ContextWindow
    var semanticWeight: Double  // 0.0 to 1.0
    var recentEditWeight: Double  // 0.0 to 1.0
    var vaultGraphWeight: Double  // 0.0 to 1.0
    var maxConcurrentSuggestions: Int
    var showContextHighlights: Bool
    var useRetroStyling: Bool
    
    enum InteractionMode: String, Codable, CaseIterable {
        case auto = "Auto"
        case manual = "Manual"
        
        var description: String {
            switch self {
            case .auto: return "Automatic presets based on your coding flow"
            case .manual: return "Full manual control over all parameters"
            }
        }
    }
    
    enum Frequency: String, Codable, CaseIterable {
        case calm = "Calm"
        case balanced = "Balanced"
        case frequent = "Frequent"
        case aggressive = "Aggressive"
        
        var interval: TimeInterval {
            switch self {
            case .calm: return 60  // 1 minute
            case .balanced: return 30  // 30 seconds
            case .frequent: return 10  // 10 seconds
            case .aggressive: return 3  // 3 seconds
            }
        }
        
        var suggestionLimit: Int {
            switch self {
            case .calm: return 1
            case .balanced: return 2
            case .frequent: return 3
            case .aggressive: return 5
            }
        }
        
        var icon: String {
            switch self {
            case .calm: return "tortoise"
            case .balanced: return "figure.walk"
            case .frequent: return "hare"
            case .aggressive: return "bolt.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .calm: return .blue
            case .balanced: return .green
            case .frequent: return .orange
            case .aggressive: return .red
            }
        }
    }
    
    enum InsightDepth: String, Codable, CaseIterable {
        case surface = "Surface"
        case standard = "Standard"
        case deep = "Deep"
        case exhaustive = "Exhaustive"
        
        var tokenBudget: Int {
            switch self {
            case .surface: return 100
            case .standard: return 500
            case .deep: return 2000
            case .exhaustive: return 8000
            }
        }
        
        var analysisComplexity: Double {
            switch self {
            case .surface: return 0.3
            case .standard: return 0.6
            case .deep: return 0.85
            case .exhaustive: return 1.0
            }
        }
        
        var icon: String {
            switch self {
            case .surface: return "water.waves"
            case .standard: return "water.waves.slash"
            case .deep: return "arrow.down.circle"
            case .exhaustive: return "arrow.down.to.line"
            }
        }
    }
    
    enum ContextWindow: String, Codable, CaseIterable {
        case narrow = "Narrow"
        case medium = "Medium"
        case wide = "Wide"
        case full = "Full File"
        
        var linesBefore: Int {
            switch self {
            case .narrow: return 5
            case .medium: return 20
            case .wide: return 50
            case .full: return 500
            }
        }
        
        var linesAfter: Int {
            switch self {
            case .narrow: return 5
            case .medium: return 20
            case .wide: return 50
            case .full: return 100
            }
        }
    }
    
    // Presets
    static let calm = AIPartnerConfiguration(
        mode: .auto,
        suggestionFrequency: .calm,
        insightDepth: .surface,
        contextWindowSize: .medium,
        semanticWeight: 0.3,
        recentEditWeight: 0.7,
        vaultGraphWeight: 0.2,
        maxConcurrentSuggestions: 1,
        showContextHighlights: true,
        useRetroStyling: false
    )
    
    static let balanced = AIPartnerConfiguration(
        mode: .auto,
        suggestionFrequency: .balanced,
        insightDepth: .standard,
        contextWindowSize: .medium,
        semanticWeight: 0.5,
        recentEditWeight: 0.5,
        vaultGraphWeight: 0.4,
        maxConcurrentSuggestions: 2,
        showContextHighlights: true,
        useRetroStyling: false
    )
    
    static let frequent = AIPartnerConfiguration(
        mode: .auto,
        suggestionFrequency: .frequent,
        insightDepth: .deep,
        contextWindowSize: .wide,
        semanticWeight: 0.6,
        recentEditWeight: 0.4,
        vaultGraphWeight: 0.6,
        maxConcurrentSuggestions: 3,
        showContextHighlights: true,
        useRetroStyling: true
    )
    
    static let aggressive = AIPartnerConfiguration(
        mode: .auto,
        suggestionFrequency: .aggressive,
        insightDepth: .exhaustive,
        contextWindowSize: .full,
        semanticWeight: 0.8,
        recentEditWeight: 0.3,
        vaultGraphWeight: 0.8,
        maxConcurrentSuggestions: 5,
        showContextHighlights: true,
        useRetroStyling: true
    )
    
    static let `default` = balanced
}

extension CaseIterable where AllCases: Collection, AllCases.Element == Self {
    static func caseForSliderValue(_ rawValue: Double, current: Self) -> Self {
        let cases = Array(allCases)
        guard let index = DiscreteSliderIndex.resolve(rawValue, count: cases.count) else {
            return current
        }
        return cases[index]
    }
}

// MARK: - Control Panel View

struct AIPartnerControlPanel: View {
    @Binding var configuration: AIPartnerConfiguration
    let onApply: () -> Void
    let onReset: () -> Void
    
    @State private var selectedPreset: PresetOption = .balanced
    @State private var showAdvanced = false
    
    enum PresetOption: String, CaseIterable {
        case calm = "Calm"
        case balanced = "Balanced"
        case frequent = "Frequent"
        case aggressive = "Aggressive"
        case custom = "Custom"
        
        var icon: String {
            switch self {
            case .calm: return "tortoise.fill"
            case .balanced: return "figure.walk.motion"
            case .frequent: return "hare.fill"
            case .aggressive: return "bolt.fill"
            case .custom: return "slider.horizontal.3"
            }
        }
        
        var color: Color {
            switch self {
            case .calm: return .blue
            case .balanced: return .green
            case .frequent: return .orange
            case .aggressive: return .red
            case .custom: return .purple
            }
        }
        
        var description: String {
            switch self {
            case .calm: return "Minimal interruptions, surface-level insights"
            case .balanced: return "Occasional helpful suggestions"
            case .frequent: return "Proactive partner with deep analysis"
            case .aggressive: return "Maximum assistance, exhaustive context"
            case .custom: return "Your personalized configuration"
            }
        }
        
        var configuration: AIPartnerConfiguration {
            switch self {
            case .calm: return .calm
            case .balanced: return .balanced
            case .frequent: return .frequent
            case .aggressive: return .aggressive
            case .custom: return .default
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            
            ScrollView {
                VStack(spacing: 20) {
                    modeSelector
                    
                    if configuration.mode == .auto {
                        presetSelector
                    } else {
                        granularControls
                    }
                    
                    if showAdvanced {
                        advancedControls
                    }
                }
                .padding()
            }
            
            footer
        }
        .frame(width: 360, height: showAdvanced ? 600 : 480)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var header: some View {
        HStack {
            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 16))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("AI Partner")
                .font(.system(size: 16, weight: .semibold))
            
            Spacer()
            
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAdvanced.toggle()
                }
            } label: {
                Image(systemName: "gearshape.2")
                    .font(.system(size: 12))
                    .foregroundStyle(showAdvanced ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private var modeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mode")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            
            Picker("", selection: $configuration.mode) {
                ForEach(AIPartnerConfiguration.InteractionMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            Text(configuration.mode.description)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
    }
    
    private var presetSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Presets")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                ForEach(PresetOption.allCases.filter { $0 != .custom }, id: \.self) { preset in
                    PresetButton(
                        preset: preset,
                        isSelected: selectedPreset == preset,
                        onSelect: {
                            selectedPreset = preset
                            configuration = preset.configuration
                            onApply()
                        }
                    )
                }
            }
        }
    }
    
    private var granularControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Manual Configuration")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            
            // Suggestion Frequency
            ControlSlider(
                title: "Frequency",
                value: Binding(
                    get: { Double(AIPartnerConfiguration.Frequency.allCases.firstIndex(of: configuration.suggestionFrequency) ?? 1) },
                    set: { index in
                        configuration.suggestionFrequency = AIPartnerConfiguration.Frequency.caseForSliderValue(
                            index,
                            current: configuration.suggestionFrequency
                        )
                    }
                ),
                range: 0...3,
                step: 1,
                labels: ["Calm", "Balanced", "Frequent", "Aggressive"],
                icon: "clock.arrow.circlepath",
                color: configuration.suggestionFrequency.color
            )
            
            // Insight Depth
            ControlSlider(
                title: "Insight Depth",
                value: Binding(
                    get: { Double(AIPartnerConfiguration.InsightDepth.allCases.firstIndex(of: configuration.insightDepth) ?? 1) },
                    set: { index in
                        configuration.insightDepth = AIPartnerConfiguration.InsightDepth.caseForSliderValue(
                            index,
                            current: configuration.insightDepth
                        )
                    }
                ),
                range: 0...3,
                step: 1,
                labels: ["Surface", "Standard", "Deep", "Exhaustive"],
                icon: "arrow.down.circle",
                color: .cyan
            )
            
            // Context Window
            ControlSlider(
                title: "Context Window",
                value: Binding(
                    get: { Double(AIPartnerConfiguration.ContextWindow.allCases.firstIndex(of: configuration.contextWindowSize) ?? 1) },
                    set: { index in
                        configuration.contextWindowSize = AIPartnerConfiguration.ContextWindow.caseForSliderValue(
                            index,
                            current: configuration.contextWindowSize
                        )
                    }
                ),
                range: 0...3,
                step: 1,
                labels: ["Narrow", "Medium", "Wide", "Full"],
                icon: "rectangle.expand.vertical",
                color: .orange
            )
            
            // Max Suggestions
            HStack {
                Label("Max Suggestions", systemImage: "number")
                    .font(.system(size: 12))
                
                Spacer()
                
                Stepper("\(configuration.maxConcurrentSuggestions)", value: $configuration.maxConcurrentSuggestions, in: 1...5)
                    .labelsHidden()
            }
        }
    }
    
    private var advancedControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Advanced")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            
            // Context Weights
            WeightSlider(
                title: "Semantic Similarity",
                value: $configuration.semanticWeight,
                icon: "brain",
                color: .purple
            )
            
            WeightSlider(
                title: "Recent Edits",
                value: $configuration.recentEditWeight,
                icon: "clock.arrow.2.circlepath",
                color: .blue
            )
            
            WeightSlider(
                title: "Vault Graph",
                value: $configuration.vaultGraphWeight,
                icon: "point.3.connected.trianglepath.dotted",
                color: .green
            )
            
            Divider()
            
            // Toggles
            Toggle("Show Context Highlights", isOn: $configuration.showContextHighlights)
                .font(.system(size: 12))
            
            Toggle("Use Retro Styling", isOn: $configuration.useRetroStyling)
                .font(.system(size: 12))
        }
    }
    
    private var footer: some View {
        HStack {
            Button("Reset") {
                onReset()
                selectedPreset = .balanced
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            
            Spacer()
            
            Button("Apply") {
                onApply()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

// MARK: - Preset Button

struct PresetButton: View {
    let preset: AIPartnerControlPanel.PresetOption
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: preset.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(preset.color)
                    .frame(width: 28, height: 28)
                    .background(preset.color.opacity(0.1))
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.rawValue)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                    
                    Text(preset.description)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.1), lineWidth: 1)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Control Slider

struct ControlSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let labels: [String]
    let icon: String
    let color: Color

    static func resolvedLabel(for value: Double, labels: [String]) -> String {
        guard let index = DiscreteSliderIndex.resolve(value, count: labels.count) else {
            return labels.first ?? ""
        }
        return labels[index]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.system(size: 12))
                
                Spacer()
                
                Text(Self.resolvedLabel(for: value, labels: labels))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Slider(value: $value, in: range, step: step)
                .tint(color)
        }
    }
}

// MARK: - Weight Slider

struct WeightSlider: View {
    let title: String
    @Binding var value: Double
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.system(size: 11))
                
                Spacer()
                
                Text("\(Int(value * 100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(color)
            }
            
            Slider(value: $value, in: 0...1)
                .tint(color)
        }
    }
}

// MARK: - Compact Control Bar

/// Compact control bar for the status bar
struct AIPartnerCompactControl: View {
    @Binding var configuration: AIPartnerConfiguration
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: configuration.suggestionFrequency.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(configuration.suggestionFrequency.color)
                
                Text(configuration.mode == .auto ? configuration.suggestionFrequency.rawValue : "Custom")
                    .font(.system(size: 11, weight: .medium))
                
                if configuration.showContextHighlights {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(configuration.suggestionFrequency.color.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(configuration.suggestionFrequency.color.opacity(0.3), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Control Panel") {
    @Previewable @State var config = AIPartnerConfiguration.default
    
    AIPartnerControlPanel(
        configuration: $config,
        onApply: {},
        onReset: {}
    )
}

#Preview("Compact Control") {
    @Previewable @State var config = AIPartnerConfiguration.aggressive
    
    AIPartnerCompactControl(configuration: $config) {}
        .padding()
}

#Preview("Preset Buttons") {
    VStack(spacing: 8) {
        PresetButton(preset: .calm, isSelected: false) {}
        PresetButton(preset: .balanced, isSelected: true) {}
        PresetButton(preset: .frequent, isSelected: false) {}
        PresetButton(preset: .aggressive, isSelected: false) {}
    }
    .padding()
    .frame(width: 300)
}
