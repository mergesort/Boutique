@testable import Boutique
import Testing

@MainActor
@Suite("Store Tests")
struct StoreTests {
    private var store: Store<BoutiqueItem>!

    init() async throws {
        // Returns a `Store` using the non-async init. This is a workaround for Swift prioritizing the
        // `async` version of the overload while in an `async` context, such as the `setUp()` here.
        // There's a separate `AsyncStoreTests` file with matching tests using the async init.
        func makeNonAsyncStore() -> Store<BoutiqueItem> {
            Store<BoutiqueItem>(
                storage: SQLiteStorageEngine.default(appendingPath: "Tests"),
                cacheIdentifier: \.merchantID)
        }

        store = makeNonAsyncStore()
        try await store.removeAll()
    }

    @Test("Test inserting a single item")
    func testInsertingItem() async throws {
        try await store.insert(.coat)
        #expect(store.items.contains(.coat))

        try await store.insert(.belt)
        #expect(store.items.contains(.belt))
        #expect(store.items.count == 2)
    }

    @Test("Test inserting multiple items")
    func testInsertingMultipleItems() async throws {
        try await store.insert([.coat, .sweater, .sweater, .purse])
        #expect(store.items.contains(.coat))
        #expect(store.items.contains(.sweater))
        #expect(store.items.contains(.purse))
    }

    @Test("Test inserting duplicate items")
    func testInsertingDuplicateItems() async throws {
        #expect(store.items.isEmpty)
        try await store.insert(.allItems)
        #expect(store.items.count == 4)
    }

    @Test("Test reading items")
    func testReadingItems() async throws {
        try await store.insert(.allItems)

        #expect(store.items[0] == .coat)
        #expect(store.items[1] == .sweater)
        #expect(store.items[2] == .purse)
        #expect(store.items[3] == .belt)

        #expect(store.items.count == 4)
    }

    @Test("Test reading items persisted in a Store")
    func testReadingPersistedItems() async throws {
        try await store.insert(.allItems)

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
        try await store.insert(.allItems)
        try await store.remove(.coat)

        #expect(!store.items.contains(.coat))

        #expect(store.items.contains(.sweater))
        #expect(store.items.contains(.purse))

        try await store.remove([.sweater, .purse])
        #expect(!store.items.contains(.sweater))
        #expect(!store.items.contains(.purse))
    }

    @Test("Test removing all items")
    func testRemoveAll() async throws {
        try await store.insert(.coat)
        #expect(store.items.count == 1)
        try await store.removeAll()

        try await store.insert(.uniqueItems)
        #expect(store.items.count == 4)
        try await store.removeAll()
        #expect(store.items.isEmpty)
    }

    @Test("Test chaining insert operations")
    func testChainingInsertOperations() async throws {
        try await store.insert(.uniqueItems)

        try await store
            .remove(.coat)
            .insert(.belt)
            .insert(.belt)
            .run()

        #expect(store.items.count == 3)
        #expect(store.items.contains(.sweater))
        #expect(store.items.contains(.purse))
        #expect(store.items.contains(.belt))
        #expect(!store.items.contains(.coat))

        try await store.removeAll()

        try await store
            .insert(.belt)
            .insert(.coat)
            .remove([.belt])
            .insert(.sweater)
            .run()

        #expect(store.items.count == 2)
        #expect(store.items.contains(.coat))
        #expect(store.items.contains(.sweater))
        #expect(!store.items.contains(.belt))

        try await store.removeAll()

        try await store
            .insert(.belt)
            .insert(.coat)
            .insert(.purse)
            .remove([.belt, .coat])
            .insert([.sweater])
            .run()

        #expect(store.items.count == 2)
        #expect(store.items.contains(.sweater))
        #expect(store.items.contains(.purse))
        #expect(!store.items.contains(.coat))
        #expect(!store.items.contains(.belt))

        try await store.removeAll()

        try await store
            .insert(.belt)
            .insert(.coat)
            .insert(.purse)
            .remove(.belt)
            .remove(.coat)
            .insert(.sweater)
            .run()

        #expect(store.items.count == 2)
        #expect(store.items.contains(.sweater))
        #expect(store.items.contains(.purse))
        #expect(!store.items.contains(.coat))
        #expect(!store.items.contains(.belt))

        try await store.removeAll()

        try await store
            .insert(.coat)
            .insert([.purse, .belt])
            .run()

        #expect(store.items.count == 3)
        #expect(store.items.contains(.purse))
        #expect(store.items.contains(.belt))
        #expect(store.items.contains(.coat))

        try await store.removeAll()

        try await store
            .insert(.coat)
            .insert([.purse, .belt])
            .remove(.purse)
            .run()

        #expect(store.items.count == 2)
        #expect(!store.items.contains(.purse))
        #expect(store.items.contains(.belt))
        #expect(store.items.contains(.coat))

        try await store.removeAll()

        try await store
            .insert([.coat])
            .remove(.coat)
            .insert([.purse, .belt])
            .remove(.purse)
            .run()

        #expect(store.items.count == 1)
        #expect(!store.items.contains(.purse))
        #expect(store.items.contains(.belt))
        #expect(!store.items.contains(.coat))

        try await store.removeAll()

        try await store
            .insert([.coat])
            .remove(.coat)
            .insert([.purse, .belt])
            .removeAll()
            .run()

        #expect(store.items.count == 0)
        #expect(!store.items.contains(.purse))
        #expect(!store.items.contains(.belt))
        #expect(!store.items.contains(.coat))

        try await store
            .insert([.coat])
            .removeAll()
            .insert([.purse, .belt])
            .run()

        #expect(store.items.count == 2)
        #expect(store.items.contains(.purse))
        #expect(store.items.contains(.belt))
        #expect(!store.items.contains(.coat))
    }

    @Test("Test chaining remove operations")
    func testChainingRemoveOperations() async throws {
        try await store
            .insert(.uniqueItems)
            .remove(.belt)
            .remove(.purse)
            .run()

        #expect(store.items.count == 2)
        #expect(store.items.contains(.sweater))
        #expect(store.items.contains(.coat))

        try await store.insert(.uniqueItems)
        #expect(store.items.count == 4)

        try await store
            .remove([.sweater, .coat])
            .remove(.belt)
            .run()

        #expect(store.items.count == 1)
        #expect(store.items.contains(.purse))

        try await store
            .removeAll()
            .insert(.belt)
            .run()

        #expect(store.items.count == 1)
        #expect(store.items.contains(.belt))

        try await store
            .removeAll()
            .remove(.belt)
            .insert(.belt)
            .run()

        #expect(store.items.count == 1)
        #expect(store.items.contains(.belt))
    }

    @Test("Test that chained operations don't execute unless explicitly run")
    func testChainedOperationsDontExecuteUnlessRun() async throws {
        let operation = try await store
            .insert(.coat)
            .insert([.purse, .belt])

        #expect(store.items.count == 0)
        #expect(!store.items.contains(.purse))
        #expect(!store.items.contains(.belt))
        #expect(!store.items.contains(.coat))

        // Adding this line to get rid of the error about
        // `operation` being unused, given that's the point of the test.
        _ = operation
    }

//    @Test("observable subscription inserting items")
//    func testObservableSubscriptionInsertingItems() async throws {
//        let uniqueItems = [BoutiqueItem].uniqueItems
//        let expectation = #await(description: "uniqueItems is published and read")
//
//        withObservationTracking({
//            _ = self.store.items
//        }, onChange: {
//            Task { @MainActor in
//                #expect(self.store.items == uniqueItems)
//                expectation.fulfill()
//            }
//        })
//
//        #expect(self.store.items.isEmpty)
//
//        // Sets items under the hood
//        try await self.store.insert(uniqueItems)
//        await expectation.fulfill()
//    }

//    @Test("observable subscription")
//    func testObservableSubscription() async throws {
//        let uniqueItems = [BoutiqueItem].uniqueItems
//
//        #expect(store.items.isEmpty)
//
//        try await store.insert(.coat)
//        try await store.insert(.sweater)
//        try await store.insert(.purse)
//        try await store.insert(.belt)
//
//        await assertEventuallyEqual(store.items, uniqueItems)
//    }
}

//extension StoreTests {
//    func assertEventuallyEqual<T: Equatable>(
//        _ expression1: @autoclosure () -> T,
//        _ expression2: @autoclosure () -> T,
//        timeout: TimeInterval = 5,
//        _ message: @autoclosure () -> String = "",
//        file: StaticString = #filePath,
//        line: UInt = #line
//    ) async {
//        let exp = #await(description: "\(#function):\(file):\(line)")
//        withObservationTracking(
//            {
//            _ = expression1()
//            },
//            onChange: {
//                exp.fulfill()
//            }
//        )
//        await exp.fulfill()
//        #expect(expression1() == expression2(), message())
//    }
//}
