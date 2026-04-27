import AppIntents
import SwiftUI
import WidgetKit

// MARK: - EpistemosControlWidget (W15.3)
//
// Wave 15 §"#3 ControlWidget for QuickCapture + OpenRawThoughtSandbox"
// — top-3 ROI item per all four App Intents research drops. macOS 26
// Tahoe brought third-party Control Center widgets to Mac for the
// first time; controls also surface in the menu-bar Control Center
// pull-down.
//
// What this gives the user:
//   - One-tap Quick Capture from the menu-bar Control Center on
//     macOS 26 — no global hotkey needed; click the brain icon, the
//     CaptureBrainDumpIntent fires headlessly via .background mode.
//   - Same intent fires when the widget is dragged onto the desktop
//     as a control.
//
// Verified canonical API (`WidgetKit.swiftinterface` line 487 / 1081):
//
//   StaticControlConfiguration<Content: ControlWidgetTemplate>
//     — fixed config, no per-instance @Parameter
//
//   AppIntentControlConfiguration<Configuration: ControlConfigurationIntent,
//                                  Content: ControlWidgetTemplate>
//     — user-configurable (e.g. "which vault to capture into")
//
// We use `StaticControlConfiguration` for QuickCapture because the
// most common use is "capture to current vault" — no configuration
// surface needed. A second control with `AppIntentControlConfiguration`
// follows when vault-selection becomes meaningful (Phase E follow-up).
//
// xcodegen target wiring: this file currently compiles into the main
// Epistemos target so the source is visible to the Xcode indexer +
// the build system. To ACTUALLY surface the control in Control
// Center, the file must move into a separate widget extension
// target (`EpistemosWidgets.appex`) per Apple's Control Center
// hosting contract — controls only render from extension bundles.
// The xcodegen project.yml addition is the follow-up commit; this
// commit lands the source.

@available(macOS 26.0, *)
struct EpistemosCaptureControl: ControlWidget {
    static let kind: String = "com.epistemos.menubar.quickcapture"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: CaptureBrainDumpIntent()) {
                Label("Capture", systemImage: "bolt.text.clipboard")
            }
        }
        .displayName("Epistemos Quick Capture")
        .description("Instantly capture a thought from the menu bar.")
    }
}

@available(macOS 26.0, *)
struct EpistemosSandboxControl: ControlWidget {
    static let kind: String = "com.epistemos.menubar.sandboxtoggle"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenRawThoughtSandboxIntent()) {
                Label("Sandbox", systemImage: "tray.full")
            }
        }
        .displayName("Epistemos Raw-Thought Sandbox")
        .description("Toggle ambient retrieval for the current conversation.")
    }
}

// MARK: - WidgetBundle wrapper (for the future extension target)
//
// When the EpistemosWidgets.appex target lands, this @main bundle
// becomes its entry point. Today it's gated behind canImport(WidgetKit)
// + the macOS 26 availability so it builds inside the main app for
// indexing without affecting startup.

#if canImport(WidgetKit)
@available(macOS 26.0, *)
struct EpistemosControlWidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        EpistemosCaptureControl()
        EpistemosSandboxControl()
    }
}
#endif
