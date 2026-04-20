/// Triple-buffered shared position buffers for zero-copy graph rendering.
///
/// Swift creates three `MTLBuffer`s with `.storageModeShared` and passes
/// their `contents()` pointers to Rust. Rust writes node positions directly
/// into Metal-visible memory. A `DispatchSemaphore(value: 3)` on the Swift
/// side prevents writing to a buffer the GPU is still reading.
///
/// Feature-gated behind `shared-position-buffers`.

const MAX_BUFFERS: usize = 3;

pub struct SharedPositionBuffers {
    buffers: [Option<SharedBuffer>; MAX_BUFFERS],
    current_write: u32,
}

struct SharedBuffer {
    ptr: *mut f32,
    capacity_floats: u32,
}

// SAFETY: SharedBuffer holds a raw pointer to Metal shared memory allocated
// by Swift. Access is synchronized by the triple-buffer semaphore protocol.
unsafe impl Send for SharedBuffer {}
unsafe impl Sync for SharedBuffer {}

impl SharedPositionBuffers {
    pub fn new() -> Self {
        Self {
            buffers: [None, None, None],
            current_write: 0,
        }
    }

    /// Register a shared buffer from Swift.
    ///
    /// # Safety
    /// `ptr` must point to at least `capacity_floats * sizeof(f32)` bytes of
    /// writable memory that remains valid until `unset_buffer` is called.
    pub unsafe fn set_buffer(&mut self, index: u32, ptr: *mut f32, capacity_floats: u32) {
        if (index as usize) < MAX_BUFFERS && !ptr.is_null() {
            self.buffers[index as usize] = Some(SharedBuffer {
                ptr,
                capacity_floats,
            });
        }
    }

    pub fn unset_buffer(&mut self, index: u32) {
        if (index as usize) < MAX_BUFFERS {
            self.buffers[index as usize] = None;
        }
    }

    /// Write node positions into the specified buffer as interleaved `[x, y, x, y, ...]`.
    /// Returns the number of nodes written.
    ///
    /// # Safety
    /// The caller must ensure no other thread (including GPU) reads from
    /// `buffer_index` during this call. Use the semaphore protocol.
    pub unsafe fn write_positions(
        &self,
        buffer_index: u32,
        positions_x: &[f32],
        positions_y: &[f32],
    ) -> u32 {
        let idx = buffer_index as usize;
        if idx >= MAX_BUFFERS {
            return 0;
        }
        let buf = match &self.buffers[idx] {
            Some(b) => b,
            None => return 0,
        };

        let node_count = positions_x.len().min(positions_y.len());
        let floats_needed = node_count * 2;
        if floats_needed > buf.capacity_floats as usize {
            return 0;
        }

        // SAFETY: caller guarantees exclusive access to this buffer slot.
        let dst = unsafe { std::slice::from_raw_parts_mut(buf.ptr, floats_needed) };
        for i in 0..node_count {
            dst[i * 2] = positions_x[i];
            dst[i * 2 + 1] = positions_y[i];
        }

        node_count as u32
    }

    pub fn advance_write_index(&mut self) {
        self.current_write = (self.current_write + 1) % MAX_BUFFERS as u32;
    }

    pub fn current_write_index(&self) -> u32 {
        self.current_write
    }
}

impl Default for SharedPositionBuffers {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn write_positions_basic() {
        let mut bufs = SharedPositionBuffers::new();

        let mut data = vec![0.0_f32; 20];
        // SAFETY: `data` is a live writable allocation with capacity for the
        // declared float count for the lifetime of this test.
        unsafe {
            bufs.set_buffer(0, data.as_mut_ptr(), 20);
        }

        let xs = [1.0, 2.0, 3.0];
        let ys = [4.0, 5.0, 6.0];
        // SAFETY: the buffer slot was just registered above and this test has
        // exclusive access to the backing storage.
        let count = unsafe { bufs.write_positions(0, &xs, &ys) };
        assert_eq!(count, 3);
        assert_eq!(data[0], 1.0);
        assert_eq!(data[1], 4.0);
        assert_eq!(data[2], 2.0);
        assert_eq!(data[3], 5.0);
        assert_eq!(data[4], 3.0);
        assert_eq!(data[5], 6.0);
    }

    #[test]
    fn write_to_unset_buffer_returns_zero() {
        let bufs = SharedPositionBuffers::new();
        let xs = [1.0];
        let ys = [2.0];
        // SAFETY: calling `write_positions` on an unset slot is permitted by
        // the API contract and should fail closed without dereferencing.
        let count = unsafe { bufs.write_positions(0, &xs, &ys) };
        assert_eq!(count, 0);
    }

    #[test]
    fn capacity_overflow_returns_zero() {
        let mut bufs = SharedPositionBuffers::new();
        let mut data = vec![0.0_f32; 4];
        // SAFETY: `data` stays alive for the full test and the registered
        // capacity matches the backing allocation.
        unsafe {
            bufs.set_buffer(0, data.as_mut_ptr(), 4);
        }

        let xs = [1.0, 2.0, 3.0];
        let ys = [4.0, 5.0, 6.0];
        // SAFETY: the slot is registered and exclusively owned by this test;
        // the method should reject the oversized write before touching memory.
        let count = unsafe { bufs.write_positions(0, &xs, &ys) };
        assert_eq!(count, 0);
    }

    #[test]
    fn advance_write_index_cycles() {
        let mut bufs = SharedPositionBuffers::new();
        assert_eq!(bufs.current_write_index(), 0);
        bufs.advance_write_index();
        assert_eq!(bufs.current_write_index(), 1);
        bufs.advance_write_index();
        assert_eq!(bufs.current_write_index(), 2);
        bufs.advance_write_index();
        assert_eq!(bufs.current_write_index(), 0);
    }
}
