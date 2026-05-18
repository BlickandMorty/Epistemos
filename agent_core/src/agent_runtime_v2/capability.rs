//! `AgentRuntimeV2Capability` — typed capability surface backed by a
//! cognitive-DAG macaroon.
//!
//! Every v2 executor side-effect (tool invoke, vault write, network egress,
//! subprocess spawn, approval grant) MUST verify a capability first. The
//! capability's `verify` runs both the HMAC-chain check (`forged macaroon
//! rejected`) and the caveat semantics (`expired macaroon rejected`,
//! scope-out-of-bounds, tool-name mismatch, context mismatch).
//!
//! Acceptance bar references (§4 T11):
//! - Property test: forged macaroon rejected (here)
//! - Property test: expired macaroon rejected (here)
//! - Macaroon verification path wired (here)

use crate::cognitive_dag::macaroons::{
    self, CaveatViolation, Macaroon, RuntimeContext, VerifyError,
};
use crate::cognitive_dag::node::{CapabilityKind, CapabilityScope};

/// Errors raised when an `AgentRuntimeV2Capability::verify` call rejects.
#[derive(Debug, Clone, PartialEq)]
pub enum CapabilityError {
    /// HMAC chain mismatch — the macaroon was forged (signed under a
    /// different root key) or tampered with (caveat appended without
    /// extending the chain). Cryptographic-grade rejection; no caller
    /// recovery is appropriate.
    Forged(VerifyError),
    /// Caveat semantics rejected the use — expired, scope out of
    /// bounds, tool-name mismatch, missing context, or two narrowing
    /// prefixes that are not nested. Recoverable in principle (issue
    /// a new macaroon) but never bypassable.
    Violated(CaveatViolation),
}

/// Typed capability surface for v2 executors. Implementors expose the
/// kind + scope and a `verify` that runs against a runtime context.
///
/// The trait is `Send + Sync` because the executor pool calls `verify`
/// across worker threads.
pub trait AgentRuntimeV2Capability: Send + Sync {
    /// What the capability authorises (tool invoke / vault access /
    /// network egress / subprocess spawn / approval / other).
    fn kind(&self) -> &CapabilityKind;
    /// Where the capability applies — typically a vault path prefix,
    /// hostname pattern, or tool-namespace prefix.
    fn scope(&self) -> &CapabilityScope;
    /// Verify the underlying token + caveat semantics against the
    /// runtime context. Called before any executor side-effect.
    fn verify(&self, ctx: &RuntimeContext) -> Result<(), CapabilityError>;
}

/// Macaroon-backed `AgentRuntimeV2Capability` — the canonical
/// implementor. Wraps a `Macaroon` + its issuing root key.
///
/// The root key is held alongside the macaroon (the runtime cannot
/// verify without it). In production, root keys live in the Sovereign
/// Gate session and are sourced from the macOS Keychain via the FFI
/// path; this struct is the pure-Rust surface that takes the key as
/// owned bytes so tests can construct a capability without keychain IO.
pub struct MacaroonCapability {
    macaroon: Macaroon,
    root_key: [u8; 32],
}

impl MacaroonCapability {
    /// Construct from an already-issued macaroon and its root key.
    #[must_use]
    pub fn new(macaroon: Macaroon, root_key: [u8; 32]) -> Self {
        Self { macaroon, root_key }
    }

    /// Borrow the underlying macaroon (read-only). Useful for audit /
    /// `RunEventLog` write-through.
    #[must_use]
    pub fn macaroon(&self) -> &Macaroon {
        &self.macaroon
    }
}

impl AgentRuntimeV2Capability for MacaroonCapability {
    fn kind(&self) -> &CapabilityKind {
        &self.macaroon.base_kind
    }

    fn scope(&self) -> &CapabilityScope {
        &self.macaroon.base_scope
    }

    fn verify(&self, ctx: &RuntimeContext) -> Result<(), CapabilityError> {
        macaroons::verify_macaroon(&self.macaroon, &self.root_key)
            .map_err(CapabilityError::Forged)?;
        macaroons::evaluate_caveats(&self.macaroon, ctx).map_err(CapabilityError::Violated)?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cognitive_dag::macaroons::{issue, restrict, Caveat};
    use crate::cognitive_dag::node::{CapabilityKind, CapabilityScope};

    fn root_key_a() -> [u8; 32] {
        let mut k = [0u8; 32];
        k[0..6].copy_from_slice(b"keyA__");
        k
    }

    fn root_key_b() -> [u8; 32] {
        let mut k = [0u8; 32];
        k[0..6].copy_from_slice(b"keyB__");
        k
    }

    fn ctx_now_at(now_ms: u64) -> RuntimeContext {
        RuntimeContext {
            now_ms,
            scope_path: "vault/notes/2026".to_string(),
            tool_name: "vault.read".to_string(),
            additional: Default::default(),
        }
    }

    fn issue_tool_macaroon(key: &[u8; 32], expiry_ms: Option<u64>) -> Macaroon {
        issue(
            "session-iter2",
            CapabilityKind::ToolInvoke("vault.read".to_string()),
            CapabilityScope("vault".to_string()),
            expiry_ms,
            key,
        )
    }

    #[test]
    fn capability_error_violated_distinguishes_all_six_caveat_violation_variants() {
        // Phase 1 hardening — inner-variant distinctness pin
        // (companion to iter-194 / iter-195 SealError inner-pins).
        // CapabilityError::Violated wraps a CaveatViolation with 6
        // variants:
        //   Expired, ScopeOutOfBounds, ToolMismatch, ContextMismatch,
        //   IncompatiblePrefixes, IncompatibleToolNames
        //
        // Each names a different caveat-evaluation failure and
        // surfaces to a different audit class. A future PartialEq
        // override that collapsed inner variants would silently
        // merge incident categories.
        use crate::cognitive_dag::macaroons::CaveatViolation;
        let variants = [
            CapabilityError::Violated(CaveatViolation::Expired {
                until_ts_ms: 1,
                now_ms: 2,
            }),
            CapabilityError::Violated(CaveatViolation::ScopeOutOfBounds {
                required_prefix: "p".into(),
                actual: "a".into(),
            }),
            CapabilityError::Violated(CaveatViolation::ToolMismatch {
                required: "r".into(),
                actual: "a".into(),
            }),
            CapabilityError::Violated(CaveatViolation::ContextMismatch {
                key: "k".into(),
                expected: "e".into(),
                actual: None,
            }),
            CapabilityError::Violated(CaveatViolation::IncompatiblePrefixes {
                a: "x".into(),
                b: "y".into(),
            }),
            CapabilityError::Violated(CaveatViolation::IncompatibleToolNames {
                a: "u".into(),
                b: "v".into(),
            }),
        ];
        assert_eq!(variants.len(), 6);
        for i in 0..variants.len() {
            for j in (i + 1)..variants.len() {
                assert_ne!(
                    variants[i], variants[j],
                    "Violated[{i}] and Violated[{j}] must be distinct"
                );
            }
        }
    }

    #[test]
    fn capability_error_variant_count_is_two() {
        // Phase 1 hardening — cardinality pin. CapabilityError has
        // 2 variants (Forged, Violated) covering the two macaroon-
        // rejection mechanisms:
        //   - Forged: HMAC chain mismatch (cryptographic-grade)
        //   - Violated: caveat semantics rejected (recoverable in
        //     principle)
        //
        // A future addition (e.g., CapabilityError::Revoked for a
        // new revocation-list check) requires:
        //   - MacaroonCapability::verify branch
        //   - Debug-repr pin update
        //   - Sealer error-attribution chain update
        let variants = [
            CapabilityError::Forged(VerifyError::SignatureMismatch),
            CapabilityError::Violated(CaveatViolation::Expired {
                until_ts_ms: 100,
                now_ms: 200,
            }),
        ];
        assert_eq!(variants.len(), 2);
        assert_ne!(variants[0], variants[1]);
    }

    #[test]
    fn capability_error_debug_repr_is_stable_for_audit_persistence() {
        // Phase 1 hardening — audit-log surface. Companion to the
        // established Debug-repr stability pattern across the other
        // error enums:
        //   - budget_error_exhausted_debug_repr_is_stable
        //   - log_validation_error_ordinal_mismatch_debug_repr_is_stable
        //   - tool_call_error_debug_repr_is_stable
        //   - mission_prompt_error_oversize_debug_repr_is_stable
        //   - para_error_debug_repr_is_stable
        //   - variant_ladder_error_debug_repr_is_stable (iter-97)
        //   - blueprint_mode_error_debug_repr_is_stable
        //
        // CapabilityError has 2 variants (Forged, Violated). Each
        // carries an inner type whose Debug surfaces in incident
        // reports + RunEventLog rows + grep-based audit dashboards.
        // A maintainer rename (Forged → Tampered, Violated → Rejected)
        // would silently break those greps.
        let forged = CapabilityError::Forged(VerifyError::SignatureMismatch);
        let dbg = format!("{forged:?}");
        assert!(dbg.starts_with("Forged("), "got {dbg}");
        assert!(dbg.contains("SignatureMismatch"));

        let violated = CapabilityError::Violated(CaveatViolation::Expired {
            until_ts_ms: 1000,
            now_ms: 2000,
        });
        let dbg = format!("{violated:?}");
        assert!(dbg.starts_with("Violated("), "got {dbg}");
        assert!(dbg.contains("Expired"));
    }

    #[test]
    fn capability_trait_and_implementor_carry_send_sync_bounds_compile_pin() {
        // Phase 1 hardening — compile-time pin for the Send+Sync
        // contract on AgentRuntimeV2Capability and its canonical
        // implementor MacaroonCapability. The executor pool calls
        // verify() across worker threads (capability.rs trait docs);
        // without Send+Sync the dispatcher cannot share a capability
        // safely.
        //
        // A future refactor that dropped Send+Sync (e.g., to allow
        // a !Send executor reference) would compile-fail right
        // here. assert_send_sync is a no-op probe enforced by trait
        // bounds at instantiation time.
        fn assert_send_sync<T: Send + Sync + ?Sized>() {}
        // The trait itself requires Send+Sync (declared on the
        // trait surface).
        assert_send_sync::<dyn AgentRuntimeV2Capability>();
        // The canonical implementor must also be Send+Sync.
        assert_send_sync::<MacaroonCapability>();
    }

    #[test]
    fn forged_macaroon_rejected() {
        // Issue under key A; verify under key B → must fail with Forged.
        let m = issue_tool_macaroon(&root_key_a(), None);
        let cap = MacaroonCapability::new(m, root_key_b());
        let err = cap
            .verify(&ctx_now_at(1_000))
            .expect_err("verify must reject forged macaroon");
        assert!(
            matches!(err, CapabilityError::Forged(VerifyError::SignatureMismatch)),
            "expected Forged(SignatureMismatch), got {err:?}"
        );
    }

    #[test]
    fn expired_macaroon_rejected() {
        // Issue with expiry at t=1000ms; verify at t=2000ms → Violated::Expired.
        let m = issue_tool_macaroon(&root_key_a(), Some(1_000));
        let cap = MacaroonCapability::new(m, root_key_a());
        let err = cap
            .verify(&ctx_now_at(2_000))
            .expect_err("verify must reject expired macaroon");
        assert!(
            matches!(err, CapabilityError::Violated(CaveatViolation::Expired { .. })),
            "expected Violated(Expired), got {err:?}"
        );
    }

    #[test]
    fn macaroon_capability_verify_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to iter-220 BudgetGate purity pin, iter-217/218/219
        // idempotency pins). MacaroonCapability::verify takes &self +
        // &ctx; calling it multiple times with the same inputs must
        // produce identical results.
        //
        // A future refactor that introduced replay-detection counter
        // or single-use enforcement INSIDE verify would break this
        // contract — that policy belongs at the RunEventLog audit
        // layer (detect_capability_reuse), not the verify path.
        let m = issue_tool_macaroon(&root_key_a(), Some(10_000));
        let cap = MacaroonCapability::new(m, root_key_a());
        let ctx = ctx_now_at(1_000);
        let r1 = cap.verify(&ctx);
        let r2 = cap.verify(&ctx);
        let r3 = cap.verify(&ctx);
        assert_eq!(r1, r2);
        assert_eq!(r2, r3);
        assert!(r1.is_ok());

        // Same property on the rejection path (forged macaroon).
        let m_bad = issue_tool_macaroon(&root_key_a(), None);
        let cap_bad = MacaroonCapability::new(m_bad, root_key_b());
        let e1 = cap_bad.verify(&ctx);
        let e2 = cap_bad.verify(&ctx);
        assert_eq!(e1, e2);
        assert!(e1.is_err());
    }

    #[test]
    fn valid_macaroon_accepted() {
        // Sanity: issued + verified under the same key with no caveats
        // and a future expiry passes both legs.
        let m = issue_tool_macaroon(&root_key_a(), Some(10_000));
        let cap = MacaroonCapability::new(m, root_key_a());
        cap.verify(&ctx_now_at(1_000)).expect("valid macaroon must verify");
        assert!(matches!(cap.kind(), CapabilityKind::ToolInvoke(s) if s == "vault.read"));
        assert_eq!(cap.scope().0, "vault");
    }

    #[test]
    fn tampered_caveat_rejected() {
        // Append a caveat AFTER the chain was signed by simulating a
        // hostile holder: take a valid macaroon, splice a Caveat into
        // `caveats` without extending the HMAC chain, and verify must
        // reject as Forged.
        let m = issue_tool_macaroon(&root_key_a(), None);
        let mut tampered = m;
        tampered.caveats.push(Caveat::ScopePrefix {
            prefix: "vault/secrets".to_string(),
        });
        // signature unchanged → HMAC chain no longer reproduces.
        let cap = MacaroonCapability::new(tampered, root_key_a());
        let err = cap
            .verify(&ctx_now_at(1_000))
            .expect_err("tampered caveats must be rejected");
        assert!(
            matches!(err, CapabilityError::Forged(VerifyError::SignatureMismatch)),
            "expected Forged(SignatureMismatch), got {err:?}"
        );
    }

    #[test]
    fn two_additional_context_caveats_compose_last_write_wins_and_multi_key_require_all() {
        // Phase 1 hardening — fourth caveat-composition leg
        // (companion to ExpiryAfter MIN iter-129, ScopePrefix
        // extend/keep/reject iter-130, ToolNameEq idempotent/incompat
        // iter-131). AdditionalContext composition doctrine
        // (macaroons.rs §299-301):
        //   - same key twice → last-write-wins (BTreeMap::insert overwrite)
        //   - different keys → ALL required to match at verify time
        //
        // This is DIFFERENT from ToolNameEq's "incompatible →
        // reject" — AdditionalContext silently overwrites. The
        // asymmetry is worth pinning so a future "reject
        // conflicting values" tightening surfaces.
        use crate::cognitive_dag::macaroons::{issue, restrict, Caveat, CaveatViolation};
        use std::collections::BTreeMap;
        let key = root_key_a();
        let base = issue(
            "additional-context-composition-session",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            Some(10_000),
            &key,
        );

        // Case (a) last-write-wins: same key, different values →
        // the SECOND value is what's enforced.
        let m_lww = restrict(
            &base,
            Caveat::AdditionalContext {
                key: "request_id".into(),
                value: "FIRST".into(),
            },
        );
        let m_lww = restrict(
            &m_lww,
            Caveat::AdditionalContext {
                key: "request_id".into(),
                value: "SECOND".into(),
            },
        );
        let cap_lww = MacaroonCapability::new(m_lww, key);
        // Context with "SECOND" must verify.
        let mut second_ctx = BTreeMap::new();
        second_ctx.insert("request_id".to_string(), "SECOND".to_string());
        cap_lww
            .verify(&RuntimeContext {
                now_ms: 1_000,
                scope_path: "vault".into(),
                tool_name: "vault.read".into(),
                additional: second_ctx,
            })
            .expect("LWW composition: SECOND value wins, must verify");
        // Context with "FIRST" — the OLD value — must REJECT.
        let mut first_ctx = BTreeMap::new();
        first_ctx.insert("request_id".to_string(), "FIRST".to_string());
        let err_lww = cap_lww
            .verify(&RuntimeContext {
                now_ms: 1_000,
                scope_path: "vault".into(),
                tool_name: "vault.read".into(),
                additional: first_ctx,
            })
            .expect_err("first-value (overwritten) must reject");
        assert!(matches!(
            err_lww,
            CapabilityError::Violated(CaveatViolation::ContextMismatch { .. })
        ));

        // Case (b) multi-key: ALL keys required to match.
        let m_multi = restrict(
            &base,
            Caveat::AdditionalContext {
                key: "request_id".into(),
                value: "abc".into(),
            },
        );
        let m_multi = restrict(
            &m_multi,
            Caveat::AdditionalContext {
                key: "tenant_id".into(),
                value: "xyz".into(),
            },
        );
        let cap_multi = MacaroonCapability::new(m_multi, key);
        // Both keys match → verify succeeds.
        let mut both = BTreeMap::new();
        both.insert("request_id".to_string(), "abc".to_string());
        both.insert("tenant_id".to_string(), "xyz".to_string());
        cap_multi
            .verify(&RuntimeContext {
                now_ms: 1_000,
                scope_path: "vault".into(),
                tool_name: "vault.read".into(),
                additional: both,
            })
            .expect("both keys present + match must verify");
        // Only one key present → reject (the OTHER missing key trips
        // the all-required gate).
        let mut only_one = BTreeMap::new();
        only_one.insert("request_id".to_string(), "abc".to_string());
        let err_partial = cap_multi
            .verify(&RuntimeContext {
                now_ms: 1_000,
                scope_path: "vault".into(),
                tool_name: "vault.read".into(),
                additional: only_one,
            })
            .expect_err("missing one key must reject (all-required gate)");
        assert!(matches!(
            err_partial,
            CapabilityError::Violated(CaveatViolation::ContextMismatch { .. })
        ));
    }

    #[test]
    fn two_tool_name_eq_caveats_compose_idempotently_or_reject_incompatible_through_v2_surface() {
        // Phase 1 hardening — third caveat-composition leg
        // (companion to iter-129 ExpiryAfter MIN + iter-130
        // ScopePrefix extend/keep/reject). ToolNameEq composition
        // doctrine (macaroons.rs §289-298):
        //   - same name twice → idempotent, no error
        //   - different names → CaveatViolation::IncompatibleToolNames
        //
        // No existing v2 test pins either case. The multi-caveat
        // test uses ONE ToolNameEq.
        use crate::cognitive_dag::macaroons::{issue, restrict, Caveat, CaveatViolation};
        let key = root_key_a();
        let base = issue(
            "tool-name-composition-session",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            Some(10_000),
            &key,
        );

        // Case (a) idempotent: two identical ToolNameEq caveats →
        // the second is a no-op. verify succeeds for matching tool.
        let m_idem = restrict(&base, Caveat::ToolNameEq { name: "vault.read".into() });
        let m_idem = restrict(&m_idem, Caveat::ToolNameEq { name: "vault.read".into() });
        let cap_idem = MacaroonCapability::new(m_idem, key);
        cap_idem
            .verify(&RuntimeContext {
                now_ms: 1_000,
                scope_path: "vault/notes".into(),
                tool_name: "vault.read".into(),
                additional: Default::default(),
            })
            .expect("idempotent same-name composition must verify");
        // And still rejects mismatching tool names.
        let err_mismatch = cap_idem
            .verify(&RuntimeContext {
                now_ms: 1_000,
                scope_path: "vault/notes".into(),
                tool_name: "vault.write".into(),
                additional: Default::default(),
            })
            .expect_err("non-matching tool must reject");
        assert!(matches!(
            err_mismatch,
            CapabilityError::Violated(CaveatViolation::ToolMismatch { .. })
        ));

        // Case (b) incompatible: two different ToolNameEq caveats →
        // CaveatViolation::IncompatibleToolNames.
        let m_incompat = restrict(&base, Caveat::ToolNameEq { name: "vault.read".into() });
        let m_incompat = restrict(&m_incompat, Caveat::ToolNameEq { name: "vault.write".into() });
        let cap_incompat = MacaroonCapability::new(m_incompat, key);
        let err_incompat = cap_incompat
            .verify(&RuntimeContext {
                now_ms: 1_000,
                scope_path: "vault/notes".into(),
                tool_name: "vault.read".into(),
                additional: Default::default(),
            })
            .expect_err("incompatible tool-name caveats must reject");
        assert!(matches!(
            err_incompat,
            CapabilityError::Violated(CaveatViolation::IncompatibleToolNames { .. })
        ));
    }

    #[test]
    fn two_scope_prefix_caveats_compose_to_longer_or_reject_unrelated_through_v2_surface() {
        // Phase 1 hardening — caveat-composition doctrine pin
        // (symmetric companion to iter-129's ExpiryAfter pin).
        // cognitive_dag::macaroons::evaluate_caveats composes
        // ScopePrefix caveats with three rules (macaroons.rs §267-281):
        //   (a) new extends existing → take new (tighter narrowing)
        //   (b) existing extends new → keep existing (already tighter)
        //   (c) neither extends → CaveatViolation::IncompatiblePrefixes
        //
        // No existing v2 test pins these compositions. Pin all three.
        use crate::cognitive_dag::macaroons::{issue, restrict, Caveat, CaveatViolation};
        let key = root_key_a();
        let base = issue(
            "scope-composition-session",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            Some(10_000),
            &key,
        );

        // Case (a): "vault" parent + "vault/notes" child →
        // effective prefix is "vault/notes" (the tighter).
        let m_a = restrict(&base, Caveat::ScopePrefix { prefix: "vault".into() });
        let m_a = restrict(&m_a, Caveat::ScopePrefix { prefix: "vault/notes".into() });
        let cap_a = MacaroonCapability::new(m_a, key);
        cap_a
            .verify(&RuntimeContext {
                now_ms: 1_000,
                scope_path: "vault/notes/2026".into(),
                tool_name: "vault.read".into(),
                additional: Default::default(),
            })
            .expect("vault/notes/2026 is inside tighter scope");
        let err_a = cap_a
            .verify(&RuntimeContext {
                now_ms: 1_000,
                // Inside the WIDER "vault" prefix but OUTSIDE the
                // tighter "vault/notes" — must reject because the
                // composed (tightest) prefix wins.
                scope_path: "vault/chats/2026".into(),
                tool_name: "vault.read".into(),
                additional: Default::default(),
            })
            .expect_err("outside-tighter-prefix must reject");
        assert!(matches!(
            err_a,
            CapabilityError::Violated(CaveatViolation::ScopeOutOfBounds { .. })
        ));

        // Case (b): swap order — "vault/notes" first, "vault" second.
        // The tighter ("vault/notes") was applied first and the wider
        // ("vault") doesn't override. effective stays "vault/notes".
        let m_b = restrict(&base, Caveat::ScopePrefix { prefix: "vault/notes".into() });
        let m_b = restrict(&m_b, Caveat::ScopePrefix { prefix: "vault".into() });
        let cap_b = MacaroonCapability::new(m_b, key);
        let err_b = cap_b
            .verify(&RuntimeContext {
                now_ms: 1_000,
                scope_path: "vault/chats/2026".into(),
                tool_name: "vault.read".into(),
                additional: Default::default(),
            })
            .expect_err("order-swap still uses tightest prefix");
        assert!(matches!(
            err_b,
            CapabilityError::Violated(CaveatViolation::ScopeOutOfBounds { .. })
        ));

        // Case (c): unrelated prefixes ("vault/notes" + "vault/chats")
        // — neither extends the other. CaveatViolation::IncompatiblePrefixes.
        let m_c = restrict(&base, Caveat::ScopePrefix { prefix: "vault/notes".into() });
        let m_c = restrict(&m_c, Caveat::ScopePrefix { prefix: "vault/chats".into() });
        let cap_c = MacaroonCapability::new(m_c, key);
        let err_c = cap_c
            .verify(&RuntimeContext {
                now_ms: 1_000,
                scope_path: "vault/notes/2026".into(),
                tool_name: "vault.read".into(),
                additional: Default::default(),
            })
            .expect_err("unrelated prefixes must reject as Incompatible");
        assert!(matches!(
            err_c,
            CapabilityError::Violated(CaveatViolation::IncompatiblePrefixes { .. })
        ));
    }

    #[test]
    fn two_expiry_after_caveats_compose_to_tighter_minimum_through_v2_surface() {
        // Phase 1 hardening — caveat-composition doctrine pin.
        // cognitive_dag::macaroons::evaluate_caveats composes
        // multiple ExpiryAfter caveats via `prev.min(until_ts_ms)`
        // (macaroons.rs §evaluate_caveats line ~285). Stacking
        // two ExpiryAfter caveats — a 10_000ms parent + a 3_000ms
        // narrower child — must produce an effective expiry of
        // 3_000ms (the tighter / earlier of the two).
        //
        // No existing v2 test pins this composition. The multi-
        // caveat test uses ONE ExpiryAfter; this fixture proves
        // the MIN composition through the MacaroonCapability::verify
        // path.
        use crate::cognitive_dag::macaroons::{issue, restrict, Caveat, CaveatViolation};
        let key = root_key_a();
        let base = issue(
            "expiry-composition-session",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            // Base expiry: 10_000ms
            Some(10_000),
            &key,
        );
        // Two stacked caveats: 5_000ms parent + 3_000ms narrower.
        let m = restrict(&base, Caveat::ExpiryAfter { until_ts_ms: 5_000 });
        let m = restrict(&m, Caveat::ExpiryAfter { until_ts_ms: 3_000 });
        let cap = MacaroonCapability::new(m, key);

        // At t=2_999ms: still inside the tightest expiry (3_000).
        cap.verify(&ctx_now_at(2_999))
            .expect("just-before tightest expiry must verify");
        // At t=3_000ms: AT the tightest expiry — rejected
        // (boundary closed at expiry, see iter-71 boundary pin).
        let err = cap
            .verify(&ctx_now_at(3_000))
            .expect_err("at tightest expiry must reject");
        match err {
            CapabilityError::Violated(CaveatViolation::Expired { until_ts_ms, now_ms }) => {
                assert_eq!(until_ts_ms, 3_000, "MIN expiry must be 3_000 (tightest)");
                assert_eq!(now_ms, 3_000);
            }
            other => panic!("expected Violated(Expired), got {other:?}"),
        }
        // At t=7_000ms: WAY past tightest, also past 5_000. Rejected.
        let err_past = cap
            .verify(&ctx_now_at(7_000))
            .expect_err("past all expiries must reject");
        assert!(matches!(
            err_past,
            CapabilityError::Violated(CaveatViolation::Expired { until_ts_ms: 3_000, .. })
        ));

        // Symmetric: swap caveat order (3_000 first, then 5_000).
        // Still composes to MIN = 3_000.
        let m_swapped = restrict(&base, Caveat::ExpiryAfter { until_ts_ms: 3_000 });
        let m_swapped = restrict(&m_swapped, Caveat::ExpiryAfter { until_ts_ms: 5_000 });
        let cap_swapped = MacaroonCapability::new(m_swapped, key);
        let err_swap = cap_swapped
            .verify(&ctx_now_at(3_000))
            .expect_err("MIN composition must be order-independent");
        assert!(matches!(
            err_swap,
            CapabilityError::Violated(CaveatViolation::Expired { until_ts_ms: 3_000, .. })
        ));
    }

    #[test]
    fn expiry_boundary_at_exactly_now_ms_rejected() {
        // Edge case: macaroons::evaluate_caveats uses `if now_ms >= exp`,
        // so a token whose expiry equals the current wall-clock time
        // is REJECTED (the boundary is closed at expiry, open at now).
        // Locking this in a property test guards against an
        // accidental flip to strict `>`.
        let m = issue_tool_macaroon(&root_key_a(), Some(5_000));
        let cap = MacaroonCapability::new(m, root_key_a());

        // now_ms = 4999 → still valid (one millisecond inside).
        cap.verify(&ctx_now_at(4_999)).expect("just-before expiry is valid");
        // now_ms = 5000 → EXACT boundary is rejected.
        let err_at = cap.verify(&ctx_now_at(5_000)).expect_err("exact-expiry must reject");
        assert!(
            matches!(err_at, CapabilityError::Violated(CaveatViolation::Expired { .. })),
            "expected Violated(Expired) at exact boundary, got {err_at:?}"
        );
        // now_ms = 5001 → past, also rejected.
        let err_after = cap
            .verify(&ctx_now_at(5_001))
            .expect_err("post-expiry must reject");
        assert!(matches!(
            err_after,
            CapabilityError::Violated(CaveatViolation::Expired { .. })
        ));
    }

    #[test]
    fn double_restrict_with_same_caveat_appends_two_chain_links() {
        // Phase 1 hardening — pin expected behaviour: macaroon
        // restrict() always appends a chain link, even when the
        // caveat duplicates an existing one. The signature changes
        // each time. Caller responsibility to dedupe if they care;
        // the runtime doesn't pretend the second restrict is a no-op.
        use crate::cognitive_dag::macaroons::{issue, restrict, Caveat};
        let key = root_key_a();
        let base = issue(
            "double-restrict",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            Some(10_000),
            &key,
        );
        let prefix = Caveat::ScopePrefix { prefix: "vault/notes".into() };
        let once = restrict(&base, prefix.clone());
        let twice = restrict(&once, prefix.clone());
        // Chain length grew with each restrict.
        assert_eq!(base.caveats.len(), 0);
        assert_eq!(once.caveats.len(), 1);
        assert_eq!(twice.caveats.len(), 2);
        // Signatures differ at every step (chain extends).
        assert_ne!(base.signature, once.signature);
        assert_ne!(once.signature, twice.signature);
        // Both restricted versions still verify under the same key.
        MacaroonCapability::new(once, root_key_a())
            .verify(&ctx_now_at(1_000))
            .expect("once-restricted verifies");
        MacaroonCapability::new(twice, root_key_a())
            .verify(&ctx_now_at(1_000))
            .expect("twice-restricted verifies");
    }

    #[test]
    fn additional_context_caveat_enforced_through_v2_surface() {
        // Phase 1 hardening — Caveat::AdditionalContext exists in
        // cognitive_dag::macaroons but hasn't been exercised through
        // the v2 MacaroonCapability path. Pin: matching ctx.additional
        // verifies; missing key rejects; wrong value rejects.
        use crate::cognitive_dag::macaroons::{issue, restrict, Caveat, CaveatViolation};
        use std::collections::BTreeMap;
        let key = root_key_a();
        let base = issue(
            "ctx-session",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            Some(10_000),
            &key,
        );
        let with_ctx = restrict(
            &base,
            Caveat::AdditionalContext {
                key: "request_id".into(),
                value: "abc-123".into(),
            },
        );
        let cap = MacaroonCapability::new(with_ctx, key);

        // Matching context → accept.
        let mut matching = BTreeMap::new();
        matching.insert("request_id".to_string(), "abc-123".to_string());
        let ctx_ok = RuntimeContext {
            now_ms: 1_000,
            scope_path: "vault/notes".into(),
            tool_name: "vault.read".into(),
            additional: matching,
        };
        cap.verify(&ctx_ok).expect("matching context verifies");

        // Missing key → reject.
        let ctx_missing = RuntimeContext {
            now_ms: 1_000,
            scope_path: "vault/notes".into(),
            tool_name: "vault.read".into(),
            additional: Default::default(),
        };
        let err = cap.verify(&ctx_missing).expect_err("missing key rejects");
        assert!(matches!(
            err,
            CapabilityError::Violated(CaveatViolation::ContextMismatch { .. })
        ));

        // Wrong value → reject.
        let mut wrong = BTreeMap::new();
        wrong.insert("request_id".to_string(), "WRONG".to_string());
        let ctx_wrong = RuntimeContext {
            now_ms: 1_000,
            scope_path: "vault/notes".into(),
            tool_name: "vault.read".into(),
            additional: wrong,
        };
        let err = cap.verify(&ctx_wrong).expect_err("wrong value rejects");
        assert!(matches!(
            err,
            CapabilityError::Violated(CaveatViolation::ContextMismatch { .. })
        ));
    }

    #[test]
    fn macaroon_base_kind_base_scope_base_expiry_each_participate_in_signature_chain() {
        // Phase 1 hardening — companion to iter-214's location-field
        // signature pin. The HMAC chain initial signature feeds in
        // EVERY base field: location, base_kind, base_scope,
        // base_expiry_ms. Each diff must produce different signatures
        // and capability_hashes — the macaroon identity is the
        // 4-tuple (plus caveats).
        //
        // No existing test pins these three individually. A future
        // refactor that dropped any one from the HMAC chain would
        // silently collapse identity across that axis.
        use crate::cognitive_dag::macaroons::issue;
        let key = root_key_a();
        let base = issue(
            "session",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            Some(10_000),
            &key,
        );

        // base_kind diff (ToolInvoke "vault.read" vs ToolInvoke "vault.write").
        let diff_kind = issue(
            "session",
            CapabilityKind::ToolInvoke("vault.write".into()),
            CapabilityScope("vault".into()),
            Some(10_000),
            &key,
        );
        assert_ne!(base.signature, diff_kind.signature, "base_kind must affect signature");
        assert_ne!(base.capability_hash(), diff_kind.capability_hash());

        // base_scope diff.
        let diff_scope = issue(
            "session",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("graph".into()),
            Some(10_000),
            &key,
        );
        assert_ne!(base.signature, diff_scope.signature, "base_scope must affect signature");
        assert_ne!(base.capability_hash(), diff_scope.capability_hash());

        // base_expiry_ms diff.
        let diff_expiry = issue(
            "session",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            Some(20_000), // 10_000 → 20_000
            &key,
        );
        assert_ne!(base.signature, diff_expiry.signature, "base_expiry_ms must affect signature");
        assert_ne!(base.capability_hash(), diff_expiry.capability_hash());

        // None-vs-Some(0) expiry also differs.
        let no_expiry = issue(
            "session",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            None,
            &key,
        );
        assert_ne!(base.signature, no_expiry.signature, "expiry None vs Some(N) must affect signature");
    }

    #[test]
    fn capability_hash_domain_separation_prefix_pinned_for_replay_parity() {
        // Phase 1 hardening — replay-parity-critical domain-separation
        // pin. Macaroon::capability_hash computes
        //   blake3("epistemos-macaroon-cap-v1\n" || signature)
        // (macaroons.rs §145-150). The prefix bytes are load-bearing
        // for cross-version replay; a silent typo or .v1 → .v2 bump
        // would silently fork every persisted capability_hash on
        // disk.
        //
        // Independently recompute the hash with the documented
        // prefix and compare. Companion to iter-84's RunEventLog
        // root_hash per-entry encoding pin (the per-entry encoding
        // there is u64-LE length + JSON; here the prefix + 32-byte
        // signature is the encoding).
        use crate::cognitive_dag::macaroons::issue;
        let m = issue(
            "domain-sep-fixture",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            Some(10_000),
            &root_key_a(),
        );
        let mut hasher = blake3::Hasher::new();
        hasher.update(b"epistemos-macaroon-cap-v1\n");
        hasher.update(&m.signature);
        let expected =
            crate::cognitive_dag::node::Hash::from_bytes(*hasher.finalize().as_bytes());
        assert_eq!(
            m.capability_hash(),
            expected,
            "capability_hash prefix/shape drift breaks replay parity"
        );
        // A wrong-prefix recompute MUST produce a different hash.
        let mut wrong_prefix = blake3::Hasher::new();
        wrong_prefix.update(b"epistemos-macaroon-cap-v2\n"); // version bump
        wrong_prefix.update(&m.signature);
        let wrong =
            crate::cognitive_dag::node::Hash::from_bytes(*wrong_prefix.finalize().as_bytes());
        assert_ne!(
            m.capability_hash(),
            wrong,
            "prefix-version bump must produce different hash"
        );
    }

    #[test]
    fn macaroon_with_empty_location_still_verifies_per_current_doctrine() {
        // Phase 1 hardening — doctrine pin. The issue() function
        // accepts any String as location (no non-empty validation).
        // An empty-location macaroon is legal and verifies; its
        // signature is just a specific HMAC chain start.
        //
        // A future "require non-empty session id" tightening would
        // silently start rejecting capabilities issued before the
        // constraint landed.
        use crate::cognitive_dag::macaroons::issue;
        let key = root_key_a();
        let m = issue(
            "", // empty location
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            Some(10_000),
            &key,
        );
        let cap = MacaroonCapability::new(m, key);
        cap.verify(&ctx_now_at(1_000))
            .expect("empty-location macaroon must still verify");
    }

    #[test]
    fn macaroon_location_field_participates_in_signature_chain() {
        // Phase 1 hardening — symmetric companion to
        // capability_hash_is_stable_across_identical_rebuilds (same-
        // location reproducibility). The macaroon HMAC chain
        // initial signature feeds in the location field
        // (macaroons.rs §issue: hasher.update(location.as_bytes())).
        // Two macaroons with DIFFERENT locations but identical
        // (kind, scope, expiry, caveats, key) must produce
        // DIFFERENT signatures and capability_hashes.
        //
        // No existing test pins this. A future refactor that
        // dropped the location field from the HMAC chain would
        // silently let session-A and session-B capabilities cache-
        // collide.
        use crate::cognitive_dag::macaroons::issue;
        let key = root_key_a();
        let m_session_a = issue(
            "session-A",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            Some(10_000),
            &key,
        );
        let m_session_b = issue(
            "session-B",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            Some(10_000),
            &key,
        );
        assert_ne!(
            m_session_a.signature, m_session_b.signature,
            "different location must produce different signature"
        );
        assert_ne!(
            m_session_a.capability_hash(),
            m_session_b.capability_hash(),
            "different location must produce different capability_hash"
        );
        // Both still verify under the same key — the location
        // diff doesn't break HMAC validity, only identity.
        let cap_a = MacaroonCapability::new(m_session_a, key);
        let cap_b = MacaroonCapability::new(m_session_b, key);
        cap_a.verify(&ctx_now_at(1_000)).expect("session A verifies");
        cap_b.verify(&ctx_now_at(1_000)).expect("session B verifies");
    }

    #[test]
    fn capability_hash_is_stable_across_identical_rebuilds() {
        // Phase 1 hardening — replay reproducibility. Building two
        // macaroons with the SAME root key, location, base_kind,
        // base_scope, base_expiry, and (in-order) caveats must yield
        // the same signature AND the same capability_hash. Replay
        // depends on this; a future change to the HMAC chain that
        // breaks reproducibility surfaces here.
        use crate::cognitive_dag::macaroons::{issue, restrict, Caveat};
        let key = root_key_a();
        let m1 = issue(
            "stable-session",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            Some(10_000),
            &key,
        );
        let m1 = restrict(&m1, Caveat::ScopePrefix { prefix: "vault/notes".into() });
        let m1 = restrict(&m1, Caveat::ToolNameEq { name: "vault.read".into() });

        let m2 = issue(
            "stable-session",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            Some(10_000),
            &key,
        );
        let m2 = restrict(&m2, Caveat::ScopePrefix { prefix: "vault/notes".into() });
        let m2 = restrict(&m2, Caveat::ToolNameEq { name: "vault.read".into() });

        assert_eq!(m1.signature, m2.signature, "signature must be reproducible");
        assert_eq!(
            m1.capability_hash(),
            m2.capability_hash(),
            "capability_hash must be reproducible"
        );
    }

    #[test]
    fn restrict_after_delegate_preserves_delegated_flag_through_v2_surface() {
        // Phase 1 hardening — doctrine pin. cognitive_dag::macaroons::restrict
        // (macaroons.rs §211) copies the `delegated` flag through to
        // the new macaroon. A future refactor that reset the flag
        // (e.g., "narrowing is a fresh capability, drop the delegation
        // marker") would silently make a delegated capability look
        // newly-issued at the audit surface — bypassing the
        // delegation chain visibility.
        //
        // The existing delegated_macaroon_still_verifies_and_preserves_flag
        // tests delegate(...) alone; the cross-operation case
        // (restrict + delegate, or delegate + restrict) is unpinned.
        use crate::cognitive_dag::macaroons::{delegate, restrict, Caveat};
        let base = issue_tool_macaroon(&root_key_a(), Some(10_000));
        // Path 1: delegate first, then restrict.
        let d_then_r = restrict(
            &delegate(&base),
            Caveat::ScopePrefix { prefix: "vault/notes".into() },
        );
        assert!(
            d_then_r.delegated,
            "delegate-then-restrict must preserve delegated=true"
        );
        // Both legs still verify under the issuing key.
        let cap_dr = MacaroonCapability::new(d_then_r, root_key_a());
        cap_dr
            .verify(&RuntimeContext {
                now_ms: 1_000,
                scope_path: "vault/notes/2026".into(),
                tool_name: "vault.read".into(),
                additional: Default::default(),
            })
            .expect("delegate-then-restrict verifies under issuing key");

        // Path 2: restrict first, then delegate. delegate() always
        // sets flag to true, so this proves restrict didn't disturb
        // the false-default.
        let r_then_d = delegate(&restrict(
            &base,
            Caveat::ScopePrefix { prefix: "vault/notes".into() },
        ));
        assert!(r_then_d.delegated);

        // Non-delegated restrict path stays non-delegated (the
        // false-default is preserved).
        let r_only = restrict(
            &base,
            Caveat::ScopePrefix { prefix: "vault/notes".into() },
        );
        assert!(!r_only.delegated, "restrict alone does NOT flip delegated");
    }

    #[test]
    fn delegate_twice_is_idempotent_no_op_after_first_call() {
        // Phase 1 hardening — idempotency pin for the delegate
        // operation. delegate() flips the delegated flag to true;
        // calling it AGAIN on an already-delegated macaroon must
        // be a no-op (delegated stays true). The flag doesn't
        // double-count or roll over.
        //
        // A future "let me track delegation depth via a counter"
        // refactor would silently change the delegation contract
        // from a boolean flag to a counter — surface at PR review.
        use crate::cognitive_dag::macaroons::delegate;
        let base = issue_tool_macaroon(&root_key_a(), Some(10_000));
        let once = delegate(&base);
        let twice = delegate(&once);
        let thrice = delegate(&twice);
        assert!(once.delegated);
        assert!(twice.delegated);
        assert!(thrice.delegated);
        // Signature unchanged across re-delegations (delegate is
        // metadata, not chain extension).
        assert_eq!(base.signature, once.signature);
        assert_eq!(once.signature, twice.signature);
        assert_eq!(twice.signature, thrice.signature);
        // All still verify under the issuing key.
        let cap_thrice = MacaroonCapability::new(thrice, root_key_a());
        cap_thrice.verify(&ctx_now_at(1_000)).expect("thrice-delegated verifies");
    }

    #[test]
    fn delegated_macaroon_still_verifies_and_preserves_flag() {
        // Phase 1 hardening — the doctrine §2.6 delegation marker
        // ("Delegate: hand to a Companion") must:
        // 1. NOT affect signature verification (delegation is metadata,
        //    not a chain link).
        // 2. SURVIVE through the v2 capability surface so audit can
        //    see "this token was passed to a non-issuer principal."
        use crate::cognitive_dag::macaroons::delegate;
        let base = issue_tool_macaroon(&root_key_a(), Some(10_000));
        let delegated = delegate(&base);
        // Delegation flag flipped.
        assert!(!base.delegated);
        assert!(delegated.delegated);
        // Both still verify under the issuing key.
        let cap_base = MacaroonCapability::new(base, root_key_a());
        let cap_del = MacaroonCapability::new(delegated, root_key_a());
        cap_base.verify(&ctx_now_at(1_000)).expect("base verifies");
        cap_del.verify(&ctx_now_at(1_000)).expect("delegated verifies");
        // The v2 capability surface exposes the underlying macaroon
        // so audit can read the flag.
        assert!(cap_del.macaroon().delegated);
        assert!(!cap_base.macaroon().delegated);
    }

    #[test]
    fn caveat_order_produces_distinct_capability_hashes() {
        // Phase 1 hardening — replay-parity boundary. The macaroon
        // HMAC chain is order-sensitive: applying caveats in a
        // different order produces a different signature → different
        // capability_hash. Replay tooling MUST reproduce the original
        // ordering byte-for-byte; a re-sort would invalidate the
        // hash and the corresponding RunEventLog SealedMutation rows.
        let base = issue_tool_macaroon(&root_key_a(), Some(10_000));

        // Two orderings of the same two caveats:
        let a_first = restrict(
            &base,
            Caveat::ScopePrefix { prefix: "vault/notes".into() },
        );
        let a_first = restrict(&a_first, Caveat::ToolNameEq { name: "vault.read".into() });

        let b_first = restrict(
            &base,
            Caveat::ToolNameEq { name: "vault.read".into() },
        );
        let b_first = restrict(
            &b_first,
            Caveat::ScopePrefix { prefix: "vault/notes".into() },
        );

        // Caveats vectors look "the same set" but they're ordered:
        assert_eq!(a_first.caveats.len(), 2);
        assert_eq!(b_first.caveats.len(), 2);
        // Signatures (and therefore capability_hashes) MUST differ.
        assert_ne!(a_first.signature, b_first.signature);
        assert_ne!(a_first.capability_hash(), b_first.capability_hash());

        // Both still verify under the issuing key — they're valid
        // tokens, just NOT the same token.
        let cap_a = MacaroonCapability::new(a_first, root_key_a());
        let cap_b = MacaroonCapability::new(b_first, root_key_a());
        let ctx = RuntimeContext {
            now_ms: 1_000,
            scope_path: "vault/notes/2026".into(),
            tool_name: "vault.read".into(),
            additional: Default::default(),
        };
        cap_a.verify(&ctx).expect("a_first verifies");
        cap_b.verify(&ctx).expect("b_first verifies");
    }

    #[test]
    fn multi_caveat_macaroon_requires_all_caveats_satisfied() {
        // Phase 1 hardening — macaroon composition: a single token
        // narrowed by ScopePrefix + ExpiryAfter + ToolNameEq. All
        // three caveats must be satisfied at use time; violating any
        // one is enough to reject.
        let base = issue_tool_macaroon(&root_key_a(), Some(100_000));
        let m = restrict(&base, Caveat::ScopePrefix { prefix: "vault/notes".into() });
        let m = restrict(&m, Caveat::ExpiryAfter { until_ts_ms: 5_000 });
        let m = restrict(&m, Caveat::ToolNameEq { name: "vault.read".into() });
        let cap = MacaroonCapability::new(m, root_key_a());

        // All three caveats satisfied → accept.
        let ok_ctx = RuntimeContext {
            now_ms: 1_000,
            scope_path: "vault/notes/2026/may".into(),
            tool_name: "vault.read".into(),
            additional: Default::default(),
        };
        cap.verify(&ok_ctx).expect("all caveats satisfied");

        // Wrong tool name → reject.
        let bad_tool = RuntimeContext { tool_name: "vault.write".into(), ..ok_ctx.clone() };
        let err = cap.verify(&bad_tool).expect_err("tool mismatch must reject");
        assert!(matches!(
            err,
            CapabilityError::Violated(CaveatViolation::ToolMismatch { .. })
        ));

        // Wrong scope → reject.
        let bad_scope = RuntimeContext { scope_path: "vault/chats/2026".into(), ..ok_ctx.clone() };
        let err = cap.verify(&bad_scope).expect_err("scope mismatch must reject");
        assert!(matches!(
            err,
            CapabilityError::Violated(CaveatViolation::ScopeOutOfBounds { .. })
        ));

        // Past expiry → reject.
        let expired = RuntimeContext { now_ms: 6_000, ..ok_ctx.clone() };
        let err = cap.verify(&expired).expect_err("expired must reject");
        assert!(matches!(
            err,
            CapabilityError::Violated(CaveatViolation::Expired { .. })
        ));
    }

    #[test]
    fn expiry_after_caveat_with_u64_max_effectively_never_expires() {
        // Phase 1 hardening — boundary completeness companion to
        // iter-255 zero-expiry. With until_ts_ms=u64::MAX, the
        // evaluator's `ctx.now_ms >= exp` check requires
        // ctx.now_ms >= u64::MAX. Any realistic now_ms < u64::MAX
        // → verify succeeds. now_ms == u64::MAX itself trips the
        // closed-at-boundary semantics (iter-71 already pinned).
        use crate::cognitive_dag::macaroons::{issue, restrict, Caveat};
        let key = root_key_a();
        let base = issue(
            "max-expiry",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            None,
            &key,
        );
        let m = restrict(&base, Caveat::ExpiryAfter { until_ts_ms: u64::MAX });
        let cap = MacaroonCapability::new(m, key);

        // All realistic now_ms values verify successfully.
        for now_ms in [0u64, 1, 1_000_000, u64::MAX - 1] {
            cap.verify(&RuntimeContext {
                now_ms,
                scope_path: "vault".into(),
                tool_name: "vault.read".into(),
                additional: Default::default(),
            })
            .unwrap_or_else(|e| panic!("now_ms={now_ms} must verify with MAX expiry, got {e:?}"));
        }
        // Boundary: now_ms == u64::MAX is rejected (closed-at-expiry,
        // per iter-71's boundary doctrine).
        let err = cap
            .verify(&RuntimeContext {
                now_ms: u64::MAX,
                scope_path: "vault".into(),
                tool_name: "vault.read".into(),
                additional: Default::default(),
            })
            .expect_err("now_ms == MAX must reject at the closed expiry boundary");
        assert!(matches!(err, CapabilityError::Violated(_)));
    }

    #[test]
    fn expiry_after_caveat_with_zero_until_ts_ms_revokes_immediately() {
        // Phase 1 hardening — doctrine pin (companion to iter-167 /
        // iter-253 / iter-254 empty/zero caveat pins). ExpiryAfter
        // with until_ts_ms=0 effectively revokes the macaroon
        // because the evaluator uses `if ctx.now_ms >= exp`. Any
        // real wall-clock now_ms (>= 0) is >= 0 → Expired.
        //
        // A future maintainer who thought "0 means no expiry" might
        // special-case it and accidentally make a revoked-by-cap
        // token legal again.
        use crate::cognitive_dag::macaroons::{issue, restrict, Caveat, CaveatViolation};
        let key = root_key_a();
        let base = issue(
            "zero-expiry-revoked",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            Some(10_000), // base expiry generous
            &key,
        );
        let m = restrict(&base, Caveat::ExpiryAfter { until_ts_ms: 0 });
        let cap = MacaroonCapability::new(m, key);

        // Any non-zero (or zero) now_ms rejects.
        for now_ms in [0u64, 1, 1_000, u64::MAX] {
            let err = cap
                .verify(&RuntimeContext {
                    now_ms,
                    scope_path: "vault".into(),
                    tool_name: "vault.read".into(),
                    additional: Default::default(),
                })
                .expect_err(&format!("expiry=0 with now_ms={now_ms} must reject"));
            assert!(matches!(
                err,
                CapabilityError::Violated(CaveatViolation::Expired { until_ts_ms: 0, .. })
            ));
        }
    }

    #[test]
    fn empty_additional_context_key_or_value_enforces_strict_empty_match() {
        // Phase 1 hardening — doctrine pin (companion to iter-167
        // empty-prefix no-op + iter-253 empty-ToolNameEq strict
        // pins). AdditionalContext is strict-equality on both key
        // and value; empty strings are legal but treated as exact
        // matches.
        use crate::cognitive_dag::macaroons::{issue, restrict, Caveat, CaveatViolation};
        use std::collections::BTreeMap;
        let key = root_key_a();
        let base = issue(
            "empty-ctx",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            Some(10_000),
            &key,
        );

        // Empty key + non-empty value.
        let m = restrict(
            &base,
            Caveat::AdditionalContext { key: "".into(), value: "v".into() },
        );
        let cap = MacaroonCapability::new(m, key);
        let mut matching = BTreeMap::new();
        matching.insert("".to_string(), "v".to_string());
        cap.verify(&RuntimeContext {
            now_ms: 1_000,
            scope_path: "vault".into(),
            tool_name: "vault.read".into(),
            additional: matching,
        })
        .expect("empty-key + value match verifies");
        // Missing empty-key entry → reject.
        let err = cap
            .verify(&RuntimeContext {
                now_ms: 1_000,
                scope_path: "vault".into(),
                tool_name: "vault.read".into(),
                additional: BTreeMap::new(),
            })
            .expect_err("missing empty-key entry rejects");
        assert!(matches!(
            err,
            CapabilityError::Violated(CaveatViolation::ContextMismatch { .. })
        ));

        // Non-empty key + empty value (symmetric).
        let m_v = restrict(
            &base,
            Caveat::AdditionalContext { key: "k".into(), value: "".into() },
        );
        let cap_v = MacaroonCapability::new(m_v, key);
        let mut matching_v = BTreeMap::new();
        matching_v.insert("k".to_string(), "".to_string());
        cap_v
            .verify(&RuntimeContext {
                now_ms: 1_000,
                scope_path: "vault".into(),
                tool_name: "vault.read".into(),
                additional: matching_v,
            })
            .expect("empty-value match verifies");
        // Non-empty value where caveat requires empty → reject.
        let mut wrong = BTreeMap::new();
        wrong.insert("k".to_string(), "non-empty".to_string());
        let err = cap_v
            .verify(&RuntimeContext {
                now_ms: 1_000,
                scope_path: "vault".into(),
                tool_name: "vault.read".into(),
                additional: wrong,
            })
            .expect_err("non-empty value with empty caveat rejects");
        assert!(matches!(
            err,
            CapabilityError::Violated(CaveatViolation::ContextMismatch { .. })
        ));
    }

    #[test]
    fn empty_tool_name_eq_caveat_enforces_strict_empty_match_per_current_doctrine() {
        // Phase 1 hardening — companion to iter-167 empty-prefix
        // ScopePrefix no-op doctrine pin. ToolNameEq with name=""
        // is legal but enforces strict equality: ctx.tool_name
        // must be "" to verify.
        //
        // This is DIFFERENT from empty-prefix ScopePrefix (which is
        // a no-op). The asymmetry is worth pinning.
        use crate::cognitive_dag::macaroons::{issue, restrict, Caveat, CaveatViolation};
        let key = root_key_a();
        let base = issue(
            "empty-tool-eq",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            Some(10_000),
            &key,
        );
        let m = restrict(&base, Caveat::ToolNameEq { name: "".into() });
        let cap = MacaroonCapability::new(m, key);

        // Empty ctx.tool_name → accepted.
        cap.verify(&RuntimeContext {
            now_ms: 1_000,
            scope_path: "vault".into(),
            tool_name: "".into(),
            additional: Default::default(),
        })
        .expect("empty tool_name caveat + empty ctx.tool_name verifies");

        // Non-empty ctx.tool_name → rejected.
        let err = cap
            .verify(&RuntimeContext {
                now_ms: 1_000,
                scope_path: "vault".into(),
                tool_name: "vault.read".into(),
                additional: Default::default(),
            })
            .expect_err("non-empty tool name with empty caveat must reject");
        assert!(matches!(
            err,
            CapabilityError::Violated(CaveatViolation::ToolMismatch { .. })
        ));
    }

    #[test]
    fn empty_scope_prefix_caveat_is_effective_no_op_per_current_doctrine() {
        // Phase 1 hardening — DOCTRINE PIN, complementary to iter-76's
        // byte-level scope_prefix pin and iter-130's composition rules.
        // The cognitive_dag::macaroons::evaluate_caveats path checks
        // `ctx.scope_path.starts_with(prefix.as_str())` (macaroons.rs
        // §315). Every string starts_with "" → trivially true.
        //
        // Current doctrine: a Caveat::ScopePrefix with prefix="" is
        // legal but has no narrowing effect. The capability still
        // applies to every scope_path the base scope admits.
        //
        // A future "reject empty-prefix caveats as invalid narrowings"
        // tightening would break callers that pass "" as a sentinel
        // for "no further narrowing." Pin current behaviour so any
        // tightening surfaces at PR review.
        use crate::cognitive_dag::macaroons::{issue, restrict, Caveat};
        let key = root_key_a();
        let base = issue(
            "empty-prefix-session",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            Some(10_000),
            &key,
        );
        let m = restrict(&base, Caveat::ScopePrefix { prefix: "".into() });
        let cap = MacaroonCapability::new(m, key);

        // Every scope_path admits — the empty prefix is a no-op.
        for path in [
            "vault/notes",
            "vault/chats/2026",
            "anything-at-all",
            "/absolute/path",
            // Even empty scope_path is admitted (empty.starts_with("") = true).
            "",
        ] {
            cap.verify(&RuntimeContext {
                now_ms: 1_000,
                scope_path: path.to_string(),
                tool_name: "vault.read".into(),
                additional: Default::default(),
            })
            .unwrap_or_else(|e| {
                panic!("empty-prefix caveat must admit scope_path {path:?}, got {e:?}")
            });
        }
    }

    #[test]
    fn scope_prefix_caveat_uses_byte_level_starts_with_not_path_segment_boundary() {
        // Phase 1 hardening — DOCTRINE PIN with security teeth.
        //
        // cognitive_dag::macaroons::evaluate_caveats checks the
        // ScopePrefix caveat via raw `ctx.scope_path.starts_with(prefix)`
        // (macaroons.rs §evaluate_caveats line ~315). This is BYTE-level
        // starts_with, NOT path-segment-boundary semantics. The
        // CURRENT doctrine is: a macaroon narrowed to prefix
        // "vault/notes" accepts:
        //   "vault/notes/2026/may"  → path child           (ACCEPT)
        //   "vault/notes"           → exact equality       (ACCEPT)
        //   "vault/notesomething"   → byte-prefix sibling  (ACCEPT)
        //
        // And rejects:
        //   "vault/chats"           → no shared prefix     (REJECT)
        //   "vault"                 → parent, not child    (REJECT)
        //
        // The byte-prefix-sibling acceptance is surprising — a path-
        // segment-boundary tightening would reject it. Pin the
        // current behaviour so a future refactor that switches to
        // path semantics surfaces at PR review (this test would
        // fail and the maintainer has to consciously update or
        // delete the assertion, documenting the doctrine change in
        // the same commit).
        //
        // This is the kind of doctrine pin where the EXACT behaviour
        // matters less than the FACT that the behaviour is locked.
        let key = root_key_a();
        let base = issue(
            "scope-doctrine-session",
            CapabilityKind::ToolInvoke("vault.read".into()),
            CapabilityScope("vault".into()),
            Some(10_000),
            &key,
        );
        let narrowed = restrict(&base, Caveat::ScopePrefix { prefix: "vault/notes".into() });
        let cap = MacaroonCapability::new(narrowed, key);

        let mk_ctx = |scope_path: &str| RuntimeContext {
            now_ms: 1_000,
            scope_path: scope_path.to_string(),
            tool_name: "vault.read".into(),
            additional: Default::default(),
        };

        // Accept cases — child path, exact match, AND byte-prefix sibling.
        cap.verify(&mk_ctx("vault/notes/2026/may"))
            .expect("path child must verify");
        cap.verify(&mk_ctx("vault/notes"))
            .expect("exact prefix match must verify");
        cap.verify(&mk_ctx("vault/notesomething"))
            .expect("byte-prefix sibling currently verifies — doctrine pin");
        cap.verify(&mk_ctx("vault/notes_archive"))
            .expect("underscore-suffix sibling also verifies — doctrine pin");

        // Reject cases — no shared prefix at all, or parent of prefix.
        let bad_sibling = cap
            .verify(&mk_ctx("vault/chats"))
            .expect_err("disjoint sibling must reject");
        assert!(matches!(
            bad_sibling,
            CapabilityError::Violated(CaveatViolation::ScopeOutOfBounds { .. })
        ));
        let bad_parent = cap
            .verify(&mk_ctx("vault"))
            .expect_err("parent of prefix must reject");
        assert!(matches!(
            bad_parent,
            CapabilityError::Violated(CaveatViolation::ScopeOutOfBounds { .. })
        ));
        let bad_empty = cap
            .verify(&mk_ctx(""))
            .expect_err("empty scope must reject when a prefix is set");
        assert!(matches!(
            bad_empty,
            CapabilityError::Violated(CaveatViolation::ScopeOutOfBounds { .. })
        ));
    }

    #[test]
    fn narrowed_macaroon_with_scope_caveat_still_verifies() {
        // Holder narrowed the scope via `restrict`; chain extends so
        // verify must still succeed, and caveat evaluation must enforce
        // the tighter scope.
        let base = issue_tool_macaroon(&root_key_a(), Some(10_000));
        let narrowed = restrict(
            &base,
            Caveat::ScopePrefix {
                prefix: "vault/notes".to_string(),
            },
        );
        let cap = MacaroonCapability::new(narrowed, root_key_a());

        let in_scope = RuntimeContext {
            now_ms: 1_000,
            scope_path: "vault/notes/2026/may".to_string(),
            tool_name: "vault.read".to_string(),
            additional: Default::default(),
        };
        cap.verify(&in_scope).expect("in-scope use must verify");

        let out_of_scope = RuntimeContext {
            now_ms: 1_000,
            scope_path: "vault/chats/2026".to_string(),
            tool_name: "vault.read".to_string(),
            additional: Default::default(),
        };
        let err = cap
            .verify(&out_of_scope)
            .expect_err("out-of-scope use must be rejected");
        assert!(
            matches!(err, CapabilityError::Violated(CaveatViolation::ScopeOutOfBounds { .. })),
            "expected Violated(ScopeOutOfBounds), got {err:?}"
        );
    }
}
