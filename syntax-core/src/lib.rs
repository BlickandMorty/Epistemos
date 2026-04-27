pub mod ffi;
pub mod generation;
pub mod highlight;
pub mod honest_handle;
pub mod languages;
pub mod rope_bridge;
pub mod token_registry;

use ropey::Rope;
use tree_sitter::{Language, Parser, Tree};

use crate::generation::GenerationCounter;
use crate::rope_bridge::parse_rope;
use crate::token_registry::TokenRegistry;

// ---------------------------------------------------------------------------
// FFI data shapes (§23.5) — all #[repr(C)] for future Swift bridging
// ---------------------------------------------------------------------------

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SyntaxDocumentHandle {
    pub doc_id: u64,
    pub generation: u64,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SyntaxEditDelta {
    pub doc_id: u64,
    pub from_generation: u64,
    pub to_generation: u64,
    pub byte_offset: u64,
    pub old_len: u64,
    pub new_len: u64,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SyntaxViewportRequest {
    pub doc_id: u64,
    pub generation: u64,
    pub utf16_start: u32,
    pub utf16_end: u32,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SyntaxTokenSpan {
    pub utf16_start: u32,
    pub utf16_len: u16,
    pub kind_id: u16,
    pub flags: u8,
    pub _pad: [u8; 3],
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SyntaxFoldRange {
    pub byte_start: u64,
    pub byte_end: u64,
    pub kind_id: u16,
    pub _pad: [u8; 6],
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SyntaxDiagnosticRange {
    pub byte_start: u64,
    pub byte_end: u64,
    pub severity: u8,
    pub _pad: [u8; 7],
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SyntaxSnapshotStats {
    pub doc_id: u64,
    pub generation: u64,
    pub node_count: u32,
    pub error_count: u32,
    pub parse_time_us: u64,
}

// Compile-time size assertions — these guarantee ABI stability
const _: () = assert!(std::mem::size_of::<SyntaxDocumentHandle>() == 16);
const _: () = assert!(std::mem::size_of::<SyntaxEditDelta>() == 48);
const _: () = assert!(std::mem::size_of::<SyntaxViewportRequest>() == 24);
const _: () = assert!(std::mem::size_of::<SyntaxTokenSpan>() == 12);
const _: () = assert!(std::mem::size_of::<SyntaxFoldRange>() == 24);
const _: () = assert!(std::mem::size_of::<SyntaxDiagnosticRange>() == 24);
const _: () = assert!(std::mem::size_of::<SyntaxSnapshotStats>() == 32);

// ---------------------------------------------------------------------------
// SyntaxDocument — owns a Rope + Parser + Tree
// ---------------------------------------------------------------------------

pub struct SyntaxDocument {
    pub doc_id: u64,
    rope: Rope,
    parser: Parser,
    tree: Option<Tree>,
    generation: GenerationCounter,
    registry: TokenRegistry,
}

impl SyntaxDocument {
    pub fn new(doc_id: u64, language: &Language, source: &str) -> Self {
        let mut parser = Parser::new();
        parser
            .set_language(language)
            .expect("language version mismatch");

        let rope = Rope::from_str(source);
        let tree = parse_rope(&mut parser, &rope, None);
        let generation = GenerationCounter::new();

        Self {
            doc_id,
            rope,
            parser,
            tree,
            generation,
            registry: TokenRegistry::new(),
        }
    }

    pub fn handle(&self) -> SyntaxDocumentHandle {
        SyntaxDocumentHandle {
            doc_id: self.doc_id,
            generation: self.generation.current(),
        }
    }

    pub fn rope(&self) -> &Rope {
        &self.rope
    }

    pub fn tree(&self) -> Option<&Tree> {
        self.tree.as_ref()
    }

    pub fn registry(&self) -> &TokenRegistry {
        &self.registry
    }

    pub fn registry_mut(&mut self) -> &mut TokenRegistry {
        &mut self.registry
    }

    pub fn generation(&self) -> u64 {
        self.generation.current()
    }

    /// Apply an edit: replace byte range `start..start+old_len` with `new_text`.
    /// Returns a `SyntaxEditDelta` describing the change.
    pub fn edit(&mut self, byte_start: usize, old_len: usize, new_text: &str) -> SyntaxEditDelta {
        let from_gen = self.generation.current();

        let start_char = self.rope.byte_to_char(byte_start);
        let old_end_char = self.rope.byte_to_char(byte_start + old_len);
        let start_line = self.rope.char_to_line(start_char);
        let start_col = byte_start - self.rope.line_to_byte(start_line);
        let old_end_line = self.rope.char_to_line(old_end_char);
        let old_end_col = (byte_start + old_len) - self.rope.line_to_byte(old_end_line);

        self.rope.remove(start_char..old_end_char);
        self.rope.insert(start_char, new_text);

        if let Some(ref mut tree) = self.tree {
            let new_end_byte = byte_start + new_text.len();
            let new_end_char = self.rope.byte_to_char(new_end_byte);
            let new_end_line = self.rope.char_to_line(new_end_char);
            let new_end_col = new_end_byte - self.rope.line_to_byte(new_end_line);

            let old_end_byte = byte_start + old_len;

            tree.edit(&tree_sitter::InputEdit {
                start_byte: byte_start,
                old_end_byte,
                new_end_byte,
                start_position: tree_sitter::Point::new(start_line, start_col),
                old_end_position: tree_sitter::Point::new(old_end_line, old_end_col),
                new_end_position: tree_sitter::Point::new(new_end_line, new_end_col),
            });
        }

        self.tree = parse_rope(&mut self.parser, &self.rope, self.tree.as_ref());
        let to_gen = self.generation.increment();

        SyntaxEditDelta {
            doc_id: self.doc_id,
            from_generation: from_gen,
            to_generation: to_gen,
            byte_offset: byte_start as u64,
            old_len: old_len as u64,
            new_len: new_text.len() as u64,
        }
    }

    pub fn stats(&self) -> SyntaxSnapshotStats {
        let (node_count, error_count) = match &self.tree {
            Some(tree) => {
                let root = tree.root_node();
                count_nodes(root)
            }
            None => (0, 0),
        };
        SyntaxSnapshotStats {
            doc_id: self.doc_id,
            generation: self.generation.current(),
            node_count,
            error_count,
            parse_time_us: 0,
        }
    }
}

fn count_nodes(node: tree_sitter::Node) -> (u32, u32) {
    let mut total: u32 = 1;
    let mut errors: u32 = if node.is_error() || node.is_missing() {
        1
    } else {
        0
    };
    let mut cursor = node.walk();
    for child in node.children(&mut cursor) {
        let (t, e) = count_nodes(child);
        total = total.saturating_add(t);
        errors = errors.saturating_add(e);
    }
    (total, errors)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn rust_language() -> Language {
        tree_sitter_rust::LANGUAGE.into()
    }

    #[test]
    fn create_document_and_parse() {
        let src = "fn main() { let x = 42; }";
        let doc = SyntaxDocument::new(1, &rust_language(), src);
        assert!(doc.tree().is_some());
        let stats = doc.stats();
        assert!(stats.node_count > 0);
        assert_eq!(stats.error_count, 0);
    }

    #[test]
    fn edit_incremental_reparse() {
        let src = "fn main() { let x = 42; }";
        let mut doc = SyntaxDocument::new(1, &rust_language(), src);
        let gen_before = doc.generation();

        let delta = doc.edit(20, 2, "99");
        assert_eq!(delta.from_generation, gen_before);
        assert!(delta.to_generation > gen_before);
        assert!(doc.tree().is_some());

        let text: String = doc.rope().to_string();
        assert!(text.contains("99"));
        assert!(!text.contains("42"));
    }

    #[test]
    fn multiline_edit_keeps_tree_positions_consistent() {
        let src = "fn main() {\n    let x = 1;\n}\n";
        let mut doc = SyntaxDocument::new(1, &rust_language(), src);
        let old_line = "    let x = 1;\n";
        let replacement = "    let x = 1;\n    let y = 2;\n";
        let byte_start = src.find(old_line).unwrap();

        let delta = doc.edit(byte_start, old_line.len(), replacement);

        assert_eq!(delta.byte_offset as usize, byte_start);
        assert!(doc.tree().is_some());
        assert_eq!(doc.stats().error_count, 0);

        let text = doc.rope().to_string();
        assert!(text.contains("let x = 1;"));
        assert!(text.contains("let y = 2;"));
    }

    #[test]
    fn handle_matches_state() {
        let doc = SyntaxDocument::new(7, &rust_language(), "struct Foo;");
        let h = doc.handle();
        assert_eq!(h.doc_id, 7);
        assert_eq!(h.generation, doc.generation());
    }

    #[test]
    fn size_assertions_compile() {
        assert_eq!(std::mem::size_of::<SyntaxTokenSpan>(), 12);
        assert_eq!(std::mem::size_of::<SyntaxDocumentHandle>(), 16);
        assert_eq!(std::mem::size_of::<SyntaxEditDelta>(), 48);
        assert_eq!(std::mem::size_of::<SyntaxViewportRequest>(), 24);
        assert_eq!(std::mem::size_of::<SyntaxFoldRange>(), 24);
        assert_eq!(std::mem::size_of::<SyntaxDiagnosticRange>(), 24);
        assert_eq!(std::mem::size_of::<SyntaxSnapshotStats>(), 32);
    }

    #[test]
    fn empty_source() {
        let doc = SyntaxDocument::new(2, &rust_language(), "");
        assert!(doc.tree().is_some());
        assert_eq!(doc.rope().len_bytes(), 0);
    }

    #[test]
    fn unicode_source() {
        let src = "fn main() { let café = \"héllo\"; }";
        let doc = SyntaxDocument::new(3, &rust_language(), src);
        assert!(doc.tree().is_some());
        let stats = doc.stats();
        assert!(stats.node_count > 0);
    }
}
