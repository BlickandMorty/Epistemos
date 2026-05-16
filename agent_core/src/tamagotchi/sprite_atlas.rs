//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.3 G2 — Sprite atlas + instanced Metal quads. DOCTRINE.md +
//!   5 character-DNA specs (block_compact · block_wide · sage · orb ·
//!   hermes_snake).
//! - Companion to [`super::animation`] (G1, 13 states) and the Metal
//!   shader `Epistemos/Shaders/SimulationQuads.metal`.
//!
//! # Phase B.3 G2 — Sprite atlas substrate
//!
//! A sprite atlas is a single texture holding N×M sprite cells. Each
//! cell is addressed by `(row, col)` and rendered as one instanced
//! quad. Substrate floor owns:
//!
//! - [`SpriteAtlas`] — the atlas geometry (`cell_pixels`, `cols`,
//!   `rows`, `atlas_pixels` derived).
//! - [`SpriteRect`] — UV coordinates for one cell, normalized to
//!   `[0, 1]` for the Metal shader's `attribute_texcoord`.
//! - [`InstancedQuad`] — per-quad position + sprite-cell-index +
//!   scale. The Metal shader takes a buffer of these + the atlas
//!   texture and emits triangles.
//!
//! 5 character-DNA specs are listed by [`CharacterDna::ALL`]; per-DNA
//! sprite-grid mappings (which atlas cells map to which 13 animation
//! states) are deferred to the Swift Simulation surface.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum CharacterDna {
    BlockCompact,
    BlockWide,
    Sage,
    Orb,
    HermesSnake,
}

impl CharacterDna {
    pub const ALL: [CharacterDna; 5] = [
        CharacterDna::BlockCompact,
        CharacterDna::BlockWide,
        CharacterDna::Sage,
        CharacterDna::Orb,
        CharacterDna::HermesSnake,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            CharacterDna::BlockCompact => "block_compact",
            CharacterDna::BlockWide => "block_wide",
            CharacterDna::Sage => "sage",
            CharacterDna::Orb => "orb",
            CharacterDna::HermesSnake => "hermes_snake",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct SpriteAtlas {
    pub cell_pixels: u32,
    pub cols: u32,
    pub rows: u32,
}

impl SpriteAtlas {
    pub fn atlas_pixels_width(&self) -> u32 {
        self.cell_pixels * self.cols
    }

    pub fn atlas_pixels_height(&self) -> u32 {
        self.cell_pixels * self.rows
    }

    pub fn total_cells(&self) -> u32 {
        self.cols * self.rows
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct SpriteRect {
    pub u_min: f32,
    pub v_min: f32,
    pub u_max: f32,
    pub v_max: f32,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct InstancedQuad {
    pub world_x: f32,
    pub world_y: f32,
    pub cell_row: u32,
    pub cell_col: u32,
    pub scale: f32,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum SpriteAtlasError {
    ZeroCellPixels,
    ZeroCols,
    ZeroRows,
    CellOutOfRange { row: u32, col: u32, rows: u32, cols: u32 },
    NonPositiveScale { scale: f32 },
}

impl SpriteAtlas {
    pub fn new(cell_pixels: u32, cols: u32, rows: u32) -> Result<Self, SpriteAtlasError> {
        if cell_pixels == 0 {
            return Err(SpriteAtlasError::ZeroCellPixels);
        }
        if cols == 0 {
            return Err(SpriteAtlasError::ZeroCols);
        }
        if rows == 0 {
            return Err(SpriteAtlasError::ZeroRows);
        }
        Ok(Self { cell_pixels, cols, rows })
    }

    /// Compute the UV rectangle for the cell at `(row, col)`. UVs are
    /// normalized to `[0, 1]` so the Metal shader doesn't need to
    /// know the atlas pixel dimensions at draw time.
    pub fn cell_uv_rect(&self, row: u32, col: u32) -> Result<SpriteRect, SpriteAtlasError> {
        if row >= self.rows || col >= self.cols {
            return Err(SpriteAtlasError::CellOutOfRange {
                row,
                col,
                rows: self.rows,
                cols: self.cols,
            });
        }
        let cell_w = 1.0 / (self.cols as f32);
        let cell_h = 1.0 / (self.rows as f32);
        Ok(SpriteRect {
            u_min: (col as f32) * cell_w,
            v_min: (row as f32) * cell_h,
            u_max: ((col + 1) as f32) * cell_w,
            v_max: ((row + 1) as f32) * cell_h,
        })
    }
}

impl InstancedQuad {
    pub fn new(
        world_x: f32,
        world_y: f32,
        cell_row: u32,
        cell_col: u32,
        scale: f32,
    ) -> Result<Self, SpriteAtlasError> {
        if scale <= 0.0 {
            return Err(SpriteAtlasError::NonPositiveScale { scale });
        }
        Ok(Self { world_x, world_y, cell_row, cell_col, scale })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn five_distinct_character_dnas() {
        let s: std::collections::HashSet<_> = CharacterDna::ALL.iter().copied().collect();
        assert_eq!(s.len(), 5);
    }

    #[test]
    fn character_codes_stable() {
        assert_eq!(CharacterDna::BlockCompact.code(), "block_compact");
        assert_eq!(CharacterDna::BlockWide.code(), "block_wide");
        assert_eq!(CharacterDna::Sage.code(), "sage");
        assert_eq!(CharacterDna::Orb.code(), "orb");
        assert_eq!(CharacterDna::HermesSnake.code(), "hermes_snake");
    }

    #[test]
    fn atlas_dims_multiply() {
        let a = SpriteAtlas::new(32, 8, 4).unwrap();
        assert_eq!(a.atlas_pixels_width(), 256);
        assert_eq!(a.atlas_pixels_height(), 128);
        assert_eq!(a.total_cells(), 32);
    }

    #[test]
    fn zero_cell_pixels_rejected() {
        let err = SpriteAtlas::new(0, 8, 4).unwrap_err();
        assert_eq!(err, SpriteAtlasError::ZeroCellPixels);
    }

    #[test]
    fn zero_cols_rejected() {
        let err = SpriteAtlas::new(32, 0, 4).unwrap_err();
        assert_eq!(err, SpriteAtlasError::ZeroCols);
    }

    #[test]
    fn zero_rows_rejected() {
        let err = SpriteAtlas::new(32, 8, 0).unwrap_err();
        assert_eq!(err, SpriteAtlasError::ZeroRows);
    }

    #[test]
    fn cell_uv_rect_top_left_is_origin() {
        let a = SpriteAtlas::new(32, 8, 4).unwrap();
        let r = a.cell_uv_rect(0, 0).unwrap();
        assert!((r.u_min - 0.0).abs() < 1e-6);
        assert!((r.v_min - 0.0).abs() < 1e-6);
        assert!((r.u_max - 0.125).abs() < 1e-6);
        assert!((r.v_max - 0.25).abs() < 1e-6);
    }

    #[test]
    fn cell_uv_rect_bottom_right_is_one() {
        let a = SpriteAtlas::new(32, 8, 4).unwrap();
        let r = a.cell_uv_rect(3, 7).unwrap();
        assert!((r.u_max - 1.0).abs() < 1e-6);
        assert!((r.v_max - 1.0).abs() < 1e-6);
    }

    #[test]
    fn cell_out_of_range_rejected() {
        let a = SpriteAtlas::new(32, 4, 4).unwrap();
        let err = a.cell_uv_rect(5, 0).unwrap_err();
        assert_eq!(
            err,
            SpriteAtlasError::CellOutOfRange { row: 5, col: 0, rows: 4, cols: 4 }
        );
    }

    #[test]
    fn instanced_quad_constructs_with_positive_scale() {
        let q = InstancedQuad::new(10.0, 20.0, 1, 2, 1.5).unwrap();
        assert_eq!(q.world_x, 10.0);
        assert_eq!(q.scale, 1.5);
    }

    #[test]
    fn instanced_quad_zero_scale_rejected() {
        let err = InstancedQuad::new(0.0, 0.0, 0, 0, 0.0).unwrap_err();
        assert_eq!(err, SpriteAtlasError::NonPositiveScale { scale: 0.0 });
    }

    #[test]
    fn instanced_quad_negative_scale_rejected() {
        let err = InstancedQuad::new(0.0, 0.0, 0, 0, -1.0).unwrap_err();
        assert_eq!(err, SpriteAtlasError::NonPositiveScale { scale: -1.0 });
    }

    #[test]
    fn atlas_roundtrips_through_serde_json() {
        let a = SpriteAtlas::new(32, 8, 4).unwrap();
        let json = serde_json::to_string(&a).unwrap();
        let back: SpriteAtlas = serde_json::from_str(&json).unwrap();
        assert_eq!(a, back);
    }

    #[test]
    fn quad_roundtrips_through_serde_json() {
        let q = InstancedQuad::new(1.0, 2.0, 3, 4, 5.0).unwrap();
        let json = serde_json::to_string(&q).unwrap();
        let back: InstancedQuad = serde_json::from_str(&json).unwrap();
        assert_eq!(q, back);
    }
}
