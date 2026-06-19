//! R-LITEPARSE seam — dedicated PDF→Markdown import (owner 2026-06-19). The
//! run-llama/liteparse Rust core (Apache-2.0) links into agent_core as a crate (like
//! epistemos-shadow / the Goose Work seam) and exposes `pdf_to_markdown` over UniFFI —
//! NO Python/Node sidecar.
//!
//! MAS SCOPE (NON-NEGOTIABLE): PDF only (PDFium in-process) + in-process Tesseract OCR.
//! liteparse's Office/image formats route through LibreOffice / ImageMagick / powershell
//! SUBPROCESSES (`conversion.rs::execute_command` / `convert_to_pdf` /
//! `resolve_image_magick_command`) — those are NOT MAS-safe and are OUT OF SCOPE: a
//! non-PDF input is rejected honestly here, never silently shelled out.
//!
//! Always-compiled + INERT until the liteparse crate is vendored + the PDFium/Tesseract
//! native deps are wired (the heavy follow-on). REAL APIs ONLY — no fake markdown, no
//! silent fallback. ProvenanceGate verdict: docs/RESEARCH_LITEPARSE_2026_06_19.md.

/// Flag that arms the liteparse PDF→Markdown path (mirrors the Swift gate).
pub const LITEPARSE_FLAG: &str = "EPISTEMOS_LITEPARSE_PDF_V0";

/// ProvenanceGate posture for the vendored run-llama/liteparse core.
pub const LITEPARSE_VENDOR_LICENSE: &str = "Apache-2.0";
pub const LITEPARSE_VENDOR_SOURCE: &str = "run-llama/liteparse";

/// Honest errors for a PDF→Markdown conversion. The caller surfaces these; the seam
/// NEVER returns fake markdown and NEVER shells out for an unsupported format.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LiteParseError {
    /// The liteparse engine isn't vendored/wired yet.
    EngineNotWired,
    /// A non-PDF input — Office/image need external binaries (NOT MAS-safe), out of scope.
    UnsupportedFormat(String),
    /// The conversion ran but failed.
    Failed(String),
}

impl std::fmt::Display for LiteParseError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            LiteParseError::EngineNotWired => write!(f, "LiteParse PDF engine not wired"),
            LiteParseError::UnsupportedFormat(ext) => write!(
                f,
                "unsupported format '{ext}' — only PDF is supported on the MAS path (Office/image need external binaries)"
            ),
            LiteParseError::Failed(m) => write!(f, "PDF→Markdown failed: {m}"),
        }
    }
}
impl std::error::Error for LiteParseError {}

fn flag_is_armed(raw: Option<&str>) -> bool {
    matches!(
        raw.map(|s| s.trim().to_ascii_lowercase()).as_deref(),
        Some("1") | Some("true") | Some("yes") | Some("on")
    )
}

/// Whether the liteparse PDF seam is armed (the env flag is set). Arming only opts in;
/// it does NOT wire the engine — the engine is the gated vendor.
pub fn is_armed() -> bool {
    flag_is_armed(std::env::var(LITEPARSE_FLAG).ok().as_deref())
}

/// Whether `path` is a PDF we can parse IN-PROCESS (PDFium). Non-PDF formats
/// (docx/xlsx/png/…) need external binaries on liteparse's side → NOT MAS-safe → not
/// supported here.
pub fn is_supported_pdf(path: &str) -> bool {
    path.rsplit('.')
        .next()
        .map(|ext| ext.eq_ignore_ascii_case("pdf"))
        .filter(|_| path.contains('.'))
        .unwrap_or(false)
}

/// The honest seam: a local PDF → Markdown (PDFium + in-process OCR). A non-PDF input is
/// rejected with `UnsupportedFormat` (never shelled out). Until the liteparse crate is
/// vendored this is INERT — a PDF returns `EngineNotWired` (NEVER fake markdown). The
/// real engine replaces this body.
pub fn pdf_to_markdown(pdf_path: &str) -> Result<String, LiteParseError> {
    if !is_supported_pdf(pdf_path) {
        let ext = pdf_path.rsplit('.').next().unwrap_or("").to_string();
        return Err(LiteParseError::UnsupportedFormat(ext));
    }
    Err(LiteParseError::EngineNotWired)
}

/// FFI: convert a local PDF to Markdown for the Swift import UI. Returns a JSON envelope
/// — `{"ok":true,"markdown":"…"}` on success, or `{"ok":false,"error":"…"}` on failure
/// (engine not wired / unsupported format / conversion failed) so the import surface
/// shows the honest outcome, NEVER a fake/empty note. A non-PDF is rejected
/// (`UnsupportedFormat`), never shelled out. INERT until the liteparse crate is vendored
/// (S2) — a PDF returns the `engine not wired` error today.
#[uniffi::export]
pub fn liteparse_pdf_to_markdown(pdf_path: String) -> String {
    match pdf_to_markdown(&pdf_path) {
        Ok(markdown) => format!(
            "{{\"ok\":true,\"markdown\":{}}}",
            serde_json::to_string(&markdown).unwrap_or_else(|_| "\"\"".to_string())
        ),
        Err(e) => format!(
            "{{\"ok\":false,\"error\":{}}}",
            serde_json::to_string(&e.to_string()).unwrap_or_else(|_| "\"conversion error\"".to_string())
        ),
    }
}

/// FFI: the liteparse seam status as JSON, for the Swift import UI to read across the
/// UniFFI boundary. Honest — reports the engine is not yet wired + the PDF+OCR scope.
#[uniffi::export]
pub fn liteparse_status_json() -> String {
    format!(
        "{{\"engine_wired\":false,\"armed\":{},\"flag\":\"{}\",\"license\":\"{}\",\"source\":\"{}\",\"scope\":\"pdf+ocr,no-subprocess\"}}",
        is_armed(),
        LITEPARSE_FLAG,
        LITEPARSE_VENDOR_LICENSE,
        LITEPARSE_VENDOR_SOURCE
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn flag_parsing_is_honest() {
        assert!(flag_is_armed(Some("1")));
        assert!(flag_is_armed(Some(" On ")));
        assert!(!flag_is_armed(None));
        assert!(!flag_is_armed(Some("0")));
    }

    #[test]
    fn only_pdf_is_supported_mas_safe() {
        assert!(is_supported_pdf("paper.pdf"));
        assert!(is_supported_pdf("/a/b/Report.PDF"));
        assert!(!is_supported_pdf("doc.docx")); // Office → external binary, out of scope
        assert!(!is_supported_pdf("scan.png")); // image → ImageMagick, out of scope
        assert!(!is_supported_pdf("noext"));
    }

    #[test]
    fn inert_seam_refuses_honestly_never_fakes_markdown() {
        // A PDF, but no engine wired → honest EngineNotWired (NEVER fabricated markdown).
        assert_eq!(pdf_to_markdown("paper.pdf"), Err(LiteParseError::EngineNotWired));
    }

    #[test]
    fn non_pdf_is_rejected_never_shelled_out() {
        // Office/image are rejected honestly — the seam never invokes a subprocess.
        match pdf_to_markdown("book.docx") {
            Err(LiteParseError::UnsupportedFormat(ext)) => assert_eq!(ext, "docx"),
            other => panic!("expected UnsupportedFormat, got {other:?}"),
        }
    }

    #[test]
    fn status_json_reports_engine_not_wired_and_scope() {
        let json = liteparse_status_json();
        assert!(json.contains("\"engine_wired\":false"));
        assert!(json.contains("pdf+ocr,no-subprocess"));
        assert!(json.contains("Apache-2.0"));
        assert!(json.contains(LITEPARSE_FLAG));
    }

    #[test]
    fn ffi_pdf_to_markdown_returns_honest_error_envelope_when_inert() {
        // A PDF, engine not wired → an honest error envelope (never fake markdown).
        let out = liteparse_pdf_to_markdown("paper.pdf".to_string());
        assert!(out.contains("\"ok\":false"));
        assert!(out.contains("not wired"));
        assert!(!out.contains("\"markdown\""));
    }

    #[test]
    fn ffi_pdf_to_markdown_rejects_non_pdf_in_the_envelope() {
        let out = liteparse_pdf_to_markdown("book.docx".to_string());
        assert!(out.contains("\"ok\":false"));
        assert!(out.contains("unsupported format"));
    }
}
