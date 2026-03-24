// RecipeManager: stores/loads JSON workflow templates (Ghost OS pattern).
// Recipes are parameterized multi-step macros that can be replayed.
// Successful multi-step workflows are saved as reusable recipes.

use serde::{Deserialize, Serialize};
use rusqlite::{Connection, params};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum RecipeError {
    #[error("SQLite error: {0}")]
    Sqlite(#[from] rusqlite::Error),
    #[error("Recipe '{0}' not found")]
    NotFound(String),
    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),
}

/// A reusable workflow template.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Recipe {
    pub id: String,
    pub name: String,
    pub description: String,
    /// JSON array of step templates.
    pub steps_json: String,
    /// Parameters that can be substituted at execution time.
    pub parameters: Vec<RecipeParameter>,
    pub created_at: String,
    pub use_count: u64,
}

/// A parameter that can be substituted into a recipe at runtime.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecipeParameter {
    pub name: String,
    pub description: String,
    pub param_type: String, // "string", "number", "boolean", "path"
    pub default_value: Option<String>,
    pub required: bool,
}

/// Manages recipe storage in SQLite.
pub struct RecipeManager {
    conn: Connection,
}

impl RecipeManager {
    pub fn open(path: &str) -> Result<Self, RecipeError> {
        let conn = Connection::open(path)?;
        conn.execute_batch("PRAGMA journal_mode=WAL;")?;
        conn.execute(
            "CREATE TABLE IF NOT EXISTS recipes (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                steps_json TEXT NOT NULL,
                parameters_json TEXT NOT NULL DEFAULT '[]',
                created_at TEXT NOT NULL,
                use_count INTEGER NOT NULL DEFAULT 0
            )",
            [],
        )?;
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_recipes_name ON recipes(name)",
            [],
        )?;
        Ok(RecipeManager { conn })
    }

    pub fn open_in_memory() -> Result<Self, RecipeError> {
        let conn = Connection::open_in_memory()?;
        conn.execute(
            "CREATE TABLE IF NOT EXISTS recipes (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                description TEXT NOT NULL DEFAULT '',
                steps_json TEXT NOT NULL,
                parameters_json TEXT NOT NULL DEFAULT '[]',
                created_at TEXT NOT NULL,
                use_count INTEGER NOT NULL DEFAULT 0
            )",
            [],
        )?;
        Ok(RecipeManager { conn })
    }

    /// Save a recipe (insert or update).
    pub fn save(&self, recipe: &Recipe) -> Result<(), RecipeError> {
        let params_json = serde_json::to_string(&recipe.parameters)?;
        self.conn.execute(
            "INSERT INTO recipes (id, name, description, steps_json, parameters_json, created_at, use_count)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
             ON CONFLICT(id) DO UPDATE SET name=?2, description=?3, steps_json=?4, parameters_json=?5, use_count=?7",
            params![recipe.id, recipe.name, recipe.description, recipe.steps_json, params_json, recipe.created_at, recipe.use_count],
        )?;
        Ok(())
    }

    /// Load a recipe by ID.
    pub fn load(&self, id: &str) -> Result<Recipe, RecipeError> {
        self.conn.query_row(
            "SELECT id, name, description, steps_json, parameters_json, created_at, use_count FROM recipes WHERE id = ?1",
            params![id],
            |row| {
                let params_json: String = row.get(4)?;
                let parameters: Vec<RecipeParameter> = serde_json::from_str(&params_json).unwrap_or_default();
                Ok(Recipe {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    description: row.get(2)?,
                    steps_json: row.get(3)?,
                    parameters,
                    created_at: row.get(5)?,
                    use_count: row.get::<_, i64>(6)? as u64,
                })
            },
        ).map_err(|_| RecipeError::NotFound(id.to_string()))
    }

    /// List all recipes.
    pub fn list(&self) -> Result<Vec<Recipe>, RecipeError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, name, description, steps_json, parameters_json, created_at, use_count FROM recipes ORDER BY use_count DESC"
        )?;
        let rows = stmt.query_map([], |row| {
            let params_json: String = row.get(4)?;
            let parameters: Vec<RecipeParameter> = serde_json::from_str(&params_json).unwrap_or_default();
            Ok(Recipe {
                id: row.get(0)?,
                name: row.get(1)?,
                description: row.get(2)?,
                steps_json: row.get(3)?,
                parameters,
                created_at: row.get(5)?,
                use_count: row.get::<_, i64>(6)? as u64,
            })
        })?;
        let mut recipes = Vec::new();
        for row in rows {
            recipes.push(row?);
        }
        Ok(recipes)
    }

    /// Increment use count for a recipe.
    pub fn increment_use(&self, id: &str) -> Result<(), RecipeError> {
        self.conn.execute(
            "UPDATE recipes SET use_count = use_count + 1 WHERE id = ?1",
            params![id],
        )?;
        Ok(())
    }

    /// Delete a recipe.
    pub fn delete(&self, id: &str) -> Result<bool, RecipeError> {
        let rows = self.conn.execute("DELETE FROM recipes WHERE id = ?1", params![id])?;
        Ok(rows > 0)
    }

    /// Count recipes.
    pub fn count(&self) -> Result<u64, RecipeError> {
        let count: i64 = self.conn.query_row("SELECT COUNT(*) FROM recipes", [], |row| row.get(0))?;
        Ok(count as u64)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_recipe(id: &str, name: &str) -> Recipe {
        Recipe {
            id: id.to_string(),
            name: name.to_string(),
            description: format!("Recipe: {name}"),
            steps_json: r#"[{"agent":"safari","tool":"open_url","args":{"url":"{{url}}"}}]"#.to_string(),
            parameters: vec![RecipeParameter {
                name: "url".to_string(),
                description: "URL to open".to_string(),
                param_type: "string".to_string(),
                default_value: Some("https://apple.com".to_string()),
                required: true,
            }],
            created_at: "2026-03-24T12:00:00Z".to_string(),
            use_count: 0,
        }
    }

    #[test]
    fn test_save_and_load() {
        let mgr = RecipeManager::open_in_memory().unwrap();
        let recipe = make_recipe("r-1", "Open Website");
        mgr.save(&recipe).unwrap();
        let loaded = mgr.load("r-1").unwrap();
        assert_eq!(loaded.name, "Open Website");
        assert_eq!(loaded.parameters.len(), 1);
        assert_eq!(loaded.parameters[0].name, "url");
    }

    #[test]
    fn test_list_sorted_by_use() {
        let mgr = RecipeManager::open_in_memory().unwrap();
        let mut r1 = make_recipe("r-1", "Less Used");
        r1.use_count = 1;
        let mut r2 = make_recipe("r-2", "More Used");
        r2.use_count = 10;
        mgr.save(&r1).unwrap();
        mgr.save(&r2).unwrap();
        let list = mgr.list().unwrap();
        assert_eq!(list[0].name, "More Used"); // Sorted by use_count DESC
    }

    #[test]
    fn test_increment_use() {
        let mgr = RecipeManager::open_in_memory().unwrap();
        mgr.save(&make_recipe("r-1", "Test")).unwrap();
        mgr.increment_use("r-1").unwrap();
        mgr.increment_use("r-1").unwrap();
        let loaded = mgr.load("r-1").unwrap();
        assert_eq!(loaded.use_count, 2);
    }

    #[test]
    fn test_delete() {
        let mgr = RecipeManager::open_in_memory().unwrap();
        mgr.save(&make_recipe("r-1", "Deleteme")).unwrap();
        assert!(mgr.delete("r-1").unwrap());
        assert!(!mgr.delete("r-1").unwrap());
        assert_eq!(mgr.count().unwrap(), 0);
    }

    #[test]
    fn test_not_found() {
        let mgr = RecipeManager::open_in_memory().unwrap();
        assert!(mgr.load("nope").is_err());
    }

    #[test]
    fn test_upsert() {
        let mgr = RecipeManager::open_in_memory().unwrap();
        mgr.save(&make_recipe("r-1", "V1")).unwrap();
        let mut updated = make_recipe("r-1", "V2");
        updated.use_count = 5;
        mgr.save(&updated).unwrap();
        let loaded = mgr.load("r-1").unwrap();
        assert_eq!(loaded.name, "V2");
        assert_eq!(loaded.use_count, 5);
        assert_eq!(mgr.count().unwrap(), 1);
    }
}
