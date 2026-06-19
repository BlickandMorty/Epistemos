import Testing
import Foundation
@testable import Epistemos

/// R-LITEPARSE — the Settings bulk-import surface (owner plan #4). Locks that the row is
/// flag-gated, routes through the SAME import button (one import path, no duplicated
/// picker/convert logic), and is mounted in the Substrate health panel.
@Suite("LiteParse Settings import row")
struct LiteParseSettingsImportRowTests {

    @Test("the Settings row is flag-gated and embeds the one shared import button")
    func gatedAndReusesButton() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/LiteParseSettingsImportRow.swift")
        // hidden unless the flag is on (same gate as the sidebar button)
        #expect(src.contains("LiteParseImportGateStatus.status().isActive"))
        // embeds the existing button → one import path, no duplicated NSOpenPanel/controller logic
        #expect(src.contains("LiteParsePDFImportButton()"))
        // no second copy of the picker/controller wiring
        #expect(!src.contains("NSOpenPanel"))
        #expect(!src.contains("LiteParsePDFImportController"))
    }

    @Test("the Settings row is mounted in the Substrate health panel")
    func mountedInPanel() throws {
        let panel = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SubstrateHealthPanel.swift")
        #expect(panel.contains("LiteParseSettingsImportRow()"))
    }
}
