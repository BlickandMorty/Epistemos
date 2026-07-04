import EpistemosLlama
import Foundation

// Phase-0 spike A harness (Plan 1-MAS §7 / §11 R1): prove the embedded
// llama.cpp lane generates tokens via Metal INSIDE the App Sandbox with zero
// forbidden entitlements. Driven by scripts/llama-mas-sandbox-spike.sh, which
// signs this binary with app-sandbox=true and nothing else.

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    print("usage: llama-spike <model.gguf> [prompt] [maxNewTokens]")
    exit(2)
}

let modelPath = arguments[1]
let userPrompt = arguments.count >= 3 ? arguments[2] : "List three colors, comma separated."
let maxNewTokens = arguments.count >= 4 ? Int(arguments[3]) ?? 48 : 48

let sandboxContainerID = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"]
print("SPIKE sandboxed=\(sandboxContainerID != nil ? 1 : 0) container=\(sandboxContainerID ?? "-") model=\((modelPath as NSString).lastPathComponent)")

// Minimal instruct wrapping so -it models answer instead of continuing the
// text. Gemma-family markers; other models get the raw prompt (fine for a
// token-generation proof).
let prompt: String
if modelPath.lowercased().contains("gemma") {
    prompt = "<start_of_turn>user\n\(userPrompt)<end_of_turn>\n<start_of_turn>model\n"
} else {
    prompt = userPrompt
}

let engine = LlamaLocalChatEngine()
do {
    try await engine.load(modelURL: URL(fileURLWithPath: modelPath), contextTokens: 4096)
} catch {
    print("SPIKE-FAIL load error=\(error)")
    exit(1)
}

var finalStats: LocalChatRunStats?
do {
    for try await event in engine.stream(prompt: prompt, maxNewTokens: maxNewTokens) {
        switch event {
        case .token(let piece):
            FileHandle.standardOutput.write(Data(piece.utf8))
        case .finished(let stats):
            finalStats = stats
        }
    }
} catch {
    print("\nSPIKE-FAIL stream error=\(error)")
    exit(1)
}

await engine.unload()

guard let stats = finalStats else {
    print("\nSPIKE-FAIL no-final-stats")
    exit(1)
}
let tps = String(format: "%.1f", stats.tokensPerSecond)
print("\nSPIKE-PROOF tokens=\(stats.generatedTokens) prompt_tokens=\(stats.promptTokens) reason=\(stats.finishReason.rawValue) tps=\(tps)")
exit(stats.generatedTokens >= 8 ? 0 : 1)
