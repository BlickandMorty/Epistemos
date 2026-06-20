//! SS-Y — raw FFI seam for the grammar masking matcher (slice 4).
//!
//! Exposes the llguidance tool-dispatch [`Matcher`] (built in the parent module)
//! over the FFI boundary so the Swift MLX `LogitProcessor` can drive constrained
//! decoding: `grammar_matcher_compute_mask` returns the allowed token ids at the
//! current step, `grammar_matcher_consume_token` feeds back the sampled token.
//!
//! Follows the battle-tested raw `extern "C"` + `Arc::into_raw` handle pattern
//! (see `rope_handle.rs`), NOT UniFFI: the handle is refcounted
//! (`*_retain`/`*_release`); `compute_mask` heap-allocates the allowed-id array and
//! the caller frees it via `grammar_matcher_free_mask`; every entry point is
//! panic-guarded + null-safe. The `Mutex` makes the `&self` methods thread-safe.
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

/// The allowed token ids at the current step. Heap-allocated by
/// `grammar_matcher_compute_mask`; the caller MUST free it with
/// `grammar_matcher_free_mask` exactly once.
#[repr(C)]
pub struct GrammarTokenMask {
    ptr: *mut u32,
    len: usize,
}

impl GrammarTokenMask {
    fn empty() -> Self {
        Self {
            ptr: std::ptr::null_mut(),
            len: 0,
        }
    }
}

fn handle_into_raw(matcher: Matcher) -> *const GrammarMatcherHandle {
    Arc::into_raw(Arc::new(GrammarMatcherHandle {
        inner: Mutex::new(matcher),
    }))
}

fn build_matcher(tokenizer_json: &str, tools_json: &str, eos: u32) -> Result<Matcher, GrammarError> {
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

/// Compute the allowed token ids at the current step. Result is heap-allocated; free
/// it with `grammar_matcher_free_mask`. Empty (null ptr, 0 len) on null handle or
/// error.
///
/// # Safety
/// `handle` must be a live `GrammarMatcherHandle` pointer or null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn grammar_matcher_compute_mask(
    handle: *const GrammarMatcherHandle,
) -> GrammarTokenMask {
    if handle.is_null() {
        return GrammarTokenMask::empty();
    }
    let result = std::panic::catch_unwind(|| {
        // SAFETY: caller contract.
        let h = unsafe { &*handle };
        let mut m = match h.inner.lock() {
            Ok(g) => g,
            Err(_) => return GrammarTokenMask::empty(),
        };
        match allowed_token_ids(&mut m) {
            Ok(ids) => {
                let mut boxed = ids.into_boxed_slice();
                let mask = GrammarTokenMask {
                    ptr: boxed.as_mut_ptr(),
                    len: boxed.len(),
                };
                // Ownership of the allocation transfers to the caller (freed via
                // grammar_matcher_free_mask).
                std::mem::forget(boxed);
                mask
            }
            Err(_) => GrammarTokenMask::empty(),
        }
    });
    result.unwrap_or_else(|_| GrammarTokenMask::empty())
}

/// Free a token mask returned by `grammar_matcher_compute_mask`. Idempotent on a
/// null/empty mask.
///
/// # Safety
/// `mask` must have come from `grammar_matcher_compute_mask` and not been freed yet.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn grammar_matcher_free_mask(mask: GrammarTokenMask) {
    if !mask.ptr.is_null() && mask.len > 0 {
        // SAFETY: reconstruct the Box<[u32]> leaked in compute_mask.
        unsafe {
            drop(Box::from_raw(std::slice::from_raw_parts_mut(
                mask.ptr, mask.len,
            )));
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
        let mask = unsafe { grammar_matcher_compute_mask(handle) };
        assert!(!mask.ptr.is_null() && mask.len > 0, "mask must be non-empty");
        let allowed = unsafe { std::slice::from_raw_parts(mask.ptr, mask.len) };
        assert!(allowed.contains(&get_w), "get_weather token must be allowed");
        assert!(!allowed.contains(&no_such), "no_such_tool token must be masked");
        unsafe {
            grammar_matcher_free_mask(mask);
            grammar_matcher_release(handle);
        }
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
            let m = grammar_matcher_compute_mask(std::ptr::null());
            assert!(m.ptr.is_null() && m.len == 0);
            grammar_matcher_free_mask(m);
        }
    }
}
