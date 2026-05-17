//! F-PacketRouter1bit-Dispatch — substrate-floor integration harness.
//!
//! Per `docs/falsifiers/F-PacketRouter1bit-Dispatch_2026_05_17.md` §3.
//!
//! # Substrate-floor scope
//!
//! Exercises `agent_core::helios::packet_router::{route_1bit,
//! unroute_1bit}` at scale + across lane distributions. Production-PASS
//! requires Metal kernel p99 < 100 µs (per F-PacketRouter1bit §4);
//! substrate-floor here proves the CPU reference is correct + has stable
//! identity property across distributions.

use agent_core::helios::{route_1bit, unroute_1bit};

const BATCH_SIZE: usize = 10_000;

fn build_batch_and_bits(seed: u64, bias_inv: u64) -> (Vec<f32>, Vec<bool>) {
    let mut rng = seed;
    let inputs: Vec<f32> = (0..BATCH_SIZE)
        .map(|i| {
            rng = rng.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1_442_695_040_888_963_407);
            (i as f32) + ((rng & 0xFFFF) as f32) / 65536.0
        })
        .collect();
    let bits: Vec<bool> = (0..BATCH_SIZE)
        .map(|_| {
            rng = rng.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1_442_695_040_888_963_407);
            // bias_inv = 2 → 50/50 (half zero, half not). bias_inv = 10 →
            // 1-in-10 hits lane_1 (true). bias_inv = N → 1/N to lane_1.
            (rng % bias_inv) == 0
        })
        .collect();
    (inputs, bits)
}

/// 50/50 dispatch + unroute = identity on 10k batch.
#[test]
fn fifty_fifty_dispatch_round_trips() {
    let (inputs, bits) = build_batch_and_bits(0xC011_1100_u64, 2);
    let (routed, stats) = route_1bit(&inputs, &bits).expect("route must succeed");
    assert_eq!(stats.total_inputs, BATCH_SIZE);
    assert_eq!(stats.routed_to_lane_0 + stats.routed_to_lane_1, BATCH_SIZE);

    let reconstructed = unroute_1bit(&routed, BATCH_SIZE).expect("unroute must succeed");
    assert_eq!(reconstructed.len(), BATCH_SIZE);
    for (i, (a, b)) in inputs.iter().zip(reconstructed.iter()).enumerate() {
        assert_eq!(a, b, "mismatch at {} ({} vs {})", i, a, b);
    }

    // 50/50 distribution should be near-balanced. Substrate-floor: each
    // lane gets at least 30% (no severe imbalance).
    let lane_0_ratio = stats.routed_to_lane_0 as f64 / BATCH_SIZE as f64;
    assert!(
        lane_0_ratio >= 0.30 && lane_0_ratio <= 0.70,
        "50/50 distribution unbalanced: lane_0_ratio = {}",
        lane_0_ratio
    );
}

#[test]
fn ten_ninety_skewed_dispatch_round_trips() {
    let (inputs, bits) = build_batch_and_bits(0xC011_2200_u64, 10);
    let (routed, stats) = route_1bit(&inputs, &bits).unwrap();
    let reconstructed = unroute_1bit(&routed, BATCH_SIZE).unwrap();
    assert_eq!(inputs, reconstructed);

    // 1-in-10 → lane_1 has ~10%.
    let lane_1_ratio = stats.routed_to_lane_1 as f64 / BATCH_SIZE as f64;
    assert!(
        lane_1_ratio < 0.20,
        "10/90 skew: lane_1 should have <20%, got {}",
        lane_1_ratio
    );
}

#[test]
fn ninety_ten_mirror_dispatch_round_trips() {
    let (inputs, _bits) = build_batch_and_bits(0xC011_3300_u64, 10);
    // Flip bits: 10/90 inversed → 90/10.
    let (_, raw_bits) = build_batch_and_bits(0xC011_3300_u64, 10);
    let bits: Vec<bool> = raw_bits.into_iter().map(|b| !b).collect();
    let (routed, stats) = route_1bit(&inputs, &bits).unwrap();
    let reconstructed = unroute_1bit(&routed, BATCH_SIZE).unwrap();
    assert_eq!(inputs, reconstructed);

    let lane_0_ratio = stats.routed_to_lane_0 as f64 / BATCH_SIZE as f64;
    assert!(
        lane_0_ratio < 0.20,
        "90/10 inverse: lane_0 should have <20%, got {}",
        lane_0_ratio
    );
}

#[test]
fn all_zero_bits_routes_everything_to_lane_zero() {
    let (inputs, _) = build_batch_and_bits(0xC011_4400_u64, 2);
    let bits: Vec<bool> = vec![false; BATCH_SIZE];
    let (routed, stats) = route_1bit(&inputs, &bits).unwrap();
    assert_eq!(stats.routed_to_lane_0, BATCH_SIZE);
    assert_eq!(stats.routed_to_lane_1, 0);
    let reconstructed = unroute_1bit(&routed, BATCH_SIZE).unwrap();
    assert_eq!(inputs, reconstructed);
}

#[test]
fn all_one_bits_routes_everything_to_lane_one() {
    let (inputs, _) = build_batch_and_bits(0xC011_5500_u64, 2);
    let bits: Vec<bool> = vec![true; BATCH_SIZE];
    let (routed, stats) = route_1bit(&inputs, &bits).unwrap();
    assert_eq!(stats.routed_to_lane_0, 0);
    assert_eq!(stats.routed_to_lane_1, BATCH_SIZE);
    let reconstructed = unroute_1bit(&routed, BATCH_SIZE).unwrap();
    assert_eq!(inputs, reconstructed);
}

/// Edge case: mismatched bits length surfaces typed error.
#[test]
fn mismatched_bits_length_surfaces_error() {
    let inputs = vec![1.0_f32; 10];
    let bits = vec![false; 5];
    assert!(route_1bit(&inputs, &bits).is_err());
}
