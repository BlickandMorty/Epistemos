.PHONY: test test-rust test-swift build-rust build clean

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

# Full Xcode build
build:
	xcodebuild -project Epistemos.xcodeproj -scheme Epistemos \
		-destination 'platform=macOS' build 2>&1 | tail -5

# Clean build artifacts
clean:
	cd graph-engine && cargo clean
	xcodebuild -project Epistemos.xcodeproj -scheme Epistemos clean 2>&1 | tail -3
