use rustc_hash::FxHashMap;

/// Maps tree-sitter capture names (e.g. "keyword", "string", "comment")
/// to stable u16 kind IDs used in `SyntaxTokenSpan`.
///
/// ID 0 is reserved for "unknown". New names are assigned incrementally.
pub struct TokenRegistry {
    name_to_id: FxHashMap<String, u16>,
    id_to_name: Vec<String>,
}

impl TokenRegistry {
    pub fn new() -> Self {
        let mut reg = Self {
            name_to_id: FxHashMap::default(),
            id_to_name: Vec::with_capacity(128),
        };
        reg.id_to_name.push("unknown".to_string());
        reg.name_to_id.insert("unknown".to_string(), 0);
        reg
    }

    /// Returns the kind ID for a capture name, inserting it if new.
    /// Panics if more than u16::MAX distinct names are registered.
    pub fn intern(&mut self, name: &str) -> u16 {
        if let Some(&id) = self.name_to_id.get(name) {
            return id;
        }
        let id = self.id_to_name.len();
        assert!(id <= u16::MAX as usize, "token registry overflow");
        let id = id as u16;
        self.id_to_name.push(name.to_string());
        self.name_to_id.insert(name.to_string(), id);
        id
    }

    /// Look up a capture name by ID. Returns `None` for out-of-range IDs.
    pub fn name(&self, id: u16) -> Option<&str> {
        self.id_to_name.get(id as usize).map(|s| s.as_str())
    }

    /// Look up an ID by capture name.
    pub fn id(&self, name: &str) -> Option<u16> {
        self.name_to_id.get(name).copied()
    }

    pub fn len(&self) -> usize {
        self.id_to_name.len()
    }

    pub fn is_empty(&self) -> bool {
        self.id_to_name.len() <= 1
    }
}

impl Default for TokenRegistry {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unknown_is_zero() {
        let reg = TokenRegistry::new();
        assert_eq!(reg.id("unknown"), Some(0));
        assert_eq!(reg.name(0), Some("unknown"));
    }

    #[test]
    fn intern_new_names() {
        let mut reg = TokenRegistry::new();
        let kw = reg.intern("keyword");
        let str_id = reg.intern("string");
        let cmt = reg.intern("comment");

        assert_eq!(kw, 1);
        assert_eq!(str_id, 2);
        assert_eq!(cmt, 3);

        assert_eq!(reg.name(kw), Some("keyword"));
        assert_eq!(reg.name(str_id), Some("string"));
        assert_eq!(reg.name(cmt), Some("comment"));
    }

    #[test]
    fn intern_idempotent() {
        let mut reg = TokenRegistry::new();
        let id1 = reg.intern("keyword");
        let id2 = reg.intern("keyword");
        assert_eq!(id1, id2);
        assert_eq!(reg.len(), 2); // "unknown" + "keyword"
    }

    #[test]
    fn out_of_range_returns_none() {
        let reg = TokenRegistry::new();
        assert_eq!(reg.name(999), None);
    }

    #[test]
    fn is_empty_with_only_unknown() {
        let reg = TokenRegistry::new();
        assert!(reg.is_empty());
    }

    #[test]
    fn not_empty_after_intern() {
        let mut reg = TokenRegistry::new();
        reg.intern("keyword");
        assert!(!reg.is_empty());
    }
}
