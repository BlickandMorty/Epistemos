//! `EventRing` — wrapper around `rtrb::RingBuffer` that owns both
//! `Producer` + `Consumer` halves so the C ABI can see one opaque type.
//!
//! Per Wave 5 plan dpp §5.1: SPSC ring buffer with cache-line-padded
//! atomics. The internal `rtrb` crate handles the Acquire/Release fence
//! correctness; this wrapper only adapts the API to the C ABI shape
//! the Swift caller expects.
//!
//! Concurrency model: `try_push` is called from ONE Rust producer
//! thread; `drain` is called from ONE Swift consumer thread (typically
//! `@MainActor` once per CADisplayLink tick). Calling either method
//! from multiple threads at once is undefined behaviour — the SPSC
//! guarantee comes from the caller.

use std::sync::Mutex;

use crossbeam_utils::CachePadded;
use rtrb::{Consumer, Producer, PushError, RingBuffer};

use crate::graph_event::GraphEvent;

/// Errors callers may want to distinguish. The C ABI surface collapses
/// these to `bool` / `usize`; the Rust API exposes them for unit tests
/// and the eventual Swift module-map type.
#[derive(Debug)]
pub enum EventRingError {
    /// Push attempted on a full ring.
    Full,
}

/// Wrapper around `rtrb`'s producer + consumer halves so the C ABI
/// surface can hold the entire ring behind one opaque pointer.
///
/// Both halves are guarded by their own `Mutex` so the C ABI is
/// safe-by-construction even if a Swift caller violates the SPSC
/// contract by accident — the Mutex serialises the access at the
/// cost of a brief lock acquisition. The lock is uncontended in the
/// canonical SPSC use, so the cost is minimal (~10ns on Apple
/// Silicon per lock+unlock when uncontended).
///
/// `CachePadded` wraps each Mutex to keep the producer's Mutex on a
/// different cache line from the consumer's — false sharing on the
/// producer/consumer atomics would tank throughput on a 128-byte L2
/// line system.
pub struct EventRing {
    producer: CachePadded<Mutex<Producer<GraphEvent>>>,
    consumer: CachePadded<Mutex<Consumer<GraphEvent>>>,
    capacity: usize,
}

impl EventRing {
    /// Construct a ring with the given capacity. `rtrb` rounds capacity
    /// UP to the next power of two so its modulo is a single AND.
    /// The recorded `capacity()` is the requested value, not the
    /// rounded one (the ring may hold up to the rounded value of
    /// pending events).
    pub fn with_capacity(capacity: usize) -> Self {
        let (producer, consumer) = RingBuffer::<GraphEvent>::new(capacity);
        Self {
            producer: CachePadded::new(Mutex::new(producer)),
            consumer: CachePadded::new(Mutex::new(consumer)),
            capacity,
        }
    }

    /// The capacity requested at construction time. The ring may hold
    /// up to `capacity.next_power_of_two()` pending events in practice.
    pub fn capacity(&self) -> usize {
        self.capacity
    }

    /// Push one event. Returns `true` on success, `false` when the
    /// ring is full. Non-blocking. SPSC: caller guarantees only one
    /// producer thread is active.
    pub fn try_push(&self, event: GraphEvent) -> bool {
        let Ok(mut producer) = self.producer.lock() else {
            return false;
        };
        match producer.push(event) {
            Ok(()) => true,
            Err(PushError::Full(_)) => false,
        }
    }

    /// Drain up to `out.len()` events into `out`. Returns the number
    /// actually written. Non-blocking. SPSC: caller guarantees only
    /// one consumer thread is active.
    pub fn drain(&self, out: &mut [GraphEvent]) -> usize {
        if out.is_empty() {
            return 0;
        }
        let Ok(mut consumer) = self.consumer.lock() else {
            return 0;
        };

        let mut written = 0;
        while written < out.len() {
            match consumer.pop() {
                Ok(event) => {
                    out[written] = event;
                    written += 1;
                }
                Err(_) => break, // empty ring
            }
        }
        written
    }

    /// Approximate live event count (producer pushes ahead of consumer
    /// drains). Snapshot only — by the time the caller reads the value,
    /// the real count may have changed.
    pub fn pending(&self) -> usize {
        let Ok(consumer) = self.consumer.lock() else {
            return 0;
        };
        consumer.slots()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::graph_event::GraphEventKind;
    use std::sync::Arc;
    use std::thread;
    use std::time::Duration;

    #[test]
    fn push_and_drain_round_trips_one_event() {
        let ring = EventRing::with_capacity(8);
        let event = GraphEvent::new(GraphEventKind::CursorMove, [42; 56]);
        assert!(ring.try_push(event));
        assert_eq!(ring.pending(), 1);

        let mut out = vec![GraphEvent::SENTINEL; 8];
        let count = ring.drain(&mut out);
        assert_eq!(count, 1);
        assert_eq!(out[0].kind, GraphEventKind::CursorMove as u8);
        assert_eq!(out[0].data, [42; 56]);
        assert_eq!(ring.pending(), 0);
    }

    #[test]
    fn drain_empty_ring_returns_zero() {
        let ring = EventRing::with_capacity(8);
        let mut out = vec![GraphEvent::SENTINEL; 4];
        assert_eq!(ring.drain(&mut out), 0);
    }

    #[test]
    fn try_push_returns_false_when_full() {
        // rtrb rounds capacity up to the next power of two, so
        // a requested capacity of 4 holds 4 events.
        let ring = EventRing::with_capacity(4);
        for i in 0..4 {
            let payload = {
                let mut p = [0u8; 56];
                p[0] = i as u8;
                p
            };
            assert!(ring.try_push(GraphEvent::new(GraphEventKind::EditDelta, payload)));
        }
        // The next push must fail until the consumer drains.
        assert!(!ring.try_push(GraphEvent::SENTINEL));

        let mut out = vec![GraphEvent::SENTINEL; 4];
        assert_eq!(ring.drain(&mut out), 4);
        // After draining, push works again.
        assert!(ring.try_push(GraphEvent::SENTINEL));
    }

    #[test]
    fn drain_into_smaller_buffer_returns_buffer_len() {
        let ring = EventRing::with_capacity(8);
        for i in 0..6 {
            let payload = {
                let mut p = [0u8; 56];
                p[0] = i as u8;
                p
            };
            ring.try_push(GraphEvent::new(GraphEventKind::EditDelta, payload));
        }
        let mut out = vec![GraphEvent::SENTINEL; 3];
        assert_eq!(ring.drain(&mut out), 3);
        for (i, ev) in out.iter().enumerate() {
            assert_eq!(ev.data[0], i as u8, "drain must preserve push order");
        }
        assert_eq!(ring.pending(), 3);
    }

    #[test]
    fn spsc_concurrent_push_and_drain_round_trips_payload() {
        // Simulate the canonical Rust producer thread + Swift consumer
        // thread pattern: producer pushes 1024 events, consumer drains
        // until it has seen them all.
        let ring = Arc::new(EventRing::with_capacity(64));
        let producer_ring = Arc::clone(&ring);
        let consumer_ring = Arc::clone(&ring);
        const TOTAL: usize = 1024;

        let producer = thread::spawn(move || {
            let mut sent = 0;
            while sent < TOTAL {
                let payload = {
                    let mut p = [0u8; 56];
                    p[0] = (sent % 256) as u8;
                    p[1] = ((sent >> 8) % 256) as u8;
                    p
                };
                let event = GraphEvent::new(GraphEventKind::EditDelta, payload);
                while !producer_ring.try_push(event) {
                    thread::sleep(Duration::from_micros(10));
                }
                sent += 1;
            }
        });

        let consumer = thread::spawn(move || {
            let mut received: Vec<GraphEvent> = Vec::with_capacity(TOTAL);
            let mut buf = vec![GraphEvent::SENTINEL; 32];
            while received.len() < TOTAL {
                let count = consumer_ring.drain(&mut buf);
                if count == 0 {
                    thread::sleep(Duration::from_micros(10));
                    continue;
                }
                received.extend_from_slice(&buf[..count]);
            }
            received
        });

        producer.join().unwrap();
        let received = consumer.join().unwrap();

        assert_eq!(received.len(), TOTAL);
        for (idx, ev) in received.iter().enumerate() {
            assert_eq!(ev.kind, GraphEventKind::EditDelta as u8);
            assert_eq!(ev.data[0], (idx % 256) as u8);
            assert_eq!(ev.data[1], ((idx >> 8) % 256) as u8);
        }
    }

    #[test]
    fn capacity_is_recorded_verbatim() {
        let ring = EventRing::with_capacity(100);
        assert_eq!(ring.capacity(), 100);
    }
}
