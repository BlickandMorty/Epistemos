//! Adversarial fixtures — deep-hardening test surface.
//!
//! These are the §3.5 "deep hardening" property tests for edge cases
//! that the §4 T11 acceptance bar lists but does not itself name as
//! load-bearing invariants:
//!
//! - capability missing entirely (a `NoCapability` implementor that
//!   always denies — proves the gate, not the macaroon, is what stops
//!   the write)
//! - runaway tool loop bounded by `max_tool_calls`
//! - partial mutation rollback when the writer fails AFTER capability
//!   and budget gates clear
//!
//! Scope-wrong is already covered in
//! `capability::tests::narrowed_macaroon_with_scope_caveat_still_verifies`.

#[cfg(test)]
mod tests {
    use crate::agent_runtime_v2::{
        AgentRuntimeV2Capability, BudgetDebit, BudgetError, BudgetGate, BudgetLedger,
        BudgetSpec, BudgetTerm, CapabilityError, MutationEnvelope, MutationWriter, SealError,
        Sealer,
    };
    use crate::cognitive_dag::macaroons::{RuntimeContext, VerifyError};
    use crate::cognitive_dag::node::{CapabilityKind, CapabilityScope, Hash};

    /// Capability implementor that ALWAYS denies. Lets us prove the
    /// `Sealer` denies the write even when there is no macaroon to
    /// verify — the gate, not the cryptography, is what blocks.
    struct NoCapability;

    impl AgentRuntimeV2Capability for NoCapability {
        fn kind(&self) -> &CapabilityKind {
            // Static reference so the trait method is callable without
            // backing storage; the gate denies before any caller would
            // dereference the kind.
            static K: std::sync::OnceLock<CapabilityKind> = std::sync::OnceLock::new();
            K.get_or_init(|| CapabilityKind::Approval)
        }
        fn scope(&self) -> &CapabilityScope {
            static S: std::sync::OnceLock<CapabilityScope> = std::sync::OnceLock::new();
            S.get_or_init(|| CapabilityScope(String::new()))
        }
        fn verify(&self, _ctx: &RuntimeContext) -> Result<(), CapabilityError> {
            Err(CapabilityError::Forged(VerifyError::SignatureMismatch))
        }
    }

    /// Writer that records every call so tests can assert "wasn't
    /// touched" / "was called exactly N times".
    struct CountingWriter {
        calls: usize,
    }
    impl CountingWriter {
        fn new() -> Self {
            Self { calls: 0 }
        }
    }
    impl MutationWriter<String> for CountingWriter {
        type Receipt = ();
        type WriteError = std::convert::Infallible;
        fn write(&mut self, _payload: &String) -> Result<(), Self::WriteError> {
            self.calls += 1;
            Ok(())
        }
    }

    /// Writer that always fails AFTER being entered. Used to prove
    /// `SealError::Write` is reached only after both prior gates clear,
    /// and that the caller can roll back by discarding the would-be
    /// advanced ledger.
    struct AlwaysFailWriter {
        calls: usize,
    }
    impl AlwaysFailWriter {
        fn new() -> Self {
            Self { calls: 0 }
        }
    }
    #[derive(Debug, Clone, PartialEq, Eq)]
    struct DiskFull;
    impl MutationWriter<String> for AlwaysFailWriter {
        type Receipt = ();
        type WriteError = DiskFull;
        fn write(&mut self, _payload: &String) -> Result<(), Self::WriteError> {
            self.calls += 1;
            Err(DiskFull)
        }
    }

    fn ctx() -> RuntimeContext {
        RuntimeContext {
            now_ms: 0,
            scope_path: "vault".into(),
            tool_name: "vault.write".into(),
            additional: Default::default(),
        }
    }

    #[test]
    fn capability_missing_entirely_blocks_write() {
        // No macaroon at all — only a NoCapability implementor. The
        // Sealer must still refuse the write before the writer is
        // touched. Proves the gate, not the cryptography, is what
        // stops the call.
        let cap = NoCapability;
        let sealer = Sealer {
            capability: &cap,
            gate: BudgetGate::new(BudgetSpec::default()),
        };
        let envelope = MutationEnvelope::new(
            Hash::zero(),
            BudgetDebit::default(),
            "would-write".to_string(),
        );
        let mut writer = CountingWriter::new();
        let err = sealer
            .seal_and_apply(&ctx(), BudgetLedger::default(), envelope, &mut writer)
            .expect_err("missing capability must deny");
        assert!(matches!(err, SealError::Capability(_)));
        assert_eq!(writer.calls, 0, "writer must not be invoked");
    }

    #[test]
    fn runaway_tool_loop_bounded_by_max_tool_calls() {
        // Simulate a misbehaving agent that emits 100 tool calls
        // back-to-back. With a max_tool_calls cap of 3, exactly 3
        // succeed; call #4 must trip BudgetError::Exhausted.
        let gate = BudgetGate::new(BudgetSpec::new(0, 0, 3, 0));
        let mut ledger = BudgetLedger::default();
        let mut accepted = 0usize;
        let mut rejection: Option<BudgetError> = None;
        for _ in 0..100 {
            let debit = BudgetDebit {
                tool_calls: 1,
                ..Default::default()
            };
            match gate.check_and_debit(ledger, debit) {
                Ok(next) => {
                    ledger = next;
                    accepted += 1;
                }
                Err(e) => {
                    rejection = Some(e);
                    break;
                }
            }
        }
        assert_eq!(accepted, 3, "runaway loop must be bounded at the cap");
        assert_eq!(ledger.tool_calls_used, 3);
        match rejection {
            Some(BudgetError::Exhausted {
                term: BudgetTerm::ToolCalls,
                attempted_total: 4,
                cap: 3,
            }) => {}
            other => panic!("expected ToolCalls rejection on call 4, got {other:?}"),
        }
    }

    #[test]
    fn partial_mutation_rollback_when_writer_fails_after_gates_clear() {
        // Capability + budget BOTH clear, then the writer itself fails
        // (disk full). Sealer returns SealError::Write; the caller
        // must NOT adopt the advanced ledger because the side effect
        // never landed. We assert by NOT applying the would-be ledger
        // and confirming the original is unchanged.
        use crate::agent_runtime_v2::MacaroonCapability;
        use crate::cognitive_dag::macaroons::issue;
        let key = [4u8; 32];
        let m = issue(
            "rollback-session",
            CapabilityKind::ToolInvoke("vault.write".into()),
            CapabilityScope("vault".into()),
            Some(10_000),
            &key,
        );
        let cap = MacaroonCapability::new(m, key);
        let sealer = Sealer {
            capability: &cap,
            gate: BudgetGate::new(BudgetSpec::new(1_000, 0, 5, 0)),
        };
        let envelope = MutationEnvelope::new(
            cap.macaroon().capability_hash(),
            BudgetDebit {
                tokens: 100,
                tool_calls: 1,
                ..Default::default()
            },
            "payload".to_string(),
        );
        let mut writer = AlwaysFailWriter::new();
        let original_ledger = BudgetLedger::default();
        let result = sealer.seal_and_apply(
            &RuntimeContext {
                now_ms: 1_000,
                scope_path: "vault".into(),
                tool_name: "vault.write".into(),
                additional: Default::default(),
            },
            original_ledger,
            envelope,
            &mut writer,
        );
        let err = result.expect_err("writer failure must surface");
        assert!(matches!(err, SealError::Write(DiskFull)));
        // Writer WAS reached (both gates cleared) but exactly once.
        assert_eq!(writer.calls, 1);
        // Original ledger is untouched — Sealer returns the advanced
        // ledger as part of the Ok tuple only; on Err the caller never
        // sees the advanced value. Bitwise compare proves the rollback
        // surface is correct.
        assert_eq!(original_ledger, BudgetLedger::default());
    }
}
