use criterion::{black_box, criterion_group, criterion_main, Criterion};
use ropey::Rope;
use syntax_core::rope_bridge::parse_rope;
use tree_sitter::{InputEdit, Language, Parser, Point};

fn rust_language() -> Language {
    tree_sitter_rust::LANGUAGE.into()
}

fn generate_rust_source(num_functions: usize) -> String {
    let mut src = String::with_capacity(num_functions * 80);
    src.push_str("use std::collections::HashMap;\n\n");
    for i in 0..num_functions {
        src.push_str(&format!(
            "fn func_{i}(x: i32, y: &str) -> Option<String> {{\n\
             \x20   let mut map = HashMap::new();\n\
             \x20   map.insert(x, y.to_string());\n\
             \x20   if x > 0 {{\n\
             \x20       Some(format!(\"{{}} = {{}}\", x, y))\n\
             \x20   }} else {{\n\
             \x20       None\n\
             \x20   }}\n\
             }}\n\n"
        ));
    }
    src
}

fn bench_initial_parse(c: &mut Criterion) {
    let source = generate_rust_source(5000);
    let line_count = source.lines().count();
    let byte_count = source.len();

    let mut group = c.benchmark_group("initial_parse");
    group.bench_function(
        format!("rust_{line_count}_lines_{byte_count}_bytes"),
        |b| {
            b.iter(|| {
                let mut parser = Parser::new();
                parser.set_language(&rust_language()).unwrap();
                let rope = Rope::from_str(black_box(&source));
                let tree = parse_rope(&mut parser, &rope, None);
                assert!(tree.is_some());
                black_box(tree);
            });
        },
    );
    group.finish();
}

fn bench_incremental_reparse(c: &mut Criterion) {
    let source = generate_rust_source(5000);
    let line_count = source.lines().count();

    let mut parser = Parser::new();
    parser.set_language(&rust_language()).unwrap();
    let rope = Rope::from_str(&source);
    let base_tree = parse_rope(&mut parser, &rope, None).unwrap();

    let insert_byte = source.len() / 2;

    let mut group = c.benchmark_group("incremental_reparse");
    group.bench_function(
        format!("single_char_insert_at_midpoint_{line_count}_lines"),
        |b| {
            b.iter(|| {
                let mut rope2 = rope.clone();
                let char_idx = rope2.byte_to_char(insert_byte);
                rope2.insert(char_idx, "X");

                let mut old_tree = base_tree.clone();
                old_tree.edit(&InputEdit {
                    start_byte: insert_byte,
                    old_end_byte: insert_byte,
                    new_end_byte: insert_byte + 1,
                    start_position: Point::new(0, 0),
                    old_end_position: Point::new(0, 0),
                    new_end_position: Point::new(0, 1),
                });

                let new_tree = parse_rope(&mut parser, &rope2, Some(&old_tree));
                assert!(new_tree.is_some());
                black_box(new_tree);
            });
        },
    );
    group.finish();
}

fn bench_rope_creation(c: &mut Criterion) {
    let source = generate_rust_source(5000);
    let byte_count = source.len();

    let mut group = c.benchmark_group("rope_creation");
    group.bench_function(format!("from_str_{byte_count}_bytes"), |b| {
        b.iter(|| {
            let rope = Rope::from_str(black_box(&source));
            black_box(&rope);
        });
    });
    group.finish();
}

criterion_group!(
    benches,
    bench_initial_parse,
    bench_incremental_reparse,
    bench_rope_creation,
);
criterion_main!(benches);
