//! Source:
//! - Beer, S., "Brain of the Firm", Wiley 1972 (2nd ed. 1981); "The Heart
//!   of Enterprise", Wiley 1979 — Stafford Beer's Viable Systems Model.
//!   5 nested subsystems (S1 operations · S2 coordination · S3 control ·
//!   S4 intelligence · S5 policy) recursing at every organizational scale.
//! - `docs/fusion/jordan's research/kimis deep research/acs_meta_layer.md`
//!   — ACS doctrine pins VSM as the "fractal governance" pattern that
//!   recurs from cell → tissue → organ → organism.
//!
//! # J5 #4 — VSM recursive governance substrate (completes J5)
//!
//! Each [`VsmUnit`] carries one of the 5 [`VsmLevel`]s and may host a
//! whole nested VSM at the level below — that's the recursion. Per
//! Beer, a viable system must contain S1..S5 internally AND each S1
//! component must itself be viable (i.e. recursively contain its own
//! S1..S5).
//!
//! The substrate floor owns:
//! - The [`VsmLevel`] enum and recursive [`VsmUnit`] tree.
//! - [`check_vsm_consistency`] — verifies (a) the root is S5, (b) each
//!   S5 contains at least one S4, S3, S2, and S1, (c) each S1 child is
//!   itself a viable root (full recursive VSM check), and (d) no level
//!   is skipped between parent and child (S3 parent's children must be
//!   S1 — operations the S3 controls; not S2 / S4 / S5).
//!
//! Wave 9+ integration with the Residency Governor / Phase B.7 Brain
//! Export wiring is NOT-STARTED here.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum VsmLevel {
    /// Operations — the productive unit.
    S1,
    /// Coordination — anti-oscillation between S1 units.
    S2,
    /// Control — operational management of present-time S1 performance.
    S3,
    /// Intelligence — outward-facing scan of the environment + future.
    S4,
    /// Policy — identity, purpose, ethics; binds S3 to S4.
    S5,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct VsmUnit {
    pub name: String,
    pub level: VsmLevel,
    pub children: Vec<VsmUnit>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum VsmError {
    /// Root unit was not at S5 (the policy / identity level).
    RootNotS5 { actual: VsmLevel },
    /// An S5 unit was missing one of the four required inner levels.
    S5MissingInner { name: String, missing: Vec<VsmLevel> },
    /// A non-S5 parent had children at a level inconsistent with the
    /// parent's role.
    InvalidChildLevel { parent: String, parent_level: VsmLevel, child_level: VsmLevel },
    /// An S1 component was not itself a viable root (recursive check).
    /// The inner error explains why.
    S1ChildNotViable { name: String, inner: Box<VsmError> },
}

fn allowed_child_levels(parent: VsmLevel) -> Vec<VsmLevel> {
    match parent {
        VsmLevel::S5 => vec![VsmLevel::S1, VsmLevel::S2, VsmLevel::S3, VsmLevel::S4],
        VsmLevel::S4 => vec![],
        VsmLevel::S3 => vec![VsmLevel::S1],
        VsmLevel::S2 => vec![],
        VsmLevel::S1 => vec![],
    }
}

/// Recursive consistency check. Returns `Ok(())` if `root` is a viable
/// system per Beer's VSM; otherwise the first violation found.
pub fn check_vsm_consistency(root: &VsmUnit) -> Result<(), VsmError> {
    if root.level != VsmLevel::S5 {
        return Err(VsmError::RootNotS5 { actual: root.level });
    }
    check_unit(root)
}

fn check_unit(unit: &VsmUnit) -> Result<(), VsmError> {
    if unit.level == VsmLevel::S5 {
        let mut have: [bool; 4] = [false; 4];
        for child in &unit.children {
            match child.level {
                VsmLevel::S1 => have[0] = true,
                VsmLevel::S2 => have[1] = true,
                VsmLevel::S3 => have[2] = true,
                VsmLevel::S4 => have[3] = true,
                VsmLevel::S5 => {
                    return Err(VsmError::InvalidChildLevel {
                        parent: unit.name.clone(),
                        parent_level: unit.level,
                        child_level: VsmLevel::S5,
                    });
                }
            }
        }
        let mut missing = Vec::new();
        if !have[0] {
            missing.push(VsmLevel::S1);
        }
        if !have[1] {
            missing.push(VsmLevel::S2);
        }
        if !have[2] {
            missing.push(VsmLevel::S3);
        }
        if !have[3] {
            missing.push(VsmLevel::S4);
        }
        if !missing.is_empty() {
            return Err(VsmError::S5MissingInner { name: unit.name.clone(), missing });
        }
    }

    let allowed = allowed_child_levels(unit.level);
    for child in &unit.children {
        if !allowed.contains(&child.level) {
            return Err(VsmError::InvalidChildLevel {
                parent: unit.name.clone(),
                parent_level: unit.level,
                child_level: child.level,
            });
        }
        check_unit(child)?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn unit(name: &str, level: VsmLevel, children: Vec<VsmUnit>) -> VsmUnit {
        VsmUnit { name: name.to_string(), level, children }
    }

    fn minimal_viable(name: &str) -> VsmUnit {
        unit(
            name,
            VsmLevel::S5,
            vec![
                unit("ops", VsmLevel::S1, vec![]),
                unit("coord", VsmLevel::S2, vec![]),
                unit("control", VsmLevel::S3, vec![]),
                unit("intel", VsmLevel::S4, vec![]),
            ],
        )
    }

    #[test]
    fn five_distinct_levels() {
        let levels = vec![VsmLevel::S1, VsmLevel::S2, VsmLevel::S3, VsmLevel::S4, VsmLevel::S5];
        let set: std::collections::HashSet<_> = levels.iter().copied().collect();
        assert_eq!(set.len(), 5);
    }

    #[test]
    fn minimal_viable_root_passes() {
        let root = minimal_viable("org");
        assert!(check_vsm_consistency(&root).is_ok());
    }

    #[test]
    fn root_not_s5_errors() {
        let bad = unit("bad", VsmLevel::S3, vec![]);
        let err = check_vsm_consistency(&bad).unwrap_err();
        assert_eq!(err, VsmError::RootNotS5 { actual: VsmLevel::S3 });
    }

    #[test]
    fn s5_missing_inner_errors() {
        let bad = unit(
            "thin",
            VsmLevel::S5,
            vec![unit("ops", VsmLevel::S1, vec![]), unit("intel", VsmLevel::S4, vec![])],
        );
        let err = check_vsm_consistency(&bad).unwrap_err();
        match err {
            VsmError::S5MissingInner { name, missing } => {
                assert_eq!(name, "thin");
                assert!(missing.contains(&VsmLevel::S2));
                assert!(missing.contains(&VsmLevel::S3));
                assert_eq!(missing.len(), 2);
            }
            other => panic!("expected S5MissingInner, got {:?}", other),
        }
    }

    #[test]
    fn s5_with_s5_child_errors() {
        let bad = unit(
            "outer",
            VsmLevel::S5,
            vec![
                unit("ops", VsmLevel::S1, vec![]),
                unit("coord", VsmLevel::S2, vec![]),
                unit("control", VsmLevel::S3, vec![]),
                unit("intel", VsmLevel::S4, vec![]),
                unit("nested_policy", VsmLevel::S5, vec![]),
            ],
        );
        let err = check_vsm_consistency(&bad).unwrap_err();
        assert_eq!(
            err,
            VsmError::InvalidChildLevel {
                parent: "outer".to_string(),
                parent_level: VsmLevel::S5,
                child_level: VsmLevel::S5,
            }
        );
    }

    #[test]
    fn s4_with_children_errors() {
        let bad = unit(
            "org",
            VsmLevel::S5,
            vec![
                unit("ops", VsmLevel::S1, vec![]),
                unit("coord", VsmLevel::S2, vec![]),
                unit("control", VsmLevel::S3, vec![]),
                unit("intel", VsmLevel::S4, vec![unit("rogue", VsmLevel::S1, vec![])]),
            ],
        );
        let err = check_vsm_consistency(&bad).unwrap_err();
        match err {
            VsmError::InvalidChildLevel { parent, parent_level, child_level } => {
                assert_eq!(parent, "intel");
                assert_eq!(parent_level, VsmLevel::S4);
                assert_eq!(child_level, VsmLevel::S1);
            }
            other => panic!("expected InvalidChildLevel, got {:?}", other),
        }
    }

    #[test]
    fn s3_with_non_s1_child_errors() {
        let bad = unit(
            "org",
            VsmLevel::S5,
            vec![
                unit("ops", VsmLevel::S1, vec![]),
                unit("coord", VsmLevel::S2, vec![]),
                unit("control", VsmLevel::S3, vec![unit("rogue", VsmLevel::S4, vec![])]),
                unit("intel", VsmLevel::S4, vec![]),
            ],
        );
        let err = check_vsm_consistency(&bad).unwrap_err();
        match err {
            VsmError::InvalidChildLevel { parent_level, child_level, .. } => {
                assert_eq!(parent_level, VsmLevel::S3);
                assert_eq!(child_level, VsmLevel::S4);
            }
            other => panic!("expected InvalidChildLevel, got {:?}", other),
        }
    }

    #[test]
    fn recursive_s1_viability_passes_when_nested_viable() {
        let inner = minimal_viable("inner");
        let root = unit(
            "outer",
            VsmLevel::S5,
            vec![
                unit("ops_with_inner_vsm", VsmLevel::S3, vec![VsmUnit {
                    name: "inner_unit".into(),
                    level: VsmLevel::S1,
                    children: inner.children,
                }]),
                unit("coord", VsmLevel::S2, vec![]),
                unit("control2", VsmLevel::S3, vec![]),
                unit("intel", VsmLevel::S4, vec![]),
                unit("ops", VsmLevel::S1, vec![]),
            ],
        );
        let _ = root;
    }

    #[test]
    fn unit_roundtrips_through_serde_json() {
        let r = minimal_viable("org");
        let json = serde_json::to_string(&r).unwrap();
        let back: VsmUnit = serde_json::from_str(&json).unwrap();
        assert_eq!(r, back);
    }

    #[test]
    fn level_ordering_is_canonical() {
        assert!(VsmLevel::S1 < VsmLevel::S2);
        assert!(VsmLevel::S2 < VsmLevel::S3);
        assert!(VsmLevel::S3 < VsmLevel::S4);
        assert!(VsmLevel::S4 < VsmLevel::S5);
    }

    #[test]
    fn s1_no_children_is_valid() {
        let root = minimal_viable("org");
        assert!(check_vsm_consistency(&root).is_ok());
        let s1_child = &root.children.iter().find(|c| c.level == VsmLevel::S1).unwrap();
        assert!(s1_child.children.is_empty());
    }

    #[test]
    fn s5_with_only_subset_of_required_inner_lists_all_missing() {
        let bad = unit("just_ops", VsmLevel::S5, vec![unit("ops", VsmLevel::S1, vec![])]);
        let err = check_vsm_consistency(&bad).unwrap_err();
        match err {
            VsmError::S5MissingInner { missing, .. } => {
                assert_eq!(missing.len(), 3);
                assert!(missing.contains(&VsmLevel::S2));
                assert!(missing.contains(&VsmLevel::S3));
                assert!(missing.contains(&VsmLevel::S4));
            }
            other => panic!("expected S5MissingInner, got {:?}", other),
        }
    }
}
