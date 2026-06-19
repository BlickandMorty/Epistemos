import Foundation

// DATA+FINETUNE part (5) MARKETPLACE — the built-in SEED catalog. First-party,
// license-clean descriptors only (user-owned vault + Epistemos's own artifacts) so
// there is zero risk of an inaccurate third-party license claim. Public/third-party
// packs are added LATER at runtime through the ProvenanceGate
// (`FineTunePackRegistry.add`), each carrying its REAL license. The `.localFile`
// sources here are representative descriptors; the real on-disk path resolves at
// import time (the follow-on slice). Pure, always-compiled, unit-tested.
enum FineTunePackCatalog {

    /// First-party built-in packs — always license-clean (user-owned / Epistemos).
    /// Demonstrates 3 kinds + honest free/Pro gating (native LoRA training is
    /// Pro-only, so that pack is `.pro` and never appears on the MAS surface).
    static let builtIn: [FineTunePack] = [
        FineTunePack(
            id: "epistemos.vault.dataset",
            kind: .dataset,
            displayName: "Your vault → chat dataset",
            source: .localFile(URL(fileURLWithPath: "Vault")),
            license: "Vault content (user-owned)",
            gate: .free,
            provenance: "first_party"
        ),
        FineTunePack(
            id: "epistemos.nano.instructions",
            kind: .instructionPack,
            displayName: "Epistemos-Nano instructions",
            source: .localFile(URL(fileURLWithPath: "Instructions")),
            license: "Epistemos (first-party)",
            gate: .free,
            provenance: "first_party"
        ),
        FineTunePack(
            id: "epistemos.lora.local",
            kind: .loraAdapter,
            displayName: "Locally-trained LoRA adapter",
            source: .localFile(URL(fileURLWithPath: "Adapters")),
            license: "Epistemos (first-party)",
            gate: .pro,
            provenance: "first_party"
        ),
    ]

    /// A registry seeded with the built-in first-party packs. Third-party packs are
    /// added at runtime through `FineTunePackRegistry.add` (ProvenanceGate license
    /// check + dedup).
    static func seededRegistry() -> FineTunePackRegistry {
        var registry = FineTunePackRegistry()
        for pack in builtIn {
            // add() only throws on an unlicensed / duplicate pack; the built-ins are
            // licensed + unique, so a throw would be a programmer error — swallow.
            _ = try? registry.add(pack)
        }
        return registry
    }
}
