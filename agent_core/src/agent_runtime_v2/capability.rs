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
