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

pub fn adversarial_query_fixture(label: &str) -> Option<AdversarialQueryFixture> {
    ADVERSARIAL_QUERY_FIXTURES
        .iter()
        .copied()
        .find(|fixture| fixture.label == label)
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

pub fn adversarial_query_fixture_labels() -> &'static [&'static str] {
    ADVERSARIAL_QUERY_FIXTURE_LABELS
}

pub fn adversarial_query_fixture_catalog_labels_match_fixture_rows() -> bool {
    ADVERSARIAL_QUERY_FIXTURE_LABELS.len() == ADVERSARIAL_QUERY_FIXTURES.len()
        && ADVERSARIAL_QUERY_FIXTURE_LABELS
            .iter()
            .zip(ADVERSARIAL_QUERY_FIXTURES.iter())
            .all(|(label, fixture)| *label == fixture.label)
}
