use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum Fp16Class {
    Zero,
    Subnormal,
    Normal,
    Infinite,
    Nan,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct Fp16Bits(u16);

impl Fp16Bits {
    pub const fn from_bits(bits: u16) -> Self {
        Self(bits)
    }

    pub const fn bits(self) -> u16 {
        self.0
    }

    pub fn from_f64(value: f64) -> Self {
        let sign = if value.is_sign_negative() { 0x8000 } else { 0 };
        if value.is_nan() {
            return Self(sign | 0x7e00);
        }
        if value.is_infinite() {
            return Self(sign | 0x7c00);
        }

        let abs = value.abs();
        if abs == 0.0 {
            return Self(sign);
        }

        const MIN_SUBNORMAL: f64 = 5.960_464_477_539_063e-8;
        const MIN_NORMAL: f64 = 0.000_061_035_156_25;
        const MAX_FINITE: f64 = 65_504.0;
        const OVERFLOW_ROUND_POINT: f64 = MAX_FINITE + 16.0;

        if abs < MIN_SUBNORMAL * 0.5 {
            return Self(sign);
        }
        if abs < MIN_NORMAL {
            let mantissa = round_ties_even(abs / MIN_SUBNORMAL) as u16;
            return Self(sign | mantissa.min(0x0400));
        }
        if abs >= OVERFLOW_ROUND_POINT {
            return Self(sign | 0x7c00);
        }

        let mut exponent = abs.log2().floor() as i32;
        let mut unit = 2.0_f64.powi(exponent);
        if unit > abs {
            exponent -= 1;
            unit = 2.0_f64.powi(exponent);
        }
        while abs >= unit * 2.0 {
            exponent += 1;
            unit *= 2.0;
        }

        let mut fraction = round_ties_even(((abs / unit) - 1.0) * 1024.0) as u16;
        if fraction == 0x0400 {
            fraction = 0;
            exponent += 1;
        }
        if exponent > 15 {
            return Self(sign | 0x7c00);
        }
        let exponent_bits = ((exponent + 15) as u16) << 10;
        Self(sign | exponent_bits | (fraction & 0x03ff))
    }

    pub fn to_f64(self) -> f64 {
        let sign = if (self.0 & 0x8000) == 0 { 1.0 } else { -1.0 };
        let exponent = (self.0 >> 10) & 0x001f;
        let fraction = self.0 & 0x03ff;
        match (exponent, fraction) {
            (0, 0) => sign * 0.0,
            (0, _) => sign * (fraction as f64) * 2.0_f64.powi(-24),
            (0x1f, 0) => sign * f64::INFINITY,
            (0x1f, _) => f64::NAN,
            _ => sign * (1.0 + fraction as f64 / 1024.0) * 2.0_f64.powi(exponent as i32 - 15),
        }
    }

    pub fn class(self) -> Fp16Class {
        let exponent = (self.0 >> 10) & 0x001f;
        let fraction = self.0 & 0x03ff;
        match (exponent, fraction) {
            (0, 0) => Fp16Class::Zero,
            (0, _) => Fp16Class::Subnormal,
            (0x1f, 0) => Fp16Class::Infinite,
            (0x1f, _) => Fp16Class::Nan,
            _ => Fp16Class::Normal,
        }
    }

    pub fn is_nan(self) -> bool {
        self.class() == Fp16Class::Nan
    }

    pub fn is_infinite(self) -> bool {
        self.class() == Fp16Class::Infinite
    }

    pub fn is_finite(self) -> bool {
        matches!(
            self.class(),
            Fp16Class::Zero | Fp16Class::Subnormal | Fp16Class::Normal
        )
    }

    pub fn ulp_distance(self, other: Self) -> Option<u32> {
        if self.is_nan() || other.is_nan() {
            return None;
        }
        Some(ordered_key(self.0).abs_diff(ordered_key(other.0)))
    }

    pub fn next_toward_positive(self) -> Option<Self> {
        if self.is_nan() || self.0 == 0x7c00 {
            return None;
        }
        if (self.0 & 0x8000) == 0 {
            Some(Self(self.0 + 1))
        } else if self.0 == 0x8000 {
            Some(Self(0x0001))
        } else {
            Some(Self(self.0 - 1))
        }
    }

    pub fn midpoint_to_next_positive(self) -> Option<f64> {
        let next = self.next_toward_positive()?;
        let a = self.to_f64();
        let b = next.to_f64();
        if a.is_finite() && b.is_finite() {
            Some((a + b) * 0.5)
        } else {
            None
        }
    }
}

fn ordered_key(bits: u16) -> u32 {
    if (bits & 0x8000) == 0 {
        bits as u32 + 0x8000
    } else {
        (!bits as u32) & 0xffff
    }
}

fn round_ties_even(value: f64) -> u64 {
    let floor = value.floor();
    let fraction = value - floor;
    let floor_u = floor as u64;
    if fraction > 0.5 {
        floor_u + 1
    } else if fraction < 0.5 || floor_u % 2 == 0 {
        floor_u
    } else {
        floor_u + 1
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn binary16_rounds_closed_interval_anchors_bit_exactly() {
        assert_eq!(Fp16Bits::from_f64(0.5).bits(), 0x3800);
        assert_eq!(Fp16Bits::from_f64(1.0).bits(), 0x3c00);
        assert_eq!(Fp16Bits::from_f64(2.0).bits(), 0x4000);
    }

    #[test]
    fn binary16_rounds_ties_to_even_at_one() {
        let midpoint = 1.0 + 2.0_f64.powi(-11);
        assert_eq!(Fp16Bits::from_f64(midpoint).bits(), 0x3c00);
    }

    #[test]
    fn binary16_ulp_distance_crosses_signed_zero() {
        let neg_zero = Fp16Bits::from_bits(0x8000);
        let pos_zero = Fp16Bits::from_bits(0x0000);
        assert_eq!(neg_zero.ulp_distance(pos_zero), Some(1));
    }

    #[test]
    fn binary16_classifies_nonfinite_and_excludes_nan_from_ulp_distance() {
        let nan = Fp16Bits::from_f64(f64::NAN);
        let inf = Fp16Bits::from_f64(f64::INFINITY);
        assert!(nan.is_nan());
        assert!(!nan.is_finite());
        assert!(inf.is_infinite());
        assert!(!inf.is_finite());
        assert_eq!(nan.ulp_distance(inf), None);
    }

    #[test]
    fn binary16_preserves_smallest_subnormal_and_signed_zero() {
        let smallest = Fp16Bits::from_f64(5.960_464_477_539_063e-8);
        let neg_zero = Fp16Bits::from_f64(-0.0);
        assert_eq!(smallest.bits(), 0x0001);
        assert_eq!(smallest.class(), Fp16Class::Subnormal);
        assert_eq!(neg_zero.bits(), 0x8000);
        assert!(neg_zero.to_f64().is_sign_negative());
    }
}
