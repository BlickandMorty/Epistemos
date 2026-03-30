use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

pub const DEFAULT_GARBAGE_THRESHOLD: f64 = 0.15;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Importance {
    Critical,
    High,
    Normal,
    Low,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct NodeStrength {
    pub strength: f64,
    pub importance: Importance,
    pub decay_rate: f64,
    pub last_accessed: DateTime<Utc>,
    pub access_count: u32,
    pub pinned: bool,
}

impl Importance {
    pub fn decay_rate(self) -> f64 {
        match self {
            Self::Critical => 0.005,
            Self::High => 0.01,
            Self::Normal => 0.05,
            Self::Low => 0.1,
        }
    }
}

impl NodeStrength {
    pub fn new(importance: Importance, strength: f64, last_accessed: DateTime<Utc>) -> Self {
        Self {
            strength: strength.clamp(0.0, 1.0),
            importance,
            decay_rate: importance.decay_rate(),
            last_accessed,
            access_count: 0,
            pinned: false,
        }
    }
}

pub fn decay(node: &mut NodeStrength, now: DateTime<Utc>) {
    if now <= node.last_accessed {
        return;
    }

    if node.pinned {
        node.strength = 1.0;
        node.last_accessed = now;
        return;
    }

    let elapsed_seconds = (now - node.last_accessed).num_seconds();
    if elapsed_seconds <= 0 {
        return;
    }

    let elapsed_days = elapsed_seconds as f64 / 86_400.0;
    let decay_factor = (-node.decay_rate * elapsed_days).exp();
    node.strength = (node.strength * decay_factor).clamp(0.0, 1.0);
    node.last_accessed = now;
}

pub fn access(node: &mut NodeStrength) {
    access_at(node, Utc::now());
}

pub fn pin(node: &mut NodeStrength) {
    node.pinned = true;
    node.strength = 1.0;
}

pub fn collect_garbage(nodes: &mut Vec<NodeStrength>, threshold: f64) -> Vec<NodeStrength> {
    let threshold = if threshold <= 0.0 {
        DEFAULT_GARBAGE_THRESHOLD
    } else {
        threshold
    };
    let mut removed = Vec::new();
    let mut kept = Vec::with_capacity(nodes.len());

    for node in nodes.drain(..) {
        if !node.pinned && node.strength < threshold {
            removed.push(node);
        } else {
            kept.push(node);
        }
    }

    *nodes = kept;
    removed
}

pub fn batch_decay(nodes: &mut [NodeStrength], now: DateTime<Utc>) {
    for node in nodes {
        if node.pinned {
            node.strength = 1.0;
            node.last_accessed = now;
            continue;
        }

        if now <= node.last_accessed {
            continue;
        }

        let elapsed_seconds = (now - node.last_accessed).num_seconds();
        if elapsed_seconds <= 0 {
            continue;
        }

        let elapsed_days = elapsed_seconds as f64 / 86_400.0;
        let decay_factor = (-node.decay_rate * elapsed_days).exp();
        node.strength = (node.strength * decay_factor).clamp(0.0, 1.0);
        node.last_accessed = now;
    }
}

fn access_at(node: &mut NodeStrength, now: DateTime<Utc>) {
    node.strength = 1.0;
    node.access_count = node.access_count.saturating_add(1);
    node.last_accessed = now;
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{Duration, TimeZone};

    fn node(importance: Importance, strength: f64) -> NodeStrength {
        NodeStrength::new(
            importance,
            strength,
            Utc.with_ymd_and_hms(2026, 3, 1, 12, 0, 0).unwrap(),
        )
    }

    #[test]
    fn memory_decay_reaches_e_to_negative_one_after_one_lambda_period() {
        let mut node = node(Importance::Normal, 1.0);
        let now = node.last_accessed + Duration::days(20);

        decay(&mut node, now);

        assert!((node.strength - std::f64::consts::E.powf(-1.0)).abs() < 0.02);
    }

    #[test]
    fn memory_decay_pinned_nodes_stay_at_full_strength() {
        let mut node = node(Importance::Low, 0.42);
        pin(&mut node);
        let now = node.last_accessed + Duration::days(365);

        decay(&mut node, now);

        assert_eq!(node.strength, 1.0);
        assert!(node.pinned);
    }

    #[test]
    fn memory_decay_access_resets_strength_and_increments_count() {
        let mut node = node(Importance::High, 0.14);
        node.access_count = 3;

        let now = Utc.with_ymd_and_hms(2026, 3, 2, 9, 0, 0).unwrap();
        access_at(&mut node, now);

        assert_eq!(node.strength, 1.0);
        assert_eq!(node.access_count, 4);
        assert_eq!(node.last_accessed, now);
    }

    #[test]
    fn memory_decay_collect_garbage_removes_weak_unpinned_nodes() {
        let mut nodes = vec![
            node(Importance::Low, 0.05),
            node(Importance::Normal, 0.8),
            NodeStrength {
                pinned: true,
                ..node(Importance::Low, 0.01)
            },
        ];

        let removed = collect_garbage(&mut nodes, 0.15);

        assert_eq!(removed.len(), 1);
        assert_eq!(nodes.len(), 2);
        assert!(nodes.iter().any(|entry| entry.pinned));
    }

    #[test]
    fn memory_decay_batch_handles_ten_thousand_nodes_quickly() {
        let mut nodes = (0..10_000)
            .map(|_| node(Importance::Normal, 1.0))
            .collect::<Vec<_>>();
        let now = Utc.with_ymd_and_hms(2026, 3, 11, 12, 0, 0).unwrap();
        let started = std::time::Instant::now();

        batch_decay(&mut nodes, now);

        assert!(started.elapsed().as_millis() < 10);
        assert!(nodes.iter().all(|entry| entry.strength < 1.0));
    }
}
