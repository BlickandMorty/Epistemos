use fsrs::{current_retrievability, MemoryState, DEFAULT_PARAMETERS, FSRS, FSRS6_DEFAULT_DECAY};

const SECONDS_PER_DAY: f64 = 86_400.0;
const MIN_DIFFICULTY: f64 = 1.0;
const MAX_DIFFICULTY: f64 = 10.0;

#[derive(Debug, Clone, PartialEq)]
pub struct FsrsMemoryState {
    pub difficulty: f64,
    pub stability: f64,
    pub retrievability: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct FsrsDecayRow {
    pub note_id: String,
    pub last_reviewed: f64,
    pub memory: FsrsMemoryState,
    pub last_grade: u32,
    pub reviews: u32,
}

#[derive(Debug, Clone, PartialEq)]
pub struct FsrsReviewOutcome {
    pub row: FsrsDecayRow,
    pub interval_days: f64,
}

#[derive(Debug, thiserror::Error)]
pub enum FsrsDecayError {
    #[error("invalid note id")]
    InvalidNoteId,
    #[error("invalid timestamp")]
    InvalidTimestamp,
    #[error("invalid memory state")]
    InvalidMemoryState,
    #[error("invalid review grade")]
    InvalidGrade,
    #[error("invalid desired retention")]
    InvalidDesiredRetention,
    #[error("scheduler rejected input")]
    Scheduler,
}

pub fn default_parameters() -> Vec<f64> {
    DEFAULT_PARAMETERS
        .iter()
        .map(|value| *value as f64)
        .collect()
}

pub fn current(memory: FsrsMemoryState, days_elapsed: f64) -> Result<f64, FsrsDecayError> {
    let state = to_fsrs_memory_state(&memory)?;
    let days = finite_nonnegative_f32(days_elapsed, FsrsDecayError::InvalidTimestamp)?;
    Ok(current_retrievability(state, days, FSRS6_DEFAULT_DECAY) as f64)
}

pub fn row_current(row: FsrsDecayRow, now_timestamp: f64) -> Result<f64, FsrsDecayError> {
    validate_row(&row)?;
    let elapsed_seconds = elapsed_seconds(row.last_reviewed, now_timestamp)?;
    current(row.memory, elapsed_seconds / SECONDS_PER_DAY)
}

pub fn schedule_review(
    row: FsrsDecayRow,
    grade: u32,
    reviewed_at: f64,
    desired_retention: f64,
) -> Result<FsrsReviewOutcome, FsrsDecayError> {
    validate_row(&row)?;
    validate_grade(grade)?;
    validate_timestamp(reviewed_at)?;

    let retention = finite_open_unit_f32(desired_retention)?;
    let elapsed_days = elapsed_days_u32(row.last_reviewed, reviewed_at)?;
    let current_memory = if row.reviews == 0 && row.last_grade == 0 {
        None
    } else {
        Some(to_fsrs_memory_state(&row.memory)?)
    };

    let scheduler = FSRS::new(Some(&DEFAULT_PARAMETERS)).map_err(|_| FsrsDecayError::Scheduler)?;
    let next_states = scheduler
        .next_states(current_memory, retention, elapsed_days)
        .map_err(|_| FsrsDecayError::Scheduler)?;
    let selected = match grade {
        1 => next_states.again,
        2 => next_states.hard,
        3 => next_states.good,
        4 => next_states.easy,
        _ => return Err(FsrsDecayError::InvalidGrade),
    };

    validate_scheduled_memory(selected.memory)?;
    if !selected.interval.is_finite() || selected.interval < 0.0 {
        return Err(FsrsDecayError::Scheduler);
    }

    let next_row = FsrsDecayRow {
        note_id: row.note_id,
        last_reviewed: reviewed_at,
        memory: FsrsMemoryState {
            difficulty: selected.memory.difficulty as f64,
            stability: selected.memory.stability as f64,
            retrievability: 1.0,
        },
        last_grade: grade,
        reviews: row.reviews.saturating_add(1),
    };

    Ok(FsrsReviewOutcome {
        row: next_row,
        interval_days: selected.interval as f64,
    })
}

fn validate_row(row: &FsrsDecayRow) -> Result<(), FsrsDecayError> {
    if row.note_id.trim().is_empty() {
        return Err(FsrsDecayError::InvalidNoteId);
    }
    validate_timestamp(row.last_reviewed)?;
    to_fsrs_memory_state(&row.memory)?;
    if row.reviews > 0 || row.last_grade != 0 {
        validate_grade(row.last_grade)?;
    }
    Ok(())
}

fn validate_grade(grade: u32) -> Result<(), FsrsDecayError> {
    if (1..=4).contains(&grade) {
        Ok(())
    } else {
        Err(FsrsDecayError::InvalidGrade)
    }
}

fn validate_timestamp(timestamp: f64) -> Result<(), FsrsDecayError> {
    if timestamp.is_finite() && timestamp >= 0.0 {
        Ok(())
    } else {
        Err(FsrsDecayError::InvalidTimestamp)
    }
}

fn validate_scheduled_memory(memory: MemoryState) -> Result<(), FsrsDecayError> {
    if memory.difficulty.is_finite()
        && (MIN_DIFFICULTY as f32..=MAX_DIFFICULTY as f32).contains(&memory.difficulty)
        && memory.stability.is_finite()
        && memory.stability > 0.0
    {
        Ok(())
    } else {
        Err(FsrsDecayError::InvalidMemoryState)
    }
}

fn to_fsrs_memory_state(memory: &FsrsMemoryState) -> Result<MemoryState, FsrsDecayError> {
    if !memory.difficulty.is_finite()
        || !(MIN_DIFFICULTY..=MAX_DIFFICULTY).contains(&memory.difficulty)
        || !memory.stability.is_finite()
        || memory.stability <= 0.0
        || !memory.retrievability.is_finite()
        || !(0.0..=1.0).contains(&memory.retrievability)
    {
        return Err(FsrsDecayError::InvalidMemoryState);
    }
    Ok(MemoryState {
        stability: memory.stability as f32,
        difficulty: memory.difficulty as f32,
    })
}

fn finite_nonnegative_f32(value: f64, error: FsrsDecayError) -> Result<f32, FsrsDecayError> {
    if value.is_finite() && value >= 0.0 && value <= f32::MAX as f64 {
        Ok(value as f32)
    } else {
        Err(error)
    }
}

fn finite_open_unit_f32(value: f64) -> Result<f32, FsrsDecayError> {
    if value.is_finite() && value > 0.0 && value < 1.0 {
        Ok(value as f32)
    } else {
        Err(FsrsDecayError::InvalidDesiredRetention)
    }
}

fn elapsed_seconds(start_timestamp: f64, end_timestamp: f64) -> Result<f64, FsrsDecayError> {
    validate_timestamp(start_timestamp)?;
    validate_timestamp(end_timestamp)?;
    Ok((end_timestamp - start_timestamp).max(0.0))
}

fn elapsed_days_u32(start_timestamp: f64, end_timestamp: f64) -> Result<u32, FsrsDecayError> {
    let days = (elapsed_seconds(start_timestamp, end_timestamp)? / SECONDS_PER_DAY).floor();
    if days <= u32::MAX as f64 {
        Ok(days as u32)
    } else {
        Err(FsrsDecayError::InvalidTimestamp)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fresh_row() -> FsrsDecayRow {
        FsrsDecayRow {
            note_id: "note-1".to_string(),
            last_reviewed: 0.0,
            memory: FsrsMemoryState {
                difficulty: 5.0,
                stability: 1.0,
                retrievability: 1.0,
            },
            last_grade: 0,
            reviews: 0,
        }
    }

    #[test]
    fn default_parameters_are_fsrs6_shape() {
        let parameters = default_parameters();
        assert_eq!(parameters.len(), 21);
        assert!((parameters[20] - FSRS6_DEFAULT_DECAY as f64).abs() < f64::EPSILON);
    }

    #[test]
    fn current_retrievability_matches_fsrs_curve_at_stability() {
        let memory = FsrsMemoryState {
            difficulty: 5.0,
            stability: 5.0,
            retrievability: 1.0,
        };

        let fresh = current(memory.clone(), 0.0).expect("fresh memory should score");
        let at_stability = current(memory, 5.0).expect("stable memory should score");

        assert!((fresh - 1.0).abs() < 0.0001);
        assert!((at_stability - 0.9).abs() < 0.0001);
    }

    #[test]
    fn row_current_clamps_future_last_review_to_fresh() {
        let mut row = fresh_row();
        row.last_reviewed = 200.0;

        let retrievability = row_current(row, 100.0).expect("clock skew should clamp");

        assert!((retrievability - 1.0).abs() < 0.0001);
    }

    #[test]
    fn schedule_review_updates_row_from_fsrs_next_states() {
        let outcome =
            schedule_review(fresh_row(), 3, 0.0, 0.9).expect("fresh review should schedule");

        assert_eq!(outcome.row.note_id, "note-1");
        assert_eq!(outcome.row.last_grade, 3);
        assert_eq!(outcome.row.reviews, 1);
        assert_eq!(outcome.row.memory.retrievability, 1.0);
        assert!(outcome.row.memory.difficulty.is_finite());
        assert!(outcome.row.memory.stability.is_finite());
        assert!(outcome.interval_days.is_finite());
        assert!(outcome.interval_days >= 0.0);
    }

    #[test]
    fn schedule_review_rejects_invalid_grade() {
        let error = schedule_review(fresh_row(), 5, 0.0, 0.9)
            .expect_err("grade outside FSRS range should fail");

        assert!(matches!(error, FsrsDecayError::InvalidGrade));
    }

    #[test]
    fn schedule_review_rejects_nonfinite_inputs() {
        let mut row = fresh_row();
        row.memory.retrievability = f64::NAN;

        let error = schedule_review(row, 3, 0.0, 0.9).expect_err("nonfinite memory should fail");

        assert!(matches!(error, FsrsDecayError::InvalidMemoryState));
    }

    #[test]
    fn reviewed_rows_require_last_grade() {
        let mut row = fresh_row();
        row.reviews = 1;

        let error = schedule_review(row, 3, 0.0, 0.9).expect_err("corrupt row should fail closed");

        assert!(matches!(error, FsrsDecayError::InvalidGrade));
    }
}
