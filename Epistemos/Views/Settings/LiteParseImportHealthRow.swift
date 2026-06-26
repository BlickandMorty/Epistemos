import SwiftUI

// Visible gate surface for the R-LITEPARSE PDF→Markdown import seam (rule #8 — the owner
// can SEE the feature + its honest status). ALWAYS-compiled; renders the honest
// LiteParseImportGateStatus (no native PDFium/Tesseract dependency).
struct LiteParseImportHealthRow: View {
    private var status: LiteParseImportGateStatus.Status { LiteParseImportGateStatus.status() }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: status.isActive ? "doc.richtext.fill" : "doc.richtext")
                    .foregroundStyle(status.isActive ? Color.green : Color.secondary)
                Text(status.headline)
                    .font(.callout.weight(.medium))
                Spacer(minLength: 0)
            }
            Text(status.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
