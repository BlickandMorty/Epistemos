import SwiftUI

enum AuthoritySettingsSovereignGate {
    enum Target: Equatable {
        case resetToDefaults
        case quickSetup(name: String)
    }

    static func requirement(for target: Target) -> SovereignGateRequirement {
        switch target {
        case .resetToDefaults, .quickSetup:
            return .deviceOwnerAuthentication
        }
    }

    static func reason(for target: Target) -> String {
        switch target {
        case .resetToDefaults:
            return "Reset authority settings to recommended defaults."
        case let .quickSetup(name):
            return "Apply authority preset \"\(name)\"."
        }
    }
}

/// User-facing Authority & Installs panel. One row per
/// AgentAuthorityCategory with a three-state picker (auto-allow / ask /
/// never). Backed by the @Observable AgentAuthorityStore so changes
/// persist across launches and other settings surfaces stay in sync.
///
/// This is the single place the user answers "what is the agent allowed to
/// do on my behalf without asking" — the existing pattern-level allow /
/// block list sits one layer down for exceptions.
struct AuthoritySettingsView: View {
    @State private var store: AgentAuthorityStore
    private let onResetConfirmed: (() -> Void)?
    // W9.8 — preview state for the SwiftUI ApprovalModalView. Lets
    // the user see what the modal looks like + tune their reaction
    // before a real agent action triggers it. Real triggers go via
    // ChatCoordinator's NSAlert path today.
    @State private var approvalPreviewPending: ApprovalModalView.PendingApproval? = nil

    init(
        store: AgentAuthorityStore,
        onResetConfirmed: (() -> Void)? = nil
    ) {
        self._store = State(initialValue: store)
        self.onResetConfirmed = onResetConfirmed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                quickSetupCard

                ForEach(visibleCategories, id: \.self) { category in
                    categoryCard(for: category)
                }

                approvalModalPreviewCard
                footer
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $approvalPreviewPending) { pending in
            ApprovalModalView(approval: pending) { _ in
                approvalPreviewPending = nil
            }
        }
    }

    /// W9.8 wire-up. Shows the SwiftUI ApprovalModalView via a
    /// preview button. Real agent-triggered approvals still flow
    /// through `ChatCoordinator.promptUserForToolApproval` (NSAlert)
    /// — this surface lets the user verify the modal renders + see
    /// the countdown ring before committing to it.
    private var approvalModalPreviewCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Approval modal preview")
                    .font(.headline)
                Text("See what the SwiftUI approval surface looks like. Real prompts still flow through the system alert; this preview lets you decide if you want to opt in to the new surface in a future build.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Show preview") {
                    approvalPreviewPending = .init(
                        sessionId: "preview-session",
                        toolName: "shell.execute",
                        argsJSON: #"{"command":"git status","cwd":"~/Downloads/Epistemos"}"#,
                        deadline: Date().addingTimeInterval(20)
                    )
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Authority & Installs")
                .font(.title2.weight(.semibold))
            Text("Decide what the agent can do without asking you first. These apply to every agent turn until you change them.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var quickSetupCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Quick Setup")
                    .font(.headline)
                Text("Apply a permission posture in one step, then fine-tune any category below.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                ForEach(visibleQuickSetupPresets) { preset in
                    Button {
                        Task { @MainActor in
                            await requestQuickSetupAuthorization(preset)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(quickSetupTitle(for: preset))
                                .font(.subheadline.weight(.semibold))
                            Text(preset.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func categoryCard(for category: AgentAuthorityCategory) -> some View {
        SettingsSurfaceCard {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.displayName)
                        .font(.headline)
                    Text(category.shortExplanation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                authorityPicker(for: category)
                    .frame(width: 150)
            }
        }
    }

    private func authorityPicker(for category: AgentAuthorityCategory) -> some View {
        let binding = Binding<AuthorityDecision>(
            get: { normalizedVisibleDecision(store.snapshot.decision(for: category), for: category) },
            set: { store.setDecision(normalizedVisibleDecision($0, for: category), for: category) }
        )

        return Picker("", selection: binding) {
            ForEach(availableDecisions(for: category), id: \.self) { decision in
                Text(decision.displayName).tag(decision)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    private var footer: some View {
        HStack(alignment: .center) {
            if let lastModified = store.snapshot.lastModified {
                Text("Last updated \(lastModified.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Using recommended defaults.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Reset to defaults") {
                Task { @MainActor in
                    await requestResetToDefaultsAuthorization()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 4)
    }

    @MainActor
    private func requestResetToDefaultsAuthorization() async {
        let target = AuthoritySettingsSovereignGate.Target.resetToDefaults
        let outcome = await AppBootstrap.shared?.sovereignGate.confirm(
            AuthoritySettingsSovereignGate.requirement(for: target),
            reason: AuthoritySettingsSovereignGate.reason(for: target)
        ) ?? .denied(.authenticationFailed)

        guard outcome == .allowed else { return }
        resetToDefaults()
    }

    @MainActor
    private func requestQuickSetupAuthorization(_ preset: AgentAuthorityQuickSetupPreset) async {
        let target = AuthoritySettingsSovereignGate.Target.quickSetup(name: quickSetupTitle(for: preset))
        let outcome = await AppBootstrap.shared?.sovereignGate.confirm(
            AuthoritySettingsSovereignGate.requirement(for: target),
            reason: AuthoritySettingsSovereignGate.reason(for: target)
        ) ?? .denied(.authenticationFailed)

        guard outcome == .allowed else { return }
        applyPreset(preset)
    }

    private func resetToDefaults() {
        store.reset()
        onResetConfirmed?()
    }

    private func applyPreset(_ preset: AgentAuthorityQuickSetupPreset) {
        let decisions = visiblePresetDecisions(preset.decisions)
        if preset == .recommended {
            store.reset(
                to: AgentAuthorityPolicySnapshot(
                    decisions: decisions,
                    lastModified: Date()
                )
            )
        } else {
            store.applyPreset(decisions)
        }
        onResetConfirmed?()
    }

    private func quickSetupTitle(for preset: AgentAuthorityQuickSetupPreset) -> String {
        switch preset {
        case .recommended:
            return "Recommended"
        case .lessInterruptions:
            return "Less Interruptions"
        case .cautious:
            return "Review More"
        }
    }

    private var visibleCategories: [AgentAuthorityCategory] {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        AgentAuthorityCategory.allCases.filter(\.isVisibleInAppStoreAuthority)
        #else
        AgentAuthorityCategory.allCases
        #endif
    }

    private var visibleQuickSetupPresets: [AgentAuthorityQuickSetupPreset] {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        AgentAuthorityQuickSetupPreset.allCases.filter { $0 != .lessInterruptions }
        #else
        AgentAuthorityQuickSetupPreset.allCases
        #endif
    }

    private func availableDecisions(for category: AgentAuthorityCategory) -> [AuthorityDecision] {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        category.appStoreAuthorityDecisions
        #else
        AuthorityDecision.allCases
        #endif
    }

    private func normalizedVisibleDecision(
        _ decision: AuthorityDecision,
        for category: AgentAuthorityCategory
    ) -> AuthorityDecision {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        return category.normalizedAppStoreDecision(decision)
        #else
        return decision
        #endif
    }

    private func visiblePresetDecisions(
        _ decisions: [AgentAuthorityCategory: AuthorityDecision]
    ) -> [AgentAuthorityCategory: AuthorityDecision] {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        var filtered: [AgentAuthorityCategory: AuthorityDecision] = [:]
        for category in visibleCategories {
            let decision = decisions[category] ?? store.snapshot.decision(for: category)
            filtered[category] = category.normalizedAppStoreDecision(decision)
        }
        return filtered
        #else
        return decisions
        #endif
    }
}

#Preview("Authority Settings") {
    AuthoritySettingsView(store: AgentAuthorityStore())
        .frame(width: 680, height: 640)
}

#if EPISTEMOS_APP_STORE || MAS_SANDBOX
private extension AgentAuthorityCategory {
    var isVisibleInAppStoreAuthority: Bool {
        switch self {
        case .vaultRead,
             .vaultWrite,
             .outOfVaultFileAccess,
             .networkFetch,
             .downloadArtifact,
             .destructiveFileOp,
             .systemProtected:
            return true
        case .gitOperation,
             .packageInstall,
             .runDownloadedScript,
             .externalAppAutomation:
            return false
        }
    }

    var appStoreAuthorityDecisions: [AuthorityDecision] {
        switch self {
        case .vaultRead,
             .vaultWrite,
             .networkFetch,
             .downloadArtifact:
            return AuthorityDecision.allCases
        case .outOfVaultFileAccess,
             .destructiveFileOp:
            return [.askFirst, .neverAllow]
        case .systemProtected:
            return [.neverAllow]
        case .gitOperation,
             .packageInstall,
             .runDownloadedScript,
             .externalAppAutomation:
            return [.neverAllow]
        }
    }

    func normalizedAppStoreDecision(_ decision: AuthorityDecision) -> AuthorityDecision {
        appStoreAuthorityDecisions.contains(decision)
            ? decision
            : appStoreAuthorityDecisions.first ?? .askFirst
    }
}
#endif
