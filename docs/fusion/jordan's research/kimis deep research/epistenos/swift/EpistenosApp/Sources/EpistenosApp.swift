import SwiftUI
import Combine
import EpistenosKit

// ---------------------------------------------------------------------------
// MARK: - EpistenosApp
// ---------------------------------------------------------------------------

/// The main entry-point for the Epistenos macOS application.
///
/// Architecture:
/// - Window group: Companion Farm (primary workspace — Simulation Mode v1.6)
/// - Auxiliary: Agent Dashboard (legacy, still accessible)
/// - Menu bar extra: Quick Capture (always-available floating input)
/// - Settings: Ternary Control Room (advanced inference view)
@main
public struct EpistenosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    public init() {}

    public var body: some Scene {
        // Primary window — Landing Farm (Simulation Mode v1.6)
        WindowGroup("Companion Farm") {
            LandingFarmView()
                .withAppEnvironment(AppEnvironment.shared)
                .environment(AppEnvironment.shared?.companionState ?? CompanionState())
                .frame(minWidth: 600, minHeight: 400)
        }
        .defaultSize(width: 800, height: 500)

        // Agent Dashboard — auxiliary window
        WindowGroup("Agent Dashboard") {
            AgentDashboardView()
                .frame(minWidth: 600, minHeight: 400)
        }
        .defaultSize(width: 800, height: 500)

        // Ternary Control Room — auxiliary window
        WindowGroup("Ternary Control Room") {
            TernaryControlRoomView()
                .frame(minWidth: 720, minHeight: 420)
        }
        .defaultSize(width: 900, height: 520)

        // Settings / Preferences scene
        Settings {
            PreferencesView()
                .withAppEnvironment(AppEnvironment.shared)
                .frame(minWidth: 400, minHeight: 300)
        }

        // Menu bar extra — Quick Capture
        MenuBarExtra("Epistenos", systemImage: "bolt.fill") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}

// ---------------------------------------------------------------------------
// MARK: - AppDelegate
// ---------------------------------------------------------------------------

/// AppDelegate handles lifecycle events and XPC service bootstrap.
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Bootstrap the shared environment, companion state, and event stream.
        AppBootstrap.shared.run()

        #if DEBUG
        print("[EpistenosApp] Launched — App Group: group.com.epistenos.shared")
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep alive for menu-bar capture and background agents.
        false
    }
}

// ---------------------------------------------------------------------------
// MARK: - PreferencesView
// ---------------------------------------------------------------------------

struct PreferencesView: View {
    @AppStorage("epistenos.appGroupID") private var appGroupID: String = "group.com.epistenos.shared"
    @AppStorage("epistenos.pollInterval") private var pollInterval: Double = 2.0
    @AppStorage("epistenos.liveDraft") private var liveDraft: Bool = true

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }

            advancedTab
                .tabItem { Label("Advanced", systemImage: "cpu") }

            securityTab
                .tabItem { Label("Security", systemImage: "lock.shield") }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }

    private var generalTab: some View {
        Form {
            TextField("App Group ID", text: $appGroupID)
            Slider(value: $pollInterval, in: 0.5...10.0, step: 0.5) {
                Text("Poll Interval: \(String(format: "%.1f", pollInterval)) s")
            }
            Toggle("Enable Live Draft Overlay", isOn: $liveDraft)
        }
    }

    private var advancedTab: some View {
        Form {
            Text("Ternary Inference Backends")
                .font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Label("DenseMlx — MLX dense tensor path", systemImage: "cpu")
                Label("BitnetReference — 1.58-bit reference CPU", systemImage: "memorychip")
                Label("TernaryMetal — Metal ternary GEMV kernel", systemImage: "gpu")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var securityTab: some View {
        Form {
            Toggle("Require Biometric for Writes", isOn: .constant(true))
                .disabled(true) // Always on in production
            Text("Write operations to vaults are gated by Touch ID / Face ID.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 4)

            NavigationLink(destination: CompanionSettingsSection()) {
                Label("Companions", systemImage: "person.2.fill")
            }
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - CompanionSettingsSection
// ---------------------------------------------------------------------------

struct CompanionSettingsSection: View {
    @Environment(CompanionState.self) private var companionState
    @State private var showCreation = false
    @State private var showRestore = false

    var body: some View {
        Form {
            Section(header: Text("Active Companions")) {
                if companionState.companions.isEmpty {
                    Text("No companions yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(companionState.companions, id: \.id) { companion in
                        HStack {
                            Text(companion.name)
                            Spacer()
                            Text(companion.baseProfile.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button("Create New Companion …") {
                    showCreation = true
                }
                Button("Restore Archived Companion …") {
                    showRestore = true
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .sheet(isPresented: $showCreation) {
            CompanionCreationFlow()
                .frame(minWidth: 480, minHeight: 400)
        }
        .sheet(isPresented: $showRestore) {
            CompanionRestoreSheet()
                .frame(minWidth: 400, minHeight: 320)
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - MenuBarView
// ---------------------------------------------------------------------------

struct MenuBarView: View {
    @State private var quickText: String = ""
    @State private var showCapture = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.accent)
                Text("Epistenos Capture")
                    .font(.headline)
                Spacer()
                Button("Open Dashboard") {
                    NSApp.activate(ignoringOtherApps: true)
                    // Open the main window via notification or direct reference.
                }
            }

            Divider()

            CaptureSurfaceCompact(text: $quickText)

            Divider()

            HStack {
                Button("Capture (⌘↩)") {
                    commitCapture()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(quickText.isEmpty)

                Button("Cancel", role: .cancel) {
                    NSApp.hide(nil)
                }
            }
        }
        .padding()
        .frame(width: 320)
    }

    private func commitCapture() {
        Task {
            // In production this calls the UniFFI `run_ternary_prompt` or a
            // dedicated `capture_intent` export.
            quickText = ""
            NSApp.hide(nil)
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - CaptureSurfaceCompact
// ---------------------------------------------------------------------------

struct CaptureSurfaceCompact: View {
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.body)
                .frame(height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2))
                )
            if text.isEmpty {
                Text("Capture a thought …")
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
                    .padding(.leading, 6)
            }
        }
    }
}
