//! IOSurface/shared arena descriptor layer.

/// Descriptor for a platform IOSurface bridge.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct IoSurfaceDescriptor {
    pub width: u32,
    pub height: u32,
    pub bytes_per_row: u32,
    pub pixel_format: u32,
}

/// Shared CloudArena / GPU arena metadata.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SharedArena {
    pub name: String,
    pub byte_len: usize,
    pub app_group_identifier: String,
}

impl SharedArena {
    #[must_use]
    pub fn new(name: impl Into<String>, byte_len: usize, app_group_identifier: impl Into<String>) -> Self {
        Self { name: name.into(), byte_len, app_group_identifier: app_group_identifier.into() }
    }
}
