//! Falsifier-hook ownership registry and validation helpers used by ledger
//! and budget validation paths.
//!
//! Hooks named in falsifier strings must trace back to a canonical owner in
//! `FALSIFIER_HOOK_OWNERS`; the boundary-aware substring helpers ensure that
//! a hook like `F-WBO-DriftLedger` cannot be spoofed by a longer surrounding
//! identifier.

use serde::{de, Deserialize, Deserializer, Serialize};

use super::error::LatticeWboError;

/// Owner for a cataloged `F-*` falsifier hook.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash, Serialize)]
#[serde(deny_unknown_fields)]
pub struct FalsifierHookOwner {
    pub hook: &'static str,
    pub owner: &'static str,
}

pub const FALSIFIER_HOOK_OWNERS: [FalsifierHookOwner; 4] = [
    FalsifierHookOwner {
        hook: "F-WBO-DriftLedger",
        owner: "docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md",
    },
    FalsifierHookOwner {
        hook: "F-ULP-Oracle",
        owner: "agent_core/src/research/eml/ulp_oracle.rs",
    },
    FalsifierHookOwner {
        hook: "F-KV-Direct-Gate",
        owner: "agent_core/src/scope_rex/kv/direct_gate.rs",
    },
    FalsifierHookOwner {
        hook: "F-ACS-AnchorLookup",
        owner: "agent_core/src/research/acs/mod.rs",
    },
];

pub const fn falsifier_hook_owners() -> &'static [FalsifierHookOwner] {
    &FALSIFIER_HOOK_OWNERS
}

impl<'de> Deserialize<'de> for FalsifierHookOwner {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        #[derive(Deserialize)]
        #[serde(deny_unknown_fields)]
        struct RawFalsifierHookOwner {
            hook: String,
            owner: String,
        }

        let raw = RawFalsifierHookOwner::deserialize(deserializer)?;
        FALSIFIER_HOOK_OWNERS
            .iter()
            .copied()
            .find(|owner| owner.hook == raw.hook && owner.owner == raw.owner)
            .ok_or_else(|| de::Error::custom(LatticeWboError::MissingCanonicalFalsifier.key()))
    }
}

pub(super) fn validate_nonnegative_finite(value: f64) -> Result<(), LatticeWboError> {
    if value.is_finite() && value >= 0.0 {
        Ok(())
    } else {
        Err(LatticeWboError::InvalidBudget)
    }
}

pub(super) fn contains_falsifier_hook(candidate: &str, canonical_hook: &str) -> bool {
    let canonical_hook = canonical_hook.trim();
    if canonical_hook.is_empty() {
        return false;
    }

    let mut search_start = 0;
    while let Some(relative_start) = candidate[search_start..].find(&canonical_hook) {
        let start = search_start + relative_start;
        let end = start + canonical_hook.len();
        let before = candidate[..start].chars().next_back();
        let after = candidate[end..].chars().next();
        if is_falsifier_hook_boundary(before) && is_falsifier_hook_boundary(after) {
            return true;
        }
        search_start = start + 1;
    }

    false
}

pub(super) fn is_falsifier_hook_boundary(ch: Option<char>) -> bool {
    ch.is_none_or(|ch| {
        ch.is_whitespace()
            || (ch.is_ascii()
                && !(ch.is_ascii_alphanumeric() || ch == '-' || ch == '_' || ch == '/'))
    })
}

pub(super) fn contains_any_falsifier_hook(candidate: &str, canonical: &str) -> bool {
    canonical
        .split(';')
        .map(str::trim)
        .filter(|hook| !hook.is_empty())
        .any(|hook| contains_falsifier_hook(candidate, hook))
}

pub(super) fn f_hooks_in(candidate: &str) -> Vec<&str> {
    let mut hooks = Vec::new();
    let bytes = candidate.as_bytes();
    let mut start = 0;

    while start + 1 < bytes.len() {
        if !((bytes[start] == b'F' || bytes[start] == b'f') && bytes[start + 1] == b'-') {
            start += 1;
            continue;
        }
        if !is_falsifier_hook_boundary(candidate[..start].chars().next_back()) {
            start += 1;
            continue;
        }

        let rest = &candidate[start..];
        let end = rest
            .find(|ch: char| is_falsifier_hook_boundary(Some(ch)))
            .unwrap_or(rest.len());
        hooks.push(&rest[..end]);
        start += end;
    }
    hooks
}

pub(super) fn falsifier_hooks_are_owned(candidate: &str) -> bool {
    let hooks = f_hooks_in(candidate);
    !hooks.is_empty()
        && hooks
            .into_iter()
            .all(|hook| FALSIFIER_HOOK_OWNERS.iter().any(|owner| owner.hook == hook))
}
