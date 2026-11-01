import Boutique
import Foundation
import Testing

@MainActor
@Suite("Store canonical identifier regressions")
struct StoreIdentityRegressionTests {
    @Test(arguments: ["disk", "sqlite"], [false, true])
    func alternateSpellingOverwritePersistsOneRecord(backend: String, reversed: Bool) async throws {
        let (storage, directory) = try self.makeStorage(backend: backend)
        defer { try? FileManager.default.removeItem(at: directory.url) }
        let store = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
        let (original, alternate) = self.spellings(reversed: reversed)
        try #require(original == alternate)
        try #require(Array(original.utf8) != Array(alternate.utf8))

        try await store.insert(Item(id: original, payload: 0))
        let replacement = Item(id: alternate, payload: 1)
        try await store.insert(replacement)

        #expect(store.items == [replacement])
        #expect(try await self.readItems(from: storage) == [replacement])
    }

    @Test(arguments: ["disk", "sqlite"], [false, true])
    func alternateSpellingRemovalDeletesPersistedRecord(backend: String, reversed: Bool) async throws {
        let (storage, directory) = try self.makeStorage(backend: backend)
        defer { try? FileManager.default.removeItem(at: directory.url) }
        let store = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
        let (original, alternate) = self.spellings(reversed: reversed)
        try await store.insert(Item(id: original, payload: 0))

        try await store.remove(Item(id: alternate, payload: -1))

        #expect(store.items.isEmpty)
        #expect(try await self.readItems(from: storage).isEmpty)
    }

    @Test(arguments: ["disk", "sqlite"], [false, true])
    func batchOverwriteOfPreseededLegacyRecordLeavesOneRecord(backend: String, reversed: Bool) async throws {
        let (storage, directory) = try self.makeStorage(backend: backend)
        defer { try? FileManager.default.removeItem(at: directory.url) }
        let (original, alternate) = self.spellings(reversed: reversed)
        let legacy = Item(id: original, payload: 0)
        try await storage.write(try JSONEncoder().encode(legacy), key: CacheKey(original))
        let store = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
        let replacement = Item(id: alternate, payload: 1)

        try await store.insert([legacy, replacement])

        #expect(store.items == [replacement])
        #expect(try await self.readItems(from: storage) == [replacement])
    }

    @Test("Reopening preserves storage keys when the payload's identifier spelling changes", arguments: ["disk", "sqlite"], [false, true])
    func reopeningPreservesStorageKeys(backend: String, reversed: Bool) async throws {
        let (storage, directory) = try self.makeStorage(backend: backend)
        defer { try? FileManager.default.removeItem(at: directory.url) }
        let (original, alternate) = self.spellings(reversed: reversed)
        let store = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
        try await store.insert(Item(id: original, payload: 0))
        try await store.insert(Item(id: alternate, payload: 1))

        let reopened = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
        let replacement = Item(id: alternate, payload: 2)
        try await reopened.insert(replacement)
        #expect(reopened.items == [replacement])
        try #require(try await self.readItems(from: storage) == [replacement])

        let reopenedAgain = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
        try await reopenedAgain.remove(Item(id: original, payload: -1))
        #expect(reopenedAgain.items.isEmpty)
        #expect(try await self.readItems(from: storage).isEmpty)
    }

    @Test("Batch and chained selective removal use the loaded storage key", arguments: ["disk", "sqlite"], [false, true])
    func selectiveRemovalUsesStorageKeys(backend: String, chained: Bool) async throws {
        let (storage, directory) = try self.makeStorage(backend: backend)
        defer { try? FileManager.default.removeItem(at: directory.url) }
        let survivor = Item(id: "survivor", payload: 10)
        let store = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
        try await store.insert([Item(id: "e\u{301}", payload: 0), survivor])
        try await store.insert(Item(id: "é", payload: 1))
        let reopened = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
        let removed = Item(id: "é", payload: -1)

        if chained {
            try await reopened.remove([removed]).insert([]).run()
        } else {
            try await reopened.remove([removed])
        }

        #expect(reopened.items == [survivor])
        #expect(try await self.readItems(from: storage) == [survivor])
        let reloaded = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
        #expect(reloaded.items == [survivor])
    }

    @Test("A failed partial write retains the key needed by an alternate-spelling retry", arguments: ["disk", "sqlite"], [false, true])
    func partialWritePreservesStorageKeys(backend: String, removeCommittedItem: Bool) async throws {
        let (storage, directory) = try self.makeStorage(backend: backend)
        defer { try? FileManager.default.removeItem(at: directory.url) }
        let failingStorage = PartiallyFailingStorage(storage: storage)
        let store = try await Store<Item>(storage: failingStorage, cacheIdentifier: \.id)
        let committed = Item(id: "e\u{301}", payload: 0)

        await #expect(throws: Failure.injectedWrite) {
            try await store.insert([committed, Item(id: "uncommitted", payload: 1)])
        }
        try #require(store.items.isEmpty)
        try #require(try await self.readItems(from: storage) == [committed])

        let replacement = Item(id: "é", payload: 2)
        if removeCommittedItem {
            try await store.remove(replacement)
        } else {
            try await store.insert(replacement)
        }

        let expected = removeCommittedItem ? [] : [replacement]
        #expect(store.items == expected)
        #expect(try await self.readItems(from: storage) == expected)
        let reopened = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
        #expect(reopened.items == expected)
    }

    @Test("Duplicate logical records are preserved until an explicit clear recovers the Store", arguments: ["disk", "sqlite"], [false, true])
    func duplicateRecordsRequireExplicitRecovery(backend: String, chained: Bool) async throws {
        let (storage, directory) = try self.makeStorage(backend: backend)
        defer { try? FileManager.default.removeItem(at: directory.url) }
        let first = Item(id: "é", payload: 0)
        let second = Item(id: "e\u{301}", payload: 1)
        try await storage.write(try JSONEncoder().encode(first), key: CacheKey(first.id))
        try await storage.write(try JSONEncoder().encode(second), key: CacheKey(second.id))
        try #require(await storage.keyCount() == 2)
        let originalRecords = await self.readRecords(from: storage)
        let store = self.makeStore(storage: storage)

        await #expect(throws: Store<Item>.LoadingError.self) { try await store.itemsHaveLoaded() }
        #expect(store.items.isEmpty)
        await #expect(throws: Store<Item>.LoadingError.self) { try await store.insert(Item(id: "blocked", payload: 2)) }
        await #expect(throws: Store<Item>.LoadingError.self) { try await store.remove(first) }
        #expect(await self.readRecords(from: storage) == originalRecords)

        let replacement = Item(id: "recovered", payload: 2)
        if chained {
            try await store.removeAll().insert(replacement).run()
        } else {
            try await store.removeAll()
            try await store.insert(replacement)
        }

        let later = Item(id: "later", payload: 3)
        try await store.insert(later)
        #expect(store.items == [replacement, later])
        #expect(try await self.readItems(from: storage) == [replacement, later])
        await #expect(throws: Store<Item>.LoadingError.self) { try await store.itemsHaveLoaded() }
        let reopened = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
        #expect(reopened.items.sorted(by: { $0.payload < $1.payload }) == [replacement, later])
    }

    @Test("Corrupt hydration rejects ordinary mutations without changing persisted records", arguments: ["disk", "sqlite"])
    func corruptHydrationRejectsOrdinaryMutations(backend: String) async throws {
        let (storage, directory) = try self.makeStorage(backend: backend)
        defer { try? FileManager.default.removeItem(at: directory.url) }
        let item = Item(id: "é", payload: 0)
        try await storage.write(try JSONEncoder().encode(item), key: CacheKey(item.id))
        try await storage.write(Data("invalid".utf8), key: CacheKey("corrupt"))
        let originalRecords = await self.readRecords(from: storage)
        let store = self.makeStore(storage: storage)

        await #expect(throws: DecodingError.self) { try await store.itemsHaveLoaded() }
        await #expect(throws: DecodingError.self) { try await store.insert(item) }
        await #expect(throws: DecodingError.self) { try await store.insert([item]) }
        await #expect(throws: DecodingError.self) { try await store.remove(item) }
        await #expect(throws: DecodingError.self) { try await store.remove([item]) }
        await #expect(throws: DecodingError.self) { try await store.remove([item]).insert([]).run() }

        #expect(store.items.isEmpty)
        #expect(await self.readRecords(from: storage) == originalRecords)
    }
}

private extension StoreIdentityRegressionTests {
    func spellings(reversed: Bool) -> (original: String, alternate: String) {
        reversed ? ("e\u{301}", "é") : ("é", "e\u{301}")
    }

    func makeStorage(backend: String) throws -> (any StorageEngine, FileManager.Directory) {
        let directory = FileManager.Directory.temporary(appendingPath: "Boutique.IdentityRegression.\(UUID())")
        if backend == "disk" {
            return (DiskStorageEngine(directory: directory), directory)
        }
        let storage = try #require(SQLiteStorageEngine(directory: directory))
        return (storage, directory)
    }

    func makeStore(storage: any StorageEngine) -> Store<Item> {
        Store(storage: storage, cacheIdentifier: \.id)
    }

    func readItems(from storage: any StorageEngine) async throws -> [Item] {
        try await storage.readAllData()
            .map({ try JSONDecoder().decode(Item.self, from: $0) })
            .sorted(by: { $0.payload < $1.payload })
    }

    func readRecords(from storage: any StorageEngine) async -> [StoredRecord] {
        await storage.readAllDataAndKeys()
            .map({ StoredRecord(key: Array($0.key.value.utf8), data: $0.data) })
            .sorted(by: { $0.key.lexicographicallyPrecedes($1.key) })
    }

    struct Item: Codable, Equatable, Sendable {
        let id: String
        let payload: Int
    }

    struct StoredRecord: Equatable {
        let key: [UInt8]
        let data: Data
    }

    enum Failure: Error, Equatable {
        case injectedWrite
    }

    actor PartiallyFailingStorage: StorageEngine {
        private let storage: any StorageEngine
        private var failsNextBatch = true

        init(storage: any StorageEngine) {
            self.storage = storage
        }

        func write(_ data: Data, key: CacheKey) async throws {
            try await self.storage.write(data, key: key)
        }

        func write(_ dataAndKeys: [(key: CacheKey, data: Data)]) async throws {
            if self.failsNextBatch, let first = dataAndKeys.first {
                self.failsNextBatch = false
                try await self.storage.write(first.data, key: first.key)
                throw Failure.injectedWrite
            }
            try await self.storage.write(dataAndKeys)
        }

        func read(key: CacheKey) async -> Data? {
            await self.storage.read(key: key)
        }

        func readDataAndKeys(keys: [CacheKey]) async -> [(key: CacheKey, data: Data)] {
            await self.storage.readDataAndKeys(keys: keys)
        }

        func remove(key: CacheKey) async throws {
            try await self.storage.remove(key: key)
        }

        func removeAllData() async throws {
            try await self.storage.removeAllData()
        }

        func keyExists(_ key: CacheKey) async -> Bool {
            await self.storage.keyExists(key)
        }

        func allKeys() async -> [CacheKey] {
            await self.storage.allKeys()
        }

        func createdAt(key: CacheKey) async -> Date? {
            await self.storage.createdAt(key: key)
        }

        func updatedAt(key: CacheKey) async -> Date? {
            await self.storage.updatedAt(key: key)
        }
    }
}

@MainActor
@Suite("Store identity after persistence failures", .timeLimit(.minutes(1)))
struct StoreIdentityFailureTests {
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

    @Test("A partial deletion retains the storage keys needed by an alternate-spelling retry", arguments: Backend.allCases)
    func partialDeletionPreservesRemainingIdentity(backend: Backend) async throws {
        let directory = FileManager.Directory.temporary(appendingPath: "Boutique-IdentityDeletionFailure-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory.url) }
        let storage = try backend.makeStorage(directory: directory)
        let first = Item(id: "e\u{301}", payload: 1)
        let second = Item(id: "a\u{308}", payload: 2)
        let secondData = try JSONEncoder().encode(second)
        try await storage.write(try JSONEncoder().encode(first), key: CacheKey(first.id))
        try await storage.write(secondData, key: CacheKey(second.id))
        let originalRecords = await self.readRecords(from: storage)
        try #require(originalRecords.count == 2)

        let failingStorage = FailingStorage(storage: storage, fault: .partialDeletion)
        let store = try await Store<Item>(storage: failingStorage, cacheIdentifier: \.id)
        let removed = [Item(id: "é", payload: 1), Item(id: "ä", payload: 2)]
        var events = store.events.makeAsyncIterator()
        #expect(await events.next()?.operation == .loaded)

        await #expect(throws: Failure.partialDeletion) {
            try await store.remove(removed)
        }
        let survivingRecords = await self.readRecords(from: storage)
        try #require(survivingRecords == originalRecords.filter({ $0.data == secondData }))
        try #require(await storage.keyCount() == 1)

        try await store.remove(removed)
        let removal = await events.next()
        #expect(removal?.operation == .remove)
        #expect(removal?.items == removed)
        #expect(store.items.isEmpty)
        #expect(await storage.keyCount() == 0)
        #expect(await self.readRecords(from: storage) == [])
        let reopenedStorage = try backend.makeStorage(directory: directory)
        let reopened = try await Store<Item>(storage: reopenedStorage, cacheIdentifier: \.id)
        #expect(reopened.items.isEmpty)
    }

    @Test("A committed replacement after clear can be retried despite failed initial hydration", arguments: Backend.allCases, [false, true])
    func failedReplacementAfterClearPreservesRecoveredIdentity(backend: Backend, batch: Bool) async throws {
        let directory = FileManager.Directory.temporary(appendingPath: "Boutique-IdentityClearFailure-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory.url) }
        let storage = try backend.makeStorage(directory: directory)
        try await storage.write(Data("invalid".utf8), key: CacheKey("corrupt"))
        let failingStorage = FailingStorage(storage: storage, fault: .writeAfterClear)
        let store = self.makeStore(storage: failingStorage)
        await #expect(throws: DecodingError.self) { try await store.itemsHaveLoaded() }
        var events = store.events.makeAsyncIterator()
        #expect(await events.next()?.operation == .initialized)

        let committed = Item(id: "e\u{301}", payload: 1)
        await #expect(throws: Failure.writeAfterClear) {
            let operation: Store<Item>.Operation = try await store.removeAll()
            if batch {
                try await operation.insert([committed]).run()
            } else {
                try await operation.insert(committed).run()
            }
        }
        let committedRecords = await self.readRecords(from: storage)
        try #require(committedRecords.count == 1)
        try #require(try JSONDecoder().decode(Item.self, from: committedRecords[0].data) == committed)
        try #require(await storage.keyCount() == 1)

        let replacement = Item(id: "é", payload: 2)
        try await store.insert(replacement)
        let insertion = await events.next()
        #expect(insertion?.operation == .insert)
        #expect(insertion?.items == [replacement])
        #expect(store.items == [replacement])
        let retriedRecords = await self.readRecords(from: storage)
        #expect(retriedRecords.map(\.key) == committedRecords.map(\.key))
        #expect(try retriedRecords.map({ try JSONDecoder().decode(Item.self, from: $0.data) }) == [replacement])
        #expect(await storage.keyCount() == 1)

        let reopenedStorage = try backend.makeStorage(directory: directory)
        let reopened = try await Store<Item>(storage: reopenedStorage, cacheIdentifier: \.id)
        #expect(reopened.items == [replacement])
        try await reopened.remove(committed)
        #expect(reopened.items.isEmpty)
        #expect(await storage.keyCount() == 0)
        #expect(await self.readRecords(from: storage) == [])
    }
}

private extension StoreIdentityFailureTests {
    struct Item: Codable, Sendable, Equatable {
        let id: String
        let payload: Int
    }

    struct StoredRecord: Equatable {
        let key: [UInt8]
        let data: Data
    }

    enum Failure: Error, Equatable {
        case partialDeletion
        case writeAfterClear
    }

    func makeStore(storage: any StorageEngine) -> Store<Item> {
        Store(storage: storage, cacheIdentifier: \.id)
    }

    func readRecords(from storage: any StorageEngine) async -> [StoredRecord] {
        await storage.readAllDataAndKeys()
            .map({ StoredRecord(key: Array($0.key.value.utf8), data: $0.data) })
            .sorted(by: { $0.key.lexicographicallyPrecedes($1.key) })
    }

    actor FailingStorage: StorageEngine {
        private let storage: any StorageEngine
        private var fault: Failure?
        private var didClear = false

        init(storage: any StorageEngine, fault: Failure) {
            self.storage = storage
            self.fault = fault
        }

        func write(_ data: Data, key: CacheKey) async throws {
            try await self.storage.write(data, key: key)
            try self.failAfterWriteIfNeeded()
        }

        func write(_ dataAndKeys: [(key: CacheKey, data: Data)]) async throws {
            try await self.storage.write(dataAndKeys)
            try self.failAfterWriteIfNeeded()
        }

        private func failAfterWriteIfNeeded() throws {
            if self.didClear, self.fault == .writeAfterClear {
                self.fault = nil
                throw Failure.writeAfterClear
            }
        }

        func remove(key: CacheKey) async throws {
            try await self.storage.remove(key: key)
        }

        func remove(keys: [CacheKey]) async throws {
            if self.fault == .partialDeletion, let first = keys.first {
                try await self.storage.remove(key: first)
                self.fault = nil
                throw Failure.partialDeletion
            }
            try await self.storage.remove(keys: keys)
        }

        func removeAllData() async throws {
            try await self.storage.removeAllData()
            self.didClear = true
        }

        func read(key: CacheKey) async -> Data? {
            await self.storage.read(key: key)
        }

        func readDataAndKeys(keys: [CacheKey]) async -> [(key: CacheKey, data: Data)] {
            await self.storage.readDataAndKeys(keys: keys)
        }

        func allKeys() async -> [CacheKey] {
            await self.storage.allKeys()
        }

        func keyExists(_ key: CacheKey) async -> Bool {
            await self.storage.keyExists(key)
        }

        func createdAt(key: CacheKey) async -> Date? {
            await self.storage.createdAt(key: key)
        }

        func updatedAt(key: CacheKey) async -> Date? {
            await self.storage.updatedAt(key: key)
        }
    }
}
