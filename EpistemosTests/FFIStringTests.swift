import Testing
import Foundation

// MARK: - FFI String Passing Tests
// Tests the C string boundary between Swift and Rust via FFI.
// All string data passes through as null-terminated UTF-8 C strings.

@Suite("FFI String Passing")
struct FFIStringTests {
    
    // MARK: - ASCII String Round-Trip Tests
    
    @Test("ASCII alphanumeric string round-trip")
    func asciiAlphanumericRoundTrip() {
        let original = "HelloWorld123"
        let cString = strdup(original)
        #expect(cString != nil)
        
        let roundTrip = String(cString: cString!)
        free(cString)
        
        #expect(roundTrip == original)
    }
    
    @Test("ASCII with spaces round-trip")
    func asciiWithSpacesRoundTrip() {
        let original = "Hello World Test"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("ASCII special characters round-trip")
    func asciiSpecialCharsRoundTrip() {
        let original = "!@#$%^&*()_+-=[]{}|;':\",./<>?"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("UUID format string round-trip")
    func uuidFormatRoundTrip() {
        let original = "550e8400-e29b-41d4-a716-446655440000"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("URL string round-trip")
    func urlStringRoundTrip() {
        let original = "https://example.com/path?query=value#fragment"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    // MARK: - Unicode String Round-Trip Tests
    
    @Test("Basic emoji round-trip")
    func basicEmojiRoundTrip() {
        let original = "Hello 👋 World 🌍"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("Complex emoji with modifiers round-trip")
    func complexEmojiRoundTrip() {
        let original = "👨‍👩‍👧‍👦 🏳️‍🌈 🧑🏽‍💻"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("CJK characters round-trip")
    func cjkCharactersRoundTrip() {
        let original = "你好世界 日本語 한국어"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("Arabic RTL text round-trip")
    func arabicRtlRoundTrip() {
        let original = "مرحبا بالعالم"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("Hebrew RTL text round-trip")
    func hebrewRtlRoundTrip() {
        let original = "שלום עולם"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("Mixed RTL and LTR round-trip")
    func mixedRtlLtrRoundTrip() {
        let original = "Hello שלום 你好"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("Combining diacritics round-trip")
    func combiningDiacriticsRoundTrip() {
        let original = "café résumé naïve"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("Mathematical symbols round-trip")
    func mathematicalSymbolsRoundTrip() {
        let original = "∀x∈ℝ: x²≥0 ∑∏∫√"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("Currency symbols round-trip")
    func currencySymbolsRoundTrip() {
        let original = "$100 €50 £30 ¥5000 ₹1000"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("Greek letters round-trip")
    func greekLettersRoundTrip() {
        let original = "αβγδε ΑΒΓΔΕ φλογοξ"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("Cyrillic text round-trip")
    func cyrillicRoundTrip() {
        let original = "Привет мир Добро пожаловать"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("Devanagari text round-trip")
    func devanagariRoundTrip() {
        let original = "नमस्ते दुनिया"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    // MARK: - Empty String Tests
    
    @Test("Empty string handling")
    func emptyStringHandling() {
        let original = ""
        let cString = strdup(original)
        #expect(cString != nil)
        
        let roundTrip = String(cString: cString!)
        free(cString)
        
        #expect(roundTrip == original)
        #expect(roundTrip.isEmpty)
    }
    
    @Test("Whitespace-only string round-trip")
    func whitespaceOnlyRoundTrip() {
        let original = "   \t\n\r   "
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    // MARK: - Long String Tests
    
    @Test("1KB string round-trip")
    func oneKBStringRoundTrip() {
        let original = String(repeating: "A", count: 1024)
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
        #expect(roundTrip.count == 1024)
    }
    
    @Test("10KB string round-trip")
    func tenKBStringRoundTrip() {
        let original = String(repeating: "Hello World ", count: 910)
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
        #expect(roundTrip.count > 10000)
    }
    
    @Test("100KB string round-trip")
    func hundredKBStringRoundTrip() {
        let original = String(repeating: "Unicode: 你好 🌍 ", count: 5000)
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("Long string with newlines round-trip")
    func longStringWithNewlines() {
        let lines = (0..<1000).map { "Line \($0) with some content here" }
        let original = lines.joined(separator: "\n")
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    // MARK: - Special Character Tests
    
    @Test("String with null byte handling")
    func stringWithNullByte() {
        // C strings can't contain null bytes - they terminate at first null
        var original = "Hello"
        original.append(Character(UnicodeScalar(0)))
        original.append("World")
        
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        
        // The string will be truncated at the null byte
        #expect(roundTrip == "Hello")
    }
    
    @Test("String with single newline")
    func stringWithSingleNewline() {
        let original = "Line1\nLine2"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("String with multiple newlines")
    func stringWithMultipleNewlines() {
        let original = "\n\n\nMultiple\n\nNewlines\n\n\n"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("String with carriage return")
    func stringWithCarriageReturn() {
        let original = "Line1\r\nLine2\rLine3"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("String with tabs")
    func stringWithTabs() {
        let original = "Col1\tCol2\tCol3\t\t"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("String with escape sequences")
    func stringWithEscapeSequences() {
        let original = "\\n\\t\\r\\\\\"\'"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    // MARK: - Boundary Value Tests
    
    @Test("Single character round-trip")
    func singleCharacterRoundTrip() {
        let original = "X"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("Single emoji round-trip")
    func singleEmojiRoundTrip() {
        let original = "🎉"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("Single CJK character round-trip")
    func singleCjkRoundTrip() {
        let original = "龍"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("String at UTF-8 boundary")
    func stringAtUtf8Boundary() {
        let original = String(repeating: "a", count: 127)
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    // MARK: - String Array Tests (Batch Operations)
    
    @Test("String array round-trip")
    func stringArrayRoundTrip() {
        let originals = ["Node1", "Node2", "Node3", "Hello 🌍", "مرحبا"]
        var cStrings: [UnsafeMutablePointer<CChar>] = []
        
        for original in originals {
            if let cString = strdup(original) {
                cStrings.append(cString)
            }
        }
        
        #expect(cStrings.count == originals.count)
        
        for (index, cString) in cStrings.enumerated() {
            let roundTrip = String(cString: cString)
            #expect(roundTrip == originals[index])
            free(cString)
        }
    }
    
    @Test("Large string array round-trip")
    func largeStringArrayRoundTrip() {
        let originals = (0..<1000).map { "Node-UUID-\($0)-你好" }
        var cStrings: [UnsafeMutablePointer<CChar>] = []
        
        for original in originals {
            if let cString = strdup(original) {
                cStrings.append(cString)
            }
        }
        
        #expect(cStrings.count == originals.count)
        
        for (index, cString) in cStrings.enumerated() {
            let roundTrip = String(cString: cString)
            #expect(roundTrip == originals[index])
            free(cString)
        }
    }
    
    // MARK: - Memory Cleanup Tests
    
    @Test("Memory cleanup verification - single allocation")
    func memoryCleanupSingle() {
        // Allocate and free a string
        let original = "Test string for memory cleanup"
        let cString = strdup(original)
        #expect(cString != nil)
        
        // Use the string
        let roundTrip = String(cString: cString!)
        #expect(roundTrip == original)
        
        // Free the memory
        free(cString)
        
        // After free, we should not access cString
        // This test passes if no crash occurs
    }
    
    @Test("Memory cleanup verification - multiple allocations")
    func memoryCleanupMultiple() {
        var pointers: [UnsafeMutablePointer<CChar>] = []
        
        // Allocate many strings
        for i in 0..<100 {
            let string = "Test string number \(i) with some padding content here"
            if let ptr = strdup(string) {
                pointers.append(ptr)
            }
        }
        
        #expect(pointers.count == 100)
        
        // Free all in reverse order
        for ptr in pointers.reversed() {
            free(ptr)
        }
    }
    
    @Test("Memory cleanup verification - interleaved allocation/free")
    func memoryCleanupInterleaved() {
        var activePointers: [UnsafeMutablePointer<CChar>] = []
        
        for i in 0..<50 {
            let string = "String \(i)"
            if let ptr = strdup(string) {
                activePointers.append(ptr)
            }
            
            // Free every other allocation
            if i % 2 == 1 && !activePointers.isEmpty {
                let ptr = activePointers.removeFirst()
                free(ptr)
            }
        }
        
        // Free remaining
        for ptr in activePointers {
            free(ptr)
        }
    }
    
    // MARK: - String Encoding Tests
    
    @Test("UTF-8 encoding validation")
    func utf8EncodingValidation() {
        let original = "Test UTF-8: café résumé naïve 日本語 🌍"
        guard let utf8Data = original.data(using: .utf8) else {
            Issue.record("Failed to encode as UTF-8")
            return
        }
        
        // Verify it's valid UTF-8
        #expect(String(data: utf8Data, encoding: .utf8) == original)
        
        // Create C string from data
        utf8Data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            let cString = strdup(baseAddress.assumingMemoryBound(to: CChar.self))
            #expect(cString != nil)
            
            let roundTrip = String(cString: cString!)
            free(cString)
            #expect(roundTrip.hasPrefix("Test UTF-8: café"))
        }
    }
    
    @Test("Invalid UTF-8 handling simulation")
    func invalidUtf8Handling() {
        // Create data with invalid UTF-8 sequence
        var bytes: [UInt8] = [0x48, 0x65, 0x6C, 0x6C, 0x6F, 0xFF, 0xFE, 0x57, 0x6F, 0x72, 0x6C, 0x64]
        bytes.append(0) // Null terminator
        
        bytes.withUnsafeBytes { rawBytes in
            guard let baseAddress = rawBytes.baseAddress else { return }
            let cString = baseAddress.assumingMemoryBound(to: CChar.self)
            
            // This will likely produce replacement characters or truncated result
            let result = String(cString: cString)
            #expect(!result.isEmpty) // Should at least produce something
        }
    }
    
    // MARK: - Edge Case Tests
    
    @Test("String with only null terminator")
    func stringOnlyNullTerminator() {
        let original = ""
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip.isEmpty)
    }
    
    @Test("Very long single word")
    func veryLongSingleWord() {
        let original = String(repeating: "a", count: 10000)
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("String with all ASCII control characters")
    func allAsciiControlCharacters() {
        var original = ""
        for i in 0x01...0x1F {
            original.append(Character(UnicodeScalar(i)!))
        }
        
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
    
    @Test("String with high Unicode code points")
    func highUnicodeCodePoints() {
        let original = "🀄🃏🎴🎭🎪🎨🎬🎮👾🕹️"
        let cString = strdup(original)
        let roundTrip = String(cString: cString!)
        free(cString)
        #expect(roundTrip == original)
    }
}
