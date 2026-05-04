use agent_core::sketch::{CountSketch, FrpBasis, SketchError, SparseJlMatrix};

fn l2_norm_squared(values: &[f32]) -> f32 {
    values.iter().map(|value| value * value).sum()
}

fn lcg_vector(seed: u64, len: usize) -> Vec<f32> {
    let mut state = seed;
    let mut out = Vec::with_capacity(len);
    for _ in 0..len {
        state = state
            .wrapping_mul(6_364_136_223_846_793_005)
            .wrapping_add(1);
        let bucket = ((state >> 32) & 0xffff) as f32 / 65_535.0;
        out.push(bucket * 2.0 - 1.0);
    }
    out
}

#[test]
fn count_sketch_recovers_heavy_item() {
    let mut sketch = CountSketch::new(128, 5, 42).unwrap();
    sketch.update(b"hot", 10.0).unwrap();
    sketch.update(b"cold", 1.0).unwrap();
    let keys: &[&[u8]] = &[b"cold", b"hot"];

    let top = sketch.top_k(keys, 1).unwrap();

    assert_eq!(top[0].0, b"hot");
    assert!(top[0].1 >= 10.0);
}

#[test]
fn count_sketch_is_seed_deterministic() {
    let mut lhs = CountSketch::new(64, 3, 7).unwrap();
    let mut rhs = CountSketch::new(64, 3, 7).unwrap();

    for (key, value) in [
        (b"a".as_slice(), 1.5),
        (b"b".as_slice(), -2.0),
        (b"a".as_slice(), 0.25),
    ] {
        lhs.update(key, value).unwrap();
        rhs.update(key, value).unwrap();
    }

    assert_eq!(lhs.buckets(), rhs.buckets());
    assert_eq!(lhs.estimate(b"a").unwrap(), rhs.estimate(b"a").unwrap());
}

#[test]
fn count_sketch_rejects_invalid_shape_and_nonfinite_update() {
    assert_eq!(
        CountSketch::new(0, 1, 1).unwrap_err(),
        SketchError::InvalidShape
    );
    assert_eq!(
        CountSketch::new(1, 0, 1).unwrap_err(),
        SketchError::InvalidShape
    );

    let mut sketch = CountSketch::new(8, 3, 1).unwrap();
    assert_eq!(
        sketch.update(b"bad", f32::NAN),
        Err(SketchError::InvalidValue)
    );
}

#[test]
fn sparse_jl_has_requested_shape_and_is_deterministic() {
    let matrix = SparseJlMatrix::new(16, 8, 2, 1).unwrap();
    let input = [1.0_f32; 8];

    let lhs = matrix.project_i8(&input).unwrap();
    let rhs = matrix.project_i8(&input).unwrap();

    assert_eq!(lhs.len(), 16);
    assert_eq!(lhs, rhs);
}

#[test]
fn sparse_jl_rejects_invalid_inputs() {
    assert_eq!(
        SparseJlMatrix::new(0, 8, 2, 1).unwrap_err(),
        SketchError::InvalidShape
    );

    let matrix = SparseJlMatrix::new(16, 8, 2, 1).unwrap();
    assert_eq!(
        matrix.project_i8(&[1.0, 2.0]),
        Err(SketchError::DimensionMismatch {
            expected: 8,
            actual: 2
        })
    );
    assert_eq!(
        matrix.project_i8(&[f32::INFINITY; 8]),
        Err(SketchError::InvalidValue)
    );
}

#[test]
fn frp_preserves_l2_norm_across_deterministic_vectors() {
    let basis = FrpBasis::new(16, 7).unwrap();

    for seed in 0..32 {
        let input = lcg_vector(seed, 16);
        let output = basis.project(&input, seed ^ 0xA5A5).unwrap();

        assert_eq!(output.len(), input.len());
        assert!(
            (l2_norm_squared(&input) - l2_norm_squared(&output)).abs() < 1.0e-4,
            "seed {seed} failed norm preservation"
        );
    }
}

#[test]
fn frp_rejects_non_power_of_two_dimension_and_bad_vectors() {
    assert_eq!(FrpBasis::new(0, 1).unwrap_err(), SketchError::InvalidShape);
    assert_eq!(FrpBasis::new(12, 1).unwrap_err(), SketchError::InvalidShape);

    let basis = FrpBasis::new(8, 1).unwrap();
    assert_eq!(
        basis.project(&[1.0, 2.0], 0),
        Err(SketchError::DimensionMismatch {
            expected: 8,
            actual: 2
        })
    );
    assert_eq!(
        basis.project(&[f32::NAN; 8], 0),
        Err(SketchError::InvalidValue)
    );
}
