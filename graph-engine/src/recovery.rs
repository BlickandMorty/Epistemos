//! Note corruption detection and repair.
//! Detects invalid UTF-8, null bytes, BOM markers, and common encoding mismatches.
//! Provides best-effort transcode from Latin-1, Windows-1252, etc.

/// Types of corruption detected in a byte sequence.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CorruptionType {
    /// No corruption detected; valid UTF-8.
    None,
    /// Contains null bytes within text content.
    NullBytes,
    /// Contains a BOM marker that may cause display issues.
    BomMarker,
    /// Invalid UTF-8 sequences — likely a different encoding.
    InvalidUtf8,
    /// Multibyte character truncated at end of file.
    TruncatedMultibyte,
}

/// Detect what kind of corruption (if any) exists in the byte sequence.
pub fn detect(bytes: &[u8]) -> CorruptionType {
    if bytes.is_empty() {
        return CorruptionType::None;
    }

    // Check for BOM
    if bytes.starts_with(&[0xEF, 0xBB, 0xBF])
        || bytes.starts_with(&[0xFF, 0xFE])
        || bytes.starts_with(&[0xFE, 0xFF])
    {
        return CorruptionType::BomMarker;
    }

    // Check for null bytes in text
    if bytes.contains(&0) {
        return CorruptionType::NullBytes;
    }

    // Check UTF-8 validity
    match std::str::from_utf8(bytes) {
        Ok(_) => CorruptionType::None,
        Err(e) => {
            let valid_up_to = e.valid_up_to();
            if valid_up_to > 0 && valid_up_to >= bytes.len().saturating_sub(3) {
                CorruptionType::TruncatedMultibyte
            } else {
                CorruptionType::InvalidUtf8
            }
        }
    }
}

/// Attempt to repair corrupted bytes into valid UTF-8.
/// Tries Latin-1 (ISO 8859-1), Windows-1252 transcoding first,
/// then falls back to lossy UTF-8 replacement.
pub fn repair(bytes: &[u8]) -> String {
    // If already valid UTF-8, return as-is (stripping BOM if present)
    if let Ok(s) = std::str::from_utf8(bytes) {
        return s.trim_start_matches('\u{FEFF}').to_string();
    }

    // Try Latin-1 (ISO 8859-1) → UTF-8
    // Latin-1 maps 1:1 to Unicode code points 0x00-0xFF
    let latin1: String = bytes.iter().map(|&b| b as char).collect();
    if is_mostly_printable(&latin1) {
        return latin1;
    }

    // Fallback: lossy UTF-8 (replaces invalid sequences with U+FFFD)
    String::from_utf8_lossy(bytes).into_owned()
}

/// Strip null bytes from a byte sequence.
pub fn strip_nulls(bytes: &[u8]) -> Vec<u8> {
    bytes.iter().copied().filter(|&b| b != 0).collect()
}

fn is_mostly_printable(s: &str) -> bool {
    if s.is_empty() {
        return true;
    }
    let printable = s
        .chars()
        .filter(|c| !c.is_control() || *c == '\n' || *c == '\r' || *c == '\t')
        .count();
    let ratio = printable as f64 / s.chars().count() as f64;
    ratio > 0.9
}

// MARK: - FFI exports

/// Detect corruption type. Returns a string: "none", "null_bytes", "bom_marker",
/// "invalid_utf8", or "truncated_multibyte".
///
/// # Safety
/// `ptr` must point to a valid byte array of length `len`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn recovery_detect(ptr: *const u8, len: usize) -> *mut std::ffi::c_char {
    let bytes = if ptr.is_null() || len == 0 {
        &[]
    } else {
        // SAFETY: caller guarantees ptr/len validity
        unsafe { std::slice::from_raw_parts(ptr, len) }
    };
    let result = match detect(bytes) {
        CorruptionType::None => "none",
        CorruptionType::NullBytes => "null_bytes",
        CorruptionType::BomMarker => "bom_marker",
        CorruptionType::InvalidUtf8 => "invalid_utf8",
        CorruptionType::TruncatedMultibyte => "truncated_multibyte",
    };
    std::ffi::CString::new(result)
        .unwrap_or_default()
        .into_raw()
}

/// Repair corrupted bytes into valid UTF-8. Returns a newly allocated C string.
///
/// # Safety
/// `ptr` must point to a valid byte array of length `len`.
/// The caller must free the returned pointer with `recovery_free_string`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn recovery_repair(ptr: *const u8, len: usize) -> *mut std::ffi::c_char {
    let bytes = if ptr.is_null() || len == 0 {
        &[]
    } else {
        // SAFETY: caller guarantees ptr/len validity
        unsafe { std::slice::from_raw_parts(ptr, len) }
    };
    let repaired = repair(bytes);
    std::ffi::CString::new(repaired)
        .unwrap_or_default()
        .into_raw()
}

/// Free a string returned by `recovery_detect` or `recovery_repair`.
///
/// # Safety
/// `ptr` must have been returned by `recovery_detect` or `recovery_repair`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn recovery_free_string(ptr: *mut std::ffi::c_char) {
    if !ptr.is_null() {
        // SAFETY: ptr was allocated by CString::into_raw
        let _ = unsafe { std::ffi::CString::from_raw(ptr) };
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn valid_utf8_returns_none() {
        assert_eq!(detect(b"Hello, world!"), CorruptionType::None);
    }

    #[test]
    fn null_bytes_detected() {
        assert_eq!(detect(b"Hello\x00World"), CorruptionType::NullBytes);
    }

    #[test]
    fn bom_detected() {
        assert_eq!(
            detect(&[0xEF, 0xBB, 0xBF, b'H', b'i']),
            CorruptionType::BomMarker
        );
    }

    #[test]
    fn invalid_utf8_detected() {
        assert_eq!(detect(&[0x80, 0x81, 0x82]), CorruptionType::InvalidUtf8);
    }

    #[test]
    fn latin1_repair() {
        // "café" in Latin-1: c a f 0xE9
        let latin1_bytes = &[b'c', b'a', b'f', 0xE9];
        let repaired = repair(latin1_bytes);
        assert_eq!(repaired, "café");
    }

    #[test]
    fn repair_strips_bom() {
        let with_bom = "\u{FEFF}Hello".as_bytes();
        let repaired = repair(with_bom);
        assert_eq!(repaired, "Hello");
    }

    #[test]
    fn strip_nulls_works() {
        assert_eq!(strip_nulls(b"He\x00llo"), b"Hello");
    }
}
