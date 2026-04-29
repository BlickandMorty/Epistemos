//! Simulation Mode reducer baseline bench (S0).
//!
//! S0 is the perf-gate substrate; the actual reducer lands in S2/S4.
//! This bench harness exists so signposts and criterion tooling are
//! wired end-to-end and a `criterion` baseline can be captured for
//! DOCTRINE.md §12 budget tracking once real reducer work lands.
//!
//! At S0 the bench exercises only the perf module's own interval scope
//! and event signpost — enough to verify benches build, run, and emit
//! the framework's signposts so Instruments → Signposts shows the
//! `epistemos.simulation.theater.*` intervals (S0 acceptance gate).

use agent_core::perf::{theater, IntervalScope};
use criterion::{criterion_group, criterion_main, Criterion};
use std::hint::black_box;

fn bench_signpost_interval(c: &mut Criterion) {
    let log = theater();
    c.bench_function("perf::signpost_interval_baseline", |b| {
        b.iter(|| {
            let _scope = IntervalScope::new(log, c"baseline");
            black_box(42_u64);
        })
    });
}

fn bench_signpost_event(c: &mut Criterion) {
    let log = theater();
    c.bench_function("perf::signpost_event_baseline", |b| {
        b.iter(|| {
            log.event(c"baseline_event");
        })
    });
}

criterion_group!(perf, bench_signpost_interval, bench_signpost_event);
criterion_main!(perf);
