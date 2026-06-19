import Foundation

// DATA+FINETUNE part (5) — the honest APPLY action for a marketplace pack. What
// "applying" does depends on the kind, and the real execution is ON-DEVICE (a loaded
// local model / the vault / the native training pipeline). So the marketplace
// affordance is HONEST about WHAT apply does and WHERE it runs — it never fakes an
// immediate apply it can't perform from the browse surface. Pure + unit-tested; the
// per-kind execution is the gated on-device follow-on.
enum FineTunePackApplyAction: String, Equatable, Sendable, CaseIterable {
    case applyAdapter        // .loraAdapter   → load into the active local model
    case importDataset       // .dataset       → add to the native training data
    case applyInstructions   // .instructionPack → set as the system prompt
    case importKnowledge     // .knowledgePack → import into the vault

    /// The button label.
    var verb: String {
        switch self {
        case .applyAdapter: "Apply"
        case .importDataset: "Import"
        case .applyInstructions: "Use"
        case .importKnowledge: "Import"
        }
    }

    /// Honest one-liner of what applying does + where it runs — no fake claim of an
    /// immediate apply when it needs on-device state.
    var honestDescription: String {
        switch self {
        case .applyAdapter:
            "Loads this LoRA adapter into your active local model — open a model first (Pro, on-device)."
        case .importDataset:
            "Marks this dataset for your next native fine-tune (training runs on-device)."
        case .applyInstructions:
            "Uses this instruction pack as the model's system prompt."
        case .importKnowledge:
            "Imports this knowledge pack into your vault (on-device)."
        }
    }

    /// Whether the apply genuinely needs on-device state (a loaded model / the vault)
    /// — the marketplace directs the owner there rather than faking it.
    var runsOnDevice: Bool {
        switch self {
        case .applyAdapter, .importKnowledge: true
        case .importDataset, .applyInstructions: false
        }
    }
}

extension FineTunePackKind {
    /// The honest apply action for this pack kind.
    var applyAction: FineTunePackApplyAction {
        switch self {
        case .dataset: .importDataset
        case .loraAdapter: .applyAdapter
        case .instructionPack: .applyInstructions
        case .knowledgePack: .importKnowledge
        }
    }
}

extension FineTunePack {
    /// The honest confirmation prompt shown when the owner taps the apply button.
    var applyConfirmation: String {
        kind.applyAction.honestDescription
    }
}
