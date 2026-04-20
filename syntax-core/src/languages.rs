use tree_sitter::Language;

pub fn language_for_name(name: &str) -> Option<Language> {
    match name {
        "rust" | "rs" => Some(tree_sitter_rust::LANGUAGE.into()),
        "swift" => Some(tree_sitter_swift::LANGUAGE.into()),
        "python" | "py" => Some(tree_sitter_python::LANGUAGE.into()),
        "javascript" | "js" => Some(tree_sitter_javascript::LANGUAGE.into()),
        "typescript" | "ts" => Some(tree_sitter_typescript::LANGUAGE_TYPESCRIPT.into()),
        "tsx" => Some(tree_sitter_typescript::LANGUAGE_TSX.into()),
        "json" => Some(tree_sitter_json::LANGUAGE.into()),
        "html" => Some(tree_sitter_html::LANGUAGE.into()),
        "css" => Some(tree_sitter_css::LANGUAGE.into()),
        "bash" | "sh" | "zsh" => Some(tree_sitter_bash::LANGUAGE.into()),
        "go" => Some(tree_sitter_go::LANGUAGE.into()),
        "c" => Some(tree_sitter_c::LANGUAGE.into()),
        "cpp" | "c++" | "cc" | "cxx" => Some(tree_sitter_cpp::LANGUAGE.into()),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn known_languages_resolve() {
        assert!(language_for_name("rust").is_some());
        assert!(language_for_name("swift").is_some());
        assert!(language_for_name("python").is_some());
        assert!(language_for_name("javascript").is_some());
        assert!(language_for_name("typescript").is_some());
        assert!(language_for_name("tsx").is_some());
        assert!(language_for_name("go").is_some());
        assert!(language_for_name("c").is_some());
        assert!(language_for_name("cpp").is_some());
    }

    #[test]
    fn unknown_returns_none() {
        assert!(language_for_name("cobol").is_none());
        assert!(language_for_name("").is_none());
    }

    #[test]
    fn aliases_work() {
        assert!(language_for_name("rs").is_some());
        assert!(language_for_name("py").is_some());
        assert!(language_for_name("js").is_some());
        assert!(language_for_name("ts").is_some());
        assert!(language_for_name("sh").is_some());
        assert!(language_for_name("cc").is_some());
    }
}
