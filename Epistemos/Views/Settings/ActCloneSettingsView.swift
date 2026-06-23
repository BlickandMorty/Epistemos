import SwiftUI
#if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
import OsaurusCore
#endif

/// PER-CLONE SETTINGS (owner 2026-06-21) — the "Act (Osaurus)" clone's Epistemos-native
/// settings surface. Act = the full Osaurus engine (OsaurusCore, in-process). This panel
/// surfaces the clone's gate + REAL engine status (`ActOsaurusHealthRow` shows OsaurusCore's live
/// `CoreModelService` status) + current configuration. The act MODEL selection — incl. the owner's "Epistemos
/// Picks" — lives under Models (shared composer). First per-clone tab; work = OpenCode is next.
/// Standing rule: each clone is its OWN app with its OWN settings — preserved + reachable, not flattened.
struct ActCloneSettingsView: View {
    @Environment(InferenceState.self) private var inference
    #if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
    @State private var osaurusModelRows: [EpistemosOsaurusModelPick] = []
    @State private var selectedOsaurusModelID: String?
    @State private var actSettingsSnapshot: EpistemosOsaurusActSettingsSnapshot?
    @State private var osaurusQuickActions: [EpistemosOsaurusQuickAction] = []
    @State private var systemPermissionRows: [EpistemosOsaurusSystemPermissionRow] = []
    @State private var toolPermissionRows: [EpistemosOsaurusToolPermissionRow] = []
    @State private var toolPermissionOptions: [EpistemosOsaurusPolicyOption] = []
    @State private var computerUsePolicySnapshot: EpistemosOsaurusComputerUsePolicySnapshot?
    @State private var computerUsePolicyOptions: [EpistemosOsaurusPolicyOption] = []
    @State private var computerUseAllowlistDraft = ""
    @State private var isChoosingWorkingFolder = false
    @State private var isRunningSandboxAction = false
    @State private var sandboxActionError: String?
    @State private var sandboxDiagnostics: [EpistemosOsaurusSandboxDiagnosticRow] = []
    @State private var providerRuntimeSnapshot: EpistemosOsaurusProviderRuntimeSnapshot?
    @State private var privacyFilterSnapshot: EpistemosOsaurusPrivacyFilterSnapshot?
    @State private var dependencySnapshot: EpistemosOsaurusDependencySnapshot?
    @State private var isRunningProviderAction = false
    @State private var isRepairingDependencies = false
    @State private var providerActionError: String?
    @State private var dependencyActionError: String?
    @State private var presentedNativeSurface: ActNativeOsaurusSurface?

    private var allManagementEntries: [EpistemosOsaurusManagementEntry] {
        EpistemosOsaurusManagementBridge.managementEntries()
    }
    #endif

    var body: some View {
        Form {
            Section {
                SettingsDescriptionText(
                    text: "Act runs through the full Osaurus engine in-process (OsaurusCore), while Epistemos "
                    + "owns the native settings chrome, model picker, commands, permissions, and visible chat UI. "
                    + "The Pro / direct-distribution build routes Act through Osaurus honestly, with no silent cloud route."
                )
                ActOsaurusHealthRow()
            } header: {
                Text("Act = Osaurus engine")
            } footer: {
                Text("Each clone keeps its own settings. The visible controls stay in Epistemos chrome while Osaurus owns Act's engine, tools, models, and runtime configuration.")
            }

            #if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
            Section {
                if let snapshot = actSettingsSnapshot {
                    LabeledContent("Selected model") {
                        Text(snapshot.selectedModelDisplayName ?? snapshot.selectedModelID ?? "Not selected")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    LabeledContent("Working folder") {
                        Text(snapshot.globalWorkingFolderPath ?? "No folder selected")
                            .foregroundStyle(snapshot.globalWorkingFolderPath == nil ? .tertiary : .secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    HStack {
                        Button {
                            Task { await chooseGlobalWorkingFolder() }
                        } label: {
                            Label(
                                snapshot.globalWorkingFolderPath == nil ? "Choose Working Folder" : "Change Working Folder",
                                systemImage: "folder.badge.plus"
                            )
                        }
                        .disabled(isChoosingWorkingFolder)

                        if snapshot.globalWorkingFolderPath != nil {
                            Button(role: .destructive) {
                                clearGlobalWorkingFolder()
                            } label: {
                                Label("Clear Folder", systemImage: "xmark.circle")
                            }
                        }
                    }
                } else {
                    ProgressView("Loading Act runtime controls")
                }
            } header: {
                Text("Act runtime controls")
            } footer: {
                Text("These controls write to OsaurusCore directly: the same model, folder, memory, tool, and policy state used by Act turns.")
            }

            Section {
                Toggle(
                    isOn: Binding(
                        get: { actSettingsSnapshot?.toolsEnabled ?? false },
                        set: { setDefaultAgentToolsEnabled($0) }
                    )
                ) {
                    Label("Tools", systemImage: "wrench.and.screwdriver.fill")
                }
                .disabled(actSettingsSnapshot == nil)

                Toggle(
                    isOn: Binding(
                        get: { actSettingsSnapshot?.memoryEnabled ?? false },
                        set: { setMemoryEnabled($0) }
                    )
                ) {
                    Label("Memory", systemImage: "brain.head.profile.fill")
                }
                .disabled(actSettingsSnapshot == nil)

                Picker(
                    "Tool selection",
                    selection: Binding(
                        get: { actSettingsSnapshot?.toolSelectionModeID ?? "auto" },
                        set: { setToolSelectionMode($0) }
                    )
                ) {
                    Text("Auto-discover").tag("auto")
                    Text("Manual allowlist").tag("manual")
                }
                .disabled(actSettingsSnapshot == nil)

                if let snapshot = actSettingsSnapshot {
                    ActOsaurusSettingsMetricRow(
                        title: "Tool catalog",
                        value: toolCatalogLabel(snapshot),
                        systemImage: "wrench.and.screwdriver.fill"
                    )
                    ActOsaurusSettingsMetricRow(
                        title: "Skill library",
                        value: skillCatalogLabel(snapshot),
                        systemImage: "sparkles"
                    )
                    ActOsaurusSettingsMetricRow(
                        title: "Memory mode",
                        value: "\(snapshot.memoryModeLabel) - \(snapshot.memoryBudgetLabel)",
                        systemImage: "brain.head.profile.fill"
                    )
                    ActOsaurusSettingsMetricRow(
                        title: "Sandbox",
                        value: "\(snapshot.sandboxStatusLabel) - \(snapshot.sandboxAvailabilityLabel)",
                        systemImage: "shippingbox.fill"
                    )
                    ActOsaurusSettingsMetricRow(
                        title: "Computer Use",
                        value: "\(snapshot.computerUsePolicyLabel) - \(snapshot.computerUseAllowlistLabel)",
                        systemImage: "cursorarrow.rays"
                    )
                }
            } header: {
                Text("Act capabilities")
            } footer: {
                Text("The main chat, mini chat, graph chat, and note chat all read this same Act capability state when Osaurus mode is active.")
            }

            Section {
                if let providerRuntimeSnapshot {
                    Toggle(
                        isOn: Binding(
                            get: { providerRuntimeSnapshot.osaurusRouterEnabled },
                            set: { setOsaurusRouterEnabled($0) }
                        )
                    ) {
                        Label("Osaurus Router", systemImage: "sparkles")
                    }

                    ActOsaurusSettingsMetricRow(
                        title: "Model providers",
                        value: "\(providerRuntimeSnapshot.remoteConnectedCount)/\(providerRuntimeSnapshot.remoteEnabledCount) connected - \(providerRuntimeSnapshot.remoteModelCount) models",
                        systemImage: "cloud.fill"
                    )
                    ActOsaurusSettingsMetricRow(
                        title: "Provider state",
                        value: "\(providerRuntimeSnapshot.remoteProviderCount) configured - \(providerRuntimeSnapshot.remoteConnectingCount) connecting - \(providerRuntimeSnapshot.remoteErrorCount) errors",
                        systemImage: "network"
                    )

                    HStack {
                        Button {
                            Task { await connectRemoteProviders() }
                        } label: {
                            Label("Connect Providers", systemImage: "bolt.horizontal.circle")
                        }
                        .disabled(isRunningProviderAction)

                        Button {
                            disconnectRemoteProviders()
                        } label: {
                            Label("Disconnect Providers", systemImage: "bolt.slash.circle")
                        }
                        .disabled(isRunningProviderAction)
                    }

                    ActOsaurusSettingsMetricRow(
                        title: "MCP tool servers",
                        value: "\(providerRuntimeSnapshot.mcpConnectedCount)/\(providerRuntimeSnapshot.mcpEnabledCount) connected - \(providerRuntimeSnapshot.mcpDiscoveredToolCount) tools",
                        systemImage: "server.rack"
                    )
                    ActOsaurusSettingsMetricRow(
                        title: "MCP state",
                        value: "\(providerRuntimeSnapshot.mcpProviderCount) configured - \(providerRuntimeSnapshot.mcpConnectingCount) connecting - \(providerRuntimeSnapshot.mcpAuthNeededCount) auth - \(providerRuntimeSnapshot.mcpErrorCount) errors",
                        systemImage: "point.3.connected.trianglepath.dotted"
                    )

                    HStack {
                        Button {
                            Task { await connectMCPProviders() }
                        } label: {
                            Label("Connect MCP", systemImage: "link.circle")
                        }
                        .disabled(isRunningProviderAction)

                        Button {
                            disconnectMCPProviders()
                        } label: {
                            Label("Disconnect MCP", systemImage: "link.circle.fill")
                        }
                        .disabled(isRunningProviderAction)
                    }

                    if isRunningProviderAction {
                        ProgressView("Updating provider connections")
                    }

                    if let providerActionError {
                        Label(providerActionError, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } else {
                    ProgressView("Loading provider controls")
                }

                HStack {
                    Button {
                        presentNativeSurface(
                            title: "Provider Details",
                            subtitle: "Remote providers, Osaurus Router, API keys, and model access.",
                            systemImage: "key.fill",
                            tabID: "providers"
                        )
                    } label: {
                        Label("Provider Details", systemImage: "key.fill")
                    }
                    Button {
                        presentNativeSurface(
                            title: "MCP Tool Details",
                            subtitle: "MCP tool servers, connection state, and discovered tools.",
                            systemImage: "wrench.and.screwdriver.fill",
                            tabID: "tools"
                        )
                    } label: {
                        Label("MCP Tool Details", systemImage: "wrench.and.screwdriver.fill")
                    }
                }
            } header: {
                Text("Providers and MCP")
            } footer: {
                Text("These buttons call the real Osaurus provider managers used by Act: model providers, Osaurus Router, and MCP tool servers.")
            }

            Section {
                if let snapshot = actSettingsSnapshot {
                    ActOsaurusSettingsMetricRow(
                        title: "Sandbox status",
                        value: "\(snapshot.sandboxStatusLabel) - \(snapshot.sandboxAvailabilityLabel)",
                        systemImage: "shippingbox.fill"
                    )

                    HStack {
                        Button {
                            Task { await provisionSandbox() }
                        } label: {
                            Label("Set Up Sandbox", systemImage: "shippingbox")
                        }
                        .disabled(isRunningSandboxAction)

                        if snapshot.sandboxRunning {
                            Button {
                                Task { await stopSandbox() }
                            } label: {
                                Label("Stop", systemImage: "stop.fill")
                            }
                            .disabled(isRunningSandboxAction)
                        } else {
                            Button {
                                Task { await startSandbox() }
                            } label: {
                                Label("Start", systemImage: "play.fill")
                            }
                            .disabled(isRunningSandboxAction || !snapshot.sandboxAvailable)
                        }

                        Button {
                            Task { await runSandboxDiagnostics() }
                        } label: {
                            Label("Run Diagnostics", systemImage: "stethoscope")
                        }
                        .disabled(isRunningSandboxAction || !snapshot.sandboxAvailable)
                    }

                    if isRunningSandboxAction {
                        ProgressView("Updating sandbox")
                    }

                    if let sandboxActionError {
                        Label(sandboxActionError, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if !sandboxDiagnostics.isEmpty {
                        ForEach(sandboxDiagnostics) { row in
                            ActSandboxDiagnosticNativeRow(row: row)
                        }
                    }
                } else {
                    ProgressView("Loading sandbox controls")
                }

                Button {
                    presentNativeSurface(
                        title: "Sandbox Details",
                        subtitle: "VM lifecycle, provisioning, diagnostics, and dependency state.",
                        systemImage: "shippingbox.fill",
                        tabID: "sandbox"
                    )
                } label: {
                    Label("Open Full Sandbox Details", systemImage: "shippingbox.fill")
                }
            } header: {
                Text("Sandbox and VM controls")
            } footer: {
                Text("These buttons call Osaurus's real sandbox lifecycle: VM provisioning, start/stop, and diagnostics.")
            }

            Section {
                if systemPermissionRows.isEmpty {
                    ProgressView("Loading permission state")
                } else {
                    ForEach(systemPermissionRows) { row in
                        ActSystemPermissionNativeRow(
                            row: row,
                            onGrant: { requestSystemPermission(row.id) },
                            onOpenSettings: { openSystemPermissionSettings(row.id) }
                        )
                    }
                }

                HStack {
                    Button {
                        refreshSystemPermissions()
                    } label: {
                        Label("Refresh Permissions", systemImage: "arrow.clockwise")
                    }
                    Button {
                        presentNativeSurface(
                            title: "All Permission Details",
                            subtitle: "macOS permissions, grants, and approval state used by Act.",
                            systemImage: "lock.shield.fill",
                            tabID: "permissions"
                        )
                    } label: {
                        Label("All Permission Details", systemImage: "lock.shield.fill")
                    }
                }
            } header: {
                Text("Native permission rows")
            } footer: {
                Text("These are Osaurus's macOS permission checks and grant actions, rendered directly in the Epistemos Act settings tab.")
            }

            Section {
                if toolPermissionRows.isEmpty {
                    ProgressView("Loading tool approval policies")
                } else {
                    ForEach(toolPermissionRows) { row in
                        ActToolPermissionNativeRow(
                            row: row,
                            options: toolPermissionOptions,
                            onPolicyChange: { policyID in
                                setToolPermissionPolicy(toolName: row.id, policyID: policyID)
                            },
                            onReset: {
                                resetToolPermissionPolicy(toolName: row.id)
                            }
                        )
                    }
                }
                Button {
                    presentNativeSurface(
                        title: "Full Tool Registry",
                        subtitle: "Tool approval policies and callable Osaurus tools.",
                        systemImage: "wrench.and.screwdriver.fill",
                        tabID: "tools"
                    )
                } label: {
                    Label("Open Full Tool Registry", systemImage: "wrench.and.screwdriver.fill")
                }
            } header: {
                Text("Tool approval policy")
            } footer: {
                Text("Auto, ask, and deny write to Osaurus's real tool registry, including shell, file, plugin, MCP, and configuration tools.")
            }

            Section {
                if let computerUsePolicySnapshot {
                    Picker(
                        "Autonomy",
                        selection: Binding(
                            get: { computerUsePolicySnapshot.globalPresetID },
                            set: { setComputerUseGlobalPreset($0) }
                        )
                    ) {
                        ForEach(computerUsePolicyOptions) { option in
                            Text(option.label).tag(option.id)
                        }
                    }

                    ActOsaurusSettingsMetricRow(
                        title: "Policy detail",
                        value: computerUsePolicySnapshot.globalPresetDetail,
                        systemImage: "slider.horizontal.3"
                    )
                    ActOsaurusSettingsMetricRow(
                        title: "Per-app overrides",
                        value: "\(computerUsePolicySnapshot.perAppOverrideCount)",
                        systemImage: "app.connected.to.app.below.fill"
                    )

                    TextField("Allowed apps, comma separated. Empty allows all apps.", text: $computerUseAllowlistDraft)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button {
                            saveComputerUseAllowlist()
                        } label: {
                            Label("Save App Allowlist", systemImage: "checkmark.circle")
                        }
                        Button {
                            computerUseAllowlistDraft = ""
                            saveComputerUseAllowlist()
                        } label: {
                            Label("Allow All Apps", systemImage: "infinity")
                        }
                    }
                } else {
                    ProgressView("Loading Computer Use policy")
                }
                Button {
                    presentNativeSurface(
                        title: "Computer Use Details",
                        subtitle: "Action confirmations, autonomy, and app allowlist.",
                        systemImage: "cursorarrow.rays",
                        tabID: "computerUse"
                    )
                } label: {
                    Label("Open Computer Use Details", systemImage: "cursorarrow.rays")
                }
            } header: {
                Text("Computer Use prompts")
            } footer: {
                Text("This controls the same confirmation model that pauses Osaurus before clicking, typing, editing, submitting, deleting, or driving apps.")
            }

            Section {
                if let privacyFilterSnapshot {
                    Toggle(
                        isOn: Binding(
                            get: { privacyFilterSnapshot.enabled },
                            set: { setPrivacyFilterEnabled($0) }
                        )
                    ) {
                        Label("Privacy Filter", systemImage: "hand.raised.fill")
                    }

                    Toggle(
                        isOn: Binding(
                            get: { privacyFilterSnapshot.skipCodeBlocks },
                            set: { setPrivacyFilterSkipCodeBlocks($0) }
                        )
                    ) {
                        Label("Skip Code Blocks", systemImage: "curlybraces")
                    }

                    Toggle(
                        isOn: Binding(
                            get: { privacyFilterSnapshot.requireReviewForNonInteractive },
                            set: { setPrivacyFilterRequireInteractiveReview($0) }
                        )
                    ) {
                        Label("Require Review for Background Sends", systemImage: "exclamationmark.shield.fill")
                    }

                    Toggle(
                        isOn: Binding(
                            get: { privacyFilterSnapshot.alwaysApproveByDefault },
                            set: { setPrivacyFilterAlwaysApprove($0) }
                        )
                    ) {
                        Label("Approve After First Review", systemImage: "checkmark.shield.fill")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Detection threshold") {
                            Text("\(Int(privacyFilterSnapshot.confidenceThreshold * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(privacyFilterSnapshot.confidenceThreshold) },
                                set: { setPrivacyFilterConfidenceThreshold(Float($0)) }
                            ),
                            in: 0 ... 1,
                            step: 0.05
                        )
                    }

                    ActOsaurusSettingsMetricRow(
                        title: "Built-in patterns",
                        value: "\(privacyFilterSnapshot.enabledBuiltinPatternCount)/\(privacyFilterSnapshot.builtinPatternCount) enabled",
                        systemImage: "text.magnifyingglass"
                    )
                    ActOsaurusSettingsMetricRow(
                        title: "Custom privacy rules",
                        value: "\(privacyFilterSnapshot.customRuleCount) custom - \(privacyFilterSnapshot.enabledPresetRuleCount) presets",
                        systemImage: "list.bullet.rectangle"
                    )
                } else {
                    ProgressView("Loading privacy controls")
                }

                Button {
                    presentNativeSurface(
                        title: "Privacy Details",
                        subtitle: "Redaction, review policy, and local privacy rules.",
                        systemImage: "hand.raised.fill",
                        tabID: "privacy"
                    )
                } label: {
                    Label("Open Privacy Details", systemImage: "hand.raised.fill")
                }
            } header: {
                Text("Privacy filter")
            } footer: {
                Text("This is Osaurus's real redaction policy for provider sends and non-interactive Act runs, rendered directly in Epistemos settings.")
            }

            Section {
                if let dependencySnapshot {
                    ActOsaurusSettingsMetricRow(
                        title: "Sandbox plugin recipes",
                        value: "\(dependencySnapshot.sandboxPluginRecipeCount) total - \(dependencySnapshot.dependencyRecipeCount) with dependencies",
                        systemImage: "puzzlepiece.extension.fill"
                    )
                    ActOsaurusSettingsMetricRow(
                        title: "Installed plugins",
                        value: "\(dependencySnapshot.readyPluginCount)/\(dependencySnapshot.installedPluginCount) ready - \(dependencySnapshot.failedPluginCount) failed - \(dependencySnapshot.installingPluginCount) changing",
                        systemImage: "shippingbox.fill"
                    )
                    ActOsaurusSettingsMetricRow(
                        title: "Active installers",
                        value: "\(dependencySnapshot.activeInstallCount)",
                        systemImage: "arrow.down.circle.fill"
                    )

                    HStack {
                        Button {
                            Task { await repairSandboxPluginDependencies() }
                        } label: {
                            Label("Install / Repair Dependencies", systemImage: "wrench.adjustable.fill")
                        }
                        .disabled(isRepairingDependencies)

                        Button {
                            presentNativeSurface(
                                title: "Plugin Details",
                                subtitle: "Plugin installs, dependency repair, and sandbox recipes.",
                                systemImage: "puzzlepiece.extension.fill",
                                tabID: "plugins"
                            )
                        } label: {
                            Label("Plugin Details", systemImage: "puzzlepiece.extension.fill")
                        }
                    }

                    if isRepairingDependencies {
                        ProgressView("Repairing sandbox dependencies")
                    }

                    if let dependencyActionError {
                        Label(dependencyActionError, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } else {
                    ProgressView("Loading dependency controls")
                }
            } header: {
                Text("Dependencies")
            } footer: {
                Text("This invokes Osaurus's sandbox plugin repair pass, including real package dependency setup inside the VM-backed sandbox.")
            }

            Section {
                osaurusSurfaceButton(
                    title: "Permission Popups",
                    subtitle: "Tool approvals, grants, and prompt policy.",
                    systemImage: "lock.shield.fill",
                    tabID: "permissions"
                )
                osaurusSurfaceButton(
                    title: "Computer Use Prompts",
                    subtitle: "Action confirmation policy, app allowlist, and automation boundaries.",
                    systemImage: "cursorarrow.rays",
                    tabID: "computerUse"
                )
                osaurusSurfaceButton(
                    title: "Provider Credentials",
                    subtitle: "Provider setup, API keys, and model access.",
                    systemImage: "key.fill",
                    tabID: "providers"
                )
                osaurusSurfaceButton(
                    title: "Identity and Biometrics",
                    subtitle: "Local identity, protected keys, and biometric prompts.",
                    systemImage: "person.badge.key.fill",
                    tabID: "identity"
                )
                osaurusSurfaceButton(
                    title: "Sandbox and Host Files",
                    subtitle: "Sandbox setup plus deeper agent-folder grants.",
                    systemImage: "shippingbox.fill",
                    tabID: "sandbox"
                )
                osaurusSurfaceButton(
                    title: "Privacy and Storage",
                    subtitle: "Data retention, local storage, and recovery.",
                    systemImage: "hand.raised.fill",
                    tabID: "privacy"
                )
            } header: {
                Text("Native permission surfaces")
            } footer: {
                Text("Permission and confirmation flows stay visible from Epistemos Settings instead of being stranded inside the standalone Osaurus app.")
            }

            Section {
                if let selectedOsaurusModelID {
                    LabeledContent("Selected Act model") {
                        Text(displayName(forModelID: selectedOsaurusModelID))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    LabeledContent("Selected Act model") {
                        Text("Not selected")
                            .foregroundStyle(.secondary)
                    }
                }

                if osaurusModelRows.isEmpty {
                    Button {
                        presentNativeSurface(
                            title: "Osaurus Models",
                            subtitle: "Local, provider, and Epistemos Pick model rows.",
                            systemImage: "cube.box.fill",
                            tabID: "models"
                        )
                    } label: {
                        Label("Open Osaurus Models", systemImage: "cube.box.fill")
                    }
                } else {
                    ForEach(osaurusModelRows) { row in
                        Button {
                            selectOsaurusModel(row)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: row.systemImage)
                                    .frame(width: 16)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.displayName)
                                    Text(row.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                    // 0.33f native model detail: on-device state + context window.
                                    HStack(spacing: 8) {
                                        Label(
                                            row.isDownloaded ? "On Device" : "Not downloaded",
                                            systemImage: row.isDownloaded ? "checkmark.circle.fill" : "icloud.and.arrow.down"
                                        )
                                        .foregroundStyle(row.isDownloaded ? Color.green : Color.secondary)
                                        if let ctx = row.contextLength, ctx > 0 {
                                            Label(Self.formatContextLength(ctx), systemImage: "text.alignleft")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .font(.caption2)
                                    .labelStyle(.titleAndIcon)
                                }
                                Spacer()
                                if row.id == selectedOsaurusModelID {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Osaurus model stack")
            } footer: {
                Text("The same rows appear inside the old Epistemos picker on Act landing and Act chat. Picking an Epistemos row also pins the Osaurus Act model.")
            }

            Section {
                ForEach(osaurusQuickActions) { action in
                    osaurusSurfaceButton(
                        title: action.title,
                        subtitle: action.subtitle,
                        systemImage: action.systemImage,
                        tabID: action.managementTabID
                    )
                }
            } header: {
                Text("Complete Osaurus settings map")
            } footer: {
                Text("Every Act capability surface is indexed here in Epistemos chrome: \(allManagementEntries.count) total surfaces, including models, providers, agents, plugins, sandbox, tools, skills, commands, memory, schedules, watchers, voice, UI theme, insights, server, permissions, computer use, privacy, identity, storage, credits, and general configuration.")
            }
            #else
            Section {
                SettingsDescriptionText(
                    text: "Osaurus native configuration is available in the Pro / direct-distribution build."
                )
            } header: {
                Text("Osaurus configuration")
            }
            #endif
        }
        .formStyle(.grouped)
        #if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
        .sheet(item: $presentedNativeSurface) { surface in
            ActNativeOsaurusSurfaceSheet(
                surface: surface,
                managementEntries: allManagementEntries,
                quickActions: osaurusQuickActions,
                actSnapshot: actSettingsSnapshot,
                providerSnapshot: providerRuntimeSnapshot,
                privacySnapshot: privacyFilterSnapshot,
                dependencySnapshot: dependencySnapshot,
                computerUseSnapshot: computerUsePolicySnapshot,
                systemPermissionRows: systemPermissionRows,
                toolPermissionRows: toolPermissionRows,
                sandboxDiagnostics: sandboxDiagnostics,
                onAction: { action in
                    Task { await handleNativeSurfaceAction(action) }
                }
            )
        }
        .task {
            await refreshOsaurusSettings()
        }
        #endif
    }

    #if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
    @MainActor
    private func refreshOsaurusSettings() async {
        selectedOsaurusModelID = EpistemosOsaurusManagementBridge.currentModel()
        osaurusModelRows = await EpistemosOsaurusManagementBridge.modelPicks()
        actSettingsSnapshot = await EpistemosOsaurusManagementBridge.actSettingsSnapshot()
        osaurusQuickActions = EpistemosOsaurusManagementBridge.nativeSettingsQuickActions()
        systemPermissionRows = EpistemosOsaurusManagementBridge.systemPermissionRows()
        toolPermissionRows = EpistemosOsaurusManagementBridge.toolPermissionRows(maxCount: 60)
        toolPermissionOptions = EpistemosOsaurusManagementBridge.toolPermissionOptions()
        computerUsePolicyOptions = EpistemosOsaurusManagementBridge.computerUsePolicyOptions()
        let policySnapshot = EpistemosOsaurusManagementBridge.computerUsePolicySnapshot()
        computerUsePolicySnapshot = policySnapshot
        computerUseAllowlistDraft = policySnapshot.allowlistedApps.joined(separator: ", ")
        providerRuntimeSnapshot = EpistemosOsaurusManagementBridge.providerRuntimeSnapshot()
        privacyFilterSnapshot = EpistemosOsaurusManagementBridge.privacyFilterSnapshot()
        dependencySnapshot = EpistemosOsaurusManagementBridge.dependencySnapshot()
    }

    /// 0.33f — compact context-window label for the native model detail row (e.g. 131072 → "128K ctx").
    static func formatContextLength(_ ctx: Int) -> String {
        if ctx >= 1000 {
            let k = Double(ctx) / 1024.0
            let rounded = (k * 10).rounded() / 10
            let kText = rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
            return "\(kText)K ctx"
        }
        return "\(ctx) ctx"
    }

    @MainActor
    private func selectOsaurusModel(_ row: EpistemosOsaurusModelPick) {
        EpistemosOsaurusManagementBridge.setCurrentModel(row.id)
        selectedOsaurusModelID = row.id
        if ChatModelSelection(rawValue: row.id) != nil {
            inference.setPreferredChatModelSelection(.localMLX(row.id))
        }
        Task { await refreshOsaurusSettings() }
    }

    @MainActor
    private func chooseGlobalWorkingFolder() async {
        isChoosingWorkingFolder = true
        defer { isChoosingWorkingFolder = false }
        _ = await EpistemosOsaurusManagementBridge.selectGlobalWorkingFolder()
        await refreshOsaurusSettings()
    }

    @MainActor
    private func clearGlobalWorkingFolder() {
        EpistemosOsaurusManagementBridge.clearGlobalWorkingFolder()
        Task { await refreshOsaurusSettings() }
    }

    @MainActor
    private func provisionSandbox() async {
        await runSandboxAction {
            await EpistemosOsaurusManagementBridge.provisionSandbox()
        }
    }

    @MainActor
    private func startSandbox() async {
        await runSandboxAction {
            await EpistemosOsaurusManagementBridge.startSandbox()
        }
    }

    @MainActor
    private func stopSandbox() async {
        await runSandboxAction {
            await EpistemosOsaurusManagementBridge.stopSandbox()
        }
    }

    @MainActor
    private func runSandboxDiagnostics() async {
        isRunningSandboxAction = true
        sandboxActionError = nil
        defer { isRunningSandboxAction = false }
        sandboxDiagnostics = await EpistemosOsaurusManagementBridge.runSandboxDiagnostics()
        await refreshOsaurusSettings()
    }

    @MainActor
    private func runSandboxAction(_ action: () async -> String?) async {
        isRunningSandboxAction = true
        sandboxActionError = nil
        defer { isRunningSandboxAction = false }
        sandboxActionError = await action()
        await refreshOsaurusSettings()
    }

    @MainActor
    private func setDefaultAgentToolsEnabled(_ enabled: Bool) {
        EpistemosOsaurusManagementBridge.setDefaultAgentToolsEnabled(enabled)
        Task { await refreshOsaurusSettings() }
    }

    @MainActor
    private func setMemoryEnabled(_ enabled: Bool) {
        EpistemosOsaurusManagementBridge.setMemoryEnabled(enabled)
        Task { await refreshOsaurusSettings() }
    }

    @MainActor
    private func setToolSelectionMode(_ rawValue: String) {
        EpistemosOsaurusManagementBridge.setToolSelectionMode(rawValue)
        Task { await refreshOsaurusSettings() }
    }

    @MainActor
    private func refreshSystemPermissions() {
        EpistemosOsaurusManagementBridge.refreshSystemPermissions()
        Task { await refreshOsaurusSettings() }
    }

    @MainActor
    private func requestSystemPermission(_ id: String) {
        EpistemosOsaurusManagementBridge.requestSystemPermission(id)
        Task { await refreshOsaurusSettings() }
    }

    @MainActor
    private func openSystemPermissionSettings(_ id: String) {
        EpistemosOsaurusManagementBridge.openSystemPermissionSettings(id)
        Task { await refreshOsaurusSettings() }
    }

    @MainActor
    private func setToolPermissionPolicy(toolName: String, policyID: String) {
        EpistemosOsaurusManagementBridge.setToolPermissionPolicy(toolName: toolName, policyID: policyID)
        Task { await refreshOsaurusSettings() }
    }

    @MainActor
    private func resetToolPermissionPolicy(toolName: String) {
        EpistemosOsaurusManagementBridge.resetToolPermissionPolicy(toolName: toolName)
        Task { await refreshOsaurusSettings() }
    }

    @MainActor
    private func setComputerUseGlobalPreset(_ rawValue: String) {
        EpistemosOsaurusManagementBridge.setComputerUseGlobalPreset(rawValue)
        Task { await refreshOsaurusSettings() }
    }

    @MainActor
    private func saveComputerUseAllowlist() {
        let apps = computerUseAllowlistDraft
            .split { $0 == "," || $0 == "\n" || $0 == ";" }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        EpistemosOsaurusManagementBridge.setComputerUseAllowlistedApps(apps)
        Task { await refreshOsaurusSettings() }
    }

    @MainActor
    private func setOsaurusRouterEnabled(_ enabled: Bool) {
        EpistemosOsaurusManagementBridge.setOsaurusRouterEnabled(enabled)
        Task { await refreshOsaurusSettings() }
    }

    @MainActor
    private func connectRemoteProviders() async {
        await runProviderAction {
            await EpistemosOsaurusManagementBridge.connectRemoteProviders()
            return nil
        }
    }

    @MainActor
    private func disconnectRemoteProviders() {
        EpistemosOsaurusManagementBridge.disconnectRemoteProviders()
        Task { await refreshOsaurusSettings() }
    }

    @MainActor
    private func connectMCPProviders() async {
        await runProviderAction {
            await EpistemosOsaurusManagementBridge.connectMCPProviders()
            return nil
        }
    }

    @MainActor
    private func disconnectMCPProviders() {
        EpistemosOsaurusManagementBridge.disconnectMCPProviders()
        Task { await refreshOsaurusSettings() }
    }

    @MainActor
    private func runProviderAction(_ action: () async -> String?) async {
        isRunningProviderAction = true
        providerActionError = nil
        defer { isRunningProviderAction = false }
        providerActionError = await action()
        await refreshOsaurusSettings()
    }

    @MainActor
    private func setPrivacyFilterEnabled(_ enabled: Bool) {
        EpistemosOsaurusManagementBridge.setPrivacyFilterEnabled(enabled)
        Task { await refreshOsaurusSettings() }
    }

    @MainActor
    private func setPrivacyFilterSkipCodeBlocks(_ enabled: Bool) {
        EpistemosOsaurusManagementBridge.setPrivacyFilterSkipCodeBlocks(enabled)
        Task { await refreshOsaurusSettings() }
    }

    @MainActor
    private func setPrivacyFilterRequireInteractiveReview(_ enabled: Bool) {
        EpistemosOsaurusManagementBridge.setPrivacyFilterRequireInteractiveReview(enabled)
        Task { await refreshOsaurusSettings() }
    }

    @MainActor
    private func setPrivacyFilterAlwaysApprove(_ enabled: Bool) {
        EpistemosOsaurusManagementBridge.setPrivacyFilterAlwaysApprove(enabled)
        Task { await refreshOsaurusSettings() }
    }

    @MainActor
    private func setPrivacyFilterConfidenceThreshold(_ threshold: Float) {
        EpistemosOsaurusManagementBridge.setPrivacyFilterConfidenceThreshold(threshold)
        Task { await refreshOsaurusSettings() }
    }

    @MainActor
    private func repairSandboxPluginDependencies() async {
        isRepairingDependencies = true
        dependencyActionError = nil
        defer { isRepairingDependencies = false }
        dependencyActionError = await EpistemosOsaurusManagementBridge.repairSandboxPluginDependencies()
        await refreshOsaurusSettings()
    }

    @MainActor
    private func presentNativeSurface(
        title: String,
        subtitle: String,
        systemImage: String,
        tabID: String
    ) {
        presentedNativeSurface = ActNativeOsaurusSurface(
            id: tabID,
            title: title,
            subtitle: subtitle,
            systemImage: systemImage
        )
    }

    @MainActor
    private func handleNativeSurfaceAction(_ action: ActNativeOsaurusSurfaceAction) async {
        switch action {
        case .refresh:
            await refreshOsaurusSettings()
        case .chooseFolder:
            await chooseGlobalWorkingFolder()
        case .clearFolder:
            clearGlobalWorkingFolder()
        case .provisionSandbox:
            await provisionSandbox()
        case .startSandbox:
            await startSandbox()
        case .stopSandbox:
            await stopSandbox()
        case .runSandboxDiagnostics:
            await runSandboxDiagnostics()
        case .connectProviders:
            await connectRemoteProviders()
        case .disconnectProviders:
            disconnectRemoteProviders()
        case .connectMCP:
            await connectMCPProviders()
        case .disconnectMCP:
            disconnectMCPProviders()
        case .repairDependencies:
            await repairSandboxPluginDependencies()
        case .refreshPermissions:
            refreshSystemPermissions()
        case .allowAllComputerUseApps:
            computerUseAllowlistDraft = ""
            saveComputerUseAllowlist()
        }
    }

    @ViewBuilder
    private func osaurusSurfaceButton(
        title: String,
        subtitle: String,
        systemImage: String,
        tabID: String
    ) -> some View {
        Button {
            presentNativeSurface(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                tabID: tabID
            )
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func toolCatalogLabel(_ snapshot: EpistemosOsaurusActSettingsSnapshot) -> String {
        let scope = snapshot.toolAllowlistCount.map { "\($0) allowed" } ?? "registry"
        return "\(snapshot.enabledToolCount)/\(snapshot.registeredToolCount) enabled - \(scope) - \(snapshot.toolSelectionModeLabel)"
    }

    private func skillCatalogLabel(_ snapshot: EpistemosOsaurusActSettingsSnapshot) -> String {
        let scope = snapshot.skillAllowlistCount.map { "\($0) allowed" } ?? "registry"
        return "\(snapshot.enabledSkillCount)/\(snapshot.registeredSkillCount) enabled - \(scope)"
    }

    private func displayName(forModelID id: String) -> String {
        osaurusModelRows.first(where: { $0.id == id })?.displayName ?? {
            guard let slashIndex = id.lastIndex(of: "/") else { return id }
            return String(id[id.index(after: slashIndex)...])
        }()
    }
    #endif
}

#if !EPISTEMOS_APP_STORE && canImport(OsaurusCore)
private struct ActNativeOsaurusSurface: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
}

private enum ActNativeOsaurusSurfaceAction: Hashable {
    case refresh
    case chooseFolder
    case clearFolder
    case provisionSandbox
    case startSandbox
    case stopSandbox
    case runSandboxDiagnostics
    case connectProviders
    case disconnectProviders
    case connectMCP
    case disconnectMCP
    case repairDependencies
    case refreshPermissions
    case allowAllComputerUseApps
}

private struct ActNativeSurfaceStatus: Identifiable {
    let title: String
    let value: String
    let systemImage: String

    var id: String { "\(title)-\(value)-\(systemImage)" }
}

private struct ActNativeSurfaceAction: Identifiable {
    let title: String
    let systemImage: String
    let action: ActNativeOsaurusSurfaceAction

    var id: String { "\(title)-\(systemImage)" }
}

private struct ActNativeOsaurusSurfaceSheet: View {
    @Environment(\.dismiss) private var dismiss

    let surface: ActNativeOsaurusSurface
    let managementEntries: [EpistemosOsaurusManagementEntry]
    let quickActions: [EpistemosOsaurusQuickAction]
    let actSnapshot: EpistemosOsaurusActSettingsSnapshot?
    let providerSnapshot: EpistemosOsaurusProviderRuntimeSnapshot?
    let privacySnapshot: EpistemosOsaurusPrivacyFilterSnapshot?
    let dependencySnapshot: EpistemosOsaurusDependencySnapshot?
    let computerUseSnapshot: EpistemosOsaurusComputerUsePolicySnapshot?
    let systemPermissionRows: [EpistemosOsaurusSystemPermissionRow]
    let toolPermissionRows: [EpistemosOsaurusToolPermissionRow]
    let sandboxDiagnostics: [EpistemosOsaurusSandboxDiagnosticRow]
    let onAction: (ActNativeOsaurusSurfaceAction) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: surface.systemImage)
                            .font(.title2)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(surface.title)
                                .font(.headline)
                            Text(surface.subtitle)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Native State") {
                    ForEach(statusRows) { row in
                        ActOsaurusSettingsMetricRow(
                            title: row.title,
                            value: row.value,
                            systemImage: row.systemImage
                        )
                    }
                }

                Section("Actions") {
                    ForEach(actionRows) { row in
                        Button {
                            onAction(row.action)
                        } label: {
                            Label(row.title, systemImage: row.systemImage)
                        }
                    }
                }

                if !sandboxDiagnostics.isEmpty, surface.id == "sandbox" {
                    Section("Latest Diagnostics") {
                        ForEach(sandboxDiagnostics) { row in
                            ActSandboxDiagnosticNativeRow(row: row)
                        }
                    }
                }

                Section("Native Act Capability Surfaces") {
                    ForEach(managementEntries) { entry in
                        Label(entry.label, systemImage: entry.systemImage)
                    }
                }

                if !quickActions.isEmpty {
                    Section("Native Index") {
                        ForEach(quickActions) { action in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: action.systemImage)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(action.title)
                                    Text(action.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(surface.title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 520, minHeight: 560)
    }

    private var statusRows: [ActNativeSurfaceStatus] {
        switch surface.id {
        case "providers":
            guard let providerSnapshot else { return loadingRows("Provider runtime") }
            return [
                .init(
                    title: "Osaurus Router",
                    value: providerSnapshot.osaurusRouterEnabled ? "Enabled" : "Disabled",
                    systemImage: "sparkles"
                ),
                .init(
                    title: "Remote providers",
                    value: "\(providerSnapshot.remoteConnectedCount)/\(providerSnapshot.remoteEnabledCount) connected - \(providerSnapshot.remoteModelCount) models",
                    systemImage: "cloud.fill"
                ),
                .init(
                    title: "MCP servers",
                    value: "\(providerSnapshot.mcpConnectedCount)/\(providerSnapshot.mcpEnabledCount) connected - \(providerSnapshot.mcpDiscoveredToolCount) tools",
                    systemImage: "server.rack"
                ),
            ]
        case "tools":
            return [
                .init(
                    title: "Tool policies",
                    value: "\(toolPermissionRows.count) native rows loaded",
                    systemImage: "wrench.and.screwdriver.fill"
                ),
                .init(
                    title: "Missing grants",
                    value: "\(toolPermissionRows.reduce(0) { $0 + $1.missingGrantCount })",
                    systemImage: "exclamationmark.shield.fill"
                ),
            ]
        case "permissions":
            return [
                .init(
                    title: "macOS permissions",
                    value: "\(systemPermissionRows.filter(\.isGranted).count)/\(systemPermissionRows.count) granted",
                    systemImage: "lock.shield.fill"
                ),
                .init(
                    title: "Tool permission rows",
                    value: "\(toolPermissionRows.count)",
                    systemImage: "wrench.and.screwdriver.fill"
                ),
            ]
        case "sandbox":
            guard let actSnapshot else { return loadingRows("Sandbox") }
            return [
                .init(
                    title: "Sandbox",
                    value: "\(actSnapshot.sandboxStatusLabel) - \(actSnapshot.sandboxAvailabilityLabel)",
                    systemImage: "shippingbox.fill"
                ),
                .init(
                    title: "Working folder",
                    value: actSnapshot.globalWorkingFolderPath ?? "No folder selected",
                    systemImage: "folder.fill"
                ),
            ]
        case "computerUse":
            guard let computerUseSnapshot else { return loadingRows("Computer Use") }
            return [
                .init(
                    title: "Autonomy",
                    value: computerUseSnapshot.globalPresetLabel,
                    systemImage: "cursorarrow.rays"
                ),
                .init(
                    title: "Allowlist",
                    value: computerUseSnapshot.allowlistedApps.isEmpty ? "All apps" : "\(computerUseSnapshot.allowlistedApps.count) apps",
                    systemImage: "app.connected.to.app.below.fill"
                ),
            ]
        case "privacy":
            guard let privacySnapshot else { return loadingRows("Privacy filter") }
            return [
                .init(
                    title: "Privacy filter",
                    value: privacySnapshot.enabled ? "Enabled" : "Disabled",
                    systemImage: "hand.raised.fill"
                ),
                .init(
                    title: "Detection threshold",
                    value: "\(Int(privacySnapshot.confidenceThreshold * 100))%",
                    systemImage: "slider.horizontal.3"
                ),
                .init(
                    title: "Rules",
                    value: "\(privacySnapshot.customRuleCount) custom - \(privacySnapshot.enabledPresetRuleCount) presets",
                    systemImage: "list.bullet.rectangle"
                ),
            ]
        case "plugins":
            guard let dependencySnapshot else { return loadingRows("Plugin dependencies") }
            return [
                .init(
                    title: "Installed plugins",
                    value: "\(dependencySnapshot.readyPluginCount)/\(dependencySnapshot.installedPluginCount) ready",
                    systemImage: "puzzlepiece.extension.fill"
                ),
                .init(
                    title: "Dependency recipes",
                    value: "\(dependencySnapshot.dependencyRecipeCount)",
                    systemImage: "wrench.adjustable.fill"
                ),
            ]
        case "models":
            return [
                .init(
                    title: "Selected Act model",
                    value: actSnapshot?.selectedModelDisplayName ?? actSnapshot?.selectedModelID ?? "Not selected",
                    systemImage: "cube.box.fill"
                ),
            ]
        default:
            return [
                .init(
                    title: "Native coverage",
                    value: "\(managementEntries.count) Osaurus surfaces indexed in Epistemos",
                    systemImage: "rectangle.stack.fill"
                ),
            ]
        }
    }

    private var actionRows: [ActNativeSurfaceAction] {
        switch surface.id {
        case "providers":
            return [
                .init(title: "Connect Providers", systemImage: "bolt.horizontal.circle", action: .connectProviders),
                .init(title: "Disconnect Providers", systemImage: "bolt.slash.circle", action: .disconnectProviders),
                .init(title: "Connect MCP", systemImage: "link.circle", action: .connectMCP),
                .init(title: "Disconnect MCP", systemImage: "link.circle.fill", action: .disconnectMCP),
                .init(title: "Refresh", systemImage: "arrow.clockwise", action: .refresh),
            ]
        case "sandbox":
            return [
                .init(title: "Choose Working Folder", systemImage: "folder.badge.plus", action: .chooseFolder),
                .init(title: "Clear Working Folder", systemImage: "xmark.circle", action: .clearFolder),
                .init(title: "Set Up Sandbox", systemImage: "shippingbox", action: .provisionSandbox),
                .init(title: "Start Sandbox", systemImage: "play.fill", action: .startSandbox),
                .init(title: "Stop Sandbox", systemImage: "stop.fill", action: .stopSandbox),
                .init(title: "Run Diagnostics", systemImage: "stethoscope", action: .runSandboxDiagnostics),
            ]
        case "tools", "permissions":
            return [
                .init(title: "Refresh Permissions", systemImage: "arrow.clockwise", action: .refreshPermissions),
                .init(title: "Refresh", systemImage: "arrow.triangle.2.circlepath", action: .refresh),
            ]
        case "computerUse":
            return [
                .init(title: "Allow All Apps", systemImage: "infinity", action: .allowAllComputerUseApps),
                .init(title: "Refresh", systemImage: "arrow.clockwise", action: .refresh),
            ]
        case "plugins":
            return [
                .init(title: "Install / Repair Dependencies", systemImage: "wrench.adjustable.fill", action: .repairDependencies),
                .init(title: "Refresh", systemImage: "arrow.clockwise", action: .refresh),
            ]
        default:
            return [
                .init(title: "Refresh", systemImage: "arrow.clockwise", action: .refresh),
            ]
        }
    }

    private func loadingRows(_ name: String) -> [ActNativeSurfaceStatus] {
        [
            .init(
                title: name,
                value: "Loading native state",
                systemImage: "hourglass"
            ),
        ]
    }
}

private struct ActOsaurusSettingsMetricRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
}

private struct ActSandboxDiagnosticNativeRow: View {
    let row: EpistemosOsaurusSandboxDiagnosticRow

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: row.passed ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .frame(width: 18)
                .foregroundStyle(row.passed ? .green : .red)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.name)
                Text(row.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer()
        }
    }
}

private struct ActSystemPermissionNativeRow: View {
    let row: EpistemosOsaurusSystemPermissionRow
    let onGrant: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: row.systemImage)
                .frame(width: 18)
                .foregroundStyle(row.isGranted ? .green : .orange)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(row.displayName)
                    Text(row.isGranted ? "Granted" : "Needed")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(row.isGranted ? .green : .orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill((row.isGranted ? Color.green : Color.orange).opacity(0.12)))
                }
                Text(row.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if row.isGranted {
                Button("Settings", action: onOpenSettings)
            } else {
                Button("Grant", action: onGrant)
                if row.usesSystemSettings {
                    Button("Settings", action: onOpenSettings)
                }
            }
        }
    }
}

private struct ActToolPermissionNativeRow: View {
    let row: EpistemosOsaurusToolPermissionRow
    let options: [EpistemosOsaurusPolicyOption]
    let onPolicyChange: (String) -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: row.isDestructive ? "exclamationmark.triangle.fill" : "wrench.and.screwdriver.fill")
                .frame(width: 18)
                .foregroundStyle(row.isDestructive ? .orange : .secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.displayName)
                Text(row.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(row.requirementsLabel)
                    .font(.caption2)
                    .foregroundStyle(row.missingGrantCount > 0 ? Color.orange : Color.secondary.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer()

            Picker(
                "",
                selection: Binding(
                    get: { row.effectivePolicyID },
                    set: { onPolicyChange($0) }
                )
            ) {
                ForEach(options) { option in
                    Text(option.label).tag(option.id)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 170)

            if row.configuredPolicyID != nil {
                Button("Reset", action: onReset)
            }
        }
    }
}
#endif
