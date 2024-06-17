use tracing::info;

const BYTES: &[u8] = include_bytes!("../../target/wasm32-unknown-unknown/debug/guest.wasm");

#[cfg(target_family = "wasm")]
#[wasm_bindgen::prelude::wasm_bindgen(start)]
pub async fn start() {
    console_error_panic_hook::set_once();
    tracing_wasm::set_as_global_default();

    info!("start");
    host::run_test(BYTES).await.unwrap();
}

#[cfg(target_family = "wasm")]
fn main() {}

#[cfg(not(target_family = "wasm"))]
#[tokio::main]
async fn main() {
    tracing_subscriber::fmt().init();
    info!("main");
    host::run_test(BYTES).await.unwrap();
}
