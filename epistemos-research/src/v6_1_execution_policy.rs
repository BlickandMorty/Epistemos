//! HELIOS V6.1 — Lean per-stream execution policy (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-V6-1-EXECUTION-POLICY guard
//!
//! This module encodes the user directive:
//!
//! - Attention is an interrupt, not a substrate.
//! - `u_t` is the only normal wake-up path for attention, retrieval,
//!   tools, and heavy work.
//! - MAS may fall back to static 9:1 hybrid behavior only when
//!   interrupt signals are unavailable.
//! - Pro uses full interrupt scoring and LocalRecallIsland.
//! - Vault adds PacketRouter1bit plus experimental ConnectomeAlarm.
//!
//! The policy names canonical kernels and gates. It is not a claim
//! that the corresponding `.metal` files are already implemented.

use serde::{Deserialize, Serialize};

use crate::five_planes::ProductStream;
use crate::interrupt_score::EscalationLevel;
use crate::m2_max_kernels::LoadBearingKernel;

/// How a product stream is allowed to decide whether attention wakes.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AttentionWakePolicy {
    /// MAS baseline: use interrupt scoring whenever the five signals
    /// are available; fall back to static 9:1 only when they are not.
    InterruptScoreWithStatic9To1Fallback,
    /// Pro: the interrupt score is required; no fixed attention
    /// metronome is the normal path.
    FullInterruptScore,
    /// Vault: full interrupt score plus experimental signals under
    /// falsifier discipline.
    ExperimentalInterruptScore,
}

impl AttentionWakePolicy {
    pub fn uses_interrupt_score(self) -> bool {
        true
    }

    pub fn has_static_9_to_1_fallback(self) -> bool {
        matches!(self, AttentionWakePolicy::InterruptScoreWithStatic9To1Fallback)
    }
}

/// Runtime status of the Goodfire-derived ConnectomeAlarm signal.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ConnectomeAlarmPolicy {
    /// No runtime ConnectomeAlarm; keep the term zeroed.
    Disabled,
    /// Atlas/observability may be logged, but runtime acceleration
    /// claims remain off.
    ObservabilityOnly,
    /// Vault falsifier path for T42; never MAS.
    ExperimentalVaultOnly,
}

impl ConnectomeAlarmPolicy {
    pub fn can_drive_runtime_interrupts(self) -> bool {
        matches!(self, ConnectomeAlarmPolicy::ExperimentalVaultOnly)
    }
}

/// Canonical per-stream execution policy.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct StreamExecutionPolicy {
    pub stream: ProductStream,
    pub attention_wake_policy: AttentionWakePolicy,
    pub state_kernel: LoadBearingKernel,
    pub recall_kernel: Option<LoadBearingKernel>,
    pub assembly_kernel: Option<LoadBearingKernel>,
    pub connectome_alarm_policy: ConnectomeAlarmPolicy,
}

impl StreamExecutionPolicy {
    /// True when the escalation level wakes exact attention/recall.
    pub fn wakes_attention(self, level: EscalationLevel) -> bool {
        matches!(level, EscalationLevel::RecallEpisode | EscalationLevel::FullEscalation)
    }

    /// True when the escalation level wakes tools/heavy work.
    pub fn wakes_tools(self, level: EscalationLevel) -> bool {
        matches!(level, EscalationLevel::FullEscalation)
    }
}

/// Canonical lean execution policy for a V6.1 product stream.
pub fn stream_execution_policy(stream: ProductStream) -> StreamExecutionPolicy {
    match stream {
        ProductStream::Mas => StreamExecutionPolicy {
            stream,
            attention_wake_policy: AttentionWakePolicy::InterruptScoreWithStatic9To1Fallback,
            state_kernel: LoadBearingKernel::SemiseparableBlockScan,
            recall_kernel: None,
            assembly_kernel: None,
            connectome_alarm_policy: ConnectomeAlarmPolicy::Disabled,
        },
        ProductStream::Pro => StreamExecutionPolicy {
            stream,
            attention_wake_policy: AttentionWakePolicy::FullInterruptScore,
            state_kernel: LoadBearingKernel::SemiseparableBlockScan,
            recall_kernel: Some(LoadBearingKernel::LocalRecallIsland),
            assembly_kernel: None,
            connectome_alarm_policy: ConnectomeAlarmPolicy::ObservabilityOnly,
        },
        ProductStream::Vault => StreamExecutionPolicy {
            stream,
            attention_wake_policy: AttentionWakePolicy::ExperimentalInterruptScore,
            state_kernel: LoadBearingKernel::SemiseparableBlockScan,
            recall_kernel: Some(LoadBearingKernel::LocalRecallIsland),
            assembly_kernel: Some(LoadBearingKernel::PacketRouter1bit),
            connectome_alarm_policy: ConnectomeAlarmPolicy::ExperimentalVaultOnly,
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_stream_uses_interrupt_score_as_normal_attention_gate() {
        for stream in [ProductStream::Mas, ProductStream::Pro, ProductStream::Vault] {
            assert!(stream_execution_policy(stream)
                .attention_wake_policy
                .uses_interrupt_score());
        }
    }

    #[test]
    fn mas_keeps_static_9_to_1_only_as_signal_unavailable_fallback() {
        let policy = stream_execution_policy(ProductStream::Mas);
        assert!(policy.attention_wake_policy.has_static_9_to_1_fallback());
        assert_eq!(policy.state_kernel, LoadBearingKernel::SemiseparableBlockScan);
        assert_eq!(policy.recall_kernel, None);
        assert_eq!(policy.assembly_kernel, None);
    }

    #[test]
    fn pro_enables_local_recall_island_without_vault_connectome_alarm() {
        let policy = stream_execution_policy(ProductStream::Pro);
        assert!(!policy.attention_wake_policy.has_static_9_to_1_fallback());
        assert_eq!(policy.recall_kernel, Some(LoadBearingKernel::LocalRecallIsland));
        assert_eq!(policy.connectome_alarm_policy, ConnectomeAlarmPolicy::ObservabilityOnly);
        assert!(!policy.connectome_alarm_policy.can_drive_runtime_interrupts());
    }

    #[test]
    fn vault_adds_packet_router_and_experimental_connectome_alarm() {
        let policy = stream_execution_policy(ProductStream::Vault);
        assert_eq!(policy.assembly_kernel, Some(LoadBearingKernel::PacketRouter1bit));
        assert_eq!(policy.connectome_alarm_policy, ConnectomeAlarmPolicy::ExperimentalVaultOnly);
        assert!(policy.connectome_alarm_policy.can_drive_runtime_interrupts());
    }

    #[test]
    fn pure_recurrent_wakes_no_attention_or_tools() {
        for stream in [ProductStream::Mas, ProductStream::Pro, ProductStream::Vault] {
            let policy = stream_execution_policy(stream);
            assert!(!policy.wakes_attention(EscalationLevel::PureRecurrent));
            assert!(!policy.wakes_tools(EscalationLevel::PureRecurrent));
        }
    }

    #[test]
    fn recall_episode_wakes_attention_but_not_tools() {
        for stream in [ProductStream::Mas, ProductStream::Pro, ProductStream::Vault] {
            let policy = stream_execution_policy(stream);
            assert!(policy.wakes_attention(EscalationLevel::RecallEpisode));
            assert!(!policy.wakes_tools(EscalationLevel::RecallEpisode));
        }
    }

    #[test]
    fn full_escalation_wakes_attention_and_tools() {
        for stream in [ProductStream::Mas, ProductStream::Pro, ProductStream::Vault] {
            let policy = stream_execution_policy(stream);
            assert!(policy.wakes_attention(EscalationLevel::FullEscalation));
            assert!(policy.wakes_tools(EscalationLevel::FullEscalation));
        }
    }
}
