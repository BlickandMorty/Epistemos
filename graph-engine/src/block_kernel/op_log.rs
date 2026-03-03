use crate::block_kernel::op::Op;

/// Append-only operation log. Source of truth for block state.
/// Each op gets a monotonic sequence number.
pub struct OpLog {
    ops: Vec<(u64, Op)>,  // (sequence_number, op)
    next_seq: u64,
}

impl OpLog {
    pub fn new() -> Self {
        Self { ops: Vec::new(), next_seq: 1 }
    }

    /// Append an op and return its sequence number.
    pub fn append(&mut self, op: Op) -> u64 {
        let seq = self.next_seq;
        self.ops.push((seq, op));
        self.next_seq += 1;
        seq
    }

    /// All ops since a given sequence number (exclusive).
    pub fn since(&self, after_seq: u64) -> &[(u64, Op)] {
        // Binary search for the first op with seq > after_seq
        let idx = self.ops.partition_point(|(s, _)| *s <= after_seq);
        &self.ops[idx..]
    }

    pub fn len(&self) -> usize {
        self.ops.len()
    }

    pub fn is_empty(&self) -> bool {
        self.ops.is_empty()
    }

    pub fn latest_seq(&self) -> u64 {
        self.next_seq - 1
    }
}

impl Default for OpLog {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::block_kernel::op::{BlockId, Op};

    #[test]
    fn append_increments_sequence() {
        let mut log = OpLog::new();
        let id = BlockId::new();
        let s1 = log.append(Op::InsertBlock {
            block_id: id, parent_id: None, position: 0,
            content: "hello".into(), depth: 0,
        });
        let s2 = log.append(Op::UpdateBlock {
            block_id: id, content: "world".into(),
        });
        assert_eq!(s1, 1);
        assert_eq!(s2, 2);
        assert_eq!(log.len(), 2);
    }

    #[test]
    fn since_returns_ops_after_seq() {
        let mut log = OpLog::new();
        let id = BlockId::new();
        for i in 0..5 {
            log.append(Op::UpdateBlock {
                block_id: id, content: format!("v{}", i),
            });
        }
        let after_3 = log.since(3);
        assert_eq!(after_3.len(), 2); // seq 4, 5
    }
}
