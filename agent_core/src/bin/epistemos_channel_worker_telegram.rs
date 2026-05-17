#[tokio::main]
async fn main() {
    agent_core::channels::worker::run_worker_binary(Some("telegram")).await;
}
