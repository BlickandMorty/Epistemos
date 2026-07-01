//! Plan 3 PDF→Markdown seam. The exported UniFFI symbol intentionally keeps the
//! original `liteparse_pdf_to_markdown` name so the already-wired Swift importer can
//! flip engines without a UI rewrite. Default/MAS builds use the pure-Rust EdgeParse
//! primary parser plus unpdf fallback. The older run-llama/liteparse PDFium path stays
//! opt-in for Pro/dev builds only. No Python/Node sidecar.
//!
//! MAS SCOPE (NON-NEGOTIABLE): PDF only, parsed in-process by the vendored
//! EdgeParse/unpdf stack. EdgeParse's optional raster OCR and hybrid backends are
//! disabled, and Office/image formats stay out of scope because upstream converters
//! route through external binaries. A non-PDF input is rejected honestly here, never
//! silently shelled out.
//!
//! REAL APIs ONLY — no fake markdown, no silent fallback. ProvenanceGate verdicts:
//! docs/RESEARCH_LITEPARSE_2026_06_19.md and
//! docs/RESEARCH_EDGEPARSE_2026_06_28.md.

/// Flag that arms the liteparse PDF→Markdown path (mirrors the Swift gate).
pub const LITEPARSE_FLAG: &str = "EPISTEMOS_LITEPARSE_PDF_V0";

/// ProvenanceGate posture for the active Plan 3 parser stack.
pub const EDGEPARSE_VENDOR_LICENSE: &str = "Apache-2.0";
pub const EDGEPARSE_VENDOR_SOURCE: &str =
    "raphaelmansuy/edgeparse@98e2fa0132629078d07c19bfc8a8776fee85d8dd";
pub const UNPDF_VENDOR_LICENSE: &str = "MIT";
pub const UNPDF_VENDOR_SOURCE: &str = "iyulab/unpdf@d41b4dff1a29411bd62d405b322c4589a025f1fb";
/// ProvenanceGate posture for the older run-llama/liteparse core.
pub const LITEPARSE_VENDOR_LICENSE: &str = "Apache-2.0";
pub const LITEPARSE_VENDOR_SOURCE: &str = "run-llama/liteparse";

const MAX_PDF_BYTES: u64 = 512 * 1024 * 1024;
const MAX_PDF_MIB: u64 = MAX_PDF_BYTES / 1024 / 1024;
const MAX_ENGINE_ERROR_CHARS: usize = 1024;
const PDF_MAGIC: &[u8] = b"%PDF-";

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

/// Whether the legacy liteparse PDF env flag is explicitly set. The Plan 3 MAS parser is
/// wired by build feature; Swift treats the same env var as an emergency kill switch.
pub fn is_armed() -> bool {
    flag_is_armed(std::env::var(LITEPARSE_FLAG).ok().as_deref())
}

/// Whether `path` carries a PDF filename extension. The live parser does not trust this
/// by itself; it sniffs `%PDF-` bytes in `preflight_pdf_path`.
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

fn preflight_pdf_path(pdf_path: &str) -> Result<(), LiteParseError> {
    let metadata = match std::fs::symlink_metadata(pdf_path) {
        Ok(metadata) => metadata,
        Err(e) => {
            reject_if_not_pdf(pdf_path)?;
            return Err(LiteParseError::Failed(format!(
                "could not inspect PDF file: {e}"
            )));
        }
    };
    if metadata.file_type().is_symlink() || !metadata.is_file() {
        return Err(LiteParseError::Failed(
            "PDF path is not a regular file".to_string(),
        ));
    }
    if metadata.len() == 0 {
        return Err(LiteParseError::Failed("PDF file is empty".to_string()));
    }
    if metadata.len() > MAX_PDF_BYTES {
        return Err(LiteParseError::Failed(format!(
            "PDF is too large to parse safely ({} MiB limit)",
            MAX_PDF_MIB
        )));
    }
    let mut file = open_pdf_for_preflight(pdf_path)?;
    let opened_metadata = file
        .metadata()
        .map_err(|e| LiteParseError::Failed(format!("could not inspect PDF file: {e}")))?;
    if !opened_metadata.is_file() {
        return Err(LiteParseError::Failed(
            "PDF path is not a regular file".to_string(),
        ));
    }
    if opened_metadata.len() == 0 {
        return Err(LiteParseError::Failed("PDF file is empty".to_string()));
    }
    if opened_metadata.len() > MAX_PDF_BYTES {
        return Err(LiteParseError::Failed(format!(
            "PDF is too large to parse safely ({} MiB limit)",
            MAX_PDF_MIB
        )));
    }
    let mut header = [0_u8; 5];
    std::io::Read::read_exact(&mut file, &mut header)
        .map_err(|e| LiteParseError::Failed(format!("could not inspect PDF file header: {e}")))?;
    if header.as_slice() != PDF_MAGIC {
        return Err(LiteParseError::Failed(
            "file does not start with %PDF-, so it is not a PDF".to_string(),
        ));
    }
    Ok(())
}

#[cfg(unix)]
fn open_pdf_for_preflight(pdf_path: &str) -> Result<std::fs::File, LiteParseError> {
    use std::os::unix::fs::OpenOptionsExt;

    std::fs::OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC)
        .open(pdf_path)
        .map_err(|e| LiteParseError::Failed(format!("could not inspect PDF file: {e}")))
}

#[cfg(not(unix))]
fn open_pdf_for_preflight(pdf_path: &str) -> Result<std::fs::File, LiteParseError> {
    std::fs::File::open(pdf_path)
        .map_err(|e| LiteParseError::Failed(format!("could not inspect PDF file: {e}")))
}

const NO_SUBSTANTIVE_TEXT_MESSAGE: &str = "\
PDF text extraction produced no readable Markdown; scanned/image-only PDFs need OCR, \
which is out of scope on the MAS path";

fn markdown_is_substantive(markdown: &str) -> bool {
    let trimmed = markdown.trim();
    !trimmed.is_empty() && !trimmed.eq_ignore_ascii_case("*No content extracted.*")
}

fn no_substantive_text_error() -> LiteParseError {
    LiteParseError::Failed(NO_SUBSTANTIVE_TEXT_MESSAGE.to_string())
}

fn redacted_engine_error(
    prefix: &str,
    error: impl std::fmt::Display,
    pdf_path: &str,
) -> LiteParseError {
    let mut message = error.to_string();
    if !pdf_path.is_empty() {
        message = message.replace(pdf_path, "<pdf>");
    }
    if let Ok(canonical) = std::fs::canonicalize(pdf_path) {
        if let Some(canonical_path) = canonical.to_str() {
            message = message.replace(canonical_path, "<pdf>");
        }
    }
    let message = message.trim();
    let message = if message.is_empty() {
        "parser error".to_string()
    } else if message.len() > MAX_ENGINE_ERROR_CHARS {
        let bounded: String = message.chars().take(MAX_ENGINE_ERROR_CHARS - 3).collect();
        format!("{bounded}...")
    } else {
        message.to_string()
    };
    LiteParseError::Failed(format!("{prefix}: {message}"))
}

/// The honest seam: a local PDF → Markdown. A non-PDF input is rejected with
/// `UnsupportedFormat` (never shelled out).
///
/// INERT build: a PDF returns `EngineNotWired` — NEVER fake markdown.
#[cfg(not(any(feature = "edgeparse-pdf", feature = "liteparse-pdf")))]
pub fn pdf_to_markdown(pdf_path: &str) -> Result<String, LiteParseError> {
    match preflight_pdf_path(pdf_path) {
        Ok(()) => {}
        Err(LiteParseError::Failed(message))
            if message.starts_with("could not inspect PDF file:") =>
        {
            reject_if_not_pdf(pdf_path)?;
        }
        Err(error) => return Err(error),
    }
    Err(LiteParseError::EngineNotWired)
}

/// MAS/default build: the embedded pure-Rust EdgeParse parser is primary, with unpdf as a
/// multilingual/CJK/RTL fallback when EdgeParse fails or extracts no substantive text.
/// EdgeParse's upstream Markdown renderer can optionally consult `pdftotext` when
/// `PdfDocument.source_path` is set; the MAS path clears that field before rendering so
/// this FFI route never spawns external tools.
#[cfg(feature = "edgeparse-pdf")]
pub fn pdf_to_markdown(pdf_path: &str) -> Result<String, LiteParseError> {
    preflight_pdf_path(pdf_path)?;
    match edgeparse_to_markdown(pdf_path) {
        Ok(markdown) if markdown_is_substantive(&markdown) => Ok(markdown),
        Ok(markdown) => fallback_or_primary_empty(pdf_path, markdown),
        Err(primary_error) => fallback_or_primary_error(pdf_path, primary_error),
    }
}

#[cfg(feature = "edgeparse-pdf")]
fn edgeparse_to_markdown(pdf_path: &str) -> Result<String, LiteParseError> {
    use edgeparse_core::api::config::{
        HybridBackend, ImageOutput, OutputFormat, ProcessingConfig, ReadingOrder, TableMethod,
    };
    use std::path::Path;

    let config = ProcessingConfig {
        formats: vec![OutputFormat::Markdown],
        quiet: true,
        table_method: TableMethod::Cluster,
        reading_order: ReadingOrder::XyCut,
        image_output: ImageOutput::Off,
        raster_table_ocr: false,
        hybrid: HybridBackend::Off,
        ..ProcessingConfig::default()
    };
    let mut doc = edgeparse_core::convert(Path::new(pdf_path), &config)
        .map_err(|e| redacted_engine_error("EdgeParse", e, pdf_path))?;
    // MAS doctrine: keep the Markdown render path pure in-process. With `source_path`
    // populated, upstream EdgeParse tries optional `pdftotext` layout helpers.
    doc.source_path = None;
    edgeparse_core::output::markdown::to_markdown(&doc)
        .map_err(|e| redacted_engine_error("EdgeParse markdown", e, pdf_path))
}

#[cfg(all(feature = "edgeparse-pdf", feature = "parser-unpdf"))]
fn unpdf_to_markdown(pdf_path: &str) -> Result<String, LiteParseError> {
    unpdf::Unpdf::new()
        .lenient()
        .with_table_fallback(unpdf::TableFallback::Markdown)
        .with_cleanup(unpdf::CleanupPreset::Standard)
        .parse(pdf_path)
        .and_then(|parsed| parsed.to_markdown())
        .map_err(|e| redacted_engine_error("unpdf", e, pdf_path))
}

#[cfg(all(feature = "edgeparse-pdf", feature = "parser-unpdf"))]
fn fallback_or_primary_empty(
    pdf_path: &str,
    _primary_markdown: String,
) -> Result<String, LiteParseError> {
    match unpdf_to_markdown(pdf_path) {
        Ok(markdown) if markdown_is_substantive(&markdown) => Ok(markdown),
        Ok(_) => Err(no_substantive_text_error()),
        Err(_) => Err(no_substantive_text_error()),
    }
}

#[cfg(all(feature = "edgeparse-pdf", not(feature = "parser-unpdf")))]
fn fallback_or_primary_empty(
    _pdf_path: &str,
    _primary_markdown: String,
) -> Result<String, LiteParseError> {
    Err(no_substantive_text_error())
}

#[cfg(all(feature = "edgeparse-pdf", feature = "parser-unpdf"))]
fn fallback_or_primary_error(
    pdf_path: &str,
    primary_error: LiteParseError,
) -> Result<String, LiteParseError> {
    match unpdf_to_markdown(pdf_path) {
        Ok(markdown) if markdown_is_substantive(&markdown) => Ok(markdown),
        Ok(_) => Err(primary_error),
        Err(fallback_error) => Err(LiteParseError::Failed(format!(
            "{primary_error}; fallback {fallback_error}"
        ))),
    }
}

#[cfg(all(feature = "edgeparse-pdf", not(feature = "parser-unpdf")))]
fn fallback_or_primary_error(
    _pdf_path: &str,
    primary_error: LiteParseError,
) -> Result<String, LiteParseError> {
    Err(primary_error)
}

/// LIVE build (`--features liteparse-pdf`, Pro/dev): the embedded run-llama/liteparse core
/// extracts the PDF's spatial text via in-process PDFium (OCR OFF — no Tesseract, no
/// subprocess, no network) and renders Markdown. The async `parse` is driven on a
/// dedicated current-thread tokio runtime so the synchronous UniFFI export stays sync.
/// A non-PDF is still rejected up front; a real conversion failure → honest `Failed`.
#[cfg(all(feature = "liteparse-pdf", not(feature = "edgeparse-pdf")))]
pub fn pdf_to_markdown(pdf_path: &str) -> Result<String, LiteParseError> {
    preflight_pdf_path(pdf_path)?;
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
        .map_err(|e| redacted_engine_error("tokio runtime", e, pdf_path))?;
    let result = runtime
        .block_on(async { LiteParse::new(config).parse(pdf_path).await })
        .map_err(|e| redacted_engine_error("liteparse", e, pdf_path))?;
    if markdown_is_substantive(&result.text) {
        Ok(result.text)
    } else {
        Err(no_substantive_text_error())
    }
}

/// FFI: convert a local PDF to Markdown for the Swift import UI. Returns a JSON envelope
/// — `{"ok":true,"markdown":"…"}` on success, or `{"ok":false,"error":"…"}` on failure
/// (engine not wired / unsupported format / conversion failed) so the import surface
/// shows the honest outcome, NEVER a fake/empty note. A non-PDF is rejected
/// (`UnsupportedFormat`), never shelled out.
#[uniffi::export]
pub fn liteparse_pdf_to_markdown(pdf_path: String) -> String {
    match pdf_to_markdown(&pdf_path) {
        Ok(markdown) => format!(
            "{{\"ok\":true,\"markdown\":{}}}",
            serde_json::to_string(&markdown).unwrap_or_else(|_| "\"\"".to_string())
        ),
        Err(e) => format!(
            "{{\"ok\":false,\"error\":{}}}",
            serde_json::to_string(&e.to_string())
                .unwrap_or_else(|_| "\"conversion error\"".to_string())
        ),
    }
}

/// FFI: the PDF parser seam status as JSON, for the Swift import UI to read across the
/// UniFFI boundary.
#[uniffi::export]
pub fn liteparse_status_json() -> String {
    let engine_wired = cfg!(any(feature = "edgeparse-pdf", feature = "liteparse-pdf"));
    format!(
        "{{\"engine_wired\":{},\"armed\":{},\"flag\":\"{}\",\"license\":\"{}\",\"source\":\"{}\",\"fallback_license\":\"{}\",\"fallback_source\":\"{}\",\"scope\":\"pdf+markdown,no-subprocess\"}}",
        engine_wired,
        is_armed(),
        LITEPARSE_FLAG,
        EDGEPARSE_VENDOR_LICENSE,
        EDGEPARSE_VENDOR_SOURCE,
        UNPDF_VENDOR_LICENSE,
        UNPDF_VENDOR_SOURCE
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
    fn preflight_uses_pdf_magic_not_filename_extension() {
        let unique = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("clock should be after the Unix epoch")
            .as_nanos();
        let dir = std::env::temp_dir().join(format!("epistemos-liteparse-magic-{unique}"));
        std::fs::create_dir_all(&dir).expect("create temp liteparse dir");
        let extensionless_pdf = dir.join("CFNetworkDownload_temp");
        let html_named_pdf = dir.join("paper.pdf");
        std::fs::write(&extensionless_pdf, b"%PDF-1.7\n").expect("write extensionless pdf");
        std::fs::write(&html_named_pdf, b"<html>not a pdf</html>").expect("write html named pdf");

        assert_eq!(
            preflight_pdf_path(extensionless_pdf.to_str().expect("utf-8 temp path")),
            Ok(())
        );
        match preflight_pdf_path(html_named_pdf.to_str().expect("utf-8 temp path")) {
            Err(LiteParseError::Failed(message)) => {
                assert!(
                    message.contains("does not start with %PDF-"),
                    "unexpected error: {message}"
                );
            }
            other => panic!("expected non-PDF body preflight failure, got {other:?}"),
        }

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn parser_error_redaction_removes_local_pdf_path() {
        let pdf_path = "/Users/alice/Documents/private/source.pdf";
        let error = redacted_engine_error(
            "EdgeParse",
            format!("Failed to load PDF {pdf_path}: parser detail"),
            pdf_path,
        );
        match error {
            LiteParseError::Failed(message) => {
                assert!(
                    message.contains("<pdf>"),
                    "redacted marker missing: {message}"
                );
                assert!(
                    !message.contains(pdf_path),
                    "local PDF path leaked through parser error: {message}"
                );
            }
            other => panic!("expected failed parser error, got {other:?}"),
        }
    }

    #[cfg(unix)]
    #[test]
    fn preflight_rejects_symlink_pdf_before_parser() {
        let unique = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("clock should be after the Unix epoch")
            .as_nanos();
        let dir = std::env::temp_dir().join(format!("epistemos-liteparse-symlink-{unique}"));
        std::fs::create_dir_all(&dir).expect("create temp liteparse dir");
        let target = dir.join("target.pdf");
        let symlink = dir.join("linked.pdf");
        std::fs::write(&target, b"%PDF-1.7\n").expect("write target pdf");
        std::os::unix::fs::symlink(&target, &symlink).expect("create symlink pdf");

        match preflight_pdf_path(symlink.to_str().expect("utf-8 temp path")) {
            Err(LiteParseError::Failed(message)) => {
                assert!(
                    message.contains("not a regular file"),
                    "unexpected error: {message}"
                );
            }
            other => panic!("expected symlink preflight failure, got {other:?}"),
        }

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[cfg(not(any(feature = "edgeparse-pdf", feature = "liteparse-pdf")))]
    #[test]
    fn inert_seam_refuses_honestly_never_fakes_markdown() {
        // INERT build: a PDF, but no engine wired → honest EngineNotWired (NEVER fabricated markdown).
        assert_eq!(
            pdf_to_markdown("paper.pdf"),
            Err(LiteParseError::EngineNotWired)
        );
    }

    #[cfg(any(feature = "edgeparse-pdf", feature = "liteparse-pdf"))]
    #[test]
    fn live_engine_fails_honestly_on_missing_pdf_never_fakes_markdown() {
        // LIVE build: a PDF *path* that does not exist → the real engine runs and returns an
        // honest Failed (NEVER EngineNotWired, NEVER fabricated markdown, NEVER a panic). Any
        // parser failure path maps to Failed, so this is robust.
        match pdf_to_markdown("/nonexistent/epistemos-liteparse-probe.pdf") {
            Err(LiteParseError::Failed(_)) => {}
            other => panic!("expected Failed for a missing PDF, got {other:?}"),
        }
    }

    #[cfg(any(feature = "edgeparse-pdf", feature = "liteparse-pdf"))]
    #[test]
    fn live_engine_rejects_oversized_pdf_before_parser() {
        let unique = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("clock should be after the Unix epoch")
            .as_nanos();
        let path = std::env::temp_dir().join(format!("epistemos-liteparse-oversized-{unique}.pdf"));
        let file = std::fs::File::create(&path).expect("create sparse oversized PDF probe");
        file.set_len(MAX_PDF_BYTES + 1)
            .expect("set sparse oversized PDF length");
        drop(file);

        let outcome = pdf_to_markdown(path.to_str().expect("temp path should be UTF-8"));
        let _ = std::fs::remove_file(&path);
        match outcome {
            Err(LiteParseError::Failed(message)) => {
                assert!(message.contains("too large"), "unexpected error: {message}");
                assert!(message.contains("512 MiB"), "unexpected limit: {message}");
            }
            other => panic!("expected oversized PDF preflight failure, got {other:?}"),
        }
    }

    #[cfg(feature = "edgeparse-pdf")]
    #[test]
    fn empty_primary_markdown_after_fallback_is_honest_failure() {
        assert_eq!(
            fallback_or_primary_empty("/nonexistent/epistemos-empty-probe.pdf", String::new()),
            Err(no_substantive_text_error())
        );
    }

    #[cfg(any(feature = "edgeparse-pdf", feature = "liteparse-pdf"))]
    #[test]
    fn live_engine_extracts_real_markdown_from_a_real_pdf() {
        // END-TO-END (engine layer): the embedded parser stack parses a real 18 KB sample
        // PDF (committed fixture) and renders Markdown — proving REAL extraction, not just
        // that it compiles or honest-fails.
        let path = concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/tests/fixtures/liteparse_sample.pdf"
        );
        let md = pdf_to_markdown(path).expect("the real sample PDF should extract to markdown");
        assert!(md.contains("# Sample PDF"), "title heading missing: {md:?}");
        assert!(
            md.contains("This is a simple PDF"),
            "body intro missing: {md:?}"
        );
        assert!(
            md.contains("Lorem ipsum dolor sit amet"),
            "body text missing"
        );
        assert!(
            md.len() > 500,
            "expected substantial extracted text, got {} bytes",
            md.len()
        );
    }

    #[cfg(any(feature = "edgeparse-pdf", feature = "liteparse-pdf"))]
    #[test]
    fn live_ffi_envelope_carries_real_markdown_for_a_real_pdf() {
        // END-TO-END (FFI envelope the Swift importer consumes): on a real PDF the envelope
        // is `{"ok":true,"markdown":"…real text…"}` — so the sidebar/bulk/Settings surfaces
        // receive genuine markdown to turn into a vault note (their note-create wiring is
        // separately compile + test verified).
        let path = concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/tests/fixtures/liteparse_sample.pdf"
        );
        let out = liteparse_pdf_to_markdown(path.to_string());
        assert!(out.contains("\"ok\":true"), "envelope not ok: {out}");
        assert!(
            out.contains("Sample PDF"),
            "envelope missing real extracted text: {out}"
        );
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
        assert!(json.contains("pdf+markdown,no-subprocess"));
        assert!(json.contains("Apache-2.0"));
        assert!(json.contains("MIT"));
        assert!(json.contains(LITEPARSE_FLAG));
    }

    #[cfg(not(any(feature = "edgeparse-pdf", feature = "liteparse-pdf")))]
    #[test]
    fn status_json_reports_engine_not_wired_when_inert() {
        assert!(liteparse_status_json().contains("\"engine_wired\":false"));
    }

    #[cfg(any(feature = "edgeparse-pdf", feature = "liteparse-pdf"))]
    #[test]
    fn status_json_reports_engine_wired_when_live() {
        assert!(liteparse_status_json().contains("\"engine_wired\":true"));
    }

    #[cfg(not(any(feature = "edgeparse-pdf", feature = "liteparse-pdf")))]
    #[test]
    fn ffi_pdf_to_markdown_returns_honest_error_envelope_when_inert() {
        // INERT: a PDF, engine not wired → an honest error envelope (never fake markdown).
        let out = liteparse_pdf_to_markdown("paper.pdf".to_string());
        assert!(out.contains("\"ok\":false"));
        assert!(out.contains("not wired"));
        assert!(!out.contains("\"markdown\""));
    }

    #[cfg(any(feature = "edgeparse-pdf", feature = "liteparse-pdf"))]
    #[test]
    fn ffi_pdf_to_markdown_envelope_is_honest_failure_on_missing_pdf() {
        // LIVE: a missing PDF path → the engine runs and fails honestly (ok:false), never
        // "not wired", never a fabricated markdown key.
        let out =
            liteparse_pdf_to_markdown("/nonexistent/epistemos-liteparse-probe.pdf".to_string());
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
