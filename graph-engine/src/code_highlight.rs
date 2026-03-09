// tree-sitter tokenizer core.
//
// Takes (language_tag, code_text) and returns Vec<CodeToken> by walking
// the tree-sitter syntax tree depth-first. Leaf nodes are classified into
// TokenType variants for Swift-side code block rendering.

use crate::markdown::{CodeToken, TokenType};
use parking_lot::Mutex;
use std::collections::HashMap;
use std::hash::{BuildHasherDefault, Hash, Hasher};
use rustc_hash::FxHasher;
use tree_sitter_language::LanguageFn;

// ── Tree cache ──────────────────────────────────────────────────────────────

const MAX_CACHE_ENTRIES: usize = 128;

type FxBuildHasher = BuildHasherDefault<FxHasher>;

static TREE_CACHE: Mutex<Option<HashMap<u64, tree_sitter::Tree, FxBuildHasher>>> =
    Mutex::new(None);

fn cache_key(lang: &str, code: &str) -> u64 {
    let mut h = FxHasher::default();
    lang.hash(&mut h);
    code.hash(&mut h);
    h.finish()
}

fn cache_get(key: u64) -> Option<tree_sitter::Tree> {
    let guard = TREE_CACHE.lock();
    guard.as_ref().and_then(|m| m.get(&key).cloned())
}

fn cache_put(key: u64, tree: tree_sitter::Tree) {
    let mut guard = TREE_CACHE.lock();
    let map = guard.get_or_insert_with(|| HashMap::with_hasher(FxBuildHasher::default()));
    if map.len() >= MAX_CACHE_ENTRIES {
        map.clear();
    }
    map.insert(key, tree);
}

// ── Language lookup ─────────────────────────────────────────────────────────

fn language_fn_for_tag(lang: &str) -> Option<LanguageFn> {
    match lang.to_ascii_lowercase().as_str() {
        "swift" => Some(tree_sitter_swift::LANGUAGE),
        "rust" | "rs" => Some(tree_sitter_rust::LANGUAGE),
        "python" | "py" => Some(tree_sitter_python::LANGUAGE),
        "javascript" | "js" | "jsx" => Some(tree_sitter_javascript::LANGUAGE),
        "typescript" | "ts" => Some(tree_sitter_typescript::LANGUAGE_TYPESCRIPT),
        "tsx" => Some(tree_sitter_typescript::LANGUAGE_TSX),
        "json" => Some(tree_sitter_json::LANGUAGE),
        "html" | "htm" => Some(tree_sitter_html::LANGUAGE),
        "css" | "scss" | "less" => Some(tree_sitter_css::LANGUAGE),
        "bash" | "sh" | "shell" | "zsh" => Some(tree_sitter_bash::LANGUAGE),
        "go" | "golang" => Some(tree_sitter_go::LANGUAGE),
        "c" | "h" => Some(tree_sitter_c::LANGUAGE),
        "cpp" | "c++" | "cc" | "cxx" | "hpp" => Some(tree_sitter_cpp::LANGUAGE),
        _ => None,
    }
}

// ── Node classification ─────────────────────────────────────────────────────

fn is_keyword(kind: &str) -> bool {
    matches!(
        kind,
        "fn" | "func" | "function"
            | "let" | "var" | "const" | "val"
            | "if" | "else" | "elif"
            | "for" | "while" | "loop" | "do"
            | "return" | "yield" | "break" | "continue"
            | "switch" | "case" | "default" | "match"
            | "struct" | "class" | "enum" | "protocol" | "interface" | "trait" | "impl"
            | "import" | "from" | "use" | "module" | "package"
            | "pub" | "public" | "private" | "protected" | "internal" | "open" | "fileprivate"
            | "static" | "final" | "override" | "mutating" | "nonmutating"
            | "async" | "await" | "throws" | "throw" | "try" | "catch" | "finally"
            | "guard" | "defer" | "where" | "in" | "as" | "is"
            | "new" | "delete" | "typeof" | "instanceof" | "void"
            | "self" | "super" | "Self"
            | "type" | "typealias" | "extension" | "associatedtype"
            | "with" | "pass" | "raise" | "except" | "lambda" | "def"
            | "not" | "and" | "or"
            | "go" | "chan" | "select" | "range" | "map"
            | "export" | "require"
            | "unsafe" | "extern" | "crate" | "mod" | "ref" | "move"
            | "mut" | "dyn"
    )
}

fn is_constant(kind: &str) -> bool {
    matches!(kind, "true" | "false" | "nil" | "null" | "None" | "True" | "False")
}

fn is_operator(kind: &str) -> bool {
    matches!(
        kind,
        "=" | "+" | "-" | "*" | "/" | "%" | "==" | "!=" | "<" | ">" | "<=" | ">="
            | "&&" | "||" | "!" | "&" | "|" | "^" | "~" | "<<" | ">>" | "+=" | "-="
            | "*=" | "/=" | "%=" | "&=" | "|=" | "^=" | "<<=" | ">>="
            | "=>" | "->" | ".." | "..=" | "??" | "?." | "?:" | "::"
    )
}

fn is_punctuation(kind: &str) -> bool {
    matches!(
        kind,
        "(" | ")" | "{" | "}" | "[" | "]" | ";" | "," | "." | ":" | "..."
    )
}

fn classify_node(node: tree_sitter::Node, code: &str) -> TokenType {
    let kind = node.kind();

    // Comments
    if kind.contains("comment") {
        return TokenType::Comment;
    }

    // Strings (including content fragments)
    if kind.contains("string") {
        return TokenType::String;
    }

    // Template/interpolation literals
    if kind.contains("template") {
        return TokenType::String;
    }

    // Numbers
    if kind.contains("integer") || kind.contains("float") || kind.contains("number") {
        return TokenType::Number;
    }

    // Tags (HTML/JSX)
    if kind == "tag_name" {
        return TokenType::Tag;
    }

    // Attributes (HTML/JSX)
    if kind == "attribute_name" {
        return TokenType::Attribute;
    }

    // Type identifiers
    if kind == "type_identifier" || kind == "primitive_type" || kind == "builtin_type" {
        return TokenType::Type;
    }

    // Constants
    if is_constant(kind) {
        return TokenType::Constant;
    }

    // Check if the node text itself is a keyword (tree-sitter often uses
    // the keyword text as the node kind for anonymous nodes)
    if is_keyword(kind) {
        return TokenType::Keyword;
    }

    // Operators
    if is_operator(kind) {
        return TokenType::Operator;
    }

    // Punctuation
    if is_punctuation(kind) {
        return TokenType::Punctuation;
    }

    // Identifiers need parent context for classification
    if kind == "identifier" || kind == "simple_identifier" || kind == "shorthand_property_identifier" {
        if let Some(parent) = node.parent() {
            let parent_kind = parent.kind();

            // Function name: parent is function declaration/call and we are the "name" field
            if parent_kind.contains("function")
                || parent_kind.contains("call")
                || parent_kind.contains("method")
                || parent_kind == "call_expression"
                || parent_kind == "function_declaration"
                || parent_kind == "function_definition"
                || parent_kind == "simple_identifier" // Swift chain
            {
                // Check if this identifier is the function/method name
                if parent_kind.contains("call") {
                    // In call expressions, the function identifier is typically
                    // the first child or the "function" field
                    if let Some(func_node) = parent.child_by_field_name("function") {
                        if func_node.id() == node.id() || func_node.start_byte() == node.start_byte() {
                            return TokenType::Function;
                        }
                    }
                    // Also check: first named child of call_expression
                    if parent.child(0).map(|c| c.id()) == Some(node.id()) {
                        return TokenType::Function;
                    }
                }
                if let Some(name_node) = parent.child_by_field_name("name") {
                    if name_node.id() == node.id() || name_node.start_byte() == node.start_byte() {
                        return TokenType::Function;
                    }
                }
            }

            // Property access
            if let Some(field) = cursor_field_name_for_node(node, parent) {
                if field == "property" || field == "field" || field == "member" {
                    return TokenType::Property;
                }
                if field == "name" && (parent_kind.contains("type") || parent_kind.contains("class") || parent_kind.contains("struct") || parent_kind.contains("interface") || parent_kind.contains("enum")) {
                    return TokenType::Type;
                }
            }

            // Property: parent is member_expression and we are the property child
            if parent_kind == "member_expression"
                || parent_kind == "field_expression"
                || parent_kind == "navigation_expression"
            {
                if let Some(prop) = parent.child_by_field_name("property") {
                    if prop.start_byte() == node.start_byte() {
                        return TokenType::Property;
                    }
                }
                if let Some(field) = parent.child_by_field_name("field") {
                    if field.start_byte() == node.start_byte() {
                        return TokenType::Property;
                    }
                }
                // Fallback: if we are the last child of member_expression, likely property
                if parent.child_count() > 0 {
                    if let Some(last) = parent.child(parent.child_count() - 1) {
                        if last.start_byte() == node.start_byte() {
                            return TokenType::Property;
                        }
                    }
                }
            }

            // Type context
            if parent_kind.contains("type")
                || parent_kind == "class_declaration"
                || parent_kind == "struct_item"
                || parent_kind == "type_spec"
            {
                return TokenType::Type;
            }
        }

        // For identifiers that are keywords in some languages but parsed as identifiers
        let text = &code[node.start_byte()..node.end_byte()];
        if is_keyword(text) {
            return TokenType::Keyword;
        }
        if is_constant(text) {
            return TokenType::Constant;
        }

        return TokenType::Variable;
    }

    // Escape sequences in strings
    if kind == "escape_sequence" || kind == "escape" {
        return TokenType::String;
    }

    // Quote characters for strings
    if kind == "\"" || kind == "'" || kind == "`" {
        return TokenType::String;
    }

    TokenType::Plain
}

/// Walk the tree depth-first to find the field name for a given child node.
/// Uses the parent's child enumeration since the cursor API doesn't expose
/// field names for arbitrary nodes easily.
fn cursor_field_name_for_node(node: tree_sitter::Node, parent: tree_sitter::Node) -> Option<&'static str> {
    for i in 0..parent.child_count() {
        if let Some(child) = parent.child(i) {
            if child.id() == node.id() {
                return parent.field_name_for_child(i as u32);
            }
        }
    }
    None
}

// ── Public API ──────────────────────────────────────────────────────────────

/// Tokenize a code block for syntax highlighting.
///
/// Returns a sorted Vec of CodeToken spans. Returns empty vec for unknown
/// languages or empty input.
pub fn tokenize(lang: &str, code: &str) -> Vec<CodeToken> {
    if code.is_empty() {
        return Vec::new();
    }

    let lang_fn = match language_fn_for_tag(lang) {
        Some(lf) => lf,
        None => return Vec::new(),
    };

    let ts_lang: tree_sitter::Language = lang_fn.into();
    let code_hash = cache_key(lang, code);

    // Try cache first
    let tree = if let Some(cached) = cache_get(code_hash) {
        cached
    } else {
        let mut parser = tree_sitter::Parser::new();
        parser.set_language(&ts_lang).expect("language load failed");
        let tree = match parser.parse(code, None) {
            Some(t) => t,
            None => return Vec::new(),
        };
        cache_put(code_hash, tree.clone());
        tree
    };

    // Walk the tree depth-first, collect leaf tokens.
    // Special handling: comment and string nodes are emitted as single tokens
    // covering their full range, skipping child descent (their children are
    // just punctuation fragments like "//" or quote chars).
    let mut tokens = Vec::with_capacity(code.len() / 4);
    let mut cursor = tree.walk();
    let mut did_visit_children = false;

    loop {
        let node = cursor.node();

        if !did_visit_children {
            let kind = node.kind();
            let start = node.start_byte();
            let end = node.end_byte();
            let valid_range = start < end && end <= code.len();

            // Coalesce: named comment/string nodes emit one token, skip children
            let is_coalesced = node.is_named()
                && (kind.contains("comment") || kind.contains("string_literal")
                    || kind == "raw_string_literal" || kind == "string");

            if is_coalesced && valid_range {
                let tt = classify_node(node, code);
                tokens.push(CodeToken {
                    start: start as u32,
                    end: end as u32,
                    token_type: tt as u8,
                    _pad: [0; 3],
                });
                // Skip children — treat as leaf
                did_visit_children = true;
            } else if node.child_count() == 0 && valid_range {
                let tt = classify_node(node, code);
                tokens.push(CodeToken {
                    start: start as u32,
                    end: end as u32,
                    token_type: tt as u8,
                    _pad: [0; 3],
                });
            }
        }

        // Depth-first traversal
        if !did_visit_children && cursor.goto_first_child() {
            did_visit_children = false;
        } else if cursor.goto_next_sibling() {
            did_visit_children = false;
        } else if cursor.goto_parent() {
            did_visit_children = true;
        } else {
            break;
        }
    }

    // Sort by start offset, dedup overlapping ranges
    tokens.sort_by_key(|t| (t.start, t.end));
    tokens.dedup_by(|b, a| a.start == b.start && a.end == b.end);

    tokens
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::markdown::TokenType;

    fn has_token_type(tokens: &[CodeToken], tt: TokenType) -> bool {
        tokens.iter().any(|t| t.token_type == tt as u8)
    }

    fn tokens_of_type(tokens: &[CodeToken], tt: TokenType) -> Vec<&CodeToken> {
        tokens.iter().filter(|t| t.token_type == tt as u8).collect()
    }

    fn token_text<'a>(token: &CodeToken, code: &'a str) -> &'a str {
        &code[token.start as usize..token.end as usize]
    }

    #[test]
    fn tokenize_swift_let_binding() {
        let code = "let x = 42";
        let tokens = tokenize("swift", code);
        assert!(!tokens.is_empty());
        let keywords = tokens_of_type(&tokens, TokenType::Keyword);
        let texts: Vec<&str> = keywords.iter().map(|t| token_text(t, code)).collect();
        assert!(texts.contains(&"let"), "expected 'let' keyword, got: {:?}", texts);
    }

    #[test]
    fn tokenize_rust_fn() {
        let code = "fn main() {}";
        let tokens = tokenize("rust", code);
        assert!(!tokens.is_empty());
        let keywords = tokens_of_type(&tokens, TokenType::Keyword);
        let texts: Vec<&str> = keywords.iter().map(|t| token_text(t, code)).collect();
        assert!(texts.contains(&"fn"), "expected 'fn' keyword, got: {:?}", texts);
    }

    #[test]
    fn tokenize_python_string() {
        let code = r#"x = "hello world""#;
        let tokens = tokenize("python", code);
        assert!(!tokens.is_empty());
        assert!(has_token_type(&tokens, TokenType::String),
            "expected string token, got types: {:?}",
            tokens.iter().map(|t| (token_text(t, code), t.token_type)).collect::<Vec<_>>());
    }

    #[test]
    fn tokenize_unknown_language_returns_empty() {
        let tokens = tokenize("brainfuck", "+++[>+++<-]");
        assert!(tokens.is_empty());
    }

    #[test]
    fn tokenize_empty_code() {
        let tokens = tokenize("rust", "");
        assert!(tokens.is_empty());
    }

    #[test]
    fn tokenize_javascript_function() {
        let code = "function hello() { return 1; }";
        let tokens = tokenize("javascript", code);
        assert!(!tokens.is_empty());
        let keywords = tokens_of_type(&tokens, TokenType::Keyword);
        let texts: Vec<&str> = keywords.iter().map(|t| token_text(t, code)).collect();
        assert!(texts.contains(&"function"), "expected 'function' keyword, got: {:?}", texts);
    }

    #[test]
    fn tokenize_comment() {
        let code = "// this is a comment";
        let tokens = tokenize("rust", code);
        assert!(!tokens.is_empty());
        assert!(has_token_type(&tokens, TokenType::Comment),
            "expected comment token, got: {:?}",
            tokens.iter().map(|t| (token_text(t, code), t.token_type)).collect::<Vec<_>>());
    }

    #[test]
    fn tokenize_number() {
        let code = "let x = 3.14;";
        let tokens = tokenize("rust", code);
        assert!(!tokens.is_empty());
        assert!(has_token_type(&tokens, TokenType::Number),
            "expected number token, got: {:?}",
            tokens.iter().map(|t| (token_text(t, code), t.token_type)).collect::<Vec<_>>());
    }

    #[test]
    fn tokenize_multiline_swift() {
        let code = "import Foundation\nfunc greet(_ name: String) -> String {\n    return \"Hello, \\(name)\"\n}\n";
        let tokens = tokenize("swift", code);
        assert!(tokens.len() > 5, "expected >5 tokens for multiline Swift, got {}", tokens.len());
    }

    #[test]
    fn tokenize_json() {
        let code = r#"{"key": "value", "num": 42}"#;
        let tokens = tokenize("json", code);
        assert!(!tokens.is_empty());
        assert!(has_token_type(&tokens, TokenType::String),
            "expected string token in JSON, got: {:?}",
            tokens.iter().map(|t| (token_text(t, code), t.token_type)).collect::<Vec<_>>());
    }

    // Additional correctness tests

    #[test]
    fn tokens_sorted_by_offset() {
        let code = "fn main() { let x = 42; }";
        let tokens = tokenize("rust", code);
        for w in tokens.windows(2) {
            assert!(w[0].start <= w[1].start,
                "tokens not sorted: {} > {}", w[0].start, w[1].start);
        }
    }

    #[test]
    fn no_overlapping_tokens() {
        let code = "let name: String = \"hello\"";
        let tokens = tokenize("swift", code);
        for w in tokens.windows(2) {
            assert!(w[0].end <= w[1].start || w[0].start == w[1].start,
                "overlapping tokens: [{}, {}) and [{}, {})",
                w[0].start, w[0].end, w[1].start, w[1].end);
        }
    }

    #[test]
    fn token_struct_size() {
        assert_eq!(std::mem::size_of::<CodeToken>(), 12);
    }

    #[test]
    fn all_supported_languages_parse() {
        let snippets = [
            ("swift", "let x = 1"),
            ("rust", "fn f() {}"),
            ("python", "x = 1"),
            ("javascript", "var x = 1"),
            ("typescript", "let x: number = 1"),
            ("json", "{}"),
            ("html", "<div></div>"),
            ("css", "body { color: red; }"),
            ("bash", "echo hello"),
            ("go", "package main"),
            ("c", "int main() { return 0; }"),
            ("cpp", "int main() { return 0; }"),
        ];
        for (lang, code) in snippets {
            let tokens = tokenize(lang, code);
            assert!(!tokens.is_empty(), "language '{}' produced no tokens for '{}'", lang, code);
        }
    }

    #[test]
    fn cache_returns_same_result() {
        let code = "fn cached() {}";
        let t1 = tokenize("rust", code);
        let t2 = tokenize("rust", code);
        assert_eq!(t1.len(), t2.len());
        for (a, b) in t1.iter().zip(t2.iter()) {
            assert_eq!(a.start, b.start);
            assert_eq!(a.end, b.end);
            assert_eq!(a.token_type, b.token_type);
        }
    }

    #[test]
    fn cache_key_includes_language() {
        // Same code text, different languages — must not reuse cached tree.
        // "let x = 1" is valid in both Swift and JavaScript but tree-sitter
        // parses them with different grammars producing different ASTs.
        let code = "let x = 1";
        let swift_tokens = tokenize("swift", code);
        let js_tokens = tokenize("javascript", code);
        // Both should produce tokens (neither should be empty from wrong-grammar cache hit)
        assert!(!swift_tokens.is_empty(), "Swift should produce tokens");
        assert!(!js_tokens.is_empty(), "JavaScript should produce tokens");
        // The token counts or types may differ because the grammars differ.
        // At minimum, both must independently parse (no cross-contamination).
        // Verify by checking that a second call to each still works correctly.
        let swift_tokens_2 = tokenize("swift", code);
        let js_tokens_2 = tokenize("javascript", code);
        assert_eq!(swift_tokens.len(), swift_tokens_2.len());
        assert_eq!(js_tokens.len(), js_tokens_2.len());
    }
}
