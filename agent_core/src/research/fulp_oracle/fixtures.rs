use super::binary16::Fp16Bits;
use serde::{Deserialize, Serialize};

pub const CLOSED_INTERVAL_MIN: f64 = 0.5;
pub const CLOSED_INTERVAL_MAX: f64 = 2.0;
pub const STRATIFIED_POINT_COUNT: usize = 412_000;
pub const ADVERSARIAL_POINT_COUNT: usize = 2_048;
pub const TOTAL_POINT_COUNT: usize = STRATIFIED_POINT_COUNT + ADVERSARIAL_POINT_COUNT;

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum FulpPointKind {
    Stratified,
    Adversarial,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum FulpAxis {
    StratifiedLog,
    ClosedIntervalEdge,
    ExpOutputMidpoint,
    LnOutputMidpoint,
    EmlCrossMidpoint,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct FulpPoint {
    pub index: usize,
    pub kind: FulpPointKind,
    pub axis: FulpAxis,
    pub x: f64,
    pub y: f64,
}

pub fn stratified_point(index: usize, count: usize) -> FulpPoint {
    assert!(count >= 2);
    assert!(index < count);

    let log_min = CLOSED_INTERVAL_MIN.ln();
    let log_max = CLOSED_INTERVAL_MAX.ln();
    let span = log_max - log_min;
    let x_t = index as f64 / (count - 1) as f64;
    let y_rank = (index * 131_071) % count;
    let y_t = y_rank as f64 / (count - 1) as f64;

    FulpPoint {
        index,
        kind: FulpPointKind::Stratified,
        axis: FulpAxis::StratifiedLog,
        x: (log_min + x_t * span).exp(),
        y: (log_min + y_t * span).exp(),
    }
}

pub fn adversarial_fixture(index: usize) -> FulpPoint {
    assert!(index < ADVERSARIAL_POINT_COUNT);

    let local = index / 4;
    let axis_slot = index % 4;
    let base_index = STRATIFIED_POINT_COUNT + index;

    match axis_slot {
        0 => edge_fixture(base_index, local),
        1 => exp_midpoint_fixture(base_index, local),
        2 => ln_midpoint_fixture(base_index, local),
        _ => eml_cross_fixture(base_index, local),
    }
}

fn edge_fixture(index: usize, local: usize) -> FulpPoint {
    const ANCHORS: [u16; 8] = [
        0x3800, // 0.5
        0x3801, // next after 0.5
        0x3bff, // next before 1.0
        0x3c00, // 1.0
        0x3c01, // next after 1.0
        0x3fff, // next before 2.0
        0x4000, // 2.0
        0x3c00, // repeat center to keep the axis balanced
    ];
    let x = Fp16Bits::from_bits(ANCHORS[local % ANCHORS.len()]).to_f64();
    let y = Fp16Bits::from_bits(ANCHORS[(local * 5 + 3) % ANCHORS.len()]).to_f64();
    point(index, FulpAxis::ClosedIntervalEdge, x, y)
}

fn exp_midpoint_fixture(index: usize, local: usize) -> FulpPoint {
    let x = exp_midpoint_x(local);
    let y = edge_y(local * 7 + 1);
    point(index, FulpAxis::ExpOutputMidpoint, x, y)
}

fn ln_midpoint_fixture(index: usize, local: usize) -> FulpPoint {
    let x = edge_y(local * 11 + 2);
    let y = ln_midpoint_y(local);
    point(index, FulpAxis::LnOutputMidpoint, x, y)
}

fn eml_cross_fixture(index: usize, local: usize) -> FulpPoint {
    let x = exp_midpoint_x(local * 17 + 5);
    let y = ln_midpoint_y(local * 19 + 7);
    point(index, FulpAxis::EmlCrossMidpoint, x, y)
}

fn point(index: usize, axis: FulpAxis, x: f64, y: f64) -> FulpPoint {
    debug_assert!(
        (CLOSED_INTERVAL_MIN..=CLOSED_INTERVAL_MAX).contains(&x),
        "{x}"
    );
    debug_assert!(
        (CLOSED_INTERVAL_MIN..=CLOSED_INTERVAL_MAX).contains(&y),
        "{y}"
    );
    FulpPoint {
        index,
        kind: FulpPointKind::Adversarial,
        axis,
        x,
        y,
    }
}

fn edge_y(local: usize) -> f64 {
    const ANCHORS: [u16; 6] = [0x3800, 0x3801, 0x3c00, 0x3c01, 0x3fff, 0x4000];
    Fp16Bits::from_bits(ANCHORS[local % ANCHORS.len()]).to_f64()
}

fn exp_midpoint_x(local: usize) -> f64 {
    let min_bits = Fp16Bits::from_f64(CLOSED_INTERVAL_MIN.exp()).bits() + 4;
    let max_bits = Fp16Bits::from_f64(CLOSED_INTERVAL_MAX.exp()).bits() - 4;
    let span = (max_bits - min_bits) as usize;
    let bits = min_bits + ((local * 1543) % span) as u16;
    let midpoint = Fp16Bits::from_bits(bits)
        .midpoint_to_next_positive()
        .expect("selected exp half bin must have a finite successor");
    midpoint.ln()
}

fn ln_midpoint_y(local: usize) -> f64 {
    let log_min = CLOSED_INTERVAL_MIN.ln();
    let log_max = CLOSED_INTERVAL_MAX.ln();
    let rank = (local * 251 + 17) % 512;
    let target = log_min + ((rank as f64 + 0.5) / 512.0) * (log_max - log_min);
    let midpoint = Fp16Bits::from_f64(target)
        .midpoint_to_next_positive()
        .expect("selected ln half bin must have a finite successor");
    midpoint.exp()
}
