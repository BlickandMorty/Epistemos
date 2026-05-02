use std::collections::HashMap;
use std::os::raw::{c_char, c_int};
use std::ptr;
use std::sync::OnceLock;

use petgraph::stable_graph::StableDiGraph;
use petgraph::visit::{EdgeRef, IntoEdgeReferences};
use rusqlite::ffi::{
    sqlite3, sqlite3_api_routines, sqlite3_auto_extension, sqlite3_free, SQLITE_OK,
};
use rusqlite::Connection;

const MAX_VEC_DIMENSIONS: u32 = 4096;

static SQLITE_VEC_REGISTRATION: OnceLock<Result<(), String>> = OnceLock::new();

type SqliteVecInitSymbol = unsafe extern "C" fn();
type SqliteVecInitEntry = unsafe extern "C" fn(
    db: *mut sqlite3,
    pz_err_msg: *mut *mut c_char,
    p_api: *const sqlite3_api_routines,
) -> c_int;

fn sqlite_vec_init_entry() -> SqliteVecInitEntry {
    // SAFETY: sqlite-vec 0.1.9 declares sqlite3_vec_init as a no-arg Rust FFI
    // symbol, while its C implementation has SQLite's extension-entry
    // signature. This annotated transmute mirrors sqlite-vec's own rusqlite
    // test while keeping the symbol live for the macOS linker.
    unsafe {
        std::mem::transmute::<SqliteVecInitSymbol, SqliteVecInitEntry>(sqlite_vec::sqlite3_vec_init)
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct VectorGraphNode {
    pub id: String,
    pub label: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct VectorGraphEdge {
    pub source_id: String,
    pub target_id: String,
    pub weight: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct StableGraphProjection {
    pub node_count: u32,
    pub edge_count: u32,
    pub node_ids: Vec<String>,
    pub edge_pairs_json: String,
}

#[derive(Debug, thiserror::Error)]
pub enum VectorGraphError {
    #[error("invalid sqlite identifier")]
    InvalidIdentifier,
    #[error("invalid vector dimension")]
    InvalidDimension,
    #[error("duplicate graph node")]
    DuplicateNode,
    #[error("missing graph node")]
    MissingNode,
    #[error("invalid edge weight")]
    InvalidWeight,
    #[error("sqlite-vec unavailable")]
    SqliteVecUnavailable,
}

pub fn register_sqlite_vec_auto_extension() -> Result<bool, VectorGraphError> {
    let result = SQLITE_VEC_REGISTRATION.get_or_init(|| {
        // SAFETY: sqlite3_auto_extension expects a SQLite extension entry point.
        let rc = unsafe { sqlite3_auto_extension(Some(sqlite_vec_init_entry())) };
        if rc == SQLITE_OK {
            Ok(())
        } else {
            Err(format!("sqlite3_auto_extension returned {rc}"))
        }
    });

    result
        .as_ref()
        .map(|_| true)
        .map_err(|_| VectorGraphError::SqliteVecUnavailable)
}

pub fn load_sqlite_vec_connection(connection: &Connection) -> Result<bool, VectorGraphError> {
    let mut error_message: *mut c_char = ptr::null_mut();
    // SAFETY: rusqlite owns a live sqlite3 handle for the duration of this
    // call. sqlite-vec 0.1.9 is compiled with SQLITE_CORE in its build script,
    // so the pApi argument is intentionally unused and may be null.
    let rc =
        unsafe { sqlite_vec_init_entry()(connection.handle(), &mut error_message, ptr::null()) };

    if rc == SQLITE_OK {
        Ok(true)
    } else {
        if !error_message.is_null() {
            // SAFETY: sqlite3_vec_init allocates error messages with SQLite's
            // allocator when it returns one; sqlite3_free is the matching free.
            unsafe { sqlite3_free(error_message.cast()) };
        }
        Err(VectorGraphError::SqliteVecUnavailable)
    }
}

pub fn note_embeddings_schema(
    table_name: String,
    dimensions: u32,
) -> Result<String, VectorGraphError> {
    validate_identifier(&table_name)?;
    validate_dimensions(dimensions)?;
    Ok(format!(
        "CREATE VIRTUAL TABLE IF NOT EXISTS {table_name} USING vec0(note_id TEXT PRIMARY KEY, embedding float[{dimensions}])"
    ))
}

pub fn project_stable_digraph(
    nodes: Vec<VectorGraphNode>,
    edges: Vec<VectorGraphEdge>,
) -> Result<StableGraphProjection, VectorGraphError> {
    let mut graph = StableDiGraph::<String, f64>::with_capacity(nodes.len(), edges.len());
    let mut indices = HashMap::with_capacity(nodes.len());
    let mut node_ids = Vec::with_capacity(nodes.len());

    for node in nodes {
        validate_node_id(&node.id)?;
        if indices.contains_key(&node.id) {
            return Err(VectorGraphError::DuplicateNode);
        }
        let id = node.id;
        let index = graph.add_node(id.clone());
        node_ids.push(id.clone());
        indices.insert(id, index);
    }

    for edge in edges {
        if !edge.weight.is_finite() {
            return Err(VectorGraphError::InvalidWeight);
        }
        let source = indices
            .get(&edge.source_id)
            .copied()
            .ok_or(VectorGraphError::MissingNode)?;
        let target = indices
            .get(&edge.target_id)
            .copied()
            .ok_or(VectorGraphError::MissingNode)?;
        graph.add_edge(source, target, edge.weight);
    }

    let edge_pairs = graph
        .edge_references()
        .map(|edge| {
            let source = graph[edge.source()].clone();
            let target = graph[edge.target()].clone();
            serde_json::json!({
                "source_id": source,
                "target_id": target,
                "weight": *edge.weight(),
            })
        })
        .collect::<Vec<_>>();

    Ok(StableGraphProjection {
        node_count: graph.node_count() as u32,
        edge_count: graph.edge_count() as u32,
        node_ids,
        edge_pairs_json: serde_json::to_string(&edge_pairs).unwrap_or_else(|_| "[]".to_string()),
    })
}

fn validate_dimensions(dimensions: u32) -> Result<(), VectorGraphError> {
    if (1..=MAX_VEC_DIMENSIONS).contains(&dimensions) {
        Ok(())
    } else {
        Err(VectorGraphError::InvalidDimension)
    }
}

fn validate_identifier(identifier: &str) -> Result<(), VectorGraphError> {
    let mut chars = identifier.chars();
    let Some(first) = chars.next() else {
        return Err(VectorGraphError::InvalidIdentifier);
    };
    if !(first == '_' || first.is_ascii_alphabetic()) {
        return Err(VectorGraphError::InvalidIdentifier);
    }
    if chars.all(|character| character == '_' || character.is_ascii_alphanumeric()) {
        Ok(())
    } else {
        Err(VectorGraphError::InvalidIdentifier)
    }
}

fn validate_node_id(node_id: &str) -> Result<(), VectorGraphError> {
    if node_id.trim().is_empty() {
        Err(VectorGraphError::MissingNode)
    } else {
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rusqlite::Connection;

    #[test]
    fn note_embeddings_schema_validates_table_and_dimensions() {
        let sql = note_embeddings_schema("note_embeddings".to_string(), 384)
            .expect("valid schema should render");

        assert!(sql.contains("USING vec0"));
        assert!(sql.contains("embedding float[384]"));
        assert!(note_embeddings_schema("bad-name".to_string(), 384).is_err());
        assert!(note_embeddings_schema("note_embeddings".to_string(), 0).is_err());
    }

    #[test]
    fn sqlite_vec_auto_extension_success_must_be_real() {
        if register_sqlite_vec_auto_extension().is_ok() {
            let conn = Connection::open_in_memory().expect("in-memory sqlite should open");
            let version: String = conn
                .query_row("SELECT vec_version()", [], |row| row.get(0))
                .expect("successful auto-extension registration should expose vec_version");

            assert!(version.starts_with('v'));
        }
    }

    #[test]
    fn sqlite_vec_loads_and_creates_vec0_table() {
        let conn = Connection::open_in_memory().expect("in-memory sqlite should open");
        load_sqlite_vec_connection(&conn).expect("sqlite-vec should load on the connection");
        let version: String = conn
            .query_row("SELECT vec_version()", [], |row| row.get(0))
            .expect("vec_version should be available");
        let sql =
            note_embeddings_schema("note_embeddings".to_string(), 4).expect("schema should render");

        conn.execute_batch(&sql)
            .expect("vec0 virtual table should create");

        assert!(version.starts_with('v'));
    }

    #[test]
    fn stable_projection_preserves_node_order_and_edges() {
        let projection = project_stable_digraph(
            vec![
                VectorGraphNode {
                    id: "a".to_string(),
                    label: "A".to_string(),
                },
                VectorGraphNode {
                    id: "b".to_string(),
                    label: "B".to_string(),
                },
            ],
            vec![VectorGraphEdge {
                source_id: "a".to_string(),
                target_id: "b".to_string(),
                weight: 0.75,
            }],
        )
        .expect("valid graph should project");

        assert_eq!(projection.node_count, 2);
        assert_eq!(projection.edge_count, 1);
        assert_eq!(projection.node_ids, vec!["a".to_string(), "b".to_string()]);
        assert!(projection.edge_pairs_json.contains("\"source_id\":\"a\""));
    }

    #[test]
    fn stable_projection_rejects_dangling_edges() {
        let error = project_stable_digraph(
            vec![VectorGraphNode {
                id: "a".to_string(),
                label: "A".to_string(),
            }],
            vec![VectorGraphEdge {
                source_id: "a".to_string(),
                target_id: "missing".to_string(),
                weight: 1.0,
            }],
        )
        .expect_err("dangling edge should fail");

        assert!(matches!(error, VectorGraphError::MissingNode));
    }
}
