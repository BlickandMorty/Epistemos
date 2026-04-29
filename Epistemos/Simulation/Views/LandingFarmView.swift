//
//  LandingFarmView.swift
//  Simulation Mode S5 — SwiftUI Landing Farm placement.
//
//  Per DOCTRINE §3.2 ALL companions appear here regardless of
//  activity state ("Dormant ≠ deleted"). Each companion's
//  visual reflects its `ActivityState` per the §3.2 table:
//
//    Active        full-color, soft glow halo
//    Recent        full-color, no glow
//    Dormant       desaturated 15%, slow breathing loop
//    Parked        desaturated 35%, sleeping pose, "z" emote
//    JustAcquired  rainbow-flash entrance (one-shot), then
//                  settles to Active/Dormant
//
//  S5 ships SwiftUI placeholder geometry (rounded rects with
//  palette colors + activity-driven saturation/opacity); the
//  Metal-rendered animated atlas comes at S10.
//

import SwiftUI

public struct LandingFarmView: View {
    @State private var viewModel: LandingFarmViewModel
    @State private var newCompanionName: String = ""
    @State private var selectedId: CompanionId?

    public init(viewModel: LandingFarmViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if viewModel.companions.isEmpty {
                emptyState
            } else {
                farmGrid
            }

            if let err = viewModel.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
        .padding()
        .task { await viewModel.refresh() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Landing Farm")
                .font(.title2)
                .bold()
            Spacer()
            Text("\(viewModel.companions.count) companions")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    // MARK: - Empty state — DOCTRINE §3.2 "tap to begin" affordance

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.crop.square.stack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No companions yet")
                .font(.headline)
            Text("Create your first Local Helper to begin.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                TextField("Companion name", text: $newCompanionName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)
                Button("Create") {
                    Task {
                        await viewModel.createLocalHelper(name: newCompanionName)
                        newCompanionName = ""
                    }
                }
                .disabled(newCompanionName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .padding()
    }

    // MARK: - Farm grid

    private var farmGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96, maximum: 120), spacing: 16)],
                spacing: 16
            ) {
                ForEach(viewModel.companions) { entry in
                    CompanionFarmTile(
                        entry: entry,
                        isSelected: selectedId == entry.id,
                        shouldFlash: viewModel.pendingFlashIds.contains(entry.id),
                        onSelect: { selectedId = entry.id },
                        onFlashAcknowledged: {
                            viewModel.acknowledgeFlash(entry.id)
                        }
                    )
                }
                createTile
            }
            .padding(.horizontal)
        }
    }

    private var createTile: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.secondary, style: StrokeStyle(lineWidth: 2, dash: [6]))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                )
            TextField("New name", text: $newCompanionName)
                .textFieldStyle(.plain)
                .font(.caption)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 100)
        }
        .frame(width: 96, height: 110)
        .contentShape(Rectangle())
        .onSubmit {
            Task {
                await viewModel.createLocalHelper(name: newCompanionName)
                newCompanionName = ""
            }
        }
    }
}

// MARK: - Per-companion tile

struct CompanionFarmTile: View {
    let entry: CompanionFarmEntry
    let isSelected: Bool
    let shouldFlash: Bool
    let onSelect: () -> Void
    let onFlashAcknowledged: () -> Void

    @State private var flashHue: Double = 0.0

    var body: some View {
        VStack(spacing: 6) {
            sprite
                .overlay(activityBadge, alignment: .bottomTrailing)
            Text(entry.name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 96)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onAppear {
            if shouldFlash {
                withAnimation(.linear(duration: 1.0)) {
                    flashHue = 1.0
                }
                // Acknowledge after the flash plays so it
                // doesn't replay on subsequent renders.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    onFlashAcknowledged()
                }
            }
        }
    }

    /// Placeholder sprite — rounded square in the palette colour
    /// with activity-driven saturation/opacity per DOCTRINE §3.2.
    /// S10 replaces this with the Metal-rendered atlas sprite.
    @ViewBuilder
    private var sprite: some View {
        let baseColor = paletteColor(for: entry.paletteRef)
        let appearance = activityAppearance(for: entry.activity)
        ZStack {
            // Active state: soft glow halo behind the body.
            if entry.activity == .active {
                Circle()
                    .fill(baseColor.opacity(0.35))
                    .frame(width: 84, height: 84)
                    .blur(radius: 10)
            }
            RoundedRectangle(cornerRadius: 12)
                .fill(baseColor)
                .frame(width: 64, height: 64)
                .saturation(appearance.saturation)
                .opacity(appearance.opacity)
                .overlay(
                    // JustAcquired rainbow flash overlay.
                    shouldFlash
                        ? AnyShapeStyle(
                            AngularGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                                center: .center,
                                angle: .degrees(flashHue * 360)
                            )
                        )
                        : AnyShapeStyle(Color.clear)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(width: 84, height: 84)
    }

    private var activityBadge: some View {
        Group {
            switch entry.activity {
            case .active:
                Circle().fill(.green).frame(width: 12, height: 12)
            case .recent:
                Circle().fill(.green.opacity(0.5)).frame(width: 10, height: 10)
            case .dormant:
                Circle().fill(.gray.opacity(0.4)).frame(width: 10, height: 10)
            case .parked:
                Text("z")
                    .font(.caption2.bold())
                    .foregroundStyle(.gray.opacity(0.6))
            case .justAcquired:
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(4)
    }
}

// MARK: - Palette / activity helpers

private struct ActivityAppearance {
    let saturation: Double
    let opacity: Double
}

private func activityAppearance(for state: ActivityState) -> ActivityAppearance {
    switch state {
    case .active, .recent, .justAcquired:
        return ActivityAppearance(saturation: 1.0, opacity: 1.0)
    case .dormant:
        // DOCTRINE §3.2: "desaturated 15%"
        return ActivityAppearance(saturation: 0.85, opacity: 1.0)
    case .parked:
        // DOCTRINE §3.2: "desaturated 35%"
        return ActivityAppearance(saturation: 0.65, opacity: 0.85)
    }
}

/// Palette ID → SwiftUI Color. S5 covers the V0 preset palettes
/// from DOCTRINE §10.4. Custom palettes (sRGB hex) land at S8.
private func paletteColor(for paletteRef: String) -> Color {
    switch paletteRef {
    case "claude_warm_v1":
        return Color(red: 0.85, green: 0.46, blue: 0.34) // #D97757 family
    case "kimi_indigo_v1":
        return Color(red: 0.36, green: 0.55, blue: 0.94) // #5B8DEF family
    case "codex_neutral_v1":
        return Color(white: 0.92)
    case "gpt_neutral_v1":
        return Color(white: 0.78)
    case "hermes_gold_v1":
        return Color(red: 0.83, green: 0.69, blue: 0.22)
    case "local_teal_v1":
        return Color(red: 0.20, green: 0.65, blue: 0.60)
    default:
        return Color(.systemGray)
    }
}

// MARK: - Standalone preview shell

/// Standalone wrapper for the S5 acceptance gate. Initialises a
/// CompanionRegistryBridge against a temporary vault root and
/// presents the LandingFarmView. NOT yet wired into Settings /
/// Graph view — S7 handles canonical placement.
public struct LandingFarmPreviewView: View {
    @State private var viewModel: LandingFarmViewModel?
    @State private var setupError: String?

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                LandingFarmView(viewModel: vm)
            } else if let err = setupError {
                VStack {
                    Text("Initialisation failed")
                        .font(.headline)
                    Text(err).foregroundStyle(.red)
                }
            } else {
                ProgressView("Loading registry…")
                    .task { await initialise() }
            }
        }
    }

    private func initialise() async {
        // Default vault for the preview: a per-user app
        // support directory. S5 isolates Theater + Farm
        // experimentation to this scratch vault until the real
        // workspace integration lands at S7.
        let supportDir = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let vaultRoot = supportDir
            .appendingPathComponent("Epistemos")
            .appendingPathComponent("SimulationPreviewVault")
        do {
            try FileManager.default.createDirectory(
                at: vaultRoot, withIntermediateDirectories: true
            )
        } catch {
            self.setupError = error.localizedDescription
            return
        }
        guard let bridge = CompanionRegistryBridge(vaultRoot: vaultRoot) else {
            self.setupError = "Could not open companion registry"
            return
        }
        self.viewModel = LandingFarmViewModel(bridge: bridge)
    }
}
