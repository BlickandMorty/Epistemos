#!/usr/bin/env python3
from pathlib import Path

TARGET = Path("EpistemosTests/MemoryStressTests.swift")
START = "// BEGIN GENERATED RELIABILITY MATRIX TESTS"
END = "// END GENERATED RELIABILITY MATRIX TESTS"
ANCHOR = "// MARK: - Required Imports for Memory Tracking"

snippet = f"""
{START}
@Suite("Generated Reliability Matrix")
@MainActor
struct GeneratedReliabilityMatrixTests {{

    @Test("benchmark parser throughput envelope", arguments: Array(0..<200))
    func benchmarkParserThroughputEnvelope(_ i: Int) {{
        let iterations = 40 + (i % 40)
        let start = ContinuousClock().now

        for j in 0..<iterations {{
            let query = "find topic \\(i)-\\(j) with references and synthesis"
            _ = QueryParser.parse(query)

            let markdown = \"\"\"
            # Heading \\(i)-\\(j)
            > Citation block \\(i)-\\(j)
            [Source \\(i)-\\(j)](https://example.com/\\(i)/\\(j))
            \"\"\"
            let toc = TOCParser.parse(markdown)
            #expect(!toc.isEmpty)

            let diff = LineDiff.compute(
                old: "alpha \\(i)-\\(j)\\nshared line",
                new: "alpha \\(i)-\\(j) updated\\nshared line\\nextra"
            )
            #expect(!diff.lines.isEmpty)
        }}

        let elapsed = ContinuousClock().now - start
        #expect(elapsed < .seconds(2), "Parser throughput case \\(i) exceeded budget: \\(elapsed)")
    }}

    @Test("graph load and traversal budget", arguments: Array(0..<200))
    func graphLoadAndTraversalBudget(_ i: Int) {{
        let nodeSizes = [64, 128, 256, 384, 512, 640]
        let nodeCount = nodeSizes[i % nodeSizes.count]
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: nodeCount)

        let store = GraphStore()
        let start = ContinuousClock().now
        store.loadDirect(nodes: nodes, edges: edges)

        let _ = store.fuzzySearch(query: "Test Node", limit: 30)
        let _ = store.connected(to: nodes[i % nodes.count].id, maxDepth: 3)
        let elapsed = ContinuousClock().now - start

        let budgetMs = 450 + (nodeCount * 2)
        #expect(store.nodeCount == nodeCount)
        #expect(elapsed < .milliseconds(budgetMs), "Graph workload \\(nodeCount) exceeded budget \\(budgetMs)ms: \\(elapsed)")
    }}

    @Test("memory growth bounded for repeated query cycles", arguments: Array(0..<200))
    func memoryGrowthBoundedForRepeatedQueryCycles(_ i: Int) {{
        let store = GraphStore()
        let nodeCount = 256 + ((i % 4) * 128)
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: nodeCount)
        store.loadDirect(nodes: nodes, edges: edges)

        let before = MemoryTracker.currentMemoryUsage()

        for j in 0..<60 {{
            autoreleasepool {{
                let _ = store.fuzzySearch(query: "query-\\(i)-\\(j)", limit: 20)
                let target = nodes[(i + j) % nodes.count].id
                let _ = store.connected(to: target, maxDepth: 2 + (j % 2))
            }}
        }}

        let after = MemoryTracker.currentMemoryUsage()
        let growth = after > before ? after - before : 0
        #expect(growth < 120_000_000, "Memory growth too high for case \\(i): \\(growth) bytes")
    }}

    @Test("malformed inputs are crash resistant", arguments: Array(0..<200))
    func malformedInputsAreCrashResistant(_ i: Int) {{
        let payloadA = String(repeating: "[", count: 128 + (i % 256))
        let payloadB = String(repeating: "\\\\", count: 64 + (i % 128))
        let payloadC = String(repeating: ">", count: 64 + (i % 128))

        _ = QueryParser.parse(payloadA + payloadB + payloadC)
        let toc = TOCParser.parse(payloadA + "\\n" + payloadC)
        let diff = LineDiff.compute(old: payloadA, new: payloadA + payloadB)

        #expect(toc.count >= 0)
        #expect(diff.lines.count >= 1)
    }}

    @Test("soft failure recovery keeps core paths healthy", arguments: Array(0..<200))
    func softFailureRecoveryKeepsCorePathsHealthy(_ i: Int) {{
        let store = GraphStore()
        let (nodes, edges) = GraphTestDataGenerator.generateConnectedGraph(nodeCount: 200)
        store.loadDirect(nodes: nodes, edges: edges)

        let malformed = String(repeating: "]", count: 256 + (i % 128))
        _ = QueryParser.parse(malformed)
        _ = TOCParser.parse(malformed)
        _ = LineDiff.compute(old: malformed, new: malformed + "x")

        let connected = store.connected(to: nodes[0].id, maxDepth: 3)
        let parsed = QueryParser.parse("all notes")

        if case .findNodes(let filter) = parsed {{
            #expect(filter.types?.contains(.note) == true)
        }} else {{
            Issue.record("Recovery parser check failed for case \\(i)")
        }}

        #expect(store.nodeCount == nodes.count)
        #expect(!connected.isEmpty)
    }}

    @Test("concurrent parser and diff stress", arguments: Array(0..<200))
    func concurrentParserAndDiffStress(_ i: Int) async {{
        let completed = await withTaskGroup(of: Bool.self, returning: Int.self) {{ group in
            for worker in 0..<8 {{
                group.addTask {{
                    for j in 0..<25 {{
                        let query = "path from node\\(i)-\\(worker)-\\(j) to node\\(j)-\\(i)"
                        await MainActor.run {{
                            _ = QueryParser.parse(query)
                            _ = LineDiff.compute(old: "a\\(j)", new: "a\\(j)-\\(i)")
                        }}
                    }}
                    return true
                }}
            }}

            var successes = 0
            for await ok in group {{
                if ok {{
                    successes += 1
                }}
            }}
            return successes
        }}

        #expect(completed == 8, "Expected 8 worker completions, got \\(completed)")
    }}
}}
{END}
"""


def inject() -> None:
    text = TARGET.read_text()

    if START in text and END in text:
        before = text.split(START)[0].rstrip()
        after = text.split(END)[1].lstrip()
        new_text = before + "\n\n" + snippet.strip() + "\n\n" + after
    elif ANCHOR in text:
        before, after = text.split(ANCHOR, 1)
        new_text = before.rstrip() + "\n\n" + snippet.strip() + "\n\n" + ANCHOR + after
    else:
        new_text = text.rstrip() + "\n\n" + snippet.strip() + "\n"

    TARGET.write_text(new_text)
    print("Injected generated reliability matrix tests into EpistemosTests/MemoryStressTests.swift")


if __name__ == "__main__":
    inject()
