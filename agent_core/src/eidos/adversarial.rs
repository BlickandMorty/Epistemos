//! Shared adversarial query fixtures for Eidos retrieval hardening.
//!
//! These fixtures name query shapes that should stay visible across
//! retriever-level tests, fuzz-like no-panic sweeps, and future Swift bridge
//! harnesses. The labels are stable test-facing identifiers; descriptions are
//! human-readable catalog notes.

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AdversarialQueryFixtureKind {
    TypoTransposition,
    Bm25Saturation,
    NearDuplicateParagraphTie,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AdversarialQueryExpectedOutcome {
    NoFuzzyMatch,
    FiniteSaturatingScore,
    DeterministicTieBreak,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct AdversarialQueryFixture {
    pub label: &'static str,
    pub kind: AdversarialQueryFixtureKind,
    pub expected_outcome: AdversarialQueryExpectedOutcome,
    pub query_text: &'static str,
    pub description: &'static str,
}

pub const ADVERSARIAL_QUERY_FIXTURES: &[AdversarialQueryFixture] = &[
    AdversarialQueryFixture {
        label: "typo-transposition",
        kind: AdversarialQueryFixtureKind::TypoTransposition,
        expected_outcome: AdversarialQueryExpectedOutcome::NoFuzzyMatch,
        query_text: "tropcial",
        description: "misspelled transposition of tropical; must not fuzzy-match by accident",
    },
    AdversarialQueryFixture {
        label: "bm25-saturation",
        kind: AdversarialQueryFixtureKind::Bm25Saturation,
        expected_outcome: AdversarialQueryExpectedOutcome::FiniteSaturatingScore,
        query_text: "tropical",
        description: "high-frequency lexical needle for score saturation and overflow pins",
    },
    AdversarialQueryFixture {
        label: "near-duplicate-paragraph-tie",
        kind: AdversarialQueryFixtureKind::NearDuplicateParagraphTie,
        expected_outcome: AdversarialQueryExpectedOutcome::DeterministicTieBreak,
        query_text: "near duplicate paragraph",
        description: "same-count near-duplicate paragraphs force deterministic tie-breaks",
    },
];

pub const ADVERSARIAL_QUERY_FIXTURE_LABELS: &[&str] = &[
    "typo-transposition",
    "bm25-saturation",
    "near-duplicate-paragraph-tie",
];

pub const ADVERSARIAL_QUERY_FIXTURE_QUERY_TEXTS: &[&str] = &[
    "tropcial",
    "tropical",
    "near duplicate paragraph",
];

pub const ADVERSARIAL_QUERY_FIXTURE_KINDS: &[AdversarialQueryFixtureKind] = &[
    AdversarialQueryFixtureKind::TypoTransposition,
    AdversarialQueryFixtureKind::Bm25Saturation,
    AdversarialQueryFixtureKind::NearDuplicateParagraphTie,
];

pub const ADVERSARIAL_QUERY_FIXTURE_EXPECTED_OUTCOMES: &[AdversarialQueryExpectedOutcome] = &[
    AdversarialQueryExpectedOutcome::NoFuzzyMatch,
    AdversarialQueryExpectedOutcome::FiniteSaturatingScore,
    AdversarialQueryExpectedOutcome::DeterministicTieBreak,
];

pub const ADVERSARIAL_QUERY_FIXTURE_DESCRIPTIONS: &[&str] = &[
    "misspelled transposition of tropical; must not fuzzy-match by accident",
    "high-frequency lexical needle for score saturation and overflow pins",
    "same-count near-duplicate paragraphs force deterministic tie-breaks",
];

pub const ADVERSARIAL_QUERY_FIXTURE_INDICES: &[usize] = &[0, 1, 2];

pub fn adversarial_query_fixture(label: &str) -> Option<AdversarialQueryFixture> {
    ADVERSARIAL_QUERY_FIXTURES
        .iter()
        .copied()
        .find(|fixture| fixture.label == label)
}

pub fn adversarial_query_fixture_at(index: usize) -> Option<AdversarialQueryFixture> {
    ADVERSARIAL_QUERY_FIXTURES.get(index).copied()
}

pub fn adversarial_query_fixture_for_kind(
    kind: AdversarialQueryFixtureKind,
) -> Option<AdversarialQueryFixture> {
    ADVERSARIAL_QUERY_FIXTURES
        .iter()
        .copied()
        .find(|fixture| fixture.kind == kind)
}

pub fn adversarial_query_fixture_for_outcome(
    expected_outcome: AdversarialQueryExpectedOutcome,
) -> Option<AdversarialQueryFixture> {
    ADVERSARIAL_QUERY_FIXTURES
        .iter()
        .copied()
        .find(|fixture| fixture.expected_outcome == expected_outcome)
}

pub fn adversarial_query_fixture_for_query_text(
    query_text: &str,
) -> Option<AdversarialQueryFixture> {
    ADVERSARIAL_QUERY_FIXTURES
        .iter()
        .copied()
        .find(|fixture| fixture.query_text == query_text)
}

pub fn adversarial_query_fixture_labels() -> &'static [&'static str] {
    ADVERSARIAL_QUERY_FIXTURE_LABELS
}

pub fn adversarial_query_fixture_query_texts() -> &'static [&'static str] {
    ADVERSARIAL_QUERY_FIXTURE_QUERY_TEXTS
}

pub fn adversarial_query_fixture_kinds() -> &'static [AdversarialQueryFixtureKind] {
    ADVERSARIAL_QUERY_FIXTURE_KINDS
}

pub fn adversarial_query_fixture_expected_outcomes(
) -> &'static [AdversarialQueryExpectedOutcome] {
    ADVERSARIAL_QUERY_FIXTURE_EXPECTED_OUTCOMES
}

pub fn adversarial_query_fixture_descriptions() -> &'static [&'static str] {
    ADVERSARIAL_QUERY_FIXTURE_DESCRIPTIONS
}

pub fn adversarial_query_fixture_count() -> usize {
    ADVERSARIAL_QUERY_FIXTURES.len()
}

pub fn adversarial_query_fixture_indices() -> &'static [usize] {
    ADVERSARIAL_QUERY_FIXTURE_INDICES
}

pub fn adversarial_query_fixture_catalog_labels_match_fixture_rows() -> bool {
    ADVERSARIAL_QUERY_FIXTURE_LABELS.len() == ADVERSARIAL_QUERY_FIXTURES.len()
        && ADVERSARIAL_QUERY_FIXTURE_LABELS
            .iter()
            .zip(ADVERSARIAL_QUERY_FIXTURES.iter())
            .all(|(label, fixture)| *label == fixture.label)
}

pub fn adversarial_query_fixture_catalog_query_texts_match_fixture_rows() -> bool {
    ADVERSARIAL_QUERY_FIXTURE_QUERY_TEXTS.len() == ADVERSARIAL_QUERY_FIXTURES.len()
        && ADVERSARIAL_QUERY_FIXTURE_QUERY_TEXTS
            .iter()
            .zip(ADVERSARIAL_QUERY_FIXTURES.iter())
            .all(|(query_text, fixture)| *query_text == fixture.query_text)
}

pub fn adversarial_query_fixture_catalog_kinds_match_fixture_rows() -> bool {
    ADVERSARIAL_QUERY_FIXTURE_KINDS.len() == ADVERSARIAL_QUERY_FIXTURES.len()
        && ADVERSARIAL_QUERY_FIXTURE_KINDS
            .iter()
            .zip(ADVERSARIAL_QUERY_FIXTURES.iter())
            .all(|(kind, fixture)| *kind == fixture.kind)
}

pub fn adversarial_query_fixture_catalog_expected_outcomes_match_fixture_rows() -> bool {
    ADVERSARIAL_QUERY_FIXTURE_EXPECTED_OUTCOMES.len() == ADVERSARIAL_QUERY_FIXTURES.len()
        && ADVERSARIAL_QUERY_FIXTURE_EXPECTED_OUTCOMES
            .iter()
            .zip(ADVERSARIAL_QUERY_FIXTURES.iter())
            .all(|(expected_outcome, fixture)| {
                *expected_outcome == fixture.expected_outcome
            })
}

pub fn adversarial_query_fixture_catalog_descriptions_match_fixture_rows() -> bool {
    ADVERSARIAL_QUERY_FIXTURE_DESCRIPTIONS.len() == ADVERSARIAL_QUERY_FIXTURES.len()
        && ADVERSARIAL_QUERY_FIXTURE_DESCRIPTIONS
            .iter()
            .zip(ADVERSARIAL_QUERY_FIXTURES.iter())
            .all(|(description, fixture)| *description == fixture.description)
}

pub fn adversarial_query_fixture_catalog_indices_match_fixture_rows() -> bool {
    ADVERSARIAL_QUERY_FIXTURE_INDICES.len() == ADVERSARIAL_QUERY_FIXTURES.len()
        && ADVERSARIAL_QUERY_FIXTURE_INDICES
            .iter()
            .copied()
            .enumerate()
            .all(|(expected_index, index)| index == expected_index)
}

pub fn adversarial_query_fixture_catalog_static_surface_is_complete() -> bool {
    adversarial_query_fixture_catalog_labels_match_fixture_rows()
        && adversarial_query_fixture_catalog_query_texts_match_fixture_rows()
        && adversarial_query_fixture_catalog_kinds_match_fixture_rows()
        && adversarial_query_fixture_catalog_expected_outcomes_match_fixture_rows()
        && adversarial_query_fixture_catalog_descriptions_match_fixture_rows()
        && adversarial_query_fixture_catalog_indices_match_fixture_rows()
}

pub fn adversarial_query_fixture_labels_are_ascii_lowercase_kebab_case() -> bool {
    ADVERSARIAL_QUERY_FIXTURE_LABELS.iter().all(|label| {
        !label.is_empty()
            && label.bytes().all(|byte| {
                byte.is_ascii_lowercase() || byte.is_ascii_digit() || byte == b'-'
            })
            && !label.starts_with('-')
            && !label.ends_with('-')
            && !label.contains("--")
    })
}

pub fn adversarial_query_fixture_query_texts_are_nonempty_trimmed_and_control_free() -> bool {
    ADVERSARIAL_QUERY_FIXTURE_QUERY_TEXTS.iter().all(|query_text| {
        !query_text.is_empty()
            && query_text.trim() == *query_text
            && !query_text.chars().any(char::is_control)
    })
}
