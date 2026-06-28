import SwiftUI

@MainActor
public struct CommandPaletteView: View {
    @Bindable private var registry: CommandRegistry
    @State private var query = ""
    @State private var selectedCommandID: String?
    @FocusState private var searchFocused: Bool

    public init(registry: CommandRegistry = .shared) {
        self.registry = registry
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()

            if matches.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(matches) { command in
                                commandRow(command)
                                    .id(command.id)
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: selectedCommandID) { _, id in
                        guard let id else { return }
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 620, height: 430)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear {
            selectedCommandID = matches.first?.id
            searchFocused = true
        }
        .onChange(of: query) { _, _ in
            selectedCommandID = matches.first?.id
        }
        .onMoveCommand(perform: handleMoveCommand)
        .background {
            Button("") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .frame(width: 0, height: 0)
                .opacity(0)
        }
    }

    private var matches: [EpistemosCommand] {
        registry.matching(query: query)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            TextField("Search commands", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .regular))
                .focused($searchFocused)
                .onSubmit(runSelectedCommand)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "command")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(.tertiary)
            Text("No commands")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func commandRow(_ command: EpistemosCommand) -> some View {
        let selected = command.id == selectedCommandID
        return Button {
            run(command)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: command.symbol)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(command.title)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    if let subtitle = command.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 12)

                if let shortcut = command.shortcut {
                    Text(shortcut.display)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.13) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                selectedCommandID = command.id
            }
        }
        .accessibilityLabel(command.title)
    }

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        switch direction {
        case .down:
            moveSelection(delta: 1)
        case .up:
            moveSelection(delta: -1)
        default:
            break
        }
    }

    private func moveSelection(delta: Int) {
        guard !matches.isEmpty else {
            selectedCommandID = nil
            return
        }
        let currentIndex = selectedCommandID.flatMap { id in
            matches.firstIndex(where: { $0.id == id })
        } ?? 0
        let nextIndex = min(max(currentIndex + delta, 0), matches.count - 1)
        selectedCommandID = matches[nextIndex].id
    }

    private func runSelectedCommand() {
        guard let selectedCommandID,
              let command = matches.first(where: { $0.id == selectedCommandID }) else {
            return
        }
        run(command)
    }

    private func run(_ command: EpistemosCommand) {
        dismiss()
        Task { @MainActor in
            command.run()
        }
    }

    private func dismiss() {
        registry.dismissCommandPalette()
    }
}
