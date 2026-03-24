use serde::{Deserialize, Serialize};

/// Training tier for auto-learn scheduling.
/// Exported to Swift via UniFFI as an enum.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TrainingTier {
    None,
    MicroTraining,
    DeepRetraining,
    UserTriggered,
}

/// Result of schedule evaluation — whether to train and at which tier.
/// Exported to Swift via UniFFI as a dictionary type.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrainingDecision {
    pub should_train: bool,
    pub tier: TrainingTier,
    pub reason: String,
    pub dirty_file_count: u64,
    pub days_since_last: i64,
}

/// Evaluate whether training should run and at which tier.
/// Called from Swift on a periodic schedule (e.g., every 30 minutes).
pub fn evaluate_schedule(
    dirty_file_count: usize,
    days_since_micro: i64,
    days_since_deep: i64,
    current_hour: u32,
    current_weekday: u32, // 1 = Sunday per Calendar.current convention
    is_on_battery: bool,
    is_training: bool,
) -> TrainingDecision {
    if is_training {
        return TrainingDecision {
            should_train: false,
            tier: TrainingTier::None,
            reason: "Training already in progress".into(),
            dirty_file_count: dirty_file_count as u64,
            days_since_last: days_since_micro,
        };
    }

    if is_on_battery {
        return TrainingDecision {
            should_train: false,
            tier: TrainingTier::None,
            reason: "On battery — deferred".into(),
            dirty_file_count: dirty_file_count as u64,
            days_since_last: days_since_micro,
        };
    }

    // Tier 3: Weekly deep (Sunday 3 AM, if ≥6 days since last deep)
    if current_weekday == 1 && current_hour == 3 && days_since_deep >= 6 {
        return TrainingDecision {
            should_train: true,
            tier: TrainingTier::DeepRetraining,
            reason: format!("{days_since_deep} days since deep, {dirty_file_count} dirty"),
            dirty_file_count: dirty_file_count as u64,
            days_since_last: days_since_deep,
        };
    }

    // Tier 2: Nightly micro (2-4 AM, dirty threshold or time threshold)
    if (2..=4).contains(&current_hour) && (dirty_file_count > 10 || days_since_micro >= 3) {
        return TrainingDecision {
            should_train: true,
            tier: TrainingTier::MicroTraining,
            reason: format!("{dirty_file_count} dirty, {days_since_micro} days since micro"),
            dirty_file_count: dirty_file_count as u64,
            days_since_last: days_since_micro,
        };
    }

    TrainingDecision {
        should_train: false,
        tier: TrainingTier::None,
        reason: "No training needed".into(),
        dirty_file_count: dirty_file_count as u64,
        days_since_last: days_since_micro,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_battery_defers() {
        let d = evaluate_schedule(50, 5, 10, 3, 1, true, false);
        assert!(!d.should_train);
        assert!(d.reason.contains("battery"));
    }

    #[test]
    fn test_already_training() {
        let d = evaluate_schedule(50, 5, 10, 3, 1, false, true);
        assert!(!d.should_train);
    }

    #[test]
    fn test_deep_sunday_3am() {
        let d = evaluate_schedule(50, 2, 7, 3, 1, false, false);
        assert!(d.should_train);
        assert!(matches!(d.tier, TrainingTier::DeepRetraining));
    }

    #[test]
    fn test_micro_dirty_threshold() {
        let d = evaluate_schedule(15, 1, 2, 3, 3, false, false);
        assert!(d.should_train);
        assert!(matches!(d.tier, TrainingTier::MicroTraining));
    }

    #[test]
    fn test_no_training_midday() {
        let d = evaluate_schedule(5, 1, 2, 14, 3, false, false);
        assert!(!d.should_train);
    }
}
