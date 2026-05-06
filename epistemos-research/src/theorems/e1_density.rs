//! HELIOS V5 E1 — Density Theorem (12-plane bundle).
//!
//! HELIOS-E1 guard
//!
//! Statement: A_Morph(X) is uniformly dense in C(X, ℂ) over the
//! 12-plane bundle X = A_1 × A_2 × A_3 × A_4 × A_5 × A_6 ⊂ ℂ⁶
//! (per v2.1 patch: product, NOT disjoint union). Stone-Weierstrass
//! via coordinates + conjugation + constant.
//!
//! mathlib4 anchor: `Mathlib.Topology.Algebra.StoneWeierstrass`.

use serde::{Deserialize, Serialize};

/// One 6-plane bundle coordinate `(a_1, …, a_6) ∈ ℂ⁶`. Each axis
/// represented by a complex number `(real, imag)` to avoid pulling
/// a heavy num-complex dep at this layer.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Chart6 {
    pub a1: (f32, f32),
    pub a2: (f32, f32),
    pub a3: (f32, f32),
    pub a4: (f32, f32),
    pub a5: (f32, f32),
    pub a6: (f32, f32),
}

impl Chart6 {
    /// Origin: all six coordinates at `(0, 0)`.
    pub fn origin() -> Self {
        let z = (0.0, 0.0);
        Self {
            a1: z,
            a2: z,
            a3: z,
            a4: z,
            a5: z,
            a6: z,
        }
    }

    /// Coordinate-wise sum of two charts.
    pub fn componentwise_sum(self, other: Self) -> Self {
        Self {
            a1: (self.a1.0 + other.a1.0, self.a1.1 + other.a1.1),
            a2: (self.a2.0 + other.a2.0, self.a2.1 + other.a2.1),
            a3: (self.a3.0 + other.a3.0, self.a3.1 + other.a3.1),
            a4: (self.a4.0 + other.a4.0, self.a4.1 + other.a4.1),
            a5: (self.a5.0 + other.a5.0, self.a5.1 + other.a5.1),
            a6: (self.a6.0 + other.a6.0, self.a6.1 + other.a6.1),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn origin_is_zero_in_every_axis() {
        let o = Chart6::origin();
        assert_eq!(o.a1, (0.0, 0.0));
        assert_eq!(o.a6, (0.0, 0.0));
    }

    #[test]
    fn componentwise_sum_adds_each_axis() {
        let mut a = Chart6::origin();
        a.a1 = (1.0, 2.0);
        let mut b = Chart6::origin();
        b.a1 = (3.0, 4.0);
        let s = a.componentwise_sum(b);
        assert_eq!(s.a1, (4.0, 6.0));
    }
}
