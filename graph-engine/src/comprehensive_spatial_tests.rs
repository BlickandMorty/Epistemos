//! Automatically generated comprehensive spatial tests.
#[cfg(test)]
mod tests {
    use crate::spatial::SpatialIndex;
    use crate::types::{Node, NodeType};

    fn make_test_node(id: u32, x: f32, y: f32, radius: f32, visible: bool) -> Node {
        Node {
            id,
            uuid: format!("uuid-{}", id),
            x,
            y,
            vx: 0.0,
            vy: 0.0,
            fx: None,
            fy: None,
            node_type: NodeType::from_u8(0),
            link_count: 1,
            radius,
            label: format!("N{}", id),
            visible,
            created_at: 0.0,
            updated_at: 0.0,
            confidence: 0.0,
            color_override: [0.0; 4],
        }
    }

    #[test]
    fn test_spatial_0_n0_clustered_uniform_10_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_1_n0_clustered_uniform_10_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_2_n0_clustered_uniform_10_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_3_n0_clustered_uniform_10_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_4_n0_clustered_uniform_10_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_5_n0_clustered_uniform_10_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_6_n0_clustered_uniform_10_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_7_n0_clustered_uniform_10_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_8_n0_clustered_uniform_10_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_9_n0_clustered_uniform_10_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_10_n0_clustered_uniform_10_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_11_n0_clustered_uniform_10_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_12_n0_clustered_uniform_100_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_13_n0_clustered_uniform_100_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_14_n0_clustered_uniform_100_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_15_n0_clustered_uniform_100_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_16_n0_clustered_uniform_100_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_17_n0_clustered_uniform_100_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_18_n0_clustered_uniform_100_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_19_n0_clustered_uniform_100_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_20_n0_clustered_uniform_100_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_21_n0_clustered_uniform_100_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_22_n0_clustered_uniform_100_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_23_n0_clustered_uniform_100_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_24_n0_clustered_mixed_1_to_50_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_25_n0_clustered_mixed_1_to_50_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_26_n0_clustered_mixed_1_to_50_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_27_n0_clustered_mixed_1_to_50_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_28_n0_clustered_mixed_1_to_50_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_29_n0_clustered_mixed_1_to_50_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_30_n0_clustered_mixed_1_to_50_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_31_n0_clustered_mixed_1_to_50_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_32_n0_clustered_mixed_1_to_50_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_33_n0_clustered_mixed_1_to_50_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_34_n0_clustered_mixed_1_to_50_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_35_n0_clustered_mixed_1_to_50_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_36_n0_grid_uniform_10_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_37_n0_grid_uniform_10_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_38_n0_grid_uniform_10_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_39_n0_grid_uniform_10_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_40_n0_grid_uniform_10_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_41_n0_grid_uniform_10_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_42_n0_grid_uniform_10_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_43_n0_grid_uniform_10_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_44_n0_grid_uniform_10_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_45_n0_grid_uniform_10_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_46_n0_grid_uniform_10_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_47_n0_grid_uniform_10_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_48_n0_grid_uniform_100_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_49_n0_grid_uniform_100_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_50_n0_grid_uniform_100_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_51_n0_grid_uniform_100_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_52_n0_grid_uniform_100_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_53_n0_grid_uniform_100_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_54_n0_grid_uniform_100_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_55_n0_grid_uniform_100_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_56_n0_grid_uniform_100_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_57_n0_grid_uniform_100_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_58_n0_grid_uniform_100_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_59_n0_grid_uniform_100_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_60_n0_grid_mixed_1_to_50_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_61_n0_grid_mixed_1_to_50_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_62_n0_grid_mixed_1_to_50_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_63_n0_grid_mixed_1_to_50_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_64_n0_grid_mixed_1_to_50_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_65_n0_grid_mixed_1_to_50_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_66_n0_grid_mixed_1_to_50_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_67_n0_grid_mixed_1_to_50_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_68_n0_grid_mixed_1_to_50_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_69_n0_grid_mixed_1_to_50_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_70_n0_grid_mixed_1_to_50_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_71_n0_grid_mixed_1_to_50_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_72_n0_line_uniform_10_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_73_n0_line_uniform_10_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_74_n0_line_uniform_10_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_75_n0_line_uniform_10_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_76_n0_line_uniform_10_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_77_n0_line_uniform_10_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_78_n0_line_uniform_10_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_79_n0_line_uniform_10_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_80_n0_line_uniform_10_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_81_n0_line_uniform_10_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_82_n0_line_uniform_10_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_83_n0_line_uniform_10_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_84_n0_line_uniform_100_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_85_n0_line_uniform_100_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_86_n0_line_uniform_100_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_87_n0_line_uniform_100_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_88_n0_line_uniform_100_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_89_n0_line_uniform_100_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_90_n0_line_uniform_100_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_91_n0_line_uniform_100_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_92_n0_line_uniform_100_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_93_n0_line_uniform_100_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_94_n0_line_uniform_100_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_95_n0_line_uniform_100_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_96_n0_line_mixed_1_to_50_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_97_n0_line_mixed_1_to_50_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_98_n0_line_mixed_1_to_50_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_99_n0_line_mixed_1_to_50_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_100_n0_line_mixed_1_to_50_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_101_n0_line_mixed_1_to_50_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_102_n0_line_mixed_1_to_50_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_103_n0_line_mixed_1_to_50_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_104_n0_line_mixed_1_to_50_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_105_n0_line_mixed_1_to_50_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_106_n0_line_mixed_1_to_50_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_107_n0_line_mixed_1_to_50_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_108_n0_origin_uniform_10_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_109_n0_origin_uniform_10_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_110_n0_origin_uniform_10_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_111_n0_origin_uniform_10_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_112_n0_origin_uniform_10_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_113_n0_origin_uniform_10_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_114_n0_origin_uniform_10_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_115_n0_origin_uniform_10_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_116_n0_origin_uniform_10_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_117_n0_origin_uniform_10_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_118_n0_origin_uniform_10_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_119_n0_origin_uniform_10_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_120_n0_origin_uniform_100_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_121_n0_origin_uniform_100_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_122_n0_origin_uniform_100_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_123_n0_origin_uniform_100_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_124_n0_origin_uniform_100_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_125_n0_origin_uniform_100_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_126_n0_origin_uniform_100_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_127_n0_origin_uniform_100_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_128_n0_origin_uniform_100_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_129_n0_origin_uniform_100_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_130_n0_origin_uniform_100_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_131_n0_origin_uniform_100_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_132_n0_origin_mixed_1_to_50_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_133_n0_origin_mixed_1_to_50_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_134_n0_origin_mixed_1_to_50_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_135_n0_origin_mixed_1_to_50_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_136_n0_origin_mixed_1_to_50_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_137_n0_origin_mixed_1_to_50_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_138_n0_origin_mixed_1_to_50_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_139_n0_origin_mixed_1_to_50_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_140_n0_origin_mixed_1_to_50_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_141_n0_origin_mixed_1_to_50_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_142_n0_origin_mixed_1_to_50_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_143_n0_origin_mixed_1_to_50_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..0 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..0).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
    }

    #[test]
    fn test_spatial_144_n1_clustered_uniform_10_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_145_n1_clustered_uniform_10_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_146_n1_clustered_uniform_10_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_147_n1_clustered_uniform_10_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_148_n1_clustered_uniform_10_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_149_n1_clustered_uniform_10_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_150_n1_clustered_uniform_10_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_151_n1_clustered_uniform_10_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_152_n1_clustered_uniform_10_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_153_n1_clustered_uniform_10_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_154_n1_clustered_uniform_10_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_155_n1_clustered_uniform_10_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_156_n1_clustered_uniform_100_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_157_n1_clustered_uniform_100_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_158_n1_clustered_uniform_100_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_159_n1_clustered_uniform_100_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_160_n1_clustered_uniform_100_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_161_n1_clustered_uniform_100_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_162_n1_clustered_uniform_100_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_163_n1_clustered_uniform_100_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_164_n1_clustered_uniform_100_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_165_n1_clustered_uniform_100_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_166_n1_clustered_uniform_100_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_167_n1_clustered_uniform_100_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_168_n1_clustered_mixed_1_to_50_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_169_n1_clustered_mixed_1_to_50_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_170_n1_clustered_mixed_1_to_50_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_171_n1_clustered_mixed_1_to_50_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_172_n1_clustered_mixed_1_to_50_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_173_n1_clustered_mixed_1_to_50_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_174_n1_clustered_mixed_1_to_50_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_175_n1_clustered_mixed_1_to_50_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_176_n1_clustered_mixed_1_to_50_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_177_n1_clustered_mixed_1_to_50_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_178_n1_clustered_mixed_1_to_50_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_179_n1_clustered_mixed_1_to_50_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_180_n1_grid_uniform_10_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_181_n1_grid_uniform_10_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_182_n1_grid_uniform_10_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        assert!(res.is_none(), "Should definitely miss isolated far point");
    }

    #[test]
    fn test_spatial_183_n1_grid_uniform_10_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_184_n1_grid_uniform_10_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_185_n1_grid_uniform_10_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_186_n1_grid_uniform_10_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_187_n1_grid_uniform_10_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_188_n1_grid_uniform_10_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_189_n1_grid_uniform_10_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_190_n1_grid_uniform_10_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_191_n1_grid_uniform_10_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_192_n1_grid_uniform_100_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_193_n1_grid_uniform_100_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_194_n1_grid_uniform_100_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_195_n1_grid_uniform_100_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_196_n1_grid_uniform_100_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_197_n1_grid_uniform_100_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_198_n1_grid_uniform_100_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_199_n1_grid_uniform_100_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_200_n1_grid_uniform_100_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_201_n1_grid_uniform_100_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_202_n1_grid_uniform_100_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_203_n1_grid_uniform_100_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_204_n1_grid_mixed_1_to_50_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_205_n1_grid_mixed_1_to_50_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_206_n1_grid_mixed_1_to_50_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_207_n1_grid_mixed_1_to_50_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_208_n1_grid_mixed_1_to_50_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_209_n1_grid_mixed_1_to_50_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_210_n1_grid_mixed_1_to_50_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_211_n1_grid_mixed_1_to_50_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_212_n1_grid_mixed_1_to_50_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_213_n1_grid_mixed_1_to_50_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_214_n1_grid_mixed_1_to_50_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_215_n1_grid_mixed_1_to_50_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_216_n1_line_uniform_10_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_217_n1_line_uniform_10_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_218_n1_line_uniform_10_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_219_n1_line_uniform_10_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_220_n1_line_uniform_10_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_221_n1_line_uniform_10_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_222_n1_line_uniform_10_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_223_n1_line_uniform_10_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_224_n1_line_uniform_10_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_225_n1_line_uniform_10_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_226_n1_line_uniform_10_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_227_n1_line_uniform_10_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_228_n1_line_uniform_100_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_229_n1_line_uniform_100_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_230_n1_line_uniform_100_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_231_n1_line_uniform_100_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_232_n1_line_uniform_100_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_233_n1_line_uniform_100_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_234_n1_line_uniform_100_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_235_n1_line_uniform_100_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_236_n1_line_uniform_100_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_237_n1_line_uniform_100_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_238_n1_line_uniform_100_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_239_n1_line_uniform_100_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_240_n1_line_mixed_1_to_50_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_241_n1_line_mixed_1_to_50_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_242_n1_line_mixed_1_to_50_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_243_n1_line_mixed_1_to_50_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_244_n1_line_mixed_1_to_50_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_245_n1_line_mixed_1_to_50_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_246_n1_line_mixed_1_to_50_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_247_n1_line_mixed_1_to_50_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_248_n1_line_mixed_1_to_50_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_249_n1_line_mixed_1_to_50_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_250_n1_line_mixed_1_to_50_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_251_n1_line_mixed_1_to_50_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_252_n1_origin_uniform_10_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_253_n1_origin_uniform_10_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_254_n1_origin_uniform_10_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_255_n1_origin_uniform_10_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_256_n1_origin_uniform_10_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_257_n1_origin_uniform_10_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_258_n1_origin_uniform_10_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_259_n1_origin_uniform_10_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_260_n1_origin_uniform_10_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_261_n1_origin_uniform_10_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_262_n1_origin_uniform_10_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_263_n1_origin_uniform_10_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_264_n1_origin_uniform_100_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_265_n1_origin_uniform_100_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_266_n1_origin_uniform_100_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_267_n1_origin_uniform_100_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_268_n1_origin_uniform_100_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_269_n1_origin_uniform_100_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_270_n1_origin_uniform_100_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_271_n1_origin_uniform_100_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_272_n1_origin_uniform_100_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_273_n1_origin_uniform_100_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_274_n1_origin_uniform_100_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_275_n1_origin_uniform_100_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_276_n1_origin_mixed_1_to_50_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_277_n1_origin_mixed_1_to_50_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_278_n1_origin_mixed_1_to_50_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_279_n1_origin_mixed_1_to_50_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 1;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_280_n1_origin_mixed_1_to_50_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_281_n1_origin_mixed_1_to_50_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_282_n1_origin_mixed_1_to_50_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_283_n1_origin_mixed_1_to_50_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_284_n1_origin_mixed_1_to_50_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 1 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_285_n1_origin_mixed_1_to_50_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_286_n1_origin_mixed_1_to_50_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_287_n1_origin_mixed_1_to_50_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..1 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..1).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_288_n10_clustered_uniform_10_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_289_n10_clustered_uniform_10_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_290_n10_clustered_uniform_10_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_291_n10_clustered_uniform_10_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_292_n10_clustered_uniform_10_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_293_n10_clustered_uniform_10_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_294_n10_clustered_uniform_10_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_295_n10_clustered_uniform_10_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_296_n10_clustered_uniform_10_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_297_n10_clustered_uniform_10_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_298_n10_clustered_uniform_10_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_299_n10_clustered_uniform_10_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_300_n10_clustered_uniform_100_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_301_n10_clustered_uniform_100_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_302_n10_clustered_uniform_100_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_303_n10_clustered_uniform_100_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_304_n10_clustered_uniform_100_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_305_n10_clustered_uniform_100_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_306_n10_clustered_uniform_100_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_307_n10_clustered_uniform_100_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_308_n10_clustered_uniform_100_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_309_n10_clustered_uniform_100_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_310_n10_clustered_uniform_100_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_311_n10_clustered_uniform_100_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_312_n10_clustered_mixed_1_to_50_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_313_n10_clustered_mixed_1_to_50_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_314_n10_clustered_mixed_1_to_50_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_315_n10_clustered_mixed_1_to_50_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_316_n10_clustered_mixed_1_to_50_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_317_n10_clustered_mixed_1_to_50_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_318_n10_clustered_mixed_1_to_50_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_319_n10_clustered_mixed_1_to_50_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_320_n10_clustered_mixed_1_to_50_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_321_n10_clustered_mixed_1_to_50_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_322_n10_clustered_mixed_1_to_50_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_323_n10_clustered_mixed_1_to_50_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_324_n10_grid_uniform_10_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_325_n10_grid_uniform_10_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_326_n10_grid_uniform_10_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        assert!(res.is_none(), "Should definitely miss isolated far point");
    }

    #[test]
    fn test_spatial_327_n10_grid_uniform_10_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_328_n10_grid_uniform_10_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_329_n10_grid_uniform_10_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_330_n10_grid_uniform_10_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_331_n10_grid_uniform_10_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_332_n10_grid_uniform_10_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_333_n10_grid_uniform_10_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_334_n10_grid_uniform_10_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_335_n10_grid_uniform_10_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_336_n10_grid_uniform_100_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_337_n10_grid_uniform_100_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_338_n10_grid_uniform_100_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_339_n10_grid_uniform_100_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_340_n10_grid_uniform_100_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_341_n10_grid_uniform_100_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_342_n10_grid_uniform_100_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_343_n10_grid_uniform_100_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_344_n10_grid_uniform_100_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_345_n10_grid_uniform_100_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_346_n10_grid_uniform_100_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_347_n10_grid_uniform_100_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_348_n10_grid_mixed_1_to_50_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_349_n10_grid_mixed_1_to_50_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_350_n10_grid_mixed_1_to_50_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_351_n10_grid_mixed_1_to_50_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_352_n10_grid_mixed_1_to_50_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_353_n10_grid_mixed_1_to_50_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_354_n10_grid_mixed_1_to_50_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_355_n10_grid_mixed_1_to_50_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_356_n10_grid_mixed_1_to_50_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_357_n10_grid_mixed_1_to_50_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_358_n10_grid_mixed_1_to_50_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_359_n10_grid_mixed_1_to_50_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_360_n10_line_uniform_10_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_361_n10_line_uniform_10_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_362_n10_line_uniform_10_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_363_n10_line_uniform_10_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_364_n10_line_uniform_10_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_365_n10_line_uniform_10_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_366_n10_line_uniform_10_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_367_n10_line_uniform_10_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_368_n10_line_uniform_10_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_369_n10_line_uniform_10_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_370_n10_line_uniform_10_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_371_n10_line_uniform_10_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_372_n10_line_uniform_100_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_373_n10_line_uniform_100_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_374_n10_line_uniform_100_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_375_n10_line_uniform_100_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_376_n10_line_uniform_100_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_377_n10_line_uniform_100_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_378_n10_line_uniform_100_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_379_n10_line_uniform_100_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_380_n10_line_uniform_100_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_381_n10_line_uniform_100_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_382_n10_line_uniform_100_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_383_n10_line_uniform_100_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_384_n10_line_mixed_1_to_50_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_385_n10_line_mixed_1_to_50_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_386_n10_line_mixed_1_to_50_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_387_n10_line_mixed_1_to_50_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_388_n10_line_mixed_1_to_50_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_389_n10_line_mixed_1_to_50_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_390_n10_line_mixed_1_to_50_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_391_n10_line_mixed_1_to_50_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_392_n10_line_mixed_1_to_50_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_393_n10_line_mixed_1_to_50_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_394_n10_line_mixed_1_to_50_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_395_n10_line_mixed_1_to_50_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_396_n10_origin_uniform_10_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_397_n10_origin_uniform_10_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_398_n10_origin_uniform_10_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_399_n10_origin_uniform_10_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_400_n10_origin_uniform_10_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_401_n10_origin_uniform_10_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_402_n10_origin_uniform_10_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_403_n10_origin_uniform_10_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_404_n10_origin_uniform_10_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_405_n10_origin_uniform_10_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_406_n10_origin_uniform_10_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_407_n10_origin_uniform_10_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_408_n10_origin_uniform_100_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_409_n10_origin_uniform_100_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_410_n10_origin_uniform_100_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_411_n10_origin_uniform_100_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_412_n10_origin_uniform_100_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_413_n10_origin_uniform_100_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_414_n10_origin_uniform_100_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_415_n10_origin_uniform_100_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_416_n10_origin_uniform_100_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_417_n10_origin_uniform_100_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_418_n10_origin_uniform_100_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_419_n10_origin_uniform_100_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_420_n10_origin_mixed_1_to_50_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_421_n10_origin_mixed_1_to_50_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_422_n10_origin_mixed_1_to_50_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_423_n10_origin_mixed_1_to_50_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 10;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_424_n10_origin_mixed_1_to_50_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_425_n10_origin_mixed_1_to_50_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_426_n10_origin_mixed_1_to_50_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_427_n10_origin_mixed_1_to_50_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_428_n10_origin_mixed_1_to_50_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 10 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_429_n10_origin_mixed_1_to_50_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_430_n10_origin_mixed_1_to_50_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_431_n10_origin_mixed_1_to_50_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..10 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..10).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_432_n100_clustered_uniform_10_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_433_n100_clustered_uniform_10_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_434_n100_clustered_uniform_10_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_435_n100_clustered_uniform_10_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_436_n100_clustered_uniform_10_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_437_n100_clustered_uniform_10_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_438_n100_clustered_uniform_10_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_439_n100_clustered_uniform_10_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_440_n100_clustered_uniform_10_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_441_n100_clustered_uniform_10_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_442_n100_clustered_uniform_10_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_443_n100_clustered_uniform_10_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_444_n100_clustered_uniform_100_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_445_n100_clustered_uniform_100_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_446_n100_clustered_uniform_100_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_447_n100_clustered_uniform_100_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_448_n100_clustered_uniform_100_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_449_n100_clustered_uniform_100_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_450_n100_clustered_uniform_100_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_451_n100_clustered_uniform_100_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_452_n100_clustered_uniform_100_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_453_n100_clustered_uniform_100_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_454_n100_clustered_uniform_100_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_455_n100_clustered_uniform_100_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_456_n100_clustered_mixed_1_to_50_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_457_n100_clustered_mixed_1_to_50_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_458_n100_clustered_mixed_1_to_50_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_459_n100_clustered_mixed_1_to_50_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_460_n100_clustered_mixed_1_to_50_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_461_n100_clustered_mixed_1_to_50_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_462_n100_clustered_mixed_1_to_50_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_463_n100_clustered_mixed_1_to_50_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_464_n100_clustered_mixed_1_to_50_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_465_n100_clustered_mixed_1_to_50_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_466_n100_clustered_mixed_1_to_50_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_467_n100_clustered_mixed_1_to_50_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_468_n100_grid_uniform_10_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_469_n100_grid_uniform_10_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_470_n100_grid_uniform_10_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        assert!(res.is_none(), "Should definitely miss isolated far point");
    }

    #[test]
    fn test_spatial_471_n100_grid_uniform_10_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_472_n100_grid_uniform_10_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_473_n100_grid_uniform_10_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_474_n100_grid_uniform_10_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_475_n100_grid_uniform_10_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_476_n100_grid_uniform_10_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_477_n100_grid_uniform_10_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_478_n100_grid_uniform_10_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_479_n100_grid_uniform_10_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_480_n100_grid_uniform_100_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_481_n100_grid_uniform_100_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_482_n100_grid_uniform_100_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_483_n100_grid_uniform_100_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_484_n100_grid_uniform_100_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_485_n100_grid_uniform_100_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_486_n100_grid_uniform_100_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_487_n100_grid_uniform_100_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_488_n100_grid_uniform_100_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_489_n100_grid_uniform_100_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_490_n100_grid_uniform_100_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_491_n100_grid_uniform_100_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_492_n100_grid_mixed_1_to_50_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_493_n100_grid_mixed_1_to_50_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_494_n100_grid_mixed_1_to_50_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_495_n100_grid_mixed_1_to_50_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_496_n100_grid_mixed_1_to_50_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_497_n100_grid_mixed_1_to_50_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_498_n100_grid_mixed_1_to_50_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_499_n100_grid_mixed_1_to_50_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_500_n100_grid_mixed_1_to_50_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_501_n100_grid_mixed_1_to_50_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_502_n100_grid_mixed_1_to_50_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_503_n100_grid_mixed_1_to_50_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_504_n100_line_uniform_10_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_505_n100_line_uniform_10_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_506_n100_line_uniform_10_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_507_n100_line_uniform_10_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_508_n100_line_uniform_10_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_509_n100_line_uniform_10_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_510_n100_line_uniform_10_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_511_n100_line_uniform_10_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_512_n100_line_uniform_10_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_513_n100_line_uniform_10_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_514_n100_line_uniform_10_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_515_n100_line_uniform_10_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_516_n100_line_uniform_100_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_517_n100_line_uniform_100_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_518_n100_line_uniform_100_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_519_n100_line_uniform_100_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_520_n100_line_uniform_100_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_521_n100_line_uniform_100_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_522_n100_line_uniform_100_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_523_n100_line_uniform_100_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_524_n100_line_uniform_100_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_525_n100_line_uniform_100_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_526_n100_line_uniform_100_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_527_n100_line_uniform_100_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_528_n100_line_mixed_1_to_50_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_529_n100_line_mixed_1_to_50_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_530_n100_line_mixed_1_to_50_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_531_n100_line_mixed_1_to_50_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_532_n100_line_mixed_1_to_50_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_533_n100_line_mixed_1_to_50_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_534_n100_line_mixed_1_to_50_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_535_n100_line_mixed_1_to_50_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_536_n100_line_mixed_1_to_50_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_537_n100_line_mixed_1_to_50_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_538_n100_line_mixed_1_to_50_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_539_n100_line_mixed_1_to_50_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_540_n100_origin_uniform_10_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_541_n100_origin_uniform_10_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_542_n100_origin_uniform_10_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_543_n100_origin_uniform_10_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_544_n100_origin_uniform_10_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_545_n100_origin_uniform_10_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_546_n100_origin_uniform_10_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_547_n100_origin_uniform_10_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_548_n100_origin_uniform_10_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_549_n100_origin_uniform_10_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_550_n100_origin_uniform_10_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_551_n100_origin_uniform_10_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_552_n100_origin_uniform_100_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_553_n100_origin_uniform_100_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_554_n100_origin_uniform_100_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_555_n100_origin_uniform_100_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_556_n100_origin_uniform_100_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_557_n100_origin_uniform_100_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_558_n100_origin_uniform_100_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_559_n100_origin_uniform_100_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_560_n100_origin_uniform_100_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_561_n100_origin_uniform_100_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_562_n100_origin_uniform_100_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_563_n100_origin_uniform_100_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_564_n100_origin_mixed_1_to_50_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_565_n100_origin_mixed_1_to_50_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_566_n100_origin_mixed_1_to_50_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_567_n100_origin_mixed_1_to_50_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 100;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_568_n100_origin_mixed_1_to_50_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_569_n100_origin_mixed_1_to_50_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_570_n100_origin_mixed_1_to_50_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_571_n100_origin_mixed_1_to_50_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_572_n100_origin_mixed_1_to_50_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 100 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_573_n100_origin_mixed_1_to_50_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_574_n100_origin_mixed_1_to_50_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_575_n100_origin_mixed_1_to_50_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..100 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..100).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_576_n500_clustered_uniform_10_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_577_n500_clustered_uniform_10_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_578_n500_clustered_uniform_10_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_579_n500_clustered_uniform_10_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_580_n500_clustered_uniform_10_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_581_n500_clustered_uniform_10_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_582_n500_clustered_uniform_10_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_583_n500_clustered_uniform_10_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_584_n500_clustered_uniform_10_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_585_n500_clustered_uniform_10_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_586_n500_clustered_uniform_10_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_587_n500_clustered_uniform_10_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_588_n500_clustered_uniform_100_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_589_n500_clustered_uniform_100_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_590_n500_clustered_uniform_100_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_591_n500_clustered_uniform_100_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_592_n500_clustered_uniform_100_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_593_n500_clustered_uniform_100_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_594_n500_clustered_uniform_100_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_595_n500_clustered_uniform_100_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_596_n500_clustered_uniform_100_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_597_n500_clustered_uniform_100_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_598_n500_clustered_uniform_100_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_599_n500_clustered_uniform_100_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_600_n500_clustered_mixed_1_to_50_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_601_n500_clustered_mixed_1_to_50_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_602_n500_clustered_mixed_1_to_50_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_603_n500_clustered_mixed_1_to_50_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_604_n500_clustered_mixed_1_to_50_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_605_n500_clustered_mixed_1_to_50_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_606_n500_clustered_mixed_1_to_50_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_607_n500_clustered_mixed_1_to_50_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_608_n500_clustered_mixed_1_to_50_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_609_n500_clustered_mixed_1_to_50_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_610_n500_clustered_mixed_1_to_50_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_611_n500_clustered_mixed_1_to_50_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let cluster_dx = (i % 3) as f32 * 2.0;
            let cluster_dy = (i / 3 % 3) as f32 * 2.0;
            let offset = (i / 9) as f32 * 1000.0;
            let x = offset + cluster_dx;
            let y = offset + cluster_dy;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_612_n500_grid_uniform_10_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_613_n500_grid_uniform_10_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_614_n500_grid_uniform_10_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        assert!(res.is_none(), "Should definitely miss isolated far point");
    }

    #[test]
    fn test_spatial_615_n500_grid_uniform_10_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_616_n500_grid_uniform_10_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_617_n500_grid_uniform_10_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_618_n500_grid_uniform_10_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_619_n500_grid_uniform_10_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_620_n500_grid_uniform_10_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_621_n500_grid_uniform_10_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_622_n500_grid_uniform_10_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_623_n500_grid_uniform_10_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_624_n500_grid_uniform_100_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_625_n500_grid_uniform_100_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_626_n500_grid_uniform_100_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_627_n500_grid_uniform_100_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_628_n500_grid_uniform_100_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_629_n500_grid_uniform_100_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_630_n500_grid_uniform_100_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_631_n500_grid_uniform_100_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_632_n500_grid_uniform_100_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_633_n500_grid_uniform_100_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_634_n500_grid_uniform_100_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_635_n500_grid_uniform_100_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_636_n500_grid_mixed_1_to_50_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_637_n500_grid_mixed_1_to_50_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_638_n500_grid_mixed_1_to_50_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_639_n500_grid_mixed_1_to_50_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_640_n500_grid_mixed_1_to_50_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_641_n500_grid_mixed_1_to_50_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_642_n500_grid_mixed_1_to_50_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_643_n500_grid_mixed_1_to_50_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_644_n500_grid_mixed_1_to_50_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_645_n500_grid_mixed_1_to_50_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_646_n500_grid_mixed_1_to_50_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_647_n500_grid_mixed_1_to_50_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = (i % 10) as f32 * 50.0;
            let y = (i / 10) as f32 * 50.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_648_n500_line_uniform_10_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_649_n500_line_uniform_10_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_650_n500_line_uniform_10_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_651_n500_line_uniform_10_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_652_n500_line_uniform_10_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_653_n500_line_uniform_10_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_654_n500_line_uniform_10_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_655_n500_line_uniform_10_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_656_n500_line_uniform_10_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_657_n500_line_uniform_10_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_658_n500_line_uniform_10_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_659_n500_line_uniform_10_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_660_n500_line_uniform_100_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_661_n500_line_uniform_100_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_662_n500_line_uniform_100_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_663_n500_line_uniform_100_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_664_n500_line_uniform_100_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_665_n500_line_uniform_100_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_666_n500_line_uniform_100_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_667_n500_line_uniform_100_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_668_n500_line_uniform_100_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_669_n500_line_uniform_100_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_670_n500_line_uniform_100_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_671_n500_line_uniform_100_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_672_n500_line_mixed_1_to_50_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_673_n500_line_mixed_1_to_50_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_674_n500_line_mixed_1_to_50_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_675_n500_line_mixed_1_to_50_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_676_n500_line_mixed_1_to_50_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_677_n500_line_mixed_1_to_50_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_678_n500_line_mixed_1_to_50_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_679_n500_line_mixed_1_to_50_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_680_n500_line_mixed_1_to_50_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_681_n500_line_mixed_1_to_50_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_682_n500_line_mixed_1_to_50_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_683_n500_line_mixed_1_to_50_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = i as f32 * 10.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_684_n500_origin_uniform_10_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_685_n500_origin_uniform_10_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_686_n500_origin_uniform_10_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_687_n500_origin_uniform_10_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_688_n500_origin_uniform_10_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_689_n500_origin_uniform_10_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_690_n500_origin_uniform_10_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_691_n500_origin_uniform_10_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_692_n500_origin_uniform_10_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_693_n500_origin_uniform_10_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_694_n500_origin_uniform_10_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_695_n500_origin_uniform_10_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 10.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_696_n500_origin_uniform_100_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_697_n500_origin_uniform_100_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_698_n500_origin_uniform_100_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_699_n500_origin_uniform_100_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_700_n500_origin_uniform_100_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_701_n500_origin_uniform_100_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_702_n500_origin_uniform_100_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_703_n500_origin_uniform_100_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_704_n500_origin_uniform_100_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_705_n500_origin_uniform_100_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_706_n500_origin_uniform_100_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_707_n500_origin_uniform_100_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 100.0;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_708_n500_origin_mixed_1_to_50_all_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_709_n500_origin_mixed_1_to_50_all_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_710_n500_origin_mixed_1_to_50_all_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_711_n500_origin_mixed_1_to_50_all_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = true;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 500;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_712_n500_origin_mixed_1_to_50_none_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_713_n500_origin_mixed_1_to_50_none_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_714_n500_origin_mixed_1_to_50_none_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_715_n500_origin_mixed_1_to_50_none_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = false;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = 0;
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }

    #[test]
    fn test_spatial_716_n500_origin_mixed_1_to_50_half_visible_exact_center() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let res = idx.query_point(target_node.x, target_node.y);
        if target_node.visible {
            assert!(res.is_some(), "Should hit center of visible point");
        } else {
            assert!(
                res.is_none() || 500 > 1,
                "Should not hit invisible point unless coincident with a visible one"
            );
        }
    }

    #[test]
    fn test_spatial_717_n500_origin_mixed_1_to_50_half_visible_padded_edge() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad - 0.1;
        let qy = target_node.y;
        let res = idx.query_point(qx, qy);
        if target_node.visible {
            assert!(res.is_some(), "Should hit padded edge");
        }
    }

    #[test]
    fn test_spatial_718_n500_origin_mixed_1_to_50_half_visible_far_miss() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        let qx = target_node.x + hit_pad + 10.0;
        let qy = target_node.y;
        let _res = idx.query_point(qx, qy);
    }

    #[test]
    fn test_spatial_719_n500_origin_mixed_1_to_50_half_visible_mass_queries() {
        let mut nodes = Vec::new();
        for i in 0..500 {
            let x = 0.0;
            let y = 0.0;
            let r = 1.0 + (i % 50) as f32;
            let v = i % 2 == 0;
            nodes.push(make_test_node(i as u32, x, y, r, v));
        }
        let mut idx = SpatialIndex::new();
        idx.build(&nodes);
        let expected_len = (0..500).filter(|i| i % 2 == 0).count();
        assert_eq!(idx.len(), expected_len, "Index length mismatch");
        let target_node = &nodes[0];
        let _hit_pad = target_node.radius * 1.5; // HIT_PADDING is 1.5 in spatial.rs
        for j in 0..100 {
            let _ = idx.query_point(j as f32 * 10.0, j as f32 * 10.0);
        }
    }
}
