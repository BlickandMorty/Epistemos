//! SDF label instance building (Rust-side).
//!
//! Holds the per-character glyph metrics pushed from Swift once at atlas
//! load time, then rebuilds the `LabelInstance` array each frame from the
//! engine's visible-node state. This keeps the label render pipeline in
//! the zero-copy / direct-Metal path: Swift pushes glyph table once,
//! Rust owns the per-frame rebuild. Per CODEX_PROMPT_CHAIN.md §B-3 +
//! Tier 1 "Deep Engineering Report" Parts II/III.
//!
//! Architecture:
//!   Swift parses `sdf_labels.json` once at startup → calls
//!   `graph_engine_set_label_glyph_table` with a flat array of
//!   `CGlyphMetric`s → Rust stores them in a `GlyphTable`. Every frame
//!   inside `graph_engine_render()`, the engine iterates visible nodes,
//!   looks up each character's metrics, and writes the `LabelInstance`
//!   buffer. No per-frame FFI required.

use rustc_hash::FxHashMap;

/// C-ABI glyph metric. One per character, pushed once from Swift after the
/// JSON metrics file has been parsed. 40 bytes, `#[repr(C)]` for ABI
/// stability. Field layout is documented in graph_engine.h
/// (`GraphEngineGlyphMetric`).
#[repr(C)]
#[derive(Clone, Copy)]
pub struct CGlyphMetric {
    pub codepoint: u32,    // Unicode code point (e.g. 65 for 'A')
    pub uv_x: f32,         // atlas UV x (normalized [0,1])
    pub uv_y: f32,         // atlas UV y (normalized [0,1])
    pub uv_w: f32,         // atlas UV width
    pub uv_h: f32,         // atlas UV height
    pub half_w_em: f32,    // half-width in em units
    pub half_h_em: f32,    // half-height in em units
    pub bearing_x_em: f32, // glyph center x-bearing in em
    pub bearing_y_em: f32, // glyph center y-bearing in em
    pub advance_em: f32,   // horizontal advance in em
}

/// Internal, hash-friendly representation. Keyed by Unicode code point
/// (u32) so we don't have to pay for `char` conversion on every glyph.
#[derive(Clone, Copy)]
struct GlyphMetric {
    uv_rect: [f32; 4],
    half_w_em: f32,
    half_h_em: f32,
    bearing_x_em: f32,
    bearing_y_em: f32,
    advance_em: f32,
}

pub struct GlyphTable {
    glyphs: FxHashMap<u32, GlyphMetric>,
    fallback: Option<GlyphMetric>,
    /// Line height in em units, from atlas JSON `metrics.lineHeight`.
    pub line_height_em: f32,
    /// Pixel range from atlas gen. Exposed for the LabelUniforms buffer.
    pub px_range: f32,
}

impl GlyphTable {
    pub fn from_c_metrics(metrics: &[CGlyphMetric], line_height_em: f32, px_range: f32) -> Self {
        let mut glyphs = FxHashMap::default();
        glyphs.reserve(metrics.len());
        let mut fallback: Option<GlyphMetric> = None;
        for m in metrics {
            let gm = GlyphMetric {
                uv_rect: [m.uv_x, m.uv_y, m.uv_w, m.uv_h],
                half_w_em: m.half_w_em,
                half_h_em: m.half_h_em,
                bearing_x_em: m.bearing_x_em,
                bearing_y_em: m.bearing_y_em,
                advance_em: m.advance_em,
            };
            glyphs.insert(m.codepoint, gm);
            if fallback.is_none() && m.codepoint == b'?' as u32 {
                fallback = Some(gm);
            }
        }
        GlyphTable {
            glyphs,
            fallback,
            line_height_em,
            px_range,
        }
    }

    fn lookup(&self, codepoint: u32) -> Option<&GlyphMetric> {
        self.glyphs.get(&codepoint).or(self.fallback.as_ref())
    }
}

/// Build a per-glyph `LabelInstance` array from the engine's visible-node
/// state. Clips labels to a character budget (keeps the graph readable at
/// low zoom) and caps per-label characters to 32.
///
/// `visible_nodes` is a slice of (world_x, world_y, radius, label, opacity,
/// world_px_per_em) tuples produced by the engine's visibility pass. `opacity`
/// is multiplied into the base color's alpha so labels can fade in/out smoothly
/// as they enter or leave the visible set (2026-04-04 polish).
///
/// The final tuple field maps em-space glyph sizes to world-space render sizes.
/// It is calculated per node by the engine's hybrid zoom policy so selected or
/// hovered labels can stay more readable without creating a separate text path.
pub(crate) fn build_instances(
    visible_nodes: &[(f32, f32, f32, &str, f32, f32)],
    table: &GlyphTable,
    camera_world: [f32; 2],
    color: [f32; 4],
    glyph_budget: usize,
    out: &mut Vec<crate::renderer::LabelInstance>,
) {
    out.clear();
    out.reserve(glyph_budget);

    const MAX_LABEL_CHARS: usize = 32;
    let line_height_em = table.line_height_em;

    for &(node_x, node_y, node_radius, label, opacity, world_px_per_em) in visible_nodes {
        if out.len() >= glyph_budget {
            break;
        }
        let trimmed: &str = if label.chars().count() > MAX_LABEL_CHARS {
            // Safe truncation at grapheme boundary.
            let cutoff = label
                .char_indices()
                .nth(MAX_LABEL_CHARS)
                .map(|(i, _)| i)
                .unwrap_or(label.len());
            &label[..cutoff]
        } else {
            label
        };
        if trimmed.is_empty() {
            continue;
        }

        // Pre-pass: total advance in em so we can center the label.
        let mut total_advance_em = 0.0_f32;
        for c in trimmed.chars() {
            let cp = c as u32;
            if let Some(g) = table.lookup(cp) {
                total_advance_em += g.advance_em;
            }
        }
        if total_advance_em <= 0.0 {
            continue;
        }

        // Per-node fade opacity — already smoothstep-shaped by the caller.
        // Skip entirely if fully invisible to save glyph budget.
        let node_opacity = opacity.clamp(0.0, 1.0);
        if node_opacity < 0.01 {
            continue;
        }
        let faded_color = [color[0], color[1], color[2], color[3] * node_opacity];

        let label_half_w_world = total_advance_em * world_px_per_em * 0.5;
        // Labels sit just below the node. Tier 1 §A3 puts them above, but
        // below-node matches the existing glow/node styling better.
        let y_offset_world = -(node_radius + world_px_per_em * line_height_em * 0.6);
        let mut pen_x_world = node_x - label_half_w_world;
        let baseline_y = node_y + y_offset_world;
        let dx = node_x - camera_world[0];
        let dy = node_y - camera_world[1];
        let node_dist = (dx * dx + dy * dy).sqrt();

        for c in trimmed.chars() {
            if out.len() >= glyph_budget {
                break;
            }
            let cp = c as u32;
            let Some(g) = table.lookup(cp) else { continue };
            if g.half_w_em == 0.0 || g.half_h_em == 0.0 {
                // Whitespace — advance only.
                pen_x_world += g.advance_em * world_px_per_em;
                continue;
            }
            let center_x = pen_x_world + g.bearing_x_em * world_px_per_em;
            let center_y = baseline_y + g.bearing_y_em * world_px_per_em;
            out.push(crate::renderer::LabelInstance {
                position: [center_x, center_y],
                size: [g.half_w_em * world_px_per_em, g.half_h_em * world_px_per_em],
                uv_rect: g.uv_rect,
                color: faded_color,
                node_dist,
                _pad: [0.0; 3],
            });
            pen_x_world += g.advance_em * world_px_per_em;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_table() -> GlyphTable {
        let metrics = vec![
            CGlyphMetric {
                codepoint: b'A' as u32,
                uv_x: 0.1,
                uv_y: 0.1,
                uv_w: 0.05,
                uv_h: 0.05,
                half_w_em: 0.3,
                half_h_em: 0.35,
                bearing_x_em: 0.3,
                bearing_y_em: 0.35,
                advance_em: 0.6,
            },
            CGlyphMetric {
                codepoint: b' ' as u32,
                uv_x: 0.0,
                uv_y: 0.0,
                uv_w: 0.0,
                uv_h: 0.0,
                half_w_em: 0.0,
                half_h_em: 0.0,
                bearing_x_em: 0.0,
                bearing_y_em: 0.0,
                advance_em: 0.25,
            },
            CGlyphMetric {
                codepoint: b'?' as u32,
                uv_x: 0.2,
                uv_y: 0.2,
                uv_w: 0.05,
                uv_h: 0.05,
                half_w_em: 0.28,
                half_h_em: 0.35,
                bearing_x_em: 0.28,
                bearing_y_em: 0.35,
                advance_em: 0.55,
            },
        ];
        GlyphTable::from_c_metrics(&metrics, 1.2, 6.0)
    }

    #[test]
    fn emits_one_instance_per_non_whitespace_glyph() {
        let table = sample_table();
        let nodes: &[(f32, f32, f32, &str, f32, f32)] = &[(0.0, 0.0, 10.0, "A A", 1.0, 20.0)];
        let mut out = Vec::new();
        build_instances(
            nodes,
            &table,
            [0.0, 0.0],
            [1.0, 1.0, 1.0, 1.0],
            256,
            &mut out,
        );
        // "A A" = 2 non-whitespace glyphs, 1 space → 2 instances.
        assert_eq!(out.len(), 2);
    }

    #[test]
    fn unknown_glyphs_fall_back_to_question() {
        let table = sample_table();
        let nodes: &[(f32, f32, f32, &str, f32, f32)] = &[(0.0, 0.0, 10.0, "Ax", 1.0, 20.0)];
        let mut out = Vec::new();
        build_instances(nodes, &table, [0.0, 0.0], [1.0; 4], 256, &mut out);
        // 'A' renders, 'x' uses '?' fallback → 2 instances.
        assert_eq!(out.len(), 2);
    }

    #[test]
    fn respects_glyph_budget() {
        let table = sample_table();
        let nodes: &[(f32, f32, f32, &str, f32, f32)] = &[
            (0.0, 0.0, 10.0, "AAAAAAAAAA", 1.0, 20.0),
            (10.0, 0.0, 10.0, "AAAAAAAAAA", 1.0, 20.0),
        ];
        let mut out = Vec::new();
        build_instances(nodes, &table, [0.0, 0.0], [1.0; 4], 7, &mut out);
        assert_eq!(out.len(), 7);
    }

    #[test]
    fn per_node_scale_controls_glyph_size_without_relayout_path() {
        let table = sample_table();
        let nodes: &[(f32, f32, f32, &str, f32, f32)] = &[
            (0.0, 0.0, 10.0, "A", 1.0, 10.0),
            (30.0, 0.0, 10.0, "A", 1.0, 30.0),
        ];
        let mut out = Vec::new();
        build_instances(nodes, &table, [0.0, 0.0], [1.0; 4], 256, &mut out);

        assert_eq!(out.len(), 2);
        assert!(out[1].size[0] > out[0].size[0] * 2.5);
    }

    #[test]
    fn truncates_long_labels_at_grapheme_boundary() {
        let table = sample_table();
        // 40-char label → truncated to 32.
        let label: String = "A".repeat(40);
        let nodes: &[(f32, f32, f32, &str, f32, f32)] = &[(0.0, 0.0, 10.0, &label, 1.0, 20.0)];
        let mut out = Vec::new();
        build_instances(nodes, &table, [0.0, 0.0], [1.0; 4], 1000, &mut out);
        assert_eq!(out.len(), 32);
    }
}
