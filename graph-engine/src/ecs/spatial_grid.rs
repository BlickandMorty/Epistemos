//! Spatial hash grid for O(n) neighbor queries.
//!
//! Cell-based partitioning: each entity maps to a cell `(floor(x / cell_size), floor(y / cell_size))`.
//! Neighbor queries check the 9 cells around the target position (center + 8 adjacent).

use rustc_hash::FxHashMap;

use super::{HierarchyComponent, TransformComponent};

pub struct SpatialGrid {
    cell_size: f32,
    inv_cell_size: f32,
    cells: FxHashMap<(i32, i32), Vec<u32>>,
}

impl SpatialGrid {
    pub fn new(cell_size: f32) -> Self {
        debug_assert!(cell_size > 0.0, "cell_size must be positive");
        Self {
            cell_size,
            inv_cell_size: 1.0 / cell_size,
            cells: FxHashMap::default(),
        }
    }

    #[inline]
    fn cell_coords(&self, x: f32, y: f32) -> (i32, i32) {
        (
            (x * self.inv_cell_size).floor() as i32,
            (y * self.inv_cell_size).floor() as i32,
        )
    }

    /// Clear all cells, reusing allocated Vecs.
    pub fn clear(&mut self) {
        for cell in self.cells.values_mut() {
            cell.clear();
        }
    }

    /// Insert an entity at the given position. Skips non-finite coordinates.
    pub fn insert(&mut self, entity: u32, x: f32, y: f32) {
        if !x.is_finite() || !y.is_finite() {
            return;
        }
        let key = self.cell_coords(x, y);
        self.cells
            .entry(key)
            .or_insert_with(|| Vec::with_capacity(8))
            .push(entity);
    }

    /// Clear and rebuild from entity IDs + transforms (parallel arrays).
    pub fn rebuild(&mut self, entities: &[u32], transforms: &[TransformComponent]) {
        self.clear();
        for (&entity, t) in entities.iter().zip(transforms.iter()) {
            self.insert(entity, t.x, t.y);
        }
    }

    /// Return candidate entities from cells overlapping the radius around `(x, y)`.
    /// Does NOT filter by exact distance — caller must apply precise distance checks.
    pub fn query_candidates(&self, x: f32, y: f32, radius: f32) -> Vec<u32> {
        let min = self.cell_coords(x - radius, y - radius);
        let max = self.cell_coords(x + radius, y + radius);

        let cells_x = (max.0 - min.0 + 1) as usize;
        let cells_y = (max.1 - min.1 + 1) as usize;
        let estimated = cells_x * cells_y * 4;
        let mut result = Vec::with_capacity(estimated.max(16));

        for cx in min.0..=max.0 {
            for cy in min.1..=max.1 {
                if let Some(entities) = self.cells.get(&(cx, cy)) {
                    result.extend(entities.iter().copied());
                }
            }
        }

        result
    }

    /// Find the closest visible entity within hit radius of `(x, y)`.
    ///
    /// Checks the 9 cells around the point, filters by visibility, and returns
    /// the entity whose center is closest and within `radius * hit_padding`.
    /// `entity_to_index` maps entity ID → array index in the SoA arrays.
    pub fn query_point(
        &self,
        x: f32,
        y: f32,
        transforms: &[TransformComponent],
        hierarchy: &[HierarchyComponent],
        entity_to_index: &FxHashMap<u32, usize>,
        hit_padding: f32,
    ) -> Option<u32> {
        let (cx, cy) = self.cell_coords(x, y);
        let mut best_entity: Option<u32> = None;
        let mut best_dist_sq = f32::MAX;

        for dx in -1..=1 {
            for dy in -1..=1 {
                if let Some(entities) = self.cells.get(&(cx + dx, cy + dy)) {
                    for &entity in entities {
                        let Some(&idx) = entity_to_index.get(&entity) else {
                            continue;
                        };
                        if hierarchy[idx].visible == 0 {
                            continue;
                        }
                        let t = &transforms[idx];
                        let ddx = x - t.x;
                        let ddy = y - t.y;
                        let dist_sq = ddx * ddx + ddy * ddy;
                        let hit_r = hierarchy[idx].radius * hit_padding;
                        if dist_sq < hit_r * hit_r && dist_sq < best_dist_sq {
                            best_dist_sq = dist_sq;
                            best_entity = Some(entity);
                        }
                    }
                }
            }
        }

        best_entity
    }

    /// Optimized query checking only the 9 cells around `(x, y)` (center + 8 adjacent).
    /// Best when `cell_size` matches the perception/interaction radius.
    pub fn query_neighbors(&self, x: f32, y: f32) -> Vec<u32> {
        let (cx, cy) = self.cell_coords(x, y);
        let mut result = Vec::with_capacity(16);

        for dx in -1..=1 {
            for dy in -1..=1 {
                if let Some(entities) = self.cells.get(&(cx + dx, cy + dy)) {
                    result.extend(entities.iter().copied());
                }
            }
        }

        result
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_hierarchy(visible: bool, radius: f32) -> HierarchyComponent {
        HierarchyComponent {
            visible: visible as u8,
            radius,
            ..Default::default()
        }
    }

    #[test]
    fn test_query_point_empty() {
        let grid = SpatialGrid::new(50.0);
        let transforms: Vec<TransformComponent> = vec![];
        let hierarchy: Vec<HierarchyComponent> = vec![];
        let map = FxHashMap::default();
        assert!(grid.query_point(0.0, 0.0, &transforms, &hierarchy, &map, 1.5).is_none());
    }

    #[test]
    fn test_query_point_hit() {
        let mut grid = SpatialGrid::new(50.0);
        grid.insert(0, 10.0, 10.0);
        let transforms = vec![TransformComponent { x: 10.0, y: 10.0, scale: 1.0 }];
        let hierarchy = vec![make_hierarchy(true, 8.0)];
        let mut map = FxHashMap::default();
        map.insert(0, 0);

        // Click right on the entity — should hit
        let result = grid.query_point(10.0, 10.0, &transforms, &hierarchy, &map, 1.5);
        assert_eq!(result, Some(0));
    }

    #[test]
    fn test_query_point_miss() {
        let mut grid = SpatialGrid::new(50.0);
        grid.insert(0, 10.0, 10.0);
        let transforms = vec![TransformComponent { x: 10.0, y: 10.0, scale: 1.0 }];
        let hierarchy = vec![make_hierarchy(true, 8.0)];
        let mut map = FxHashMap::default();
        map.insert(0, 0);

        // Click far from entity (radius*1.5 = 12.0, clicking at distance ~50)
        let result = grid.query_point(60.0, 10.0, &transforms, &hierarchy, &map, 1.5);
        assert!(result.is_none());
    }

    #[test]
    fn test_query_point_closest_wins() {
        let mut grid = SpatialGrid::new(50.0);
        grid.insert(0, 5.0, 5.0);
        grid.insert(1, 10.0, 10.0);
        let transforms = vec![
            TransformComponent { x: 5.0, y: 5.0, scale: 1.0 },
            TransformComponent { x: 10.0, y: 10.0, scale: 1.0 },
        ];
        let hierarchy = vec![make_hierarchy(true, 20.0), make_hierarchy(true, 20.0)];
        let mut map = FxHashMap::default();
        map.insert(0, 0);
        map.insert(1, 1);

        // Click at (7, 7) — closer to entity 0 at (5,5) than entity 1 at (10,10)
        let result = grid.query_point(7.0, 7.0, &transforms, &hierarchy, &map, 1.5);
        assert_eq!(result, Some(0));
    }

    #[test]
    fn test_query_point_invisible_skipped() {
        let mut grid = SpatialGrid::new(50.0);
        grid.insert(0, 10.0, 10.0);
        let transforms = vec![TransformComponent { x: 10.0, y: 10.0, scale: 1.0 }];
        let hierarchy = vec![make_hierarchy(false, 8.0)];
        let mut map = FxHashMap::default();
        map.insert(0, 0);

        let result = grid.query_point(10.0, 10.0, &transforms, &hierarchy, &map, 1.5);
        assert!(result.is_none());
    }

    #[test]
    fn test_query_point_zero_radius() {
        let mut grid = SpatialGrid::new(50.0);
        grid.insert(0, 10.0, 10.0);
        let transforms = vec![TransformComponent { x: 10.0, y: 10.0, scale: 1.0 }];
        let hierarchy = vec![make_hierarchy(true, 0.0)];
        let mut map = FxHashMap::default();
        map.insert(0, 0);

        // Exact position match but radius is 0 — no hit (dist_sq=0 < 0 is false)
        let result = grid.query_point(10.0, 10.0, &transforms, &hierarchy, &map, 1.5);
        // dist_sq=0 < 0*1.5^2=0 is false, so no hit
        assert!(result.is_none());
    }

    #[test]
    fn test_query_point_boundary() {
        let mut grid = SpatialGrid::new(50.0);
        grid.insert(0, 10.0, 10.0);
        let transforms = vec![TransformComponent { x: 10.0, y: 10.0, scale: 1.0 }];
        let hierarchy = vec![make_hierarchy(true, 10.0)];
        let mut map = FxHashMap::default();
        map.insert(0, 0);

        // Click at exactly hit_radius distance (10.0 * 1.5 = 15.0)
        // At (25.0, 10.0) -> distance = 15.0, hit_r = 15.0, dist_sq == hit_r^2 -> NOT hit (strict <)
        let result = grid.query_point(25.0, 10.0, &transforms, &hierarchy, &map, 1.5);
        assert!(result.is_none());

        // Just inside: at (24.9, 10.0) -> distance < 15.0
        let result = grid.query_point(24.9, 10.0, &transforms, &hierarchy, &map, 1.5);
        assert_eq!(result, Some(0));
    }

    #[test]
    fn test_spatial_grid_insert_query() {
        let mut grid = SpatialGrid::new(50.0);

        // Three entities in different cells
        grid.insert(0, 10.0, 10.0);   // cell (0, 0)
        grid.insert(1, 60.0, 60.0);   // cell (1, 1)
        grid.insert(2, 200.0, 200.0); // cell (4, 4) — far away

        // Query around (10, 10) with radius 70 — should find entities 0 and 1
        let nearby = grid.query_candidates(10.0, 10.0, 70.0);
        assert!(nearby.contains(&0));
        assert!(nearby.contains(&1));
        assert!(!nearby.contains(&2));
    }

    #[test]
    fn test_spatial_grid_rebuild() {
        let mut grid = SpatialGrid::new(50.0);
        let entities: Vec<u32> = vec![0, 1, 2];
        let transforms = vec![
            TransformComponent { x: 5.0, y: 5.0, scale: 1.0 },
            TransformComponent { x: 10.0, y: 10.0, scale: 1.0 },
            TransformComponent { x: 300.0, y: 300.0, scale: 1.0 },
        ];

        grid.rebuild(&entities, &transforms);

        // Entities 0 and 1 are in/near cell (0,0); entity 2 is far away
        let nearby = grid.query_neighbors(5.0, 5.0);
        assert!(nearby.contains(&0));
        assert!(nearby.contains(&1));
        assert!(!nearby.contains(&2));
    }

    #[test]
    fn test_spatial_grid_clear() {
        let mut grid = SpatialGrid::new(50.0);
        grid.insert(0, 10.0, 10.0);
        grid.insert(1, 20.0, 20.0);

        assert!(!grid.query_neighbors(10.0, 10.0).is_empty());

        grid.clear();

        assert!(grid.query_neighbors(10.0, 10.0).is_empty());
        // Cells still exist (reused), but are empty
        assert!(!grid.cells.is_empty());
    }

    #[test]
    fn test_query_empty_grid() {
        let grid = SpatialGrid::new(50.0);

        let result = grid.query_candidates(100.0, 100.0, 200.0);
        assert!(result.is_empty());

        let result = grid.query_neighbors(0.0, 0.0);
        assert!(result.is_empty());
    }

    #[test]
    fn test_query_neighbors() {
        let mut grid = SpatialGrid::new(50.0);

        // Entity at cell (0, 0)
        grid.insert(0, 25.0, 25.0);
        // Entity at adjacent cell (1, 0)
        grid.insert(1, 75.0, 25.0);
        // Entity at adjacent cell (0, 1)
        grid.insert(2, 25.0, 75.0);
        // Entity at diagonal cell (1, 1)
        grid.insert(3, 75.0, 75.0);
        // Entity 2 cells away (2, 0) — outside ±1 neighborhood
        grid.insert(4, 125.0, 25.0);

        let neighbors = grid.query_neighbors(25.0, 25.0);
        assert!(neighbors.contains(&0));
        assert!(neighbors.contains(&1));
        assert!(neighbors.contains(&2));
        assert!(neighbors.contains(&3));
        assert!(!neighbors.contains(&4));
    }

    #[test]
    fn test_large_grid() {
        let mut grid = SpatialGrid::new(50.0);

        // Insert 1000 entities spread across a 1000x1000 area
        for i in 0..1000u32 {
            let x = (i % 100) as f32 * 10.0; // 0..990
            let y = (i / 100) as f32 * 100.0; // 0..900
            grid.insert(i, x, y);
        }

        // Query a small region — should return a subset, not all 1000
        let result = grid.query_candidates(50.0, 50.0, 50.0);
        assert!(!result.is_empty());
        assert!(result.len() < 1000);

        // Query neighbors at origin — should also return a subset
        let neighbors = grid.query_neighbors(0.0, 0.0);
        assert!(!neighbors.is_empty());
        assert!(neighbors.len() < 1000);
    }
}
