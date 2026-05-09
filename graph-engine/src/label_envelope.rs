//! Graph label envelope estimates used by physics and ECS metadata.
//!
//! The SDF renderer owns exact glyph placement, but the force simulation needs a
//! bounded world-space approximation before labels are rendered. These helpers
//! keep that estimate deterministic and cheap so labels can participate in node
//! spacing without changing the force model.

const LABEL_ENVELOPE_MAX_CHARS: usize = 32;
const LABEL_ENVELOPE_MIN_CHARS: usize = 4;
const LABEL_ENVELOPE_ADVANCE_EM: f32 = 0.74;
const LABEL_ENVELOPE_WORLD_EM: f32 = 16.0;
const LABEL_ENVELOPE_LINE_HEIGHT_EM: f32 = 1.10;
const LABEL_ENVELOPE_VERTICAL_GAP_EM: f32 = 0.62;
const LABEL_ENVELOPE_PAD_WORLD: f32 = 10.0;
const LABEL_ENVELOPE_MAX_RADIUS: f32 = 240.0;

#[derive(Clone, Copy, Debug, Default)]
pub struct LabelEnvelope {
    pub half_width: f32,
    pub half_height: f32,
    pub offset_y: f32,
    pub pad: f32,
    pub bubble_radius: f32,
}

pub fn estimate_label_envelope(node_radius: f32, label: &str) -> LabelEnvelope {
    let char_count = label.chars().take(LABEL_ENVELOPE_MAX_CHARS).count();
    if char_count < LABEL_ENVELOPE_MIN_CHARS {
        return LabelEnvelope::default();
    }

    let node_radius = node_radius.max(0.0);
    let half_width = char_count as f32 * LABEL_ENVELOPE_ADVANCE_EM * LABEL_ENVELOPE_WORLD_EM * 0.5;
    let half_height = LABEL_ENVELOPE_LINE_HEIGHT_EM * LABEL_ENVELOPE_WORLD_EM * 0.5;
    let offset_y = -(node_radius + LABEL_ENVELOPE_WORLD_EM * LABEL_ENVELOPE_VERTICAL_GAP_EM);
    let pad = LABEL_ENVELOPE_PAD_WORLD;
    let dx = half_width + pad;
    let dy = offset_y.abs() + half_height + pad;
    let bubble_radius = (dx * dx + dy * dy).sqrt().min(LABEL_ENVELOPE_MAX_RADIUS);

    LabelEnvelope {
        half_width,
        half_height,
        offset_y,
        pad,
        bubble_radius,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn wide_label_envelope_is_larger_than_node_disc() {
        let envelope = estimate_label_envelope(12.0, "CODEX_KIMI_OVERSIGHT_ROUND_033_2");

        assert!(envelope.half_width > 60.0);
        assert!(envelope.half_height > 0.0);
        assert!(envelope.offset_y < -12.0);
        assert!(envelope.bubble_radius > 70.0);
    }

    #[test]
    fn long_label_envelope_tracks_rendered_sdf_label_scale() {
        let envelope = estimate_label_envelope(12.0, "CODEX_KIMI_OVERSIGHT_ROUND_033_2");

        assert!(
            envelope.half_width >= 180.0,
            "physics label envelope must approximate the visible SDF label width; got {}",
            envelope.half_width
        );
        assert!(
            envelope.bubble_radius >= 190.0,
            "long selected-neighbor labels need a real collision bubble; got {}",
            envelope.bubble_radius
        );
    }

    #[test]
    fn label_envelope_is_bounded_for_extreme_titles() {
        let envelope = estimate_label_envelope(12.0, &"X".repeat(10_000));
        let capped_reference = estimate_label_envelope(12.0, &"X".repeat(LABEL_ENVELOPE_MAX_CHARS));

        assert_eq!(envelope.bubble_radius, capped_reference.bubble_radius);
        assert!(envelope.bubble_radius <= LABEL_ENVELOPE_MAX_RADIUS);
    }
}
