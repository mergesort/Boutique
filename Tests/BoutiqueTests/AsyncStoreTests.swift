@testable import Boutique
import Testing

@MainActor
@Suite("Async Store Tests", .serialized)
struct AsyncStoreTests {
    private var asyncStore: Store<BoutiqueItem>!

    init() async throws {
        asyncStore = try await Store<BoutiqueItem>(
            storage: SQLiteStorageEngine.default(appendingPath: "Tests"),
            cacheIdentifier: \.merchantID)
        try await asyncStore.removeAll()
    }

    @Test("Test inserting a single item")
    func testInsertingItem() async throws {
        try await asyncStore.insert(.coat)
        #expect(asyncStore.items.contains(.coat))

        try await asyncStore.insert(.belt)
        #expect(asyncStore.items.contains(.belt))
        #expect(asyncStore.items.count == 2)
    }

    @Test("Test inserting multiple items")
    func testInsertingMultipleItems() async throws {
        try await asyncStore.insert([.coat, .sweater, .sweater, .purse])
        #expect(asyncStore.items.contains(.coat))
        #expect(asyncStore.items.contains(.sweater))
        #expect(asyncStore.items.contains(.purse))
    }

    @Test("Test inserting duplicate items")
    func testInsertingDuplicateItems() async throws {
        #expect(asyncStore.items.isEmpty)
        try await asyncStore.insert(.allItems)
        #expect(asyncStore.items.count == 4)
    }

    @Test("Test reading items")
    func testReadingItems() async throws {
        try await asyncStore.insert(.allItems)

        #expect(asyncStore.items[0] == .coat)
        #expect(asyncStore.items[1] == .sweater)
        #expect(asyncStore.items[2] == .purse)
        #expect(asyncStore.items[3] == .belt)

        #expect(asyncStore.items.count == 4)
    }

    @Test("Test reading items persisted in a Store")
    func testReadingPersistedItems() async throws {
        try await asyncStore.insert(.allItems)

        // The new store has to fetch items from disk.
        let newStore = try await Store<BoutiqueItem>(
            storage: SQLiteStorageEngine.default(appendingPath: "Tests"),
            cacheIdentifier: \.merchantID)

        #expect(newStore.items[0] == .coat)
        #expect(newStore.items[1] == .sweater)
        #expect(newStore.items[2] == .purse)
        #expect(newStore.items[3] == .belt)

        #expect(newStore.items.count == 4)
    }

    @Test("Test removing items")
    func testRemovingSingleItems() async throws {
        try await asyncStore.insert(.allItems)
        try await asyncStore.remove(.coat)

        #expect(!asyncStore.items.contains(.coat))

        #expect(asyncStore.items.contains(.sweater))
        #expect(asyncStore.items.contains(.purse))

        try await asyncStore.remove([.sweater, .purse])
        #expect(!asyncStore.items.contains(.sweater))
        #expect(!asyncStore.items.contains(.purse))
    }

    @Test("Test removing all items")
    func testRemoveAll() async throws {
        try await asyncStore.insert(.coat)
        #expect(asyncStore.items.count == 1)
        try await asyncStore.removeAll()

        try await asyncStore.insert(.uniqueItems)
        #expect(asyncStore.items.count == 4)
        try await asyncStore.removeAll()
        #expect(asyncStore.items.isEmpty)
    }

    @Test("Test chaining insert operations")
    func testChainingInsertOperations() async throws {
        try await asyncStore.insert(.uniqueItems)

        try await asyncStore
            .remove(.coat)
            .insert(.belt)
            .insert(.belt)
            .run()

        #expect(asyncStore.items.count == 3)
        #expect(asyncStore.items.contains(.sweater))
        #expect(asyncStore.items.contains(.purse))
        #expect(asyncStore.items.contains(.belt))
        #expect(!asyncStore.items.contains(.coat))

        try await asyncStore.removeAll()

        try await asyncStore
            .insert(.belt)
            .insert(.coat)
            .remove([.belt])
            .insert(.sweater)
            .run()

        #expect(asyncStore.items.count == 2)
        #expect(asyncStore.items.contains(.coat))
        #expect(asyncStore.items.contains(.sweater))
        #expect(!asyncStore.items.contains(.belt))

        try await asyncStore.removeAll()

        try await asyncStore
            .insert(.belt)
            .insert(.coat)
            .insert(.purse)
            .remove([.belt, .coat])
            .insert([.sweater])
            .run()

        #expect(asyncStore.items.count == 2)
        #expect(asyncStore.items.contains(.sweater))
        #expect(asyncStore.items.contains(.purse))
        #expect(!asyncStore.items.contains(.coat))
        #expect(!asyncStore.items.contains(.belt))

        try await asyncStore.removeAll()

        try await asyncStore
            .insert(.belt)
            .insert(.coat)
            .insert(.purse)
            .remove(.belt)
            .remove(.coat)
            .insert(.sweater)
            .run()

        #expect(asyncStore.items.count == 2)
        #expect(asyncStore.items.contains(.sweater))
        #expect(asyncStore.items.contains(.purse))
        #expect(!asyncStore.items.contains(.coat))
        #expect(!asyncStore.items.contains(.belt))

        try await asyncStore.removeAll()

        try await asyncStore
            .insert(.coat)
            .insert([.purse, .belt])
            .run()

        #expect(asyncStore.items.count == 3)
        #expect(asyncStore.items.contains(.purse))
        #expect(asyncStore.items.contains(.belt))
        #expect(asyncStore.items.contains(.coat))

        try await asyncStore.removeAll()

        try await asyncStore
            .insert(.coat)
            .insert([.purse, .belt])
            .remove(.purse)
            .run()

        #expect(asyncStore.items.count == 2)
        #expect(!asyncStore.items.contains(.purse))
        #expect(asyncStore.items.contains(.belt))
        #expect(asyncStore.items.contains(.coat))

        try await asyncStore.removeAll()

        try await asyncStore
            .insert([.coat])
            .remove(.coat)
            .insert([.purse, .belt])
            .remove(.purse)
            .run()

        #expect(asyncStore.items.count == 1)
        #expect(!asyncStore.items.contains(.purse))
        #expect(asyncStore.items.contains(.belt))
        #expect(!asyncStore.items.contains(.coat))

        try await asyncStore.removeAll()

        try await asyncStore
            .insert([.coat])
            .remove(.coat)
            .insert([.purse, .belt])
            .removeAll()
            .run()

        #expect(asyncStore.items.count == 0)
        #expect(!asyncStore.items.contains(.purse))
        #expect(!asyncStore.items.contains(.belt))
        #expect(!asyncStore.items.contains(.coat))

        try await asyncStore
            .insert([.coat])
            .removeAll()
            .insert([.purse, .belt])
            .run()

        #expect(asyncStore.items.count == 2)
        #expect(asyncStore.items.contains(.purse))
        #expect(asyncStore.items.contains(.belt))
        #expect(!asyncStore.items.contains(.coat))
    }

    @Test("Test chaining remove operations")
    func testChainingRemoveOperations() async throws {
        try await asyncStore
            .insert(.uniqueItems)
            .remove(.belt)
            .remove(.purse)
            .run()

        #expect(asyncStore.items.count == 2)
        #expect(asyncStore.items.contains(.sweater))
        #expect(asyncStore.items.contains(.coat))

        try await asyncStore.insert(.uniqueItems)
        #expect(asyncStore.items.count == 4)

        try await asyncStore
            .remove([.sweater, .coat])
            .remove(.belt)
            .run()

        #expect(asyncStore.items.count == 1)
        #expect(asyncStore.items.contains(.purse))

        try await asyncStore
            .removeAll()
            .insert(.belt)
            .run()

        #expect(asyncStore.items.count == 1)
        #expect(asyncStore.items.contains(.belt))

        try await asyncStore
            .removeAll()
            .remove(.belt)
            .insert(.belt)
            .run()

        #expect(asyncStore.items.count == 1)
        #expect(asyncStore.items.contains(.belt))
    }

    @Test("Test that chained operations don't execute unless explicitly run")
    func testChainedOperationsDontExecuteUnlessRun() async throws {
        let operation = try await asyncStore
            .insert(.coat)
            .insert([.purse, .belt])

        #expect(asyncStore.items.count == 0)
        #expect(!asyncStore.items.contains(.purse))
        #expect(!asyncStore.items.contains(.belt))
        #expect(!asyncStore.items.contains(.coat))

        // Adding this line to get rid of the error about
        // `operation` being unused, given that's the point of the test.
        _ = operation
    }

    @Test("Test the ability to observe an AsyncStream of Store.events by inserting one value at a time", .timeLimit(.minutes(1)))
    func testAsyncStreamByInsertingSingleItems() async throws {
        let populateStoreTask = Task {
            var accumulatedValues: [BoutiqueItem] = []

            for await event in asyncStore.events {
                try asyncStore.validateStoreEvent(event: event)

                accumulatedValues += event.items

                if accumulatedValues.count == 4 {
                    #expect(accumulatedValues == [.coat, .sweater, .purse, .belt])
                    return true
                }
            }

            return false
        }

        #expect(asyncStore.items.isEmpty)

        Task {
            let uniqueItems = [BoutiqueItem].uniqueItems

            try await asyncStore.insert(uniqueItems[0])
            try await asyncStore.insert(uniqueItems[1])
            try await asyncStore.insert(uniqueItems[2])
            try await asyncStore.insert(uniqueItems[3])
        }

        let populateStoreTaskCompleted = try await populateStoreTask.value
        try #require(populateStoreTaskCompleted)
    }

    @Test("Test the ability to observe an AsyncStream of Store.values by inserting an array of values", .timeLimit(.minutes(1)))
    func testAsyncStreamByInsertingMultipleItems() async throws {
        let populateStoreTask = Task {
            var accumulatedValues: [BoutiqueItem] = []
            for await event in asyncStore.events {
                try asyncStore.validateStoreEvent(event: event)

                accumulatedValues.append(contentsOf: event.items)

                if accumulatedValues.count == 4 {
                    #expect(accumulatedValues == [.coat, .sweater, .purse, .belt])
                    return true
                }
            }

            return false
        }

        #expect(asyncStore.items.isEmpty)

        Task {
            try await asyncStore.insert(.uniqueItems)
        }

        let populateStoreTaskCompleted = try await populateStoreTask.value
        try #require(populateStoreTaskCompleted)
    }

}
