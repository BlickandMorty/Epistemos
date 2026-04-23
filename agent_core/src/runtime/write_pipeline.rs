use std::path::Path;
use std::sync::Mutex;

use async_trait::async_trait;
use chrono::Utc;
use rusqlite::{params, Connection};

use crate::resources::{
    Capability, PermissionService, ResourceError, ResourceId, ResourceService,
};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VerifiedWrite {
    pub id: ResourceId,
    pub version: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AuditEntry {
    pub actor: String,
    pub tool: String,
    pub resource_uri: String,
    pub operation: String,
    pub before_version: Option<String>,
    pub after_version: Option<String>,
    pub approval_source: Option<String>,
    pub result: String,
    pub timestamp: String,
}

#[derive(Debug, thiserror::Error)]
pub enum WriteError {
    #[error("permission denied for {resource}: {capability}")]
    PermissionDenied {
        resource: ResourceId,
        capability: String,
    },
    #[error("version conflict for {id}: expected {expected}, actual {actual}")]
    VersionConflict {
        id: ResourceId,
        expected: String,
        actual: String,
    },
    #[error("write verification failed: expected {expected}, actual {actual}")]
    VerificationFailed { expected: String, actual: String },
    #[error("resource error: {0}")]
    Resource(String),
    #[error("audit error: {0}")]
    Audit(String),
}

#[async_trait]
pub trait ResourceAuditLog: Send + Sync {
    async fn record(&self, entry: AuditEntry) -> Result<(), WriteError>;
    async fn list(&self) -> Result<Vec<AuditEntry>, WriteError>;
}

pub struct SqliteResourceAuditLog {
    conn: Mutex<Connection>,
}

impl SqliteResourceAuditLog {
    pub fn open(path: impl AsRef<Path>) -> Result<Self, WriteError> {
        let conn = Connection::open(path).map_err(|error| WriteError::Audit(error.to_string()))?;
        Self::init_schema(&conn)?;
        Ok(Self {
            conn: Mutex::new(conn),
        })
    }

    pub fn open_in_memory() -> Result<Self, WriteError> {
        let conn = Connection::open_in_memory()
            .map_err(|error| WriteError::Audit(error.to_string()))?;
        Self::init_schema(&conn)?;
        Ok(Self {
            conn: Mutex::new(conn),
        })
    }

    fn init_schema(conn: &Connection) -> Result<(), WriteError> {
        conn.execute_batch(
            "
            CREATE TABLE IF NOT EXISTS resource_audit_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                actor TEXT NOT NULL,
                tool TEXT NOT NULL,
                resource_uri TEXT NOT NULL,
                operation TEXT NOT NULL,
                before_version TEXT,
                after_version TEXT,
                approval_source TEXT,
                result TEXT NOT NULL,
                timestamp DATETIME NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_audit_resource
                ON resource_audit_log(resource_uri, timestamp);
            ",
        )
        .map_err(|error| WriteError::Audit(error.to_string()))
    }
}

#[async_trait]
impl ResourceAuditLog for SqliteResourceAuditLog {
    async fn record(&self, entry: AuditEntry) -> Result<(), WriteError> {
        let conn = self
            .conn
            .lock()
            .map_err(|_| WriteError::Audit("audit db lock poisoned".into()))?;
        conn.execute(
            "INSERT INTO resource_audit_log
                (actor, tool, resource_uri, operation, before_version, after_version, approval_source, result, timestamp)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
            params![
                entry.actor,
                entry.tool,
                entry.resource_uri,
                entry.operation,
                entry.before_version,
                entry.after_version,
                entry.approval_source,
                entry.result,
                entry.timestamp,
            ],
        )
        .map_err(|error| WriteError::Audit(error.to_string()))?;
        Ok(())
    }

    async fn list(&self) -> Result<Vec<AuditEntry>, WriteError> {
        let conn = self
            .conn
            .lock()
            .map_err(|_| WriteError::Audit("audit db lock poisoned".into()))?;
        let mut stmt = conn
            .prepare(
                "SELECT actor, tool, resource_uri, operation, before_version, after_version, approval_source, result, timestamp
                 FROM resource_audit_log
                 ORDER BY id ASC",
            )
            .map_err(|error| WriteError::Audit(error.to_string()))?;
        let rows = stmt
            .query_map([], |row| {
                Ok(AuditEntry {
                    actor: row.get(0)?,
                    tool: row.get(1)?,
                    resource_uri: row.get(2)?,
                    operation: row.get(3)?,
                    before_version: row.get(4)?,
                    after_version: row.get(5)?,
                    approval_source: row.get(6)?,
                    result: row.get(7)?,
                    timestamp: row.get(8)?,
                })
            })
            .map_err(|error| WriteError::Audit(error.to_string()))?;
        Ok(rows.filter_map(Result::ok).collect())
    }
}

pub async fn verified_write(
    service: &dyn ResourceService,
    permissions: &dyn PermissionService,
    audit_log: &dyn ResourceAuditLog,
    id: &ResourceId,
    content: &[u8],
    base_version: Option<&str>,
    tool_name: &str,
    approval_source: Option<&str>,
) -> Result<VerifiedWrite, WriteError> {
    let before_version = base_version.map(str::to_string);
    let permission_allowed = permissions.check(id.clone(), Capability::Write).await;
    if !permission_allowed {
        let error = WriteError::PermissionDenied {
            resource: id.clone(),
            capability: "write".into(),
        };
        record_result(
            audit_log,
            id,
            tool_name,
            before_version,
            None,
            approval_source,
            "capability_denied",
        )
        .await?;
        return Err(error);
    }

    let write_result = match service
        .write(id.clone(), content.to_vec(), base_version.map(str::to_string))
        .await
    {
        Ok(result) => result,
        Err(ResourceError::VersionConflict {
            id,
            expected,
            actual,
        }) => {
            record_result(
                audit_log,
                &id,
                tool_name,
                before_version,
                None,
                approval_source,
                "version_conflict",
            )
            .await?;
            return Err(WriteError::VersionConflict {
                id,
                expected,
                actual,
            });
        }
        Err(error) => {
            record_result(
                audit_log,
                id,
                tool_name,
                before_version,
                None,
                approval_source,
                "error",
            )
            .await?;
            return Err(WriteError::Resource(error.to_string()));
        }
    };

    let readback = service
        .read(id.clone())
        .await
        .map_err(|error| WriteError::Resource(error.to_string()))?;
    if readback.checksum != write_result.post_checksum {
        record_result(
            audit_log,
            id,
            tool_name,
            before_version,
            Some(write_result.new_version.clone()),
            approval_source,
            "verification_failed",
        )
        .await?;
        return Err(WriteError::VerificationFailed {
            expected: write_result.post_checksum,
            actual: readback.checksum,
        });
    }

    record_result(
        audit_log,
        id,
        tool_name,
        before_version,
        Some(write_result.new_version.clone()),
        approval_source,
        "success",
    )
    .await?;

    Ok(VerifiedWrite {
        id: id.clone(),
        version: write_result.new_version,
    })
}

async fn record_result(
    audit_log: &dyn ResourceAuditLog,
    id: &ResourceId,
    tool_name: &str,
    before_version: Option<String>,
    after_version: Option<String>,
    approval_source: Option<&str>,
    result: &str,
) -> Result<(), WriteError> {
    audit_log
        .record(AuditEntry {
            actor: "assistant".into(),
            tool: tool_name.to_string(),
            resource_uri: id.as_uri(),
            operation: "write".into(),
            before_version,
            after_version,
            approval_source: approval_source.map(str::to_string),
            result: result.to_string(),
            timestamp: Utc::now().to_rfc3339(),
        })
        .await
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;
    use std::sync::{Arc, Mutex};

    use async_trait::async_trait;

    use super::{verified_write, ResourceAuditLog, SqliteResourceAuditLog, WriteError};
    use crate::resources::{
        Capability, GrantScope, PermissionGrant, PermissionService, ResourceContent,
        ResourceError, ResourceHit, ResourceId, ResourceSelector, ResourceService,
        SearchScope, SqlitePermissionService, WriteResult,
    };

    struct MockResourceService {
        path: PathBuf,
        current: Mutex<Vec<u8>>,
        readback: Mutex<Vec<u8>>,
    }

    impl MockResourceService {
        fn new(path: PathBuf, current: &[u8], readback: &[u8]) -> Self {
            Self {
                path,
                current: Mutex::new(current.to_vec()),
                readback: Mutex::new(readback.to_vec()),
            }
        }
    }

    #[async_trait]
    impl ResourceService for MockResourceService {
        async fn resolve(&self, _ref_: String) -> Result<ResourceId, ResourceError> {
            Ok(ResourceId::File {
                absolute_path: self.path.to_string_lossy().to_string(),
            })
        }

        async fn search(
            &self,
            _query: String,
            _scope: SearchScope,
        ) -> Result<Vec<ResourceHit>, ResourceError> {
            Ok(Vec::new())
        }

        async fn read(&self, id: ResourceId) -> Result<ResourceContent, ResourceError> {
            let bytes = self.readback.lock().unwrap().clone();
            let checksum = checksum(&bytes);
            Ok(ResourceContent {
                id,
                bytes,
                version: checksum.clone(),
                checksum,
                media_type: "text/plain".into(),
            })
        }

        async fn write(
            &self,
            id: ResourceId,
            content: Vec<u8>,
            _base_version: Option<String>,
        ) -> Result<WriteResult, ResourceError> {
            *self.current.lock().unwrap() = content.clone();
            let checksum = checksum(&content);
            Ok(WriteResult {
                id,
                new_version: checksum.clone(),
                post_checksum: checksum,
            })
        }

        async fn create(
            &self,
            _parent: ResourceId,
            _kind: crate::resources::ResourceKind,
            _content: Vec<u8>,
        ) -> Result<ResourceId, ResourceError> {
            Err(ResourceError::UnsupportedReference("create not used in tests".into()))
        }

        async fn delete(
            &self,
            _id: ResourceId,
            _mode: crate::resources::DeleteMode,
        ) -> Result<(), ResourceError> {
            Err(ResourceError::UnsupportedReference("delete not used in tests".into()))
        }
    }

    #[tokio::test]
    async fn write_without_readback_is_treated_as_error() {
        let path = PathBuf::from("/tmp/vault_graph.json");
        let service = MockResourceService::new(path.clone(), br#"{"a":1}"#, br#"{"b":2}"#);
        let permissions = SqlitePermissionService::open_in_memory().unwrap();
        let resource = ResourceId::File {
            absolute_path: path.to_string_lossy().to_string(),
        };
        permissions
            .grant(PermissionGrant::new(
                GrantScope::Session,
                ResourceSelector::ById(resource.clone()),
                vec![Capability::Write],
            ))
            .await
            .unwrap();
        let audit = SqliteResourceAuditLog::open_in_memory().unwrap();

        let error = verified_write(
            &service,
            &permissions,
            &audit,
            &resource,
            br#"{"updated":true}"#,
            None,
            "note_write",
            Some("grant-1"),
        )
        .await
        .unwrap_err();

        assert!(matches!(error, WriteError::VerificationFailed { .. }));
        let entries = audit.list().await.unwrap();
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].result, "verification_failed");
    }

    #[tokio::test]
    async fn write_with_stale_base_version_returns_version_conflict() {
        let temp = tempfile::tempdir().unwrap();
        let note_path = temp.path().join("Inbox/Stale.md");
        std::fs::create_dir_all(note_path.parent().unwrap()).unwrap();
        std::fs::write(&note_path, "fresh").unwrap();

        let vault = Arc::new(crate::storage::vault::VaultStore::open(
            temp.path().to_str().unwrap(),
        )
        .unwrap());
        let service = crate::resources::VaultResourceService::new(vault, temp.path(), "main");
        let resource = service.resolve("Inbox/Stale.md".into()).await.unwrap();
        let current_version = service.read(resource.clone()).await.unwrap().version;

        let permissions = SqlitePermissionService::open_in_memory().unwrap();
        permissions
            .grant(PermissionGrant::new(
                GrantScope::Session,
                ResourceSelector::ById(resource.clone()),
                vec![Capability::Write],
            ))
            .await
            .unwrap();
        let audit = SqliteResourceAuditLog::open_in_memory().unwrap();

        let error = verified_write(
            &service,
            &permissions,
            &audit,
            &resource,
            b"updated",
            Some("stale-version"),
            "note_write",
            Some("grant-2"),
        )
        .await
        .unwrap_err();

        assert!(matches!(error, WriteError::VersionConflict { .. }));
        let entries = audit.list().await.unwrap();
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].result, "version_conflict");
        assert_eq!(current_version, service.read(resource).await.unwrap().version);
    }

    fn checksum(bytes: &[u8]) -> String {
        use sha2::{Digest, Sha256};

        let mut digest = Sha256::new();
        digest.update(bytes);
        digest
            .finalize()
            .iter()
            .map(|byte| format!("{byte:02x}"))
            .collect()
    }
}
