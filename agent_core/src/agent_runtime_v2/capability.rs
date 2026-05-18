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
