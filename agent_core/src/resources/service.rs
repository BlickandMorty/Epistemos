use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use walkdir::WalkDir;

use crate::storage::vault::VaultBackend;

use super::{AliasRegistry, ResourceId};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, uniffi::Enum)]
pub enum ResourceSearchScope {
    ActiveVault,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, uniffi::Enum)]
pub enum ResourceKind {
    Note { name: String },
    Folder { name: String },
    File { name: String },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, uniffi::Enum)]
pub enum DeleteMode {
    Trash,
    Hard,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, uniffi::Record)]
pub struct ResourceContent {
    pub id: ResourceId,
    pub bytes: Vec<u8>,
    pub version: String,
    pub checksum: String,
    pub media_type: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, uniffi::Record)]
pub struct WriteResult {
    pub id: ResourceId,
    pub new_version: String,
    pub post_checksum: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, uniffi::Record)]
pub struct ResourceHit {
    pub id: ResourceId,
    pub title: String,
    pub excerpt: String,
    pub aliases: Vec<String>,
    pub score: f64,
}

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error, uniffi::Error)]
pub enum ResourceError {
    #[error("resource not found: {0}")]
    NotFound(String),
    #[error("unsupported resource reference: {0}")]
    UnsupportedReference(String),
    #[error("unsupported resource id: {0}")]
    UnsupportedId(String),
    #[error("capability denied for {resource}: {capability}")]
    CapabilityDenied {
        resource: ResourceId,
        capability: String,
    },
    #[error("version conflict for {id}: expected {expected}, actual {actual}")]
    VersionConflict {
        id: ResourceId,
        expected: String,
        actual: String,
    },
    #[error("invalid parent resource: {0}")]
    InvalidParent(String),
    #[error("invalid content: {0}")]
    InvalidContent(String),
    #[error("backend error: {0}")]
    Backend(String),
}

#[async_trait]
pub trait ResourceService: Send + Sync {
    async fn resolve(&self, ref_: String) -> Result<ResourceId, ResourceError>;
    async fn search(
        &self,
        query: String,
        scope: ResourceSearchScope,
    ) -> Result<Vec<ResourceHit>, ResourceError>;
    async fn read(&self, id: ResourceId) -> Result<ResourceContent, ResourceError>;
    async fn write(
        &self,
        id: ResourceId,
        content: Vec<u8>,
        base_version: Option<String>,
    ) -> Result<WriteResult, ResourceError>;
    async fn create(
        &self,
        parent: ResourceId,
        kind: ResourceKind,
        content: Vec<u8>,
    ) -> Result<ResourceId, ResourceError>;
    async fn delete(&self, id: ResourceId, mode: DeleteMode) -> Result<(), ResourceError>;
}

pub struct VaultResourceService {
    vault: Arc<dyn VaultBackend>,
    vault_root: PathBuf,
    vault_id: String,
    aliases: Mutex<AliasRegistry>,
    scanned: Mutex<bool>,
}

impl VaultResourceService {
    pub fn new(
        vault: Arc<dyn VaultBackend>,
        vault_root: impl Into<PathBuf>,
        vault_id: impl Into<String>,
    ) -> Self {
        Self {
            vault,
            vault_root: vault_root.into(),
            vault_id: vault_id.into(),
            aliases: Mutex::new(AliasRegistry::new()),
            scanned: Mutex::new(false),
        }
    }

    fn ensure_vault_aliases_loaded(&self) -> Result<(), ResourceError> {
        let mut scanned = self
            .scanned
            .lock()
            .map_err(|_| ResourceError::Backend("alias scan lock poisoned".into()))?;
        if *scanned {
            return Ok(());
        }

        let mut aliases = self
            .aliases
            .lock()
            .map_err(|_| ResourceError::Backend("alias registry lock poisoned".into()))?;
        for entry in WalkDir::new(&self.vault_root)
            .into_iter()
            .filter_map(Result::ok)
            .filter(|entry| entry.file_type().is_file())
        {
            let path = entry.path();
            if path.extension().and_then(|ext| ext.to_str()) != Some("md") {
                continue;
            }
            if let Ok(relative) = path.strip_prefix(&self.vault_root) {
                if relative.components().any(|component| {
                    component
                        .as_os_str()
                        .to_string_lossy()
                        .starts_with('.')
                }) {
                    continue;
                }
                self.register_note_aliases(&mut aliases, relative);
            }
        }

        *scanned = true;
        Ok(())
    }

    fn register_note_aliases(&self, aliases: &mut AliasRegistry, relative_path: &Path) {
        let relative = normalize_relative(relative_path);
        let canonical = self.canonical_note_id(&relative);
        let absolute = self.vault_root.join(relative_path);
        let title = relative_path
            .file_stem()
            .map(|stem| stem.to_string_lossy().to_string())
            .unwrap_or_else(|| relative.clone());

        aliases.register_all(
            [
                canonical.as_uri(),
                relative.clone(),
                title,
                format!("file://{}", absolute.to_string_lossy()),
            ],
            canonical,
        );
    }

    fn canonical_note_id(&self, relative_path: &str) -> ResourceId {
        ResourceId::VaultNote {
            vault_id: self.vault_id.clone(),
            note_id: relative_path.to_string(),
        }
    }

    fn absolute_path_for_id(&self, id: &ResourceId) -> Result<PathBuf, ResourceError> {
        match id {
            ResourceId::VaultNote { note_id, .. } => Ok(self.vault_root.join(note_id)),
            ResourceId::File { absolute_path } => Ok(PathBuf::from(absolute_path)),
            other => Err(ResourceError::UnsupportedId(other.to_string())),
        }
    }

    fn canonicalize_id(&self, id: ResourceId) -> Result<ResourceId, ResourceError> {
        match id {
            ResourceId::VaultNote { vault_id, note_id } => Ok(ResourceId::VaultNote {
                vault_id,
                note_id: normalize_relative(Path::new(&note_id)),
            }),
            ResourceId::File { absolute_path } => {
                let absolute = PathBuf::from(&absolute_path);
                if let Ok(relative) = absolute.strip_prefix(&self.vault_root) {
                    if absolute.extension().and_then(|ext| ext.to_str()) == Some("md") {
                        return Ok(self.canonical_note_id(&normalize_relative(relative)));
                    }
                }
                Ok(ResourceId::File { absolute_path })
            }
            other => Ok(other),
        }
    }

    fn maybe_resolve_path_reference(&self, reference: &str) -> Option<ResourceId> {
        let trimmed = reference.trim();
        if trimmed.is_empty() {
            return None;
        }

        let path = Path::new(trimmed);
        if path.is_absolute() {
            let absolute = PathBuf::from(trimmed);
            if let Ok(relative) = absolute.strip_prefix(&self.vault_root) {
                if absolute.extension().and_then(|ext| ext.to_str()) == Some("md") {
                    return Some(self.canonical_note_id(&normalize_relative(relative)));
                }
            }
            return Some(ResourceId::File {
                absolute_path: absolute.to_string_lossy().to_string(),
            });
        }

        let candidate = self.vault_root.join(trimmed);
        if candidate.exists() && candidate.extension().and_then(|ext| ext.to_str()) == Some("md") {
            return Some(self.canonical_note_id(trimmed));
        }

        None
    }

    fn ensure_parent_directory(&self, parent: &Path) -> Result<(), ResourceError> {
        std::fs::create_dir_all(parent)
            .map_err(|error| ResourceError::Backend(error.to_string()))
    }

    fn fallback_search_hits(&self, query: &str) -> Result<Vec<ResourceHit>, ResourceError> {
        let normalized_query = query.trim().to_lowercase();
        if normalized_query.is_empty() {
            return Ok(Vec::new());
        }

        self.ensure_vault_aliases_loaded()?;
        let aliases = self
            .aliases
            .lock()
            .map_err(|_| ResourceError::Backend("alias registry lock poisoned".into()))?;
        let mut hits = Vec::new();

        for entry in WalkDir::new(&self.vault_root)
            .into_iter()
            .filter_map(Result::ok)
            .filter(|entry| entry.file_type().is_file())
        {
            let path = entry.path();
            if path.extension().and_then(|ext| ext.to_str()) != Some("md") {
                continue;
            }
            let Ok(relative) = path.strip_prefix(&self.vault_root) else {
                continue;
            };
            if relative.components().any(|component| {
                component
                    .as_os_str()
                    .to_string_lossy()
                    .starts_with('.')
            }) {
                continue;
            }

            let title = path
                .file_stem()
                .map(|stem| stem.to_string_lossy().to_string())
                .unwrap_or_else(|| normalize_relative(relative));
            let content = std::fs::read_to_string(path).unwrap_or_default();
            let normalized_content = content.to_lowercase();
            let normalized_title = title.to_lowercase();
            if !normalized_title.contains(&normalized_query)
                && !normalized_content.contains(&normalized_query)
            {
                continue;
            }

            let id = self.canonical_note_id(&normalize_relative(relative));
            hits.push(ResourceHit {
                aliases: aliases.aliases_for(&id),
                id,
                title,
                excerpt: content.chars().take(240).collect(),
                score: 0.5,
            });
        }

        Ok(hits)
    }
}

#[async_trait]
impl ResourceService for VaultResourceService {
    async fn resolve(&self, ref_: String) -> Result<ResourceId, ResourceError> {
        let trimmed = ref_.trim();
        if trimmed.is_empty() {
            return Err(ResourceError::UnsupportedReference(ref_));
        }

        if let Ok(id) = ResourceId::parse(trimmed) {
            return self.canonicalize_id(id);
        }

        if let Some(id) = self.maybe_resolve_path_reference(trimmed) {
            return Ok(id);
        }

        self.ensure_vault_aliases_loaded()?;
        let aliases = self
            .aliases
            .lock()
            .map_err(|_| ResourceError::Backend("alias registry lock poisoned".into()))?;
        aliases
            .resolve(trimmed)
            .ok_or_else(|| ResourceError::UnsupportedReference(trimmed.to_string()))
    }

    async fn search(
        &self,
        query: String,
        scope: ResourceSearchScope,
    ) -> Result<Vec<ResourceHit>, ResourceError> {
        let ResourceSearchScope::ActiveVault = scope;
        self.ensure_vault_aliases_loaded()?;
        let results = self
            .vault
            .hybrid_search(&query, 12, &[])
            .await
            .map_err(|error| ResourceError::Backend(error.to_string()))?;

        let hits = {
            let aliases = self
                .aliases
                .lock()
                .map_err(|_| ResourceError::Backend("alias registry lock poisoned".into()))?;

            results
                .into_iter()
                .map(|result| {
                    let id = self.canonical_note_id(&result.path);
                    let title = Path::new(&result.path)
                        .file_stem()
                        .map(|stem| stem.to_string_lossy().to_string())
                        .unwrap_or_else(|| result.path.clone());
                    ResourceHit {
                        aliases: aliases.aliases_for(&id),
                        id,
                        title,
                        excerpt: result.excerpt,
                        score: result.score,
                    }
                })
                .collect::<Vec<_>>()
        };

        if hits.is_empty() {
            self.fallback_search_hits(&query)
        } else {
            Ok(hits)
        }
    }

    async fn read(&self, id: ResourceId) -> Result<ResourceContent, ResourceError> {
        let canonical = self.canonicalize_id(id)?;
        match &canonical {
            ResourceId::VaultNote { note_id, .. } => {
                let text = self
                    .vault
                    .read(note_id)
                    .await
                    .map_err(map_vault_error)?;
                let bytes = text.into_bytes();
                let checksum = checksum(&bytes);
                Ok(ResourceContent {
                    id: canonical,
                    bytes,
                    version: checksum.clone(),
                    checksum,
                    media_type: "text/markdown".into(),
                })
            }
            ResourceId::File { absolute_path } => {
                let bytes = std::fs::read(absolute_path)
                    .map_err(|error| ResourceError::Backend(error.to_string()))?;
                let checksum = checksum(&bytes);
                let media_type = infer_media_type(absolute_path);
                Ok(ResourceContent {
                    id: canonical.clone(),
                    bytes,
                    version: checksum.clone(),
                    checksum,
                    media_type,
                })
            }
            other => Err(ResourceError::UnsupportedId(other.to_string())),
        }
    }

    async fn write(
        &self,
        id: ResourceId,
        content: Vec<u8>,
        base_version: Option<String>,
    ) -> Result<WriteResult, ResourceError> {
        let canonical = self.canonicalize_id(id)?;
        let current_version = match self.read(canonical.clone()).await {
            Ok(current) => Some(current.version),
            Err(ResourceError::NotFound(_)) => None,
            Err(error) => return Err(error),
        };

        if let Some(expected) = base_version {
            let actual = current_version.unwrap_or_default();
            if expected != actual {
                return Err(ResourceError::VersionConflict {
                    id: canonical,
                    expected,
                    actual,
                });
            }
        }

        match &canonical {
            ResourceId::VaultNote { note_id, .. } => {
                let text = String::from_utf8(content)
                    .map_err(|error| ResourceError::InvalidContent(error.to_string()))?;
                self.vault
                    .write(note_id, &text, None, false)
                    .await
                    .map_err(map_vault_error)?;
            }
            ResourceId::File { absolute_path } => {
                let path = PathBuf::from(absolute_path);
                if let Some(parent) = path.parent() {
                    self.ensure_parent_directory(parent)?;
                }
                std::fs::write(&path, &content)
                    .map_err(|error| ResourceError::Backend(error.to_string()))?;
            }
            other => return Err(ResourceError::UnsupportedId(other.to_string())),
        }

        let readback = self.read(canonical.clone()).await?;
        Ok(WriteResult {
            id: canonical,
            new_version: readback.version.clone(),
            post_checksum: readback.checksum,
        })
    }

    async fn create(
        &self,
        parent: ResourceId,
        kind: ResourceKind,
        content: Vec<u8>,
    ) -> Result<ResourceId, ResourceError> {
        let parent_path = match self.absolute_path_for_id(&self.canonicalize_id(parent)?)? {
            path if path.is_dir() => path,
            path => path
                .parent()
                .map(Path::to_path_buf)
                .ok_or_else(|| ResourceError::InvalidParent(path.to_string_lossy().to_string()))?,
        };
        self.ensure_parent_directory(&parent_path)?;

        match kind {
            ResourceKind::Folder { name } => {
                let directory = parent_path.join(sanitize_name(&name));
                std::fs::create_dir_all(&directory)
                    .map_err(|error| ResourceError::Backend(error.to_string()))?;
                Ok(ResourceId::File {
                    absolute_path: directory.to_string_lossy().to_string(),
                })
            }
            ResourceKind::Note { name } => {
                let file_name = ensure_extension(&sanitize_name(&name), "md");
                let path = parent_path.join(file_name);
                if let Ok(relative) = path.strip_prefix(&self.vault_root) {
                    let canonical = self.canonical_note_id(&normalize_relative(relative));
                    self.write(canonical.clone(), content, None).await?;
                    Ok(canonical)
                } else {
                    std::fs::write(&path, &content)
                        .map_err(|error| ResourceError::Backend(error.to_string()))?;
                    self.resolve(format!("file://{}", path.to_string_lossy())).await
                }
            }
            ResourceKind::File { name } => {
                let path = parent_path.join(sanitize_name(&name));
                std::fs::write(&path, &content)
                    .map_err(|error| ResourceError::Backend(error.to_string()))?;
                Ok(ResourceId::File {
                    absolute_path: path.to_string_lossy().to_string(),
                })
            }
        }
    }

    async fn delete(&self, id: ResourceId, mode: DeleteMode) -> Result<(), ResourceError> {
        let canonical = self.canonicalize_id(id)?;
        let path = self.absolute_path_for_id(&canonical)?;
        if !path.exists() {
            return Err(ResourceError::NotFound(path.to_string_lossy().to_string()));
        }

        match mode {
            DeleteMode::Hard => {
                std::fs::remove_file(&path)
                    .map_err(|error| ResourceError::Backend(error.to_string()))?;
            }
            DeleteMode::Trash => {
                let relative = path
                    .strip_prefix(&self.vault_root)
                    .unwrap_or(path.as_path());
                let trash_target = self
                    .vault_root
                    .join(".trash")
                    .join(relative);
                if let Some(parent) = trash_target.parent() {
                    self.ensure_parent_directory(parent)?;
                }
                std::fs::rename(&path, &trash_target)
                    .map_err(|error| ResourceError::Backend(error.to_string()))?;
            }
        }

        Ok(())
    }
}

pub async fn read_note_adapter(
    service: &dyn ResourceService,
    reference: &str,
) -> Result<String, ResourceError> {
    let id = service.resolve(reference.to_string()).await?;
    let content = service.read(id).await?;
    String::from_utf8(content.bytes)
        .map_err(|error| ResourceError::InvalidContent(error.to_string()))
}

pub async fn write_note_adapter(
    service: &dyn ResourceService,
    reference: &str,
    content: &str,
    base_version: Option<&str>,
) -> Result<WriteResult, ResourceError> {
    let id = service.resolve(reference.to_string()).await?;
    service
        .write(
            id,
            content.as_bytes().to_vec(),
            base_version.map(str::to_string),
        )
        .await
}

pub async fn find_note_adapter(
    service: &dyn ResourceService,
    query: &str,
) -> Result<Vec<ResourceHit>, ResourceError> {
    service.search(query.to_string(), ResourceSearchScope::ActiveVault).await
}

pub async fn create_note_adapter(
    service: &dyn ResourceService,
    parent_reference: &str,
    name: &str,
    content: &str,
) -> Result<ResourceId, ResourceError> {
    let parent = service.resolve(parent_reference.to_string()).await?;
    service
        .create(
            parent,
            ResourceKind::Note {
                name: name.to_string(),
            },
            content.as_bytes().to_vec(),
        )
        .await
}

pub async fn delete_note_adapter(
    service: &dyn ResourceService,
    reference: &str,
    mode: DeleteMode,
) -> Result<(), ResourceError> {
    let id = service.resolve(reference.to_string()).await?;
    service.delete(id, mode).await
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

fn normalize_relative(path: &Path) -> String {
    path.components()
        .filter_map(|component| {
            let text = component.as_os_str().to_string_lossy();
            if text.is_empty() || text == "." {
                None
            } else {
                Some(text.to_string())
            }
        })
        .collect::<Vec<_>>()
        .join("/")
}

fn sanitize_name(name: &str) -> String {
    let trimmed = name.trim();
    let fallback = if trimmed.is_empty() { "untitled" } else { trimmed };
    fallback.replace('/', "-").replace(':', "-")
}

fn ensure_extension(name: &str, ext: &str) -> String {
    if Path::new(name).extension().is_some() {
        name.to_string()
    } else {
        format!("{name}.{ext}")
    }
}

fn infer_media_type(path: &str) -> String {
    match Path::new(path).extension().and_then(|ext| ext.to_str()) {
        Some("md") => "text/markdown".into(),
        Some("json") => "application/json".into(),
        Some("swift") => "text/x-swift".into(),
        Some("rs") => "text/rust".into(),
        Some("txt") => "text/plain".into(),
        _ => "application/octet-stream".into(),
    }
}

fn map_vault_error(error: crate::storage::vault::VaultError) -> ResourceError {
    match error {
        crate::storage::vault::VaultError::NotFound(path) => ResourceError::NotFound(path),
        other => ResourceError::Backend(other.to_string()),
    }
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use tempfile::tempdir;

    use super::{
        create_note_adapter, delete_note_adapter, find_note_adapter, read_note_adapter,
        write_note_adapter, DeleteMode, ResourceService, ResourceSearchScope, VaultResourceService,
    };
    use crate::resources::ResourceId;
    use crate::storage::vault::VaultStore;

    #[tokio::test]
    async fn same_note_by_title_or_path_or_id_resolves_to_same_canonical() {
        let temp = tempdir().unwrap();
        let note_path = temp.path().join("Notes/Daily Note.md");
        std::fs::create_dir_all(note_path.parent().unwrap()).unwrap();
        std::fs::write(&note_path, "# Daily\n").unwrap();

        let vault = Arc::new(VaultStore::open(temp.path().to_str().unwrap()).unwrap());
        let service = VaultResourceService::new(vault, temp.path(), "main");

        let by_title = service.resolve("Daily Note".into()).await.unwrap();
        let by_path = service.resolve("Notes/Daily Note.md".into()).await.unwrap();
        let by_id = service
            .resolve("vault://main/note/Notes/Daily Note.md".into())
            .await
            .unwrap();

        let expected = ResourceId::VaultNote {
            vault_id: "main".into(),
            note_id: "Notes/Daily Note.md".into(),
        };
        assert_eq!(by_title, expected);
        assert_eq!(by_path, expected);
        assert_eq!(by_id, expected);
    }

    #[tokio::test]
    async fn ui_history_and_tool_layer_show_same_updated_note_after_edit() {
        let temp = tempdir().unwrap();
        let note_path = temp.path().join("Inbox/Shared.md");
        std::fs::create_dir_all(note_path.parent().unwrap()).unwrap();
        std::fs::write(&note_path, "before").unwrap();

        let vault = Arc::new(VaultStore::open(temp.path().to_str().unwrap()).unwrap());
        let service = VaultResourceService::new(vault, temp.path(), "main");

        let before = read_note_adapter(&service, "Shared").await.unwrap();
        assert_eq!(before, "before");

        let base_version = service
            .read(
                service
                    .resolve("Inbox/Shared.md".into())
                    .await
                    .unwrap(),
            )
            .await
            .unwrap()
            .version;
        write_note_adapter(
            &service,
            "Inbox/Shared.md",
            "after",
            Some(base_version.as_str()),
        )
        .await
        .unwrap();

        let history = read_note_adapter(&service, "Shared").await.unwrap();
        let search_hits = find_note_adapter(&service, "after").await.unwrap();

        assert_eq!(history, "after");
        assert_eq!(search_hits.len(), 1);
        assert_eq!(
            search_hits[0].id,
            ResourceId::VaultNote {
                vault_id: "main".into(),
                note_id: "Inbox/Shared.md".into(),
            }
        );
    }

    #[tokio::test]
    async fn legacy_note_adapters_route_through_resource_service() {
        let temp = tempdir().unwrap();
        let vault_root = temp.path();
        std::fs::create_dir_all(vault_root.join("Inbox")).unwrap();
        std::fs::write(vault_root.join("Inbox/Start.md"), "seed").unwrap();

        let vault = Arc::new(VaultStore::open(vault_root.to_str().unwrap()).unwrap());
        let service = VaultResourceService::new(vault, vault_root, "main");

        let created = create_note_adapter(&service, "Inbox/Start.md", "Created", "hello")
            .await
            .unwrap();
        assert_eq!(
            created,
            ResourceId::VaultNote {
                vault_id: "main".into(),
                note_id: "Inbox/Created.md".into(),
            }
        );

        let found = find_note_adapter(&service, "hello").await.unwrap();
        assert_eq!(found.len(), 1);
        assert_eq!(read_note_adapter(&service, "Created").await.unwrap(), "hello");

        delete_note_adapter(&service, "Created", DeleteMode::Trash)
            .await
            .unwrap();
        assert!(vault_root.join(".trash/Inbox/Created.md").exists());
    }

    #[tokio::test]
    async fn search_scope_active_vault_returns_hits() {
        let temp = tempdir().unwrap();
        std::fs::write(temp.path().join("Alpha.md"), "alpha beta gamma").unwrap();

        let vault = Arc::new(VaultStore::open(temp.path().to_str().unwrap()).unwrap());
        let service = VaultResourceService::new(vault, temp.path(), "main");

        let hits = service
            .search("beta".into(), ResourceSearchScope::ActiveVault)
            .await
            .unwrap();
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].title, "Alpha");
    }
}
