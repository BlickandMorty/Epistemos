use serde::{Deserialize, Serialize};
use std::sync::Mutex;

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum SerialFallbackMode {
    Resident,
    SsdStreaming,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct SerialInferenceSnapshot {
    pub phase: String,
    pub fallback_mode: SerialFallbackMode,
    pub should_stream_experts_from_ssd: bool,
    pub turn_boundary_readahead_allowed: bool,
    pub expert_prefetch_allowed: bool,
    pub turn_index: u64,
    pub available_memory_bytes: u64,
    pub non_expert_resident_bytes: u64,
}

#[derive(Debug, thiserror::Error)]
pub enum SerialInferenceTransitionError {
    #[error("invalid serial inference transition")]
    InvalidTransition,
    #[error("turn-boundary readahead is only allowed at the start of a turn")]
    TurnBoundaryOnly,
    #[error("disk reads are forbidden during active GPU compute")]
    GpuComputeActive,
    #[error("no inference turn is currently open")]
    NoOpenTurn,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SerialPhase {
    Idle,
    TurnBoundary,
    BetweenStages,
    SsdRead,
    GpuCompute,
}

impl SerialPhase {
    fn as_str(self) -> &'static str {
        match self {
            Self::Idle => "idle",
            Self::TurnBoundary => "turn_boundary",
            Self::BetweenStages => "between_stages",
            Self::SsdRead => "ssd_read",
            Self::GpuCompute => "gpu_compute",
        }
    }
}

#[derive(Debug, Clone, Copy)]
struct SerialInferenceState {
    phase: SerialPhase,
    fallback_mode: SerialFallbackMode,
    turn_index: u64,
    available_memory_bytes: u64,
    turn_open: bool,
}

impl SerialInferenceState {
    fn new() -> Self {
        Self {
            phase: SerialPhase::Idle,
            fallback_mode: SerialFallbackMode::Resident,
            turn_index: 0,
            available_memory_bytes: 0,
            turn_open: false,
        }
    }
}

/// Enforces the hard local-inference invariant:
/// GPU compute and SSD reads may alternate, but never overlap.
///
/// The controller is intentionally stateful and conservative:
/// - turn-boundary readahead is only legal at `TurnBoundary`
/// - SSD reads are forbidden during `GpuCompute`
/// - expert prefetch is never allowed
/// - memory-pressure fallback uses hysteresis to avoid mode flapping
pub struct SerialInferenceController {
    state: Mutex<SerialInferenceState>,
    pressure_threshold_bytes: u64,
    recovery_threshold_bytes: u64,
    non_expert_resident_bytes: u64,
}

impl SerialInferenceController {
    pub fn new(
        pressure_threshold_bytes: u64,
        recovery_threshold_bytes: u64,
        non_expert_resident_bytes: u64,
    ) -> Self {
        let effective_pressure = pressure_threshold_bytes.max(1);
        let effective_recovery = recovery_threshold_bytes.max(effective_pressure);
        let effective_non_expert = non_expert_resident_bytes.max(1);

        Self {
            state: Mutex::new(SerialInferenceState::new()),
            pressure_threshold_bytes: effective_pressure,
            recovery_threshold_bytes: effective_recovery,
            non_expert_resident_bytes: effective_non_expert,
        }
    }

    pub fn update_available_memory(&self, available_bytes: u64) {
        if let Ok(mut state) = self.state.lock() {
            state.available_memory_bytes = available_bytes;
            state.fallback_mode = match state.fallback_mode {
                SerialFallbackMode::Resident if available_bytes <= self.pressure_threshold_bytes => {
                    SerialFallbackMode::SsdStreaming
                }
                SerialFallbackMode::SsdStreaming
                    if available_bytes >= self.recovery_threshold_bytes =>
                {
                    SerialFallbackMode::Resident
                }
                current => current,
            };
        }
    }

    pub fn begin_turn(&self) -> Result<(), SerialInferenceTransitionError> {
        let mut state = self
            .state
            .lock()
            .map_err(|_| SerialInferenceTransitionError::InvalidTransition)?;
        match state.phase {
            SerialPhase::Idle => {
                state.turn_index += 1;
                state.turn_open = true;
                state.phase = SerialPhase::TurnBoundary;
                Ok(())
            }
            _ => Err(SerialInferenceTransitionError::InvalidTransition),
        }
    }

    pub fn end_turn(&self) -> Result<(), SerialInferenceTransitionError> {
        let mut state = self
            .state
            .lock()
            .map_err(|_| SerialInferenceTransitionError::InvalidTransition)?;
        if !state.turn_open {
            return Err(SerialInferenceTransitionError::NoOpenTurn);
        }
        match state.phase {
            SerialPhase::TurnBoundary | SerialPhase::BetweenStages => {
                state.turn_open = false;
                state.phase = SerialPhase::Idle;
                Ok(())
            }
            _ => Err(SerialInferenceTransitionError::InvalidTransition),
        }
    }

    pub fn record_turn_boundary_readahead(&self) -> Result<(), SerialInferenceTransitionError> {
        let state = self
            .state
            .lock()
            .map_err(|_| SerialInferenceTransitionError::InvalidTransition)?;
        if !state.turn_open {
            return Err(SerialInferenceTransitionError::NoOpenTurn);
        }
        match state.phase {
            SerialPhase::TurnBoundary => Ok(()),
            SerialPhase::GpuCompute => Err(SerialInferenceTransitionError::TurnBoundaryOnly),
            _ => Err(SerialInferenceTransitionError::TurnBoundaryOnly),
        }
    }

    pub fn begin_ssd_read(&self) -> Result<(), SerialInferenceTransitionError> {
        let mut state = self
            .state
            .lock()
            .map_err(|_| SerialInferenceTransitionError::InvalidTransition)?;
        if !state.turn_open {
            return Err(SerialInferenceTransitionError::NoOpenTurn);
        }
        match state.phase {
            SerialPhase::GpuCompute => Err(SerialInferenceTransitionError::GpuComputeActive),
            SerialPhase::TurnBoundary | SerialPhase::BetweenStages => {
                state.phase = SerialPhase::SsdRead;
                Ok(())
            }
            _ => Err(SerialInferenceTransitionError::InvalidTransition),
        }
    }

    pub fn finish_ssd_read(&self) -> Result<(), SerialInferenceTransitionError> {
        let mut state = self
            .state
            .lock()
            .map_err(|_| SerialInferenceTransitionError::InvalidTransition)?;
        if !state.turn_open {
            return Err(SerialInferenceTransitionError::NoOpenTurn);
        }
        match state.phase {
            SerialPhase::SsdRead => {
                state.phase = SerialPhase::BetweenStages;
                Ok(())
            }
            _ => Err(SerialInferenceTransitionError::InvalidTransition),
        }
    }

    pub fn begin_gpu_compute(&self) -> Result<(), SerialInferenceTransitionError> {
        let mut state = self
            .state
            .lock()
            .map_err(|_| SerialInferenceTransitionError::InvalidTransition)?;
        if !state.turn_open {
            return Err(SerialInferenceTransitionError::NoOpenTurn);
        }
        match state.phase {
            SerialPhase::TurnBoundary | SerialPhase::BetweenStages => {
                state.phase = SerialPhase::GpuCompute;
                Ok(())
            }
            _ => Err(SerialInferenceTransitionError::InvalidTransition),
        }
    }

    pub fn finish_gpu_compute(&self) -> Result<(), SerialInferenceTransitionError> {
        let mut state = self
            .state
            .lock()
            .map_err(|_| SerialInferenceTransitionError::InvalidTransition)?;
        if !state.turn_open {
            return Err(SerialInferenceTransitionError::NoOpenTurn);
        }
        match state.phase {
            SerialPhase::GpuCompute => {
                state.phase = SerialPhase::BetweenStages;
                Ok(())
            }
            _ => Err(SerialInferenceTransitionError::InvalidTransition),
        }
    }

    pub fn snapshot(&self) -> SerialInferenceSnapshot {
        let state = self.state.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
        SerialInferenceSnapshot {
            phase: state.phase.as_str().to_string(),
            fallback_mode: state.fallback_mode.clone(),
            should_stream_experts_from_ssd: state.fallback_mode == SerialFallbackMode::SsdStreaming,
            turn_boundary_readahead_allowed: state.phase == SerialPhase::TurnBoundary,
            expert_prefetch_allowed: false,
            turn_index: state.turn_index,
            available_memory_bytes: state.available_memory_bytes,
            non_expert_resident_bytes: self.non_expert_resident_bytes,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{
        SerialFallbackMode, SerialInferenceController, SerialInferenceTransitionError,
    };

    #[test]
    fn allows_turn_boundary_readahead_but_not_mid_compute_readahead() {
        let controller = SerialInferenceController::new(
            1_200_000_000,
            1_800_000_000,
            3_000_000_000,
        );

        controller.begin_turn().unwrap();
        controller.record_turn_boundary_readahead().unwrap();
        controller.begin_gpu_compute().unwrap();

        let error = controller.record_turn_boundary_readahead().unwrap_err();
        assert!(matches!(
            error,
            SerialInferenceTransitionError::TurnBoundaryOnly
        ));
    }

    #[test]
    fn forbids_disk_reads_during_active_gpu_compute() {
        let controller = SerialInferenceController::new(
            1_200_000_000,
            1_800_000_000,
            3_000_000_000,
        );

        controller.begin_turn().unwrap();
        controller.begin_gpu_compute().unwrap();

        let error = controller.begin_ssd_read().unwrap_err();
        assert!(matches!(
            error,
            SerialInferenceTransitionError::GpuComputeActive
        ));
    }

    #[test]
    fn supports_serial_gpu_and_ssd_alternation_within_a_turn() {
        let controller = SerialInferenceController::new(
            1_200_000_000,
            1_800_000_000,
            3_000_000_000,
        );

        controller.begin_turn().unwrap();
        controller.begin_gpu_compute().unwrap();
        controller.finish_gpu_compute().unwrap();
        controller.begin_ssd_read().unwrap();
        controller.finish_ssd_read().unwrap();
        controller.begin_gpu_compute().unwrap();
        controller.finish_gpu_compute().unwrap();
        controller.end_turn().unwrap();

        let snapshot = controller.snapshot();
        assert_eq!(snapshot.phase, "idle");
        assert_eq!(snapshot.turn_index, 1);
    }

    #[test]
    fn enters_and_recovers_from_ssd_streaming_fallback_based_on_available_memory() {
        let controller = SerialInferenceController::new(
            1_200_000_000,
            1_800_000_000,
            3_000_000_000,
        );

        controller.update_available_memory(900_000_000);
        let pressured = controller.snapshot();
        assert_eq!(pressured.fallback_mode, SerialFallbackMode::SsdStreaming);
        assert!(pressured.should_stream_experts_from_ssd);

        controller.update_available_memory(2_400_000_000);
        let recovered = controller.snapshot();
        assert_eq!(recovered.fallback_mode, SerialFallbackMode::Resident);
        assert!(!recovered.should_stream_experts_from_ssd);
    }
}
