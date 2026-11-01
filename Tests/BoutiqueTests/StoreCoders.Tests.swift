@testable import Boutique
import Foundation
import Testing

@MainActor
struct StoreCodersTests {
    @Test("Store coders run off the main thread and preserve persisted values")
    func codersRunOffMainThread() async throws {
        let storage = CodersTestStorage(data: [Data(#"{"id":"first","value":1}"#.utf8)])
        let store = try await Store<CodersTestItem>(storage: storage, cacheIdentifier: \.id)
        #expect(store.items == [.init(id: "first", value: 1)])

        try await store.insert([.init(id: "second", value: 2), .init(id: "third", value: 3)])
        let reloaded = try await Store<CodersTestItem>(storage: storage, cacheIdentifier: \.id)
        #expect(reloaded.items == store.items)
        #expect(await storage.writeCount == 1)
    }

    @Test("Mutations wait for hydration and all load waiters share one loaded event")
    func mutationsWaitForHydration() async throws {
        let storage = CodersTestStorage(data: [Data(#"{"id":"first","value":1}"#.utf8)], pausesRead: true)
        let store = Self.makeStore(storage: storage)
        var events = store.events.makeAsyncIterator()
        await storage.waitForRead()

        let insertion = Task { try await store.insert(CodersTestItem(id: "second", value: 2)) }
        let waiter = Task { try await store.itemsHaveLoaded() }
        await storage.resumeRead()
        try await insertion.value
        try await waiter.value

        #expect(store.items.map(\.id) == ["first", "second"])
        #expect(await storage.readCount == 1)
        let initial = await events.next()
        let loaded = await events.next()
        let inserted = await events.next()
        #expect(initial?.operation == .initialized)
        #expect(loaded?.operation == .loaded)
        #expect(loaded?.items.map(\.id) == ["first"])
        #expect(inserted?.operation == .insert)
        #expect(inserted?.items.map(\.id) == ["second"])
    }

    @Test("Concurrent inserts do not overwrite snapshots across encoding suspension")
    func concurrentInsertsPreserveEveryItem() async throws {
        let storage = CodersTestStorage()
        let store = try await Store<CodersTestItem>(storage: storage, cacheIdentifier: \.id)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask { try await store.insert(CodersTestItem(id: String(index), value: index)) }
            }
            try await group.waitForAll()
        }
        #expect(store.items.count == 100)
        #expect(Set(store.items.map(\.id)) == Set((0..<100).map(String.init)))
        let reloaded = try await Store<CodersTestItem>(storage: storage, cacheIdentifier: \.id)
        #expect(reloaded.items == store.items)
    }

    @Test("Corrupt hydration remains all-or-nothing and can be cleared")
    func corruptHydrationCanBeCleared() async throws {
        let storage = CodersTestStorage(data: [Data(#"{"id":"first","value":1}"#.utf8), Data("invalid".utf8)])
        let store = Self.makeStore(storage: storage)
        await #expect(throws: DecodingError.self) { try await store.itemsHaveLoaded() }
        await #expect(throws: DecodingError.self) { try await store.itemsHaveLoaded() }
        #expect(store.items.isEmpty)
        #expect(await storage.readCount == 1)
        var events = store.events.makeAsyncIterator()
        #expect(await events.next()?.operation == .initialized)

        try await store.removeAll()
        #expect(await storage.keyCount() == 0)
        let reloaded = try await Store<CodersTestItem>(storage: storage, cacheIdentifier: \.id)
        #expect(reloaded.items.isEmpty)
    }

    @Test("Encoding failure does not persist a partial batch or block later mutations")
    func encodingFailureReleasesMutationGate() async throws {
        let storage = CodersTestStorage()
        let store = try await Store<CodersTestItem>(storage: storage, cacheIdentifier: \.id)
        await #expect(throws: CodersTestItem.Failure.self) {
            try await store.insert([.init(id: "valid", value: 1), .init(id: "invalid", value: -1)])
        }
        #expect(store.items.isEmpty)
        #expect(await storage.writeCount == 0)
        try await store.insert(CodersTestItem(id: "later", value: 2))
        #expect(store.items.map(\.id) == ["later"])
    }

    private static func makeStore(storage: CodersTestStorage) -> Store<CodersTestItem> {
        Store(storage: storage, cacheIdentifier: \.id)
    }
}

private struct CodersTestItem: StorableItem, Equatable {
    let id: String
    let value: Int

    enum CodingKeys: CodingKey { case id, value }
    enum Failure: Error { case invalidValue }

    init(id: String, value: Int) {
        self.id = id
        self.value = value
    }

    init(from decoder: any Decoder) throws {
        #expect(!Thread.isMainThread)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.value = try container.decode(Int.self, forKey: .value)
    }

    func encode(to encoder: any Encoder) throws {
        #expect(!Thread.isMainThread)
        guard self.value >= 0 else { throw Failure.invalidValue }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.value, forKey: .value)
    }
}

private actor CodersTestStorage: StorageEngine {
    private var entries: [(key: CacheKey, data: Data)]
    private var pausesRead: Bool
    private var readHasStarted = false
    private var readStartedWaiters: [CheckedContinuation<Void, Never>] = []
    private var pausedRead: CheckedContinuation<Void, Never>?
    private(set) var readCount = 0
    private(set) var writeCount = 0

    init(data: [Data] = [], pausesRead: Bool = false) {
        self.entries = data.enumerated().map({ (CacheKey(String($0.offset)), $0.element) })
        self.pausesRead = pausesRead
    }

    func waitForRead() async {
        guard !self.readHasStarted else { return }
        await withCheckedContinuation { self.readStartedWaiters.append($0) }
    }

    func resumeRead() {
        self.pausesRead = false
        self.pausedRead?.resume()
        self.pausedRead = nil
    }

    func readAllData() async -> [Data] {
        self.readCount += 1
        let data = self.entries.map(\.data)
        self.readHasStarted = true
        self.readStartedWaiters.forEach({ $0.resume() })
        self.readStartedWaiters.removeAll()
        if self.pausesRead {
            await withCheckedContinuation { self.pausedRead = $0 }
        }
        return data
    }

    func write(_ data: Data, key: CacheKey) async throws {
        try await self.write([(key, data)])
    }

    func write(_ dataAndKeys: [(key: CacheKey, data: Data)]) async throws {
        self.writeCount += 1
        for entry in dataAndKeys {
            if let index = self.entries.firstIndex(where: { $0.key == entry.key }) {
                self.entries[index] = entry
            } else {
                self.entries.append(entry)
            }
        }
    }

    func read(key: CacheKey) async -> Data? {
        self.entries.first(where: { $0.key == key })?.data
    }

    func readDataAndKeys(keys: [CacheKey]) async -> [(key: CacheKey, data: Data)] {
        self.entries.filter({ keys.contains($0.key) })
    }

    func remove(key: CacheKey) async throws {
        self.entries.removeAll(where: { $0.key == key })
    }

    func removeAllData() async throws { self.entries.removeAll() }
    func keyExists(_ key: CacheKey) async -> Bool { self.entries.contains(where: { $0.key == key }) }
    func allKeys() async -> [CacheKey] { self.entries.map(\.key) }
    func createdAt(key: CacheKey) async -> Date? { nil }
    func updatedAt(key: CacheKey) async -> Date? { nil }
}
