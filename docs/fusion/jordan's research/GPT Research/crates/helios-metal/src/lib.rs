//! Metal direct-path scaffold. Platform APIs are feature-gated in the future;
//! this crate provides deterministic metadata and page allocation now.

pub mod iosurface;
pub mod pages;
pub mod residency;

pub use iosurface::{IoSurfaceDescriptor, SharedArena};
pub use pages::{PageAllocator, PageHandle};
pub use residency::{ResidencyClass, ResidencyPlan};
