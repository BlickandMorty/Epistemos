.PHONY: test test-rust test-swift build-rust build-rust-release build deploy-rust build clean

# Run all tests (Rust + Swift)
test: test-rust test-swift

# Rust engine tests
test-rust:
	cd graph-engine && cargo test

# Swift tests via xcodebuild
test-swift:
	xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos \
		-destination 'platform=macOS' -only-testing:EpistemosTests \
		2>&1 | grep -E "✘|✔|Test Suite|Executed|error:" | tail -40

# Build Rust engine (debug)
build-rust:
	cd graph-engine && cargo build

# Build Rust engine (release, for embedding in app)
build-rust-release:
	cd graph-engine && cargo build --release

# Build + deploy Rust release binary to both link paths
deploy-rust: build-rust-release
	cp graph-engine/target/release/libgraph_engine.a graph-engine-bridge/libgraph_engine.a
	cp graph-engine/target/release/libgraph_engine.a build-rust/libgraph_engine.a

# Full Xcode build
build:
	xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
		-destination 'platform=macOS' build 2>&1 | tail -5

# Full release: Rust release + Xcode build
release: deploy-rust build

# Clean build artifacts
clean:
	cd graph-engine && cargo clean
	xcodebuild -project Epistemos.xcodeproj -scheme Epistemos clean 2>&1 | tail -3
