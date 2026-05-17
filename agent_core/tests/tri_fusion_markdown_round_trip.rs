use agent_core::tri_fusion::{TriFusionDocument, TriFusionError};

const MARKDOWN_FIXTURE_COUNT: usize = 13;

fn assert_markdown_round_trip(input: &str) {
    let document = TriFusionDocument::parse_markdown(input).unwrap();
    let rendered = document.to_markdown().unwrap();
    assert_eq!(rendered, input);

    let reparsed = TriFusionDocument::parse_markdown(&rendered).unwrap();
    assert_eq!(reparsed.canonical_json(), document.canonical_json());
    assert_eq!(reparsed.hash(), document.hash());
}

macro_rules! markdown_case {
    ($name:ident, $input:expr) => {
        #[test]
        fn $name() {
            assert_markdown_round_trip($input);
        }
    };
}

#[test]
fn markdown_fixture_count_is_reported() {
    assert_eq!(MARKDOWN_FIXTURE_COUNT, 13);
}

markdown_case!(paragraph_round_trips_byte_equal, "Plain paragraph");
markdown_case!(
    two_paragraphs_round_trip_byte_equal,
    "First paragraph\n\nSecond paragraph"
);
markdown_case!(
    soft_break_paragraph_round_trips_byte_equal,
    "First line\nsecond line"
);
markdown_case!(
    heading_and_paragraph_round_trip_byte_equal,
    "# Title\n\nBody paragraph"
);
markdown_case!(
    heading_levels_round_trip_byte_equal,
    "# One\n\n## Two\n\n### Three"
);
markdown_case!(
    rust_code_fence_round_trips_byte_equal,
    "```rust\nfn main() {}\n```"
);
markdown_case!(
    plain_code_fence_round_trips_byte_equal,
    "```\nraw text\n```"
);
markdown_case!(empty_code_fence_round_trips_byte_equal, "```\n```");
markdown_case!(
    multiline_code_fence_round_trips_byte_equal,
    "```swift\nlet x = 1\nprint(x)\n```"
);
markdown_case!(blockquote_round_trips_byte_equal, "> Quoted text");
markdown_case!(
    multiline_blockquote_round_trips_byte_equal,
    "> First quote line\n> Second quote line"
);
markdown_case!(
    bullet_list_round_trips_byte_equal,
    "- Alpha\n- Beta\n- Gamma"
);
markdown_case!(
    mixed_supported_blocks_round_trip_byte_equal,
    "# Daily Note\n\nIntro\n\n> Context\n\n- Task one\n- Task two\n\n```typescript\nconst done = true\n```"
);

#[test]
fn supported_json_round_trips_through_markdown_without_semantic_drift() {
    let document = TriFusionDocument::parse_json(
        r#"{"content":[{"attrs":{"level":2},"content":[{"text":"Title","type":"text"}],"type":"heading"},{"content":[{"text":"Body","type":"text"}],"type":"paragraph"},{"content":[{"content":[{"content":[{"text":"One","type":"text"}],"type":"paragraph"}],"type":"listItem"}],"type":"bulletList"}],"type":"doc"}"#,
    )
    .unwrap();

    let markdown = document.to_markdown().unwrap();
    assert_eq!(markdown, "## Title\n\nBody\n\n- One");

    let reparsed = TriFusionDocument::parse_markdown(&markdown).unwrap();
    assert_eq!(reparsed.canonical_json(), document.canonical_json());
}

#[test]
fn markdown_rejects_unclosed_code_fence() {
    let error = TriFusionDocument::parse_markdown("```rust\nfn main() {}").unwrap_err();
    assert_eq!(
        error,
        TriFusionError::InvalidMarkdown {
            line: 1,
            message: "unclosed code fence".to_string()
        }
    );
}

#[test]
fn markdown_rejects_non_lf_line_endings() {
    let error = TriFusionDocument::parse_markdown("One\r\nTwo").unwrap_err();
    assert_eq!(
        error,
        TriFusionError::InvalidMarkdown {
            line: 1,
            message: "canonical Markdown uses LF line endings only".to_string()
        }
    );
}

#[test]
fn markdown_rejects_multi_token_code_fence_language() {
    let error = TriFusionDocument::parse_markdown("```rust extra\ncode\n```").unwrap_err();
    assert_eq!(
        error,
        TriFusionError::InvalidMarkdown {
            line: 1,
            message: "code fence language must be one token".to_string()
        }
    );
}

#[test]
fn markdown_rejects_unsupported_table_syntax() {
    let error = TriFusionDocument::parse_markdown("| A | B |\n| - | - |").unwrap_err();
    assert_eq!(
        error,
        TriFusionError::InvalidMarkdown {
            line: 1,
            message: "Markdown block is outside the canonical subset".to_string()
        }
    );
}

#[test]
fn markdown_projection_rejects_unsupported_inline_marks() {
    let document = TriFusionDocument::parse_json(
        r#"{"content":[{"content":[{"marks":[{"type":"bold"}],"text":"Bold","type":"text"}],"type":"paragraph"}],"type":"doc"}"#,
    )
    .unwrap();

    let error = document.to_markdown().unwrap_err();
    assert!(matches!(
        error,
        TriFusionError::UnsupportedMarkdownProjection { .. }
    ));
}

#[test]
fn markdown_projection_rejects_unsupported_table_nodes() {
    let document = TriFusionDocument::parse_json(
        r#"{"content":[{"content":[],"type":"table"}],"type":"doc"}"#,
    )
    .unwrap();

    let error = document.to_markdown().unwrap_err();
    assert!(matches!(
        error,
        TriFusionError::UnsupportedMarkdownProjection { .. }
    ));
}
