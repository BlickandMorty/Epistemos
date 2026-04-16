use ropey::Rope;
use tree_sitter::{Parser, Point, Tree};

/// Parse a `Rope` using tree-sitter's chunk callback API.
///
/// The callback hands tree-sitter consecutive byte slices from the rope
/// without ever materializing the entire string. For incremental reparsing,
/// pass the previous `Tree` as `old_tree`.
pub fn parse_rope(parser: &mut Parser, rope: &Rope, old_tree: Option<&Tree>) -> Option<Tree> {
    let byte_len = rope.len_bytes();
    parser.parse_with_options(
        &mut |byte_offset: usize, _position: Point| -> &[u8] {
            if byte_offset >= byte_len {
                return &[];
            }
            let (chunk, chunk_byte_start, _, _) = rope.chunk_at_byte(byte_offset);
            let start_within_chunk = byte_offset - chunk_byte_start;
            &chunk.as_bytes()[start_within_chunk..]
        },
        old_tree,
        None,
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use tree_sitter::Language;

    fn rust_language() -> Language {
        tree_sitter_rust::LANGUAGE.into()
    }

    #[test]
    fn parse_simple_rope() {
        let mut parser = Parser::new();
        parser.set_language(&rust_language()).unwrap();

        let rope = Rope::from_str("fn hello() {}");
        let tree = parse_rope(&mut parser, &rope, None);
        assert!(tree.is_some());
        let tree = tree.unwrap();
        let root = tree.root_node();
        assert_eq!(root.kind(), "source_file");
        assert!(!root.has_error());
    }

    #[test]
    fn parse_multiline_rope() {
        let mut parser = Parser::new();
        parser.set_language(&rust_language()).unwrap();

        let src = "fn main() {\n    let x = 1;\n    let y = 2;\n}\n";
        let rope = Rope::from_str(src);
        let tree = parse_rope(&mut parser, &rope, None);
        assert!(tree.is_some());
        assert!(!tree.unwrap().root_node().has_error());
    }

    #[test]
    fn incremental_reparse() {
        let mut parser = Parser::new();
        parser.set_language(&rust_language()).unwrap();

        let src = "fn main() { let x = 1; }";
        let rope = Rope::from_str(src);
        let tree = parse_rope(&mut parser, &rope, None).unwrap();

        // Simulate editing "1" -> "42" at byte 20
        let mut rope2 = rope.clone();
        let char_idx = rope2.byte_to_char(20);
        rope2.remove(char_idx..char_idx + 1);
        rope2.insert(char_idx, "42");

        let mut old_tree = tree;
        old_tree.edit(&tree_sitter::InputEdit {
            start_byte: 20,
            old_end_byte: 21,
            new_end_byte: 22,
            start_position: Point::new(0, 20),
            old_end_position: Point::new(0, 21),
            new_end_position: Point::new(0, 22),
        });

        let new_tree = parse_rope(&mut parser, &rope2, Some(&old_tree));
        assert!(new_tree.is_some());
        assert!(!new_tree.unwrap().root_node().has_error());
    }

    #[test]
    fn parse_empty_rope() {
        let mut parser = Parser::new();
        parser.set_language(&rust_language()).unwrap();

        let rope = Rope::from_str("");
        let tree = parse_rope(&mut parser, &rope, None);
        assert!(tree.is_some());
    }

    #[test]
    fn parse_large_rope() {
        let mut parser = Parser::new();
        parser.set_language(&rust_language()).unwrap();

        let mut src = String::with_capacity(100_000);
        for i in 0..1000 {
            src.push_str(&format!("fn func_{i}() {{ let x = {i}; }}\n"));
        }
        let rope = Rope::from_str(&src);
        let tree = parse_rope(&mut parser, &rope, None);
        assert!(tree.is_some());
        assert!(!tree.unwrap().root_node().has_error());
    }
}
