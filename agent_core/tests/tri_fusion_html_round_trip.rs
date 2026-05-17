use agent_core::tri_fusion::{TriFusionDocument, TriFusionError};

const HTML_FIXTURE_COUNT: usize = 8;

fn assert_html_tree_round_trip(input: &str) {
    let normalized = TriFusionDocument::normalize_html(input).unwrap();
    let document = TriFusionDocument::parse_html(input).unwrap();
    let rendered = document.to_html().unwrap();

    assert_eq!(
        TriFusionDocument::normalize_html(&rendered).unwrap(),
        normalized
    );

    let reparsed = TriFusionDocument::parse_html(&rendered).unwrap();
    assert_eq!(reparsed.canonical_json(), document.canonical_json());
    assert_eq!(reparsed.hash(), document.hash());
}

macro_rules! html_case {
    ($name:ident, $input:expr) => {
        #[test]
        fn $name() {
            assert_html_tree_round_trip($input);
        }
    };
}

#[test]
fn html_fixture_count_is_reported() {
    assert_eq!(HTML_FIXTURE_COUNT, 8);
}

html_case!(paragraph_tree_round_trips, "<p>Plain paragraph</p>");
html_case!(heading_tree_round_trips, "<H1>Title</H1><p>Body</p>");
html_case!(
    escaped_text_tree_round_trips,
    "<p>A &amp; B &lt; C &quot;quoted&quot;</p>"
);
html_case!(
    rust_code_block_tree_round_trips,
    r#"<pre><code class="language-rust">fn main() {}</code></pre>"#
);
html_case!(
    blockquote_tree_round_trips,
    "<blockquote><p>Quoted text</p></blockquote>"
);
html_case!(
    bullet_list_with_paragraph_items_tree_round_trips,
    "<ul><li><p>Alpha</p></li><li><p>Beta</p></li></ul>"
);
html_case!(
    wrapper_noise_tree_round_trips,
    "<div data-tri-fusion-doc><p>Wrapped</p></div>"
);
html_case!(
    mixed_supported_blocks_tree_round_trip,
    "<section data-tri-fusion-doc><h2>Daily Note</h2>\n<p>Intro</p><blockquote><p>Context</p></blockquote><ul><li>Task one</li><li>Task two</li></ul></section>"
);

#[test]
fn html_normalization_is_semantic_not_byte_equal() {
    let noisy = "<div data-tri-fusion-doc><H2>Title</H2>\n<p>A &amp; B</p></div>";
    let canonical = "<h2>Title</h2><p>A &amp; B</p>";

    assert_ne!(noisy, canonical);
    assert_eq!(TriFusionDocument::normalize_html(noisy).unwrap(), canonical);
    assert_eq!(
        TriFusionDocument::normalize_html(canonical).unwrap(),
        canonical
    );
}

#[test]
fn html_rejects_unsafe_script_tag() {
    let error = TriFusionDocument::parse_html("<script>alert(1)</script>").unwrap_err();
    assert_eq!(
        error,
        TriFusionError::InvalidHtml {
            message: "unsafe HTML tag is outside the canonical subset".to_string()
        }
    );
}

#[test]
fn html_rejects_unsupported_nested_inline_tag() {
    let error = TriFusionDocument::parse_html("<p>Hello <span>world</span></p>").unwrap_err();
    assert_eq!(
        error,
        TriFusionError::InvalidHtml {
            message: "html.children[0] contains unsupported child <span>".to_string()
        }
    );
}

#[test]
fn html_rejects_unknown_entity() {
    let error = TriFusionDocument::parse_html("<p>&nbsp;</p>").unwrap_err();
    assert_eq!(
        error,
        TriFusionError::InvalidHtml {
            message: "unsupported HTML entity &nbsp;".to_string()
        }
    );
}

#[test]
fn html_rejects_multiple_code_language_classes() {
    let error = TriFusionDocument::parse_html(
        r#"<pre><code class="language-rust language-js">x</code></pre>"#,
    )
    .unwrap_err();
    assert_eq!(
        error,
        TriFusionError::InvalidHtml {
            message: "code block has multiple language classes".to_string()
        }
    );
}

#[test]
fn html_projection_rejects_unsupported_image_node() {
    let document = TriFusionDocument::parse_json(
        r#"{"content":[{"attrs":{"src":"https://example.com/a.png"},"type":"epdocImage"}],"type":"doc"}"#,
    )
    .unwrap();

    let error = document.to_html().unwrap_err();
    assert!(matches!(
        error,
        TriFusionError::UnsupportedHtmlProjection { .. }
    ));
}
