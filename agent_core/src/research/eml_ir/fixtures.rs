use super::Fp16Bits;
use serde::{Deserialize, Serialize};

pub const CLOSED_INTERVAL_MIN: f64 = 0.5;
pub const CLOSED_INTERVAL_MAX: f64 = 2.0;
pub const LOG_SAMPLED_POINT_COUNT: usize = 412_000;
pub const STRESS_POINT_COUNT: usize = 2_048;
pub const TOTAL_FIXTURE_COUNT: usize = LOG_SAMPLED_POINT_COUNT + STRESS_POINT_COUNT;
pub const ADVERSARIAL_FIXTURE_COUNT: usize = 15;

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum FixtureKind {
    LogSampled,
    Stress,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum StressAxis {
    LogSampled,
    ClosedIntervalEdge,
    ExpOutputMidpoint,
    LnOutputMidpoint,
    EmlCrossMidpoint,
}

impl StressAxis {
    pub const ALL: [Self; 5] = [
        Self::LogSampled,
        Self::ClosedIntervalEdge,
        Self::ExpOutputMidpoint,
        Self::LnOutputMidpoint,
        Self::EmlCrossMidpoint,
    ];

    pub const fn index(self) -> usize {
        match self {
            Self::LogSampled => 0,
            Self::ClosedIntervalEdge => 1,
            Self::ExpOutputMidpoint => 2,
            Self::LnOutputMidpoint => 3,
            Self::EmlCrossMidpoint => 4,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct FixtureInput {
    pub index: usize,
    pub kind: FixtureKind,
    pub axis: StressAxis,
    pub x: f64,
    pub y: f64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum AdversarialOperation {
    Exp,
    Ln,
    Eml,
}

impl AdversarialOperation {
    pub const fn as_u8(self) -> u8 {
        match self {
            Self::Exp => 0,
            Self::Ln => 1,
            Self::Eml => 2,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct AdversarialFixture {
    pub index: usize,
    pub label: &'static str,
    pub operation: AdversarialOperation,
    pub x: f64,
    pub y: f64,
}

impl AdversarialFixture {
    pub const fn to_fixture_input(self) -> FixtureInput {
        FixtureInput {
            index: self.index,
            kind: FixtureKind::Stress,
            axis: StressAxis::ClosedIntervalEdge,
            x: self.x,
            y: self.y,
        }
    }
}

pub fn fixture_input(index: usize) -> FixtureInput {
    assert!(index < TOTAL_FIXTURE_COUNT);
    if index < LOG_SAMPLED_POINT_COUNT {
        log_sampled_input(index)
    } else {
        stress_input(index - LOG_SAMPLED_POINT_COUNT)
    }
}

pub fn adversarial_fixture(index: usize) -> AdversarialFixture {
    assert!(index < ADVERSARIAL_FIXTURE_COUNT);
    match index {
        0 => adversarial(
            index,
            "exp_positive_zero",
            AdversarialOperation::Exp,
            0.0,
            1.0,
        ),
        1 => adversarial(
            index,
            "exp_negative_zero",
            AdversarialOperation::Exp,
            -0.0,
            1.0,
        ),
        2 => adversarial(
            index,
            "ln_positive_zero",
            AdversarialOperation::Ln,
            1.0,
            0.0,
        ),
        3 => adversarial(
            index,
            "ln_negative_zero",
            AdversarialOperation::Ln,
            1.0,
            -0.0,
        ),
        4 => adversarial(
            index,
            "ln_f64_min_positive_subnormal",
            AdversarialOperation::Ln,
            1.0,
            f64::from_bits(1),
        ),
        5 => adversarial(
            index,
            "ln_fp16_min_positive_subnormal",
            AdversarialOperation::Ln,
            1.0,
            Fp16Bits::from_bits(0x0001).to_f64(),
        ),
        6 => adversarial(index, "nan_x", AdversarialOperation::Exp, f64::NAN, 1.0),
        7 => adversarial(index, "nan_y", AdversarialOperation::Ln, 1.0, f64::NAN),
        8 => adversarial(
            index,
            "positive_infinity_y",
            AdversarialOperation::Ln,
            1.0,
            f64::INFINITY,
        ),
        9 => adversarial(
            index,
            "negative_infinity_x",
            AdversarialOperation::Exp,
            f64::NEG_INFINITY,
            1.0,
        ),
        10 => adversarial(
            index,
            "ln_fp16_max_positive_subnormal",
            AdversarialOperation::Ln,
            1.0,
            Fp16Bits::from_bits(0x03ff).to_f64(),
        ),
        11 => adversarial(
            index,
            "ln_fp16_min_positive_normal",
            AdversarialOperation::Ln,
            1.0,
            Fp16Bits::from_bits(0x0400).to_f64(),
        ),
        12 => adversarial(
            index,
            "eml_fp16_max_positive_subnormal",
            AdversarialOperation::Eml,
            0.0,
            Fp16Bits::from_bits(0x03ff).to_f64(),
        ),
        13 => adversarial(
            index,
            "eml_fp16_min_positive_normal",
            AdversarialOperation::Eml,
            0.0,
            Fp16Bits::from_bits(0x0400).to_f64(),
        ),
        _ => adversarial(
            index,
            "eml_ln_negative_zero",
            AdversarialOperation::Eml,
            1.0,
            -0.0,
        ),
    }
}

fn adversarial(
    index: usize,
    label: &'static str,
    operation: AdversarialOperation,
    x: f64,
    y: f64,
) -> AdversarialFixture {
    AdversarialFixture {
        index,
        label,
        operation,
        x,
        y,
    }
}

pub fn log_sampled_input(index: usize) -> FixtureInput {
    assert!(index < LOG_SAMPLED_POINT_COUNT);
    let (x_rank, y_rank) = log_sampled_rank_pair(index);
    let last = LOG_SAMPLED_POINT_COUNT - 1;
    let log_min = CLOSED_INTERVAL_MIN.ln();
    let span = CLOSED_INTERVAL_MAX.ln() - log_min;
    FixtureInput {
        index,
        kind: FixtureKind::LogSampled,
        axis: StressAxis::LogSampled,
        x: log_sampled_value(x_rank, last, log_min, span),
        y: log_sampled_value(y_rank, last, log_min, span),
    }
}

fn log_sampled_rank_pair(index: usize) -> (usize, usize) {
    assert!(index < LOG_SAMPLED_POINT_COUNT);
    (index, (index * 131_071) % LOG_SAMPLED_POINT_COUNT)
}

fn log_sampled_value(rank: usize, last: usize, log_min: f64, span: f64) -> f64 {
    assert!(rank <= last);
    if rank == 0 {
        CLOSED_INTERVAL_MIN
    } else if rank == last {
        CLOSED_INTERVAL_MAX
    } else {
        let t = rank as f64 / last as f64;
        (log_min + t * span).exp()
    }
}

pub fn stress_input(index: usize) -> FixtureInput {
    assert!(index < STRESS_POINT_COUNT);
    let local = index / 4;
    let global = LOG_SAMPLED_POINT_COUNT + index;
    match index % 4 {
        0 => edge_fixture(global, local),
        1 => exp_midpoint_fixture(global, local),
        2 => ln_midpoint_fixture(global, local),
        _ => eml_cross_fixture(global, local),
    }
}

fn edge_fixture(index: usize, local: usize) -> FixtureInput {
    const ANCHORS: [u16; 8] = [
        0x3800, 0x3801, 0x3bff, 0x3c00, 0x3c01, 0x3fff, 0x4000, 0x3c00,
    ];
    point(
        index,
        StressAxis::ClosedIntervalEdge,
        Fp16Bits::from_bits(ANCHORS[local % ANCHORS.len()]).to_f64(),
        Fp16Bits::from_bits(ANCHORS[(local * 5 + 3) % ANCHORS.len()]).to_f64(),
    )
}

fn exp_midpoint_fixture(index: usize, local: usize) -> FixtureInput {
    point(
        index,
        StressAxis::ExpOutputMidpoint,
        exp_midpoint_x(local),
        edge_y(local * 7 + 1),
    )
}

fn ln_midpoint_fixture(index: usize, local: usize) -> FixtureInput {
    point(
        index,
        StressAxis::LnOutputMidpoint,
        edge_y(local * 11 + 2),
        ln_midpoint_y(local),
    )
}

fn eml_cross_fixture(index: usize, local: usize) -> FixtureInput {
    point(
        index,
        StressAxis::EmlCrossMidpoint,
        exp_midpoint_x(local * 17 + 5),
        ln_midpoint_y(local * 19 + 7),
    )
}

fn point(index: usize, axis: StressAxis, x: f64, y: f64) -> FixtureInput {
    debug_assert!((CLOSED_INTERVAL_MIN..=CLOSED_INTERVAL_MAX).contains(&x));
    debug_assert!((CLOSED_INTERVAL_MIN..=CLOSED_INTERVAL_MAX).contains(&y));
    FixtureInput {
        index,
        kind: FixtureKind::Stress,
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
    Fp16Bits::from_bits(bits)
        .midpoint_to_next_positive()
        .expect("finite exp output midpoint")
        .ln()
}

fn ln_midpoint_y(local: usize) -> f64 {
    let log_min = CLOSED_INTERVAL_MIN.ln();
    let log_max = CLOSED_INTERVAL_MAX.ln();
    let rank = (local * 251 + 17) % 512;
    let target = log_min + ((rank as f64 + 0.5) / 512.0) * (log_max - log_min);
    Fp16Bits::from_f64(target)
        .midpoint_to_next_positive()
        .expect("finite ln output midpoint")
        .exp()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn log_sampled_input_locks_closed_interval_edges() {
        let first = log_sampled_input(0);
        let last = log_sampled_input(LOG_SAMPLED_POINT_COUNT - 1);
        assert_eq!(first.x, CLOSED_INTERVAL_MIN);
        assert_eq!(last.x, CLOSED_INTERVAL_MAX);
        assert!(first.y >= CLOSED_INTERVAL_MIN && first.y <= CLOSED_INTERVAL_MAX);
        assert!(last.y >= CLOSED_INTERVAL_MIN && last.y <= CLOSED_INTERVAL_MAX);
    }

    #[test]
    fn fixture_counts_match_twelve_acceptance_bar() {
        assert_eq!(LOG_SAMPLED_POINT_COUNT, 412_000);
        assert_eq!(STRESS_POINT_COUNT, 2_048);
        assert_eq!(TOTAL_FIXTURE_COUNT, 414_048);
    }

    #[test]
    fn log_sampled_y_rank_is_full_permutation() {
        let mut seen = vec![false; LOG_SAMPLED_POINT_COUNT];
        for index in 0..LOG_SAMPLED_POINT_COUNT {
            let (x_rank, y_rank) = log_sampled_rank_pair(index);
            assert_eq!(x_rank, index);
            assert!(!seen[y_rank], "duplicate y rank {y_rank}");
            seen[y_rank] = true;
        }
        assert!(seen.into_iter().all(|rank_seen| rank_seen));
    }

    #[test]
    fn stress_inputs_cover_four_adversarial_axes() {
        let mut counts = [0usize; 4];
        for i in 0..STRESS_POINT_COUNT {
            let point = stress_input(i);
            assert!(point.x >= CLOSED_INTERVAL_MIN && point.x <= CLOSED_INTERVAL_MAX);
            assert!(point.y >= CLOSED_INTERVAL_MIN && point.y <= CLOSED_INTERVAL_MAX);
            match point.axis {
                StressAxis::ClosedIntervalEdge => counts[0] += 1,
                StressAxis::ExpOutputMidpoint => counts[1] += 1,
                StressAxis::LnOutputMidpoint => counts[2] += 1,
                StressAxis::EmlCrossMidpoint => counts[3] += 1,
                StressAxis::LogSampled => panic!("stress input used log-sampled axis"),
            }
        }
        assert_eq!(counts, [512, 512, 512, 512]);
    }

    #[test]
    fn adversarial_fixtures_cover_zero_nan_infinity_and_subnormals() {
        let mut coverage = [false; 9];
        for index in 0..ADVERSARIAL_FIXTURE_COUNT {
            let fixture = adversarial_fixture(index);
            coverage[0] |= fixture.x == 0.0 && fixture.x.is_sign_positive();
            coverage[1] |= fixture.x == -0.0 && fixture.x.is_sign_negative();
            coverage[2] |= fixture.y == 0.0 && fixture.y.is_sign_positive();
            coverage[3] |= fixture.y == -0.0 && fixture.y.is_sign_negative();
            coverage[4] |= fixture.x.is_nan();
            coverage[5] |= fixture.y.is_nan();
            coverage[6] |= fixture.x.is_infinite();
            coverage[7] |= fixture.y.is_infinite();
            coverage[8] |=
                fixture.y.is_subnormal() || Fp16Bits::from_f64(fixture.y).bits() == 0x0001;
        }
        assert!(coverage.into_iter().all(|covered| covered), "{coverage:?}");
    }

    #[test]
    fn adversarial_fixtures_pin_operation_intent() {
        assert_eq!(adversarial_fixture(0).operation, AdversarialOperation::Exp);
        assert_eq!(adversarial_fixture(3).operation, AdversarialOperation::Ln);
        assert_eq!(adversarial_fixture(5).operation, AdversarialOperation::Ln);
        assert_eq!(adversarial_fixture(9).operation, AdversarialOperation::Exp);
        assert_eq!(adversarial_fixture(14).operation, AdversarialOperation::Eml);
    }

    #[test]
    fn adversarial_fixtures_cover_fp16_denormal_normal_boundary() {
        let max_subnormal = adversarial_fixture(10);
        assert_eq!(max_subnormal.label, "ln_fp16_max_positive_subnormal");
        assert_eq!(max_subnormal.operation, AdversarialOperation::Ln);
        assert_eq!(max_subnormal.y, Fp16Bits::from_bits(0x03ff).to_f64());

        let min_normal = adversarial_fixture(11);
        assert_eq!(min_normal.label, "ln_fp16_min_positive_normal");
        assert_eq!(min_normal.operation, AdversarialOperation::Ln);
        assert_eq!(min_normal.y, Fp16Bits::from_bits(0x0400).to_f64());
    }

    #[test]
    fn adversarial_fixtures_cover_eml_fp16_denormal_normal_boundary() {
        let max_subnormal = adversarial_fixture(12);
        assert_eq!(max_subnormal.label, "eml_fp16_max_positive_subnormal");
        assert_eq!(max_subnormal.operation, AdversarialOperation::Eml);
        assert_eq!(max_subnormal.x, 0.0);
        assert_eq!(max_subnormal.y, Fp16Bits::from_bits(0x03ff).to_f64());

        let min_normal = adversarial_fixture(13);
        assert_eq!(min_normal.label, "eml_fp16_min_positive_normal");
        assert_eq!(min_normal.operation, AdversarialOperation::Eml);
        assert_eq!(min_normal.x, 0.0);
        assert_eq!(min_normal.y, Fp16Bits::from_bits(0x0400).to_f64());
    }

    #[test]
    fn adversarial_fixtures_cover_all_operations() {
        let mut coverage = [false; 3];
        for index in 0..ADVERSARIAL_FIXTURE_COUNT {
            coverage[adversarial_fixture(index).operation.as_u8() as usize] = true;
        }
        assert!(coverage.into_iter().all(|covered| covered), "{coverage:?}");
    }

    #[test]
    fn adversarial_operation_stays_fixture_local() {
        let source = include_str!("fixtures.rs");
        assert!(!source.contains(concat!("Fulp", "Operation")));
    }
}
