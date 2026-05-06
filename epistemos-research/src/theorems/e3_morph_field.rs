//! HELIOS V5 E3 — Storage-Disaggregated Morph Field.
//!
//! HELIOS-E3 guard
//!
//! `M_resident(t) ≤ M_core + M_state + M_active(t) + M_cache(t) +
//!  M_glue(t)`; resident scales with active patches not total
//! archive size.

use serde::{Deserialize, Serialize};

/// Storage budget components per the E3 inequality.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct MorphFieldBudget {
    pub m_core: u64,
    pub m_state: u64,
    pub m_active: u64,
    pub m_cache: u64,
    pub m_glue: u64,
}

impl MorphFieldBudget {
    /// Resident memory upper bound per the E3 inequality.
    pub fn resident_upper_bound(&self) -> u64 {
        self.m_core
            .saturating_add(self.m_state)
            .saturating_add(self.m_active)
            .saturating_add(self.m_cache)
            .saturating_add(self.m_glue)
    }
}

/// E3 invariant check: resident actual must not exceed the budget
/// upper bound.
pub fn e3_resident_within_budget(budget: &MorphFieldBudget, resident_actual: u64) -> bool {
    resident_actual <= budget.resident_upper_bound()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn upper_bound_is_sum_of_components() {
        let b = MorphFieldBudget {
            m_core: 100,
            m_state: 200,
            m_active: 300,
            m_cache: 400,
            m_glue: 500,
        };
        assert_eq!(b.resident_upper_bound(), 1500);
    }

    #[test]
    fn resident_within_budget_is_true_when_actual_below_bound() {
        let b = MorphFieldBudget {
            m_core: 100,
            m_state: 0,
            m_active: 0,
            m_cache: 0,
            m_glue: 0,
        };
        assert!(e3_resident_within_budget(&b, 50));
        assert!(e3_resident_within_budget(&b, 100));
        assert!(!e3_resident_within_budget(&b, 101));
    }
}
