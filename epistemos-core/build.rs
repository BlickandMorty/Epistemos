fn main() {
    uniffi::generate_scaffolding("uniffi/epistemos_core.udl")
        .expect("UniFFI scaffolding generation failed");
}
