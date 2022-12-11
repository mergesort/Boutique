@testable import Boutique
import Combine
import XCTest

extension Store where Item == BoutiqueItem {
  static let boutiqueItemStore = Store<BoutiqueItem>(
    storage: SQLiteStorageEngine.default(appendingPath: "StoredTests")
  )
}

final class StoredTests: XCTestCase {
    
    @Stored(in: .boutiqueItemStore) private var items
    
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() async throws {
        try await $items.itemsHaveLoaded()
        try await $items.removeAll()
    }
  
  override func tearDown() {
    cancellables.removeAll()
  }


    @MainActor
    func testInsertingItem() async throws {
        try await $items.insert(BoutiqueItem.coat)
        XCTAssertTrue(items.contains(BoutiqueItem.coat))

        try await $items.insert(BoutiqueItem.belt)
        XCTAssertTrue(items.contains(BoutiqueItem.belt))
        XCTAssertEqual(items.count, 2)
    }

    @MainActor
    func testInsertingItems() async throws {
        try await $items.insert([BoutiqueItem.coat, BoutiqueItem.sweater, BoutiqueItem.sweater, BoutiqueItem.purse])
        XCTAssertTrue(items.contains(BoutiqueItem.coat))
        XCTAssertTrue(items.contains(BoutiqueItem.sweater))
        XCTAssertTrue(items.contains(BoutiqueItem.purse))
    }

    @MainActor
    func testInsertingDuplicateItems() async throws {
        XCTAssertTrue(items.isEmpty)
        try await $items.insert(BoutiqueItem.allItems)
        XCTAssertEqual(items.count, 4)
    }

    @MainActor
    func testReadingItems() async throws {
        try await $items.insert(BoutiqueItem.allItems)
        
        XCTAssertEqual(items[0], BoutiqueItem.coat)
        XCTAssertEqual(items[1], BoutiqueItem.sweater)
        XCTAssertEqual(items[2], BoutiqueItem.purse)
        XCTAssertEqual(items[3], BoutiqueItem.belt)

        XCTAssertEqual(items.count, 4)
    }

    @MainActor
    func testReadingPersistedItems() async throws {
        try await $items.insert(BoutiqueItem.allItems)

        // The new store has to fetch items from disk.
        let newStore = try await Store<BoutiqueItem>(
            storage: SQLiteStorageEngine.default(appendingPath: "StoredTests"),
            cacheIdentifier: \.merchantID)

        XCTAssertEqual(newStore.items.count, 4)

        XCTAssertEqual(newStore.items[0], BoutiqueItem.coat)
        XCTAssertEqual(newStore.items[1], BoutiqueItem.sweater)
        XCTAssertEqual(newStore.items[2], BoutiqueItem.purse)
        XCTAssertEqual(newStore.items[3], BoutiqueItem.belt)
    }

    @MainActor
    func testRemovingItems() async throws {
        try await $items.insert(BoutiqueItem.allItems)
        try await $items.remove(BoutiqueItem.coat)

        XCTAssertFalse(items.contains(BoutiqueItem.coat))

        XCTAssertTrue(items.contains(BoutiqueItem.sweater))
        XCTAssertTrue(items.contains(BoutiqueItem.purse))

        try await $items.remove([BoutiqueItem.sweater, BoutiqueItem.purse])
        XCTAssertFalse(items.contains(BoutiqueItem.sweater))
        XCTAssertFalse(items.contains(BoutiqueItem.purse))
    }

    @MainActor
    func testRemoveAll() async throws {
        try await $items.insert(BoutiqueItem.coat)
        XCTAssertEqual(items.count, 1)
        try await $items.removeAll()

        try await $items.insert(BoutiqueItem.uniqueItems)
        XCTAssertEqual(items.count, 4)
        try await $items.removeAll()
        XCTAssertTrue(items.isEmpty)
    }

    @MainActor
    func testChainingInsertOperations() async throws {
        try await $items.insert(BoutiqueItem.uniqueItems)

        try await $items
            .remove(BoutiqueItem.coat)
            .insert(BoutiqueItem.belt)
            .insert(BoutiqueItem.belt)
            .run()

        XCTAssertEqual(items.count, 3)
        XCTAssertTrue(items.contains(BoutiqueItem.sweater))
        XCTAssertTrue(items.contains(BoutiqueItem.purse))
        XCTAssertTrue(items.contains(BoutiqueItem.belt))
        XCTAssertFalse(items.contains(BoutiqueItem.coat))

        try await $items.removeAll()

        try await $items
            .insert(BoutiqueItem.belt)
            .insert(BoutiqueItem.coat)
            .remove([BoutiqueItem.belt])
            .insert(BoutiqueItem.sweater)
            .run()

        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.contains(BoutiqueItem.coat))
        XCTAssertTrue(items.contains(BoutiqueItem.sweater))
        XCTAssertFalse(items.contains(BoutiqueItem.belt))

        try await $items
            .insert(BoutiqueItem.belt)
            .insert(BoutiqueItem.coat)
            .insert(BoutiqueItem.purse)
            .remove([BoutiqueItem.belt, .coat])
            .insert(BoutiqueItem.sweater)
            .run()

        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.contains(BoutiqueItem.sweater))
        XCTAssertTrue(items.contains(BoutiqueItem.purse))
        XCTAssertFalse(items.contains(BoutiqueItem.coat))
        XCTAssertFalse(items.contains(BoutiqueItem.belt))

        try await $items.removeAll()

        try await $items
            .insert(BoutiqueItem.coat)
            .insert([BoutiqueItem.purse, BoutiqueItem.belt])
            .run()

        XCTAssertEqual(items.count, 3)
        XCTAssertTrue(items.contains(BoutiqueItem.purse))
        XCTAssertTrue(items.contains(BoutiqueItem.belt))
        XCTAssertTrue(items.contains(BoutiqueItem.coat))
    }

    @MainActor
    func testChainingRemoveOperations() async throws {
        try await $items
            .insert(BoutiqueItem.uniqueItems)
            .remove(BoutiqueItem.belt)
            .remove(BoutiqueItem.purse)
            .run()

        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.contains(BoutiqueItem.sweater))
        XCTAssertTrue(items.contains(BoutiqueItem.coat))

        try await $items.insert(BoutiqueItem.uniqueItems)
        XCTAssertEqual(items.count, 4)

        try await $items
            .remove([BoutiqueItem.sweater, BoutiqueItem.coat])
            .remove(BoutiqueItem.belt)
            .run()

        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items.contains(BoutiqueItem.purse))

        try await $items
            .removeAll()
            .insert(BoutiqueItem.belt)
            .run()

        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items.contains(BoutiqueItem.belt))

        try await $items
            .removeAll()
            .remove(BoutiqueItem.belt)
            .insert(BoutiqueItem.belt)
            .run()

        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items.contains(BoutiqueItem.belt))
    }

    @MainActor
    func testChainingOperationsDontExecuteUnlessRun() async throws {
        let operation = try await $items
            .insert(BoutiqueItem.coat)
            .insert([BoutiqueItem.purse, BoutiqueItem.belt])

        XCTAssertEqual(items.count, 0)
        XCTAssertFalse(items.contains(BoutiqueItem.purse))
        XCTAssertFalse(items.contains(BoutiqueItem.belt))
        XCTAssertFalse(items.contains(BoutiqueItem.coat))

        // Adding this line to get rid of the error about
        // `operation` being unused, given that's the point of the test.
        _ = operation
    }

    @MainActor
    func testPublishedItemsSubscription() async throws {
        let uniqueItems = BoutiqueItem.uniqueItems
        let expectation = XCTestExpectation(description: "uniqueItems is published and read")

        $items.$items
            .dropFirst()
            .sink(receiveValue: { items in
                print("🔴", items)
                XCTAssertEqual(items, uniqueItems)
                expectation.fulfill()
            })
            .store(in: &cancellables)

        XCTAssertTrue(items.isEmpty)

        // Sets items under the hood
        try await $items.insert(uniqueItems)
        wait(for: [expectation], timeout: 1)
    }
}
