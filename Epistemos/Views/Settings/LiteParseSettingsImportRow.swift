import SwiftUI

/// R-LITEPARSE — the **Settings bulk-import surface** (owner's R-LITEPARSE plan item #4).
///
/// A labeled Settings row that offers the same bulk PDF→Markdown import as the note-sidebar
/// button — it EMBEDS `LiteParsePDFImportButton`, so there is exactly ONE import path (no
/// duplicated picker/convert/note-create logic). Gated by `EPISTEMOS_LITEPARSE_PDF_V0`
/// (`LiteParseImportGateStatus`): hidden when the flag is off, so it is opt-in and adds
/// nothing to Settings by default.
///
/// Mounted in `SubstrateHealthPanel` directly beneath `LiteParseImportHealthRow`, inside
/// `SettingsView`'s environment where `VaultSyncService` / `GraphState` / `modelContext`
/// are ambient (the embedded button reads them). Because the `if isActive` short-circuits
/// before the button is constructed, the button — and therefore its `@Environment` reads —
/// only exist when the owner has armed the flag, so the default build / previews never
/// require those environment objects.
struct LiteParseSettingsImportRow: View {
    private var isActive: Bool { LiteParseImportGateStatus.status().isActive }

    var body: some View {
        if isActive {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import PDFs as notes")
                        .font(.callout)
                    Text("Pick one or more PDFs — each becomes a Markdown note in your vault "
                        + "(in-process PDFium, PDF only). Honest per-file status; no note on failure.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                LiteParsePDFImportButton()
            }
        }
    }
}
