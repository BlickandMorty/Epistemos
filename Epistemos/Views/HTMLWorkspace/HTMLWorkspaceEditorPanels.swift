import SwiftUI

struct HTMLWorkspaceSourceRail: View {
    @Binding var selectedPane: HTMLWorkspaceSourcePane
    let package: HTMLWorkspacePackage
    let theme: EpistemosTheme
    let panelFill: Color
    let dataStatus: String
    let statusText: String?

    private var mutedText: Color {
        theme.textTertiary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(HTMLWorkspaceSourcePane.allCases) { pane in
                Button {
                    selectedPane = pane
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: pane.systemImage)
                            .frame(width: 16)
                        Text(pane.title)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 12, weight: selectedPane == pane ? .semibold : .regular))
                    .foregroundStyle(selectedPane == pane ? theme.resolved.accent.color : mutedText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background {
                        if selectedPane == pane {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(theme.resolved.accent.color.opacity(theme.isDark ? 0.20 : 0.14))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            status
        }
        .padding(8)
        .background(panelFill)
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(package.manifest.sandboxPolicy.allowNetwork ? "Network" : "Offline")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(mutedText)
            Text(dataStatus)
                .font(.caption2)
                .foregroundStyle(dataStatus == "Data OK" ? mutedText : theme.error)
                .lineLimit(2)
            if let feedSummary = HTMLWorkspaceDataFeedStatus.compactLine(for: package) {
                Text(feedSummary)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(feedSummary.contains("stale") ? theme.warning : mutedText)
                    .lineLimit(2)
                    .padding(.top, 4)
                if let feedDetail = HTMLWorkspaceDataFeedStatus.detailLine(for: package) {
                    Text(feedDetail)
                        .font(.caption2)
                        .foregroundStyle(mutedText)
                        .lineLimit(4)
                        .truncationMode(.middle)
                }
            }
            if let statusText {
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(mutedText)
                    .lineLimit(3)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }
}

struct HTMLWorkspaceReadOnlySourcePane: View {
    let title: String
    let systemImage: String
    let text: String
    let emptyText: String
    let theme: EpistemosTheme

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .foregroundStyle(theme.resolved.accent.color)
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                    Spacer(minLength: 0)
                }
                Text(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? emptyText : text)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.resolved.foreground.color)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .background(MarkdownPreviewSurfaceStyle.canvasBackground(for: theme))
    }
}

struct HTMLWorkspacePreviewHeader: View {
    let package: HTMLWorkspacePackage
    let routeNames: [String]
    @Binding var previewRouteName: String?
    let bridgeStatusText: String
    let pythonRuntimeStatusText: String
    let headerFill: Color
    let theme: EpistemosTheme

    private var mutedText: Color {
        theme.textTertiary
    }

    private var pythonRuntimeColor: Color {
        package.manifest.sandboxPolicy.allowPythonRuntime && HTMLWorkspacePythonRuntime.isAvailable
            ? theme.success
            : mutedText
    }

    private var networkStatusColor: Color {
        package.manifest.sandboxPolicy.allowNetwork ? theme.warning : theme.success
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "safari")
                .foregroundStyle(mutedText)
            Text("Preview")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.resolved.foreground.color)
            Text("WKWebView")
                .font(.caption2)
                .foregroundStyle(mutedText)
            Picker("Route", selection: $previewRouteName) {
                Text("index.html").tag(String?.none)
                ForEach(routeNames, id: \.self) { routeName in
                    Text("routes/\(routeName)").tag(Optional(routeName))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 220)
            Spacer(minLength: 12)
            Text(bridgeStatusText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(mutedText)
            Text(pythonRuntimeStatusText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(pythonRuntimeColor)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 150, alignment: .trailing)
            Text(package.manifest.sandboxPolicy.allowNetwork ? "Network" : "Offline")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(networkStatusColor)
            HTMLWorkspaceDataFeedStatusStrip(package: package, compact: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(headerFill)
    }
}

struct HTMLWorkspaceConsolePanel: View {
    @Binding var isExpanded: Bool
    let errors: [HTMLWorkspaceConsoleError]
    let panelFill: Color
    let theme: EpistemosTheme
    let onClear: () -> Void

    private var mutedText: Color {
        theme.textTertiary
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 6) {
                if errors.isEmpty {
                    Text("No errors")
                        .foregroundStyle(mutedText)
                } else {
                    HStack {
                        Spacer()
                        Button(action: onClear) {
                            Label("Clear console", systemImage: "trash")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.borderless)
                        .help("Clear console")
                    }
                    ForEach(Array(errors.suffix(8).enumerated()), id: \.offset) { _, error in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(severityLabel(for: error.severity))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(severityColor(for: error.severity))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(severityColor(for: error.severity).opacity(0.12), in: Capsule())
                                Text(error.message)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(2)
                            }
                            if let source = error.source {
                                Text("\(source):\(error.line):\(error.column)")
                                    .font(.caption2)
                                    .foregroundStyle(mutedText)
                            }
                        }
                    }
                }
            }
            .padding(.top, 6)
        } label: {
            HStack {
                Text("Console")
                    .foregroundStyle(theme.resolved.foreground.color)
                Spacer()
                if !errors.isEmpty {
                    Text("\(errors.count)")
                        .font(.caption)
                        .foregroundStyle(mutedText)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(panelFill)
    }

    private func severityLabel(for severity: HTMLWorkspaceConsoleSeverity) -> String {
        switch severity {
        case .diagnostic:
            "INFO"
        case .warning:
            "WARN"
        case .error:
            "ERROR"
        }
    }

    private func severityColor(for severity: HTMLWorkspaceConsoleSeverity) -> Color {
        switch severity {
        case .diagnostic:
            mutedText
        case .warning:
            theme.warning
        case .error:
            theme.error
        }
    }
}

struct HTMLWorkspaceInspectorPanel: View {
    let package: HTMLWorkspacePackage
    let contentHash: String
    let domNodeCount: Int
    let domSourceLabel: String
    let selectedElementInspection: HTMLWorkspaceElementInspection?
    let dataStatus: String
    let generationProvenanceText: String
    let bridgeStatusText: String
    let pythonRuntimeStatusText: String
    let panelFill: Color
    let theme: EpistemosTheme
    let onCopySelector: (String) -> Void
    let onCreateStyleRule: (HTMLWorkspaceElementInspection) -> Void
    let onCopyStyleRulePatch: (HTMLWorkspaceElementInspection) -> Void
    let onUpdateStyleDeclaration: (HTMLWorkspaceElementInspection, String, String) -> Void
    let onCopyStyleDeclarationPatch: (HTMLWorkspaceElementInspection, String, String) -> Void

    @State private var styleProperty = "color"
    @State private var styleValue = ""

    private var mutedText: Color {
        theme.textTertiary
    }

    private var fieldBackground: Color {
        theme.resolved.card.color.opacity(theme.isDark ? 0.30 : 0.54)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Inspector")
                .font(.headline)
                .foregroundStyle(theme.resolved.foreground.color)

            VStack(alignment: .leading, spacing: 7) {
                inspectorRow("Hash", String(contentHash.prefix(12)))
                inspectorRow("Sandbox", package.manifest.sandboxPolicy.allowNetwork ? "Network" : "Offline")
                inspectorRow("Bridge", bridgeStatusText)
                inspectorRow("Python", pythonRuntimeStatusText)
                inspectorRow("DOM", "\(domNodeCount) \(domSourceLabel)")
                inspectorRow("Selected", selectedElementInspection?.selector ?? "None")
                inspectorRow("Data", dataStatus)
                inspectorRow("Provenance", generationProvenanceText)
                inspectorRow("Routes", "\(package.routes.count)")
                inspectorRow("Assets", "\(package.assets.count)")
                inspectorRow("Snapshots", "\(package.snapshots.count)")
                inspectorRow("Errors", "\(package.consoleErrors.count)")
            }

            elementInspectorSection

            VStack(alignment: .leading, spacing: 8) {
                Text("Patch Ops")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.resolved.foreground.color)
                capabilityGrid
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(panelFill)
    }

    private var elementInspectorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Element")
                .font(.subheadline.weight(.semibold))
            if let selectedElementInspection {
                HStack(alignment: .top, spacing: 6) {
                    Text(selectedElementInspection.selector)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.resolved.foreground.color)
                        .lineLimit(2)
                        .textSelection(.enabled)
                    Spacer(minLength: 0)
                    Button {
                        onCopySelector(selectedElementInspection.selector)
                    } label: {
                        Label("Copy selector", systemImage: "doc.on.doc")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .help("Copy selector")
                    Button {
                        onCreateStyleRule(selectedElementInspection)
                    } label: {
                        Label("Add style rule", systemImage: "paintbrush")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .help("Add style rule")
                    Button {
                        onCopyStyleRulePatch(selectedElementInspection)
                    } label: {
                        Label("Copy style patch", systemImage: "curlybraces")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .help("Copy style patch")
                }
                if !selectedElementInspection.textPreview.isEmpty {
                    Text(selectedElementInspection.textPreview)
                        .font(.caption2)
                        .foregroundStyle(mutedText)
                        .lineLimit(3)
                }
                styleDeclarationEditor(for: selectedElementInspection)
                ForEach(selectedElementInspection.styles.keys.sorted(), id: \.self) { key in
                    inspectorRow(key, selectedElementInspection.styles[key] ?? "")
                }
            } else {
                Text("Click an element in the preview.")
                    .font(.caption)
                    .foregroundStyle(mutedText)
            }
        }
    }

    private func styleDeclarationEditor(for inspection: HTMLWorkspaceElementInspection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Edit Style")
                .font(.caption.weight(.semibold))
                .foregroundStyle(mutedText)
            HStack(spacing: 6) {
                TextField("property", text: $styleProperty)
                    .font(.system(size: 11, design: .monospaced))
                    .textFieldStyle(.plain)
                    .foregroundStyle(theme.resolved.foreground.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(fieldBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                TextField("value", text: $styleValue)
                    .font(.system(size: 11, design: .monospaced))
                    .textFieldStyle(.plain)
                    .foregroundStyle(theme.resolved.foreground.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(fieldBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Button {
                    onUpdateStyleDeclaration(inspection, styleProperty, styleValue)
                } label: {
                    Label("Apply style", systemImage: "checkmark")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Apply style")
                Button {
                    onCopyStyleDeclarationPatch(inspection, styleProperty, styleValue)
                } label: {
                    Label("Copy style patch", systemImage: "curlybraces")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Copy style patch")
            }
        }
    }

    private func inspectorRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(mutedText)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(theme.resolved.foreground.color)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .font(.caption)
    }

    private var capabilityGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(["HTML", "CSS", "JS", "Data", "DOM", "Chart", "Asset", "PDF"], id: \.self) { label in
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(theme.resolved.foreground.color)
                    .background(fieldBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }
}
