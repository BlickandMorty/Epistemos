//! Paper Translation: IPC Bridge Latency and Multithreaded Race Conditions
//! Tests the Engine's Arc<Mutex> boundaries by hammering tick() and write() concurrently.
#[cfg(test)]
mod tests {
    use crate::simulation::Simulation;
    use crate::types::Graph;
    use std::sync::{Arc, Mutex};
    use std::thread;

    #[test]
    fn test_ffi_multithread_deadlock_stress() {
        // The FFI wrapper is single-threaded from Swift Main Actor typically, but background tasks may request data.
        // We simulate highly contentious reads/writes to the Simulation core to ensure no Mutex deadlocks.
        let sim = Arc::new(Mutex::new(Simulation::new()));
        let mut handles = vec![];

        // 10 Writer threads hammering graph rebuilding
        for i in 0..10 {
            let sim_clone = Arc::clone(&sim);
            handles.push(thread::spawn(move || {
                for j in 0..100 {
                    let mut g = Graph::new();
                    g.add_node(format!("n-{}-{}", i, j), 0.0, 0.0, 0, 1, format!("L"));
                    let mut lock = sim_clone.lock().unwrap();
                    lock.load_from_graph(&g);
                }
            }));
        }

        // 10 Reader threads hammering `tick` calculations
        for _ in 0..10 {
            let sim_clone = Arc::clone(&sim);
            handles.push(thread::spawn(move || {
                for _ in 0..200 {
                    let mut lock = sim_clone.lock().unwrap();
                    lock.tick();
                }
            }));
        }

        for h in handles {
            h.join().unwrap();
        }

        let lock = sim.lock().unwrap();
        assert!(lock.x.len() <= 1); // Only the very last `load_from_graph` remains
    }
}
