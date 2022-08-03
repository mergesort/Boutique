@testable import Boutique
import Combine
import XCTest

final class StoreTests: XCTestCase {

    private var store: Store<BoutiqueItem>!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() async throws {
        store = Store<BoutiqueItem>(
            storage: SQLiteStorageEngine.default(appendingPath: "Tests"),
            cacheIdentifier: \.merchantID)

        try await store.removeAll()
    }

    @MainActor
    func testStoreWithItemsInitializer() async {
        let store = await Store<BoutiqueItem>(
            storage: DiskStorageEngine(directory: .documents(appendingPath: "Items")),
            items: [.belt, .sweater, .purse],
            cacheIdentifier: \.merchantID
        )

        XCTAssertEqual(store.items.count, 3)
        XCTAssertEqual(store.items[0], .belt)
        XCTAssertEqual(store.items[1], .sweater)
        XCTAssertEqual(store.items[2], .purse)
    }

    @MainActor
    func testAddingItem() async throws {
        try await store.add(BoutiqueItem.coat)
        XCTAssertTrue(store.items.contains(BoutiqueItem.coat))

        try await store.add(BoutiqueItem.belt)
        XCTAssertTrue(store.items.contains(BoutiqueItem.belt))
        XCTAssertEqual(store.items.count, 2)
    }

    @MainActor
    func testAddingItems() async throws {
        try await store.add([BoutiqueItem.coat, BoutiqueItem.sweater, BoutiqueItem.sweater, BoutiqueItem.purse])
        XCTAssertTrue(store.items.contains(BoutiqueItem.coat))
        XCTAssertTrue(store.items.contains(BoutiqueItem.sweater))
        XCTAssertTrue(store.items.contains(BoutiqueItem.purse))
    }

    @MainActor
    func testAddingDuplicateItems() async throws {
        XCTAssertTrue(store.items.isEmpty)
        try await store.add(BoutiqueItem.allItems)
        XCTAssertEqual(store.items.count, 4)
    }

    @MainActor
    func testReadingItems() async throws {
        try await store.add(BoutiqueItem.allItems)

        XCTAssertEqual(store.items[0], BoutiqueItem.coat)
        XCTAssertEqual(store.items[1], BoutiqueItem.sweater)
        XCTAssertEqual(store.items[2], BoutiqueItem.purse)
        XCTAssertEqual(store.items[3], BoutiqueItem.belt)

        XCTAssertEqual(store.items.count, 4)
    }

    @MainActor
    func testRemovingItems() async throws {
        try await store.add(BoutiqueItem.allItems)
        try await store.remove(BoutiqueItem.coat)

        XCTAssertFalse(store.items.contains(BoutiqueItem.coat))

        XCTAssertTrue(store.items.contains(BoutiqueItem.sweater))
        XCTAssertTrue(store.items.contains(BoutiqueItem.purse))

        try await store.remove([BoutiqueItem.sweater, BoutiqueItem.purse])
        XCTAssertFalse(store.items.contains(BoutiqueItem.sweater))
        XCTAssertFalse(store.items.contains(BoutiqueItem.purse))
    }

    @MainActor
    func testRemoveAll() async throws {
        try await store.add(BoutiqueItem.coat)
        XCTAssertEqual(store.items.count, 1)
        try await store.removeAll()

        try await store.add(BoutiqueItem.uniqueItems)
        XCTAssertEqual(store.items.count, 4)
        try await store.removeAll()
        XCTAssertTrue(store.items.isEmpty)
    }

    @MainActor
    func testChainingAddOperations() async throws {
        try await store.add(BoutiqueItem.uniqueItems)

        try await store
            .remove(BoutiqueItem.coat)
            .add(BoutiqueItem.belt)
            .add(BoutiqueItem.belt)
            .run()

        XCTAssertEqual(store.items.count, 3)
        XCTAssertTrue(store.items.contains(BoutiqueItem.sweater))
        XCTAssertTrue(store.items.contains(BoutiqueItem.purse))
        XCTAssertTrue(store.items.contains(BoutiqueItem.belt))
        XCTAssertFalse(store.items.contains(BoutiqueItem.coat))

        try await store.removeAll()

        try await store
            .add(BoutiqueItem.coat)
            .add([BoutiqueItem.purse, BoutiqueItem.belt])
            .run()

        XCTAssertEqual(store.items.count, 3)
        XCTAssertTrue(store.items.contains(BoutiqueItem.purse))
        XCTAssertTrue(store.items.contains(BoutiqueItem.belt))
        XCTAssertTrue(store.items.contains(BoutiqueItem.coat))
    }

    @MainActor
    func testChainingRemoveOperations() async throws {
        try await store
            .add(BoutiqueItem.uniqueItems)
            .remove(BoutiqueItem.belt)
            .remove(BoutiqueItem.purse)
            .run()

        XCTAssertEqual(store.items.count, 2)
        XCTAssertTrue(store.items.contains(BoutiqueItem.sweater))
        XCTAssertTrue(store.items.contains(BoutiqueItem.coat))

        try await store.add(BoutiqueItem.uniqueItems)
        XCTAssertEqual(store.items.count, 4)

        try await store
            .remove([BoutiqueItem.sweater, BoutiqueItem.coat])
            .remove(BoutiqueItem.belt)
            .run()

        XCTAssertEqual(store.items.count, 1)
        XCTAssertTrue(store.items.contains(BoutiqueItem.purse))

        try await store
            .removeAll()
            .add(BoutiqueItem.belt)
            .run()

        XCTAssertEqual(store.items.count, 1)
        XCTAssertTrue(store.items.contains(BoutiqueItem.belt))
    }

    @MainActor
    func testChainingOperationsDontExecuteUnlessRun() async throws {
        let operation = try await store
            .add(BoutiqueItem.coat)
            .add([BoutiqueItem.purse, BoutiqueItem.belt])

        XCTAssertEqual(store.items.count, 0)
        XCTAssertFalse(store.items.contains(BoutiqueItem.purse))
        XCTAssertFalse(store.items.contains(BoutiqueItem.belt))
        XCTAssertFalse(store.items.contains(BoutiqueItem.coat))

        // Adding this line to get rid of the error about
        // `operation` being unused, given that's the point of the test.
        _ = operation
    }

    @MainActor
    func testPublishedItemsSubscription() async throws {
        let uniqueItems = BoutiqueItem.uniqueItems
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
        try await store.add(uniqueItems)
        wait(for: [expectation], timeout: 1)
    }

}
