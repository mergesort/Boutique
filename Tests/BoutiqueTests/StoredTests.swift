@testable import Boutique
import Testing

@MainActor
@Suite("@Stored Tests", .serialized)
struct StoredTests {
    @Stored(in: .boutiqueItemsStore) private var items

    init() async throws {
        try await $items.removeAll()
    }

    @Test("Test inserting a single item")
    func testInsertingItem() async throws {
        try await $items.insert(.coat)
        #expect(items.contains(.coat))

        try await $items.insert(.belt)
        #expect(items.contains(.belt))
        #expect(items.count == 2)
    }

    @Test("Test inserting multiple items")
    func testInsertingMultipleItems() async throws {
        try await $items.insert([.coat, .sweater, .sweater, .purse])
        #expect(items.contains(.coat))
        #expect(items.contains(.sweater))
        #expect(items.contains(.purse))
    }

    @Test("Test inserting duplicate items")
    func testInsertingDuplicateItems() async throws {
        #expect(items.isEmpty)
        try await $items.insert(.allItems)
        #expect(items.count == 4)
    }

    @Test("Test reading items")
    func testReadingItems() async throws {
        try await $items.insert(.allItems)

        #expect(items[0] == .coat)
        #expect(items[1] == .sweater)
        #expect(items[2] == .purse)
        #expect(items[3] == .belt)

        #expect(items.count == 4)
    }

    @Test("Test reading items persisted in a Store")
    func testReadingPersistedItems() async throws {
        try await $items.insert(.allItems)

        // The new store has to fetch items from disk.
        let newStore = try await Store<BoutiqueItem>(
            storage: SQLiteStorageEngine.default(appendingPath: "StoredTests"),
            cacheIdentifier: \.merchantID
        )

        #expect(newStore.items.count == 4)

        #expect(newStore.items[0] == .coat)
        #expect(newStore.items[1] == .sweater)
        #expect(newStore.items[2] == .purse)
        #expect(newStore.items[3] == .belt)
    }

    @Test("Test removing items")
    func testRemovingSingleItems() async throws {
        try await $items.insert(.allItems)
        try await $items.remove(.coat)

        #expect(!items.contains(.coat))

        #expect(items.contains(.sweater))
        #expect(items.contains(.purse))

        try await $items.remove([.sweater, .purse])
        #expect(!items.contains(.sweater))
        #expect(!items.contains(.purse))
    }

    @Test("Test removing all items")
    func testRemoveAll() async throws {
        try await $items.insert(.coat)
        #expect(items.count == 1)
        try await $items.removeAll()

        try await $items.insert(.uniqueItems)
        #expect(items.count == 4)
        try await $items.removeAll()
        #expect(items.isEmpty)
    }

    @Test("Test chaining insert operations")
    func testChainingInsertOperations() async throws {
        try await $items.insert(.uniqueItems)

        try await $items
            .remove(.coat)
            .insert(.belt)
            .insert(.belt)
            .run()

        #expect(items.count == 3)
        #expect(items.contains(.sweater))
        #expect(items.contains(.purse))
        #expect(items.contains(.belt))
        #expect(!items.contains(.coat))

        try await $items.removeAll()

        try await $items
            .insert(.belt)
            .insert(.coat)
            .remove([.belt])
            .insert(.sweater)
            .run()

        #expect(items.count == 2)
        #expect(items.contains(.coat))
        #expect(items.contains(.sweater))
        #expect(!items.contains(.belt))

        try await $items.removeAll()

        try await $items
            .insert(.belt)
            .insert(.coat)
            .insert(.purse)
            .remove([.belt, .coat])
            .insert([.sweater])
            .run()

        #expect(items.count == 2)
        #expect(items.contains(.sweater))
        #expect(items.contains(.purse))
        #expect(!items.contains(.coat))
        #expect(!items.contains(.belt))

        try await $items.removeAll()

        try await $items
            .insert(.belt)
            .insert(.coat)
            .insert(.purse)
            .remove(.belt)
            .remove(.coat)
            .insert(.sweater)
            .run()

        #expect(items.count == 2)
        #expect(items.contains(.sweater))
        #expect(items.contains(.purse))
        #expect(!items.contains(.coat))
        #expect(!items.contains(.belt))

        try await $items.removeAll()

        try await $items
            .insert(.coat)
            .insert([.purse, .belt])
            .run()

        #expect(items.count == 3)
        #expect(items.contains(.purse))
        #expect(items.contains(.belt))
        #expect(items.contains(.coat))

        try await $items.removeAll()

        try await $items
            .insert(.coat)
            .insert([.purse, .belt])
            .remove(.purse)
            .run()

        #expect(items.count == 2)
        #expect(!items.contains(.purse))
        #expect(items.contains(.belt))
        #expect(items.contains(.coat))

        try await $items.removeAll()

        try await $items
            .insert([.coat])
            .remove(.coat)
            .insert([.purse, .belt])
            .remove(.purse)
            .run()

        #expect(items.count == 1)
        #expect(!items.contains(.purse))
        #expect(items.contains(.belt))
        #expect(!items.contains(.coat))

        try await $items.removeAll()

        try await $items
            .insert([.coat])
            .remove(.coat)
            .insert([.purse, .belt])
            .removeAll()
            .run()

        #expect(items.count == 0)
        #expect(!items.contains(.purse))
        #expect(!items.contains(.belt))
        #expect(!items.contains(.coat))

        try await $items
            .insert([.coat])
            .removeAll()
            .insert([.purse, .belt])
            .run()

        #expect(items.count == 2)
        #expect(items.contains(.purse))
        #expect(items.contains(.belt))
        #expect(!items.contains(.coat))
    }

    @Test("Test chaining remove operations")
    func testChainingRemoveOperations() async throws {
        try await $items
            .insert(.uniqueItems)
            .remove(.belt)
            .remove(.purse)
            .run()

        #expect(items.count == 2)
        #expect(items.contains(.sweater))
        #expect(items.contains(.coat))

        try await $items.insert(.uniqueItems)
        #expect(items.count == 4)

        try await $items
            .remove([.sweater, .coat])
            .remove(.belt)
            .run()

        #expect(items.count == 1)
        #expect(items.contains(.purse))

        try await $items
            .removeAll()
            .insert(.belt)
            .run()

        #expect(items.count == 1)
        #expect(items.contains(.belt))

        try await $items
            .removeAll()
            .remove(.belt)
            .insert(.belt)
            .run()

        #expect(items.count == 1)
        #expect(items.contains(.belt))
    }

    @Test("Test that chained operations don't execute unless explicitly run")
    func testChainedOperationsDontExecuteUnlessRun() async throws {
        let operation = try await $items
            .insert(.coat)
            .insert([.purse, .belt])

        #expect(items.count == 0)
        #expect(!items.contains(.purse))
        #expect(!items.contains(.belt))
        #expect(!items.contains(.coat))

        // Adding this line to get rid of the error about
        // `operation` being unused, given that's the point of the test.
        _ = operation
    }

    @Test("Test the ability to observe an AsyncStream of Stored.events by inserting one value at a time", .timeLimit(.minutes(1)))
    func testAsyncStreamByInsertingSingleItems() async throws {
        let populateStoreTask = Task {
            var accumulatedValues: [BoutiqueItem] = []

            for await event in $items.events {
                try $items.validateStoreEvent(event: event)

                accumulatedValues += event.items

                if accumulatedValues.count == 4 {
                    #expect(accumulatedValues == [.coat, .sweater, .purse, .belt])
                    return true
                }
            }

            return false
        }

        #expect(items.isEmpty)

        Task {
            let uniqueItems = [BoutiqueItem].uniqueItems

            try await $items.insert(uniqueItems[0])
            try await $items.insert(uniqueItems[1])
            try await $items.insert(uniqueItems[2])
            try await $items.insert(uniqueItems[3])
        }

        let populateStoreTaskCompleted = try await populateStoreTask.value
        try #require(populateStoreTaskCompleted)
    }

    @Test("Test the ability to observe an AsyncStream of Stored.values by inserting an array of values", .timeLimit(.minutes(1)))
    func testAsyncStreamByInsertingMultipleItems() async throws {
        let populateStoreTask = Task {
            var accumulatedValues: [BoutiqueItem] = []

            for await event in $items.events {
                try $items.validateStoreEvent(event: event)

                accumulatedValues.append(contentsOf: event.items)

                if accumulatedValues.count == 4 {
                    #expect(accumulatedValues == [.coat, .sweater, .purse, .belt])
                    return true
                }
            }

            return false
        }

        #expect(items.isEmpty)

        Task {
            try await $items.insert(.uniqueItems)
        }

        let populateStoreTaskCompleted = try await populateStoreTask.value
        try #require(populateStoreTaskCompleted)
    }
}

private extension Store where Item == BoutiqueItem {
    static let boutiqueItemsStore = Store<BoutiqueItem>(
        storage: SQLiteStorageEngine.default(appendingPath: "StoredTests")
    )
}
