pub mod attachments;
pub mod alias_registry;
pub mod bridge;
pub mod id;
pub mod permissions;
pub mod service;

pub use attachments::{
    read_attached_resource, write_attached_resource, AttachedResource, AttachmentMode,
    Capability,
};
pub use alias_registry::{canonical_model_id, expand_model_aliases, AliasRegistry};
pub use id::{IdError, ResourceId};
pub use permissions::{
    always_requires_per_call_approval, GrantScope, PermissionError, PermissionGrant,
    PermissionService, ResourceSelector, ResourceSelectorKind, SqlitePermissionService,
};
pub use service::{
    create_note_adapter, delete_note_adapter, find_note_adapter, read_note_adapter,
    write_note_adapter, DeleteMode, ResourceContent, ResourceError, ResourceHit,
    ResourceKind, ResourceService, ResourceSearchScope, VaultResourceService, WriteResult,
};
