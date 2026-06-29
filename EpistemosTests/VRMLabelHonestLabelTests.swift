import Foundation
import Testing
@testable import Epistemos

@Suite("Plan 3 provenance moat — honest VRM labels")
struct VRMLabelHonestLabelTests {
    @Test("empty packet renders no VRM label")
    func emptyPacketRendersNoLabel() {
        let packet = Self.packet(claims: [], storedLabel: .verified)
        #expect(VRMLabel.honestLabel(for: packet) == nil)
    }

    @Test("UAS-addressed empirical self-witness is plausible, never verified")
    func uasAddressedEmpiricalClaimIsPlausible() {
        let packet = Self.packet(claims: [
            Self.claim(kind: .empirical, status: .active, uasAddressed: true)
        ])

        #expect(VRMLabel.honestLabel(for: packet) == .plausibleButUnverified)
    }

    @Test("ACS-anchored empirical and code-invariant claims are verified")
    func acsAnchoredVerifiableClaimsAreVerified() {
        #expect(VRMLabel.honestLabel(for: Self.packet(claims: [
            Self.claim(kind: .empirical, status: .active, acsAnchored: true)
        ])) == .verified)

        #expect(VRMLabel.honestLabel(for: Self.packet(claims: [
            Self.claim(kind: .codeInvariant, status: .active, acsAnchored: true)
        ])) == .verified)
    }

    @Test("malformed anchor objects cannot promote active claims to verified")
    func malformedAnchorObjectsCannotPromoteVerified() {
        let emptyUAS = Claim(
            id: "claim-empty-uas",
            text: "active empirical claim with empty UAS placeholder",
            status: .active,
            createdAtMs: 1_783_000_000_000,
            kind: .empirical,
            uasAddress: UasAddress(kind: "", hash: "", createdAtMs: 0)
        )
        let malformedACS = Claim(
            id: "claim-bad-acs",
            text: "active empirical claim with malformed ACS placeholder",
            status: .active,
            createdAtMs: 1_783_000_000_000,
            kind: .empirical,
            acsAnchor: AcsAnchor(
                anchorId: "",
                theoremId: "E1",
                plane: .episodic,
                residency: .verifiedFloor,
                salience: 0.7
            )
        )

        #expect(emptyUAS.hasUasAddress == false)
        #expect(emptyUAS.hasVerificationAnchor == false)
        #expect(malformedACS.hasVerificationAnchor == false)
        #expect(VRMLabel.honestLabel(for: Self.packet(claims: [emptyUAS, malformedACS])) == .plausibleButUnverified)
    }

    @Test("ACS-anchored speculative claims do not become verified")
    func acsAnchoredSpeculativeClaimsStayPlausible() {
        let packet = Self.packet(claims: [
            Self.claim(kind: .speculative, status: .active, acsAnchored: true)
        ])

        #expect(VRMLabel.honestLabel(for: packet) == .plausibleButUnverified)
    }

    @Test("ACS anchors must be bound to the rendered packet before Verified appears")
    func acsAnchorsMustBeBoundToRenderedPacket() {
        #expect(VRMLabel.honestLabel(for: Self.packet(claims: [
            Self.claim(kind: .empirical, status: .active, acsAnchored: true, activePacketId: nil)
        ])) == .plausibleButUnverified)

        #expect(VRMLabel.honestLabel(for: Self.packet(claims: [
            Self.claim(
                kind: .empirical,
                status: .active,
                acsAnchored: true,
                activePacketId: "borrowed-packet"
            )
        ])) == .plausibleButUnverified)
    }

    @Test("ACS anchor packet ids must be well formed before Verified appears")
    func acsAnchorPacketIDsMustBeWellFormed() {
        let malformedPacketID = "pkt@test"
        let claim = Self.claim(
            kind: .empirical,
            status: .active,
            acsAnchored: true,
            activePacketId: malformedPacketID
        )
        let packet = Self.packet(id: malformedPacketID, claims: [claim])

        #expect(claim.hasVerificationAnchor == false)
        #expect(VRMLabel.honestLabel(for: packet) == .plausibleButUnverified)
    }

    @Test("unanchored speculative active claims render speculative")
    func unanchoredSpeculativeClaimsRenderSpeculative() {
        let packet = Self.packet(claims: [
            Self.claim(kind: .speculative, status: .active)
        ])

        #expect(VRMLabel.honestLabel(for: packet) == .speculative)
    }

    @Test("verified cannot leak without active ACS-anchored verifiable claim")
    func verifiedInvariantSweep() {
        let statuses: [ClaimStatus] = [.active, .atRisk, .needsRevalidation, .retracted]

        for kind in ClaimKind.allCases {
            for status in statuses {
                let labelWithoutAnchor = VRMLabel.honestLabel(for: Self.packet(claims: [
                    Self.claim(kind: kind, status: status)
                ]))
                #expect(labelWithoutAnchor != .verified)

                let labelWithAnchor = VRMLabel.honestLabel(for: Self.packet(claims: [
                    Self.claim(kind: kind, status: status, acsAnchored: true)
                ]))
                let expectedVerified = status == .active
                    && [.empirical, .mathematical, .codeInvariant].contains(kind)
                #expect((labelWithAnchor == VRMLabel.verified) == expectedVerified)
            }
        }
    }

    @Test("VRMLabelView binds only through honestLabel")
    func vrmLabelViewDoesNotTrustStoredPacketLabel() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Provenance/VRMLabelView.swift")
        #expect(source.contains("VRMLabel.honestLabel(for: packet)"))
        #expect(source.contains("guard let honestLabel = VRMLabel.honestLabel(for: packet) else { return nil }"))
        #expect(source.contains("LatestAnswerPacketSink.shared.packet(for: packetID)"))
        #expect(source.contains("message.answerPacketId"))
        #expect(source.contains("VRMLineageExport.make("))
        #expect(source.contains("ClaimLineageRow(claim: claim, packetID: packet.id)"))
        #expect(source.contains("claim.isVerifiedByAnchor(forPacketID: packetID)"))
        #expect(source.contains("NSPasteboard.general.setString(export.encodedJSONString(), forType: .string)"))
        #expect(source.contains("encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]"))
        #expect(source.contains("Copy lineage JSON"))
        #expect(!source.contains("packet.uiLabel"))
    }

    @Test("lineage export is deterministic and excludes legacy stored label")
    func lineageExportIsDeterministicAndHonest() throws {
        let packet = Self.packet(
            claims: [
                Self.claim(kind: .empirical, status: .active, acsAnchored: true),
                Self.claim(
                    kind: .empirical,
                    status: .retracted,
                    acsAnchored: true,
                    createdAtMs: 1_784_000_000_000
                ),
            ],
            storedLabel: .blocked
        )
        let export = try #require(VRMLineageExport.make(
            packet: packet,
            modelLabel: "test-model",
            tierLabel: "dynamic",
            acceptedAt: Date(timeIntervalSince1970: 42)
        ))
        let json = export.encodedJSONString()
        let decoded = try JSONDecoder().decode(VRMLineageExport.self, from: Data(json.utf8))

        #expect(decoded == export)
        #expect(export.schema == "epistemos.vrm_lineage.v1")
        #expect(export.honestLabel == .verified)
        #expect(export.modelLabel == "test-model")
        #expect(export.acceptedAtMs == 42_000)
        #expect(export.generatedAtMs == 1_783_000_000_000)
        #expect(export.claims.map(\.status) == [.active])
        #expect(!json.contains("ui_label"))
        #expect(json.contains("\"honest_label\""))
        #expect(json.contains("\"packet_id\""))
    }

    @Test("lineage export renders nothing for unclaimed packets")
    func lineageExportRequiresHonestVisibleLabel() {
        let export = VRMLineageExport.make(
            packet: Self.packet(claims: [], storedLabel: .verified),
            modelLabel: "test-model",
            tierLabel: "dynamic",
            acceptedAt: Date(timeIntervalSince1970: 42)
        )

        #expect(export == nil)
    }

    @Test("AnswerPacketEmitter derives Rust-produced labels through the honest gate")
    func emitterStampsRustPacketWithHonestGate() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/AnswerPacketEmitter.swift")
        #expect(source.contains("VRMLabel.honestLabel(for: stamped)"))
        #expect(source.contains("stamped.uiLabel = honest"))
        #expect(source.contains("stamped.uiLabel = .default"))
    }

    @Test("Plan 3 provenance docs describe the shipped honest moat")
    func plan3ProvenanceDocsTrackShippedMoat() throws {
        let codepack = try loadMirroredSourceTextFile("docs/research/PLAN_3_PROVENANCE_CODEPACK_2026_06_28.md")
        let capability = try loadMirroredSourceTextFile("docs/research/PLAN_3_CAPABILITIES_2026_06_28.md")

        for phrase in [
            "Fix A — honest label gate [DELIVERED]",
            "Fix B — tightened `VerifiedFloorChipStrip` [DELIVERED]",
            "Moat-1 — `VRMLabelView` hover-lineage card [DELIVERED]",
            "Moat-3 — copy verifiable lineage JSON [DELIVERED]",
            "message.resolvedModelLabel",
            "message.mode?.rawValue",
            "message.createdAt",
        ] {
            #expect(codepack.contains(phrase), "Provenance codepack must include \(phrase)")
        }

        for phrase in [
            "`VRMLabel.honestLabel(for:)` gates every per-answer label",
            "`VRMLabelView` renders only `honestLabel(for:)`",
            "`requiresLiveBacking: .ledger/.dag`",
            "`VRMLineageExport`",
            "Moat-3 (delivered)",
            "Provenance moat follow-up",
        ] {
            #expect(capability.contains(phrase), "Capability doc must include \(phrase)")
        }

        for stale in [
            "VRMLabelView exists nowhere",
            "per-answer VRM chip renderer is DELETED",
            "chip is currently honest-by-omission",
            "NEW `Epistemos/Views/Provenance/VRMLabelView.swift`",
            "[INFERRED]` confirm `message.modelDisplayName/.capabilityTier/.timestamp`",
        ] {
            #expect(!codepack.contains(stale), "Provenance codepack must not contain stale claim \(stale)")
            #expect(!capability.contains(stale), "Capability doc must not contain stale claim \(stale)")
        }
    }

    private static func packet(
        id: String = "pkt-test",
        claims: [Claim],
        storedLabel: VRMLabel = .plausibleButUnverified
    ) -> AnswerPacket {
        AnswerPacket(
            id: id,
            claims: claims,
            residencySignals: [.neutral],
            uiLabel: storedLabel,
            witnessedStateRef: "stop:end_turn;in:1;out:1",
            mutationEnvelopeRef: id
        )
    }

    private static func claim(
        kind: ClaimKind,
        status: ClaimStatus,
        acsAnchored: Bool = false,
        uasAddressed: Bool = false,
        activePacketId: String? = "pkt-test",
        createdAtMs: Int64 = 1_783_000_000_000
    ) -> Claim {
        Claim(
            id: "\(kind.rawValue)-\(status.rawValue)-acs-\(acsAnchored)-uas-\(uasAddressed)",
            text: "\(kind.rawValue) \(status.rawValue)",
            status: status,
            createdAtMs: createdAtMs,
            kind: kind,
            uasAddress: uasAddressed ? UasAddress(
                kind: "claim",
                hash: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
                createdAtMs: UInt64(clamping: createdAtMs)
            ) : nil,
            acsAnchor: acsAnchored ? AcsAnchor(
                anchorId: "anchor-\(kind.rawValue)-\(status.rawValue)",
                theoremId: "E1",
                plane: .episodic,
                residency: .verifiedFloor,
                activePacketId: activePacketId,
                salience: 0.7
            ) : nil
        )
    }
}
