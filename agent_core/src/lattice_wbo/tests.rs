//! Shared test helpers and submodule declarations for the lattice_wbo register.

#[allow(unused_imports)]
pub(super) use super::*;
#[allow(unused_imports)]
pub(super) use super::verifier::{
    contains_any_falsifier_hook, contains_falsifier_hook, f_hooks_in, falsifier_hooks_are_owned,
    is_falsifier_hook_boundary, validate_nonnegative_finite,
};
#[allow(unused_imports)]
pub(super) use super::wire::{deserialize_explicit_public_option, ExplicitPublicOption};

#[allow(unused_imports)]
pub(super) use serde::Deserialize;

pub(super) fn side_information_probe_budget(
    coder: LatticeCoderKind,
    side_information: SideInformationKind,
) -> LatticeBudget {
    let mut contributions = Vec::with_capacity(coder.canonical_wbo_terms().len());
    for term in coder.canonical_wbo_terms() {
        contributions.push(
            LatticeErrorContribution::new(*term, format!("probe {}", term.code()), 0.0)
                .expect("canonical probe contribution should be valid"),
        );
    }
    LatticeBudget::new(
        coder,
        coder.allows_rate_parameter().then_some(1250),
        side_information,
        contributions,
    )
}

pub(super) fn measured_probe_budget(
    coder: LatticeCoderKind,
    rate_milli_bits_per_symbol: Option<u32>,
    side_information: SideInformationKind,
) -> LatticeBudget {
    let mut contributions = Vec::with_capacity(coder.canonical_wbo_terms().len());
    for term in coder.canonical_wbo_terms() {
        contributions.push(
            LatticeErrorContribution::new(
                *term,
                format!("measured probe {}", term.code()),
                0.0,
            )
            .expect("canonical measured probe contribution should be valid")
            .with_measured(0.0)
            .expect("canonical measured probe measurement should be valid"),
        );
    }
    LatticeBudget::new(
        coder,
        rate_milli_bits_per_symbol,
        side_information,
        contributions,
    )
}

pub(super) fn assert_budget_measurements_pending(budget: &LatticeBudget) {
    assert_eq!(budget.measured_pre_softmax_total(), None);
    assert_eq!(budget.measured_semantic_wbo6_pre_softmax_total(), None);
    assert_eq!(budget.measured_numerical_post_correction_total(), None);
    assert_eq!(budget.measured_softmax_half_corrected_total(), None);
    assert_eq!(budget.measured_within_budget(), None);
}

pub(super) fn tier_probe_contributions(tier: ResidencyTier) -> Vec<LatticeErrorContribution> {
    let mut contributions = Vec::with_capacity(tier.canonical_register_terms().len());
    for term in tier.canonical_register_terms() {
        contributions.push(
            LatticeErrorContribution::new(*term, format!("tier probe {}", term.code()), 0.0)
                .expect("canonical tier probe contribution should be valid"),
        );
    }
    contributions
}

pub(super) fn assert_unique_catalog_keys(mut keys: Vec<String>, label: &str) {
    keys.sort_unstable();
    for pair in keys.windows(2) {
        assert_ne!(pair[0], pair[1], "{label} must not duplicate {}", pair[0]);
    }
}

pub(super) fn assert_json_unknown_field_rejected<T>(value: serde_json::Value, field: &str)
where
    T: for<'de> Deserialize<'de>,
{
    let error = match serde_json::from_value::<T>(value) {
        Ok(_) => panic!("unknown public JSON field must be rejected"),
        Err(error) => error,
    };
    let message = error.to_string();
    assert!(message.contains("unknown field"), "{message}");
    assert!(message.contains(field), "{message}");
}

pub(super) fn assert_json_duplicate_field_rejected<T>(json: &str, field: &str)
where
    T: for<'de> Deserialize<'de>,
{
    let error = match serde_json::from_str::<T>(json) {
        Ok(_) => panic!("duplicate public JSON field must be rejected"),
        Err(error) => error,
    };
    let message = error.to_string();
    assert!(message.contains("duplicate field"), "{message}");
    assert!(message.contains(field), "{message}");
}

pub(super) fn assert_json_missing_field_value_rejected<T>(mut value: serde_json::Value, field: &str)
where
    T: for<'de> Deserialize<'de>,
{
    let object = value
        .as_object_mut()
        .expect("public JSON fixture must be an object");
    assert!(
        object.remove(field).is_some(),
        "public JSON fixture must contain {field}"
    );
    let error = match serde_json::from_value::<T>(value) {
        Ok(_) => panic!("missing public JSON field must be rejected"),
        Err(error) => error,
    };
    assert_json_missing_field_error(error, field);
}

pub(super) fn assert_json_missing_field_error(error: serde_json::Error, field: &str) {
    let message = error.to_string();
    assert!(message.contains("missing field"), "{message}");
    assert!(message.contains(field), "{message}");
}

pub(super) fn assert_json_wrong_type_rejected<T>(json: &str)
where
    T: for<'de> Deserialize<'de>,
{
    let error = match serde_json::from_str::<T>(json) {
        Ok(_) => panic!("wrong-type public JSON field must be rejected"),
        Err(error) => error,
    };
    let message = error.to_string();
    assert!(message.contains("invalid type"), "{message}");
}

mod active_support_side_info;
mod axis_assignment;
mod budget_validation;
mod codec_falsifier_catalog;
mod ledger_basic_validation;
mod ledger_measured_and_falsifier;
mod ledger_residency_rejections;
mod public_accounting_envelope;
mod public_key_registries;
mod register_doc_cross_links;
mod register_doc_rows;
mod residency_catalog;
mod serde_roundtrip;
mod term_catalog_and_slices;
