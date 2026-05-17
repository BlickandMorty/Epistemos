use agent_core::tri_fusion::TriFusionDocument;
use serde_json::{json, Value};

const JSON_CORPUS_CASE_COUNT: usize = 200;

fn text_node(text: impl Into<String>) -> Value {
    json!({
        "type": "text",
        "text": text.into(),
    })
}

fn paragraph(block_id: String, text: String) -> Value {
    json!({
        "type": "paragraph",
        "attrs": {
            "id": block_id,
        },
        "content": [
            text_node(text),
        ],
    })
}

fn heading(seed: usize) -> Value {
    json!({
        "type": "heading",
        "attrs": {
            "id": format!("h{seed}"),
            "level": seed % 3 + 1,
        },
        "content": [
            text_node(format!("Corpus heading {seed}")),
        ],
    })
}

fn bullet_list(seed: usize) -> Value {
    json!({
        "type": "bulletList",
        "attrs": {
            "id": format!("list{seed}"),
        },
        "content": [
            {
                "type": "listItem",
                "attrs": {
                    "id": format!("li{seed}a"),
                },
                "content": [
                    paragraph(format!("li{seed}ap"), format!("First generated item {seed}")),
                ],
            },
            {
                "type": "listItem",
                "attrs": {
                    "id": format!("li{seed}b"),
                },
                "content": [
                    paragraph(format!("li{seed}bp"), format!("Second generated item {seed}")),
                ],
            },
        ],
    })
}

fn blockquote(seed: usize) -> Value {
    json!({
        "type": "blockquote",
        "attrs": {
            "id": format!("quote{seed}"),
        },
        "content": [
            paragraph(format!("quote{seed}p"), format!("Quoted generated text {seed}")),
        ],
    })
}

fn code_block(seed: usize) -> Value {
    let language = match seed % 4 {
        0 => "rust",
        1 => "swift",
        2 => "python",
        _ => "typescript",
    };
    json!({
        "type": "codeBlock",
        "attrs": {
            "id": format!("code{seed}"),
            "language": language,
        },
        "content": [
            text_node(format!("fn generated_{seed}() {{ return; }}")),
        ],
    })
}

fn callout(seed: usize) -> Value {
    let tone = match seed % 3 {
        0 => "note",
        1 => "warning",
        _ => "insight",
    };
    json!({
        "type": "callout",
        "attrs": {
            "id": format!("callout{seed}"),
            "tone": tone,
            "title": format!("Corpus callout {seed}"),
        },
        "content": [
            paragraph(format!("callout{seed}p"), format!("Callout body {seed}")),
        ],
    })
}

fn mermaid(seed: usize) -> Value {
    json!({
        "type": "mermaid",
        "attrs": {
            "id": format!("mermaid{seed}"),
        },
        "content": [
            text_node(format!("graph TD\\nA{seed} --> B{seed}")),
        ],
    })
}

fn table(seed: usize) -> Value {
    json!({
        "type": "table",
        "attrs": {
            "id": format!("table{seed}"),
        },
        "content": [
            {
                "type": "tableRow",
                "attrs": {
                    "id": format!("tr{seed}h"),
                },
                "content": [
                    table_cell(format!("th{seed}a"), format!("Metric {seed}")),
                    table_cell(format!("th{seed}b"), "Value".to_string()),
                ],
            },
            {
                "type": "tableRow",
                "attrs": {
                    "id": format!("tr{seed}b"),
                },
                "content": [
                    table_cell(format!("td{seed}a"), "Score".to_string()),
                    table_cell(format!("td{seed}b"), format!("{}", seed * 7)),
                ],
            },
        ],
    })
}

fn table_cell(block_id: String, text: String) -> Value {
    json!({
        "type": "tableCell",
        "attrs": {
            "id": block_id,
        },
        "content": [
            paragraph(format!("cell-{text}"), text),
        ],
    })
}

fn chart(seed: usize) -> Value {
    json!({
        "type": "epdocChart",
        "attrs": {
            "chart_type": "bar",
            "id": format!("chart{seed}"),
        },
        "content": [
            text_node(format!("series: [{}, {}, {}]", seed, seed + 1, seed + 2)),
        ],
    })
}

fn image(seed: usize) -> Value {
    json!({
        "type": "epdocImage",
        "attrs": {
            "alt": format!("Generated corpus image {seed}"),
            "id": format!("image{seed}"),
            "src": format!("assets/image-{seed}.png"),
            "title": "",
        },
    })
}

fn generated_doc(seed: usize) -> Value {
    let mut content = vec![
        paragraph(format!("p{seed}a"), format!("Generated paragraph {seed}")),
        heading(seed),
    ];

    if seed % 2 == 0 {
        content.push(bullet_list(seed));
    } else {
        content.push(blockquote(seed));
    }
    if seed % 3 == 0 {
        content.push(code_block(seed));
    }
    if seed % 5 == 0 {
        content.push(callout(seed));
    }
    if seed % 7 == 0 {
        content.push(mermaid(seed));
    }
    if seed % 11 == 0 {
        content.push(table(seed));
    }
    if seed % 13 == 0 {
        content.push(chart(seed));
    }
    if seed % 17 == 0 {
        content.push(image(seed));
    }

    json!({
        "type": "doc",
        "content": content,
    })
}

fn assert_generated_json_corpus_case(seed: usize) {
    let document = TriFusionDocument::from_json_value(generated_doc(seed)).unwrap();
    let canonical_json = document.canonical_json().to_string();
    let reparsed = TriFusionDocument::parse_json(&canonical_json).unwrap();

    assert_eq!(reparsed.canonical_json(), canonical_json);
    assert_eq!(reparsed.hash(), document.hash());
    assert_eq!(reparsed.canonical_version(), document.canonical_version());
}

#[test]
fn json_corpus_case_count_is_reported() {
    assert_eq!(JSON_CORPUS_CASE_COUNT, 200);
}

macro_rules! corpus_case {
    ($name:ident, $seed:expr) => {
        #[test]
        fn $name() {
            assert_generated_json_corpus_case($seed);
        }
    };
}

corpus_case!(json_corpus_001, 1);
corpus_case!(json_corpus_002, 2);
corpus_case!(json_corpus_003, 3);
corpus_case!(json_corpus_004, 4);
corpus_case!(json_corpus_005, 5);
corpus_case!(json_corpus_006, 6);
corpus_case!(json_corpus_007, 7);
corpus_case!(json_corpus_008, 8);
corpus_case!(json_corpus_009, 9);
corpus_case!(json_corpus_010, 10);
corpus_case!(json_corpus_011, 11);
corpus_case!(json_corpus_012, 12);
corpus_case!(json_corpus_013, 13);
corpus_case!(json_corpus_014, 14);
corpus_case!(json_corpus_015, 15);
corpus_case!(json_corpus_016, 16);
corpus_case!(json_corpus_017, 17);
corpus_case!(json_corpus_018, 18);
corpus_case!(json_corpus_019, 19);
corpus_case!(json_corpus_020, 20);
corpus_case!(json_corpus_021, 21);
corpus_case!(json_corpus_022, 22);
corpus_case!(json_corpus_023, 23);
corpus_case!(json_corpus_024, 24);
corpus_case!(json_corpus_025, 25);
corpus_case!(json_corpus_026, 26);
corpus_case!(json_corpus_027, 27);
corpus_case!(json_corpus_028, 28);
corpus_case!(json_corpus_029, 29);
corpus_case!(json_corpus_030, 30);
corpus_case!(json_corpus_031, 31);
corpus_case!(json_corpus_032, 32);
corpus_case!(json_corpus_033, 33);
corpus_case!(json_corpus_034, 34);
corpus_case!(json_corpus_035, 35);
corpus_case!(json_corpus_036, 36);
corpus_case!(json_corpus_037, 37);
corpus_case!(json_corpus_038, 38);
corpus_case!(json_corpus_039, 39);
corpus_case!(json_corpus_040, 40);
corpus_case!(json_corpus_041, 41);
corpus_case!(json_corpus_042, 42);
corpus_case!(json_corpus_043, 43);
corpus_case!(json_corpus_044, 44);
corpus_case!(json_corpus_045, 45);
corpus_case!(json_corpus_046, 46);
corpus_case!(json_corpus_047, 47);
corpus_case!(json_corpus_048, 48);
corpus_case!(json_corpus_049, 49);
corpus_case!(json_corpus_050, 50);
corpus_case!(json_corpus_051, 51);
corpus_case!(json_corpus_052, 52);
corpus_case!(json_corpus_053, 53);
corpus_case!(json_corpus_054, 54);
corpus_case!(json_corpus_055, 55);
corpus_case!(json_corpus_056, 56);
corpus_case!(json_corpus_057, 57);
corpus_case!(json_corpus_058, 58);
corpus_case!(json_corpus_059, 59);
corpus_case!(json_corpus_060, 60);
corpus_case!(json_corpus_061, 61);
corpus_case!(json_corpus_062, 62);
corpus_case!(json_corpus_063, 63);
corpus_case!(json_corpus_064, 64);
corpus_case!(json_corpus_065, 65);
corpus_case!(json_corpus_066, 66);
corpus_case!(json_corpus_067, 67);
corpus_case!(json_corpus_068, 68);
corpus_case!(json_corpus_069, 69);
corpus_case!(json_corpus_070, 70);
corpus_case!(json_corpus_071, 71);
corpus_case!(json_corpus_072, 72);
corpus_case!(json_corpus_073, 73);
corpus_case!(json_corpus_074, 74);
corpus_case!(json_corpus_075, 75);
corpus_case!(json_corpus_076, 76);
corpus_case!(json_corpus_077, 77);
corpus_case!(json_corpus_078, 78);
corpus_case!(json_corpus_079, 79);
corpus_case!(json_corpus_080, 80);
corpus_case!(json_corpus_081, 81);
corpus_case!(json_corpus_082, 82);
corpus_case!(json_corpus_083, 83);
corpus_case!(json_corpus_084, 84);
corpus_case!(json_corpus_085, 85);
corpus_case!(json_corpus_086, 86);
corpus_case!(json_corpus_087, 87);
corpus_case!(json_corpus_088, 88);
corpus_case!(json_corpus_089, 89);
corpus_case!(json_corpus_090, 90);
corpus_case!(json_corpus_091, 91);
corpus_case!(json_corpus_092, 92);
corpus_case!(json_corpus_093, 93);
corpus_case!(json_corpus_094, 94);
corpus_case!(json_corpus_095, 95);
corpus_case!(json_corpus_096, 96);
corpus_case!(json_corpus_097, 97);
corpus_case!(json_corpus_098, 98);
corpus_case!(json_corpus_099, 99);
corpus_case!(json_corpus_100, 100);
corpus_case!(json_corpus_101, 101);
corpus_case!(json_corpus_102, 102);
corpus_case!(json_corpus_103, 103);
corpus_case!(json_corpus_104, 104);
corpus_case!(json_corpus_105, 105);
corpus_case!(json_corpus_106, 106);
corpus_case!(json_corpus_107, 107);
corpus_case!(json_corpus_108, 108);
corpus_case!(json_corpus_109, 109);
corpus_case!(json_corpus_110, 110);
corpus_case!(json_corpus_111, 111);
corpus_case!(json_corpus_112, 112);
corpus_case!(json_corpus_113, 113);
corpus_case!(json_corpus_114, 114);
corpus_case!(json_corpus_115, 115);
corpus_case!(json_corpus_116, 116);
corpus_case!(json_corpus_117, 117);
corpus_case!(json_corpus_118, 118);
corpus_case!(json_corpus_119, 119);
corpus_case!(json_corpus_120, 120);
corpus_case!(json_corpus_121, 121);
corpus_case!(json_corpus_122, 122);
corpus_case!(json_corpus_123, 123);
corpus_case!(json_corpus_124, 124);
corpus_case!(json_corpus_125, 125);
corpus_case!(json_corpus_126, 126);
corpus_case!(json_corpus_127, 127);
corpus_case!(json_corpus_128, 128);
corpus_case!(json_corpus_129, 129);
corpus_case!(json_corpus_130, 130);
corpus_case!(json_corpus_131, 131);
corpus_case!(json_corpus_132, 132);
corpus_case!(json_corpus_133, 133);
corpus_case!(json_corpus_134, 134);
corpus_case!(json_corpus_135, 135);
corpus_case!(json_corpus_136, 136);
corpus_case!(json_corpus_137, 137);
corpus_case!(json_corpus_138, 138);
corpus_case!(json_corpus_139, 139);
corpus_case!(json_corpus_140, 140);
corpus_case!(json_corpus_141, 141);
corpus_case!(json_corpus_142, 142);
corpus_case!(json_corpus_143, 143);
corpus_case!(json_corpus_144, 144);
corpus_case!(json_corpus_145, 145);
corpus_case!(json_corpus_146, 146);
corpus_case!(json_corpus_147, 147);
corpus_case!(json_corpus_148, 148);
corpus_case!(json_corpus_149, 149);
corpus_case!(json_corpus_150, 150);
corpus_case!(json_corpus_151, 151);
corpus_case!(json_corpus_152, 152);
corpus_case!(json_corpus_153, 153);
corpus_case!(json_corpus_154, 154);
corpus_case!(json_corpus_155, 155);
corpus_case!(json_corpus_156, 156);
corpus_case!(json_corpus_157, 157);
corpus_case!(json_corpus_158, 158);
corpus_case!(json_corpus_159, 159);
corpus_case!(json_corpus_160, 160);
corpus_case!(json_corpus_161, 161);
corpus_case!(json_corpus_162, 162);
corpus_case!(json_corpus_163, 163);
corpus_case!(json_corpus_164, 164);
corpus_case!(json_corpus_165, 165);
corpus_case!(json_corpus_166, 166);
corpus_case!(json_corpus_167, 167);
corpus_case!(json_corpus_168, 168);
corpus_case!(json_corpus_169, 169);
corpus_case!(json_corpus_170, 170);
corpus_case!(json_corpus_171, 171);
corpus_case!(json_corpus_172, 172);
corpus_case!(json_corpus_173, 173);
corpus_case!(json_corpus_174, 174);
corpus_case!(json_corpus_175, 175);
corpus_case!(json_corpus_176, 176);
corpus_case!(json_corpus_177, 177);
corpus_case!(json_corpus_178, 178);
corpus_case!(json_corpus_179, 179);
corpus_case!(json_corpus_180, 180);
corpus_case!(json_corpus_181, 181);
corpus_case!(json_corpus_182, 182);
corpus_case!(json_corpus_183, 183);
corpus_case!(json_corpus_184, 184);
corpus_case!(json_corpus_185, 185);
corpus_case!(json_corpus_186, 186);
corpus_case!(json_corpus_187, 187);
corpus_case!(json_corpus_188, 188);
corpus_case!(json_corpus_189, 189);
corpus_case!(json_corpus_190, 190);
corpus_case!(json_corpus_191, 191);
corpus_case!(json_corpus_192, 192);
corpus_case!(json_corpus_193, 193);
corpus_case!(json_corpus_194, 194);
corpus_case!(json_corpus_195, 195);
corpus_case!(json_corpus_196, 196);
corpus_case!(json_corpus_197, 197);
corpus_case!(json_corpus_198, 198);
corpus_case!(json_corpus_199, 199);
corpus_case!(json_corpus_200, 200);
