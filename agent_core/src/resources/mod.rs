pub mod alias_registry;
pub mod id;
pub mod service;

pub use alias_registry::AliasRegistry;
pub use id::{IdError, ResourceId};
pub use service::{
    create_note_adapter, delete_note_adapter, find_note_adapter, read_note_adapter,
    write_note_adapter, DeleteMode, ResourceContent, ResourceError, ResourceHit,
    ResourceKind, ResourceService, SearchScope, VaultResourceService, WriteResult,
};
