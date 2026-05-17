# Epistemos Third-Party License Attribution

Epistemos incorporates the following open-source libraries and frameworks.

## Swift Dependencies

| Library | License | Purpose |
|---------|---------|---------|
| [GRDB](https://github.com/groue/GRDB.swift) | MIT | SQLite database layer |
| [MLX Swift](https://github.com/ml-explore/mlx-swift) | MIT | On-device ML inference (Apple Silicon) |
| [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-examples) | MIT | Language model inference |
| [AXorcist](https://github.com/steipete/AXorcist) | MIT | Accessibility API (fuzzy AX queries) |
| [swift-sdk (MCP)](https://github.com/modelcontextprotocol/swift-sdk) | MIT | Model Context Protocol client/server |
| [swift-subprocess](https://github.com/swiftlang/swift-subprocess) | Apache 2.0 | Process management |
| [Grape](https://github.com/nicklama/Grape) | MIT | Force-directed graph visualization |

## Rust Dependencies

| Crate | License | Purpose |
|-------|---------|---------|
| [tokio](https://tokio.rs) | MIT | Async runtime |
| [reqwest](https://github.com/seanmonstar/reqwest) | MIT/Apache 2.0 | HTTP client for agent_core web/provider tools and omega-mcp HTTPS integrations |
| [rusqlite](https://github.com/rusqlite/rusqlite) | MIT | SQLite bindings |
| [tantivy](https://github.com/quickwit-oss/tantivy) | MIT | Full-text search engine |
| [UniFFI](https://github.com/mozilla/uniffi-rs) | MPL 2.0 | Rust-Swift FFI bridge |
| [serde](https://serde.rs) | MIT/Apache 2.0 | Serialization framework |
| [git2](https://github.com/rust-lang/git2-rs) | MIT/Apache 2.0 | Git integration |
| [nix](https://github.com/nix-rust/nix) | MIT | POSIX API bindings (PTY) |
| [cozo](https://github.com/cozodb/cozo) | MPL 2.0 | Graph database engine |
| [usearch](https://github.com/unum-cloud/usearch) | Apache 2.0 | Vector similarity search |
| [tree-sitter](https://tree-sitter.github.io) | MIT | Source code parsing |

## Python Dependencies (hermes-agent subprocess)

| Package | License | Purpose |
|---------|---------|---------|
| [anthropic](https://github.com/anthropics/anthropic-sdk-python) | MIT | Anthropic API client |
| [openai](https://github.com/openai/openai-python) | MIT | OpenAI API client |

## Model Licenses

Models are downloaded separately by the user and are not bundled with Epistemos:

| Model | License | Notes |
|-------|---------|-------|
| Qwen 2.5 / Qwen 3.5 | Apache 2.0 | Default local model |
| Hermes 3 (NousResearch) | Apache 2.0 | Tool-calling local model |

## Full License Texts

Full license texts for all dependencies are available in their respective repositories linked above. The MIT license text is reproduced below as it covers the majority of dependencies:

```
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
