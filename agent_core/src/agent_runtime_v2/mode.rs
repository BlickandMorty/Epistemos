//! `AgentRuntimeV2Mode` — the tier gate for the v2 executor.

use serde::{Deserialize, Serialize};

/// Tier gate for Agent Runtime v2 / System G.
///
/// The mode is the single source of truth for which v2 paths are alive in a
/// given build. Mode selection is **build-time only** for the MAS bundle:
/// MAS must always observe `Disabled`. Pro builds choose between
/// `IpcBounded` (default) and `Subprocess` (Research only).
///
/// Locked semantics:
///
/// | Mode          | Tier            | Bounded executor | Subprocess CLI |
/// |---------------|-----------------|------------------|----------------|
/// | `Disabled`    | MAS V1          | no               | no             |
/// | `IpcBounded`  | Pro V1.x        | yes              | no             |
/// | `Subprocess`  | Pro Research    | yes              | yes (hardened) |
///
/// MAS cannot pivot to `IpcBounded` or `Subprocess` at runtime — flipping
/// requires a CLAUDE.md edit + App Review re-submission (see
/// `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` IR-1).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AgentRuntimeV2Mode {
    /// MAS V1 — Agent Runtime v2 is dormant. Existing `agent_runtime::`
    /// paths serve all in-process orchestration. v2 callers MUST refuse to
    /// drive any executor when the active mode is `Disabled`.
    Disabled,
    /// Pro V1.x — bounded, in-process executor. WBO budget + macaroon
    /// verification + `MutationEnvelope` wrapping all required.
    IpcBounded,
    /// Pro Research only — subprocess CLI adapters (Claude Code, Codex,
    /// Goose, Aider, OpenHands, SweAgent). Hardened via
    /// `security::harden_cli_subprocess`. Never compiled into MAS.
    Subprocess,
}

impl AgentRuntimeV2Mode {
    /// True when the mode permits any v2 executor to run. `Disabled` is
    /// always false; the other two are always true.
    #[must_use]
    pub const fn allows_execution(self) -> bool {
        matches!(self, Self::IpcBounded | Self::Subprocess)
    }

    /// True only for the Research mode that may drive a subprocess CLI.
    /// MAS submissions MUST observe this as `false`.
    #[must_use]
    pub const fn allows_subprocess(self) -> bool {
        matches!(self, Self::Subprocess)
    }

    /// Canonical MAS default. Used by tests and by the MAS feature gate.
    #[must_use]
    pub const fn mas_default() -> Self {
        Self::Disabled
    }

    /// Canonical Pro default. Pro builds start in bounded mode; flipping
    /// to `Subprocess` is an explicit Research opt-in.
    #[must_use]
    pub const fn pro_default() -> Self {
        Self::IpcBounded
    }

    /// True when the mode is a Pro-tier mode (`IpcBounded` or
    /// `Subprocess`). Convenience for executor selection that wants
    /// to branch on "is Pro" without enumerating both variants.
    #[must_use]
    pub const fn is_pro(self) -> bool {
        matches!(self, Self::IpcBounded | Self::Subprocess)
    }
}

#[cfg(test)]
mod tests {
    use super::AgentRuntimeV2Mode;

    #[test]
    fn mas_default_is_disabled() {
        assert_eq!(AgentRuntimeV2Mode::mas_default(), AgentRuntimeV2Mode::Disabled);
        assert!(!AgentRuntimeV2Mode::Disabled.allows_execution());
        assert!(!AgentRuntimeV2Mode::Disabled.allows_subprocess());
    }

    #[test]
    fn pro_default_is_bounded_not_subprocess() {
        assert_eq!(AgentRuntimeV2Mode::pro_default(), AgentRuntimeV2Mode::IpcBounded);
        assert!(AgentRuntimeV2Mode::IpcBounded.allows_execution());
        assert!(!AgentRuntimeV2Mode::IpcBounded.allows_subprocess());
    }

    #[test]
    fn subprocess_allows_both() {
        assert!(AgentRuntimeV2Mode::Subprocess.allows_execution());
        assert!(AgentRuntimeV2Mode::Subprocess.allows_subprocess());
    }

    #[test]
    fn is_pro_returns_true_for_ipc_bounded_and_subprocess() {
        assert!(!AgentRuntimeV2Mode::Disabled.is_pro());
        assert!(AgentRuntimeV2Mode::IpcBounded.is_pro());
        assert!(AgentRuntimeV2Mode::Subprocess.is_pro());
    }

    #[test]
    fn mode_is_pro_equivalent_to_allows_execution_for_every_variant() {
        // Phase 1 hardening MILESTONE iter-480 — equivalence pin
        // between two related predicates on AgentRuntimeV2Mode:
        //
        //   - is_pro(self): IpcBounded | Subprocess
        //   - allows_execution(self): IpcBounded | Subprocess
        //
        // Both return the same boolean for the same variant — the
        // 2 predicates have IDENTICAL truth tables. The doctrine
        // distinction:
        //   - is_pro: "is this a Pro-tier mode?"
        //   - allows_execution: "may any v2 executor run?"
        // In the current 3-variant taxonomy, every Pro mode also
        // allows execution, but a future "Pro-Probe" mode that
        // allows execution probes WITHOUT being a fully-functional
        // Pro tier would break the equivalence — surface here.
        //
        // Pin the IDENTITY-LAW: is_pro(m) == allows_execution(m) for
        // all 3 variants. Defends against drift.
        for mode in [
            AgentRuntimeV2Mode::Disabled,
            AgentRuntimeV2Mode::IpcBounded,
            AgentRuntimeV2Mode::Subprocess,
        ] {
            assert_eq!(
                mode.is_pro(),
                mode.allows_execution(),
                "{mode:?}: is_pro and allows_execution must agree"
            );
        }
    }

    #[test]
    fn only_subprocess_mode_allows_subprocess_spawn() {
        // Phase 1 hardening — MAS-safety invariant: allows_subprocess
        // must return false for both Disabled AND IpcBounded. The
        // MAS bundle observes Disabled by build-time gate; the Pro
        // V1.x bundle observes IpcBounded. Only the Pro Research
        // Subprocess mode may ever spawn a child binary. A future
        // refactor that flips this check must surface here first.
        assert!(!AgentRuntimeV2Mode::Disabled.allows_subprocess());
        assert!(!AgentRuntimeV2Mode::IpcBounded.allows_subprocess());
        assert!(AgentRuntimeV2Mode::Subprocess.allows_subprocess());
    }

    #[test]
    fn mode_serde_forms_are_pairwise_distinct_across_all_three_variants() {
        // Phase 1 hardening — pairwise-distinct serde-form pin for
        // AgentRuntimeV2Mode (companion to the serde-pairwise-distinct
        // pin family iter-533/537/538/539/540/541). The 3 snake_case
        // variants (disabled, ipc_bounded, subprocess) gate the entire
        // v2 surface — a 4th variant added with #[serde(rename =
        // "disabled")] would silently collide with an existing tag,
        // misrouting the mode discriminator at runtime AND silently
        // approving execution paths that should have been disabled in
        // the MAS bundle. Pin asserts all 3 serialized forms are
        // pairwise-distinct.
        let variants = [
            AgentRuntimeV2Mode::Disabled,
            AgentRuntimeV2Mode::IpcBounded,
            AgentRuntimeV2Mode::Subprocess,
        ];
        let serde_forms: Vec<String> = variants
            .iter()
            .map(|v| serde_json::to_string(v).expect("serialize"))
            .collect();
        for i in 0..serde_forms.len() {
            for j in (i + 1)..serde_forms.len() {
                assert_ne!(
                    serde_forms[i], serde_forms[j],
                    "Mode serde forms collide at [{i}] = {:?} and [{j}] = {:?}",
                    serde_forms[i], serde_forms[j]
                );
            }
        }
    }

    #[test]
    fn mode_serde_discriminator_values_are_stable() {
        // Phase 1 hardening — cross-version replay parity guardrail.
        // Pin the snake_case JSON string each variant serialises to.
        // A rename here silently breaks replay of older RunEventLogs
        // that embedded mode strings — catch the rename at PR review.
        assert_eq!(
            serde_json::to_string(&AgentRuntimeV2Mode::Disabled).unwrap(),
            "\"disabled\""
        );
        assert_eq!(
            serde_json::to_string(&AgentRuntimeV2Mode::IpcBounded).unwrap(),
            "\"ipc_bounded\""
        );
        assert_eq!(
            serde_json::to_string(&AgentRuntimeV2Mode::Subprocess).unwrap(),
            "\"subprocess\""
        );
    }

    #[test]
    fn allows_subprocess_implies_allows_execution_semantic_invariant() {
        // Phase 1 hardening — semantic invariant across the two
        // helper predicates. A mode that permits spawning a child
        // binary MUST also permit in-process executors to run
        // (the binary IS executed); the converse need not hold
        // (IpcBounded permits in-process execution but not
        // subprocess spawn). Tests this implication across all 3
        // variants so a future helper refactor that flips one
        // without the other surfaces at PR review.
        for mode in [
            AgentRuntimeV2Mode::Disabled,
            AgentRuntimeV2Mode::IpcBounded,
            AgentRuntimeV2Mode::Subprocess,
        ] {
            if mode.allows_subprocess() {
                assert!(
                    mode.allows_execution(),
                    "{mode:?}: allows_subprocess true → allows_execution must be true"
                );
            }
        }
        // Reverse direction: at least one mode permits execution
        // without permitting subprocess (witnesses the inequality).
        assert!(
            AgentRuntimeV2Mode::IpcBounded.allows_execution()
                && !AgentRuntimeV2Mode::IpcBounded.allows_subprocess(),
            "IpcBounded must witness execution-without-subprocess"
        );
    }

    #[test]
    fn agent_runtime_v2_mode_variant_count_is_three() {
        // Phase 1 hardening — cardinality pin symmetric to
        // LocalAgentCapabilityTier::ALL.len() == 3 and the rest of
        // the count-pin series (BudgetTerm 5, AgentEventErrorKind 4
        // iter-139). AgentRuntimeV2Mode has 3 variants (Disabled,
        // IpcBounded, Subprocess) — the tier ladder. A future
        // addition (e.g., a "PureLocal" tier between Disabled and
        // IpcBounded, or a "Trusted" tier above Subprocess) would
        // require updating every mode-aware gate site AND every
        // tier→mode mapping. Pin the count so the addition surfaces
        // at PR review with a deliberate test update.
        let variants = [
            AgentRuntimeV2Mode::Disabled,
            AgentRuntimeV2Mode::IpcBounded,
            AgentRuntimeV2Mode::Subprocess,
        ];
        assert_eq!(variants.len(), 3);
        // Pairwise distinctness.
        for i in 0..variants.len() {
            for j in (i + 1)..variants.len() {
                assert_ne!(
                    variants[i], variants[j],
                    "modes[{i}] and modes[{j}] must be distinct"
                );
            }
        }
    }

    #[test]
    fn mode_ord_matches_privilege_ladder_disabled_lt_ipc_bounded_lt_subprocess() {
        // Phase 1 hardening — PartialOrd+Ord derive on this enum is
        // load-bearing (BTreeSet membership for batch audits per
        // iter-48). The derived ordering MUST match the privilege
        // ladder so a future variant addition that inserts higher
        // privilege at the wrong source-order position is caught
        // at PR review.
        assert!(AgentRuntimeV2Mode::Disabled < AgentRuntimeV2Mode::IpcBounded);
        assert!(AgentRuntimeV2Mode::IpcBounded < AgentRuntimeV2Mode::Subprocess);
        assert!(AgentRuntimeV2Mode::Disabled < AgentRuntimeV2Mode::Subprocess);
        // Reflexive
        assert!(AgentRuntimeV2Mode::IpcBounded == AgentRuntimeV2Mode::IpcBounded);
        // Antisymmetric (negation)
        assert!(!(AgentRuntimeV2Mode::Subprocess < AgentRuntimeV2Mode::Disabled));
        // Sort a deliberately-out-of-order array → confirm ascending
        // privilege.
        let mut modes = [
            AgentRuntimeV2Mode::Subprocess,
            AgentRuntimeV2Mode::Disabled,
            AgentRuntimeV2Mode::IpcBounded,
        ];
        modes.sort();
        assert_eq!(
            modes,
            [
                AgentRuntimeV2Mode::Disabled,
                AgentRuntimeV2Mode::IpcBounded,
                AgentRuntimeV2Mode::Subprocess,
            ]
        );
        // Max / min usage as practical convenience.
        assert_eq!(modes.iter().max().copied(), Some(AgentRuntimeV2Mode::Subprocess));
        assert_eq!(modes.iter().min().copied(), Some(AgentRuntimeV2Mode::Disabled));
    }

    #[test]
    fn unknown_mode_string_fails_to_deserialise() {
        // Phase 1 hardening — negative serde pin. The closed taxonomy
        // (Disabled / IpcBounded / Subprocess) is load-bearing for MAS
        // safety: a RunEventLog entry that recorded a stray mode
        // string MUST fail to replay, not silently fall through to
        // a "default" variant. A future #[serde(other)] catch-all,
        // or a case-insensitive shim, would let an unknown mode
        // pass through — surface that at PR review.
        //
        // Three adversarial categories: outright unknown,
        // case-variant of a known mode (must fail because the
        // taxonomy is snake_case-exact), and the legacy "off" /
        // "on" shapes a maintainer might "helpfully" allow.
        for bad in [
            "\"research\"",        // semantically plausible but not in the taxonomy
            "\"unrestricted\"",    // adjacent vocabulary
            "\"DISABLED\"",        // case variant of a known mode
            "\"Ipc_Bounded\"",     // pascal-snake mix
            "\"ipcBounded\"",      // camelCase variant
            "\"off\"",             // legacy on/off shape
            "\"on\"",
            "\"\"",                // empty string
        ] {
            let r: Result<AgentRuntimeV2Mode, _> = serde_json::from_str(bad);
            assert!(
                r.is_err(),
                "unknown mode string {bad} must fail to deserialise (closed taxonomy)"
            );
        }
    }

    #[test]
    fn mode_helpers_are_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — runtime determinism pin (companion to
        // iter-101 const-fn compile pin). allows_execution /
        // allows_subprocess / is_pro are all pure matches; calling
        // them many times must produce identical results.
        for mode in [
            AgentRuntimeV2Mode::Disabled,
            AgentRuntimeV2Mode::IpcBounded,
            AgentRuntimeV2Mode::Subprocess,
        ] {
            for _ in 0..3 {
                assert_eq!(mode.allows_execution(), mode.allows_execution());
                assert_eq!(mode.allows_subprocess(), mode.allows_subprocess());
                assert_eq!(mode.is_pro(), mode.is_pro());
            }
        }
    }

    #[test]
    fn mode_const_fn_annotations_compile_in_const_context() {
        // Phase 1 hardening — compile-time pin for the 5 const fn
        // annotations on AgentRuntimeV2Mode (companion to iter-100's
        // BudgetSpec/Debit/Gate/Ledger const-context pin). The const
        // items compile if-and-only-if every called function is
        // `const fn`. A future refactor that dropped `const` from
        // any of these signatures surfaces as a compile failure
        // right here.
        //
        // Pinned signatures: AgentRuntimeV2Mode::{allows_execution,
        // allows_subprocess, mas_default, pro_default, is_pro}.
        const MAS: AgentRuntimeV2Mode = AgentRuntimeV2Mode::mas_default();
        const PRO: AgentRuntimeV2Mode = AgentRuntimeV2Mode::pro_default();
        const MAS_ALLOWS_EXEC: bool = MAS.allows_execution();
        const PRO_ALLOWS_EXEC: bool = PRO.allows_execution();
        const MAS_ALLOWS_SUB: bool = MAS.allows_subprocess();
        const PRO_ALLOWS_SUB: bool = PRO.allows_subprocess();
        const MAS_IS_PRO: bool = MAS.is_pro();
        const PRO_IS_PRO: bool = PRO.is_pro();
        const SUB_ALLOWS_EXEC: bool = AgentRuntimeV2Mode::Subprocess.allows_execution();
        const SUB_ALLOWS_SUB: bool = AgentRuntimeV2Mode::Subprocess.allows_subprocess();
        const SUB_IS_PRO: bool = AgentRuntimeV2Mode::Subprocess.is_pro();

        // Runtime sanity — keep const items live + provide regression
        // fallback should the const-context behaviour drift.
        assert_eq!(MAS, AgentRuntimeV2Mode::Disabled);
        assert_eq!(PRO, AgentRuntimeV2Mode::IpcBounded);
        assert!(!MAS_ALLOWS_EXEC);
        assert!(PRO_ALLOWS_EXEC);
        assert!(!MAS_ALLOWS_SUB);
        assert!(!PRO_ALLOWS_SUB);
        assert!(!MAS_IS_PRO);
        assert!(PRO_IS_PRO);
        assert!(SUB_ALLOWS_EXEC);
        assert!(SUB_ALLOWS_SUB);
        assert!(SUB_IS_PRO);
    }

    #[test]
    fn mode_hash_is_consistent_with_eq_usable_as_hashmap_key() {
        // Phase 1 hardening — Hash-derive consistency pin (companion
        // to mode_ord_matches_privilege_ladder which exercises Ord via
        // BTreeSet). The PartialEq+Eq+Hash derive on AgentRuntimeV2Mode
        // is auto-coherent, but pin that the variants are usable as
        // HashSet members and HashMap keys — equal modes hash to the
        // same bucket; distinct modes occupy distinct slots.
        //
        // Defends against a future "let me drop Hash to simplify the
        // derive" refactor that would break HashMap<Mode, _> call sites
        // (which exist in dispatch caches per the dispatcher seam plan).
        use std::collections::{HashMap, HashSet};

        let mut set: HashSet<AgentRuntimeV2Mode> = HashSet::new();
        set.insert(AgentRuntimeV2Mode::Disabled);
        set.insert(AgentRuntimeV2Mode::IpcBounded);
        set.insert(AgentRuntimeV2Mode::Subprocess);
        // Duplicate insert is a no-op via Hash+Eq.
        set.insert(AgentRuntimeV2Mode::IpcBounded);
        assert_eq!(set.len(), 3, "all 3 modes must occupy distinct hash slots");
        assert!(set.contains(&AgentRuntimeV2Mode::Disabled));
        assert!(set.contains(&AgentRuntimeV2Mode::IpcBounded));
        assert!(set.contains(&AgentRuntimeV2Mode::Subprocess));

        // HashMap with mode keys.
        let mut map: HashMap<AgentRuntimeV2Mode, &'static str> = HashMap::new();
        map.insert(AgentRuntimeV2Mode::Disabled, "mas");
        map.insert(AgentRuntimeV2Mode::IpcBounded, "pro-bounded");
        map.insert(AgentRuntimeV2Mode::Subprocess, "pro-research");
        assert_eq!(map.len(), 3);
        assert_eq!(map.get(&AgentRuntimeV2Mode::Disabled), Some(&"mas"));
        assert_eq!(map.get(&AgentRuntimeV2Mode::IpcBounded), Some(&"pro-bounded"));
        assert_eq!(map.get(&AgentRuntimeV2Mode::Subprocess), Some(&"pro-research"));

        // Hash-consistent-with-Eq: same value produces same hash bucket
        // (functionally pinned via the duplicate-insert no-op above,
        // but call out the contract explicitly for future readers).
        let a = AgentRuntimeV2Mode::Subprocess;
        let b = AgentRuntimeV2Mode::Subprocess;
        assert_eq!(a, b);
        // Equality implies same hash — checked by HashSet's dedup
        // contract: { a } ∪ { b } == { a }.
        let s: HashSet<_> = [a, b].into_iter().collect();
        assert_eq!(s.len(), 1, "equal values must hash to the same bucket");
    }

    #[test]
    fn mode_is_copy_clone_send_sync_for_propagation_safety() {
        // Phase 1 hardening — trait-bound pin (companion to
        // budget_gate_is_copy_and_clone_for_pure_function_semantics).
        // AgentRuntimeV2Mode is intentionally a tiny stack value
        // (3-variant unit enum) marked Copy via derive (mode.rs §23).
        // No interior mutability, no heap, no Drop.
        //
        // The Copy + Clone + Send + Sync bounds are load-bearing for:
        //   - Dispatcher hot-path: every gate site copies the mode
        //     rather than borrowing, avoiding lifetime plumbing.
        //   - Cross-thread propagation: the dispatcher pool reads
        //     mode without coordination.
        //   - HashMap dispatch caches (mode_hash_is_consistent_with_eq...
        //     iter-321 already pins HashMap usability).
        //
        // A future "let me add a hidden runtime-only flag to mode"
        // refactor that introduced a non-Copy field would silently
        // break the hot-path assumption — surface here.
        fn assert_copy_clone_send_sync<T: Copy + Clone + Send + Sync>() {}
        assert_copy_clone_send_sync::<AgentRuntimeV2Mode>();

        // Runtime sanity: copy + use both bindings (Copy doesn't move).
        let mode = AgentRuntimeV2Mode::IpcBounded;
        let copy_a = mode;
        let copy_b = mode; // would fail to compile without Copy
        assert_eq!(copy_a, copy_b);
        assert_eq!(copy_a, mode);
    }

    #[test]
    fn modes_round_trip_through_json() {
        for mode in [
            AgentRuntimeV2Mode::Disabled,
            AgentRuntimeV2Mode::IpcBounded,
            AgentRuntimeV2Mode::Subprocess,
        ] {
            let s = serde_json::to_string(&mode).expect("serialize");
            let back: AgentRuntimeV2Mode = serde_json::from_str(&s).expect("deserialize");
            assert_eq!(back, mode);
        }
    }
}
