use exports::example::schema::my_interface::{Guest, GuestMyRes};

wit_bindgen::generate!({
    path: "../protocol.wit",
});

struct MyRes;

impl GuestMyRes for MyRes {
    fn new() -> Self {
        println!("NEW");
        Self
    }

    fn my_method(&self, _value: f32) {
        println!("METHOD");
    }
}

struct GuestImpl;

impl Guest for GuestImpl {
    type MyRes = MyRes;
}

export!(GuestImpl);
