mod engine;

use std::ffi::c_void;

/// Create a new graph engine. Returns an opaque pointer.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_create(
    _metal_device: *mut c_void,
    _metal_layer: *mut c_void,
) -> *mut c_void {
    let engine = Box::new(engine::Engine::new());
    Box::into_raw(engine) as *mut c_void
}

/// Destroy the engine and free memory.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_destroy(ptr: *mut c_void) {
    if !ptr.is_null() {
        unsafe { drop(Box::from_raw(ptr as *mut engine::Engine)) };
    }
}

/// Render one frame. Called by MTKViewDelegate.draw().
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_render(ptr: *mut c_void) {
    if ptr.is_null() { return; }
    let engine = unsafe { &mut *(ptr as *mut engine::Engine) };
    engine.render();
}

/// Resize the viewport.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_resize(ptr: *mut c_void, width: u32, height: u32) {
    if ptr.is_null() { return; }
    let engine = unsafe { &mut *(ptr as *mut engine::Engine) };
    engine.resize(width, height);
}
