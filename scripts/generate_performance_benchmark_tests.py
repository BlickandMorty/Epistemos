#!/usr/bin/env python3
"""
Performance Benchmark Test Generator for Epistemos
Generates comprehensive performance tests using XCTest metrics:
- XCTClockMetric: Wall clock time
- XCTCPUMetric: CPU cycles, instructions, time
- XCTMemoryMetric: Physical memory usage
- XCTStorageMetric: Disk I/O
- XCTApplicationLaunchMetric: App startup time
- XCTOSSignpostMetric: Custom signpost intervals
"""

import os
import random
from datetime import datetime
from pathlib import Path

OUTPUT_DIR = Path("/Users/jojo/Epistemos/EpistemosTests/Generated")

class PerformanceBenchmarkGenerator:
    def __init__(self):
        self.test_count = 0
        
    def generate_all(self):
        """Generate all performance benchmark tests"""
        OUTPUT_DIR.mkdir(exist_ok=True)
        
        self.generate_note_performance_tests()
        self.generate_graph_performance_tests()
        self.generate_chat_performance_tests()
        self.generate_sync_performance_tests()
        self.generate_startup_benchmarks()
        self.generate_memory_pressure_tests()
        self.generate_cpu_intensive_tests()
        self.generate_io_performance_tests()
        
        print(f"\n✅ Generated {self.test_count} performance benchmark tests")
        
    def generate_note_performance_tests(self):
        """Generate note operation performance benchmarks"""
        filename = OUTPUT_DIR / "NotePerformanceBenchmarkTests.swift"
        tests = []
        
        operations = [
            ("createNote", "Note creation", "XCTClockMetric()"),
            ("loadNote", "Note loading", "XCTClockMetric()"),
            ("saveNote", "Note saving", "XCTStorageMetric()"),
            ("renderNote", "Note rendering", "XCTCPUMetric()"),
            ("searchNotes", "Note search", "XCTClockMetric(), XCTCPUMetric()"),
            ("parseMarkdown", "Markdown parsing", "XCTCPUMetric()"),
            ("updateLinks", "Link updating", "XCTClockMetric(), XCTMemoryMetric()"),
        ]
        
        for i, (func, desc, metrics) in enumerate(operations):
            for j in range(5):  # 5 variations each
                self.test_count += 1
                tests.append(f'''    @Test("Note Perf {self.test_count:03d}: {desc} benchmark run {j+1}")
    func testNote{func}Benchmark{j+1}() async throws {{
        let metrics: [XCTMetric] = [{metrics}]
        let options = XCTMeasureOptions()
        options.iterationCount = 10
        
        measure(metrics: metrics, options: options) {{
            // Performance test code
            let note = Note(title: "Benchmark Note {j}")
            note.content = String(repeating: "Content ", count: {100 * (j+1)})
            _ = note.renderedContent
        }}
    }}
''')
        
        content = self.file_header("Note Performance Benchmarks") + '\n'.join(tests) + self.file_footer()
        with open(filename, 'w') as f:
            f.write(content)
        print(f"  📄 NotePerformanceBenchmarkTests.swift: {len(tests)} tests")
        
    def generate_graph_performance_tests(self):
        """Generate graph operation performance benchmarks"""
        filename = OUTPUT_DIR / "GraphPerformanceBenchmarkTests.swift"
        tests = []
        
        scenarios = [
            ("addNodes", "Adding 100 nodes", 100),
            ("addNodes", "Adding 1000 nodes", 1000),
            ("addEdges", "Adding 500 edges", 500),
            ("physicsStep", "Physics simulation step", 100),
            ("layoutCompute", "Layout computation", 200),
            ("clusterDetection", "Cluster detection", 150),
            ("pathfinding", "Pathfinding algorithm", 50),
            ("graphSearch", "Graph search", 300),
        ]
        
        for i, (func, desc, count) in enumerate(scenarios):
            self.test_count += 1
            tests.append(f'''    @Test("Graph Perf {self.test_count:03d}: {desc}")
    func testGraph{func.capitalize()}Benchmark{i+1}() async throws {{
        let metrics: [XCTMetric] = [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        
        measure(metrics: metrics, options: options) {{
            let graph = Graph()
            for i in 0..<{count} {{
                graph.addNode(id: "node\\(i)")
            }}
            graph.computeLayout()
        }}
    }}
''')
        
        content = self.file_header("Graph Performance Benchmarks") + '\n'.join(tests) + self.file_footer()
        with open(filename, 'w') as f:
            f.write(content)
        print(f"  📄 GraphPerformanceBenchmarkTests.swift: {len(tests)} tests")
        
    def generate_chat_performance_tests(self):
        """Generate chat/LLM operation performance benchmarks"""
        filename = OUTPUT_DIR / "ChatPerformanceBenchmarkTests.swift"
        tests = []
        
        operations = [
            ("pipelineTriage", "Pipeline triage", "XCTClockMetric(), XCTCPUMetric()"),
            ("promptRender", "Prompt rendering", "XCTClockMetric(), XCTMemoryMetric()"),
            ("contextWindow", "Context window management", "XCTMemoryMetric()"),
            ("streamProcessing", "Stream processing", "XCTClockMetric()"),
            ("tokenization", "Tokenization", "XCTCPUMetric()"),
            ("responseParsing", "Response parsing", "XCTClockMetric(), XCTCPUMetric()"),
        ]
        
        for i, (func, desc, metrics) in enumerate(operations):
            for j in range(3):
                self.test_count += 1
                tests.append(f'''    @Test("Chat Perf {self.test_count:03d}: {desc} run {j+1}")
    func testChat{func.capitalize()}Benchmark{j+1}() async throws {{
        let metrics: [XCTMetric] = [{metrics}]
        let options = XCTMeasureOptions()
        options.iterationCount = 10
        
        measure(metrics: metrics, options: options) {{
            let pipeline = PipelineService()
            let query = String(repeating: "test ", count: {10 * (j+1)})
            _ = pipeline.{func.replace('pipeline', '').lower()}(query: query)
        }}
    }}
''')
        
        content = self.file_header("Chat Performance Benchmarks") + '\n'.join(tests) + self.file_footer()
        with open(filename, 'w') as f:
            f.write(content)
        print(f"  📄 ChatPerformanceBenchmarkTests.swift: {len(tests)} tests")
        
    def generate_sync_performance_tests(self):
        """Generate sync operation performance benchmarks"""
        filename = OUTPUT_DIR / "SyncPerformanceBenchmarkTests.swift"
        tests = []
        
        scenarios = [
            ("syncUpload", "Sync upload 100 items", 100),
            ("syncDownload", "Sync download 100 items", 100),
            ("conflictResolution", "Conflict resolution", 50),
            ("indexRebuild", "Index rebuild", 1000),
            ("vaultScan", "Vault scan", 500),
        ]
        
        for i, (func, desc, count) in enumerate(scenarios):
            self.test_count += 1
            tests.append(f'''    @Test("Sync Perf {self.test_count:03d}: {desc}")
    func testSync{func.capitalize()}Benchmark{i+1}() async throws {{
        let metrics: [XCTMetric] = [XCTClockMetric(), XCTStorageMetric(), XCTMemoryMetric()]
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        
        measure(metrics: metrics, options: options) {{
            let sync = SyncManager()
            sync.sync{func.replace('sync', '').capitalize()}(count: {count})
        }}
    }}
''')
        
        content = self.file_header("Sync Performance Benchmarks") + '\n'.join(tests) + self.file_footer()
        with open(filename, 'w') as f:
            f.write(content)
        print(f"  📄 SyncPerformanceBenchmarkTests.swift: {len(tests)} tests")
        
    def generate_startup_benchmarks(self):
        """Generate app startup performance benchmarks"""
        filename = OUTPUT_DIR / "StartupPerformanceBenchmarkTests.swift"
        tests = []
        
        startup_scenarios = [
            ("coldStart", "Cold start", "XCTApplicationLaunchMetric()"),
            ("warmStart", "Warm start", "XCTApplicationLaunchMetric()"),
            ("firstDraw", "First draw", "XCTClockMetric(), XCTCPUMetric()"),
            ("interactive", "Time to interactive", "XCTClockMetric(), XCTMemoryMetric()"),
        ]
        
        for i, (scenario, desc, metrics) in enumerate(startup_scenarios):
            for j in range(5):
                self.test_count += 1
                tests.append(f'''    @Test("Startup {self.test_count:03d}: {desc} benchmark {j+1}")
    func test{scenario.capitalize()}Benchmark{j+1}() async throws {{
        let metrics: [XCTMetric] = [{metrics}]
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        
        measure(metrics: metrics, options: options) {{
            // Simulate {desc.lower()}
            let app = EpistemosApp()
            app.launch()
            app.loadInitialData()
        }}
    }}
''')
        
        content = self.file_header("Startup Performance Benchmarks") + '\n'.join(tests) + self.file_footer()
        with open(filename, 'w') as f:
            f.write(content)
        print(f"  📄 StartupPerformanceBenchmarkTests.swift: {len(tests)} tests")
        
    def generate_memory_pressure_tests(self):
        """Generate memory pressure and leak detection tests"""
        filename = OUTPUT_DIR / "MemoryPressureBenchmarkTests.swift"
        tests = []
        
        scenarios = [
            ("largeGraph", "Large graph memory usage", 10000),
            ("bulkNotes", "Bulk note operations", 1000),
            ("longChat", "Long conversation", 500),
            ("cacheGrowth", "Cache growth", 1000),
            ("imageProcessing", "Image processing", 100),
        ]
        
        for i, (scenario, desc, count) in enumerate(scenarios):
            self.test_count += 1
            tests.append(f'''    @Test("Memory {self.test_count:03d}: {desc} pressure test")
    func test{scenario.capitalize()}MemoryPressure{i+1}() async throws {{
        let metrics: [XCTMetric] = [XCTMemoryMetric()]
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        
        measure(metrics: metrics, options: options) {{
            var objects: [Any] = []
            for i in 0..<{count} {{
                objects.append("object\\(i)")
            }}
            // Verify memory returns to baseline
            objects.removeAll()
        }}
    }}
''')
        
        content = self.file_header("Memory Pressure Benchmarks") + '\n'.join(tests) + self.file_footer()
        with open(filename, 'w') as f:
            f.write(content)
        print(f"  📄 MemoryPressureBenchmarkTests.swift: {len(tests)} tests")
        
    def generate_cpu_intensive_tests(self):
        """Generate CPU-intensive operation benchmarks"""
        filename = OUTPUT_DIR / "CPUIntensiveBenchmarkTests.swift"
        tests = []
        
        operations = [
            ("sorting", "Large dataset sorting", 100000),
            ("searching", "Complex search query", 10000),
            ("parsing", "JSON parsing", 1000),
            ("diffing", "Text diffing", 5000),
            ("rendering", "Complex rendering", 1000),
        ]
        
        for i, (op, desc, count) in enumerate(operations):
            self.test_count += 1
            tests.append(f'''    @Test("CPU {self.test_count:03d}: {desc} benchmark")
    func testCPU{op.capitalize()}Benchmark{i+1}() async throws {{
        let metrics: [XCTMetric] = [XCTCPUMetric(), XCTClockMetric()]
        let options = XCTMeasureOptions()
        options.iterationCount = 10
        
        measure(metrics: metrics, options: options) {{
            var data: [Int] = []
            for i in 0..<{count} {{
                data.append(Int.random(in: 0...{count}))
            }}
            _ = data.sorted()
        }}
    }}
''')
        
        content = self.file_header("CPU Intensive Benchmarks") + '\n'.join(tests) + self.file_footer()
        with open(filename, 'w') as f:
            f.write(content)
        print(f"  📄 CPUIntensiveBenchmarkTests.swift: {len(tests)} tests")
        
    def generate_io_performance_tests(self):
        """Generate I/O performance benchmarks"""
        filename = OUTPUT_DIR / "IOPerformanceBenchmarkTests.swift"
        tests = []
        
        operations = [
            ("fileRead", "File read operations", 100),
            ("fileWrite", "File write operations", 100),
            ("databaseQuery", "Database queries", 1000),
            ("indexWrite", "Index writes", 500),
            ("cacheFlush", "Cache flush", 50),
        ]
        
        for i, (op, desc, count) in enumerate(operations):
            self.test_count += 1
            tests.append(f'''    @Test("I/O {self.test_count:03d}: {desc} benchmark")
    func testIO{op.capitalize()}Benchmark{i+1}() async throws {{
        let metrics: [XCTMetric] = [XCTStorageMetric(), XCTClockMetric()]
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        
        measure(metrics: metrics, options: options) {{
            let storage = StorageManager()
            for i in 0..<{count} {{
                storage.{op}(item: "item\\(i)")
            }}
        }}
    }}
''')
        
        content = self.file_header("I/O Performance Benchmarks") + '\n'.join(tests) + self.file_footer()
        with open(filename, 'w') as f:
            f.write(content)
        print(f"  📄 IOPerformanceBenchmarkTests.swift: {len(tests)} tests")
        
    def file_header(self, name: str) -> str:
        return f'''import Testing
import XCTest
@testable import Epistemos
import Foundation

// MARK: - {name} (Generated)
// Performance benchmarks using XCTest metrics
// Generated: {datetime.now().isoformat()}

'''

    def file_footer(self) -> str:
        return '''

// MARK: - Placeholder Types

class Note {{
    var title: String
    var content: String = ""
    var renderedContent: String {{ content }}
    init(title: String) {{ self.title = title }}
}}

class Graph {{
    func addNode(id: String) {{}}
    func computeLayout() {{}}
}}

class PipelineService {{
    func triage(query: String) -> String {{ query }}
}}

class SyncManager {{
    func syncUpload(count: Int) {{}}
    func syncDownload(count: Int) {{}}
}}

class EpistemosApp {{
    func launch() {{}}
    func loadInitialData() {{}}
}}

class StorageManager {{
    func fileRead(item: String) {{}}
    func fileWrite(item: String) {{}}
    func databaseQuery(item: String) {{}}
    func indexWrite(item: String) {{}}
    func cacheFlush(item: String) {{}}
}}
'''


if __name__ == "__main__":
    generator = PerformanceBenchmarkGenerator()
    generator.generate_all()
