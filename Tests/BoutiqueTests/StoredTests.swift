@testable import Boutique
import Testing

@MainActor
@Suite("@Stored Tests")
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

//    @Test("observable subscription inserting items")
//    func testObservableSubscriptionInsertingItems() async throws {
//        let uniqueItems = [BoutiqueItem].uniqueItems
//        let expectation = XCTestExpectation(description: "uniqueItems is published and read")
//
//        withObservationTracking({
//            _ = self.items
//        }, onChange: {
//            Task { @MainActor in
//                #expect(self.items == uniqueItems)
//                expectation.fulfill()
//            }
//        })
//
//        #expect(items.isEmpty)
//
//        // Sets items under the hood
//        try await $items.insert(uniqueItems)
//        await fulfillment(of: [expectation], timeout: 1.0)
//    }
}

private extension Store where Item == BoutiqueItem {
    static let boutiqueItemsStore = Store<BoutiqueItem>(
        storage: SQLiteStorageEngine.default(appendingPath: "StoredTests")
    )
}
