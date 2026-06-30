import SwiftUI

struct HTMLWorkspaceSourceRail: View {
    @Binding var selectedPane: HTMLWorkspaceSourcePane
    let package: HTMLWorkspacePackage
    let theme: EpistemosTheme
    let panelFill: Color
    let dataStatus: String
    let statusText: String?

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
                    .foregroundStyle(selectedPane == pane ? theme.resolved.accent.color : .secondary)
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
            Text(dataStatus)
                .font(.caption2)
                .foregroundStyle(dataStatus == "Data OK" ? Color.secondary : Color.red)
                .lineLimit(2)
            if let feedSummary = HTMLWorkspaceDataFeedStatus.compactLine(for: package) {
                Divider()
                    .padding(.vertical, 2)
                Text(feedSummary)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(feedSummary.contains("stale") ? Color.orange : Color.secondary)
                    .lineLimit(2)
                if let feedDetail = HTMLWorkspaceDataFeedStatus.detailLine(for: package) {
                    Text(feedDetail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .truncationMode(.middle)
                }
            }
            if let statusText {
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
    let bridgeStatusText: String
    let pythonRuntimeStatusText: String
    let headerFill: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "safari")
                .foregroundStyle(.secondary)
            Text("Preview")
                .font(.subheadline.weight(.semibold))
            Text("WKWebView")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(bridgeStatusText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(pythonRuntimeStatusText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(package.manifest.sandboxPolicy.allowPythonRuntime && HTMLWorkspacePythonRuntime.isAvailable ? .green : .secondary)
            Text(package.manifest.sandboxPolicy.allowNetwork ? "Network" : "Offline")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(package.manifest.sandboxPolicy.allowNetwork ? .orange : .green)
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

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 6) {
                if errors.isEmpty {
                    Text("No errors")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(errors.suffix(8).enumerated()), id: \.offset) { _, error in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(error.message)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(2)
                            if let source = error.source {
                                Text("\(source):\(error.line):\(error.column)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(.top, 6)
        } label: {
            HStack {
                Text("Console")
                Spacer()
                if !errors.isEmpty {
                    Text("\(errors.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(panelFill)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Inspector")
                .font(.headline)

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

            Divider()
            elementInspectorSection
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Patch Ops")
                    .font(.subheadline.weight(.semibold))
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
                Text(selectedElementInspection.selector)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(2)
                    .textSelection(.enabled)
                if !selectedElementInspection.textPreview.isEmpty {
                    Text(selectedElementInspection.textPreview)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                ForEach(selectedElementInspection.styles.keys.sorted(), id: \.self) { key in
                    inspectorRow(key, selectedElementInspection.styles[key] ?? "")
                }
            } else {
                Text("Click an element in the preview.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func inspectorRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
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
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }
}
