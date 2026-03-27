import Foundation
import Testing
@testable import Epistemos

@Suite("CollectionRegistry")
struct CollectionRegistryTests {
    private let key = "epistemos.collectionFolderNames"

    private func withIsolatedRegistryState(_ body: () -> Void) {
        let defaults = UserDefaults.standard
        let original = defaults.stringArray(forKey: key)
        defaults.removeObject(forKey: key)
        defer {
            if let original {
                defaults.set(original, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        body()
    }

    @Test("setCollection true stores folder name")
    func setCollectionTrueStoresName() {
        withIsolatedRegistryState {
            let registry = CollectionRegistry.shared
            let name = "Research-\(UUID().uuidString)"

            registry.setCollection(name, true)

            #expect(registry.isCollection(name))
            #expect(registry.collectionNames.contains(name))
        }
    }

    @Test("setCollection false removes folder name")
    func setCollectionFalseRemovesName() {
        withIsolatedRegistryState {
            let registry = CollectionRegistry.shared
            let name = "Essays-\(UUID().uuidString)"

            registry.setCollection(name, true)
            #expect(registry.isCollection(name))

            registry.setCollection(name, false)

            #expect(!registry.isCollection(name))
            #expect(!registry.collectionNames.contains(name))
        }
    }

    @Test("collectionNames deduplicates repeated inserts")
    func collectionNamesDeduplicate() {
        withIsolatedRegistryState {
            let registry = CollectionRegistry.shared
            let name = "Projects-\(UUID().uuidString)"

            registry.setCollection(name, true)
            registry.setCollection(name, true)
            registry.setCollection(name, true)

            #expect(registry.collectionNames == Set([name]))
        }
    }

    @Test("unknown folder is not a collection")
    func unknownFolderNotCollection() {
        withIsolatedRegistryState {
            let registry = CollectionRegistry.shared
            let unknown = "Unknown-\(UUID().uuidString)"
            #expect(!registry.isCollection(unknown))
        }
    }
}
