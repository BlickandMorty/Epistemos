//
//  CompanionCreationFlow.swift
//  Simulation Mode S8 — sheet UI for the §6.1 8-step companion
//  creation wizard.
//
//  Per IMPLEMENTATION §S8 the flow uses a typed
//  `NavigationStack(path:)` with a compile-time `CreationStepRoute`
//  enum — no `AnyView`, no string-keyed dispatch (DOCTRINE I-15).
//  Each step renders its inputs alongside the live
//  `CompanionPreviewView` so the user sees the composed sprite
//  update per pick.
//

import SwiftUI

public struct CompanionCreationFlow: View {
    @State public var viewModel: CreationFlowViewModel
    public let dismiss: () -> Void

    public init(viewModel: CreationFlowViewModel, dismiss: @escaping () -> Void) {
        self._viewModel = State(initialValue: viewModel)
        self.dismiss = dismiss
    }

    public var body: some View {
        NavigationStack(path: $viewModel.route) {
            CreationPresetPickStep(viewModel: viewModel, advance: advance)
                .navigationDestination(for: CreationStepRoute.self) { route in
                    stepView(for: route)
                }
        }
        .onChange(of: viewModel.lastCreatedId) { _, newValue in
            if newValue != nil {
                dismiss()
            }
        }
        .frame(minWidth: 640, minHeight: 480)
    }

    @ViewBuilder
    private func stepView(for route: CreationStepRoute) -> some View {
        switch route {
        case .presetPick:
            // Root step is rendered above; this branch is unreachable
            // but the switch must be exhaustive over the enum.
            EmptyView()
        case .headShape:
            CreationHeadShapeStep(viewModel: viewModel, advance: advance)
        case .palette:
            CreationPaletteStep(viewModel: viewModel, advance: advance)
        case .eyes:
            CreationEyesStep(viewModel: viewModel, advance: advance)
        case .arms:
            CreationArmsStep(viewModel: viewModel, advance: advance)
        case .prop:
            CreationPropStep(viewModel: viewModel, advance: advance)
        case .workspace:
            CreationWorkspaceStep(viewModel: viewModel, advance: advance)
        case .name:
            CreationNameStep(viewModel: viewModel, advance: advance)
        case .review:
            CreationReviewStep(viewModel: viewModel, dismiss: dismiss)
        }
    }

    private func advance() {
        viewModel.advance()
    }
}

// MARK: - Step chrome

/// Common per-step shell — title bar, live preview, content,
/// next/cancel buttons. Reduces duplication across the 9 step
/// views.
private struct StepShell<Content: View>: View {
    let route: CreationStepRoute
    let viewModel: CreationFlowViewModel
    let content: Content
    let advance: () -> Void

    init(
        _ route: CreationStepRoute,
        viewModel: CreationFlowViewModel,
        @ViewBuilder content: () -> Content,
        advance: @escaping () -> Void
    ) {
        self.route = route
        self.viewModel = viewModel
        self.content = content()
        self.advance = advance
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            progressStrip
            HStack(alignment: .top, spacing: 24) {
                CompanionPreviewView(
                    headShape: viewModel.headShape,
                    paletteHex: viewModel.paletteRef.isEmpty
                        ? viewModel.customPaletteHex
                        : viewModel.paletteRef,
                    eyes: viewModel.eyes,
                    arms: viewModel.arms,
                    prop: viewModel.prop
                )
                .padding(.top, 8)
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            navButtons
        }
        .padding(20)
        .navigationTitle("Step \(route.stepNumber). \(route.label)")
    }

    private var progressStrip: some View {
        HStack(spacing: 4) {
            ForEach(CreationStepRoute.sequence.dropLast(), id: \.self) { step in
                Capsule()
                    .fill(step.stepNumber <= route.stepNumber
                          ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(height: 3)
            }
        }
    }

    private var navButtons: some View {
        HStack {
            Button("Back") {
                viewModel.pop()
            }
            .disabled(route == .presetPick)
            Spacer()
            Button(route == .review ? "Create" : "Next") {
                advance()
            }
            .disabled(!viewModel.isStepValid(route))
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Step views

private struct CreationPresetPickStep: View {
    @Bindable var viewModel: CreationFlowViewModel
    let advance: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Begin from a preset")
                .font(.title2.weight(.semibold))
            Text("Pick a starting point — every axis is editable in the next 7 steps.")
                .font(.callout)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(PresetCatalog.all) { preset in
                    presetTile(preset)
                }
            }
            Spacer()
            HStack {
                Spacer()
                Button("Next") {
                    advance()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .navigationTitle("Step 1. Start")
    }

    private func presetTile(_ preset: CompanionPreset) -> some View {
        let isSelected = viewModel.selectedPreset == preset.id
        return Button {
            viewModel.applyPreset(preset.id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(brandColor(preset.brandHex))
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.displayName)
                        .font(.system(size: 13, weight: .semibold))
                    Text(preset.blurb)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected
                          ? Color.accentColor.opacity(0.15)
                          : Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func brandColor(_ hex: String) -> Color {
        // Same lenient hex parse the preview uses.
        guard hex.count == 7, hex.first == "#" else { return .gray }
        var r: UInt64 = 0, g: UInt64 = 0, b: UInt64 = 0
        _ = Scanner(string: String(hex.dropFirst().prefix(2))).scanHexInt64(&r)
        _ = Scanner(string: String(hex.dropFirst(3).prefix(2))).scanHexInt64(&g)
        _ = Scanner(string: String(hex.dropFirst(5).prefix(2))).scanHexInt64(&b)
        return Color(red: Double(r)/255.0, green: Double(g)/255.0, blue: Double(b)/255.0)
    }
}

private struct CreationHeadShapeStep: View {
    @Bindable var viewModel: CreationFlowViewModel
    let advance: () -> Void

    var body: some View {
        StepShell(.headShape, viewModel: viewModel, content: {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pick the body family.")
                    .font(.headline)
                Picker("Head shape", selection: $viewModel.headShape) {
                    Text("Block").tag("Block")
                    Text("Sage (humanoid)").tag("Sage")
                    Text("Orb").tag("Orb")
                }
                .pickerStyle(.radioGroup)
            }
        }, advance: advance)
    }
}

private struct CreationPaletteStep: View {
    @Bindable var viewModel: CreationFlowViewModel
    let advance: () -> Void

    private static let curated: [(slug: String, label: String, hex: String)] = [
        ("claude_warm_v1", "Claude warm", "#D97757"),
        ("kimi_indigo_v1", "Kimi indigo", "#5B8DEF"),
        ("local_teal_v1",  "Local teal",  "#2BA59B"),
        ("gpt_neutral_v1", "GPT neutral", "#9C9C9C"),
    ]

    var body: some View {
        StepShell(.palette, viewModel: viewModel, content: {
            VStack(alignment: .leading, spacing: 12) {
                Text("Curated palettes")
                    .font(.headline)
                ForEach(Self.curated, id: \.slug) { (slug, label, hex) in
                    HStack {
                        Circle()
                            .fill(Color(red: 0.2, green: 0.2, blue: 0.2))
                            .overlay(Circle().fill(Color.gray))
                            .frame(width: 16, height: 16)
                        Text(label)
                        Spacer()
                        Text(hex)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.paletteRef = slug
                        viewModel.customPaletteHex = ""
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(viewModel.paletteRef == slug
                                  ? Color.accentColor.opacity(0.12)
                                  : .clear)
                    )
                }
                Divider().padding(.vertical, 4)
                Text("Custom hex")
                    .font(.headline)
                HStack {
                    TextField("#RRGGBB", text: $viewModel.customPaletteHex)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            if !viewModel.customPaletteHex.isEmpty {
                                viewModel.paletteRef = ""
                            }
                        }
                        .onChange(of: viewModel.customPaletteHex) { _, newValue in
                            if !newValue.isEmpty {
                                viewModel.paletteRef = ""
                            }
                        }
                }
                if !viewModel.customPaletteHex.isEmpty
                    && !CreationFlowViewModel.isValidHex(viewModel.customPaletteHex)
                {
                    Text("Hex must be `#RRGGBB`.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }, advance: advance)
    }
}

private struct CreationEyesStep: View {
    @Bindable var viewModel: CreationFlowViewModel
    let advance: () -> Void

    var body: some View {
        StepShell(.eyes, viewModel: viewModel, content: {
            VStack(alignment: .leading, spacing: 12) {
                Text("Eye style")
                    .font(.headline)
                Picker("Eyes", selection: $viewModel.eyes) {
                    Text("Round").tag("Round")
                    Text("Slit").tag("Slit")
                    Text("Visor").tag("Visor")
                    Text("Closed").tag("Closed")
                    Text("Negative space (cutout)").tag("NegativeSpace")
                }
                .pickerStyle(.radioGroup)
            }
        }, advance: advance)
    }
}

private struct CreationArmsStep: View {
    @Bindable var viewModel: CreationFlowViewModel
    let advance: () -> Void

    var body: some View {
        StepShell(.arms, viewModel: viewModel, content: {
            VStack(alignment: .leading, spacing: 12) {
                Text("Arm style")
                    .font(.headline)
                Picker("Arms", selection: $viewModel.arms) {
                    Text("None").tag("None")
                    Text("Short").tag("Short")
                    Text("Long").tag("Long")
                }
                .pickerStyle(.radioGroup)
            }
        }, advance: advance)
    }
}

private struct CreationPropStep: View {
    @Bindable var viewModel: CreationFlowViewModel
    let advance: () -> Void

    private static let props: [(slug: String, label: String, blurb: String)] = [
        ("Wrench", "Wrench", "code edit / git / tests"),
        ("Scroll", "Scroll", "notes / docs"),
        ("Magnifier", "Magnifier", "search"),
        ("Folder", "Folder", "vault read/write"),
        ("Baton", "Baton", "routing / delegate"),
        ("Lantern", "Lantern", "deep think"),
    ]

    var body: some View {
        StepShell(.prop, viewModel: viewModel, content: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tool affinity prop")
                    .font(.headline)
                Text("Each prop pre-fills a default tool affinity bitset (DOCTRINE §5.5 Category A).")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(Self.props, id: \.slug) { item in
                    HStack {
                        Text(item.label).bold()
                        Spacer()
                        Text(item.blurb).foregroundStyle(.secondary).font(.caption)
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 4)
                    .onTapGesture { viewModel.prop = item.slug }
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(viewModel.prop == item.slug
                                  ? Color.accentColor.opacity(0.12)
                                  : .clear)
                    )
                }
                Toggle("No prop", isOn: Binding(
                    get: { viewModel.prop == nil },
                    set: { viewModel.prop = $0 ? nil : "Wrench" }
                ))
                .padding(.top, 6)
            }
        }, advance: advance)
    }
}

private struct CreationWorkspaceStep: View {
    @Bindable var viewModel: CreationFlowViewModel
    let advance: () -> Void

    var body: some View {
        StepShell(.workspace, viewModel: viewModel, content: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Vault folder")
                    .font(.headline)
                Text("Path under your vault root. Empty = `Companions/<name>` (recommended).")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Companions/<name>", text: $viewModel.vaultSubpath)
                    .textFieldStyle(.roundedBorder)
                if viewModel.vaultSubpath.contains("..") {
                    Text("`..` is forbidden — paths can't escape the vault root.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }, advance: advance)
    }
}

private struct CreationNameStep: View {
    @Bindable var viewModel: CreationFlowViewModel
    let advance: () -> Void

    var body: some View {
        StepShell(.name, viewModel: viewModel, content: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.headline)
                Text("Display label + the registry's UNIQUE constraint key. ≤ 64 chars; no `/`, `\\`, `\\0`.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Sage Reviewer", text: $viewModel.name)
                    .textFieldStyle(.roundedBorder)
                if !viewModel.name.isEmpty,
                   !viewModel.isStepValid(.name)
                {
                    Text("Invalid name — empty / too long / contains forbidden character.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }, advance: advance)
    }
}

private struct CreationReviewStep: View {
    @Bindable var viewModel: CreationFlowViewModel
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 24) {
                CompanionPreviewView(
                    headShape: viewModel.headShape,
                    paletteHex: viewModel.paletteRef.isEmpty
                        ? viewModel.customPaletteHex
                        : viewModel.paletteRef,
                    eyes: viewModel.eyes,
                    arms: viewModel.arms,
                    prop: viewModel.prop
                )
                VStack(alignment: .leading, spacing: 4) {
                    row("Name", viewModel.name)
                    row("Head", viewModel.headShape)
                    row("Palette", viewModel.paletteRef.isEmpty
                        ? viewModel.customPaletteHex
                        : viewModel.paletteRef)
                    row("Eyes", viewModel.eyes)
                    row("Arms", viewModel.arms)
                    row("Prop", viewModel.prop ?? "(none)")
                    row("Role", viewModel.role)
                    row("Base model", viewModel.baseModel)
                    row("Workspace",
                        viewModel.vaultSubpath.isEmpty
                            ? "Companions/\(viewModel.name)"
                            : viewModel.vaultSubpath)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let err = viewModel.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
            HStack {
                Button("Back") { viewModel.pop() }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") {
                    Task { await viewModel.submit() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSubmitting || !viewModel.isStepValid(.review))
            }
        }
        .padding(20)
        .navigationTitle("Step 9. Review")
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary).frame(width: 96, alignment: .leading)
            Text(value).font(.system(.body, design: .monospaced))
        }
    }
}

// MARK: - Standalone preview shell

public struct CompanionCreationPreviewView: View {
    @State private var bridge: CompanionRegistryBridge?
    @State private var viewModel: CreationFlowViewModel?
    @State private var setupError: String?
    @State private var dismissed = false

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                CompanionCreationFlow(viewModel: vm) {
                    dismissed = true
                }
            } else if let err = setupError {
                VStack {
                    Text("Initialisation failed").font(.headline)
                    Text(err).foregroundStyle(.red)
                }
            } else {
                ProgressView("Loading registry…")
                    .task { await initialise() }
            }
        }
    }

    @MainActor
    private func initialise() async {
        let supportDir = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let vaultRoot = supportDir
            .appendingPathComponent("Epistemos")
            .appendingPathComponent("CreationPreviewVault")
        do {
            try FileManager.default.createDirectory(
                at: vaultRoot, withIntermediateDirectories: true
            )
        } catch {
            self.setupError = error.localizedDescription
            return
        }
        guard let b = CompanionRegistryBridge(vaultRoot: vaultRoot) else {
            self.setupError = "Could not open companion registry"
            return
        }
        self.bridge = b
        self.viewModel = CreationFlowViewModel(bridge: b)
    }
}
