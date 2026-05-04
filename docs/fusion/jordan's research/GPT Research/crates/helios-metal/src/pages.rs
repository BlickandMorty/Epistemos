//! Six-tier page allocator.

use helios_core::{PageHeader, TierState};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct PageHandle {
    pub header: PageHeader,
    pub offset: u64,
    pub byte_len: u64,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct PageAllocator {
    next_page_id: u64,
    next_offset: u64,
}

impl PageAllocator {
    #[must_use]
    pub const fn new() -> Self {
        Self { next_page_id: 1, next_offset: 0 }
    }

    pub fn allocate(&mut self, tier: TierState, token_start: u64, token_len: u32, byte_len: u64) -> PageHandle {
        let page_id = self.next_page_id;
        self.next_page_id += 1;
        let offset = self.next_offset;
        self.next_offset += align_up(byte_len, 4096);
        PageHandle { header: PageHeader::new(tier, page_id, token_start, token_len, checksum(page_id, token_start, token_len)), offset, byte_len }
    }
}

fn align_up(value: u64, alignment: u64) -> u64 {
    ((value + alignment - 1) / alignment) * alignment
}

fn checksum(page_id: u64, token_start: u64, token_len: u32) -> u32 {
    let mixed = page_id ^ token_start ^ u64::from(token_len).wrapping_mul(0x9E37_79B9);
    (mixed ^ (mixed >> 32)) as u32
}

#[cfg(test)]
mod tests {
    use super::PageAllocator;
    use helios_core::TierState;

    #[test]
    fn allocator_aligns_offsets() {
        let mut allocator = PageAllocator::new();
        let a = allocator.allocate(TierState::Hot, 0, 16, 17);
        let b = allocator.allocate(TierState::Residual, 16, 16, 17);
        assert_eq!(a.offset, 0);
        assert_eq!(b.offset, 4096);
    }
}
