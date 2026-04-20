use ropey::Rope;
use tree_sitter::{Language, Query, QueryCursor, StreamingIterator, Tree};

use crate::token_registry::TokenRegistry;
use crate::SyntaxTokenSpan;

const GENERIC_HIGHLIGHTS_QUERY: &str = r#"
(line_comment) @comment
(block_comment) @comment
(string_literal) @string
(string_content) @string
(raw_string_literal) @string
(char_literal) @string
(integer_literal) @number
(float_literal) @number
(boolean_literal) @constant
(escape_sequence) @escape
(type_identifier) @type
(primitive_type) @type
(identifier) @variable
(field_identifier) @property
(function_item name: (identifier) @function.def)
(call_expression function: (identifier) @function.call)
(macro_invocation macro: (identifier) @macro)
(attribute_item) @attribute
"#;

fn query_for_language(language: &Language) -> Option<Query> {
    Query::new(language, GENERIC_HIGHLIGHTS_QUERY).ok()
}

/// Produce `SyntaxTokenSpan` entries for the visible byte range of a parsed tree.
///
/// `byte_start`/`byte_end` restrict tree-sitter's query cursor so only nodes
/// overlapping the viewport are visited. Tokens are written into `out` up to
/// `max_tokens`. Returns the number of tokens written.
pub fn tokens_for_byte_range(
    tree: &Tree,
    language: &Language,
    rope: &Rope,
    registry: &mut TokenRegistry,
    byte_start: usize,
    byte_end: usize,
    out: &mut [SyntaxTokenSpan],
) -> usize {
    let query = match query_for_language(language) {
        Some(q) => q,
        None => return 0,
    };

    let mut cursor = QueryCursor::new();
    cursor.set_byte_range(byte_start..byte_end);

    let full_bytes: Vec<u8> = rope.bytes().collect();
    let root = tree.root_node();

    let mut count = 0;
    let mut match_iter = cursor.matches(&query, root, full_bytes.as_slice());
    while let Some(m) = match_iter.next() {
        for capture in m.captures.iter() {
            if count >= out.len() {
                return count;
            }

            let node = capture.node;
            let node_byte_start = node.byte_range().start;
            let node_byte_end = node.byte_range().end;

            let utf16_start = byte_to_utf16(rope, node_byte_start);
            let utf16_end = byte_to_utf16(rope, node_byte_end);
            let utf16_len = utf16_end.saturating_sub(utf16_start);
            if utf16_len == 0 || utf16_len > u16::MAX as usize {
                continue;
            }

            let capture_name = &query.capture_names()[capture.index as usize];
            let kind_id = registry.intern(capture_name);

            out[count] = SyntaxTokenSpan {
                utf16_start: utf16_start as u32,
                utf16_len: utf16_len as u16,
                kind_id,
                flags: 0,
                _pad: [0; 3],
            };
            count += 1;
        }
    }

    count
}

fn byte_to_utf16(rope: &Rope, byte_offset: usize) -> usize {
    if byte_offset == 0 {
        return 0;
    }
    let byte_offset = byte_offset.min(rope.len_bytes());
    let char_idx = rope.byte_to_char(byte_offset);
    let mut utf16_count: usize = 0;
    for ch in rope.chars().take(char_idx) {
        utf16_count += ch.len_utf16();
    }
    utf16_count
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rust_language() -> Language {
        tree_sitter_rust::LANGUAGE.into()
    }

    #[test]
    fn tokens_for_simple_function() {
        let src = "fn main() { let x = 42; }";
        let mut parser = tree_sitter::Parser::new();
        parser.set_language(&rust_language()).unwrap();
        let tree = parser.parse(src, None).unwrap();

        let rope = Rope::from_str(src);
        let mut registry = TokenRegistry::new();
        let mut buf = vec![
            SyntaxTokenSpan {
                utf16_start: 0,
                utf16_len: 0,
                kind_id: 0,
                flags: 0,
                _pad: [0; 3],
            };
            64
        ];

        let count = tokens_for_byte_range(
            &tree,
            &rust_language(),
            &rope,
            &mut registry,
            0,
            src.len(),
            &mut buf,
        );

        assert!(count > 0, "should produce tokens for Rust source");
        assert!(registry.id("number").is_some(), "should have interned 'number'");
    }

    #[test]
    fn viewport_restriction_works() {
        let src = "fn a() {}\nfn b() {}\nfn c() {}\n";
        let mut parser = tree_sitter::Parser::new();
        parser.set_language(&rust_language()).unwrap();
        let tree = parser.parse(src, None).unwrap();

        let rope = Rope::from_str(src);
        let mut registry = TokenRegistry::new();
        let mut buf = vec![
            SyntaxTokenSpan {
                utf16_start: 0,
                utf16_len: 0,
                kind_id: 0,
                flags: 0,
                _pad: [0; 3],
            };
            64
        ];

        let full_count = tokens_for_byte_range(
            &tree,
            &rust_language(),
            &rope,
            &mut registry,
            0,
            src.len(),
            &mut buf,
        );

        let partial_count = tokens_for_byte_range(
            &tree,
            &rust_language(),
            &rope,
            &mut registry,
            0,
            10,
            &mut buf,
        );

        assert!(
            partial_count <= full_count,
            "viewport restriction should produce fewer or equal tokens"
        );
    }
}
