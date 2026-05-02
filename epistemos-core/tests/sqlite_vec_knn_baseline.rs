use std::fs;
use std::path::{Path, PathBuf};
use std::time::Instant;

use rusqlite::{params, Connection};
use serde_json::json;

#[path = "../src/vector_graph.rs"]
mod vector_graph;

use vector_graph::{load_sqlite_vec_connection, note_embeddings_schema};

const GENERATED_AT: &str = "2026-05-01T00:00:00.000Z";
const ROW_COUNT: usize = 100_000;
const DIMENSIONS: usize = 32;
const K: usize = 10;
const QUERY_COUNT: usize = 16;

#[test]
#[ignore = "manual 100k sqlite-vec fixture baseline"]
fn sqlite_vec_knn_baseline_writes_report() {
    let mut conn = Connection::open_in_memory().expect("in-memory sqlite should open");
    load_sqlite_vec_connection(&conn).expect("sqlite-vec should load directly on connection");
    configure_fast_fixture_pragmas(&conn);
    let schema = note_embeddings_schema("note_embeddings".to_string(), DIMENSIONS as u32)
        .expect("schema should render for fixture");
    conn.execute_batch(&schema)
        .expect("vec0 table should create for fixture");

    insert_fixture_vectors(&mut conn);

    let samples = run_knn_queries(&conn);
    let report_path = write_report(&samples);
    let decoded: serde_json::Value =
        serde_json::from_slice(&fs::read(&report_path).expect("report should be readable"))
            .expect("report should decode as JSON");

    assert_eq!(decoded["schema_version"], 1);
    assert_eq!(decoded["suite"], "sqlite-vec KNN");
    assert_eq!(decoded["measurement"], "sqlite_vec_knn_100k_32d");
    assert_eq!(decoded["sample_count"], QUERY_COUNT);
    assert_eq!(
        decoded["metadata"]["status"],
        "real sqlite-vec vec0 KNN fixture"
    );
    assert!(decoded["p95"]
        .as_f64()
        .expect("p95 should be numeric")
        .is_finite());
}

fn configure_fast_fixture_pragmas(conn: &Connection) {
    conn.execute_batch(
        "PRAGMA journal_mode = OFF;
         PRAGMA synchronous = OFF;
         PRAGMA temp_store = MEMORY;
         PRAGMA cache_size = -200000;",
    )
    .expect("fixture pragmas should apply");
}

fn insert_fixture_vectors(conn: &mut Connection) {
    let tx = conn
        .transaction()
        .expect("fixture insert transaction should open");
    {
        let mut insert = tx
            .prepare("INSERT INTO note_embeddings(note_id, embedding) VALUES (?1, ?2)")
            .expect("fixture insert statement should prepare");
        for row in 0..ROW_COUNT {
            let id = format!("note-{row:06}");
            let vector = vector_json(row, DIMENSIONS);
            insert
                .execute(params![id, vector])
                .expect("fixture vector should insert");
        }
    }
    tx.commit()
        .expect("fixture insert transaction should commit");
}

fn run_knn_queries(conn: &Connection) -> Vec<f64> {
    let mut query = conn
        .prepare(
            "SELECT note_id, distance
             FROM note_embeddings
             WHERE embedding MATCH ?1 AND k = ?2
             ORDER BY distance",
        )
        .expect("KNN query should prepare");
    let mut samples = Vec::with_capacity(QUERY_COUNT);

    for query_index in 0..QUERY_COUNT {
        let query_vector = vector_json(query_index * 6_127, DIMENSIONS);
        let start = Instant::now();
        let rows = query
            .query_map(params![query_vector, K as i64], |row| {
                Ok((row.get::<_, String>(0)?, row.get::<_, f64>(1)?))
            })
            .expect("KNN query should execute");

        let results = rows
            .map(|row| row.expect("KNN row should decode"))
            .collect::<Vec<_>>();
        let elapsed = start.elapsed().as_secs_f64();

        assert_eq!(results.len(), K);
        assert!(results.windows(2).all(|pair| pair[0].1 <= pair[1].1));
        assert!(elapsed.is_finite());
        samples.push(elapsed);
    }

    samples
}

fn write_report(samples: &[f64]) -> PathBuf {
    let mut sorted = samples.to_vec();
    sorted.sort_by(|left, right| {
        left.partial_cmp(right)
            .expect("samples should be finite before sorting")
    });

    let report = json!({
        "schema_version": 1,
        "generated_at": GENERATED_AT,
        "suite": "sqlite-vec KNN",
        "measurement": "sqlite_vec_knn_100k_32d",
        "unit": "seconds",
        "sample_count": sorted.len(),
        "min": sorted[0],
        "max": sorted[sorted.len() - 1],
        "p50": percentile(&sorted, 50.0),
        "p95": percentile(&sorted, 95.0),
        "p99": percentile(&sorted, 99.0),
        "samples": sorted,
        "metadata": {
            "status": "real sqlite-vec vec0 KNN fixture",
            "target_vector_count": ROW_COUNT.to_string(),
            "dimensions": DIMENSIONS.to_string(),
            "k": K.to_string(),
            "query_count": QUERY_COUNT.to_string(),
            "sqlite_vec_load": "direct per-connection sqlite3_vec_init",
            "query_shape": "embedding MATCH ? AND k = ? ORDER BY distance",
        },
    });

    let results_dir = results_directory();
    fs::create_dir_all(&results_dir).expect("benchmark results directory should exist");
    let path = results_dir
        .join("2026-05-01t00-00-00-000z-r15-sqlite-vec-knn-sqlite_vec_knn_100k_32d.json");
    let data = serde_json::to_vec_pretty(&report).expect("report should encode");
    fs::write(&path, data).expect("report should write");
    path
}

fn results_directory() -> PathBuf {
    std::env::var_os("EPISTEMOS_BENCHMARK_RESULTS_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| repo_root().join("benchmarks").join("results"))
}

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("epistemos-core should live under repo root")
        .to_path_buf()
}

fn vector_json(seed: usize, dimensions: usize) -> String {
    let values = (0..dimensions)
        .map(|dimension| {
            let raw =
                ((seed.wrapping_mul(31)) + (dimension * 17) + (dimension * dimension * 3)) % 10_000;
            raw as f32 / 10_000.0
        })
        .collect::<Vec<_>>();
    serde_json::to_string(&values).expect("fixture vector should encode")
}

fn percentile(sorted_samples: &[f64], percentile: f64) -> f64 {
    assert!(!sorted_samples.is_empty());
    if sorted_samples.len() == 1 {
        return sorted_samples[0];
    }

    let rank = (percentile / 100.0) * ((sorted_samples.len() - 1) as f64);
    let lower_index = rank.floor() as usize;
    let upper_index = rank.ceil() as usize;
    if lower_index == upper_index {
        return sorted_samples[lower_index];
    }

    let weight = rank - lower_index as f64;
    sorted_samples[lower_index] * (1.0 - weight) + sorted_samples[upper_index] * weight
}
