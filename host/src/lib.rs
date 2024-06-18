use tracing::info;
use wasm_bridge::{
    component::{Component, Linker},
    Config, Engine, Result, Store,
};
use wasm_bridge_wasi::{add_to_linker_async, ResourceTable, WasiCtx, WasiCtxBuilder, WasiView};

wasm_bridge::component::bindgen!({
    path: "../protocol.wit",
    async: true
});

struct State {
    table: ResourceTable,
    wasi: WasiCtx,
}

impl WasiView for State {
    fn table(&mut self) -> &mut ResourceTable {
        &mut self.table
    }

    fn ctx(&mut self) -> &mut WasiCtx {
        &mut self.wasi
    }
}

pub async fn run_test(component_bytes: &[u8]) -> Result<()> {
    info!("Running test...");

    let mut config = Config::new();
    config.wasm_component_model(true);
    config.async_support(true);

    let table = ResourceTable::new();
    let wasi = WasiCtxBuilder::new().inherit_stdout().build();

    let engine = Engine::new(&config).unwrap();
    let mut store = Store::new(&engine, State { table, wasi });

    let component = Component::new_safe(&store.engine(), &component_bytes)
        .await
        .unwrap();

    let mut linker = Linker::new(store.engine());
    add_to_linker_async(&mut linker).unwrap();

    let (instance, _) = MyWorld::instantiate_async(&mut store, &component, &linker)
        .await
        .unwrap();

    let interface = instance.example_schema_my_interface().my_res();
    let res = interface.call_constructor(&mut store).await.unwrap();

    interface
        .call_my_method(&mut store, res, 1.0)
        .await
        .unwrap();

    Ok(())
}
