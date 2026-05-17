use agent_core::tri_fusion::{TriFusionDocument, TriFusionError};

const MARKDOWN_FIXTURE_COUNT: usize = 50;

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

fn generated_markdown_fixture(seed: usize) -> String {
    let mut blocks = vec![
        format!("# Generated Fixture {seed}"),
        format!("Generated paragraph {seed}\ncontinues line {seed}"),
    ];

    match seed % 4 {
        0 => blocks.push(format!("```rust\nfn generated_{seed}() {{}}\n```")),
        1 => blocks.push(format!("> Generated quote {seed}\n> Second quote {seed}")),
        2 => blocks.push(format!(
            "- Generated item {seed}a\n- Generated item {seed}b"
        )),
        _ => blocks.push(format!("## Generated Section {seed}")),
    }

    if seed % 5 == 0 {
        blocks.push("```\n```".to_string());
    }

    blocks.join("\n\n")
}

fn assert_generated_markdown_round_trip(seed: usize) {
    let fixture = generated_markdown_fixture(seed);
    assert_markdown_round_trip(&fixture);
}

macro_rules! generated_markdown_case {
    ($name:ident, $seed:expr) => {
        #[test]
        fn $name() {
            assert_generated_markdown_round_trip($seed);
        }
    };
}

#[test]
fn markdown_fixture_count_is_reported() {
    assert_eq!(MARKDOWN_FIXTURE_COUNT, 50);
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

generated_markdown_case!(generated_markdown_corpus_014, 14);
generated_markdown_case!(generated_markdown_corpus_015, 15);
generated_markdown_case!(generated_markdown_corpus_016, 16);
generated_markdown_case!(generated_markdown_corpus_017, 17);
generated_markdown_case!(generated_markdown_corpus_018, 18);
generated_markdown_case!(generated_markdown_corpus_019, 19);
generated_markdown_case!(generated_markdown_corpus_020, 20);
generated_markdown_case!(generated_markdown_corpus_021, 21);
generated_markdown_case!(generated_markdown_corpus_022, 22);
generated_markdown_case!(generated_markdown_corpus_023, 23);
generated_markdown_case!(generated_markdown_corpus_024, 24);
generated_markdown_case!(generated_markdown_corpus_025, 25);
generated_markdown_case!(generated_markdown_corpus_026, 26);
generated_markdown_case!(generated_markdown_corpus_027, 27);
generated_markdown_case!(generated_markdown_corpus_028, 28);
generated_markdown_case!(generated_markdown_corpus_029, 29);
generated_markdown_case!(generated_markdown_corpus_030, 30);
generated_markdown_case!(generated_markdown_corpus_031, 31);
generated_markdown_case!(generated_markdown_corpus_032, 32);
generated_markdown_case!(generated_markdown_corpus_033, 33);
generated_markdown_case!(generated_markdown_corpus_034, 34);
generated_markdown_case!(generated_markdown_corpus_035, 35);
generated_markdown_case!(generated_markdown_corpus_036, 36);
generated_markdown_case!(generated_markdown_corpus_037, 37);
generated_markdown_case!(generated_markdown_corpus_038, 38);
generated_markdown_case!(generated_markdown_corpus_039, 39);
generated_markdown_case!(generated_markdown_corpus_040, 40);
generated_markdown_case!(generated_markdown_corpus_041, 41);
generated_markdown_case!(generated_markdown_corpus_042, 42);
generated_markdown_case!(generated_markdown_corpus_043, 43);
generated_markdown_case!(generated_markdown_corpus_044, 44);
generated_markdown_case!(generated_markdown_corpus_045, 45);
generated_markdown_case!(generated_markdown_corpus_046, 46);
generated_markdown_case!(generated_markdown_corpus_047, 47);
generated_markdown_case!(generated_markdown_corpus_048, 48);
generated_markdown_case!(generated_markdown_corpus_049, 49);
generated_markdown_case!(generated_markdown_corpus_050, 50);

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
