use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use super::{ResourceContent, ResourceError, ResourceId, ResourceService, WriteResult};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, uniffi::Enum)]
pub enum AttachmentMode {
    Snapshot,
    Live,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, uniffi::Enum)]
pub enum Capability {
    Read,
    Write,
    Delete,
    Create,
    Search,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, uniffi::Record)]
pub struct AttachedResource {
    pub resource_id: ResourceId,
    pub display_name: String,
    pub mode: AttachmentMode,
    pub snapshot_content: Option<String>,
    pub version: Option<String>,
    pub granted_capabilities: Vec<Capability>,
}

impl AttachedResource {
    pub fn attach_via_ui(
        resource_id: ResourceId,
        display_name: impl Into<String>,
        version: Option<String>,
    ) -> Self {
        Self {
            resource_id,
            display_name: display_name.into(),
            mode: AttachmentMode::Live,
            snapshot_content: None,
            version,
            granted_capabilities: vec![Capability::Read, Capability::Write],
        }
    }

    pub fn finder_file(
        resource_id: ResourceId,
        display_name: impl Into<String>,
        version: Option<String>,
    ) -> Self {
        Self::attach_via_ui(resource_id, display_name, version)
    }

    pub fn pasted_text(
        resource_id: ResourceId,
        display_name: impl Into<String>,
        snapshot_content: impl Into<String>,
    ) -> Self {
        let snapshot_content = snapshot_content.into();
        Self {
            resource_id,
            display_name: display_name.into(),
            mode: AttachmentMode::Snapshot,
            version: Some(checksum(snapshot_content.as_bytes())),
            snapshot_content: Some(snapshot_content),
            granted_capabilities: vec![Capability::Read],
        }
    }

    pub fn allows(&self, capability: Capability) -> bool {
        self.granted_capabilities.contains(&capability)
    }

    fn denied(&self, capability: Capability) -> ResourceError {
        ResourceError::CapabilityDenied {
            resource: self.resource_id.clone(),
            capability: format!("{capability:?}").to_lowercase(),
        }
    }
}

pub async fn read_attached_resource(
    service: &dyn ResourceService,
    attachment: &AttachedResource,
) -> Result<ResourceContent, ResourceError> {
    if !attachment.allows(Capability::Read) {
        return Err(attachment.denied(Capability::Read));
    }

    match attachment.mode {
        AttachmentMode::Live => service.read(attachment.resource_id.clone()).await,
        AttachmentMode::Snapshot => {
            let snapshot = attachment
                .snapshot_content
                .clone()
                .ok_or_else(|| attachment.denied(Capability::Read))?;
            let bytes = snapshot.into_bytes();
            let checksum = checksum(&bytes);
            Ok(ResourceContent {
                id: attachment.resource_id.clone(),
                bytes,
                version: attachment
                    .version
                    .clone()
                    .unwrap_or_else(|| checksum.clone()),
                checksum,
                media_type: "text/plain".into(),
            })
        }
    }
}

pub async fn write_attached_resource(
    service: &dyn ResourceService,
    attachment: &AttachedResource,
    content: &[u8],
    base_version: Option<&str>,
) -> Result<WriteResult, ResourceError> {
    if attachment.mode == AttachmentMode::Snapshot || !attachment.allows(Capability::Write) {
        return Err(attachment.denied(Capability::Write));
    }

    service
        .write(
            attachment.resource_id.clone(),
            content.to_vec(),
            base_version.map(str::to_string),
        )
        .await
}

fn checksum(bytes: &[u8]) -> String {
    let mut digest = Sha256::new();
    digest.update(bytes);
    digest
        .finalize()
        .iter()
        .map(|byte| format!("{byte:02x}"))
        .collect()
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use tempfile::tempdir;

    use super::{
        read_attached_resource, write_attached_resource, AttachedResource, AttachmentMode,
        Capability,
    };
    use crate::resources::{
        read_note_adapter, ResourceError, ResourceId, ResourceService, VaultResourceService,
    };
    use crate::storage::vault::VaultStore;

    #[tokio::test]
    async fn attach_note_as_live_edits_real_file() {
        let temp = tempdir().unwrap();
        let note_path = temp.path().join("Inbox/Attached.md");
        std::fs::create_dir_all(note_path.parent().unwrap()).unwrap();
        std::fs::write(&note_path, "before").unwrap();

        let vault = Arc::new(VaultStore::open(temp.path().to_str().unwrap()).unwrap());
        let service = VaultResourceService::new(vault, temp.path(), "main");
        let resource_id = service.resolve("Inbox/Attached.md".into()).await.unwrap();
        let version = service.read(resource_id.clone()).await.unwrap().version;
        let attachment =
            AttachedResource::attach_via_ui(resource_id, "Attached", Some(version.clone()));

        write_attached_resource(&service, &attachment, b"after", Some(version.as_str()))
            .await
            .unwrap();

        assert_eq!(
            read_note_adapter(&service, "Attached").await.unwrap(),
            "after"
        );
        assert_eq!(std::fs::read_to_string(note_path).unwrap(), "after");
    }

    #[tokio::test]
    async fn attach_note_as_snapshot_returns_capability_denied() {
        let attachment = AttachedResource::pasted_text(
            ResourceId::VaultNote {
                vault_id: "main".into(),
                note_id: "Inbox/Snapshot.md".into(),
            },
            "Snapshot",
            "pasted body",
        );
        assert_eq!(attachment.mode, AttachmentMode::Snapshot);
        assert_eq!(attachment.granted_capabilities, vec![Capability::Read]);

        let temp = tempdir().unwrap();
        let vault = Arc::new(VaultStore::open(temp.path().to_str().unwrap()).unwrap());
        let service = VaultResourceService::new(vault, temp.path(), "main");

        let error = write_attached_resource(&service, &attachment, b"mutated", None)
            .await
            .unwrap_err();
        assert!(matches!(error, ResourceError::CapabilityDenied { .. }));
    }

    #[tokio::test]
    async fn ai_edits_attached_code_file_and_file_on_disk_changes() {
        let temp = tempdir().unwrap();
        let file_path = temp.path().join("Example.swift");
        std::fs::write(&file_path, "let answer = 41\n").unwrap();

        let vault = Arc::new(VaultStore::open(temp.path().to_str().unwrap()).unwrap());
        let service = VaultResourceService::new(vault, temp.path(), "main");
        let resource_id = ResourceId::File {
            absolute_path: file_path.to_string_lossy().to_string(),
        };
        let version = service.read(resource_id.clone()).await.unwrap().version;
        let attachment =
            AttachedResource::finder_file(resource_id, "Example.swift", Some(version.clone()));

        write_attached_resource(
            &service,
            &attachment,
            b"let answer = 42\n",
            Some(version.as_str()),
        )
        .await
        .unwrap();

        assert_eq!(
            std::fs::read_to_string(file_path).unwrap(),
            "let answer = 42\n"
        );
    }

    #[tokio::test]
    async fn attach_via_ui_defaults_to_live_read_write() {
        let attachment = AttachedResource::attach_via_ui(
            ResourceId::VaultNote {
                vault_id: "main".into(),
                note_id: "Inbox/Attached.md".into(),
            },
            "Attached",
            None,
        );

        assert_eq!(attachment.mode, AttachmentMode::Live);
        assert_eq!(
            attachment.granted_capabilities,
            vec![Capability::Read, Capability::Write]
        );
    }

    #[tokio::test]
    async fn snapshot_reads_from_inline_content() {
        let temp = tempdir().unwrap();
        let vault = Arc::new(VaultStore::open(temp.path().to_str().unwrap()).unwrap());
        let service = VaultResourceService::new(vault, temp.path(), "main");
        let attachment = AttachedResource::pasted_text(
            ResourceId::VaultNote {
                vault_id: "main".into(),
                note_id: "Inbox/Snapshot.md".into(),
            },
            "Snapshot",
            "inline body",
        );

        let content = read_attached_resource(&service, &attachment).await.unwrap();
        assert_eq!(String::from_utf8(content.bytes).unwrap(), "inline body");
    }
}
