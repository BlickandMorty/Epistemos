//! `serde_json::RawValue` → `bumpalo::String` copy helper.
//!
//! Per Wave 6 plan dpp §6.3 + canonical research finding: the
//! `serde_json` interaction is the real arena gotcha — `from_str`
//! always allocates owned `String`s on the heap, regardless of any
//! arena. The canonical 2026 workaround is read once into `&RawValue`,
//! then copy the slice into the arena via
//! `bumpalo::collections::String::from_str_in`.
//!
//! This module ships that copy helper as a single function so MCP
//! dispatch + tool-result formatting paths can use it uniformly.

use bumpalo::collections::String as BumpString;
use bumpalo::Bump;
use serde_json::value::RawValue;

/// Copy a `&RawValue`'s underlying bytes into an arena-allocated
/// `BumpString`. The returned string borrows from the arena, so it is
/// valid for the lifetime of the closure passed to `with_frame`.
///
/// Use this in the MCP dispatch path when you need to KEEP a JSON
/// sub-tree alive until the arena resets, but want to avoid the
/// `serde_json::Value` heap-allocation tax.
pub fn raw_value_in<'a>(raw: &RawValue, arena: &'a Bump) -> BumpString<'a> {
    let mut s = BumpString::with_capacity_in(raw.get().len(), arena);
    s.push_str(raw.get());
    s
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::arenas::frame::with_frame;

    #[test]
    fn raw_value_in_copies_bytes_into_arena() {
        // Parse a small JSON object once via RawValue (no Value tree).
        let raw_text = r#"{"foo":42,"bar":[1,2,3]}"#;
        let parsed: Box<RawValue> = serde_json::from_str(raw_text).unwrap();

        with_frame(|arena| {
            let copied = raw_value_in(&parsed, arena);
            assert_eq!(copied.as_str(), raw_text);
        });
    }

    #[test]
    fn raw_value_in_handles_unicode() {
        let raw_text = r#""café \u2603 hello""#;
        let parsed: Box<RawValue> = serde_json::from_str(raw_text).unwrap();
        with_frame(|arena| {
            let copied = raw_value_in(&parsed, arena);
            assert_eq!(copied.as_str(), raw_text);
        });
    }

    #[test]
    fn nested_raw_values_keep_their_serialised_form() {
        // Nested RawValues read just the top-level JSON without parsing
        // the inner sub-trees — that's the cost-saving trick.
        #[derive(serde::Deserialize)]
        struct Outer<'a> {
            #[serde(borrow)]
            inner: &'a RawValue,
        }
        let text = r#"{"inner":{"deep":{"nested":[1,2,3]}}}"#;
        let outer: Outer = serde_json::from_str(text).unwrap();
        with_frame(|arena| {
            let copied = raw_value_in(outer.inner, arena);
            // The inner RawValue's serialised form is preserved verbatim.
            assert_eq!(copied.as_str(), r#"{"deep":{"nested":[1,2,3]}}"#);
        });
    }
}
