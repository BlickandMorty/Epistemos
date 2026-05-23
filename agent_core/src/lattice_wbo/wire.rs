//! Shared serde infrastructure for the `lattice_wbo` register.
//!
//! `ExplicitPublicOption` and its deserializer hook let the public wire format
//! distinguish a missing key from an explicit `null`, so accounting fields stay
//! mandatory even when their value is "no rate" or "no measurement."

use serde::{de, Deserialize, Deserializer};

pub(super) enum ExplicitPublicOption<T> {
    Missing,
    Present(Option<T>),
}

impl<T> Default for ExplicitPublicOption<T> {
    fn default() -> Self {
        Self::Missing
    }
}

impl<T> ExplicitPublicOption<T> {
    pub(super) fn require<E>(self, field: &'static str) -> Result<Option<T>, E>
    where
        E: de::Error,
    {
        match self {
            Self::Missing => Err(E::missing_field(field)),
            Self::Present(value) => Ok(value),
        }
    }
}

pub(super) fn deserialize_explicit_public_option<'de, D, T>(
    deserializer: D,
) -> Result<ExplicitPublicOption<T>, D::Error>
where
    D: Deserializer<'de>,
    T: Deserialize<'de>,
{
    Option::<T>::deserialize(deserializer).map(ExplicitPublicOption::Present)
}
