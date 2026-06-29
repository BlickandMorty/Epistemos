//! SS-Y — raw FFI seam for the grammar masking matcher (slice 4).
//!
//! Exposes the llguidance tool-dispatch [`Matcher`] (built in the parent module)
//! over the FFI boundary so the Swift MLX `LogitProcessor` can drive constrained
//! decoding: `grammar_matcher_compute_mask` returns the allowed token ids at the
//! current step, `grammar_matcher_consume_token` feeds back the sampled token.
//!
//! Follows the battle-tested raw `extern "C"` + `Arc::into_raw` handle pattern
//! (see `rope_handle.rs`), NOT UniFFI: the handle is refcounted
//! (`*_retain`/`*_release`); `compute_mask` heap-allocates the allowed-id buffer and
//! returns it via an OUT-PARAMETER + length (no C-struct-return, which is ABI-unsafe
//! across the Swift `@_silgen_name` boundary — every existing FFI client returns
//! only pointers/primitives); the caller frees it via `grammar_matcher_free_mask`.
//! Every entry point is panic-guarded + null-safe; the `Mutex` makes the `&self`
//! methods thread-safe.
//!
//! This seam does NOT touch the generation path — the Swift wiring lands it behind
//! a default-OFF flag in the next slice, and `isFullyConstraining` stays false until
//! a live witness.

use std::ffi::{c_char, CStr};
use std::sync::{Arc, Mutex};

use llguidance::{token_bytes_from_tokenizer_json, Matcher};
use serde_json::Value;

use super::{allowed_token_ids, tool_dispatch_matcher_with_vocab, GrammarError};

/// Opaque refcounted handle to a tool-dispatch grammar [`Matcher`]. Crosses FFI as
/// `*const GrammarMatcherHandle`; Rust never exposes the inner `Matcher` to Swift.
pub struct GrammarMatcherHandle {
    inner: Mutex<Matcher>,
}

fn handle_into_raw(matcher: Matcher) -> *const GrammarMatcherHandle {
    Arc::into_raw(Arc::new(GrammarMatcherHandle {
        inner: Mutex::new(matcher),
    }))
}

fn build_matcher(
    tokenizer_json: &str,
    tools_json: &str,
    eos: u32,
) -> Result<Matcher, GrammarError> {
    let tj: Value =
        serde_json::from_str(tokenizer_json).map_err(|e| GrammarError::Parser(e.to_string()))?;
    let vocab =
        token_bytes_from_tokenizer_json(&tj).map_err(|e| GrammarError::Parser(e.to_string()))?;
    let tools_val: Value =
        serde_json::from_str(tools_json).map_err(|e| GrammarError::Parser(e.to_string()))?;
    let arr = tools_val.as_array().ok_or(GrammarError::EmptyDispatch)?;
    let null = Value::Null;
    let tools: Vec<(&str, &Value)> = arr
        .iter()
        .filter_map(|t| {
            t.get("name")
                .and_then(|n| n.as_str())
                .map(|name| (name, t.get("schema").unwrap_or(&null)))
        })
        .collect();
    tool_dispatch_matcher_with_vocab(&tools, &vocab, eos)
}

/// Build a grammar matcher from a model's `tokenizer.json` content + a tools JSON
/// array (`[{"name": String, "schema": Object}, ...]`). Returns a refcount-1 handle,
/// or null on any parse/build failure. The caller must `grammar_matcher_release` it.
///
/// # Safety
/// `tokenizer_json` + `tools_json` must be valid null-terminated UTF-8 C strings or
/// null (null → null return).
#[unsafe(no_mangle)]
pub unsafe extern "C" fn grammar_matcher_new(
    tokenizer_json: *const c_char,
    tools_json: *const c_char,
    eos_token_id: u32,
) -> *const GrammarMatcherHandle {
    let result = std::panic::catch_unwind(|| {
        if tokenizer_json.is_null() || tools_json.is_null() {
            return std::ptr::null();
        }
        // SAFETY: caller contract — null-terminated UTF-8.
        let tj = match unsafe { CStr::from_ptr(tokenizer_json) }.to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null(),
        };
        let tl = match unsafe { CStr::from_ptr(tools_json) }.to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null(),
        };
        match build_matcher(tj, tl, eos_token_id) {
            Ok(matcher) => handle_into_raw(matcher),
            Err(_) => std::ptr::null(),
        }
    });
    result.unwrap_or(std::ptr::null())
}

/// Increment the handle refcount.
///
/// # Safety
/// `handle` must be a live `GrammarMatcherHandle` pointer or null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn grammar_matcher_retain(handle: *const GrammarMatcherHandle) {
    if !handle.is_null() {
        // SAFETY: caller contract — balanced retain/release.
        unsafe {
            Arc::increment_strong_count(handle);
        }
    }
}

/// Decrement the handle refcount; drops the matcher at zero. Idempotent on null.
///
/// # Safety
/// `handle` must be a live `GrammarMatcherHandle` pointer or null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn grammar_matcher_release(handle: *const GrammarMatcherHandle) {
    if !handle.is_null() {
        // SAFETY: caller contract — balanced retain/release.
        unsafe {
            Arc::decrement_strong_count(handle);
        }
    }
}

/// Compute the allowed token ids at the current step. Writes a heap-allocated buffer
/// pointer to `*out_ids` and returns its length; the caller frees the buffer via
/// `grammar_matcher_free_mask(ids, len)`. Writes null + returns 0 on null
/// handle/out-param or error. (Out-param avoids C-struct-return ABI ambiguity across
/// the Swift `@_silgen_name` boundary.)
///
/// # Safety
/// `handle` must be a live pointer or null; `out_ids` must be a valid writable
/// `*mut *mut u32` or null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn grammar_matcher_compute_mask(
    handle: *const GrammarMatcherHandle,
    out_ids: *mut *mut u32,
) -> usize {
    if out_ids.is_null() {
        return 0;
    }
    // Default the out-param to null, so an early/error return is well-defined.
    // SAFETY: caller contract — out_ids is writable.
    unsafe {
        *out_ids = std::ptr::null_mut();
    }
    if handle.is_null() {
        return 0;
    }
    let result = std::panic::catch_unwind(|| {
        // SAFETY: caller contract.
        let h = unsafe { &*handle };
        let mut m = match h.inner.lock() {
            Ok(g) => g,
            Err(_) => return (std::ptr::null_mut(), 0usize),
        };
        match allowed_token_ids(&mut m) {
            Ok(ids) => {
                let mut boxed = ids.into_boxed_slice();
                let ptr = boxed.as_mut_ptr();
                let len = boxed.len();
                // Ownership transfers to the caller (freed via grammar_matcher_free_mask).
                std::mem::forget(boxed);
                (ptr, len)
            }
            Err(_) => (std::ptr::null_mut(), 0usize),
        }
    });
    let (ptr, len) = result.unwrap_or((std::ptr::null_mut(), 0));
    // SAFETY: out_ids checked non-null above.
    unsafe {
        *out_ids = ptr;
    }
    len
}

/// Free a buffer returned by `grammar_matcher_compute_mask`. Idempotent on null/empty.
///
/// # Safety
/// `ids` must have come from `grammar_matcher_compute_mask` with the same `len`, and
/// not been freed yet.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn grammar_matcher_free_mask(ids: *mut u32, len: usize) {
    if !ids.is_null() && len > 0 {
        // SAFETY: reconstruct the Box<[u32]> leaked in compute_mask.
        unsafe {
            drop(Box::from_raw(std::slice::from_raw_parts_mut(ids, len)));
        }
    }
}

/// Feed the sampled token back to the matcher. Returns true if the token was
/// accepted (grammar-valid), false on null handle / error / invalid token.
///
/// # Safety
/// `handle` must be a live `GrammarMatcherHandle` pointer or null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn grammar_matcher_consume_token(
    handle: *const GrammarMatcherHandle,
    token: u32,
) -> bool {
    if handle.is_null() {
        return false;
    }
    let result = std::panic::catch_unwind(|| {
        // SAFETY: caller contract.
        let h = unsafe { &*handle };
        let mut m = match h.inner.lock() {
            Ok(g) => g,
            Err(_) => return false,
        };
        m.consume_token(token).is_ok()
    });
    result.unwrap_or(false)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use std::ffi::CString;

    /// Read the allowed-id out-param into a Vec (and free the Rust buffer).
    unsafe fn compute_mask_vec(handle: *const GrammarMatcherHandle) -> Vec<u32> {
        let mut ids: *mut u32 = std::ptr::null_mut();
        let len = unsafe { grammar_matcher_compute_mask(handle, &mut ids) };
        if ids.is_null() || len == 0 {
            return Vec::new();
        }
        let v = unsafe { std::slice::from_raw_parts(ids, len) }.to_vec();
        unsafe { grammar_matcher_free_mask(ids, len) };
        v
    }

    #[test]
    fn ffi_compute_mask_and_consume_token_drive_streaming_masking() {
        // Witness the stateful FFI surface the MLX LogitProcessor drives. Vocab = all
        // single bytes + the valid + an invalid tool name as multi-byte tokens.
        let mut vocab: Vec<Vec<u8>> = (0u16..=255).map(|b| vec![b as u8]).collect();
        vocab.push(b"get_weather".to_vec()); // token id 256
        vocab.push(b"no_such_tool".to_vec()); // token id 257
        vocab.push(b"<eos>".to_vec()); // token id 258
        let eos = (vocab.len() - 1) as u32;
        let (get_w, no_such) = (256u32, 257u32);
        let weather_input = json!({
            "type": "object",
            "required": ["city"],
            "additionalProperties": false,
            "properties": { "city": { "type": "string" } }
        });
        let tools: Vec<(&str, &Value)> = vec![("get_weather", &weather_input)];
        let matcher = tool_dispatch_matcher_with_vocab(&tools, &vocab, eos).unwrap();
        let handle = handle_into_raw(matcher);

        // `{"name":"` is all single bytes; for the single-byte vocab, token id == byte.
        for b in br#"{"name":""#.iter() {
            assert!(
                unsafe { grammar_matcher_consume_token(handle, *b as u32) },
                "valid prefix byte must consume"
            );
        }

        // At the const tool-name position: get_weather allowed, no_such_tool masked.
        let allowed = unsafe { compute_mask_vec(handle) };
        assert!(!allowed.is_empty(), "mask must be non-empty");
        assert!(
            allowed.contains(&get_w),
            "get_weather token must be allowed"
        );
        assert!(
            !allowed.contains(&no_such),
            "no_such_tool token must be masked"
        );
        unsafe { grammar_matcher_release(handle) };
    }

    #[test]
    fn ffi_new_from_tokenizer_json_builds_a_handle_and_is_null_safe() {
        // A minimal valid ByteLevel tokenizer.json proves the constructor parses the
        // model tokenizer + builds a handle (the masking itself is witnessed above).
        let tokenizer_json =
            r#"{"added_tokens":[],"decoder":{"type":"ByteLevel"},"model":{"vocab":{"a":0,"b":1}}}"#;
        let tools_json = r#"[{"name":"t","schema":{"type":"object","properties":{}}}]"#;
        let c_tok = CString::new(tokenizer_json).unwrap();
        let c_tools = CString::new(tools_json).unwrap();
        let handle = unsafe { grammar_matcher_new(c_tok.as_ptr(), c_tools.as_ptr(), 1) };
        assert!(
            !handle.is_null(),
            "constructor must build a handle from a valid tokenizer.json"
        );
        unsafe { grammar_matcher_release(handle) };

        // Null-safe: every entry point tolerates null without crashing.
        unsafe {
            assert!(grammar_matcher_new(std::ptr::null(), c_tools.as_ptr(), 1).is_null());
            grammar_matcher_retain(std::ptr::null());
            grammar_matcher_release(std::ptr::null());
            assert!(!grammar_matcher_consume_token(std::ptr::null(), 0));
            let mut p: *mut u32 = std::ptr::null_mut();
            assert_eq!(grammar_matcher_compute_mask(std::ptr::null(), &mut p), 0);
            assert!(p.is_null());
            grammar_matcher_free_mask(p, 0);
            // A null out-param is tolerated too.
            assert_eq!(
                grammar_matcher_compute_mask(std::ptr::null(), std::ptr::null_mut()),
                0
            );
        }
    }
}
