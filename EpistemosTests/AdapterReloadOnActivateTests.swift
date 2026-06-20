import Testing
import Foundation

@testable import Epistemos

// SS-LS reload-on-activate (completes apply-gap step 2): when the user activates or
// deactivates a LoRA adapter mid-session, the loaded container is dropped IFF the
// active signature actually changed, so the next generation re-applies it live — but
// no-active <-> no-active (and an unchanged adapter) never reloads, so the normal
// path is untouched. Witnessed WITHOUT a live model; the live mid-session token swap
// is PENDING OWNER VERIFICATION.
@Suite("SS-LS reload-on-activate (step 2 completion)")
struct AdapterReloadOnActivateTests {

    #if !EPISTEMOS_APP_STORE
    @Test("reload iff the active signature changed; no-active <-> no-active never reloads")
    func reloadDecision() {
        let a = URL(fileURLWithPath: "/tmp/adapterA")
        let b = URL(fileURLWithPath: "/tmp/adapterB")
        // The normal path: no active before, no active after ⇒ NO reload.
        #expect(MLXInferenceService.shouldReloadForAdapterChange(lastApplied: nil, current: nil) == false)
        // Same adapter still active ⇒ no reload.
        #expect(MLXInferenceService.shouldReloadForAdapterChange(lastApplied: a, current: a) == false)
        // Activated / deactivated / swapped ⇒ reload.
        #expect(MLXInferenceService.shouldReloadForAdapterChange(lastApplied: nil, current: a) == true)
        #expect(MLXInferenceService.shouldReloadForAdapterChange(lastApplied: a, current: nil) == true)
        #expect(MLXInferenceService.shouldReloadForAdapterChange(lastApplied: a, current: b) == true)
    }
    #endif

    @Test("the change signal is posted on activate, observed at bootstrap, and reload is guarded")
    func wiring() throws {
        let registry = try loadMirroredSourceTextFile(
            "Epistemos/KnowledgeFusion/Adapters/AdapterRegistry.swift"
        )
        // setActive posts the change notification only when the active state changed.
        #expect(registry.contains("static let epistemosActiveAdaptersDidChange"))
        #expect(registry.contains("if changed {"))
        #expect(registry.contains("NotificationCenter.default.post(name: .epistemosActiveAdaptersDidChange"))

        let bootstrap = try loadMirroredSourceTextFile("Epistemos/App/AppBootstrap.swift")
        #expect(bootstrap.contains("forName: .epistemosActiveAdaptersDidChange"))
        #expect(bootstrap.contains("await localInferenceService.reloadIfActiveAdapterChanged()"))

        let service = try loadMirroredSourceTextFile("Epistemos/Engine/MLXInferenceService.swift")
        // The reload is a no-op unless a container is loaded AND the signature changed.
        #expect(service.contains("guard container != nil else { return }"))
        #expect(service.contains("shouldReloadForAdapterChange(lastApplied: lastAppliedActiveAdapter"))
        #expect(service.contains("await unload()"))
    }
}
