//! Top-k recall benchmark.

#[derive(Clone, Debug, PartialEq)]
pub struct RecallCase {
    pub truth: Vec<u64>,
    pub predicted: Vec<u64>,
}

#[must_use]
pub fn top_k_recall(case: &RecallCase, k: usize) -> f32 {
    if case.truth.is_empty() { return 1.0; }
    let top: Vec<u64> = case.predicted.iter().take(k).copied().collect();
    let hits = case.truth.iter().filter(|item| top.contains(item)).count();
    hits as f32 / case.truth.len() as f32
}

#[cfg(test)]
mod tests {
    use super::{top_k_recall, RecallCase};

    #[test]
    fn computes_recall() {
        let case = RecallCase { truth: vec![1, 2], predicted: vec![2, 3, 1] };
        assert_eq!(top_k_recall(&case, 2), 0.5);
        assert_eq!(top_k_recall(&case, 3), 1.0);
    }
}
