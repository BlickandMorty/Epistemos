//! AST quality gate — Deterministic Schema Engine, P8.2 spec §A
//! (docs/DETERMINISTIC_SCHEMA_ENGINE_SPEC_2026_06_18.md).
//!
//! "A local tool's output is validated … via an AST quality gate BEFORE any disk write
//! or compile loop runs." This is that gate at the syntax layer: parse a local model's
//! generated CODE with tree-sitter and reject it if the tree contains ERROR / MISSING
//! nodes — so a syntactically-broken generation never reaches disk (the caller can feed
//! a repair loop instead of corrupting the workspace).
//!
//! Feature-gated behind `lsp-runtime`, where the tree-sitter grammars already live
//! (this reuses the SAME grammars the in-process LSP runtime uses — no new deps).
//! Pure + deterministic + unit-tested.

use tree_sitter::Parser;

/// The languages the gate can parse (the grammars the product already vendors).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GateLanguage {
    Rust,
    Swift,
}

/// Outcome of the parse gate.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ParseGateOutcome {
    /// `true` iff the code parsed with NO tree-sitter ERROR / MISSING nodes.
    pub parses_cleanly: bool,
}

/// Parse `code` as `language` and report whether it is syntactically clean. Returns
/// `None` only if the parser itself could not be constructed (a never-expected internal
/// failure) — `passes_gate` treats that conservatively as "not clean".
pub fn parse_gate(code: &str, language: GateLanguage) -> Option<ParseGateOutcome> {
    let mut parser = Parser::new();
    let grammar = match language {
        GateLanguage::Rust => tree_sitter_rust::LANGUAGE.into(),
        GateLanguage::Swift => tree_sitter_swift::LANGUAGE.into(),
    };
    parser.set_language(&grammar).ok()?;
    let tree = parser.parse(code, None)?;
    Some(ParseGateOutcome {
        parses_cleanly: !tree.root_node().has_error(),
    })
}

/// Did the generated code pass the gate (parse cleanly)? A parser-construction failure
/// is conservatively treated as NOT clean — never write code the gate couldn't validate.
pub fn passes_gate(code: &str, language: GateLanguage) -> bool {
    parse_gate(code, language).is_some_and(|o| o.parses_cleanly)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn clean_rust_passes() {
        assert!(passes_gate(
            "fn main() {\n    let x = 1 + 2;\n    let _ = x;\n}",
            GateLanguage::Rust
        ));
    }

    #[test]
    fn broken_rust_is_rejected() {
        // an unterminated expression + missing brace → ERROR/MISSING nodes
        assert!(!passes_gate("fn main() { let x = ", GateLanguage::Rust));
    }

    #[test]
    fn clean_swift_passes() {
        assert!(passes_gate(
            "let x = 1\nfunc greet() -> String { return \"hi\" }",
            GateLanguage::Swift
        ));
    }

    #[test]
    fn broken_swift_is_rejected() {
        assert!(!passes_gate("func greet( {", GateLanguage::Swift));
    }

    #[test]
    fn outcome_reports_cleanliness_both_ways() {
        let ok = parse_gate("fn a() {}", GateLanguage::Rust).expect("parser builds");
        assert!(ok.parses_cleanly);
        let bad = parse_gate("fn a( {", GateLanguage::Rust).expect("parser builds");
        assert!(!bad.parses_cleanly);
    }
}
