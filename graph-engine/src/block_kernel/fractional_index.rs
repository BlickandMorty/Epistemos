use std::cmp::Ordering;

/// Fractional sibling ordering using base-256 digits plus peer/discriminator tie-breakers.
/// This keeps inserts and moves stable without renumbering every sibling.
#[derive(Clone, Debug, Eq, PartialEq, Hash)]
pub struct FractionalIndex {
    digits: Vec<u8>,
    peer_id: u32,
    discriminator: u32,
}

impl FractionalIndex {
    /// Build a stable ordering key from a concrete sibling position.
    pub fn from_position(position: u32) -> Self {
        Self {
            digits: position.to_be_bytes().to_vec(),
            peer_id: 0,
            discriminator: 0,
        }
    }

    /// Generate an index strictly between `left` and `right`.
    ///
    /// If the neighbors collide or are inverted, the new value is placed after `left`.
    pub fn between(
        left: Option<&Self>,
        right: Option<&Self>,
        peer_id: u32,
        discriminator: u32,
    ) -> Self {
        if let (Some(left), Some(right)) = (left, right) {
            if left >= right {
                return Self::after(left, peer_id, discriminator);
            }
        }

        let left_digits = left.map_or(&[][..], |index| index.digits.as_slice());
        let right_digits = right.map_or(&[][..], |index| index.digits.as_slice());
        let mut digits = Vec::with_capacity(left_digits.len().max(right_digits.len()) + 1);
        let mut pos = 0usize;

        loop {
            let left_digit = left_digits.get(pos).copied().unwrap_or(0);
            let right_digit = right_digits.get(pos).copied().unwrap_or(u8::MAX);

            if right_digit > left_digit.saturating_add(1) {
                digits.push(left_digit + ((right_digit - left_digit) / 2));
                break;
            }

            digits.push(left_digit);
            pos += 1;
        }

        Self {
            digits,
            peer_id,
            discriminator,
        }
    }

    /// Return a lexical sort key that can be stored in query rows and snapshots.
    pub fn as_sort_key(&self) -> String {
        let mut key = String::with_capacity((self.digits.len() * 2) + 18);
        for byte in &self.digits {
            use std::fmt::Write;
            let _ = write!(&mut key, "{byte:02x}");
        }
        use std::fmt::Write;
        let _ = write!(&mut key, "-{:08x}-{:08x}", self.peer_id, self.discriminator);
        key
    }

    /// Parse a lexical sort key previously produced by `as_sort_key`.
    pub fn from_sort_key(key: &str) -> Option<Self> {
        let mut parts = key.splitn(3, '-');
        let digits_hex = parts.next()?;
        let peer_hex = parts.next()?;
        let discriminator_hex = parts.next()?;

        if digits_hex.len() % 2 != 0 {
            return None;
        }

        let mut digits = Vec::with_capacity(digits_hex.len() / 2);
        let mut cursor = 0usize;
        while cursor < digits_hex.len() {
            let next = cursor + 2;
            let byte = u8::from_str_radix(&digits_hex[cursor..next], 16).ok()?;
            digits.push(byte);
            cursor = next;
        }

        Some(Self {
            digits,
            peer_id: u32::from_str_radix(peer_hex, 16).ok()?,
            discriminator: u32::from_str_radix(discriminator_hex, 16).ok()?,
        })
    }

    fn after(left: &Self, peer_id: u32, discriminator: u32) -> Self {
        let mut digits = left.digits.clone();
        digits.push(128);
        Self {
            digits,
            peer_id,
            discriminator,
        }
    }
}

impl Ord for FractionalIndex {
    fn cmp(&self, other: &Self) -> Ordering {
        self.digits
            .cmp(&other.digits)
            .then(self.peer_id.cmp(&other.peer_id))
            .then(self.discriminator.cmp(&other.discriminator))
    }
}

impl PartialOrd for FractionalIndex {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

#[cfg(test)]
mod tests {
    use super::FractionalIndex;

    #[test]
    fn between_orders_between_neighbors() {
        let left = FractionalIndex::from_position(1);
        let right = FractionalIndex::from_position(2);
        let middle = FractionalIndex::between(Some(&left), Some(&right), 7, 1);

        assert!(left < middle);
        assert!(middle < right);
    }

    #[test]
    fn collision_uses_peer_and_discriminator_tie_breakers() {
        let left = FractionalIndex::from_position(5);
        let right = FractionalIndex::from_position(6);

        let a = FractionalIndex::between(Some(&left), Some(&right), 1, 1);
        let b = FractionalIndex::between(Some(&left), Some(&right), 2, 1);
        let c = FractionalIndex::between(Some(&left), Some(&right), 2, 2);

        assert_ne!(a, b);
        assert_ne!(b, c);
        assert!(a < b);
        assert!(b < c);
    }

    #[test]
    fn repeated_insertions_reset_by_extending_digits() {
        let left = FractionalIndex::from_position(10);
        let mut current = FractionalIndex::between(Some(&left), None, 1, 1);

        for discriminator in 2..8 {
            let next = FractionalIndex::between(Some(&current), None, 1, discriminator);
            assert!(current < next);
            current = next;
        }
    }

    #[test]
    fn alternating_gap_inserts_remain_strictly_sorted() {
        let mut indices = vec![
            FractionalIndex::from_position(1),
            FractionalIndex::from_position(2),
        ];

        for discriminator in 1..33 {
            let insert_at = if discriminator % 2 == 0 {
                1
            } else {
                indices.len() - 1
            };
            let next = FractionalIndex::between(
                indices.get(insert_at.wrapping_sub(1)),
                indices.get(insert_at),
                7,
                discriminator,
            );
            indices.insert(insert_at, next);
            assert!(indices.windows(2).all(|window| window[0] < window[1]));
        }
    }

    #[test]
    fn inverted_neighbors_fall_back_after_left() {
        let left = FractionalIndex::from_position(9);
        let right = FractionalIndex::from_position(8);
        let next = FractionalIndex::between(Some(&left), Some(&right), 3, 1);

        assert!(next > left);
    }

    #[test]
    fn sort_key_roundtrips() {
        let index = FractionalIndex::between(
            Some(&FractionalIndex::from_position(1)),
            Some(&FractionalIndex::from_position(2)),
            7,
            42,
        );

        let roundtrip =
            FractionalIndex::from_sort_key(&index.as_sort_key()).expect("sort key should parse");
        assert_eq!(roundtrip, index);
    }
}
