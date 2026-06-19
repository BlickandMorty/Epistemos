import Testing
import Foundation
@testable import Epistemos

/// DATA+FINETUNE part (5) — locks the marketplace seed catalog + the browse-view
/// wiring so a future edit can't silently drop the surface, weaken the honest
/// gating, or seed an unlicensed pack (ProvenanceGate).
@Suite("Fine-tune pack catalog + marketplace browse")
struct FineTunePackCatalogTests {

    @Test("built-in catalog is non-empty and every pack is licensed + identified (ProvenanceGate)")
    func builtInLicensedAndIdentified() {
        #expect(!FineTunePackCatalog.builtIn.isEmpty)
        for pack in FineTunePackCatalog.builtIn {
            #expect(!pack.license.isEmpty)
            #expect(!pack.id.isEmpty)
        }
    }

    @Test("seeded registry contains all built-ins")
    func seededRegistryHasBuiltIns() {
        let registry = FineTunePackCatalog.seededRegistry()
        #expect(registry.packs.count == FineTunePackCatalog.builtIn.count)
        for pack in FineTunePackCatalog.builtIn {
            #expect(registry.pack(id: pack.id) != nil)
        }
    }

    @Test("honest gating: Pro packs hide on the MAS surface, show in a Pro build")
    func honestGating() {
        let registry = FineTunePackCatalog.seededRegistry()
        let mas = registry.available(isPro: false, isDev: false)
        let pro = registry.available(isPro: true, isDev: false)
        // The locally-trained LoRA pack is Pro-gated (native training is Pro-only)
        // so it must NEVER appear on the MAS surface.
        #expect(!mas.contains { $0.gate == .pro })
        #expect(pro.contains { $0.id == "epistemos.lora.local" })
        // Free first-party packs appear everywhere.
        #expect(mas.contains { $0.id == "epistemos.vault.dataset" })
    }

    @Test("marketplace view browses the registry with honest gating + empty state, mounted in Settings")
    func marketplaceViewWiringAndMount() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/FineTuneMarketplaceView.swift")
        #expect(src.contains("registry.available(isPro: isPro, isDev: isDev)"))
        #expect(src.contains("FineTunePackKind.allCases"))
        #expect(src.contains("No packs available here yet"))
        #expect(src.contains("gateBadge"))
        // honest gating uses the deployment flag (Pro packs hidden on MAS).
        #expect(src.contains("#if !EPISTEMOS_APP_STORE"))

        // Mounted in the model-vaults settings surface (rule #8 — owner can see it).
        let mount = try loadMirroredSourceTextFile("Epistemos/Views/Settings/ModelVaultsSettingsView.swift")
        #expect(mount.contains("FineTuneMarketplaceView()"))
    }
}
