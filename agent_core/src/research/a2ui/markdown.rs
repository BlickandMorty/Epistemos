//! Wave I Markdown component.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct MarkdownProps {
    pub body: String,
    pub allow_raw_html: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum MarkdownError {
    EmptyBody,
    RawHtmlPresentWithoutFlag,
}

impl MarkdownProps {
    pub fn validate(&self) -> Result<(), MarkdownError> {
        if self.body.is_empty() {
            return Err(MarkdownError::EmptyBody);
        }
        if !self.allow_raw_html && (self.body.contains("<script") || self.body.contains("<iframe")) {
            return Err(MarkdownError::RawHtmlPresentWithoutFlag);
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_body_rejected() {
        let m = MarkdownProps { body: String::new(), allow_raw_html: false };
        assert_eq!(m.validate().unwrap_err(), MarkdownError::EmptyBody);
    }

    #[test]
    fn plain_markdown_validates() {
        let m = MarkdownProps { body: "# hello".into(), allow_raw_html: false };
        assert!(m.validate().is_ok());
    }

    #[test]
    fn script_tag_without_flag_rejected() {
        let m = MarkdownProps { body: "<script>alert(1)</script>".into(), allow_raw_html: false };
        assert_eq!(m.validate().unwrap_err(), MarkdownError::RawHtmlPresentWithoutFlag);
    }

    #[test]
    fn script_tag_with_flag_passes() {
        let m = MarkdownProps { body: "<script>alert(1)</script>".into(), allow_raw_html: true };
        assert!(m.validate().is_ok());
    }

    #[test]
    fn serde_json_roundtrip() {
        let m = MarkdownProps { body: "x".into(), allow_raw_html: true };
        let json = serde_json::to_string(&m).unwrap();
        let back: MarkdownProps = serde_json::from_str(&json).unwrap();
        assert_eq!(m, back);
    }
}
