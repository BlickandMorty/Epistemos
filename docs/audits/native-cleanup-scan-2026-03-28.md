# Native Cleanup Scan

> **Index status**: CANONICAL-OPERATIONAL — Append-only audit log; needed for state reconstruction. No copy to _consolidated.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



- Generated: Sat Mar 28 19:40:26 CDT 2026
- Root: `/Users/jojo/Downloads/Epistemos`

## Tool Availability
- ast-grep: missing
- periphery: missing
- cargo-machete: missing
- cargo-udeps: missing

## Immediate Install Commands
```bash
brew install ast-grep peripheryapp/periphery/periphery
cargo install cargo-machete
cargo install cargo-udeps
rustup toolchain install nightly
```

## Rule Files
- `/Users/jojo/Downloads/Epistemos/scripts/audit/ast-grep/legacy-runtime-ban-swift.yml`
- `/Users/jojo/Downloads/Epistemos/scripts/audit/ast-grep/observable-object-ban-swift.yml`
- `/Users/jojo/Downloads/Epistemos/scripts/audit/ast-grep/ffi-json-copy-ban-swift.yml`
- `/Users/jojo/Downloads/Epistemos/scripts/audit/ast-grep/legacy-runtime-ban-rust.yml`

### Fallback Legacy Runtime Grep
```bash
rg -n 'LocalSidecar|DeepSeek|\breasoner\b|mlx-openai-server|127\.0\.0\.1|\bSSE\b' '/Users/jojo/Downloads/Epistemos/Epistemos' '/Users/jojo/Downloads/Epistemos/graph-engine' '/Users/jojo/Downloads/Epistemos/graph-engine-bridge' --glob '!docs/**' --glob '!scripts/audit/**'
```

### Fallback SwiftUI Legacy State Grep
```bash
rg -n 'ObservableObject|@Published|objectWillChange' '/Users/jojo/Downloads/Epistemos/Epistemos'
```
    /Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/UI/KnowledgeFusionViewModel.swift:25:/// Follows Epistemos pattern: @MainActor @Observable (never ObservableObject).
    /Users/jojo/Downloads/Epistemos/Epistemos/KnowledgeFusion/MOHAWK/generate_epistemos_training_data.py:747:            # Find @Observable or @Published properties

### Fallback FFI JSON Copy Grep
```bash
rg -n 'JSONEncoder\(\)\.encode|JSONDecoder\(\)\.decode|JSONSerialization' '/Users/jojo/Downloads/Epistemos/Epistemos/Graph' '/Users/jojo/Downloads/Epistemos/Epistemos/Engine' '/Users/jojo/Downloads/Epistemos/graph-engine'
```
    /Users/jojo/Downloads/Epistemos/Epistemos/Graph/EntityExtractor.swift:356:        return try? JSONDecoder().decode(type, from: data)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:574:        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:626:        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:662:        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:704:        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:742:        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:790:        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:831:                          let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LLMService.swift:898:        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:576:        return try? JSONDecoder().decode(PreparedRetrievalIndexManifest.self, from: data)
    /Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalModelInfrastructure.swift:792:        let manifest = try JSONDecoder().decode(Manifest.self, from: data)

### Periphery Missing
```bash
printf 'periphery is not installed\n'
```
    periphery is not installed

### cargo-machete Missing
```bash
printf 'cargo-machete is not installed\n'
```
    cargo-machete is not installed

### cargo-udeps Missing
```bash
printf 'cargo-udeps is not installed\n'
```
    cargo-udeps is not installed

