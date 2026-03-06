//! ECS component types — all `#[repr(C)]` for Metal FFI compatibility.
//! Padding bytes are explicit to prevent silent misalignment at the FFI boundary.

#[repr(C)]
#[derive(Clone, Copy, Debug, Default)]
pub struct TransformComponent {
    pub x: f32,
    pub y: f32,
    pub scale: f32,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default)]
pub struct VelocityComponent {
    pub vx: f32,
    pub vy: f32,
}

#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct HierarchyComponent {
    pub depth: u32,
    pub parent: u32,      // u32::MAX = no parent
    pub node_type: u8,
    pub _pad: [u8; 3],    // explicit padding for u32 alignment
    pub link_count: u32,
}

impl Default for HierarchyComponent {
    fn default() -> Self {
        Self {
            depth: 0,
            parent: u32::MAX,
            node_type: 0,
            _pad: [0; 3],
            link_count: 0,
        }
    }
}

#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BlockType {
    Core = 0,
    Primary = 1,
    Secondary = 2,
    Tertiary = 3,
    Leaf = 4,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AIState {
    Idle = 0,
    Swimming = 1,
    AvoidingCursor = 2,
    TrailingParent = 3,
    Excited = 4,
    Sleeping = 5,
}

#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct RenderComponent {
    pub block_type: u8,
    pub has_glare: u8,     // 0 = false, 1 = true (u8 for FFI safety)
    pub _pad: [u8; 2],    // explicit padding for f32 alignment
    pub color_override: [f32; 4], // [0,0,0,0] = use default palette
}

impl Default for RenderComponent {
    fn default() -> Self {
        Self {
            block_type: BlockType::Primary as u8,
            has_glare: 0,
            _pad: [0; 2],
            color_override: [0.0; 4],
        }
    }
}

#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct AIComponent {
    pub state: u8,
    pub _pad: [u8; 3],    // explicit padding for u32 alignment
    pub personality_seed: u32,
    pub breath_phase: f32,
    pub breath_freq: f32,
    pub wander_radius: f32,
    pub speed: f32,
}

impl Default for AIComponent {
    fn default() -> Self {
        Self {
            state: AIState::Idle as u8,
            _pad: [0; 3],
            personality_seed: 0,
            breath_phase: 0.0,
            breath_freq: 0.5,
            wander_radius: 5.0,
            speed: 1.0,
        }
    }
}
