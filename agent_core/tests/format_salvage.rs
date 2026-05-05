use agent_core::format::{
    Actor, FormatError, Intent, MemFile, MemHeader, MemType, Provenance, Signals, SkillManifest,
    SkillStep, INTENT_V1_ID, MEM_V1_ID, SKILL_V1_ID,
};
use chrono::{TimeZone, Utc};

fn sample_header() -> MemHeader {
    MemHeader {
        schema: MEM_V1_ID.to_string(),
        id: "01HX42KQM3R7N9PVK0X8Z3W5MQ".to_string(),
        mem_type: MemType::Capture,
        ts: Utc.with_ymd_and_hms(2026, 4, 29, 1, 0, 0).unwrap(),
        actor: Some(Actor::User),
        tags: vec!["routing".to_string(), "quick-capture".to_string()],
        links: vec!["c_4f2a".to_string()],
        salience: Some(0.62),
        signals: Signals {
            access_count: Some(3),
            last_accessed: Some(Utc.with_ymd_and_hms(2026, 4, 29, 1, 5, 0).unwrap()),
            explicit_importance: None,
        },
        provenance: Provenance {
            source: Some("capture.text".to_string()),
            device: Some("M4Pro".to_string()),
            tool_chain: vec!["structure.route_capture".to_string()],
        },
        schema_version: Some(1),
    }
}

#[test]
fn mem_round_trip_preserves_verbatim_markdown_body() {
    let body = "\n---not a header, just body text---\nemoji 🚀 中文\n";
    let mem = MemFile {
        header: sample_header(),
        body: body.to_string(),
    };

    let encoded = mem.serialize().unwrap();
    let decoded = MemFile::parse(&encoded).unwrap();

    assert_eq!(decoded.header, mem.header);
    assert_eq!(decoded.body, body);
    decoded.validate().unwrap();
}

#[test]
fn mem_rejects_malformed_header_and_non_ulid_id() {
    let malformed = "not a fenced header\nbody";
    assert!(matches!(
        MemFile::parse(malformed),
        Err(FormatError::MalformedMemHeader(_))
    ));

    let bad_id = format!(
        "---{}---\nbody",
        serde_json::json!({
            "$schema": MEM_V1_ID,
            "id": "not-a-ulid",
            "type": "capture",
            "ts": "2026-04-29T01:00:00Z"
        })
    );
    let parsed = MemFile::parse(&bad_id).unwrap();
    assert!(matches!(parsed.validate(), Err(FormatError::Validation(_))));
}

#[test]
fn all_mem_types_round_trip_through_json_names() {
    for mem_type in MemType::all() {
        let header = MemHeader {
            mem_type,
            ..sample_header()
        };
        let mem = MemFile {
            header,
            body: format!("# {:?}\n", mem_type),
        };
        let encoded = mem.serialize().unwrap();
        let decoded = MemFile::parse(&encoded).unwrap();
        assert_eq!(decoded.header.mem_type, mem_type);
        decoded.validate().unwrap();
    }
}

#[test]
fn intent_variants_round_trip_and_validate() {
    let intents = [
        Intent::VaultWrite {
            path: "notes/a.md".to_string(),
            body: "body".to_string(),
            frontmatter: serde_json::json!({}),
        },
        Intent::VaultMove {
            from: "notes/a.md".to_string(),
            to: "notes/b.md".to_string(),
        },
        Intent::VaultDelete {
            path: "notes/old.md".to_string(),
        },
        Intent::ConceptCreate {
            canonical_name: "gradient-checkpointing".to_string(),
            definition: "recompute forward to save memory".to_string(),
        },
        Intent::ConceptAlias {
            canonical_name: "gradient-checkpointing".to_string(),
            alias: "rematerialization".to_string(),
        },
        Intent::MemoryWrite {
            entry: serde_json::json!({"$schema": MEM_V1_ID, "id": "01HX42KQM3R7N9PVK0X8Z3W5MQ"}),
        },
        Intent::Noop {
            reason: "no action needed".to_string(),
        },
        Intent::Abort {
            reason: "unrecoverable".to_string(),
        },
    ];

    for intent in intents {
        intent.validate().unwrap();
        let encoded = serde_json::to_string(&intent).unwrap();
        let decoded: Intent = serde_json::from_str(&encoded).unwrap();
        assert_eq!(decoded, intent);
    }

    assert_eq!(INTENT_V1_ID, "epistemos://schemas/intent.v1.json");
}

#[test]
fn skill_manifest_validates_voyager_style_steps() {
    let manifest = SkillManifest {
        schema: SKILL_V1_ID.to_string(),
        id: "skill.weekly-review.v1".to_string(),
        name: "weekly-review".to_string(),
        narrative_path: "weekly-review.skill.md".to_string(),
        preconditions: vec!["day_of_week == 'Sunday'".to_string()],
        steps: vec![
            SkillStep {
                id: "s1".to_string(),
                tool: "memory.recall_episodic".to_string(),
                input: Some(serde_json::json!({"window_days": 7})),
                input_from: None,
                params: None,
            },
            SkillStep {
                id: "s2".to_string(),
                tool: "knowledge.summarize".to_string(),
                input: None,
                input_from: Some("s1.result".to_string()),
                params: Some(serde_json::json!({"style": "outline"})),
            },
        ],
        success_metric: Some("vault.write returned status:ok".to_string()),
        last_used: None,
        success_rate: Some(0.93),
        schema_version: 1,
    };

    manifest.validate().unwrap();

    let mut payload_ref = manifest.clone();
    payload_ref.steps[1].input_from = Some("s1.payload".to_string());
    assert!(matches!(
        payload_ref.validate(),
        Err(FormatError::Validation(_))
    ));
}
