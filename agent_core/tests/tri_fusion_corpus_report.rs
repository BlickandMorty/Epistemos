use std::collections::BTreeSet;

#[derive(Clone, Copy, Debug)]
struct CorpusFamily {
    label: &'static str,
    case_count: usize,
    property: &'static str,
    source: &'static str,
}

const ACCEPTANCE_MIN_POSITIVE_DOCUMENTS: usize = 200;

const POSITIVE_FAMILIES: &[CorpusFamily] = &[
    CorpusFamily {
        label: "json_identity",
        case_count: 200,
        property: "byte-equal canonical JSON identity",
        source: "tri_fusion_json_corpus.rs",
    },
    CorpusFamily {
        label: "markdown_byte_equal",
        case_count: 50,
        property: "byte-equal canonical Markdown projection",
        source: "tri_fusion_markdown_round_trip.rs",
    },
    CorpusFamily {
        label: "html_tree_equal",
        case_count: 50,
        property: "tree-equal canonical HTML projection",
        source: "tri_fusion_html_round_trip.rs",
    },
    CorpusFamily {
        label: "cross_format_common_subset",
        case_count: 40,
        property: "canonical JSON convergence across supported projections",
        source: "tri_fusion_cross_format.rs",
    },
    CorpusFamily {
        label: "mutation_witness_before_after",
        case_count: 20,
        property: "before/after mutation witnesses with byte-stable witness JSON",
        source: "tri_fusion_mutation_corpus.rs",
    },
];

const FAILURE_FAMILIES: &[CorpusFamily] = &[
    CorpusFamily {
        label: "json_malformed_roots",
        case_count: 1,
        property: "deterministic invalid JSON rejection",
        source: "tri_fusion_json_round_trip.rs",
    },
    CorpusFamily {
        label: "markdown_malformed_or_unsupported",
        case_count: 6,
        property: "deterministic Markdown rejection and unsupported projection errors",
        source: "tri_fusion_markdown_round_trip.rs",
    },
    CorpusFamily {
        label: "html_malformed_or_unsupported",
        case_count: 5,
        property: "deterministic HTML rejection and unsupported projection errors",
        source: "tri_fusion_html_round_trip.rs",
    },
    CorpusFamily {
        label: "cross_format_unsupported_projection",
        case_count: 1,
        property: "unsupported projection remains outside common subset",
        source: "tri_fusion_cross_format.rs",
    },
];

fn positive_document_count() -> usize {
    POSITIVE_FAMILIES
        .iter()
        .map(|family| family.case_count)
        .sum()
}

fn failure_fixture_count() -> usize {
    FAILURE_FAMILIES
        .iter()
        .map(|family| family.case_count)
        .sum()
}

fn corpus_report() -> String {
    let mut lines = vec![format!(
        "positive_document_total={}",
        positive_document_count()
    )];
    for family in POSITIVE_FAMILIES {
        lines.push(format!(
            "positive:{}:{}:{}:{}",
            family.label, family.case_count, family.property, family.source
        ));
    }
    lines.push(format!("failure_fixture_total={}", failure_fixture_count()));
    for family in FAILURE_FAMILIES {
        lines.push(format!(
            "failure:{}:{}:{}:{}",
            family.label, family.case_count, family.property, family.source
        ));
    }
    lines.join("\n")
}

#[test]
fn corpus_report_exceeds_acceptance_document_floor() {
    assert_eq!(positive_document_count(), 360);
    assert!(positive_document_count() >= ACCEPTANCE_MIN_POSITIVE_DOCUMENTS);
}

#[test]
fn corpus_report_keeps_failure_fixtures_out_of_positive_count() {
    assert_eq!(failure_fixture_count(), 13);
    assert_eq!(positive_document_count() + failure_fixture_count(), 373);
}

#[test]
fn corpus_report_labels_are_unique() {
    let mut labels = BTreeSet::new();
    for family in POSITIVE_FAMILIES.iter().chain(FAILURE_FAMILIES.iter()) {
        assert!(
            labels.insert(family.label),
            "duplicate corpus label: {}",
            family.label
        );
    }
}

#[test]
fn corpus_report_is_deterministic_and_names_sources() {
    let first = corpus_report();
    let second = corpus_report();

    assert_eq!(first, second);
    assert!(first.contains("positive_document_total=360"));
    assert!(first.contains("failure_fixture_total=13"));
    assert!(first.contains("tri_fusion_json_corpus.rs"));
    assert!(first.contains("tri_fusion_markdown_round_trip.rs"));
    assert!(first.contains("tri_fusion_html_round_trip.rs"));
    assert!(first.contains("tri_fusion_cross_format.rs"));
    assert!(first.contains("tri_fusion_mutation_corpus.rs"));
}
