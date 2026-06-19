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

/// Reject a non-PDF input honestly (Office/image need external binaries → out of scope).
/// Shared by both the inert and the live engine bodies so the MAS scope is enforced
/// identically regardless of build.
fn reject_if_not_pdf(pdf_path: &str) -> Result<(), LiteParseError> {
    if !is_supported_pdf(pdf_path) {
        let ext = pdf_path.rsplit('.').next().unwrap_or("").to_string();
        return Err(LiteParseError::UnsupportedFormat(ext));
    }
    Ok(())
}

/// The honest seam: a local PDF → Markdown (PDFium, in-process). A non-PDF input is
/// rejected with `UnsupportedFormat` (never shelled out).
///
/// INERT build (default / MAS): a PDF returns `EngineNotWired` — NEVER fake markdown. The
/// real PDFium engine is compiled only under the `liteparse-pdf` feature (Pro/dev), so the
/// MAS binary does not link PDFium/bindgen and stays honest about not having the engine.
#[cfg(not(feature = "liteparse-pdf"))]
pub fn pdf_to_markdown(pdf_path: &str) -> Result<String, LiteParseError> {
    reject_if_not_pdf(pdf_path)?;
    Err(LiteParseError::EngineNotWired)
}

/// LIVE build (`--features liteparse-pdf`, Pro/dev): the embedded run-llama/liteparse core
/// extracts the PDF's spatial text via in-process PDFium (OCR OFF — no Tesseract, no
/// subprocess, no network) and renders Markdown. The async `parse` is driven on a
/// dedicated current-thread tokio runtime so the synchronous UniFFI export stays sync.
/// A non-PDF is still rejected up front; a real conversion failure → honest `Failed`.
#[cfg(feature = "liteparse-pdf")]
pub fn pdf_to_markdown(pdf_path: &str) -> Result<String, LiteParseError> {
    reject_if_not_pdf(pdf_path)?;
    use liteparse::config::{LiteParseConfig, OutputFormat};
    use liteparse::parser::LiteParse;
    let config = LiteParseConfig {
        output_format: OutputFormat::Markdown,
        // OCR off → pure PDFium text extraction, no Tesseract/subprocess/network (MAS-safe core).
        ocr_enabled: false,
        quiet: true,
        ..Default::default()
    };
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .map_err(|e| LiteParseError::Failed(format!("tokio runtime: {e}")))?;
    let result = runtime
        .block_on(async { LiteParse::new(config).parse(pdf_path).await })
        .map_err(|e| LiteParseError::Failed(e.to_string()))?;
    Ok(result.text)
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
    // `engine_wired` is true only when the real PDFium engine is compiled in (the
    // `liteparse-pdf` feature, Pro/dev). The default MAS build links no engine → false,
    // matching the inert `pdf_to_markdown`. The scope literal "pdf+ocr,no-subprocess" is
    // the DESIGN boundary (PDF + in-process OCR, never a subprocess); OCR is currently
    // compile-disabled (default-features=false drops tesseract) per vendor/liteparse/README.
    let engine_wired = cfg!(feature = "liteparse-pdf");
    format!(
        "{{\"engine_wired\":{},\"armed\":{},\"flag\":\"{}\",\"license\":\"{}\",\"source\":\"{}\",\"scope\":\"pdf+ocr,no-subprocess\"}}",
        engine_wired,
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

    #[cfg(not(feature = "liteparse-pdf"))]
    #[test]
    fn inert_seam_refuses_honestly_never_fakes_markdown() {
        // INERT build: a PDF, but no engine wired → honest EngineNotWired (NEVER fabricated markdown).
        assert_eq!(pdf_to_markdown("paper.pdf"), Err(LiteParseError::EngineNotWired));
    }

    #[cfg(feature = "liteparse-pdf")]
    #[test]
    fn live_engine_fails_honestly_on_missing_pdf_never_fakes_markdown() {
        // LIVE build: a PDF *path* that does not exist → the real engine runs and returns an
        // honest Failed (NEVER EngineNotWired, NEVER fabricated markdown, NEVER a panic). Any
        // failure path (missing file or PDFium not loadable) maps to Failed, so this is robust.
        match pdf_to_markdown("/nonexistent/epistemos-liteparse-probe.pdf") {
            Err(LiteParseError::Failed(_)) => {}
            other => panic!("expected Failed for a missing PDF, got {other:?}"),
        }
    }

    #[cfg(feature = "liteparse-pdf")]
    #[test]
    fn live_engine_extracts_real_markdown_from_a_real_pdf() {
        // END-TO-END (engine layer): the embedded PDFium engine parses a real 18 KB sample
        // PDF (committed fixture) and renders Markdown — proving REAL extraction, not just
        // that it compiles or honest-fails. This is the strongest headless "real PDF →
        // markdown" proof; the in-app run-through additionally needs the owner's signed
        // build with the PDFium dylib bundled.
        let path = concat!(env!("CARGO_MANIFEST_DIR"), "/tests/fixtures/liteparse_sample.pdf");
        let md = pdf_to_markdown(path).expect("the real sample PDF should extract to markdown");
        assert!(md.contains("Sample PDF"), "title text missing: {md:?}");
        assert!(md.contains("# This is a simple PDF file"), "markdown heading missing: {md:?}");
        assert!(md.contains("Lorem ipsum dolor sit amet"), "body text missing");
        assert!(md.len() > 500, "expected substantial extracted text, got {} bytes", md.len());
    }

    #[cfg(feature = "liteparse-pdf")]
    #[test]
    fn live_ffi_envelope_carries_real_markdown_for_a_real_pdf() {
        // END-TO-END (FFI envelope the Swift importer consumes): on a real PDF the envelope
        // is `{"ok":true,"markdown":"…real text…"}` — so the sidebar/bulk/Settings surfaces
        // receive genuine markdown to turn into a vault note (their note-create wiring is
        // separately compile + test verified).
        let path = concat!(env!("CARGO_MANIFEST_DIR"), "/tests/fixtures/liteparse_sample.pdf");
        let out = liteparse_pdf_to_markdown(path.to_string());
        assert!(out.contains("\"ok\":true"), "envelope not ok: {out}");
        assert!(out.contains("Sample PDF"), "envelope missing real extracted text: {out}");
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
    fn status_json_reports_scope_and_provenance() {
        // Build-agnostic: the MAS scope boundary + Apache-2.0 ProvenanceGate + flag are
        // always reported (the Swift seam test mirrors these literals).
        let json = liteparse_status_json();
        assert!(json.contains("pdf+ocr,no-subprocess"));
        assert!(json.contains("Apache-2.0"));
        assert!(json.contains(LITEPARSE_FLAG));
    }

    #[cfg(not(feature = "liteparse-pdf"))]
    #[test]
    fn status_json_reports_engine_not_wired_when_inert() {
        // Default MAS build links no engine → honest engine_wired:false.
        assert!(liteparse_status_json().contains("\"engine_wired\":false"));
    }

    #[cfg(feature = "liteparse-pdf")]
    #[test]
    fn status_json_reports_engine_wired_when_live() {
        // Pro/dev build with the real PDFium engine compiled in → engine_wired:true.
        assert!(liteparse_status_json().contains("\"engine_wired\":true"));
    }

    #[cfg(not(feature = "liteparse-pdf"))]
    #[test]
    fn ffi_pdf_to_markdown_returns_honest_error_envelope_when_inert() {
        // INERT: a PDF, engine not wired → an honest error envelope (never fake markdown).
        let out = liteparse_pdf_to_markdown("paper.pdf".to_string());
        assert!(out.contains("\"ok\":false"));
        assert!(out.contains("not wired"));
        assert!(!out.contains("\"markdown\""));
    }

    #[cfg(feature = "liteparse-pdf")]
    #[test]
    fn ffi_pdf_to_markdown_envelope_is_honest_failure_on_missing_pdf() {
        // LIVE: a missing PDF path → the engine runs and fails honestly (ok:false), never
        // "not wired", never a fabricated markdown key.
        let out = liteparse_pdf_to_markdown("/nonexistent/epistemos-liteparse-probe.pdf".to_string());
        assert!(out.contains("\"ok\":false"));
        assert!(!out.contains("not wired"));
        assert!(!out.contains("\"markdown\""));
    }

    #[test]
    fn ffi_pdf_to_markdown_rejects_non_pdf_in_the_envelope() {
        let out = liteparse_pdf_to_markdown("book.docx".to_string());
        assert!(out.contains("\"ok\":false"));
        assert!(out.contains("unsupported format"));
    }
}
