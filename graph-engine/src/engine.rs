use crate::types::Graph;

pub struct Engine {
    pub graph: Graph,
    pub width: u32,
    pub height: u32,
}

impl Engine {
    pub fn new() -> Self {
        Self {
            graph: Graph::new(),
            width: 800,
            height: 600,
        }
    }

    pub fn resize(&mut self, width: u32, height: u32) {
        self.width = width;
        self.height = height;
    }

    pub fn render(&mut self) {
        // Placeholder — Metal rendering comes in Task 5
    }
}
