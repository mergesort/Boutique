@testable import Boutique
import Foundation
import Testing

@MainActor
@Suite("Store mutation concurrency", .timeLimit(.minutes(1)))
struct StoreMutationConcurrencyTests {
    @Test(arguments: [false, true])
    func competingInsertsKeepBothItems(batch: Bool) async throws {
        let storage = MutationTestStorage()
        let store = try await Store<MutationTestItem>(storage: storage, cacheIdentifier: \.id)
        let firstItem = MutationTestItem(id: "first", payload: 1)
        let secondItem = MutationTestItem(id: "second", payload: 2)
        await storage.pause(at: .beforeCommit)

        try await self.withTaskCleanup(storage: storage) { tasks in
            let first = tasks.start { try await self.insert(firstItem, batch: batch, into: store) }
            try await storage.waitUntilPaused()
            let second = tasks.start { try await self.insert(secondItem, batch: batch, into: store) }
            try await second.waitUntilStarted()
            #expect(!(await second.finishesWithin(.milliseconds(250))))
            await storage.release()
            try await first.value()
            try await second.value()
        }

        #expect(try await storage.decodedItems() == [firstItem, secondItem])
        #expect(store.items.sorted(by: { $0.id < $1.id }) == [firstItem, secondItem])
    }

    @Test(arguments: [false, true])
    func initialLoadAndInsertionKeepBothItems(batch: Bool) async throws {
        let initial = MutationTestItem(id: "initial", payload: 1)
        let inserted = MutationTestItem(id: "inserted", payload: 2)
        let storage = MutationTestStorage()
        try await storage.write(JSONEncoder().encode(initial), key: CacheKey(initial.id))
        await storage.pause(at: .readSnapshot)
        let store = self.makeSynchronousStore(storage: storage)

        try await self.withTaskCleanup(storage: storage) { tasks in
            let loading = tasks.start { try await store.itemsHaveLoaded() }
            try await storage.waitUntilPaused()
            let insertion = tasks.start { try await self.insert(inserted, batch: batch, into: store) }
            try await insertion.waitUntilStarted()
            #expect(!(await insertion.finishesWithin(.milliseconds(250))))
            await storage.release()
            try await loading.value()
            try await insertion.value()
        }

        #expect(try await storage.decodedItems() == [initial, inserted])
        #expect(store.items.sorted(by: { $0.id < $1.id }) == [initial, inserted])
    }

    @Test(arguments: [false, true])
    func sequentialInsertControl(batch: Bool) async throws {
        let storage = MutationTestStorage()
        let store = try await Store<MutationTestItem>(storage: storage, cacheIdentifier: \.id)
        let expected = [MutationTestItem(id: "first", payload: 1), MutationTestItem(id: "second", payload: 2)]
        for item in expected {
            try await self.insert(item, batch: batch, into: store)
        }

        #expect(store.items == expected)
        #expect(try await storage.decodedItems() == expected)
    }

    @Test("A committed write owns its turn until its result is published")
    func sameIdentifierUpdatesPreserveCommitOrder() async throws {
        let storage = MutationTestStorage()
        let store = try await Store<MutationTestItem>(storage: storage, cacheIdentifier: \.id)
        let firstItem = MutationTestItem(id: "shared", payload: 1)
        let replacement = MutationTestItem(id: "shared", payload: 2)
        await storage.pause(at: .afterCommit)

        try await self.withTaskCleanup(storage: storage) { tasks in
            let first = tasks.start { try await store.insert(firstItem) as Void }
            try await storage.waitUntilPaused()
            #expect(try await storage.decodedItems() == [firstItem])
            let second = tasks.start { try await store.insert(replacement) as Void }
            try await second.waitUntilStarted()
            // A correct gate prevents completion here. Give an ungated write a
            // bounded opportunity to return before the first result is released.
            #expect(!(await second.finishesWithin(.milliseconds(250))))
            await storage.release()
            try await first.value()
            try await second.value()
        }

        #expect(store.items == [replacement])
        #expect(try await storage.decodedItems() == [replacement])
    }

    @Test("Another mutation cannot interleave a storage engine's batch writes")
    func overlappingBatchesKeepMemoryAndStorageInAgreement() async throws {
        let storage = MutationTestStorage()
        let store = try await Store<MutationTestItem>(storage: storage, cacheIdentifier: \.id)
        let firstBatch = [MutationTestItem(id: "first", payload: 1), MutationTestItem(id: "shared", payload: 1)]
        let secondBatch = [MutationTestItem(id: "shared", payload: 2), MutationTestItem(id: "third", payload: 2)]
        let expected = [firstBatch[0], secondBatch[0], secondBatch[1]]
        await storage.pause(at: .betweenBatchEntries)

        try await self.withTaskCleanup(storage: storage) { tasks in
            let first = tasks.start { try await store.insert(firstBatch) as Void }
            try await storage.waitUntilPaused()
            let second = tasks.start { try await store.insert(secondBatch) as Void }
            try await second.waitUntilStarted()
            #expect(!(await second.finishesWithin(.milliseconds(250))))
            await storage.release()
            try await first.value()
            try await second.value()
        }

        #expect(store.items == expected)
        #expect(try await storage.decodedItems() == expected)
    }

    @Test(arguments: [false, true])
    func removalWaitsForAnInFlightInsert(batch: Bool) async throws {
        let storage = MutationTestStorage()
        let store = try await Store<MutationTestItem>(storage: storage, cacheIdentifier: \.id)
        let item = MutationTestItem(id: "shared", payload: 1)
        await storage.pause(at: .beforeCommit)

        try await self.withTaskCleanup(storage: storage) { tasks in
            let insertion = tasks.start { try await store.insert(item) as Void }
            try await storage.waitUntilPaused()
            let removal = tasks.start {
                if batch { try await store.remove([item]) as Void }
                else { try await store.remove(item) as Void }
            }
            try await removal.waitUntilStarted()
            await storage.release()
            try await insertion.value()
            try await removal.value()
        }

        #expect(store.items.isEmpty)
        #expect(try await storage.decodedItems().isEmpty)
    }

    @Test("Insertion waits until an in-flight clear has finished")
    func insertionWaitsForClear() async throws {
        let storage = MutationTestStorage()
        let store = try await Store<MutationTestItem>(storage: storage, cacheIdentifier: \.id)
        try await store.insert(MutationTestItem(id: "old", payload: 0))
        let inserted = MutationTestItem(id: "new", payload: 1)
        await storage.pause(at: .beforeCommit)

        try await self.withTaskCleanup(storage: storage) { tasks in
            let removal = tasks.start { try await store.removeAll() as Void }
            try await storage.waitUntilPaused()
            let insertion = tasks.start { try await store.insert(inserted) as Void }
            try await insertion.waitUntilStarted()
            #expect(!(await insertion.finishesWithin(.milliseconds(250))))
            await storage.release()
            try await removal.value()
            try await insertion.value()
        }

        #expect(store.items == [inserted])
        #expect(try await storage.decodedItems() == [inserted])
    }

    @Test("A failed storage write releases the next queued mutation")
    func failedWriteReleasesQueuedMutation() async throws {
        let storage = MutationTestStorage()
        let store = try await Store<MutationTestItem>(storage: storage, cacheIdentifier: \.id)
        let inserted = MutationTestItem(id: "survivor", payload: 1)
        await storage.failNextMutation()
        await storage.pause(at: .beforeCommit)

        try await self.withTaskCleanup(storage: storage) { tasks in
            let failing = tasks.start { try await store.insert(MutationTestItem(id: "failed", payload: 0)) as Void }
            try await storage.waitUntilPaused()
            let succeeding = tasks.start { try await store.insert(inserted) as Void }
            try await succeeding.waitUntilStarted()
            await storage.release()
            await #expect(throws: MutationTestError.writeFailed) { try await failing.value() }
            try await succeeding.value()
        }

        #expect(store.items == [inserted])
        #expect(try await storage.decodedItems() == [inserted])
    }

    @Test("A canceled waiter has no effects and releases the following mutation")
    func canceledWaiterReleasesQueuedMutation() async throws {
        let storage = MutationTestStorage()
        let store = try await Store<MutationTestItem>(storage: storage, cacheIdentifier: \.id)
        let firstItem = MutationTestItem(id: "first", payload: 1)
        let lastItem = MutationTestItem(id: "last", payload: 3)
        var events = store.events.makeAsyncIterator()
        #expect(await events.next()?.operation == .loaded)
        await storage.pause(at: .beforeCommit)

        try await self.withTaskCleanup(storage: storage) { tasks in
            let first = tasks.start { try await store.insert(firstItem) as Void }
            try await storage.waitUntilPaused()
            let canceled = tasks.start { try await store.insert(MutationTestItem(id: "canceled", payload: 2)) as Void }
            try await canceled.waitUntilStarted()
            canceled.cancel()
            let last = tasks.start { try await store.insert(lastItem) as Void }
            try await last.waitUntilStarted()
            await storage.release()
            try await first.value()
            await #expect(throws: CancellationError.self) { try await canceled.value() }
            try await last.value()
        }

        #expect(store.items == [firstItem, lastItem])
        #expect(try await storage.decodedItems() == [firstItem, lastItem])
        #expect(await storage.mutationCount == 2)
        #expect(await events.next()?.items == [firstItem])
        #expect(await events.next()?.items == [lastItem])
    }

    @Test("Cancellation after a storage commit does not skip publication")
    func cancellationAfterCommitStillPublishes() async throws {
        let storage = MutationTestStorage()
        let store = try await Store<MutationTestItem>(storage: storage, cacheIdentifier: \.id)
        let item = MutationTestItem(id: "committed", payload: 1)
        await storage.pause(at: .afterCommit)

        try await self.withTaskCleanup(storage: storage) { tasks in
            let insertion = tasks.start { try await store.insert(item) as Void }
            try await storage.waitUntilPaused()
            insertion.cancel()
            await storage.release()
            try await insertion.value()
        }

        #expect(store.items == [item])
        #expect(try await storage.decodedItems() == [item])
        var events = store.events.makeAsyncIterator()
        #expect(await events.next()?.items == [item])
    }

    @Test("A paused store does not serialize an independent store")
    func independentStoresCanProgress() async throws {
        let storage = MutationTestStorage()
        let store = try await Store<MutationTestItem>(storage: storage, cacheIdentifier: \.id)
        let otherStorage = MutationTestStorage()
        let otherStore = try await Store<MutationTestItem>(storage: otherStorage, cacheIdentifier: \.id)
        let item = MutationTestItem(id: "independent", payload: 1)
        await storage.pause(at: .beforeCommit)

        try await self.withTaskCleanup(storage: storage) { tasks in
            let blocked = tasks.start { try await store.insert(MutationTestItem(id: "blocked", payload: 0)) as Void }
            try await storage.waitUntilPaused()
            let independent = tasks.start { try await otherStore.insert(item) as Void }
            try await independent.value()
            #expect(otherStore.items == [item])
            #expect(try await otherStorage.decodedItems() == [item])
            await storage.release()
            try await blocked.value()
        }
    }
}

private extension StoreMutationConcurrencyTests {
    func makeSynchronousStore(storage: MutationTestStorage) -> Store<MutationTestItem> {
        Store(storage: storage, cacheIdentifier: \.id)
    }

    func insert(_ item: MutationTestItem, batch: Bool, into store: Store<MutationTestItem>) async throws {
        if batch { try await store.insert([item]) as Void }
        else { try await store.insert(item) as Void }
    }

    func withTaskCleanup(storage: MutationTestStorage, body: @MainActor (MutationTestTasks) async throws -> Void) async throws {
        let tasks = MutationTestTasks()
        do {
            try await body(tasks)
        } catch {
            await storage.release()
            await tasks.cancelAndWait()
            throw error
        }
        await storage.release()
        await tasks.cancelAndWait()
    }
}

private struct MutationTestItem: Codable, Sendable, Equatable {
    let id: String
    let payload: Int
}

private enum MutationTestError: Error, Equatable {
    case timedOut
    case writeFailed
}

private actor MutationTestStorage: StorageEngine {
    enum PausePoint: Equatable { case readSnapshot, beforeCommit, betweenBatchEntries, afterCommit }

    private var values: [CacheKey: Data] = [:]
    private var pausePoint: PausePoint?
    private var gate: CheckedContinuation<Void, Never>?
    private var pauseWaiters: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var shouldFailNextMutation = false
    private(set) var mutationCount = 0

    func pause(at point: PausePoint) { self.pausePoint = point }
    func failNextMutation() { self.shouldFailNextMutation = true }

    func waitUntilPaused() async throws {
        guard self.gate == nil else { return }
        let id = UUID()
        let timeout = Task { @concurrent in
            do { try await Task.sleep(for: .seconds(5)) }
            catch { return }
            await self.expirePauseWaiter(id)
        }
        defer { timeout.cancel() }
        try await withCheckedThrowingContinuation { self.pauseWaiters[id] = $0 }
    }

    private func expirePauseWaiter(_ id: UUID) {
        self.pauseWaiters.removeValue(forKey: id)?.resume(throwing: MutationTestError.timedOut)
    }

    func release() {
        self.pausePoint = nil
        let continuation = self.gate
        self.gate = nil
        continuation?.resume()
        let waiters = self.pauseWaiters
        self.pauseWaiters.removeAll()
        waiters.values.forEach({ $0.resume(throwing: MutationTestError.timedOut) })
    }

    private func reach(_ point: PausePoint) async {
        guard self.pausePoint == point else { return }
        self.pausePoint = nil
        await withCheckedContinuation { continuation in
            self.gate = continuation
            let waiters = self.pauseWaiters
            self.pauseWaiters.removeAll()
            waiters.values.forEach({ $0.resume() })
        }
    }

    private func beforeMutation() async throws {
        self.mutationCount += 1
        let shouldFail = self.shouldFailNextMutation
        self.shouldFailNextMutation = false
        await self.reach(.beforeCommit)
        if shouldFail { throw MutationTestError.writeFailed }
    }

    func write(_ data: Data, key: CacheKey) async throws {
        try await self.beforeMutation()
        self.values[key] = data
        await self.reach(.afterCommit)
    }

    func write(_ entries: [(key: CacheKey, data: Data)]) async throws {
        try await self.beforeMutation()
        for (index, entry) in entries.enumerated() {
            self.values[entry.key] = entry.data
            if index == 0 && entries.count > 1 {
                await self.reach(.betweenBatchEntries)
            }
        }
        await self.reach(.afterCommit)
    }

    func remove(key: CacheKey) async throws { try await self.remove(keys: [key]) }

    func remove(keys: [CacheKey]) async throws {
        try await self.beforeMutation()
        keys.forEach({ self.values.removeValue(forKey: $0) })
        await self.reach(.afterCommit)
    }

    func removeAllData() async throws {
        try await self.beforeMutation()
        self.values.removeAll()
        await self.reach(.afterCommit)
    }

    func readAllData() async -> [Data] { await self.readAllDataAndKeys().map(\.data) }

    func readAllDataAndKeys() async -> [(key: CacheKey, data: Data)] {
        let snapshot = self.values.sorted(by: { $0.key.value < $1.key.value }).map({ (key: $0.key, data: $0.value) })
        await self.reach(.readSnapshot)
        return snapshot
    }

    func decodedItems() throws -> [MutationTestItem] {
        try self.values.values.map({ try JSONDecoder().decode(MutationTestItem.self, from: $0) }).sorted(by: { $0.id < $1.id })
    }

    func read(key: CacheKey) -> Data? { self.values[key] }
    func readDataAndKeys(keys: [CacheKey]) -> [(key: CacheKey, data: Data)] { keys.compactMap({ key in self.values[key].map({ (key, $0) }) }) }
    func allKeys() -> [CacheKey] { Array(self.values.keys) }
    func keyExists(_ key: CacheKey) -> Bool { self.values[key] != nil }
    func createdAt(key: CacheKey) -> Date? { nil }
    func updatedAt(key: CacheKey) -> Date? { nil }
}

@MainActor
private final class MutationTestTasks {
    private var tasks: [MutationTestTask] = []

    func start(_ body: @escaping @MainActor () async throws -> Void) -> MutationTestTask {
        let task = MutationTestTask(body)
        self.tasks.append(task)
        return task
    }

    func cancelAndWait() async {
        self.tasks.forEach({ $0.cancel() })
        for task in self.tasks {
            _ = try? await task.value()
        }
    }
}

@MainActor
private final class MutationTestTask {
    private let started: MutationTestSignal
    private let finished: MutationTestSignal
    private let task: Task<Void, Never>

    init(_ body: @escaping @MainActor () async throws -> Void) {
        let started = MutationTestSignal()
        let finished = MutationTestSignal()
        self.started = started
        self.finished = finished
        self.task = Task {
            // The caller resumes on MainActor after this task reaches its first
            // suspension, so the operation starts before the caller releases I/O.
            started.resolve(.success(()))
            do {
                try await body()
                finished.resolve(.success(()))
            } catch {
                finished.resolve(.failure(error))
            }
        }
    }

    func cancel() { self.task.cancel() }
    func waitUntilStarted() async throws { try await self.started.wait() }
    func value() async throws { try await self.finished.wait() }

    func finishesWithin(_ duration: Duration) async -> Bool {
        // This timeout observes the absence of completion while storage is held;
        // it does not stand in for a successful operation's synchronization.
        do {
            try await self.finished.wait(timeout: duration)
            return true
        } catch MutationTestError.timedOut {
            return false
        } catch {
            return true
        }
    }
}

@MainActor
private final class MutationTestSignal {
    private var result: Result<Void, Error>?
    private var waiters: [UUID: CheckedContinuation<Void, Error>] = [:]

    func resolve(_ result: Result<Void, Error>) {
        self.result = result
        let waiters = self.waiters
        self.waiters.removeAll()
        waiters.values.forEach({ $0.resume(with: result) })
    }

    func wait(timeout duration: Duration = .seconds(5)) async throws {
        if let result = self.result { return try result.get() }
        let id = UUID()
        let timeout = Task { @concurrent in
            do { try await Task.sleep(for: duration) }
            catch { return }
            await MainActor.run {
                self.waiters.removeValue(forKey: id)?.resume(throwing: MutationTestError.timedOut)
            }
        }
        defer { timeout.cancel() }
        try await withCheckedThrowingContinuation { self.waiters[id] = $0 }
    }
}
