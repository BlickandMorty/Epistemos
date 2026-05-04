import SwiftUI

// ---------------------------------------------------------------------------
// MARK: - LandingFarmView
// ---------------------------------------------------------------------------

/// The default view shown when Epistenos launches.
///
/// `LandingFarmView` displays all active companions in a lazy grid. Each
/// companion breathes idly via `TimelineView` (gated by `windowOccluded` and
/// `reduceMotion`). Tapping a companion activates it. The empty state shows a
/// creation CTA.
///
/// This view is registered as the default window in `LandingFarmWindowManager`.
public struct LandingFarmView: View {
    @Environment(CompanionState.self) private var companionState
    @Environment(\.appEnvironment) private var appEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showCreationFlow = false
    @State private var showRestoreSheet = false

    private let gridColumns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 24)
    ]

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                companionGrid
            }
            .padding(32)
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(backgroundMaterial)
        .sheet(isPresented: $showCreationFlow) {
            CompanionCreationFlow()
                .frame(minWidth: 480, minHeight: 400)
        }
        .sheet(isPresented: $showRestoreSheet) {
            CompanionRestoreSheet()
                .frame(minWidth: 400, minHeight: 320)
        }
        .onAppear {
            Task { @MainActor in
                try? await companionState.loadCompanions()
                companionState.startListeningToEvents()
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Companion Farm")
                    .font(.title2.bold())
                Text("\(companionState.companions.count) active companion(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showRestoreSheet = true
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .disabled(false)

            Button {
                showCreationFlow = true
            } label: {
                Label("Create", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var companionGrid: some View {
        if companionState.companions.isEmpty {
            emptyState
        } else {
            LazyVGrid(columns: gridColumns, spacing: 32) {
                ForEach(companionState.companions, id: \.id) { companion in
                    CompanionView(
                        companion: companion,
                        isActive: companionState.activeCompanion?.id == companion.id
                    )
                    .onTapGesture {
                        companionState.activeCompanion = companion
                        companion.lastActiveAt = Date()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Companion \(companion.name), \(companion.relativeLastActive)")
                    .accessibilityHint("Double-tap to activate.")
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Create your first companion")
                .font(.headline)

            Text("Companions help you navigate notes, summarise threads, and react to agent activity.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Button("Create Companion") {
                showCreationFlow = true
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("n", modifiers: .command)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
    }

    private var backgroundMaterial: some View {
        LinearGradient(
            colors: [
                Color(NSColor.controlBackgroundColor),
                Color(NSColor.controlBackgroundColor).opacity(0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// ---------------------------------------------------------------------------
// MARK: - Preview
// ---------------------------------------------------------------------------

#if DEBUG
#Preview {
    let state = CompanionState()
    state.companions = [
        CompanionModel(name: "Amber", baseProfile: "default", cosmeticConfig: CosmeticConfig(colorTheme: "amber", avatarShape: "orb", idleBreathingRate: 1.0)),
        CompanionModel(name: "Teal", baseProfile: "research", cosmeticConfig: CosmeticConfig(colorTheme: "teal", avatarShape: "shard", idleBreathingRate: 0.8)),
        CompanionModel(name: "Violet", baseProfile: "coding", cosmeticConfig: CosmeticConfig(colorTheme: "violet", avatarShape: "pulse", idleBreathingRate: 1.2))
    ]
    return LandingFarmView()
        .environment(state)
        .frame(width: 700, height: 500)
}
#endif
