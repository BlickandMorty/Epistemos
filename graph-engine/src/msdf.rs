// ── MSDF Font Atlas ──────────────────────────────────────────────────────────
//
// Loads a pre-baked MSDF (Multi-channel Signed Distance Field) font atlas
// generated from Inter. Provides glyph metrics and per-character layout
// for GPU text rendering via instanced quads.

use serde::Deserialize;

// ── Static embeds ───────────────────────────────────────────────────────────

const ATLAS_PNG: &[u8] = include_bytes!("../assets/inter-msdf-atlas.png");
const ATLAS_JSON: &[u8] = include_bytes!("../assets/inter-msdf-atlas.json");

// ── Serde JSON structs ──────────────────────────────────────────────────────

#[derive(Deserialize)]
struct AtlasJson {
    atlas: AtlasInfo,
    glyphs: Vec<GlyphJson>,
}

#[derive(Deserialize)]
struct AtlasInfo {
    width: u32,
    height: u32,
    size: f32,
    #[serde(rename = "distanceRange")]
    distance_range: f32,
}

#[derive(Deserialize)]
struct GlyphJson {
    unicode: u32,
    advance: f32,
    #[serde(rename = "planeBounds")]
    plane_bounds: Option<BoundsJson>,
    #[serde(rename = "atlasBounds")]
    atlas_bounds: Option<BoundsJson>,
}

#[derive(Deserialize)]
struct BoundsJson {
    left: f32,
    bottom: f32,
    right: f32,
    top: f32,
}

// ── Public types ────────────────────────────────────────────────────────────

/// Metrics for a single glyph in the font atlas.
#[derive(Clone, Copy, Debug)]
pub struct GlyphMetrics {
    /// Horizontal advance in EM units.
    pub advance: f32,
    /// EM-space quad bounds (left, bottom, right, top).
    pub plane_left: f32,
    pub plane_bottom: f32,
    pub plane_right: f32,
    pub plane_top: f32,
    /// Normalized UV bounds (0..1) in the atlas texture.
    pub uv_left: f32,
    pub uv_bottom: f32,
    pub uv_right: f32,
    pub uv_top: f32,
}

/// Per-glyph instance data sent to the GPU. Must be exactly 64 bytes.
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct GlyphInstance {
    /// Node world position (label anchor).
    pub position: [f32; 2],     // offset 0
    /// Per-glyph offset from anchor in world units.
    pub glyph_offset: [f32; 2], // offset 8
    /// Quad half-extents in world units.
    pub glyph_size: [f32; 2],   // offset 16
    /// Atlas UV origin (top-left of glyph region).
    pub uv_origin: [f32; 2],    // offset 24
    /// Atlas UV dimensions (width, height).
    pub uv_size: [f32; 2],      // offset 32
    /// World-space font size.
    pub font_size: f32,         // offset 40
    /// LOD opacity (0..1).
    pub alpha: f32,             // offset 44
    /// RGBA text color.
    pub color: [f32; 4],        // offset 48
}

/// Pre-loaded MSDF font atlas with glyph metrics and decoded RGBA texture data.
pub struct FontAtlas {
    pub atlas_width: u32,
    pub atlas_height: u32,
    /// Font EM size from the atlas metadata (typically 48).
    pub em_size: f32,
    /// SDF distance range in pixels (typically 6).
    pub distance_range: f32,
    /// Decoded RGBA8 texture data (atlas_width * atlas_height * 4 bytes).
    pub rgba_data: Vec<u8>,
    /// ASCII lookup table indexed by unicode codepoint (0..127).
    pub glyphs: [Option<GlyphMetrics>; 128],
}

// ── Implementation ──────────────────────────────────────────────────────────

impl FontAtlas {
    /// Load the embedded font atlas, decode the PNG to RGBA, and parse glyph metrics.
    pub fn load() -> Self {
        // ── Parse JSON ──────────────────────────────────────────────────
        let json: AtlasJson =
            serde_json::from_slice(ATLAS_JSON).expect("failed to parse atlas JSON");

        let atlas_width = json.atlas.width;
        let atlas_height = json.atlas.height;
        let em_size = json.atlas.size;
        let distance_range = json.atlas.distance_range;

        let aw = atlas_width as f32;
        let ah = atlas_height as f32;

        // ── Decode PNG ──────────────────────────────────────────────────
        let decoder = png::Decoder::new(ATLAS_PNG);
        let mut reader = decoder.read_info().expect("failed to read PNG info");
        let mut raw_buf = vec![0u8; reader.output_buffer_size()];
        let info = reader.next_frame(&mut raw_buf).expect("failed to decode PNG frame");
        let raw_data = &raw_buf[..info.buffer_size()];

        // The atlas is RGB (3 channels). Expand to RGBA by inserting alpha=255.
        let pixel_count = (atlas_width * atlas_height) as usize;
        let mut rgba_data = Vec::with_capacity(pixel_count * 4);

        match info.color_type {
            png::ColorType::Rgb => {
                for chunk in raw_data.chunks_exact(3) {
                    rgba_data.push(chunk[0]);
                    rgba_data.push(chunk[1]);
                    rgba_data.push(chunk[2]);
                    rgba_data.push(255);
                }
            }
            png::ColorType::Rgba => {
                // Already RGBA — just copy.
                rgba_data.extend_from_slice(raw_data);
            }
            other => panic!("unexpected PNG color type: {:?}", other),
        }

        assert_eq!(
            rgba_data.len(),
            pixel_count * 4,
            "RGBA data length mismatch: expected {}, got {}",
            pixel_count * 4,
            rgba_data.len()
        );

        // ── Build glyph lookup ──────────────────────────────────────────
        let mut glyphs: [Option<GlyphMetrics>; 128] = [None; 128];

        for g in &json.glyphs {
            if g.unicode >= 128 {
                continue; // only ASCII
            }

            let (plane_left, plane_bottom, plane_right, plane_top) =
                if let Some(ref pb) = g.plane_bounds {
                    (pb.left, pb.bottom, pb.right, pb.top)
                } else {
                    (0.0, 0.0, 0.0, 0.0)
                };

            let (uv_left, uv_bottom, uv_right, uv_top) =
                if let Some(ref ab) = g.atlas_bounds {
                    (ab.left / aw, ab.bottom / ah, ab.right / aw, ab.top / ah)
                } else {
                    (0.0, 0.0, 0.0, 0.0)
                };

            glyphs[g.unicode as usize] = Some(GlyphMetrics {
                advance: g.advance,
                plane_left,
                plane_bottom,
                plane_right,
                plane_top,
                uv_left,
                uv_bottom,
                uv_right,
                uv_top,
            });
        }

        FontAtlas {
            atlas_width,
            atlas_height,
            em_size,
            distance_range,
            rgba_data,
            glyphs,
        }
    }

    /// Lay out a text string into GPU-ready glyph instances.
    ///
    /// * `text`      — the label string (truncated to 20 chars + "..." if needed)
    /// * `position`  — world-space anchor point (center-bottom of label)
    /// * `font_size` — world-space font size in the same units as node positions
    /// * `alpha`     — LOD opacity (0..1)
    /// * `color`     — RGBA text color
    pub fn layout_label(
        &self,
        text: &str,
        position: [f32; 2],
        font_size: f32,
        alpha: f32,
        color: [f32; 4],
    ) -> Vec<GlyphInstance> {
        if text.is_empty() {
            return Vec::new();
        }

        // Truncate to 20 characters; append "..." if truncated.
        let display: String = if text.chars().count() > 20 {
            let truncated: String = text.chars().take(20).collect();
            format!("{}...", truncated)
        } else {
            text.to_string()
        };

        // ── Pass 1: measure total advance width ─────────────────────────
        let mut total_advance = 0.0_f32;
        for ch in display.chars() {
            let cp = ch as u32;
            if cp < 128 {
                if let Some(ref gm) = self.glyphs[cp as usize] {
                    total_advance += gm.advance;
                }
            }
        }
        let total_width = total_advance * font_size;

        // ── Pass 2: emit GlyphInstance for each visible glyph ───────────
        let mut instances = Vec::with_capacity(display.len());
        let mut cursor_x = -total_width / 2.0;

        for ch in display.chars() {
            let cp = ch as u32;
            if cp >= 128 {
                continue;
            }

            let gm = match self.glyphs[cp as usize] {
                Some(gm) => gm,
                None => continue,
            };

            // Skip quads for space and glyphs with zero-size bounds.
            let has_bounds = (gm.plane_right - gm.plane_left).abs() > f32::EPSILON
                && (gm.plane_top - gm.plane_bottom).abs() > f32::EPSILON;

            if has_bounds {
                let quad_left = cursor_x + gm.plane_left * font_size;
                let quad_right = cursor_x + gm.plane_right * font_size;
                let quad_bottom = gm.plane_bottom * font_size;
                let quad_top = gm.plane_top * font_size;

                let half_w = (quad_right - quad_left) / 2.0;
                let half_h = (quad_top - quad_bottom) / 2.0;
                let center_x = (quad_left + quad_right) / 2.0;
                let center_y = (quad_bottom + quad_top) / 2.0;

                let uv_w = gm.uv_right - gm.uv_left;
                let uv_h = gm.uv_top - gm.uv_bottom;

                instances.push(GlyphInstance {
                    position,
                    glyph_offset: [center_x, center_y],
                    glyph_size: [half_w, half_h],
                    uv_origin: [gm.uv_left, gm.uv_bottom],
                    uv_size: [uv_w, uv_h],
                    font_size,
                    alpha,
                    color,
                });
            }

            // Advance cursor regardless (spaces advance but emit no quad).
            cursor_x += gm.advance * font_size;
        }

        instances
    }
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn atlas_loads_successfully() {
        let atlas = FontAtlas::load();
        assert_eq!(atlas.atlas_width, 1024);
        assert_eq!(atlas.atlas_height, 1024);
        assert_eq!(atlas.rgba_data.len(), 1024 * 1024 * 4);
    }

    #[test]
    fn ascii_glyphs_present() {
        let atlas = FontAtlas::load();

        // Space (32) should be present with advance > 0 but zero bounds.
        let space = atlas.glyphs[32].expect("space glyph missing");
        assert!(space.advance > 0.0, "space advance should be positive");

        // All printable ASCII (33..=126) should be present.
        for cp in 33..=126u8 {
            assert!(
                atlas.glyphs[cp as usize].is_some(),
                "missing glyph for codepoint {} ('{}')",
                cp,
                cp as char
            );
        }
    }

    #[test]
    fn layout_produces_glyphs() {
        let atlas = FontAtlas::load();
        let instances =
            atlas.layout_label("Hello", [0.0, 0.0], 1.0, 1.0, [1.0, 1.0, 1.0, 1.0]);
        assert_eq!(instances.len(), 5, "expected 5 glyph instances for 'Hello'");
    }

    #[test]
    fn layout_truncation() {
        let atlas = FontAtlas::load();
        let long_text = "A".repeat(50);
        let instances =
            atlas.layout_label(&long_text, [0.0, 0.0], 1.0, 1.0, [1.0, 1.0, 1.0, 1.0]);
        // Truncated to 20 chars + "..." = 23 visible glyphs (all are 'A' or '.').
        assert!(
            instances.len() <= 23,
            "expected at most 23 instances, got {}",
            instances.len()
        );
    }

    #[test]
    fn layout_empty_string_no_output() {
        let atlas = FontAtlas::load();
        let instances =
            atlas.layout_label("", [0.0, 0.0], 1.0, 1.0, [1.0, 1.0, 1.0, 1.0]);
        assert_eq!(instances.len(), 0);
    }

    #[test]
    fn layout_centering() {
        let atlas = FontAtlas::load();
        let instances =
            atlas.layout_label("A", [0.0, 0.0], 1.0, 1.0, [1.0, 1.0, 1.0, 1.0]);
        assert_eq!(instances.len(), 1, "expected 1 glyph for 'A'");
        // The single glyph should be roughly centered around x=0.
        let offset_x = instances[0].glyph_offset[0];
        assert!(
            offset_x.abs() < 0.5,
            "expected glyph offset near 0, got {}",
            offset_x
        );
    }

    #[test]
    fn glyph_instance_size_and_alignment() {
        assert_eq!(
            std::mem::size_of::<GlyphInstance>(),
            64,
            "GlyphInstance must be exactly 64 bytes"
        );
        assert_eq!(
            std::mem::offset_of!(GlyphInstance, color),
            48,
            "color field must be at byte offset 48"
        );
    }
}
