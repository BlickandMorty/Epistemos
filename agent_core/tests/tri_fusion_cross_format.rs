use agent_core::tri_fusion::{TriFusionDocument, TriFusionError};

const CROSS_FORMAT_FIXTURE_COUNT: usize = 6;

fn assert_common_subset_coherence(canonical_json: &str) {
    let document = TriFusionDocument::parse_json(canonical_json).unwrap();

    let markdown = document.to_markdown().unwrap();
    let markdown_reparsed = TriFusionDocument::parse_markdown(&markdown).unwrap();
    assert_eq!(
        markdown_reparsed.canonical_json(),
        document.canonical_json()
    );
    assert_eq!(markdown_reparsed.hash(), document.hash());

    let html = document.to_html().unwrap();
    let html_reparsed = TriFusionDocument::parse_html(&html).unwrap();
    assert_eq!(html_reparsed.canonical_json(), document.canonical_json());
    assert_eq!(html_reparsed.hash(), document.hash());

    let markdown_to_html = markdown_reparsed.to_html().unwrap();
    let markdown_html_reparsed = TriFusionDocument::parse_html(&markdown_to_html).unwrap();
    assert_eq!(
        markdown_html_reparsed.canonical_json(),
        markdown_reparsed.canonical_json()
    );
    assert_eq!(markdown_html_reparsed.hash(), markdown_reparsed.hash());
}

macro_rules! cross_format_case {
    ($name:ident, $json:expr) => {
        #[test]
        fn $name() {
            assert_common_subset_coherence($json);
        }
    };
}

#[test]
fn cross_format_fixture_count_is_reported() {
    assert_eq!(CROSS_FORMAT_FIXTURE_COUNT, 6);
}

cross_format_case!(
    paragraph_common_subset_coheres,
    r#"{"content":[{"content":[{"text":"Plain paragraph","type":"text"}],"type":"paragraph"}],"type":"doc"}"#
);

cross_format_case!(
    heading_common_subset_coheres,
    r#"{"content":[{"attrs":{"level":2},"content":[{"text":"Section","type":"text"}],"type":"heading"},{"content":[{"text":"Body","type":"text"}],"type":"paragraph"}],"type":"doc"}"#
);

cross_format_case!(
    code_block_common_subset_coheres,
    r#"{"content":[{"attrs":{"language":"rust"},"content":[{"text":"fn main() {}","type":"text"}],"type":"codeBlock"}],"type":"doc"}"#
);

cross_format_case!(
    blockquote_common_subset_coheres,
    r#"{"content":[{"content":[{"content":[{"text":"Quoted text","type":"text"}],"type":"paragraph"}],"type":"blockquote"}],"type":"doc"}"#
);

cross_format_case!(
    bullet_list_common_subset_coheres,
    r#"{"content":[{"content":[{"content":[{"content":[{"text":"Alpha","type":"text"}],"type":"paragraph"}],"type":"listItem"},{"content":[{"content":[{"text":"Beta","type":"text"}],"type":"paragraph"}],"type":"listItem"}],"type":"bulletList"}],"type":"doc"}"#
);

cross_format_case!(
    mixed_common_subset_coheres,
    r#"{"content":[{"attrs":{"level":1},"content":[{"text":"Daily Note","type":"text"}],"type":"heading"},{"content":[{"text":"Intro","type":"text"}],"type":"paragraph"},{"content":[{"content":[{"text":"Context","type":"text"}],"type":"paragraph"}],"type":"blockquote"},{"content":[{"content":[{"content":[{"text":"Task one","type":"text"}],"type":"paragraph"}],"type":"listItem"},{"content":[{"content":[{"text":"Task two","type":"text"}],"type":"paragraph"}],"type":"listItem"}],"type":"bulletList"},{"attrs":{"language":"typescript"},"content":[{"text":"const done = true","type":"text"}],"type":"codeBlock"}],"type":"doc"}"#
);

#[test]
fn markdown_to_html_coherence_preserves_markdown_source_json() {
    let markdown = "# Title\n\nBody\n\n- One\n- Two\n\n```rust\nfn main() {}\n```";
    let markdown_document = TriFusionDocument::parse_markdown(markdown).unwrap();
    let html = markdown_document.to_html().unwrap();
    let html_document = TriFusionDocument::parse_html(&html).unwrap();

    assert_eq!(
        html_document.canonical_json(),
        markdown_document.canonical_json()
    );
    assert_eq!(html_document.hash(), markdown_document.hash());
}

#[test]
fn html_normalization_only_changes_do_not_change_json() {
    let noisy = "<div data-tri-fusion-doc><H2>Title</H2>\n<p>A &amp; B</p></div>";
    let canonical = "<h2>Title</h2><p>A &amp; B</p>";
    let noisy_document = TriFusionDocument::parse_html(noisy).unwrap();
    let canonical_document = TriFusionDocument::parse_html(canonical).unwrap();

    assert_ne!(noisy, canonical);
    assert_eq!(
        noisy_document.canonical_json(),
        canonical_document.canonical_json()
    );
    assert_eq!(noisy_document.hash(), canonical_document.hash());
}

#[test]
fn semantic_html_edit_changes_json_and_hash() {
    let before = TriFusionDocument::parse_html("<p>Before</p>").unwrap();
    let after = TriFusionDocument::parse_html("<p>After</p>").unwrap();

    assert_ne!(before.canonical_json(), after.canonical_json());
    assert_ne!(before.hash(), after.hash());
}

#[test]
fn marked_text_is_not_claimed_as_common_subset() {
    let document = TriFusionDocument::parse_json(
        r#"{"content":[{"content":[{"marks":[{"type":"bold"}],"text":"Bold","type":"text"}],"type":"paragraph"}],"type":"doc"}"#,
    )
    .unwrap();

    assert!(matches!(
        document.to_markdown().unwrap_err(),
        TriFusionError::UnsupportedMarkdownProjection { .. }
    ));
    assert!(matches!(
        document.to_html().unwrap_err(),
        TriFusionError::UnsupportedHtmlProjection { .. }
    ));
}
