//! Wave I Quote component.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct QuoteProps {
    pub body: String,
    pub attribution: Option<String>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum QuoteError {
    EmptyBody,
}

impl QuoteProps {
    pub fn validate(&self) -> Result<(), QuoteError> {
        if self.body.trim().is_empty() {
            return Err(QuoteError::EmptyBody);
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_body_rejected() {
        let q = QuoteProps { body: "   ".into(), attribution: None };
        assert_eq!(q.validate().unwrap_err(), QuoteError::EmptyBody);
    }

    #[test]
    fn valid_passes() {
        let q = QuoteProps {
            body: "I think therefore I am".into(),
            attribution: Some("Descartes".into()),
        };
        assert!(q.validate().is_ok());
    }

    #[test]
    fn attribution_optional() {
        let q = QuoteProps { body: "anon quote".into(), attribution: None };
        assert!(q.validate().is_ok());
    }

    #[test]
    fn empty_string_rejected() {
        let q = QuoteProps { body: String::new(), attribution: None };
        assert_eq!(q.validate().unwrap_err(), QuoteError::EmptyBody);
    }

    #[test]
    fn serde_json_roundtrip() {
        let q = QuoteProps { body: "x".into(), attribution: Some("y".into()) };
        let json = serde_json::to_string(&q).unwrap();
        let back: QuoteProps = serde_json::from_str(&json).unwrap();
        assert_eq!(q, back);
    }
}
