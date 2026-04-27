import SwiftUI

/// Settings → Agent → Structures.
///
/// First reader of the orphan `StructureRegistry` abstraction. The registry
/// catalogs every `@Generable` schema in the app, the surface that produces
/// it, where it persists, the build profiles it ships in, and how mature
/// the structuring is (full / partial / raw). Without a reader the registry
/// was scaffolding — this view is the WRV-Visible counterpart.
///
/// The view is intentionally read-only. The registry is the source of
/// truth; updates happen by appending entries in `StructureRegistry.swift`,
/// not by editing UI.
///
/// Pro/MAS: filter starts at the current build profile so MAS sees only
/// what's actually shipping. The user can flip to "All" if they want to
/// see what the Pro build adds.
struct StructuredSurfacesView: View {

    private enum ProfileFilter: String, CaseIterable, Identifiable {
        case current = "This build"
        case all = "All builds"
        var id: String { rawValue }
    }

    private enum MaturitySort: String, CaseIterable, Identifiable {
        case bySurface = "Surface"
        case byMaturity = "Maturity"
        case byStorage = "Storage"
        var id: String { rawValue }
    }

    @State private var profileFilter: ProfileFilter = .current
    @State private var sort: MaturitySort = .bySurface
    @State private var query: String = ""

    // N1 Phase 1 — Prompt Tree toggle. UserDefaults-backed so the
    // user can flip the feature on without setting an env var. The
    // env var (EPISTEMOS_PROMPT_TREE=1) still wins if set; this
    // surface displays "pinned" state in that case.
    @AppStorage(PromptTreePreferences.userDefaultsKey)
    private var promptTreeEnabled: Bool = false

    /// The active build profile this binary represents.
    /// Computed once at view init via `#if EPISTEMOS_APP_STORE`.
    private static var activeProfile: BuildProfile {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        return .mas
        #else
        return .pro
        #endif
    }

    private var visibleSchemas: [StructureSchemaDescriptor] {
        let base: [StructureSchemaDescriptor]
        switch profileFilter {
        case .current:
            base = StructureRegistry.schemas(for: Self.activeProfile)
        case .all:
            base = StructureRegistry.allSchemas
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered: [StructureSchemaDescriptor] = trimmed.isEmpty
            ? base
            : base.filter { schema in
                schema.id.lowercased().contains(trimmed)
                    || schema.surface.lowercased().contains(trimmed)
                    || schema.swiftType.lowercased().contains(trimmed)
                    || schema.summary.lowercased().contains(trimmed)
            }
        switch sort {
        case .bySurface:
            return filtered.sorted { $0.surface < $1.surface }
        case .byMaturity:
            return filtered.sorted { lhs, rhs in
                Self.maturityRank(lhs.maturity) < Self.maturityRank(rhs.maturity)
            }
        case .byStorage:
            return filtered.sorted { $0.storage.rawValue < $1.storage.rawValue }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.25)
            if visibleSchemas.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(visibleSchemas) { schema in
                            row(schema)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }
            }
            Divider().opacity(0.25)
            promptTreeToggleRow
        }
    }

    /// Footer toggle for the N1 Prompt Tree (JSPF + PTF) feature flag.
    /// Lives at the bottom of the Structures tab because the Prompt
    /// itself is one of the structured surfaces this catalog tracks
    /// (see the prompt_root / prompt_identity / prompt_tools /
    /// prompt_memory / prompt_task entries in StructureRegistry).
    private var promptTreeToggleRow: some View {
        let pinnedByEnv = PromptTreePreferences.isPinnedByEnvironment()
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "tree")
                        .foregroundStyle(.secondary)
                    Text("Prompt Tree (Beta)")
                        .font(.callout.weight(.semibold))
                    if pinnedByEnv {
                        Text("env-pinned")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
                Text(pinnedByEnv
                    ? "Locked on by EPISTEMOS_PROMPT_TREE=1 environment variable. Unset the env var to use this toggle."
                    : "Routes the next agent turn through the typed Prompt composer + persists a PTF directory at <vault>/.epistemos/prompts/<session>/<turn>/. Restart the chat after toggling for changes to take effect on the next turn.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Toggle("", isOn: $promptTreeEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(pinnedByEnv)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.25))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Structured surfaces")
                    .font(.headline.weight(.semibold))
                Spacer()
                summaryCounts
            }

            Text(headerCaption)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Picker("Profile", selection: $profileFilter) {
                    ForEach(ProfileFilter.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)

                Picker("Sort", selection: $sort) {
                    ForEach(MaturitySort.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                searchField
                    .frame(maxWidth: 220)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var summaryCounts: some View {
        let totals = countsByMaturity
        return HStack(spacing: 6) {
            badge(label: "\(totals.full) full", tint: .green)
            badge(label: "\(totals.partial) partial", tint: .orange)
            badge(label: "\(totals.raw) raw", tint: .red)
        }
    }

    private var headerCaption: String {
        switch profileFilter {
        case .current:
            #if EPISTEMOS_APP_STORE || MAS_SANDBOX
            return "Schemas active in this Mac App Store (sandboxed) build."
            #else
            return "Schemas active in this Pro (Hardened Runtime) build."
            #endif
        case .all:
            return "Every schema across both build profiles."
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField("Search id / surface / type", text: $query)
                .textFieldStyle(.plain)
                .font(.caption)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func row(_ schema: StructureSchemaDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(schema.id)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                profileBadges(schema.profiles)
                maturityBadge(schema.maturity)
            }

            HStack(spacing: 14) {
                metaItem(label: "surface", value: schema.surface)
                metaItem(label: "type", value: schema.swiftType)
                metaItem(label: "storage", value: schema.storage.rawValue)
            }

            Text(schema.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }

    private func metaItem(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private func profileBadges(_ profiles: Set<BuildProfile>) -> some View {
        HStack(spacing: 4) {
            ForEach(profiles.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { p in
                Text(p.rawValue.uppercased())
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    private func maturityBadge(_ maturity: SchemaMaturity) -> some View {
        let tint = Self.maturityTint(maturity)
        return Text(maturity.rawValue.capitalized)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
            .overlay(
                Capsule().strokeBorder(tint.opacity(0.5), lineWidth: 0.5)
            )
    }

    private func badge(label: String, tint: Color) -> some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(query.isEmpty ? "No schemas registered for this filter." : "No matches for \"\(query)\".")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var countsByMaturity: (full: Int, partial: Int, raw: Int) {
        let schemas = visibleSchemas
        let full = schemas.filter { $0.maturity == .full }.count
        let partial = schemas.filter { $0.maturity == .partial }.count
        let raw = schemas.filter { $0.maturity == .raw }.count
        return (full, partial, raw)
    }

    private static func maturityRank(_ m: SchemaMaturity) -> Int {
        switch m {
        case .full: return 0
        case .partial: return 1
        case .raw: return 2
        }
    }

    private static func maturityTint(_ m: SchemaMaturity) -> Color {
        switch m {
        case .full: return .green
        case .partial: return .orange
        case .raw: return .red
        }
    }
}

#Preview {
    StructuredSurfacesView()
        .frame(width: 720, height: 480)
}
