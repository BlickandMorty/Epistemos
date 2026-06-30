import SwiftUI

@MainActor
struct AgentLauncherPanelView: View {
    @Binding var selection: AgentRailDestination
    let activeDestination: AgentRailDestination
    let theme: EpistemosTheme
    let onDismiss: () -> Void

    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    private var filteredDestinations: [AgentRailDestination] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return AgentRailDestination.launcherDestinations }
        return AgentRailDestination.launcherDestinations.filter { destination in
            destination.title.localizedCaseInsensitiveContains(trimmed)
                || destination.rawValue.localizedCaseInsensitiveContains(trimmed)
                || destination.webRoute.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            searchField
            launcherContent
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(GooseSurfaceStyle.background(for: theme, role: .content).opacity(theme.isDark ? 0.44 : 0.30))
        .onExitCommand(perform: onDismiss)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.resolved.accent.color.opacity(theme.isDark ? 0.18 : 0.11))
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.resolved.accent.color)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("Launcher")
                    .font(GooseSurfaceStyle.bodyFont(22, weight: .semibold))
                    .foregroundStyle(theme.resolved.foreground.color)
                Text("Open a Goose surface")
                    .font(GooseSurfaceStyle.bodyFont(12, weight: .medium))
                    .foregroundStyle(theme.mutedForeground)
            }

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.mutedForeground)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(theme.resolved.foreground.color.opacity(theme.isDark ? 0.06 : 0.04))
            )
            .help("Close launcher")
            .accessibilityLabel("Close launcher")
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.textTertiary)
            TextField("Search Goose surfaces", text: $query)
                .textFieldStyle(.plain)
                .font(GooseSurfaceStyle.bodyFont(14))
                .foregroundStyle(theme.resolved.foreground.color)
                .focused($isSearchFocused)
                .onSubmit(openFirstFilteredDestination)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(theme.resolved.foreground.color.opacity(theme.isDark ? 0.055 : 0.036))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(theme.glassBorder.opacity(theme.isDark ? 0.46 : 0.58), lineWidth: 0.7)
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    private var launcherContent: some View {
        ScrollView {
            if filteredDestinations.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                routeGrid
                    .padding(.bottom, 2)
            }
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var routeGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 176, maximum: 260), spacing: 10, alignment: .top),
            ],
            alignment: .leading,
            spacing: 10
        ) {
            ForEach(filteredDestinations) { destination in
                Button {
                    selection = destination
                } label: {
                    launcherRow(destination)
                }
                .buttonStyle(.plain)
                .help(destination.webRoute)
                .accessibilityLabel(destination.title)
            }
        }
    }

    private func openFirstFilteredDestination() {
        guard let destination = filteredDestinations.first else { return }
        selection = destination
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
            Text("No matching surfaces")
                .font(GooseSurfaceStyle.bodyFont(13, weight: .semibold))
                .foregroundStyle(theme.mutedForeground)
        }
        .frame(maxWidth: .infinity)
    }

    private func launcherRow(_ destination: AgentRailDestination) -> some View {
        let isActive = destination == activeDestination
        return HStack(spacing: 10) {
            Image(systemName: destination.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isActive ? theme.resolved.accent.color : theme.mutedForeground)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(destination.title)
                    .font(GooseSurfaceStyle.bodyFont(13, weight: .semibold))
                    .foregroundStyle(theme.resolved.foreground.color)
                    .lineLimit(1)
                Text(destination.webRoute)
                    .font(GooseSurfaceStyle.captionFont(10, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 54)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isActive
                        ? theme.resolved.accent.color.opacity(theme.isDark ? 0.12 : 0.08)
                        : theme.resolved.foreground.color.opacity(theme.isDark ? 0.052 : 0.032)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isActive
                        ? theme.resolved.accent.color.opacity(theme.isDark ? 0.48 : 0.38)
                        : theme.glassBorder.opacity(theme.isDark ? 0.34 : 0.46),
                    lineWidth: isActive ? 1 : 0.7
                )
        }
    }
}
