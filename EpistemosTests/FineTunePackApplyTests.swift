import Testing
import Foundation
@testable import Epistemos

/// DATA+FINETUNE part (5) APPLY — locks the honest per-kind apply action: each pack
/// kind maps to the right verb + an honest description that names WHERE it runs, and
/// the marketplace view wires the Apply affordance (button + confirm). The apply
/// never fakes an execution the browse surface can't perform (the real per-kind
/// execution is the gated on-device step).
@Suite("Fine-tune pack apply affordance")
struct FineTunePackApplyTests {

    @Test("every pack kind maps to the expected apply action")
    func kindToActionMapping() {
        #expect(FineTunePackKind.dataset.applyAction == .importDataset)
        #expect(FineTunePackKind.loraAdapter.applyAction == .applyAdapter)
        #expect(FineTunePackKind.instructionPack.applyAction == .applyInstructions)
        #expect(FineTunePackKind.knowledgePack.applyAction == .importKnowledge)
    }

    @Test("every apply action has a non-empty verb + honest description")
    func actionsAreDescribed() {
        for action in FineTunePackApplyAction.allCases {
            #expect(!action.verb.isEmpty)
            #expect(!action.honestDescription.isEmpty)
        }
    }

    @Test("on-device actions are flagged honestly (adapter + knowledge run on-device)")
    func runsOnDeviceIsHonest() {
        #expect(FineTunePackApplyAction.applyAdapter.runsOnDevice)
        #expect(FineTunePackApplyAction.importKnowledge.runsOnDevice)
        #expect(!FineTunePackApplyAction.importDataset.runsOnDevice)
        #expect(!FineTunePackApplyAction.applyInstructions.runsOnDevice)
    }

    @Test("the LoRA-adapter description directs the owner on-device (never a fake apply)")
    func adapterDescriptionIsHonest() {
        let desc = FineTunePackApplyAction.applyAdapter.honestDescription
        #expect(desc.localizedCaseInsensitiveContains("on-device"))
        #expect(desc.localizedCaseInsensitiveContains("model"))
    }

    @Test("pack.applyConfirmation mirrors its kind's honest description")
    func packConfirmationMirrorsKind() {
        let pack = FineTunePackCatalog.builtIn.first { $0.kind == .loraAdapter }
        // The seed catalog ships at least one LoRA adapter pack.
        #expect(pack != nil)
        if let pack {
            #expect(pack.applyConfirmation == FineTunePackApplyAction.applyAdapter.honestDescription)
        }
    }

    @Test("marketplace view wires the Apply button + honest confirm")
    func marketplaceViewWiresApply() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/FineTuneMarketplaceView.swift")
        // an honest per-kind apply button + the confirm flow.
        #expect(src.contains("pendingApplyPack"))
        #expect(src.contains("applyAction.verb"))
        #expect(src.contains("applyConfirmation"))
        #expect(src.contains(".alert("))
    }
}
