//! Small tensor view layer used before binding MLX arrays.

/// Borrowed tensor view metadata.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct TensorView<'a> {
    pub data: &'a [f32],
    pub rows: usize,
    pub cols: usize,
}

impl<'a> TensorView<'a> {
    pub fn new(data: &'a [f32], rows: usize, cols: usize) -> Result<Self, TensorViewError> {
        if rows.checked_mul(cols) != Some(data.len()) {
            return Err(TensorViewError::ShapeMismatch);
        }
        Ok(Self { data, rows, cols })
    }

    #[must_use]
    pub fn row(self, idx: usize) -> Option<&'a [f32]> {
        if idx >= self.rows {
            return None;
        }
        let start = idx * self.cols;
        Some(&self.data[start..start + self.cols])
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum TensorViewError {
    ShapeMismatch,
}

#[cfg(test)]
mod tests {
    use super::TensorView;

    #[test]
    fn rows_slice_correctly() {
        let view = TensorView::new(&[1.0, 2.0, 3.0, 4.0], 2, 2).unwrap();
        assert_eq!(view.row(1).unwrap(), &[3.0, 4.0]);
    }
}
