import Testing
import Foundation
@testable import Epistemos

/// SS-G (the #1 owner-blocker remnant): the model-stack rows (Settings → the
/// "Advertised models" stack) can now INSTALL per-row — they previously only
/// showed "Not installed" with no action. Descriptor models install via
/// install(modelID:); the foundation GGUF models (no LocalModelDescriptor) via the
/// one-tap installEpistemosFoundationPackage().
@Suite("Model-stack per-row install (SS-G)")
struct ModelStackInstallTests {

    @Test("the stack rows wire a per-row Install action (descriptor + foundation GGUF)")
    func stackRowsCanInstall() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/Views/Settings/ModelStackSettingsView.swift"
        )
        // A per-row Install control is rendered for uninstalled rows.
        #expect(src.contains("installControl(row)"))
        #expect(src.contains("if !row.isInstalled"))
        // Descriptor models install via install(modelID:); GGUF foundation via the
        // package — both paths wired.
        #expect(src.contains("localModelManager.install(modelID: descriptor.id)"))
        #expect(src.contains("localModelManager.installEpistemosFoundationPackage()"))
    }
}
