import Foundation

final class TestKeychainStore: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var values: [String: String]

    init(values: [String: String] = [:]) {
        self.values = values
    }

    nonisolated func load(_ key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    @discardableResult
    nonisolated func save(_ value: String, _ key: String) -> Bool {
        lock.lock()
        values[key] = value
        lock.unlock()
        return true
    }

    nonisolated func delete(_ key: String) {
        lock.lock()
        values.removeValue(forKey: key)
        lock.unlock()
    }
}

final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var value = false

    nonisolated func setTrue() {
        lock.lock()
        value = true
        lock.unlock()
    }

    nonisolated var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

final class LockedStringIntMap: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var values: [String: Int] = [:]

    nonisolated func increment(_ key: String) {
        lock.lock()
        values[key, default: 0] += 1
        lock.unlock()
    }

    nonisolated func value(for key: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return values[key, default: 0]
    }
}
