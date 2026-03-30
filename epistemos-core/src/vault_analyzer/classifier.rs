// Document classifier — classifies documents as prose/code/technical/mixed.
// Uses line-level heuristics: code fences, indentation patterns, frontmatter,
// heading density, and symbol-to-alpha ratio.

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum DocumentType {
    Prose,
    SourceCode,
    TechnicalDocs,
    MixedMedia,
}

impl DocumentType {
    pub fn as_str(&self) -> &'static str {
        match self {
            DocumentType::Prose => "prose",
            DocumentType::SourceCode => "source_code",
            DocumentType::TechnicalDocs => "technical_docs",
            DocumentType::MixedMedia => "mixed_media",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClassificationResult {
    pub doc_type: DocumentType,
    pub code_prose_ratio: f64,
    pub confidence: f64,
    pub line_count: usize,
    pub has_frontmatter: bool,
}

/// UniFFI-exported struct matching the UDL `DocumentClassification` dictionary.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DocumentClassification {
    pub doc_type: String,
    pub code_prose_ratio: f64,
    pub confidence: f64,
    pub line_count: u64,
    pub has_frontmatter: bool,
}

impl From<ClassificationResult> for DocumentClassification {
    fn from(r: ClassificationResult) -> Self {
        DocumentClassification {
            doc_type: r.doc_type.as_str().to_string(),
            code_prose_ratio: r.code_prose_ratio,
            confidence: r.confidence,
            line_count: r.line_count as u64,
            has_frontmatter: r.has_frontmatter,
        }
    }
}

/// Classify a document's content by analyzing line-level patterns.
pub fn classify_document(content: &str) -> ClassificationResult {
    let lines: Vec<&str> = content.lines().collect();
    let line_count = lines.len();

    if line_count == 0 {
        return ClassificationResult {
            doc_type: DocumentType::Prose,
            code_prose_ratio: 0.0,
            confidence: 1.0,
            line_count: 0,
            has_frontmatter: false,
        };
    }

    let has_frontmatter = detect_frontmatter(content);

    let mut code_lines = 0usize;
    let mut _prose_lines = 0usize;
    let mut heading_lines = 0usize;
    let mut blank_lines = 0usize;
    let mut in_code_fence = false;
    let mut table_lines = 0usize;

    for line in &lines {
        let trimmed = line.trim();

        if trimmed.is_empty() {
            blank_lines += 1;
            continue;
        }

        // Fenced code blocks (``` or ~~~)
        if trimmed.starts_with("```") || trimmed.starts_with("~~~") {
            in_code_fence = !in_code_fence;
            code_lines += 1;
            continue;
        }

        if in_code_fence {
            code_lines += 1;
            continue;
        }

        // Markdown headings
        if trimmed.starts_with('#') && trimmed.len() > 1 && trimmed.chars().nth(1) == Some(' ')
            || trimmed.starts_with("## ")
            || trimmed.starts_with("### ")
        {
            heading_lines += 1;
            _prose_lines += 1;
            continue;
        }

        // Markdown tables
        if trimmed.starts_with('|') && trimmed.ends_with('|') {
            table_lines += 1;
            continue;
        }

        if is_code_line(trimmed) {
            code_lines += 1;
        } else {
            _prose_lines += 1;
        }
    }

    let content_lines = line_count - blank_lines;
    let code_prose_ratio = if content_lines == 0 {
        0.0
    } else {
        code_lines as f64 / content_lines as f64
    };

    let heading_density = if content_lines == 0 {
        0.0
    } else {
        heading_lines as f64 / content_lines as f64
    };

    let table_density = if content_lines == 0 {
        0.0
    } else {
        table_lines as f64 / content_lines as f64
    };

    // Classification logic
    let (doc_type, confidence) = if code_prose_ratio >= 0.70 {
        (
            DocumentType::SourceCode,
            0.7 + (code_prose_ratio - 0.70) * 1.0,
        )
    } else if code_prose_ratio <= 0.15 && heading_density >= 0.03 {
        if table_density >= 0.10 || heading_density >= 0.10 {
            (
                DocumentType::TechnicalDocs,
                0.70 + heading_density.min(0.30),
            )
        } else {
            (DocumentType::Prose, 0.75 + (1.0 - code_prose_ratio) * 0.25)
        }
    } else if code_prose_ratio <= 0.15 {
        (DocumentType::Prose, 0.70 + (1.0 - code_prose_ratio) * 0.25)
    } else if code_prose_ratio >= 0.30 && code_prose_ratio < 0.70 {
        (
            DocumentType::MixedMedia,
            0.60 + (0.50 - (code_prose_ratio - 0.50).abs()) * 0.5,
        )
    } else {
        // 0.15..0.30 — lean prose or technical
        if heading_density >= 0.05 || has_frontmatter {
            (
                DocumentType::TechnicalDocs,
                0.55 + heading_density.min(0.30),
            )
        } else {
            (DocumentType::Prose, 0.55)
        }
    };

    let confidence = confidence.min(1.0);

    ClassificationResult {
        doc_type,
        code_prose_ratio,
        confidence,
        line_count,
        has_frontmatter,
    }
}

/// Detect YAML frontmatter delimited by `---` at the start of the document.
fn detect_frontmatter(content: &str) -> bool {
    let trimmed = content.trim_start();
    if !trimmed.starts_with("---") {
        return false;
    }
    // Find closing `---` after the opening one
    let after_open = &trimmed[3..];
    after_open.contains("\n---")
}

/// Heuristic: is this line likely code rather than prose?
fn is_code_line(line: &str) -> bool {
    let trimmed = line.trim();

    // Indented by 4+ spaces (common code indicator in markdown)
    if line.starts_with("    ") && !trimmed.starts_with('-') && !trimmed.starts_with('*') {
        return true;
    }

    // Tab-indented
    if line.starts_with('\t') {
        return true;
    }

    // Common code patterns
    let code_indicators = [
        "fn ", "pub fn", "let ", "mut ", "use ", "impl ", "struct ", "enum ", "mod ", "import ",
        "from ", "def ", "class ", "return ", "if ", "for ", "while ", "const ", "var ", "func ",
        "switch ", "case ", "guard ", "async ", "await ", "export ", "module ", "#include",
        "#define", "#pragma", "//", "/*", "*/", "///",
    ];

    for indicator in &code_indicators {
        if trimmed.starts_with(indicator) {
            return true;
        }
    }

    // High symbol density (brackets, semicolons, operators)
    let alpha_count = trimmed.chars().filter(|c| c.is_alphabetic()).count();
    let symbol_count = trimmed
        .chars()
        .filter(|c| {
            matches!(
                c,
                '{' | '}' | '(' | ')' | '[' | ']' | ';' | '=' | '<' | '>' | '&' | '|'
            )
        })
        .count();

    if alpha_count > 0 && symbol_count as f64 / alpha_count as f64 > 0.3 {
        return true;
    }

    // Lines ending with common code terminators
    if trimmed.ends_with(';') || trimmed.ends_with('{') || trimmed.ends_with('}') {
        return true;
    }

    false
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_empty() {
        let result = classify_document("");
        assert_eq!(result.doc_type, DocumentType::Prose);
        assert_eq!(result.line_count, 0);
        assert_eq!(result.confidence, 1.0);
    }

    #[test]
    fn test_pure_prose() {
        let text = "This is a simple paragraph about nature.\n\
                     The birds were singing in the morning light.\n\
                     A gentle breeze blew across the meadow.\n\
                     Children played near the old oak tree.";
        let result = classify_document(text);
        assert_eq!(result.doc_type, DocumentType::Prose);
        assert!(
            result.code_prose_ratio < 0.15,
            "Expected low code ratio, got {}",
            result.code_prose_ratio
        );
    }

    #[test]
    fn test_pure_code() {
        let code = "fn main() {\n\
                     let x = 42;\n\
                     let y = x * 2;\n\
                     println!(\"{}\", y);\n\
                     if y > 80 {\n\
                         return;\n\
                     }\n\
                     }";
        let result = classify_document(code);
        assert_eq!(result.doc_type, DocumentType::SourceCode);
        assert!(
            result.code_prose_ratio >= 0.70,
            "Expected high code ratio, got {}",
            result.code_prose_ratio
        );
    }

    #[test]
    fn test_markdown_with_code_fences() {
        let md = "# Getting Started\n\
                   \n\
                   Install the package:\n\
                   \n\
                   ```bash\n\
                   npm install my-package\n\
                   ```\n\
                   \n\
                   Then use it in your code:\n\
                   \n\
                   ```javascript\n\
                   const pkg = require('my-package');\n\
                   pkg.init();\n\
                   pkg.run();\n\
                   ```\n\
                   \n\
                   That's all you need to get started.";
        let result = classify_document(md);
        assert!(
            result.doc_type == DocumentType::MixedMedia
                || result.doc_type == DocumentType::TechnicalDocs,
            "Expected mixed or technical, got {:?}",
            result.doc_type
        );
    }

    #[test]
    fn test_frontmatter_detection() {
        let with_fm = "---\ntitle: My Post\ndate: 2026-01-01\n---\n\nHello world.";
        let without_fm = "# Hello World\n\nSome text.";
        assert!(detect_frontmatter(with_fm));
        assert!(!detect_frontmatter(without_fm));
    }

    #[test]
    fn test_technical_docs_with_tables() {
        let doc = "# API Reference\n\
                    \n\
                    ## Endpoints\n\
                    \n\
                    | Method | Path | Description |\n\
                    |--------|------|-------------|\n\
                    | GET | /users | List users |\n\
                    | POST | /users | Create user |\n\
                    | DELETE | /users/:id | Delete user |\n\
                    \n\
                    ## Authentication\n\
                    \n\
                    All requests require a Bearer token.";
        let result = classify_document(doc);
        assert_eq!(result.doc_type, DocumentType::TechnicalDocs);
    }

    #[test]
    fn test_frontmatter_sets_flag() {
        let doc = "---\ntitle: Test\ntags: [a, b]\n---\n\nContent here.";
        let result = classify_document(doc);
        assert!(result.has_frontmatter);
    }

    #[test]
    fn test_classification_to_uniffi() {
        let result = classify_document("Hello world paragraph.");
        let exported: DocumentClassification = result.into();
        assert_eq!(exported.doc_type, "prose");
    }

    #[test]
    fn test_confidence_bounded() {
        // Even extreme inputs should keep confidence in [0, 1]
        let code = (0..1000)
            .map(|i| format!("let x{i} = {i};"))
            .collect::<Vec<_>>()
            .join("\n");
        let result = classify_document(&code);
        assert!(result.confidence <= 1.0);
        assert!(result.confidence >= 0.0);
    }

    #[test]
    fn test_is_code_line_heuristics() {
        assert!(is_code_line("fn main() {"));
        assert!(is_code_line("    indented code"));
        assert!(is_code_line("\ttab indented"));
        assert!(is_code_line("let x = 42;"));
        assert!(is_code_line("import os"));
        assert!(!is_code_line("This is a normal sentence."));
        assert!(!is_code_line("The quick brown fox."));
    }
}
