use encoding_rs::{Encoding, UTF_8};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CorruptionClass {
    Mojibake,
    NullPadded,
    TruncatedMultibyte,
    ReplacementCharClusters,
    LikelyClean,
}

impl CorruptionClass {
    pub fn as_str(self) -> &'static str {
        match self {
            CorruptionClass::Mojibake => "mojibake",
            CorruptionClass::NullPadded => "null_padded",
            CorruptionClass::TruncatedMultibyte => "truncated_multibyte",
            CorruptionClass::ReplacementCharClusters => "replacement_char_clusters",
            CorruptionClass::LikelyClean => "likely_clean",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CorruptionAnalysis {
    pub classification: String,
    pub detail: String,
    pub replacement_ratio: f64,
    pub null_density: f64,
    pub likely_true_encoding: String,
    pub first_problem_offset: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RepairCandidate {
    pub chain: String,
    pub repaired_text: String,
    pub score: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BinaryTextRegion {
    pub offset: u64,
    pub length: u64,
    pub decoded: String,
    pub raw_bytes: Vec<u8>,
    pub is_padding: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BinaryTextExtraction {
    pub regions: Vec<BinaryTextRegion>,
    pub readable_text: String,
}

const COMMON_MOJIBAKE_MARKERS: [&str; 7] = ["Ã", "Â", "â", "ð", "¤", "¢", "‚"];
const TRANSCODE_CHAINS: [(&str, &str); 10] = [
    ("windows-1252", "utf-8"),
    ("utf-8", "windows-1252"),
    ("utf-8", "shift_jis"),
    ("utf-8", "euc-jp"),
    ("utf-8", "gbk"),
    ("utf-8", "big5"),
    ("utf-8", "koi8-r"),
    ("utf-8", "iso-8859-1"),
    ("macintosh", "utf-8"),
    ("utf-8", "macintosh"),
];

pub fn classify_corruption(text: &str, source_encoding: &str) -> CorruptionAnalysis {
    let total_chars = text.chars().count().max(1) as f64;
    let replacement_count = text.chars().filter(|&character| character == '\u{FFFD}').count();
    let replacement_ratio = replacement_count as f64 / total_chars;
    let null_count = text.chars().filter(|&character| character == '\0').count();
    let null_density = null_count as f64 / total_chars;
    let marker_hits = COMMON_MOJIBAKE_MARKERS
        .iter()
        .map(|marker| text.matches(marker).count())
        .sum::<usize>();
    let marker_density = marker_hits as f64 / total_chars;
    let first_problem_offset = text
        .char_indices()
        .find(|(_, character)| *character == '\u{FFFD}' || *character == '\0')
        .map(|(index, _)| index as u64)
        .unwrap_or(0);

    let (classification, detail) = if null_density >= 0.05 {
        (
            CorruptionClass::NullPadded,
            format!("Detected null/0xFF style padding density of {:.1}%", null_density * 100.0),
        )
    } else if replacement_ratio > 0.05 || marker_density > 0.02 {
        (
            CorruptionClass::Mojibake,
            format!(
                "Detected mojibake markers (replacement ratio {:.1}%, marker density {:.1}%)",
                replacement_ratio * 100.0,
                marker_density * 100.0
            ),
        )
    } else if replacement_count >= 2 {
        (
            CorruptionClass::ReplacementCharClusters,
            format!("Detected {} replacement characters in visible clusters", replacement_count),
        )
    } else if replacement_count > 0 {
        (
            CorruptionClass::TruncatedMultibyte,
            format!("Detected trailing replacement character near byte {}", first_problem_offset),
        )
    } else {
        (CorruptionClass::LikelyClean, "No obvious corruption markers detected".to_string())
    };

    let likely_true_encoding = if matches!(classification, CorruptionClass::Mojibake) {
        repair_mojibake(text.as_bytes())
            .into_iter()
            .find_map(|candidate| candidate.chain.split("→").nth(1).map(|encoding| encoding.trim().to_string()))
            .unwrap_or_else(|| source_encoding.to_string())
    } else {
        source_encoding.to_string()
    };

    CorruptionAnalysis {
        classification: classification.as_str().to_string(),
        detail,
        replacement_ratio,
        null_density,
        likely_true_encoding,
        first_problem_offset,
    }
}

pub fn repair_mojibake(bytes: &[u8]) -> Vec<RepairCandidate> {
    let lossy = String::from_utf8_lossy(bytes);
    let mut seen = HashSet::new();
    let mut candidates = Vec::new();

    for (wrong_encoding_label, true_encoding_label) in TRANSCODE_CHAINS {
        let Some(wrong_encoding) = Encoding::for_label(wrong_encoding_label.as_bytes()) else {
            continue;
        };
        let Some(true_encoding) = Encoding::for_label(true_encoding_label.as_bytes()) else {
            continue;
        };

        let (reencoded, _, had_encode_errors) = wrong_encoding.encode(&lossy);
        if reencoded.is_empty() {
            continue;
        }

        let (decoded, _, had_decode_errors) = true_encoding.decode(&reencoded);
        let repaired_text = decoded.into_owned();
        if repaired_text.trim().is_empty() || !seen.insert(repaired_text.clone()) {
            continue;
        }

        let score = score_decoded_text(&repaired_text, had_encode_errors || had_decode_errors);
        candidates.push(RepairCandidate {
            chain: format!("{} → {}", wrong_encoding_label, true_encoding_label),
            repaired_text,
            score,
        });
    }

    candidates.sort_by(|lhs, rhs| rhs.score.total_cmp(&lhs.score));
    candidates
}

pub fn extract_text_from_binary(bytes: &[u8], encoding_label: &str) -> BinaryTextExtraction {
    let encoding = Encoding::for_label(encoding_label.as_bytes()).unwrap_or(UTF_8);
    let mut regions = Vec::new();
    let mut readable_segments = Vec::new();
    let mut index = 0usize;

    while index < bytes.len() {
        if bytes[index] == 0x00 || bytes[index] == 0xFF {
            let padding_start = index;
            while index < bytes.len() && (bytes[index] == 0x00 || bytes[index] == 0xFF) {
                index += 1;
            }
            regions.push(BinaryTextRegion {
                offset: padding_start as u64,
                length: (index - padding_start) as u64,
                decoded: String::new(),
                raw_bytes: bytes[padding_start..index].to_vec(),
                is_padding: true,
            });
            continue;
        }

        let text_start = index;
        while index < bytes.len() && bytes[index] != 0x00 && bytes[index] != 0xFF {
            index += 1;
        }

        let slice = &bytes[text_start..index];
        let (decoded, _, _) = encoding.decode(slice);
        let decoded = decoded.into_owned();
        if !decoded.trim().is_empty() {
            readable_segments.push(decoded.clone());
        }
        regions.push(BinaryTextRegion {
            offset: text_start as u64,
            length: slice.len() as u64,
            decoded,
            raw_bytes: slice.to_vec(),
            is_padding: false,
        });
    }

    BinaryTextExtraction {
        readable_text: readable_segments.join("\n···\n"),
        regions,
    }
}

fn score_decoded_text(text: &str, had_errors: bool) -> f64 {
    let total = text.chars().count().max(1) as f64;
    let printable = text
        .chars()
        .filter(|character| !character.is_control() || matches!(character, '\n' | '\r' | '\t'))
        .count() as f64;
    let alphanumeric = text.chars().filter(|character| character.is_alphanumeric()).count() as f64;
    let whitespace = text.chars().filter(|character| character.is_whitespace()).count() as f64;
    let replacement_count = text.chars().filter(|&character| character == '\u{FFFD}').count() as f64;
    let control_count = text
        .chars()
        .filter(|character| character.is_control() && !matches!(character, '\n' | '\r' | '\t'))
        .count() as f64;
    let mojibake_hits = COMMON_MOJIBAKE_MARKERS
        .iter()
        .map(|marker| text.matches(marker).count())
        .sum::<usize>() as f64;

    let mut score = 0.0;
    score += (printable / total) * 0.45;
    score += (alphanumeric / total) * 0.30;
    score += (whitespace / total).min(0.25) * 0.15;
    score -= (replacement_count / total) * 1.6;
    score -= (control_count / total) * 1.2;
    score -= (mojibake_hits / total) * 0.8;
    if had_errors {
        score -= 0.15;
    }
    score.clamp(0.0, 1.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn classify_replacement_clusters_as_corrupted() {
        let analysis = classify_corruption(
            "This line is mostly intact but ends with clustered damage \u{FFFD}\u{FFFD}",
            "utf-8",
        );
        assert_eq!(analysis.classification, "replacement_char_clusters");
        assert!(analysis.replacement_ratio > 0.0);
    }

    #[test]
    fn repair_common_cp1252_utf8_mojibake() {
        let candidates = repair_mojibake("FranÃ§ais".as_bytes());
        assert!(!candidates.is_empty());
        assert_eq!(candidates[0].repaired_text, "Français");
    }

    #[test]
    fn extract_binary_regions_separates_padding_and_text() {
        let extraction = extract_text_from_binary(b"Hello\x00\x00World\xFFDone", "utf-8");
        assert_eq!(extraction.regions.len(), 5);
        assert_eq!(extraction.regions[0].decoded, "Hello");
        assert!(extraction.regions[1].is_padding);
        assert!(extraction.readable_text.contains("World"));
        assert!(extraction.readable_text.contains("Done"));
    }
}
