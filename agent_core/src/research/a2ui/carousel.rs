//! Wave I Carousel component.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct CarouselSlide {
    pub key: String,
    pub caption: String,
    pub media_uri: String,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct CarouselProps {
    pub slides: Vec<CarouselSlide>,
    pub active_index: u32,
    pub autoplay_ms: Option<u32>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum CarouselError {
    NoSlides,
    EmptyMediaUri { index: usize },
    ActiveOutOfRange { active: u32, len: usize },
    AutoplayTooFast { ms: u32 },
}

impl CarouselProps {
    pub fn validate(&self) -> Result<(), CarouselError> {
        if self.slides.is_empty() {
            return Err(CarouselError::NoSlides);
        }
        for (i, s) in self.slides.iter().enumerate() {
            if s.media_uri.is_empty() {
                return Err(CarouselError::EmptyMediaUri { index: i });
            }
        }
        if self.active_index as usize >= self.slides.len() {
            return Err(CarouselError::ActiveOutOfRange {
                active: self.active_index,
                len: self.slides.len(),
            });
        }
        if let Some(ms) = self.autoplay_ms {
            if ms < 200 {
                return Err(CarouselError::AutoplayTooFast { ms });
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn slide(k: &str, media: &str) -> CarouselSlide {
        CarouselSlide { key: k.into(), caption: "c".into(), media_uri: media.into() }
    }

    #[test]
    fn no_slides_rejected() {
        let c = CarouselProps { slides: vec![], active_index: 0, autoplay_ms: None };
        assert_eq!(c.validate().unwrap_err(), CarouselError::NoSlides);
    }

    #[test]
    fn valid_passes() {
        let c = CarouselProps {
            slides: vec![slide("a", "vault://x")],
            active_index: 0,
            autoplay_ms: None,
        };
        assert!(c.validate().is_ok());
    }

    #[test]
    fn empty_media_uri_rejected() {
        let c = CarouselProps {
            slides: vec![slide("a", "")],
            active_index: 0,
            autoplay_ms: None,
        };
        assert!(matches!(c.validate().unwrap_err(), CarouselError::EmptyMediaUri { .. }));
    }

    #[test]
    fn active_out_of_range_rejected() {
        let c = CarouselProps {
            slides: vec![slide("a", "x")],
            active_index: 5,
            autoplay_ms: None,
        };
        assert!(matches!(c.validate().unwrap_err(), CarouselError::ActiveOutOfRange { .. }));
    }

    #[test]
    fn autoplay_too_fast_rejected() {
        let c = CarouselProps {
            slides: vec![slide("a", "x")],
            active_index: 0,
            autoplay_ms: Some(100),
        };
        assert!(matches!(c.validate().unwrap_err(), CarouselError::AutoplayTooFast { .. }));
    }

    #[test]
    fn autoplay_at_threshold_passes() {
        let c = CarouselProps {
            slides: vec![slide("a", "x")],
            active_index: 0,
            autoplay_ms: Some(200),
        };
        assert!(c.validate().is_ok());
    }

    #[test]
    fn serde_json_roundtrip() {
        let c = CarouselProps {
            slides: vec![slide("a", "x")],
            active_index: 0,
            autoplay_ms: Some(500),
        };
        let json = serde_json::to_string(&c).unwrap();
        let back: CarouselProps = serde_json::from_str(&json).unwrap();
        assert_eq!(c, back);
    }
}
