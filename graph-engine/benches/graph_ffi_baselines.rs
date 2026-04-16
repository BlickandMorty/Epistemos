//! Baseline benchmarks for graph-engine FFI surfaces.
//!
//! Measures the core FFI-adjacent operations that Swift calls through the C bridge:
//! graph data loading, search, markdown parsing, and simulation tick.
//!
//! Run:  cargo bench --manifest-path graph-engine/Cargo.toml

use criterion::{Criterion, black_box, criterion_group, criterion_main};

use graph_engine::markdown::parse_structure;
use graph_engine::search::SearchIndex;
use graph_engine::simulation::Simulation;
use graph_engine::types::Graph;

fn make_graph(n: usize) -> Graph {
    let mut g = Graph::new();
    for i in 0..n {
        let uuid = format!("node-{i:06}");
        let x = (i as f32) * 0.1;
        let y = (i as f32) * 0.2;
        g.add_node(&uuid, x, y, 0, (i as u32) % 8, &format!("Label {i}"));
    }
    for i in 1..n {
        let src = format!("node-{:06}", i - 1);
        let tgt = format!("node-{i:06}");
        g.add_edge(&src, &tgt, 1.0, 0);
    }
    g
}

// ---------------------------------------------------------------------------
// Graph Data Loading
// ---------------------------------------------------------------------------

fn bench_graph_loading(c: &mut Criterion) {
    let mut group = c.benchmark_group("graph_data_loading");

    for &n in &[100, 500, 1000, 5000] {
        group.bench_function(format!("add_{n}_nodes_and_edges"), |b| {
            b.iter(|| {
                let g = make_graph(black_box(n));
                black_box(g.nodes.len());
            });
        });
    }

    group.finish();
}

// ---------------------------------------------------------------------------
// Search Index Build + Query
// ---------------------------------------------------------------------------

fn bench_search(c: &mut Criterion) {
    let mut group = c.benchmark_group("search");

    let graph_1000 = make_graph(1000);

    group.bench_function("build_index_1000", |b| {
        b.iter(|| {
            let mut idx = SearchIndex::new();
            idx.build(black_box(&graph_1000.nodes));
            black_box(&idx);
        });
    });

    let mut idx = SearchIndex::new();
    idx.build(&graph_1000.nodes);

    group.bench_function("search_exact_1000", |b| {
        b.iter(|| {
            let hits = idx.search(black_box("Label 500"), 20);
            black_box(hits.len());
        });
    });

    group.bench_function("search_fuzzy_1000", |b| {
        b.iter(|| {
            let hits = idx.search(black_box("Labl 42"), 20);
            black_box(hits.len());
        });
    });

    group.bench_function("search_no_match_1000", |b| {
        b.iter(|| {
            let hits = idx.search(black_box("zzzzzzzzz"), 20);
            black_box(hits.len());
        });
    });

    group.finish();
}

// ---------------------------------------------------------------------------
// Simulation Tick
// ---------------------------------------------------------------------------

fn bench_simulation_tick(c: &mut Criterion) {
    let mut group = c.benchmark_group("simulation_tick");

    for &n in &[100, 500, 1000] {
        let graph = make_graph(n);
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);

        group.bench_function(format!("tick_{n}_nodes"), |b| {
            b.iter(|| {
                sim.tick();
            });
        });
    }

    group.finish();
}

// ---------------------------------------------------------------------------
// Markdown Parser
// ---------------------------------------------------------------------------

fn bench_markdown_parse(c: &mut Criterion) {
    let mut group = c.benchmark_group("markdown_parse");

    let small_md = "# Hello\n\nSome **bold** text with a [link](https://example.com).\n";
    let medium_md = (0..100)
        .map(|i| format!("## Section {i}\n\nParagraph with **bold** and *italic* and `code` tokens.\n\n- Item A\n- Item B\n- Item C\n\n"))
        .collect::<String>();
    let large_md = (0..500)
        .map(|i| format!("### Heading {i}\n\nLorem ipsum dolor sit amet, **consectetur** adipiscing elit.\n\n```rust\nfn main() {{ println!(\"hello\"); }}\n```\n\n"))
        .collect::<String>();

    group.bench_function("small_50bytes", |b| {
        b.iter(|| {
            let spans = parse_structure(black_box(small_md));
            black_box(spans.len());
        });
    });

    group.bench_function("medium_10KB", |b| {
        b.iter(|| {
            let spans = parse_structure(black_box(&medium_md));
            black_box(spans.len());
        });
    });

    group.bench_function("large_50KB", |b| {
        b.iter(|| {
            let spans = parse_structure(black_box(&large_md));
            black_box(spans.len());
        });
    });

    group.finish();
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

criterion_group!(
    benches,
    bench_graph_loading,
    bench_search,
    bench_simulation_tick,
    bench_markdown_parse,
);
criterion_main!(benches);
