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

        if abs < 2.0_f64.powi(-25) {
            return Self(sign);
        }

        if abs < 2.0_f64.powi(-14) {
            let scaled = abs / 2.0_f64.powi(-24);
            let mantissa = round_ties_even(scaled).min(0x03ff) as u16;
            return Self(sign | mantissa);
        }

        let mut exponent = abs.log2().floor() as i32;
        let mut pow = 2.0_f64.powi(exponent);
        while pow > abs {
            exponent -= 1;
            pow = 2.0_f64.powi(exponent);
        }
        while abs >= pow * 2.0 {
            exponent += 1;
            pow = 2.0_f64.powi(exponent);
        }

        if exponent > 15 {
            return Self(sign | 0x7c00);
        }

        let significand = abs / pow;
        let mut mantissa = round_ties_even(significand * 1024.0);
        if mantissa == 2048 {
            mantissa = 1024;
            exponent += 1;
        }
        if exponent > 15 {
            return Self(sign | 0x7c00);
        }
        if exponent < -14 {
            let scaled = abs / 2.0_f64.powi(-24);
            let sub = round_ties_even(scaled).min(0x03ff) as u16;
            return Self(sign | sub);
        }

        let exponent_bits = ((exponent + 15) as u16) << 10;
        let fraction_bits = (mantissa as u16).saturating_sub(1024) & 0x03ff;
        Self(sign | exponent_bits | fraction_bits)
    }

    pub fn to_f64(self) -> f64 {
        let sign = if (self.0 & 0x8000) == 0 { 1.0 } else { -1.0 };
        let exponent = (self.0 >> 10) & 0x1f;
        let fraction = self.0 & 0x03ff;

        match exponent {
            0 => sign * (fraction as f64) * 2.0_f64.powi(-24),
            0x1f if fraction == 0 => sign * f64::INFINITY,
            0x1f => f64::NAN,
            _ => {
                let significand = 1.0 + (fraction as f64 / 1024.0);
                sign * significand * 2.0_f64.powi(exponent as i32 - 15)
            }
        }
    }

    pub fn class(self) -> Fp16Class {
        let exponent = (self.0 >> 10) & 0x1f;
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

    pub fn next_toward_positive(self) -> Option<Self> {
        if self.is_nan() || self.0 == 0x7c00 {
            return None;
        }
        if (self.0 & 0x8000) != 0 {
            if self.0 == 0x8000 {
                Some(Self(0x0001))
            } else {
                Some(Self(self.0 - 1))
            }
        } else {
            Some(Self(self.0 + 1))
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

    pub fn ulp_distance(self, other: Self) -> Option<u32> {
        if self.is_nan() || other.is_nan() {
            return None;
        }
        let a = ordered_key(self.0);
        let b = ordered_key(other.0);
        Some(a.abs_diff(b))
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
    debug_assert!(value >= 0.0);
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
    fn fulp_oracle_binary16_classifies_subnormal_zero_normal_and_inf() {
        assert_eq!(Fp16Bits::from_bits(0x0000).class(), Fp16Class::Zero);
        assert_eq!(Fp16Bits::from_bits(0x0001).class(), Fp16Class::Subnormal);
        assert_eq!(Fp16Bits::from_bits(0x3c00).class(), Fp16Class::Normal);
        assert_eq!(Fp16Bits::from_bits(0x7c00).class(), Fp16Class::Infinite);
        assert_eq!(Fp16Bits::from_bits(0x7e00).class(), Fp16Class::Nan);
    }

    #[test]
    fn fulp_oracle_binary16_ulp_distance_crosses_signed_zero() {
        let neg_zero = Fp16Bits::from_bits(0x8000);
        let pos_zero = Fp16Bits::from_bits(0x0000);
        assert_eq!(neg_zero.ulp_distance(pos_zero), Some(1));
    }

    #[test]
    fn fulp_oracle_binary16_subnormal_halfway_ties_to_even() {
        let min_subnormal = 2.0_f64.powi(-24);
        assert_eq!(Fp16Bits::from_f64(min_subnormal * 0.5).bits(), 0x0000);
        assert_eq!(Fp16Bits::from_f64(min_subnormal * 1.5).bits(), 0x0002);
        assert_eq!(Fp16Bits::from_f64(min_subnormal * 2.5).bits(), 0x0002);
    }

    #[test]
    fn fulp_oracle_binary16_nan_has_no_ulp_distance() {
        let nan = Fp16Bits::from_f64(f64::NAN);
        let one = Fp16Bits::from_f64(1.0);
        assert_eq!(nan.class(), Fp16Class::Nan);
        assert_eq!(nan.ulp_distance(one), None);
    }
}
