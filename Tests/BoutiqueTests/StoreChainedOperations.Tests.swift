@testable import Boutique
import Foundation
import Testing

@MainActor
@Suite("Store chained removal persistence")
struct StoreChainedRemovalTests {
    enum Backend: String, CaseIterable, Sendable {
        case disk, sqlite

        func makeStorage(directory: FileManager.Directory) throws -> any StorageEngine {
            switch self {
            case .disk:
                return DiskStorageEngine(directory: directory)
            case .sqlite:
                return try #require(SQLiteStorageEngine(directory: directory))
            }
        }
    }

    enum Removal: String, CaseIterable, Sendable {
        case all, oneItemBatch, multipleItemBatch
    }

    enum Insertion: String, CaseIterable, Sendable {
        case single, batch, emptyBatch
    }

    @Test("Chained removals preserve exact values after reopening", arguments: Backend.allCases, Removal.allCases)
    func chainedRemovalsPersist(backend: Backend, removal: Removal) async throws {
        for insertion in Insertion.allCases {
            let context = "backend=\(backend), removal=\(removal), insertion=\(insertion)"
            let directory = FileManager.Directory.temporary(appendingPath: "Boutique-ChainedRemoval-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: directory.url) }

            let storage = try backend.makeStorage(directory: directory)
            let store = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
            let first = Item(id: "first/é", payload: 1)
            let second = Item(id: "second", payload: 2)
            let keeper = Item(id: "keeper", payload: 3)
            let initial = [first, second, keeper]
            try await store.insert(initial)
            try #require(store.items == initial, "\(context)")
            try #require(await storage.keyCount() == initial.count, "\(context)")

            var operation: Store<Item>.Operation
            let survivors: [Item]
            switch removal {
            case .all:
                operation = try await store.removeAll()
                survivors = []
            case .oneItemBatch:
                operation = try await store.remove([first])
                survivors = [second, keeper]
            case .multipleItemBatch:
                operation = try await store.remove([first, second])
                survivors = [keeper]
            }

            let newItem = Item(id: "new", payload: 4)
            let otherNewItem = Item(id: "other-new", payload: 5)
            let inserted: [Item]
            switch insertion {
            case .single:
                operation = try await operation.insert(newItem)
                inserted = [newItem]
            case .batch:
                operation = try await operation.insert([newItem, otherNewItem])
                inserted = [newItem, otherNewItem]
            case .emptyBatch:
                operation = try await operation.insert([Item]())
                inserted = []
            }

            #expect(store.items == initial, "queued operations ran early: \(context)")
            try await operation.run()

            let expected = survivors + inserted
            #expect(store.items == expected, "\(context)")
            #expect(await storage.keyCount() == expected.count, "\(context)")

            let reopenedStorage = try backend.makeStorage(directory: directory)
            let reopened = try await Store<Item>(storage: reopenedStorage, cacheIdentifier: \.id)
            #expect(reopened.items.sorted(by: { $0.id < $1.id }) == expected.sorted(by: { $0.id < $1.id }), "reopened values: \(context)")
        }
    }
    @Test("Closure-based removal strategies select items from the current contents", arguments: Backend.allCases)
    func closureBasedRemovalPersists(backend: Backend) async throws {
        let directory = FileManager.Directory.temporary(appendingPath: "Boutique-ClosureRemoval-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory.url) }
        let storage = try backend.makeStorage(directory: directory)
        let store = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
        let removed = Item(id: "removed", payload: 1)
        let keeper = Item(id: "keeper", payload: 2)
        let replacement = Item(id: "replacement", payload: 3)
        try await store.insert([removed, keeper])
        let strategy = Store<Item>.ItemRemovalStrategy<Item>(removedItems: { $0.filter({ $0.payload == 1 }) })

        try await store.performInsert(replacement, firstRemovingExistingItems: strategy)

        #expect(store.items == [keeper, replacement])
        let reopenedStorage = try backend.makeStorage(directory: directory)
        let reopened = try await Store<Item>(storage: reopenedStorage, cacheIdentifier: \.id)
        #expect(reopened.items.sorted(by: { $0.id < $1.id }) == [keeper, replacement])
    }

}

private extension StoreChainedRemovalTests {
    struct Item: Codable, Sendable, Equatable {
        let id: String
        let payload: Int
    }
}

@MainActor
@Suite("Chained replacement encoding failures", .timeLimit(.minutes(1)))
struct StoreChainedEncodingFailureTests {
    enum Backend: String, CaseIterable, Sendable {
        case disk, sqlite

        func makeStorage(directory: FileManager.Directory) throws -> any StorageEngine {
            switch self {
            case .disk:
                return DiskStorageEngine(directory: directory)
            case .sqlite:
                return try #require(SQLiteStorageEngine(directory: directory))
            }
        }
    }

    enum Removal: String, CaseIterable, Sendable {
        case all, selected
    }

    @Test("Encoding failure preserves the previous persisted values", arguments: Backend.allCases, Removal.allCases)
    func encodingFailurePreservesExistingItems(backend: Backend, removal: Removal) async throws {
        for batch in [false, true] {
            let directory = FileManager.Directory.temporary(appendingPath: "Boutique-ChainedEncodingFailure-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: directory.url) }
            let storage = try backend.makeStorage(directory: directory)
            let store = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
            let original = Item(id: "original", payload: 1)
            let keeper = Item(id: "keeper", payload: 2)
            let valid = Item(id: "valid", payload: 3)
            let invalid = Item(id: "invalid", payload: -1)
            let initial = [original, keeper]
            try await store.insert(initial)
            var events = store.events.makeAsyncIterator()
            #expect(await events.next()?.items == initial)

            let operation: Store<Item>.Operation
            switch removal {
            case .all:
                operation = try await store.removeAll()
            case .selected:
                operation = try await store.remove([original])
            }

            await #expect(throws: Item.Failure.self) {
                if batch {
                    try await operation.insert([valid, invalid]).run()
                } else {
                    try await operation.insert(invalid).run()
                }
            }
            #expect(store.items == initial)
            let persisted = try await storage.readAllData().map({ try JSONDecoder().decode(Item.self, from: $0) })
            #expect(persisted.sorted(by: { $0.id < $1.id }) == [keeper, original])

            let reopenedStorage = try backend.makeStorage(directory: directory)
            let reopened = try await Store<Item>(storage: reopenedStorage, cacheIdentifier: \.id)
            #expect(reopened.items.sorted(by: { $0.id < $1.id }) == [keeper, original])

            try await store.insert(valid)
            let event = await events.next()
            #expect(event?.operation == .insert)
            #expect(event?.items == [valid])
            #expect(store.items == initial + [valid])
        }
    }
}

private extension StoreChainedEncodingFailureTests {
    struct Item: Codable, Sendable, Equatable {
        enum Failure: Error {
            case invalidPayload
        }

        let id: String
        let payload: Int

        func encode(to encoder: any Encoder) throws {
            guard self.payload >= 0 else { throw Failure.invalidPayload }
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.id, forKey: .id)
            try container.encode(self.payload, forKey: .payload)
        }
    }
}

@MainActor
@Suite("Store clearing shared storage", .timeLimit(.minutes(1)))
struct StoreSharedClearReproductionTests {
    enum Backend: String, CaseIterable, Sendable {
        case disk, sqlite

        func makeStorage(directory: FileManager.Directory) throws -> any StorageEngine {
            switch self {
            case .disk:
                return DiskStorageEngine(directory: directory)
            case .sqlite:
                return try #require(SQLiteStorageEngine(directory: directory))
            }
        }
    }

    enum Replacement: String, CaseIterable, Sendable {
        case single, batch, empty
    }

    @Test(arguments: Backend.allCases, Replacement.allCases)
    func directClearRemovesOtherStoresRecord(backend: Backend, replacement: Replacement) async throws {
        try await self.reproduce(backend: backend, replacement: replacement, chained: false)
    }

    @Test(arguments: Backend.allCases, Replacement.allCases)
    func chainedClearRemovesOtherStoresRecord(backend: Backend, replacement: Replacement) async throws {
        try await self.reproduce(backend: backend, replacement: replacement, chained: true)
    }
}

private extension StoreSharedClearReproductionTests {
    struct Item: Codable, Equatable, Sendable {
        let id: String
        let payload: Int
    }

    func reproduce(backend: Backend, replacement: Replacement, chained: Bool) async throws {
        let directory = FileManager.Directory.temporary(appendingPath: "Boutique-SharedClear-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory.url) }
        let storage = try backend.makeStorage(directory: directory)
        let first = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
        let second = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
        let original = Item(id: "original", payload: 1)
        let newItem = Item(id: "replacement", payload: 2)
        let expected = replacement == .empty ? [] : [newItem]
        try await first.insert(original)
        try #require(second.items.isEmpty)
        var events = second.events.makeAsyncIterator()
        #expect(await events.next()?.operation == .loaded)

        // The calls are sequential; this does not require cross-Store cache refresh.
        if chained {
            let operation: Store<Item>.Operation = try await second.removeAll()
            if replacement == .single {
                try await operation.insert(newItem).run()
            } else {
                try await operation.insert(expected).run()
            }
        } else {
            try await second.removeAll()
            if replacement == .single {
                try await second.insert(newItem)
            } else {
                try await second.insert(expected)
            }
            let removal = await events.next()
            #expect(removal?.operation == .remove)
            #expect(removal?.items == [])
        }

        // Chained removal and insertion publish the final insertion without an intermediate removal.
        let insertion = await events.next()
        #expect(insertion?.operation == .insert)
        #expect(insertion?.items == expected)
        #expect(second.items == expected)
        let persisted = try await storage.readAllData().map({ try JSONDecoder().decode(Item.self, from: $0) })
        #expect(persisted == expected)
        let reopenedStorage = try backend.makeStorage(directory: directory)
        let reopened = try await Store<Item>(storage: reopenedStorage, cacheIdentifier: \.id)
        #expect(reopened.items == expected)
    }
}

@MainActor
@Suite("Store clearing partially committed storage", .timeLimit(.minutes(1)))
struct StorePartialFailureClearReproductionTests {
    enum Replacement: String, CaseIterable, Sendable {
        case single, batch, empty
    }

    @Test(arguments: Replacement.allCases)
    func directClearRemovesPartiallyCommittedRecord(replacement: Replacement) async throws {
        try await self.reproduce(chained: false, replacement: replacement)
    }

    @Test(arguments: Replacement.allCases)
    func successfulChainedClearRemovesPartiallyCommittedRecord(replacement: Replacement) async throws {
        try await self.reproduce(chained: true, replacement: replacement)
    }

    @Test("A failed chained clear preserves data and allows later mutations")
    func failedClearPreservesDataAndAllowsLaterMutations() async throws {
        let storage = Storage(failsFirstBatch: false)
        let store = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
        let original = Item(id: "original", payload: 1)
        let replacement = Item(id: "replacement", payload: 2)
        let later = Item(id: "later", payload: 3)
        try await store.insert(original)
        var events = store.events.makeAsyncIterator()
        #expect(await events.next()?.items == [original])
        await storage.failNextClear()

        await #expect(throws: Storage.Failure.clear) {
            try await store.removeAll().insert(replacement).run()
        }
        #expect(store.items == [original])
        let afterFailure = try await storage.readAllData().map({ try JSONDecoder().decode(Item.self, from: $0) })
        #expect(afterFailure == [original])

        try await store.insert(later)
        let event = await events.next()
        #expect(event?.operation == .insert)
        #expect(event?.items == [later])
        #expect(store.items == [original, later])
        let reopened = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
        #expect(reopened.items.sorted(by: { $0.id < $1.id }) == [later, original])
    }
}

private extension StorePartialFailureClearReproductionTests {
    struct Item: Codable, Sendable, Equatable {
        let id: String
        let payload: Int
    }

    func reproduce(chained: Bool, replacement: Replacement) async throws {
        let storage = Storage()
        let store = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
        let committed = Item(id: "committed", payload: 1)
        let uncommitted = Item(id: "uncommitted", payload: 2)
        var threwExpectedError = false
        do {
            try await store.insert([committed, uncommitted])
        } catch Storage.Failure.committedFirstBatchEntry {
            threwExpectedError = true
        }
        try #require(threwExpectedError)
        let afterFailure = try await storage.readAllData().map({ try JSONDecoder().decode(Item.self, from: $0) })
        try #require(afterFailure == [committed])

        let newItem = Item(id: "replacement", payload: 3)
        let expected = replacement == .empty ? [] : [newItem]
        if chained {
            let operation: Store<Item>.Operation = try await store.removeAll()
            if replacement == .single {
                try await operation.insert(newItem).run()
            } else {
                try await operation.insert(expected).run()
            }
        } else {
            try await store.removeAll()
            if replacement == .single {
                try await store.insert(newItem)
            } else {
                try await store.insert(expected)
            }
        }

        #expect(store.items == expected)
        let persisted = try await storage.readAllData().map({ try JSONDecoder().decode(Item.self, from: $0) })
        #expect(persisted == expected)
        let reopened = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
        #expect(reopened.items == expected)
    }

    actor Storage: StorageEngine {
        enum Failure: Error, Equatable {
            case committedFirstBatchEntry
            case clear
        }

        private var records = [CacheKey: Data]()
        private var failsNextBatch: Bool
        private var failsNextClear = false

        init(failsFirstBatch: Bool = true) {
            self.failsNextBatch = failsFirstBatch
        }

        func failNextClear() {
            self.failsNextClear = true
        }

        func write(_ data: Data, key: CacheKey) {
            self.records[key] = data
        }

        func write(_ entries: [(key: CacheKey, data: Data)]) throws {
            let shouldFail = self.failsNextBatch
            self.failsNextBatch = false
            for entry in entries {
                self.records[entry.key] = entry.data
                if shouldFail {
                    throw Failure.committedFirstBatchEntry
                }
            }
        }

        func remove(key: CacheKey) {
            self.records.removeValue(forKey: key)
        }

        func removeAllData() throws {
            if self.failsNextClear {
                self.failsNextClear = false
                throw Failure.clear
            }
            self.records.removeAll()
        }

        func readAllData() -> [Data] {
            Array(self.records.values)
        }

        func read(key: CacheKey) -> Data? {
            self.records[key]
        }

        func readDataAndKeys(keys: [CacheKey]) -> [(key: CacheKey, data: Data)] {
            keys.compactMap({ key in self.records[key].map({ (key, $0) }) })
        }

        func allKeys() -> [CacheKey] {
            Array(self.records.keys)
        }

        func keyExists(_ key: CacheKey) -> Bool {
            self.records[key] != nil
        }

        func createdAt(key: CacheKey) -> Date? { nil }
        func updatedAt(key: CacheKey) -> Date? { nil }
    }
}
