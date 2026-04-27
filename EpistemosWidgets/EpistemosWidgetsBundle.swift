import WidgetKit
import SwiftUI

// MARK: - EpistemosWidgetsBundle (AR1 — widget extension entry point)
//
// Per Wave 15 §"#3 ControlWidget for QuickCapture + OpenRawThoughtSandbox"
// + audit verdict on commit 1ce994ea: ControlWidgets only render
// from a `.appex` extension bundle — the in-main-app source the
// W15.3 commit shipped was source-only. This file is the canonical
// `@main` entry point for the `EpistemosWidgets.appex` target.
//
// The `EpistemosCaptureControl` + `EpistemosSandboxControl` types
// live in the main-app target at
// `Epistemos/Intents/Schemas/EpistemosControlWidget.swift` because
// they reference cognitive-intent types (`CaptureBrainDumpIntent`,
// `OpenRawThoughtSandboxIntent`) that the main app owns. The widget
// extension target's project.yml entry includes BOTH the main-app
// source paths (transitively) AND this entry point so the linker
// resolves the intent button targets correctly.
//
// xcodegen wires the App Group entitlement
// (`group.com.epistemos.shared`) on both the main app and this
// extension so they share the SwiftData/GRDB store + Quarantine
// archive without going through XPC.

@main
@available(macOS 26.0, *)
struct EpistemosWidgetsBundle: WidgetBundle {
    var body: some Widget {
        EpistemosCaptureControl()
        EpistemosSandboxControl()
    }
}
