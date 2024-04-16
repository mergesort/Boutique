@testable import Boutique
import Combine
import XCTest

final class StoreTests: XCTestCase {
    private var store: Store<BoutiqueItem>!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() async throws {
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

    override func tearDown() {
        cancellables.removeAll()
    }

    @MainActor
    func testInsertingItem() async throws {
        try await store.insert(.coat)
        XCTAssertTrue(store.items.contains(.coat))

        try await store.insert(.belt)
        XCTAssertTrue(store.items.contains(.belt))
        XCTAssertEqual(store.items.count, 2)
    }

    @MainActor
    func testInsertingItems() async throws {
        try await store.insert([.coat, .sweater, .sweater, .purse])
        XCTAssertTrue(store.items.contains(.coat))
        XCTAssertTrue(store.items.contains(.sweater))
        XCTAssertTrue(store.items.contains(.purse))
    }

    @MainActor
    func testInsertingDuplicateItems() async throws {
        XCTAssertTrue(store.items.isEmpty)
        try await store.insert(.allItems)
        XCTAssertEqual(store.items.count, 4)
    }

    @MainActor
    func testReadingItems() async throws {
        try await store.insert(.allItems)

        XCTAssertEqual(store.items[0], .coat)
        XCTAssertEqual(store.items[1], .sweater)
        XCTAssertEqual(store.items[2], .purse)
        XCTAssertEqual(store.items[3], .belt)

        XCTAssertEqual(store.items.count, 4)
    }

    @MainActor
    func testReadingPersistedItems() async throws {
        try await store.insert(.allItems)

        // The new store has to fetch items from disk.
        let newStore = try await Store<BoutiqueItem>(
            storage: SQLiteStorageEngine.default(appendingPath: "Tests"),
            cacheIdentifier: \.merchantID)

        XCTAssertEqual(newStore.items[0], .coat)
        XCTAssertEqual(newStore.items[1], .sweater)
        XCTAssertEqual(newStore.items[2], .purse)
        XCTAssertEqual(newStore.items[3], .belt)

        XCTAssertEqual(newStore.items.count, 4)
    }

    @MainActor
    func testRemovingItems() async throws {
        try await store.insert(.allItems)
        try await store.remove(.coat)

        XCTAssertFalse(store.items.contains(.coat))

        XCTAssertTrue(store.items.contains(.sweater))
        XCTAssertTrue(store.items.contains(.purse))

        try await store.remove([.sweater, .purse])
        XCTAssertFalse(store.items.contains(.sweater))
        XCTAssertFalse(store.items.contains(.purse))
    }

    @MainActor
    func testRemoveAll() async throws {
        try await store.insert(.coat)
        XCTAssertEqual(store.items.count, 1)
        try await store.removeAll()

        try await store.insert(.uniqueItems)
        XCTAssertEqual(store.items.count, 4)
        try await store.removeAll()
        XCTAssertTrue(store.items.isEmpty)
    }

    @MainActor
    func testChainingInsertOperations() async throws {
        try await store.insert(.uniqueItems)

        try await store
            .remove(.coat)
            .insert(.belt)
            .insert(.belt)
            .run()

        XCTAssertEqual(store.items.count, 3)
        XCTAssertTrue(store.items.contains(.sweater))
        XCTAssertTrue(store.items.contains(.purse))
        XCTAssertTrue(store.items.contains(.belt))
        XCTAssertFalse(store.items.contains(.coat))

        try await store.removeAll()

        try await store
            .insert(.belt)
            .insert(.coat)
            .remove([.belt])
            .insert(.sweater)
            .run()

        XCTAssertEqual(store.items.count, 2)
        XCTAssertTrue(store.items.contains(.coat))
        XCTAssertTrue(store.items.contains(.sweater))
        XCTAssertFalse(store.items.contains(.belt))

        try await store.removeAll()

        try await store
            .insert(.belt)
            .insert(.coat)
            .insert(.purse)
            .remove([.belt, .coat])
            .insert([.sweater])
            .run()

        XCTAssertEqual(store.items.count, 2)
        XCTAssertTrue(store.items.contains(.sweater))
        XCTAssertTrue(store.items.contains(.purse))
        XCTAssertFalse(store.items.contains(.coat))
        XCTAssertFalse(store.items.contains(.belt))

        try await store.removeAll()

        try await store
            .insert(.belt)
            .insert(.coat)
            .insert(.purse)
            .remove(.belt)
            .remove(.coat)
            .insert(.sweater)
            .run()

        XCTAssertEqual(store.items.count, 2)
        XCTAssertTrue(store.items.contains(.sweater))
        XCTAssertTrue(store.items.contains(.purse))
        XCTAssertFalse(store.items.contains(.coat))
        XCTAssertFalse(store.items.contains(.belt))

        try await store.removeAll()

        try await store
            .insert(.coat)
            .insert([.purse, .belt])
            .run()

        XCTAssertEqual(store.items.count, 3)
        XCTAssertTrue(store.items.contains(.purse))
        XCTAssertTrue(store.items.contains(.belt))
        XCTAssertTrue(store.items.contains(.coat))

        try await store.removeAll()

        try await store
            .insert(.coat)
            .insert([.purse, .belt])
            .remove(.purse)
            .run()

        XCTAssertEqual(store.items.count, 2)
        XCTAssertFalse(store.items.contains(.purse))
        XCTAssertTrue(store.items.contains(.belt))
        XCTAssertTrue(store.items.contains(.coat))

        try await store.removeAll()

        try await store
            .insert([.coat])
            .remove(.coat)
            .insert([.purse, .belt])
            .remove(.purse)
            .run()

        XCTAssertEqual(store.items.count, 1)
        XCTAssertFalse(store.items.contains(.purse))
        XCTAssertTrue(store.items.contains(.belt))
        XCTAssertFalse(store.items.contains(.coat))

        try await store.removeAll()

        try await store
            .insert([.coat])
            .remove(.coat)
            .insert([.purse, .belt])
            .removeAll()
            .run()

        XCTAssertEqual(store.items.count, 0)
        XCTAssertFalse(store.items.contains(.purse))
        XCTAssertFalse(store.items.contains(.belt))
        XCTAssertFalse(store.items.contains(.coat))

        try await store
            .insert([.coat])
            .removeAll()
            .insert([.purse, .belt])
            .run()

        XCTAssertEqual(store.items.count, 2)
        XCTAssertTrue(store.items.contains(.purse))
        XCTAssertTrue(store.items.contains(.belt))
        XCTAssertFalse(store.items.contains(.coat))
    }

    @MainActor
    func testChainingRemoveOperations() async throws {
        try await store
            .insert(.uniqueItems)
            .remove(.belt)
            .remove(.purse)
            .run()

        XCTAssertEqual(store.items.count, 2)
        XCTAssertTrue(store.items.contains(.sweater))
        XCTAssertTrue(store.items.contains(.coat))

        try await store.insert(.uniqueItems)
        XCTAssertEqual(store.items.count, 4)

        try await store
            .remove([.sweater, .coat])
            .remove(.belt)
            .run()

        XCTAssertEqual(store.items.count, 1)
        XCTAssertTrue(store.items.contains(.purse))

        try await store
            .removeAll()
            .insert(.belt)
            .run()

        XCTAssertEqual(store.items.count, 1)
        XCTAssertTrue(store.items.contains(.belt))

        try await store
            .removeAll()
            .remove(.belt)
            .insert(.belt)
            .run()

        XCTAssertEqual(store.items.count, 1)
        XCTAssertTrue(store.items.contains(.belt))
    }

    @MainActor
    func testChainingOperationsDontExecuteUnlessRun() async throws {
        let operation = try await store
            .insert(.coat)
            .insert([.purse, .belt])

        XCTAssertEqual(store.items.count, 0)
        XCTAssertFalse(store.items.contains(.purse))
        XCTAssertFalse(store.items.contains(.belt))
        XCTAssertFalse(store.items.contains(.coat))

        // Adding this line to get rid of the error about
        // `operation` being unused, given that's the point of the test.
        _ = operation
    }

    @MainActor
    func testPublishedItemsSubscription() async throws {
        let uniqueItems: [BoutiqueItem] = .uniqueItems
        let expectation = XCTestExpectation(description: "uniqueItems is published and read")

        store.$items
            .dropFirst()
            .sink(receiveValue: { items in
                XCTAssertEqual(items, uniqueItems)
                expectation.fulfill()
            })
            .store(in: &cancellables)

        XCTAssertTrue(store.items.isEmpty)

        // Sets items under the hood
        try await store.insert(uniqueItems)
        wait(for: [expectation], timeout: 1)
    }
}

