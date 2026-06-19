import Foundation

// R-LITEPARSE — Seam A gate (owner 2026-06-19). Honest flag-status for
// EPISTEMOS_LITEPARSE_PDF_V0, read by the visible LiteParseImportHealthRow. ALWAYS-
// compiled + pure (NO liteparse dependency) so the build shows the honest status
// WITHOUT the native PDFium/Tesseract deps. Mirrors WorkBackendGateStatus.
//
// MAS-SAFE BY SCOPE: dedicated PDF→Markdown is fully LOCAL — in-process PDFium + bundled
// Tesseract OCR, NO sidecar. liteparse's Office/image formats route through LibreOffice /
// ImageMagick SUBPROCESSES = NOT MAS-safe → OUT OF SCOPE (rejected, never shelled out).
// The run-llama/liteparse Rust vendor (Apache-2.0, into agent_core via UniFFI) is the
// heavy native-dep follow-on (S2); until it lands the seam is honestly INERT.
nonisolated enum LiteParseImportGateStatus {
    static let flagName = "EPISTEMOS_LITEPARSE_PDF_V0"

    struct Status: Equatable, Sendable {
        let isActive: Bool
        let headline: String
        let detail: String
    }

    static func isEnabled(_ raw: String?) -> Bool {
        guard let n = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return false }
        return ["1", "true", "yes", "on"].contains(n)
    }

    static func status(environment: [String: String] = ProcessInfo.processInfo.environment) -> Status {
        if isEnabled(environment[flagName]) {
            return Status(
                isActive: true,
                headline: "PDF→Markdown import: armed (engine not wired yet)",
                detail: "The liteparse seam is armed (\(flagName)=1). The run-llama/liteparse Rust core (Apache-2.0, in-process PDFium + Tesseract OCR — MAS-safe) is the native-dep follow-on; until it lands the seam is honestly INERT (no fake markdown). PDF only — Office/image formats are out of scope (they need external binaries)."
            )
        }
        return Status(
            isActive: false,
            headline: "PDF→Markdown import: coming (opt-in)",
            detail: "Set \(flagName)=1 to arm the liteparse PDF import seam. Dedicated, fully LOCAL PDF→Markdown (in-process PDFium + Tesseract OCR, no sidecar); PDF only. Off by default → not yet wired."
        )
    }
}
