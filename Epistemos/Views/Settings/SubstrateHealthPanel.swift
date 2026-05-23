import SwiftUI

// MARK: - SubstrateHealthPanel
//
// W6 from the Terminal 1 WRV mission
// (`docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md`):
//
// > one unified panel showing Eidos, VaultRecall, SystemG, F-ULP,
// > Lattice/WBO, ACS, UAS, AnswerPacket status.
//
// Today these rows are individually mounted in the General →
// Diagnostics section of `SettingsView`, scattered between
// general-purpose rows (RuntimeTruth, ShadowSearch, ProcessMemory, …).
// The user has to scroll a long list to spot whether a particular
// substrate is healthy. This panel composes the seven cross-terminal
// substrate diagnostics together so the WRV substrate cluster reads as
// one coherent product surface.
//
// **No new substrate logic.** The panel only re-mounts the existing
// HealthRow views; their metrics, refresh logic, and feature flags are
// unchanged. Each child row still listens to its own
// `didChangeNotification` and refreshes independently — moving them
// into a parent VStack does not gate, throttle, or otherwise alter
// their observation contracts.
//
// **UAS row deferred.** The W-10 `UasAcsHealthRow.swift` is not yet
// implemented (NOT-STARTED in
// `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md`); the
// panel surfaces a placeholder note so the missing substrate is
// visible rather than silently absent.

@MainActor
public struct SubstrateHealthPanel: View {

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsDescriptionText(
                text: "WRV substrate cluster. Each row carries its own feature flag + backend-origin indicator: rows that read fixture/stub data show a ✗ on the flag indicator until Terminal 2 lands real production wiring. See the per-row labels for the W-NN handoff that flips each substrate to a real backend."
            )

            // Eidos V0 — closed-citation retrieval (T10).
            // Backend honesty added in commit 7dc4ea9faf (W1 hardening):
            // fixture-corpus today; real vault binding lands under W-46.1.
            EidosHealthRow()

            // Vault Recall Contract (T21) — 5-signal trace emission.
            // Backend honesty added in commit ebc62166ab (W2 hardening):
            // scaffold-lexical today; real VaultBackend lands under W-21.1.
            VaultRecallHealthRow()

            // Lattice / Wyner-Ziv / WBO accounting (T17B) — oplog audit
            // counter for every successful mutation. Always-on (per T17B
            // contract that hidden mutations are inadmissible).
            LatticeWBOHealthRow()

            // System G / Agent Runtime v2 (T11) — mode + capability
            // gates + build tier breadcrumb. Status-read only today; the
            // full MissionPacket → AgentEvent → RunEventLog →
            // AnswerPacket flow lands in W-11..W-18 + W-44..W-45.
            SystemGHealthRow()

            // F-ULP-Oracle (T12) — arithmetic verification floor
            // witness; surfaces "max ULP ≤ 2 fp16" gate state.
            FUlpHealthRow()

            // ACS Admission Field (T18B) — policy verdict ledger.
            // Records every admission verdict in the RunEventLog
            // adapter once W-46 (T11 wire) lands.
            ACSAdmissionHealthRow()

            // AnswerPacket emitter (T2) — V6.2 audit channel. Bounded
            // ring of per-turn packets with attention_mode +
            // interruptBucket + uiLabel; refresh is event-driven via
            // `didEmitNotification`. Per
            // docs/audits/V6_2_LAPTOP_MANUAL_AUDIT_CHECKLIST_2026_05_07.md.
            AnswerPacketHealthRow()

            // W-10 UAS-ACS substrate health row (`UasAcsHealthRow.swift`)
            // is NOT-STARTED per
            // docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md
            // §2. Surface the gap explicitly so the WRV cluster is
            // self-describing about its still-missing pieces.
            uasPlaceholderRow()
        }
    }

    @ViewBuilder
    private func uasPlaceholderRow() -> some View {
        HStack(spacing: 10) {
            Image(systemName: "questionmark.circle")
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("UAS-ACS substrate health")
                    .font(.system(size: 13, weight: .medium))
                Text("UasAcsHealthRow not yet implemented (W-10 NOT-STARTED)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(AnyShapeStyle(Color.orange))
                .font(.system(size: 16))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
