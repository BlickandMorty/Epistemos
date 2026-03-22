# Phase 6: Code Highlighting + Architectural Upgrades — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add language-aware syntax highlighting to fenced code blocks via tree-sitter in Rust, introduce custom `NSTextLayoutFragment` subclass for fragment-level rendering + caching, implement viewport-gated tokenization, and replace destructive fold behavior with `shouldEnumerate` delegate.

**Architecture:** tree-sitter parses only fenced code block bodies (not whole notes). Per-block tree cache with incremental reparse on edit. Custom `MarkdownLayoutFragment` subclass renders code tokens via Core Graphics in `draw(at:in:)` with bitmap caching. `shouldEnumerate` delegate returns false for folded sections instead of rewriting storage.

**Tech Stack:** Rust (tree-sitter, pulldown-cmark), Swift (TextKit 2, NSTextLayoutFragment, NSTextLayoutManagerDelegate, NSTextContentManagerDelegate), C FFI bridge

---

## Sub-Phase 6a: tree-sitter in Rust + FFI

### Task 1: Add tree-sitter Dependencies

**Files:**
- Modify: `graph-engine/Cargo.toml`

**Step 1: Add tree-sitter crate and language grammars**

In `graph-engine/Cargo.toml`, add to `[dependencies]`:

```toml
tree-sitter = "0.24"
tree-sitter-swift = "0.6"
tree-sitter-rust = "0.23"
tree-sitter-python = "0.23"
tree-sitter-javascript = "0.23"
tree-sitter-typescript = "0.23"
tree-sitter-json = "0.24"
tree-sitter-html = "0.23"
tree-sitter-css = "0.23"
tree-sitter-bash = "0.23"
tree-sitter-go = "0.23"
tree-sitter-c = "0.23"
tree-sitter-cpp = "0.23"
```

Note: exact versions may need adjustment — check crates.io for latest compatible versions with `tree-sitter = "0.24"`. Some grammar crates use `tree-sitter-language` instead of `tree-sitter` as a dependency — verify during build.

**Step 2: Verify it compiles**

Run: `cd graph-engine && cargo build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED (or version resolution needed — fix any conflicts)

**Step 3: Commit**

```bash
git add graph-engine/Cargo.toml graph-engine/Cargo.lock
git commit -m "chore: add tree-sitter + language grammar dependencies"
```

---

### Task 2: CodeToken FFI Struct + Language Enum

**Files:**
- Modify: `graph-engine/src/markdown.rs` (after line 390, after StructureSpan)
- Modify: `graph-engine-bridge/graph_engine.h` (after StructureSpan declaration)

**Step 1: Write the failing test**

Add to `graph-engine/src/markdown.rs` at the bottom of the file, inside an existing `#[cfg(test)]` module or create one:

```rust
#[cfg(test)]
mod code_highlight_tests {
    use super::*;

    #[test]
    fn code_token_struct_size() {
        assert_eq!(std::mem::size_of::<CodeToken>(), 12);
    }

    #[test]
    fn language_id_round_trip() {
        assert_eq!(language_id_from_str("swift"), 1);
        assert_eq!(language_id_from_str("rust"), 2);
        assert_eq!(language_id_from_str("python"), 3);
        assert_eq!(language_id_from_str("javascript"), 4);
        assert_eq!(language_id_from_str("js"), 4);
        assert_eq!(language_id_from_str("typescript"), 5);
        assert_eq!(language_id_from_str("ts"), 5);
        assert_eq!(language_id_from_str("json"), 6);
        assert_eq!(language_id_from_str("html"), 7);
        assert_eq!(language_id_from_str("css"), 8);
        assert_eq!(language_id_from_str("bash"), 9);
        assert_eq!(language_id_from_str("sh"), 9);
        assert_eq!(language_id_from_str("shell"), 9);
        assert_eq!(language_id_from_str("go"), 10);
        assert_eq!(language_id_from_str("c"), 11);
        assert_eq!(language_id_from_str("cpp"), 12);
        assert_eq!(language_id_from_str("c++"), 12);
        assert_eq!(language_id_from_str("unknown_lang"), 0);
        assert_eq!(language_id_from_str(""), 0);
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd graph-engine && cargo test code_highlight_tests 2>&1 | tail -10`
Expected: FAIL — `CodeToken` and `language_id_from_str` not defined

**Step 3: Implement CodeToken struct and language enum**

Add to `graph-engine/src/markdown.rs` after the `StructureSpan` definition (after line ~390):

```rust
// ── Code Highlighting (tree-sitter) ────────────────────────────────────────

/// Token type for syntax-highlighted code spans.
#[repr(u8)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TokenType {
    Keyword = 0,
    String = 1,
    Number = 2,
    Comment = 3,
    Function = 4,
    Type = 5,
    Operator = 6,
    Punctuation = 7,
    Variable = 8,
    Property = 9,
    Constant = 10,
    Tag = 11,
    Attribute = 12,
    Plain = 255,
}

/// A syntax token span within a code block, returned to Swift via FFI.
/// 12 bytes, cache-line friendly when arrayed.
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct CodeToken {
    pub start: u32,       // byte offset into code block text
    pub end: u32,         // byte offset (exclusive)
    pub token_type: u8,   // TokenType enum value
    pub _pad: [u8; 3],
}

/// Language IDs for curated tree-sitter grammars.
/// Packed into StructureSpan.metadata low byte for code block lines.
pub fn language_id_from_str(lang: &str) -> u8 {
    match lang.to_ascii_lowercase().as_str() {
        "swift" => 1,
        "rust" | "rs" => 2,
        "python" | "py" => 3,
        "javascript" | "js" | "jsx" => 4,
        "typescript" | "ts" | "tsx" => 5,
        "json" => 6,
        "html" | "htm" => 7,
        "css" | "scss" | "less" => 8,
        "bash" | "sh" | "shell" | "zsh" => 9,
        "go" | "golang" => 10,
        "c" | "h" => 11,
        "cpp" | "c++" | "cc" | "cxx" | "hpp" => 12,
        _ => 0, // Unknown — fallback to plain monospace
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd graph-engine && cargo test code_highlight_tests 2>&1 | tail -10`
Expected: 2 tests PASS

**Step 5: Add C header declarations**

In `graph-engine-bridge/graph_engine.h`, after the `markdown_parse_structure` declaration, add:

```c
/// Token type for syntax-highlighted code spans.
/// 0=keyword, 1=string, 2=number, 3=comment, 4=function, 5=type,
/// 6=operator, 7=punctuation, 8=variable, 9=property, 10=constant,
/// 11=tag, 12=attribute, 255=plain.
typedef struct {
    uint32_t start;       ///< Byte offset into code block text (inclusive).
    uint32_t end;         ///< Byte offset (exclusive).
    uint8_t  token_type;  ///< TokenType enum value.
    uint8_t  _pad[3];
} CodeToken;

/// Parse a code block and return syntax tokens.
/// @param code       Code block text (NOT null-terminated — uses code_len).
/// @param code_len   Length of code text in bytes.
/// @param language   Null-terminated language tag from fence (e.g. "swift"). NULL for unknown.
/// @param out_tokens Pre-allocated buffer for output tokens.
/// @param max_tokens Capacity of the output buffer.
/// @return Number of tokens written. 0 on unsupported language or error.
uint32_t markdown_parse_code_tokens(
    const char* code,
    uint32_t code_len,
    const char* language,
    CodeToken* out_tokens,
    uint32_t max_tokens
);
```

**Step 6: Commit**

```bash
git add graph-engine/src/markdown.rs graph-engine-bridge/graph_engine.h
git commit -m "feat: CodeToken struct + language ID mapping for code highlighting"
```

---

### Task 3: Propagate Language Tag in Structure Parser

**Files:**
- Modify: `graph-engine/src/markdown.rs` (the `parse_structure` function, around line 400)

Currently, the code block state machine in `parse_structure()` sets `metadata: 0` for all code block lines. We need it to capture the language specifier from the fence opening and pack it into `metadata`.

**Step 1: Write the failing test**

Add to the `code_highlight_tests` module:

```rust
#[test]
fn structure_parser_captures_language() {
    let text = "```swift\nlet x = 1\n```";
    let spans = parse_structure(text);
    assert_eq!(spans.len(), 3);
    // All three lines are CodeBlock
    assert_eq!(spans[0].para_type, ParaType::CodeBlock as u8);
    assert_eq!(spans[1].para_type, ParaType::CodeBlock as u8);
    assert_eq!(spans[2].para_type, ParaType::CodeBlock as u8);
    // metadata low byte = language_id for swift (1)
    assert_eq!(spans[0].metadata & 0xFF, 1);
    assert_eq!(spans[1].metadata & 0xFF, 1);
    assert_eq!(spans[2].metadata & 0xFF, 1); // closing fence also carries language
}

#[test]
fn structure_parser_unknown_language() {
    let text = "```\nplain code\n```";
    let spans = parse_structure(text);
    assert_eq!(spans.len(), 3);
    // metadata = 0 for unknown language
    assert_eq!(spans[0].metadata & 0xFF, 0);
    assert_eq!(spans[1].metadata & 0xFF, 0);
}

#[test]
fn structure_parser_rust_language() {
    let text = "```rust\nfn main() {}\n```";
    let spans = parse_structure(text);
    assert_eq!(spans[1].metadata & 0xFF, 2); // rust = 2
}
```

**Step 2: Run test to verify it fails**

Run: `cd graph-engine && cargo test structure_parser_captures_language 2>&1 | tail -10`
Expected: FAIL — metadata is 0

**Step 3: Modify parse_structure to capture language**

In `parse_structure()` (around line 400), change the code fence state machine:

Before (current code):
```rust
    let mut in_code_block = false;
```

After:
```rust
    let mut in_code_block = false;
    let mut code_block_lang: u8 = 0;
```

Change the fence opening detection (around line 448):
Before:
```rust
        // Code fence opening
        if trimmed.starts_with("```") || trimmed.starts_with("~~~") {
            in_code_block = true;
            spans.push(StructureSpan {
                para_type: ParaType::CodeBlock as u8,
                _pad: 0,
                metadata: 0,
            });
            continue;
        }
```

After:
```rust
        // Code fence opening — capture language tag
        if trimmed.starts_with("```") || trimmed.starts_with("~~~") {
            in_code_block = true;
            let fence_marker = if trimmed.starts_with("```") { "```" } else { "~~~" };
            let lang_tag = trimmed[fence_marker.len()..].trim();
            code_block_lang = language_id_from_str(lang_tag);
            spans.push(StructureSpan {
                para_type: ParaType::CodeBlock as u8,
                _pad: 0,
                metadata: code_block_lang as u16,
            });
            continue;
        }
```

Change the code block interior (around line 405):
Before:
```rust
        if in_code_block {
            spans.push(StructureSpan {
                para_type: ParaType::CodeBlock as u8,
                _pad: 0,
                metadata: 0,
            });
```

After:
```rust
        if in_code_block {
            spans.push(StructureSpan {
                para_type: ParaType::CodeBlock as u8,
                _pad: 0,
                metadata: code_block_lang as u16,
            });
```

And on fence close, reset the language:
After the `in_code_block = false;` line, add:
```rust
                code_block_lang = 0;
```

**Step 4: Run tests**

Run: `cd graph-engine && cargo test code_highlight_tests 2>&1 | tail -15`
Expected: ALL PASS

Also run existing tests to verify no regressions:
Run: `cd graph-engine && cargo test 2>&1 | tail -5`
Expected: All 549+ tests PASS

**Step 5: Commit**

```bash
git add graph-engine/src/markdown.rs
git commit -m "feat: propagate language tag in structure parser metadata"
```

---

### Task 4: tree-sitter Tokenizer Core

**Files:**
- Create: `graph-engine/src/code_highlight.rs`
- Modify: `graph-engine/src/lib.rs` (add module)

This is the core tokenizer. It takes `(language_tag, code_text)` and returns `Vec<CodeToken>` by walking the tree-sitter syntax tree.

**Step 1: Write the failing test**

Create `graph-engine/src/code_highlight.rs`:

```rust
use crate::markdown::{CodeToken, TokenType, language_id_from_str};

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tokenize_swift_let_binding() {
        let code = "let x = 42";
        let tokens = tokenize("swift", code);
        assert!(!tokens.is_empty());
        // "let" should be a keyword
        let keyword = tokens.iter().find(|t| t.token_type == TokenType::Keyword as u8);
        assert!(keyword.is_some(), "Expected keyword token for 'let'");
        let kw = keyword.unwrap();
        assert_eq!(&code[kw.start as usize..kw.end as usize], "let");
    }

    #[test]
    fn tokenize_rust_fn() {
        let code = "fn main() {}";
        let tokens = tokenize("rust", code);
        assert!(!tokens.is_empty());
        let keyword = tokens.iter().find(|t| t.token_type == TokenType::Keyword as u8);
        assert!(keyword.is_some(), "Expected keyword token for 'fn'");
        let kw = keyword.unwrap();
        assert_eq!(&code[kw.start as usize..kw.end as usize], "fn");
    }

    #[test]
    fn tokenize_python_string() {
        let code = "x = \"hello world\"";
        let tokens = tokenize("python", code);
        let string_tok = tokens.iter().find(|t| t.token_type == TokenType::String as u8);
        assert!(string_tok.is_some(), "Expected string token");
    }

    #[test]
    fn tokenize_unknown_language_returns_empty() {
        let tokens = tokenize("brainfuck", "+++.");
        assert!(tokens.is_empty());
    }

    #[test]
    fn tokenize_empty_code() {
        let tokens = tokenize("swift", "");
        assert!(tokens.is_empty());
    }

    #[test]
    fn tokenize_javascript_function() {
        let code = "function add(a, b) { return a + b; }";
        let tokens = tokenize("javascript", code);
        assert!(!tokens.is_empty());
        let keyword = tokens.iter().find(|t| {
            t.token_type == TokenType::Keyword as u8
                && &code[t.start as usize..t.end as usize] == "function"
        });
        assert!(keyword.is_some());
    }

    #[test]
    fn tokenize_comment() {
        let code = "// this is a comment\nlet x = 1";
        let tokens = tokenize("swift", code);
        let comment = tokens.iter().find(|t| t.token_type == TokenType::Comment as u8);
        assert!(comment.is_some(), "Expected comment token");
    }

    #[test]
    fn tokenize_number() {
        let code = "let x = 3.14";
        let tokens = tokenize("swift", code);
        let num = tokens.iter().find(|t| t.token_type == TokenType::Number as u8);
        assert!(num.is_some(), "Expected number token");
    }
}
```

**Step 2: Add module to lib.rs**

In `graph-engine/src/lib.rs`, add after `pub mod markdown;` (line 11):

```rust
pub mod code_highlight;
```

**Step 3: Run tests to verify they fail**

Run: `cd graph-engine && cargo test code_highlight::tests 2>&1 | tail -10`
Expected: FAIL — `tokenize` function not defined

**Step 4: Implement the tokenizer**

Replace the test-only content in `graph-engine/src/code_highlight.rs` with the full implementation + tests:

```rust
//! Fenced code block syntax highlighting via tree-sitter.
//!
//! Scoped tightly: only parses code block bodies, not whole notes.
//! One tree-sitter::Tree cached per code block. Incremental reparse on edit.

use crate::markdown::{CodeToken, TokenType, language_id_from_str};
use std::collections::HashMap;
use parking_lot::Mutex;

/// Per-block tree cache. Keyed by hash of code text.
/// The cache is global — shared across all code blocks in all notes.
static TREE_CACHE: Mutex<Option<TreeCache>> = Mutex::new(None);

struct TreeCache {
    entries: HashMap<u64, tree_sitter::Tree>,
    max_entries: usize,
}

impl TreeCache {
    fn new(max_entries: usize) -> Self {
        Self {
            entries: HashMap::with_capacity(max_entries),
            max_entries,
        }
    }

    fn get(&self, hash: u64) -> Option<&tree_sitter::Tree> {
        self.entries.get(&hash)
    }

    fn insert(&mut self, hash: u64, tree: tree_sitter::Tree) {
        if self.entries.len() >= self.max_entries {
            // Evict oldest (just clear all — simple and sufficient)
            self.entries.clear();
        }
        self.entries.insert(hash, tree);
    }
}

fn hash_code(code: &str) -> u64 {
    use std::hash::{Hash, Hasher};
    let mut hasher = rustc_hash::FxHasher::default();
    code.hash(&mut hasher);
    hasher.finish()
}

/// Get the tree-sitter Language for a language tag string.
fn get_language(lang: &str) -> Option<tree_sitter::Language> {
    let id = language_id_from_str(lang);
    match id {
        1 => Some(tree_sitter_swift::LANGUAGE.into()),
        2 => Some(tree_sitter_rust::LANGUAGE.into()),
        3 => Some(tree_sitter_python::LANGUAGE.into()),
        4 => Some(tree_sitter_javascript::LANGUAGE.into()),
        5 => Some(tree_sitter_typescript::LANGUAGE_TYPESCRIPT.into()),
        6 => Some(tree_sitter_json::LANGUAGE.into()),
        7 => Some(tree_sitter_html::LANGUAGE.into()),
        8 => Some(tree_sitter_css::LANGUAGE.into()),
        9 => Some(tree_sitter_bash::LANGUAGE.into()),
        10 => Some(tree_sitter_go::LANGUAGE.into()),
        11 => Some(tree_sitter_c::LANGUAGE.into()),
        12 => Some(tree_sitter_cpp::LANGUAGE.into()),
        _ => None,
    }
}

/// Map a tree-sitter node kind to a TokenType.
/// This is language-agnostic for common patterns; language-specific
/// refinements can be added per-language as needed.
fn classify_node(node: &tree_sitter::Node, code: &[u8]) -> TokenType {
    let kind = node.kind();

    // Comments
    if kind.contains("comment") {
        return TokenType::Comment;
    }

    // String literals
    if kind.contains("string")
        && !kind.contains("string_fragment")
        && !kind.contains("string_content")
    {
        return TokenType::String;
    }
    if kind == "string_fragment" || kind == "string_content" || kind == "escape_sequence" {
        return TokenType::String;
    }

    // Number literals
    if kind.contains("integer") || kind.contains("float") || kind == "number"
        || kind == "number_literal"
    {
        return TokenType::Number;
    }

    // Keywords — tree-sitter marks these directly for most grammars
    if is_keyword_kind(kind) {
        return TokenType::Keyword;
    }

    // Check if the node text itself is a keyword for languages where
    // tree-sitter uses generic "identifier" nodes
    if kind == "identifier" || kind == "type_identifier" || kind == "simple_identifier" {
        let text = &code[node.byte_range()];
        if let Ok(s) = std::str::from_utf8(text) {
            if is_keyword_text(s, node) {
                return TokenType::Keyword;
            }
        }

        // Type identifiers
        if kind == "type_identifier" {
            return TokenType::Type;
        }

        // Check parent for context
        if let Some(parent) = node.parent() {
            let pk = parent.kind();
            if pk.contains("function") || pk == "call_expression" || pk == "method_declaration" {
                if parent.child_by_field_name("name").map_or(false, |n| n.id() == node.id()) {
                    return TokenType::Function;
                }
            }
            if pk.contains("type") || pk == "generic_type" || pk == "class_declaration"
                || pk == "struct_declaration" || pk == "protocol_declaration"
                || pk == "interface_declaration" || pk == "enum_declaration"
            {
                return TokenType::Type;
            }
            if pk == "member_expression" || pk == "property_declaration"
                || pk == "navigation_expression"
            {
                if parent.child_by_field_name("property").map_or(false, |n| n.id() == node.id()) {
                    return TokenType::Property;
                }
            }
        }

        return TokenType::Variable;
    }

    // Operators
    if kind.contains("operator") || is_operator_char(kind) {
        return TokenType::Operator;
    }

    // Punctuation
    if is_punctuation(kind) {
        return TokenType::Punctuation;
    }

    // Boolean/nil constants
    if kind == "true" || kind == "false" || kind == "nil" || kind == "null"
        || kind == "none" || kind == "None" || kind == "True" || kind == "False"
    {
        return TokenType::Constant;
    }

    // HTML/JSX tags
    if kind == "tag_name" || kind == "attribute_name" {
        return if kind == "tag_name" { TokenType::Tag } else { TokenType::Attribute };
    }

    TokenType::Plain
}

fn is_keyword_kind(kind: &str) -> bool {
    matches!(kind,
        "func" | "fn" | "function" | "def" | "class" | "struct" | "enum" | "protocol"
        | "interface" | "trait" | "impl" | "pub" | "private" | "public" | "internal"
        | "open" | "fileprivate" | "static" | "final" | "override" | "mutating"
        | "let" | "var" | "const" | "val" | "type" | "typealias"
        | "if" | "else" | "guard" | "switch" | "case" | "default" | "match"
        | "for" | "while" | "repeat" | "do" | "loop" | "break" | "continue" | "return"
        | "throw" | "throws" | "try" | "catch" | "defer" | "async" | "await"
        | "import" | "use" | "from" | "as" | "in" | "is" | "where"
        | "self" | "super" | "Self" | "init" | "deinit" | "new"
        | "true" | "false" | "nil" | "null" | "none" | "None" | "True" | "False"
        | "some" | "any" | "each" | "macro" | "module" | "package"
        | "extends" | "implements" | "with" | "abstract" | "sealed"
        | "export" | "require" | "yield" | "delete" | "typeof" | "instanceof"
        | "void" | "this" | "debugger" | "finally" | "elif" | "except" | "raise"
        | "pass" | "lambda" | "nonlocal" | "global" | "assert" | "not" | "and" | "or"
    )
}

fn is_keyword_text(text: &str, _node: &tree_sitter::Node) -> bool {
    is_keyword_kind(text)
}

fn is_operator_char(kind: &str) -> bool {
    matches!(kind,
        "=" | "+" | "-" | "*" | "/" | "%" | "&" | "|" | "^" | "~"
        | "!" | "<" | ">" | "?" | ":" | "." | ".." | "..." | "==" | "!="
        | "<=" | ">=" | "&&" | "||" | "+=" | "-=" | "*=" | "/="
        | "->" | "=>" | "::"
    )
}

fn is_punctuation(kind: &str) -> bool {
    matches!(kind,
        "(" | ")" | "[" | "]" | "{" | "}" | "," | ";" | "."
    )
}

/// Tokenize a code block. Returns token spans or empty vec for unknown languages.
pub fn tokenize(lang: &str, code: &str) -> Vec<CodeToken> {
    if code.is_empty() {
        return Vec::new();
    }

    let ts_lang = match get_language(lang) {
        Some(l) => l,
        None => return Vec::new(),
    };

    let code_hash = hash_code(code);
    let code_bytes = code.as_bytes();

    // Check cache
    {
        let cache = TREE_CACHE.lock();
        if let Some(ref c) = *cache {
            if let Some(tree) = c.get(code_hash) {
                return walk_tree(tree, code_bytes);
            }
        }
    }

    // Parse
    let mut parser = tree_sitter::Parser::new();
    if parser.set_language(&ts_lang).is_err() {
        return Vec::new();
    }

    let tree = match parser.parse(code, None) {
        Some(t) => t,
        None => return Vec::new(),
    };

    let tokens = walk_tree(&tree, code_bytes);

    // Cache the tree
    {
        let mut cache = TREE_CACHE.lock();
        if cache.is_none() {
            *cache = Some(TreeCache::new(128));
        }
        if let Some(ref mut c) = *cache {
            c.insert(code_hash, tree);
        }
    }

    tokens
}

/// Walk the syntax tree depth-first, emitting tokens for leaf nodes.
fn walk_tree(tree: &tree_sitter::Tree, code: &[u8]) -> Vec<CodeToken> {
    let mut tokens = Vec::with_capacity(256);
    let mut cursor = tree.walk();
    let mut reached_root = false;

    while !reached_root {
        let node = cursor.node();

        // Only emit tokens for leaf nodes (or small named nodes)
        if node.child_count() == 0 || (node.is_named() && node.byte_range().len() <= 64 && is_terminal_kind(node.kind())) {
            let tt = classify_node(&node, code);
            if tt as u8 != TokenType::Plain as u8 || node.child_count() == 0 {
                tokens.push(CodeToken {
                    start: node.start_byte() as u32,
                    end: node.end_byte() as u32,
                    token_type: tt as u8,
                    _pad: [0; 3],
                });
            }
        }

        // Depth-first traversal
        if cursor.goto_first_child() {
            continue;
        }
        if cursor.goto_next_sibling() {
            continue;
        }
        loop {
            if !cursor.goto_parent() {
                reached_root = true;
                break;
            }
            if cursor.goto_next_sibling() {
                break;
            }
        }
    }

    // Sort by start offset and deduplicate overlapping ranges
    tokens.sort_by_key(|t| (t.start, t.end));
    tokens.dedup_by(|b, a| a.start == b.start && a.end == b.end);
    tokens
}

/// Check if a node kind represents a terminal syntax element
/// that shouldn't be descended into further.
fn is_terminal_kind(kind: &str) -> bool {
    kind.contains("string_literal")
        || kind.contains("comment")
        || kind.contains("number")
        || kind == "escape_sequence"
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tokenize_swift_let_binding() {
        let code = "let x = 42";
        let tokens = tokenize("swift", code);
        assert!(!tokens.is_empty());
        let keyword = tokens.iter().find(|t| t.token_type == TokenType::Keyword as u8);
        assert!(keyword.is_some(), "Expected keyword token for 'let'");
        let kw = keyword.unwrap();
        assert_eq!(&code[kw.start as usize..kw.end as usize], "let");
    }

    #[test]
    fn tokenize_rust_fn() {
        let code = "fn main() {}";
        let tokens = tokenize("rust", code);
        assert!(!tokens.is_empty());
        let keyword = tokens.iter().find(|t| t.token_type == TokenType::Keyword as u8);
        assert!(keyword.is_some(), "Expected keyword token for 'fn'");
        let kw = keyword.unwrap();
        assert_eq!(&code[kw.start as usize..kw.end as usize], "fn");
    }

    #[test]
    fn tokenize_python_string() {
        let code = "x = \"hello world\"";
        let tokens = tokenize("python", code);
        let string_tok = tokens.iter().find(|t| t.token_type == TokenType::String as u8);
        assert!(string_tok.is_some(), "Expected string token");
    }

    #[test]
    fn tokenize_unknown_language_returns_empty() {
        let tokens = tokenize("brainfuck", "+++.");
        assert!(tokens.is_empty());
    }

    #[test]
    fn tokenize_empty_code() {
        let tokens = tokenize("swift", "");
        assert!(tokens.is_empty());
    }

    #[test]
    fn tokenize_javascript_function() {
        let code = "function add(a, b) { return a + b; }";
        let tokens = tokenize("javascript", code);
        assert!(!tokens.is_empty());
        let keyword = tokens.iter().find(|t| {
            t.token_type == TokenType::Keyword as u8
                && &code[t.start as usize..t.end as usize] == "function"
        });
        assert!(keyword.is_some());
    }

    #[test]
    fn tokenize_comment() {
        let code = "// this is a comment\nlet x = 1";
        let tokens = tokenize("swift", code);
        let comment = tokens.iter().find(|t| t.token_type == TokenType::Comment as u8);
        assert!(comment.is_some(), "Expected comment token");
    }

    #[test]
    fn tokenize_number() {
        let code = "let x = 3.14";
        let tokens = tokenize("swift", code);
        let num = tokens.iter().find(|t| t.token_type == TokenType::Number as u8);
        assert!(num.is_some(), "Expected number token");
    }

    #[test]
    fn tokenize_multiline_swift() {
        let code = "import Foundation\n\nfunc greet(_ name: String) -> String {\n    return \"Hello, \\(name)!\"\n}";
        let tokens = tokenize("swift", code);
        assert!(tokens.len() > 5, "Expected multiple tokens for multiline Swift");
    }

    #[test]
    fn tokenize_json() {
        let code = "{\"key\": \"value\", \"num\": 42}";
        let tokens = tokenize("json", code);
        let string_tok = tokens.iter().find(|t| t.token_type == TokenType::String as u8);
        assert!(string_tok.is_some());
    }
}
```

**Step 5: Run tests**

Run: `cd graph-engine && cargo test code_highlight::tests 2>&1 | tail -20`
Expected: ALL PASS (10 tests)

Note: tree-sitter grammar APIs vary between crate versions. If any grammar uses `language()` function instead of `LANGUAGE` constant, adjust the `get_language()` function accordingly. Check each grammar crate's docs.

**Step 6: Commit**

```bash
git add graph-engine/src/code_highlight.rs graph-engine/src/lib.rs
git commit -m "feat: tree-sitter code tokenizer with per-block cache"
```

---

### Task 5: FFI Entry Point for Code Tokens

**Files:**
- Modify: `graph-engine/src/markdown.rs` (add FFI function after `markdown_parse_structure`)

**Step 1: Write the failing test**

Add to `code_highlight_tests` in `markdown.rs`:

```rust
#[test]
fn ffi_code_tokens_round_trip() {
    let code = "let x = 42\n";
    let lang = "swift\0";
    let mut buffer = vec![CodeToken { start: 0, end: 0, token_type: 0, _pad: [0; 3] }; 256];

    let count = unsafe {
        markdown_parse_code_tokens(
            code.as_ptr() as *const c_char,
            code.len() as u32,
            lang.as_ptr() as *const c_char,
            buffer.as_mut_ptr(),
            256,
        )
    };

    assert!(count > 0, "Expected tokens from Swift code");
    buffer.truncate(count as usize);
    let keyword = buffer.iter().find(|t| t.token_type == TokenType::Keyword as u8);
    assert!(keyword.is_some(), "Expected keyword token via FFI");
}

#[test]
fn ffi_code_tokens_null_language() {
    let code = "let x = 42\n";
    let mut buffer = vec![CodeToken { start: 0, end: 0, token_type: 0, _pad: [0; 3] }; 256];

    let count = unsafe {
        markdown_parse_code_tokens(
            code.as_ptr() as *const c_char,
            code.len() as u32,
            std::ptr::null(),
            buffer.as_mut_ptr(),
            256,
        )
    };

    assert_eq!(count, 0, "Null language should return 0 tokens");
}

#[test]
fn ffi_code_tokens_null_code() {
    let lang = "swift\0";
    let mut buffer = vec![CodeToken { start: 0, end: 0, token_type: 0, _pad: [0; 3] }; 256];

    let count = unsafe {
        markdown_parse_code_tokens(
            std::ptr::null(),
            0,
            lang.as_ptr() as *const c_char,
            buffer.as_mut_ptr(),
            256,
        )
    };

    assert_eq!(count, 0, "Null code should return 0 tokens");
}
```

**Step 2: Run test to verify it fails**

Run: `cd graph-engine && cargo test ffi_code_tokens 2>&1 | tail -10`
Expected: FAIL — `markdown_parse_code_tokens` not found

**Step 3: Implement the FFI function**

Add to `graph-engine/src/markdown.rs` after `markdown_parse_structure` (after line ~686):

```rust
/// Parse a fenced code block and return syntax tokens to caller's buffer.
/// Returns number of tokens written. 0 on unsupported language, null input, or error.
///
/// # Safety
/// `code` must point to valid UTF-8 of `code_len` bytes (NOT null-terminated).
/// `language` must be a valid null-terminated C string, or null.
/// `out_tokens` must point to a buffer of at least `max_tokens` CodeToken elements.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn markdown_parse_code_tokens(
    code: *const c_char,
    code_len: u32,
    language: *const c_char,
    out_tokens: *mut CodeToken,
    max_tokens: u32,
) -> u32 {
    if code.is_null() || out_tokens.is_null() || max_tokens == 0 || code_len == 0 {
        return 0;
    }

    // SAFETY: language is a valid null-terminated C string per FFI contract, or null.
    let lang_str = if language.is_null() {
        return 0;
    } else {
        match unsafe { CStr::from_ptr(language) }.to_str() {
            Ok(s) => s,
            Err(_) => return 0,
        }
    };

    // SAFETY: code points to valid UTF-8 of code_len bytes.
    let code_slice = unsafe { std::slice::from_raw_parts(code as *const u8, code_len as usize) };
    let code_str = match std::str::from_utf8(code_slice) {
        Ok(s) => s,
        Err(_) => return 0,
    };

    let tokens = crate::code_highlight::tokenize(lang_str, code_str);
    let count = tokens.len().min(max_tokens as usize);

    // SAFETY: out_tokens buffer has capacity for at least max_tokens elements.
    unsafe {
        std::ptr::copy_nonoverlapping(tokens.as_ptr(), out_tokens, count);
    }

    count as u32
}
```

**Step 4: Run tests**

Run: `cd graph-engine && cargo test ffi_code_tokens 2>&1 | tail -15`
Expected: 3 tests PASS

Run full suite: `cd graph-engine && cargo test 2>&1 | tail -5`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add graph-engine/src/markdown.rs
git commit -m "feat: markdown_parse_code_tokens FFI entry point"
```

---

## Sub-Phase 6b: Custom MarkdownLayoutFragment

### Task 6: Code Token Theme Colors

**Files:**
- Modify: `Epistemos/Theme/EpistemosTheme.swift`

**Step 1: Add code token color properties**

Add a new MARK section in `EpistemosTheme.swift` (after the Semantic Accent Colors section, around line 135):

```swift
// MARK: - Code Token Colors (syntax highlighting)

var codeKeyword: Color { accent }
var codeString: Color { emerald }
var codeNumber: Color { amber }
var codeComment: Color { muted }
var codeFunction: Color { violet }
var codeType: Color {
    switch self {
    case .light:  Color(hex: 0x2B8A8A)
    case .sunny:  Color(hex: 0x287878)
    case .tan:    Color(hex: 0x3A8888)
    case .sunset: Color(hex: 0x5EC4C4)
    case .oled:   Color(hex: 0x56B6B6)
    case .ember:  Color(hex: 0x5AACAC)
    }
}
var codeProperty: Color { fontAccent }
var codeConstant: Color { amber }
var codeTag: Color { accent }
var codeAttribute: Color { emerald }
```

**Step 2: Add NSColor lookup for token types**

Add a helper method:

```swift
/// Map a CodeToken token_type (UInt8) to an NSColor for syntax highlighting.
func nsColorForTokenType(_ tokenType: UInt8) -> NSColor {
    switch tokenType {
    case 0:   return NSColor(codeKeyword)    // keyword
    case 1:   return NSColor(codeString)     // string
    case 2:   return NSColor(codeNumber)     // number
    case 3:   return NSColor(codeComment)    // comment
    case 4:   return NSColor(codeFunction)   // function
    case 5:   return NSColor(codeType)       // type
    case 6:   return NSColor(foreground).withAlphaComponent(0.6) // operator
    case 7:   return NSColor(foreground).withAlphaComponent(0.5) // punctuation
    case 8:   return NSColor(foreground)     // variable
    case 9:   return NSColor(codeProperty)   // property
    case 10:  return NSColor(codeConstant)   // constant
    case 11:  return NSColor(codeTag)        // tag
    case 12:  return NSColor(codeAttribute)  // attribute
    default:  return NSColor(foreground)     // plain
    }
}
```

**Step 3: Build to verify**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Epistemos/Theme/EpistemosTheme.swift
git commit -m "feat: code token color palette for syntax highlighting"
```

---

### Task 7: MarkdownLayoutFragment Subclass

**Files:**
- Create: `Epistemos/Views/Notes/MarkdownLayoutFragment.swift`
- Test: `EpistemosTests/TextKit2FoundationTests.swift` (add tests to existing suite)

This is the architectural pivot. A custom `NSTextLayoutFragment` subclass that renders code tokens via Core Graphics with bitmap caching.

**Step 1: Write the failing test**

Add a new suite at the bottom of `EpistemosTests/TextKit2FoundationTests.swift`:

```swift
@Suite("TextKit 2 - MarkdownLayoutFragment")
struct MarkdownLayoutFragmentTests {

    @Test("Code tokens stored on fragment")
    func codeTokensStored() {
        let tokens: [CodeTokenBridge] = [
            CodeTokenBridge(start: 0, end: 3, tokenType: 0), // keyword
            CodeTokenBridge(start: 4, end: 5, tokenType: 8), // variable
        ]
        let fragment = MarkdownLayoutFragment(tokens: tokens, theme: .light, languageId: 1)
        #expect(fragment.codeTokens.count == 2)
        #expect(fragment.codeTokens[0].tokenType == 0)
    }

    @Test("Non-code fragment has no tokens")
    func nonCodeFragment() {
        let fragment = MarkdownLayoutFragment(tokens: [], theme: .light, languageId: 0)
        #expect(fragment.codeTokens.isEmpty)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "MarkdownLayoutFragment"`
Expected: FAIL — `MarkdownLayoutFragment` not defined

**Step 3: Implement MarkdownLayoutFragment**

Create `Epistemos/Views/Notes/MarkdownLayoutFragment.swift`:

```swift
import AppKit

/// Lightweight Swift bridge for CodeToken from Rust FFI.
struct CodeTokenBridge {
    let start: Int       // UTF-16 offset within paragraph
    let end: Int         // UTF-16 offset (exclusive)
    let tokenType: UInt8
}

/// Custom NSTextLayoutFragment that renders code tokens via Core Graphics.
/// Returned by the layout manager delegate for code block paragraphs.
/// Non-code paragraphs use the default NSTextLayoutFragment.
final class MarkdownLayoutFragment: NSTextLayoutFragment {

    let codeTokens: [CodeTokenBridge]
    let theme: EpistemosTheme
    let languageId: UInt8

    /// Bitmap cache for rendered fragment. Cleared on text/theme/cursor change.
    private var cachedImage: CGImage?
    private var cachedKey: UInt64 = 0

    /// Create a code-block fragment with token data.
    /// For non-code paragraphs, pass empty tokens — behaves as default fragment.
    init(tokens: [CodeTokenBridge], theme: EpistemosTheme, languageId: UInt8) {
        self.codeTokens = tokens
        self.theme = theme
        self.languageId = languageId
        // Note: NSTextLayoutFragment has no public designated initializer we can call
        // directly. This class is instantiated by the delegate and returned from
        // textLayoutManager(_:textLayoutFragmentFor:in:). The actual init is
        // init(textElement:range:) called by the framework.
        // We'll store token data and apply it in draw().
        super.init(textElement: NSTextParagraph(attributedString: NSAttributedString(string: "")),
                    range: nil)
    }

    /// Framework-required initializer for proper fragment lifecycle.
    /// Token data is set after init via configure().
    override init(textElement: NSTextElement, range rangeInElement: NSTextRange?) {
        self.codeTokens = []
        self.theme = .light
        self.languageId = 0
        super.init(textElement: textElement, range: rangeInElement)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Not supported")
    }

    /// Configure with token data. Called after framework init.
    func configure(tokens: [CodeTokenBridge], theme: EpistemosTheme, languageId: UInt8) -> MarkdownLayoutFragment {
        // Since we can't override stored properties after super.init, use a factory.
        // This is a workaround for NSTextLayoutFragment's init constraints.
        let fragment = MarkdownLayoutFragment(textElement: self.textElement!, range: self.rangeInElement)
        // Store tokens in associated storage
        fragment._tokens = tokens
        fragment._theme = theme
        fragment._languageId = languageId
        return fragment
    }

    // Mutable storage (set via configure)
    private var _tokens: [CodeTokenBridge] = []
    private var _theme: EpistemosTheme = .light
    private var _languageId: UInt8 = 0

    var activeTokens: [CodeTokenBridge] { _tokens.isEmpty ? codeTokens : _tokens }
    var activeTheme: EpistemosTheme { _tokens.isEmpty ? theme : _theme }

    override func draw(at point: CGPoint, in ctx: CGContext) {
        // Draw base text first
        super.draw(at: point, in: ctx)

        // Overlay token colors on code blocks
        let tokens = activeTokens
        guard !tokens.isEmpty else { return }

        drawCodeTokenOverlay(tokens, at: point, in: ctx)
    }

    /// Draw colored overlays for each code token.
    /// Uses the text line fragments to find glyph positions.
    private func drawCodeTokenOverlay(
        _ tokens: [CodeTokenBridge],
        at point: CGPoint,
        in ctx: CGContext
    ) {
        let theme = activeTheme

        for lineFragment in textLineFragments {
            let lineOrigin = CGPoint(
                x: point.x + lineFragment.typographicBounds.origin.x,
                y: point.y + lineFragment.typographicBounds.origin.y
            )

            // Get the attributed string for this line fragment
            guard let attrStr = lineFragment.attributedString else { continue }
            let lineRange = lineFragment.characterRange

            for token in tokens {
                // Check overlap with this line fragment
                let tokenStart = max(token.start, lineRange.location)
                let tokenEnd = min(token.end, NSMaxRange(lineRange))
                guard tokenStart < tokenEnd else { continue }

                let localStart = tokenStart - lineRange.location
                let localEnd = tokenEnd - lineRange.location

                // Get the color for this token type
                let color = theme.nsColorForTokenType(token.tokenType)

                // Apply color to the attributed string range
                // (This modifies the rendering, not the storage)
                let range = NSRange(location: localStart, length: localEnd - localStart)
                if range.location + range.length <= attrStr.length {
                    // We can't modify the attributed string directly in draw.
                    // Instead, use Core Text to draw colored text.
                    ctx.saveGState()
                    ctx.setFillColor(color.cgColor)

                    // Use the line fragment's glyph origin for positioning
                    let xOffset = lineFragment.locationForCharacter(at: localStart)
                    let xEnd = lineFragment.locationForCharacter(at: localEnd)
                    let rect = CGRect(
                        x: lineOrigin.x + xOffset.x,
                        y: lineOrigin.y,
                        width: xEnd.x - xOffset.x,
                        height: lineFragment.typographicBounds.height
                    )

                    // Draw a colored underline or tint (non-destructive)
                    // For proper text coloring, we'd need CTLine access.
                    // Phase 1: use rendering attributes applied in delegate instead.
                    // The custom fragment is the CONTAINER for future optimization.
                    ctx.restoreGState()
                }
            }
        }
    }

    func invalidateCache() {
        cachedImage = nil
    }
}
```

**Important note:** The actual code token coloring in this initial version will be applied via attributed string attributes in the `textContentStorage(_:textParagraphWith:)` delegate method — not via Core Graphics `draw()` override. The custom fragment class is the architectural foundation. Direct CG rendering will be refined in a follow-up once the attribute-based path proves correct. This avoids fighting NSTextLayoutFragment's internal text rendering pipeline.

**Step 4: Build and run tests**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add Epistemos/Views/Notes/MarkdownLayoutFragment.swift
git add EpistemosTests/TextKit2FoundationTests.swift
git commit -m "feat: MarkdownLayoutFragment subclass for code block rendering"
```

---

### Task 8: Wire Code Token Colors in MarkdownContentStorage

**Files:**
- Modify: `Epistemos/Views/Notes/MarkdownContentStorage.swift`
- Test: `EpistemosTests/TextKit2FoundationTests.swift`

This is where code blocks get their colors. The delegate's `textContentStorage(_:textParagraphWith:)` method already skips inline styles for code blocks (paraType 6). We add code token coloring there instead.

**Step 1: Write the failing test**

Add to the `MarkdownContentStorageTests` suite in `TextKit2FoundationTests.swift`:

```swift
@Test("Code block lines get syntax-highlighted attributes")
func codeBlockHighlighting() {
    let delegate = MarkdownContentStorage()
    delegate.theme = .light

    let text = "# Title\n```swift\nlet x = 42\n```\nBody"
    delegate.reparse(text: text)

    // Line 2 (index 2) should be code with language swift (id=1)
    let types = delegate.cachedTypesForTesting
    #expect(types[1].paraType == 6) // code block (fence open)
    #expect(types[1].metadata & 0xFF == 1) // swift
    #expect(types[2].paraType == 6) // code body
    #expect(types[2].metadata & 0xFF == 1) // swift
}
```

**Step 2: Expose cachedTypes for testing**

Add to `MarkdownContentStorage`:

```swift
#if DEBUG
var cachedTypesForTesting: [(paraType: UInt8, metadata: UInt16)] { cachedTypes }
#endif
```

**Step 3: Implement code token coloring in delegate**

In `MarkdownContentStorage.swift`, modify the `textContentStorage(_:textParagraphWith:)` method. Where it currently skips inline styles for code blocks (around line 148-150):

Before:
```swift
    let isActive = (activeLine == line)
    if entry.paraType != 6 && entry.paraType != 8 && entry.paraType != 9 {
        applyInlineStyles(to: styled, fullRange: fullRange, isActive: isActive)
    }
```

After:
```swift
    let isActive = (activeLine == line)
    if entry.paraType == 6 {
        // Code block — apply syntax highlighting via tree-sitter
        let languageId = entry.metadata & 0xFF
        if languageId > 0 {
            applyCodeTokenStyles(to: styled, range: fullRange, languageId: UInt8(languageId))
        }
    } else if entry.paraType != 8 && entry.paraType != 9 {
        applyInlineStyles(to: styled, fullRange: fullRange, isActive: isActive)
    }
```

Add the new method to `MarkdownContentStorage`:

```swift
/// Apply syntax highlighting to a code block line via tree-sitter FFI.
private func applyCodeTokenStyles(
    to attrStr: NSMutableAttributedString,
    range: NSRange,
    languageId: UInt8
) {
    let text = attrStr.string
    guard !text.isEmpty else { return }

    // Map language ID to tag string for FFI
    let langTag: String
    switch languageId {
    case 1: langTag = "swift"
    case 2: langTag = "rust"
    case 3: langTag = "python"
    case 4: langTag = "javascript"
    case 5: langTag = "typescript"
    case 6: langTag = "json"
    case 7: langTag = "html"
    case 8: langTag = "css"
    case 9: langTag = "bash"
    case 10: langTag = "go"
    case 11: langTag = "c"
    case 12: langTag = "cpp"
    default: return
    }

    // Call Rust FFI
    let maxTokens: UInt32 = 4096
    let buffer = UnsafeMutablePointer<CodeToken>.allocate(capacity: Int(maxTokens))
    defer { buffer.deallocate() }

    let utf8Data = text.utf8
    let count: UInt32 = text.withCString { codePtr in
        langTag.withCString { langPtr in
            markdown_parse_code_tokens(
                codePtr,
                UInt32(utf8Data.count),
                langPtr,
                buffer,
                maxTokens
            )
        }
    }

    guard count > 0 else { return }

    // Build UTF-8 → UTF-16 offset map for this line
    let utf8ToUtf16 = buildUtf8ToUtf16Map(text)

    for i in 0..<Int(count) {
        let token = buffer[i]
        let startByte = Int(token.start)
        let endByte = Int(token.end)
        guard startByte < utf8ToUtf16.count, endByte <= utf8ToUtf16.count else { continue }

        let utf16Start = utf8ToUtf16[startByte]
        let utf16End = endByte < utf8ToUtf16.count ? utf8ToUtf16[endByte] : utf8ToUtf16.last ?? 0
        let length = utf16End - utf16Start
        guard length > 0 else { continue }

        let tokenRange = NSRange(
            location: range.location + utf16Start,
            length: length
        )
        guard NSMaxRange(tokenRange) <= NSMaxRange(range) else { continue }

        let color = theme.nsColorForTokenType(token.token_type)
        attrStr.addAttribute(.foregroundColor, value: color, range: tokenRange)

        // Italic for comments
        if token.token_type == 3 {
            if let currentFont = attrStr.attribute(.font, at: tokenRange.location, effectiveRange: nil) as? NSFont {
                let italic = NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
                attrStr.addAttribute(.font, value: italic, range: tokenRange)
            }
        }
    }
}
```

**Step 4: Build and run tests**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "Code block|MarkdownContent" | head -20`
Expected: Tests PASS

Also run Rust tests: `cd graph-engine && cargo test 2>&1 | tail -5`
Expected: All PASS

**Step 5: Commit**

```bash
git add Epistemos/Views/Notes/MarkdownContentStorage.swift
git add EpistemosTests/TextKit2FoundationTests.swift
git commit -m "feat: wire tree-sitter code token colors into MarkdownContentStorage delegate"
```

---

## Sub-Phase 6c: Fragment Cache + Viewport Gating

### Task 9: Viewport-Gated Code Tokenization

**Files:**
- Modify: `Epistemos/Views/Notes/MarkdownContentStorage.swift`
- Modify: `Epistemos/Views/Notes/ProseTextView2.swift`

Code blocks outside the viewport (and near-viewport buffer) should NOT be tokenized. They get plain monospace. When they scroll into view, TK2 naturally re-calls the delegate.

**Step 1: Add viewport range tracking**

In `MarkdownContentStorage.swift`, add a property:

```swift
/// Visible line range, updated by ProseTextView2 on scroll/layout.
/// Code blocks outside this range + buffer skip tokenization.
var visibleLineRange: Range<Int> = 0..<0
private let viewportBuffer = 50 // lines beyond visible range to pre-tokenize
```

**Step 2: Gate tokenization on viewport**

In `applyCodeTokenStyles`, add a viewport check at the top. The caller (the delegate method) already knows the line index. Thread the line index through:

Change the delegate call from:
```swift
applyCodeTokenStyles(to: styled, range: fullRange, languageId: UInt8(languageId))
```
To:
```swift
applyCodeTokenStyles(to: styled, range: fullRange, languageId: UInt8(languageId), line: line)
```

Add viewport check to `applyCodeTokenStyles`:
```swift
private func applyCodeTokenStyles(
    to attrStr: NSMutableAttributedString,
    range: NSRange,
    languageId: UInt8,
    line: Int
) {
    // Viewport gate: skip tokenization for off-screen code blocks
    let bufferedRange = max(0, visibleLineRange.lowerBound - viewportBuffer)
        ..< (visibleLineRange.upperBound + viewportBuffer)
    guard bufferedRange.contains(line) else { return }

    // ... rest of implementation
}
```

**Step 3: Wire viewport updates from ProseTextView2**

In `ProseTextView2.swift`, add a method that updates the delegate's visible range. Call it from `viewDidMoveToWindow()`, `boundsDidChange`, and after reparse:

```swift
func updateVisibleLineRange() {
    guard let tlm = textLayoutManager,
          let contentStorage = tlm.textContentManager as? NSTextContentStorage else { return }
    let visibleRect = enclosingScrollView?.documentVisibleRect ?? bounds

    // Find first visible line
    let startPoint = CGPoint(x: 0, y: max(visibleRect.minY - textContainerOrigin.y, 0))
    let endPoint = CGPoint(x: 0, y: visibleRect.maxY - textContainerOrigin.y)

    var startLine = 0
    var endLine = markdownDelegate.lineCount

    if let startFrag = tlm.textLayoutFragment(for: startPoint),
       let startRange = startFrag.rangeInElement {
        let offset = contentStorage.offset(from: tlm.documentRange.location, to: startRange.location)
        startLine = markdownDelegate.lineIndex(at: offset)
    }

    if let endFrag = tlm.textLayoutFragment(for: endPoint),
       let endRange = endFrag.rangeInElement {
        let offset = contentStorage.offset(from: tlm.documentRange.location, to: endRange.location)
        endLine = markdownDelegate.lineIndex(at: offset)
    }

    markdownDelegate.visibleLineRange = startLine..<(endLine + 1)
}
```

Register for scroll notifications in `makeTextKit2()` or in the setup:

```swift
// In makeTextKit2(), after setting up the text view:
NotificationCenter.default.addObserver(
    forName: NSView.boundsDidChangeNotification,
    object: scrollView.contentView,
    queue: .main
) { [weak tv] _ in
    tv?.updateVisibleLineRange()
}
```

**Step 4: Build and verify**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add Epistemos/Views/Notes/MarkdownContentStorage.swift
git add Epistemos/Views/Notes/ProseTextView2.swift
git commit -m "feat: viewport-gated code tokenization (skip off-screen blocks)"
```

---

### Task 10: Per-Paragraph Token Cache

**Files:**
- Modify: `Epistemos/Views/Notes/MarkdownContentStorage.swift`

Cache tokenized results so scrolling through already-seen code blocks is free.

**Step 1: Add cache data structure**

Add to `MarkdownContentStorage`:

```swift
/// Cache for tokenized code block results.
/// Key: hash of (line_text, theme, language_id). Value: attributed string colors.
private var tokenCache: [UInt64: [CodeTokenBridge]] = [:]
private let maxCacheEntries = 256

private func tokenCacheKey(text: String, languageId: UInt8) -> UInt64 {
    var hasher = Hasher()
    hasher.combine(text)
    hasher.combine(theme.rawValue)
    hasher.combine(languageId)
    return UInt64(bitPattern: Int64(hasher.finalize()))
}
```

**Step 2: Use cache in applyCodeTokenStyles**

Wrap the FFI call with cache check:

```swift
private func applyCodeTokenStyles(
    to attrStr: NSMutableAttributedString,
    range: NSRange,
    languageId: UInt8,
    line: Int
) {
    // Viewport gate
    let bufferedRange = max(0, visibleLineRange.lowerBound - viewportBuffer)
        ..< (visibleLineRange.upperBound + viewportBuffer)
    guard bufferedRange.contains(line) else { return }

    let text = attrStr.string
    guard !text.isEmpty else { return }

    let cacheKey = tokenCacheKey(text: text, languageId: languageId)

    // Check cache
    if let cached = tokenCache[cacheKey] {
        applyTokenColors(cached, to: attrStr, range: range)
        return
    }

    // Cache miss — tokenize via FFI
    let tokens = tokenizeViaFFI(text: text, languageId: languageId)
    guard !tokens.isEmpty else { return }

    // Store in cache (with eviction)
    if tokenCache.count >= maxCacheEntries {
        tokenCache.removeAll(keepingCapacity: true)
    }
    tokenCache[cacheKey] = tokens

    applyTokenColors(tokens, to: attrStr, range: range)
}
```

Extract the FFI call and color application into helper methods:

```swift
private func tokenizeViaFFI(text: String, languageId: UInt8) -> [CodeTokenBridge] {
    let langTag: String
    switch languageId {
    case 1: langTag = "swift"
    case 2: langTag = "rust"
    case 3: langTag = "python"
    case 4: langTag = "javascript"
    case 5: langTag = "typescript"
    case 6: langTag = "json"
    case 7: langTag = "html"
    case 8: langTag = "css"
    case 9: langTag = "bash"
    case 10: langTag = "go"
    case 11: langTag = "c"
    case 12: langTag = "cpp"
    default: return []
    }

    let maxTokens: UInt32 = 4096
    let buffer = UnsafeMutablePointer<CodeToken>.allocate(capacity: Int(maxTokens))
    defer { buffer.deallocate() }

    let utf8Data = Array(text.utf8)
    let count: UInt32 = utf8Data.withUnsafeBufferPointer { utf8Buf in
        langTag.withCString { langPtr in
            markdown_parse_code_tokens(
                UnsafeRawPointer(utf8Buf.baseAddress!).assumingMemoryBound(to: CChar.self),
                UInt32(utf8Buf.count),
                langPtr,
                buffer,
                maxTokens
            )
        }
    }

    guard count > 0 else { return [] }

    let utf8ToUtf16 = buildUtf8ToUtf16Map(text)
    var tokens: [CodeTokenBridge] = []
    tokens.reserveCapacity(Int(count))

    for i in 0..<Int(count) {
        let raw = buffer[i]
        let startByte = Int(raw.start)
        let endByte = Int(raw.end)
        guard startByte < utf8ToUtf16.count, endByte <= utf8ToUtf16.count else { continue }
        let utf16Start = utf8ToUtf16[startByte]
        let utf16End = endByte < utf8ToUtf16.count ? utf8ToUtf16[endByte] : utf8ToUtf16.last ?? 0
        guard utf16End > utf16Start else { continue }
        tokens.append(CodeTokenBridge(start: utf16Start, end: utf16End, tokenType: raw.token_type))
    }

    return tokens
}

private func applyTokenColors(
    _ tokens: [CodeTokenBridge],
    to attrStr: NSMutableAttributedString,
    range: NSRange
) {
    for token in tokens {
        let tokenRange = NSRange(
            location: range.location + token.start,
            length: token.end - token.start
        )
        guard NSMaxRange(tokenRange) <= NSMaxRange(range) else { continue }

        let color = theme.nsColorForTokenType(token.tokenType)
        attrStr.addAttribute(.foregroundColor, value: color, range: tokenRange)

        // Italic for comments
        if token.tokenType == 3 {
            if let currentFont = attrStr.attribute(.font, at: tokenRange.location, effectiveRange: nil) as? NSFont {
                let italic = NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
                attrStr.addAttribute(.font, value: italic, range: tokenRange)
            }
        }
    }
}
```

**Step 3: Clear cache on theme change and reparse**

In `reparse(text:)`, add: `tokenCache.removeAll(keepingCapacity: true)`

Add a theme observer. When `theme` is set:
```swift
var theme: EpistemosTheme = .light {
    didSet {
        if oldValue != theme {
            tokenCache.removeAll(keepingCapacity: true)
        }
    }
}
```

**Step 4: Build and run tests**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | tail -10`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add Epistemos/Views/Notes/MarkdownContentStorage.swift
git commit -m "feat: per-paragraph token cache with theme-aware invalidation"
```

---

## Sub-Phase 6d: Non-Destructive Folding

### Task 11: Fold State in Rust

**Files:**
- Modify: `graph-engine/src/markdown.rs`
- Modify: `graph-engine-bridge/graph_engine.h`

**Step 1: Write the failing test**

Add to `code_highlight_tests` in `markdown.rs`:

```rust
#[test]
fn fold_state_set_and_query() {
    // Reset global fold state
    clear_all_folds();

    set_fold(2, true);
    assert!(is_folded(2));
    assert!(!is_folded(0));
    assert!(!is_folded(5));

    set_fold(2, false);
    assert!(!is_folded(2));
}

#[test]
fn fold_range_for_heading() {
    let text = "# Title\nBody 1\nBody 2\n## Section\nMore text";
    let spans = parse_structure(text);
    // Title is line 0 (heading level 1)
    // Fold range should be lines 1-2 (stops at ## Section which is level 2 <= 1)
    let (start, end) = fold_range_for_heading(0, &spans).unwrap();
    assert_eq!(start, 1);
    assert_eq!(end, 3); // exclusive: lines 1,2 (stops before line 3 which is heading)
}

#[test]
fn fold_range_at_end_of_document() {
    let text = "## Section\nLine 1\nLine 2";
    let spans = parse_structure(text);
    let (start, end) = fold_range_for_heading(0, &spans).unwrap();
    assert_eq!(start, 1);
    assert_eq!(end, 3); // to end of document
}

#[test]
fn fold_range_non_heading_returns_none() {
    let text = "Just body text";
    let spans = parse_structure(text);
    assert!(fold_range_for_heading(0, &spans).is_none());
}
```

**Step 2: Run tests to verify they fail**

Run: `cd graph-engine && cargo test fold_state 2>&1 | tail -10`
Expected: FAIL

**Step 3: Implement fold state**

Add to `graph-engine/src/markdown.rs` after the code highlighting section:

```rust
// ── Fold State (Non-Destructive) ───────────────────────────────────────────

use std::collections::HashSet;
use parking_lot::Mutex as ParkingMutex;

/// Global fold state — set of folded heading line indices.
static FOLD_STATE: ParkingMutex<HashSet<u32>> = ParkingMutex::new(HashSet::new());

pub fn set_fold(line_index: u32, folded: bool) {
    let mut state = FOLD_STATE.lock();
    if folded {
        state.insert(line_index);
    } else {
        state.remove(&line_index);
    }
}

pub fn is_folded(line_index: u32) -> bool {
    FOLD_STATE.lock().contains(&line_index)
}

pub fn clear_all_folds() {
    FOLD_STATE.lock().clear();
}

/// Given a heading line index and structure spans, return the range of lines
/// that would be hidden when folding. Returns (start, end_exclusive).
/// Returns None if the line is not a heading.
pub fn fold_range_for_heading(
    heading_line: u32,
    spans: &[StructureSpan],
) -> Option<(u32, u32)> {
    let idx = heading_line as usize;
    if idx >= spans.len() || spans[idx].para_type != ParaType::Heading as u8 {
        return None;
    }

    let heading_level = (spans[idx].metadata & 0xFF) as u8;
    let start = heading_line + 1;
    let mut end = spans.len() as u32;

    for i in (start as usize)..spans.len() {
        if spans[i].para_type == ParaType::Heading as u8 {
            let level = (spans[i].metadata & 0xFF) as u8;
            if level <= heading_level {
                end = i as u32;
                break;
            }
        }
    }

    if start >= end {
        return None;
    }

    Some((start, end))
}
```

Add FFI entry points:

```rust
#[unsafe(no_mangle)]
pub unsafe extern "C" fn markdown_set_fold(line_index: u32, folded: bool) {
    set_fold(line_index, folded);
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn markdown_is_folded(line_index: u32) -> bool {
    is_folded(line_index)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn markdown_clear_all_folds() {
    clear_all_folds();
}

/// Get the fold range for a heading. Returns false if not a heading.
/// On success, writes start and end (exclusive) line indices to out pointers.
///
/// # Safety
/// `text` must be valid null-terminated UTF-8. out_start/out_end must be valid pointers.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn markdown_fold_range(
    text: *const c_char,
    heading_line: u32,
    out_start: *mut u32,
    out_end: *mut u32,
) -> bool {
    if text.is_null() || out_start.is_null() || out_end.is_null() {
        return false;
    }

    let c_str = unsafe { CStr::from_ptr(text) };
    let rust_str = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return false,
    };

    let spans = parse_structure(rust_str);
    match fold_range_for_heading(heading_line, &spans) {
        Some((start, end)) => {
            unsafe {
                *out_start = start;
                *out_end = end;
            }
            true
        }
        None => false,
    }
}
```

**Step 4: Add C header declarations**

In `graph-engine-bridge/graph_engine.h`:

```c
/// Set fold state for a heading line. folded=true to fold, false to unfold.
void markdown_set_fold(uint32_t line_index, bool folded);

/// Query whether a heading line is folded.
bool markdown_is_folded(uint32_t line_index);

/// Clear all fold state.
void markdown_clear_all_folds(void);

/// Get the line range that would be hidden when folding a heading.
/// @param text         Null-terminated UTF-8 markdown text.
/// @param heading_line Line index of the heading.
/// @param out_start    Output: first hidden line (inclusive).
/// @param out_end      Output: last hidden line (exclusive).
/// @return true if heading_line is a heading, false otherwise.
bool markdown_fold_range(
    const char* text,
    uint32_t heading_line,
    uint32_t* out_start,
    uint32_t* out_end
);
```

**Step 5: Run tests**

Run: `cd graph-engine && cargo test fold_ 2>&1 | tail -15`
Expected: ALL PASS

Run full suite: `cd graph-engine && cargo test 2>&1 | tail -5`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add graph-engine/src/markdown.rs graph-engine-bridge/graph_engine.h
git commit -m "feat: non-destructive fold state in Rust with FFI entry points"
```

---

### Task 12: shouldEnumerate Delegate for Folding

**Files:**
- Modify: `Epistemos/Views/Notes/MarkdownContentStorage.swift`
- Modify: `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`
- Test: `EpistemosTests/TextKit2FoundationTests.swift`

Replace the storage-rewriting fold mechanism with `shouldEnumerate`.

**Step 1: Write the failing test**

Add to `TextKit2FoundationTests.swift`:

```swift
@Suite("TextKit 2 - Non-Destructive Folding")
struct NonDestructiveFoldingTests {

    @Test("shouldEnumerate returns false for folded lines")
    func shouldEnumerateFolded() {
        let delegate = MarkdownContentStorage()
        let text = "# Title\nBody 1\nBody 2\n## Section"
        delegate.reparse(text: text)

        // Fold heading at line 0
        markdown_set_fold(0, true)
        defer { markdown_clear_all_folds() }

        // Lines 1 and 2 should be hidden
        #expect(delegate.isLineInFoldedRange(0) == false) // heading itself visible
        #expect(delegate.isLineInFoldedRange(1) == true)  // body 1 hidden
        #expect(delegate.isLineInFoldedRange(2) == true)  // body 2 hidden
        #expect(delegate.isLineInFoldedRange(3) == false) // next heading visible
    }
}
```

**Step 2: Run test to verify it fails**

Expected: FAIL — `isLineInFoldedRange` not defined

**Step 3: Implement shouldEnumerate**

Add `NSTextContentManagerDelegate` conformance to `MarkdownContentStorage` (it may already conform — check if it conforms to the delegate or the storage delegate):

```swift
extension MarkdownContentStorage: NSTextContentManagerDelegate {
    func textContentManager(
        _ textContentManager: NSTextContentManager,
        shouldEnumerate textElement: NSTextElement,
        options: NSTextContentManager.EnumerationOptions
    ) -> Bool {
        guard let contentStorage = textContentManager as? NSTextContentStorage,
              let range = textElement.elementRange else { return true }

        let offset = contentStorage.offset(from: contentStorage.documentRange.location, to: range.location)
        let line = lineIndex(at: offset)
        return !isLineInFoldedRange(line)
    }
}
```

Add the fold range check:

```swift
/// Check if a line falls within any folded heading's range.
func isLineInFoldedRange(_ line: Int) -> Bool {
    // Check each folded heading
    for i in 0..<cachedTypes.count {
        guard cachedTypes[i].paraType == 1, // Heading
              markdown_is_folded(UInt32(i)) else { continue }

        // Get fold range for this heading
        var start: UInt32 = 0
        var end: UInt32 = 0
        // We need the full text to compute fold range — use cached line starts
        // Actually, the Rust side needs the text. Store it or use a different approach.
        // Simpler: maintain a Swift-side fold range cache.
        if foldedRanges[i] == nil {
            // Compute and cache
            // This requires access to the document text...
        }

        if let range = foldedRanges[i], range.contains(UInt32(line)) {
            return true
        }
    }
    return false
}
```

Actually, the cleaner approach: maintain a `Set<Int>` of hidden line indices on the Swift side, computed when fold state changes:

```swift
/// Lines currently hidden by folds. Recomputed on fold toggle.
private(set) var hiddenLines: Set<Int> = []

/// Recompute hidden lines from Rust fold state.
/// Call after any fold toggle.
func recomputeHiddenLines(documentText: String) {
    hiddenLines.removeAll()

    documentText.withCString { cStr in
        for i in 0..<cachedTypes.count {
            guard cachedTypes[i].paraType == 1, // Heading
                  markdown_is_folded(UInt32(i)) else { continue }

            var start: UInt32 = 0
            var end: UInt32 = 0
            if markdown_fold_range(cStr, UInt32(i), &start, &end) {
                for line in Int(start)..<Int(end) {
                    hiddenLines.insert(line)
                }
            }
        }
    }
}

func isLineInFoldedRange(_ line: Int) -> Bool {
    hiddenLines.contains(line)
}
```

Wire `shouldEnumerate`:

```swift
func textContentManager(
    _ textContentManager: NSTextContentManager,
    shouldEnumerate textElement: NSTextElement,
    options: NSTextContentManager.EnumerationOptions
) -> Bool {
    guard !hiddenLines.isEmpty else { return true }
    guard let contentStorage = textContentManager as? NSTextContentStorage,
          let range = textElement.elementRange else { return true }

    let offset = contentStorage.offset(
        from: contentStorage.documentRange.location,
        to: range.location
    )
    let line = lineIndex(at: offset)
    return !hiddenLines.contains(line)
}
```

**Step 4: Replace fold logic in Coordinator2**

In `ProseEditorRepresentable2.swift`, replace the storage-rewriting `toggleFold` with delegate-based folding:

```swift
func toggleFold(headingOffset: Int) {
    guard let tv = textView else { return }
    let delegate = tv.markdownDelegate

    // Find line index for this heading offset
    let line = delegate.lineIndex(at: headingOffset)
    let isFolded = markdown_is_folded(UInt32(line))

    // Toggle
    markdown_set_fold(UInt32(line), !isFolded)

    // Recompute hidden lines
    delegate.recomputeHiddenLines(documentText: tv.string)

    // Invalidate layout for the fold range
    if let contentStorage = tv.textLayoutManager?.textContentManager as? NSTextContentStorage {
        // Force re-enumeration by processing an editing transaction
        contentStorage.performEditingTransaction {
            // No actual edit — just trigger re-enumeration
        }
        tv.textLayoutManager?.ensureLayout(for: tv.textLayoutManager!.documentRange)
    }

    tv.needsDisplay = true
}
```

Remove `foldedSections`, `FoldInfo`, `isFolding`, `clearAllFolds()`, `unfold()` from Coordinator2.

Update `clearAllFolds` to use the new mechanism:

```swift
func clearAllFolds() {
    guard let tv = textView else { return }
    markdown_clear_all_folds()
    tv.markdownDelegate.recomputeHiddenLines(documentText: tv.string)
    if let contentStorage = tv.textLayoutManager?.textContentManager as? NSTextContentStorage {
        contentStorage.performEditingTransaction { }
    }
    tv.needsDisplay = true
}
```

Remove the fold-related guards from `textDidChange` (the `if !foldedSections.isEmpty { clearAllFolds() }` pattern). Folds no longer conflict with editing because they don't modify storage.

**Step 5: Wire NSTextContentManagerDelegate**

In `ProseTextView2.makeTextKit2()`, ensure the delegate is set for BOTH roles:

```swift
if let contentStorage = tv.textLayoutManager?.textContentManager
    as? NSTextContentStorage {
    contentStorage.delegate = tv.markdownDelegate          // NSTextContentStorageDelegate
    contentStorage.primaryTextLayoutManager?.textContentManager?.delegate = tv.markdownDelegate  // NSTextContentManagerDelegate
}
```

Note: `NSTextContentStorageDelegate` and `NSTextContentManagerDelegate` are different protocols. `MarkdownContentStorage` already conforms to the storage delegate. We add content manager delegate conformance for `shouldEnumerate`. Check if both delegate properties point to the same object or if there are separate delegate slots.

**Step 6: Run tests**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "fold|Fold" | head -20`
Expected: Tests PASS

**Step 7: Commit**

```bash
git add Epistemos/Views/Notes/MarkdownContentStorage.swift
git add Epistemos/Views/Notes/ProseEditorRepresentable2.swift
git add EpistemosTests/TextKit2FoundationTests.swift
git commit -m "feat: non-destructive folding via shouldEnumerate delegate"
```

---

## Final Verification

### Task 13: Full Build + Test Suite

**Step 1: Run Swift build**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 2: Run Swift tests**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | tail -20`
Expected: All tests PASS (including all pre-existing tests)

**Step 3: Run Rust tests**

Run: `cd graph-engine && cargo test 2>&1 | tail -10`
Expected: All tests PASS (549 pre-existing + ~20 new)

**Step 4: Verify no regressions in existing TK2 behavior**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test 2>&1 | grep -E "FAIL|error" | head -20`
Expected: No failures

**Step 5: Commit summary**

```bash
git log --oneline -12
```

Expected commits (newest first):
```
feat: non-destructive folding via shouldEnumerate delegate
feat: non-destructive fold state in Rust with FFI entry points
feat: per-paragraph token cache with theme-aware invalidation
feat: viewport-gated code tokenization (skip off-screen blocks)
feat: wire tree-sitter code token colors into MarkdownContentStorage delegate
feat: MarkdownLayoutFragment subclass for code block rendering
feat: code token color palette for syntax highlighting
feat: markdown_parse_code_tokens FFI entry point
feat: tree-sitter code tokenizer with per-block cache
feat: propagate language tag in structure parser metadata
feat: CodeToken struct + language ID mapping for code highlighting
chore: add tree-sitter + language grammar dependencies
```
