@testable import Boutique
import Combine
import XCTest

final class AsyncStoreTests: XCTestCase {
    
    private var asyncStore: Store<BoutiqueItem>!
    private var cancellables: Set<AnyCancellable> = []
    
    override func setUp() async throws {
        asyncStore = try await Store<BoutiqueItem>(
            storage: SQLiteStorageEngine.default(appendingPath: "Tests"),
            cacheIdentifier: \.merchantID)
        try await asyncStore.removeAll()
    }
    
    override func tearDown() {
        cancellables.removeAll()
    }
    
    @MainActor
    func testInsertingItem() async throws {
        try await asyncStore.insert(BoutiqueItem.coat)
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.coat))
        
        try await asyncStore.insert(BoutiqueItem.belt)
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.belt))
        XCTAssertEqual(asyncStore.items.count, 2)
    }
    
    @MainActor
    func testInsertingItems() async throws {
        try await asyncStore.insert([BoutiqueItem.coat, BoutiqueItem.sweater, BoutiqueItem.sweater, BoutiqueItem.purse])
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.coat))
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.sweater))
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.purse))
    }
    
    @MainActor
    func testInsertingDuplicateItems() async throws {
        XCTAssertTrue(asyncStore.items.isEmpty)
        try await asyncStore.insert(BoutiqueItem.allItems)
        XCTAssertEqual(asyncStore.items.count, 4)
    }
    
    @MainActor
    func testReadingItems() async throws {
        try await asyncStore.insert(BoutiqueItem.allItems)
        
        XCTAssertEqual(asyncStore.items[0], BoutiqueItem.coat)
        XCTAssertEqual(asyncStore.items[1], BoutiqueItem.sweater)
        XCTAssertEqual(asyncStore.items[2], BoutiqueItem.purse)
        XCTAssertEqual(asyncStore.items[3], BoutiqueItem.belt)
        
        XCTAssertEqual(asyncStore.items.count, 4)
    }
    
    @MainActor
    func testReadingPersistedItems() async throws {
        try await asyncStore.insert(BoutiqueItem.allItems)
        
        // The new store has to fetch items from disk.
        let newStore = try await Store<BoutiqueItem>(
            storage: SQLiteStorageEngine.default(appendingPath: "Tests"),
            cacheIdentifier: \.merchantID)
        
        XCTAssertEqual(newStore.items[0], BoutiqueItem.coat)
        XCTAssertEqual(newStore.items[1], BoutiqueItem.sweater)
        XCTAssertEqual(newStore.items[2], BoutiqueItem.purse)
        XCTAssertEqual(newStore.items[3], BoutiqueItem.belt)
        
        XCTAssertEqual(newStore.items.count, 4)
    }
    
    @MainActor
    func testRemovingItems() async throws {
        try await asyncStore.insert(BoutiqueItem.allItems)
        try await asyncStore.remove(BoutiqueItem.coat)
        
        XCTAssertFalse(asyncStore.items.contains(BoutiqueItem.coat))
        
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.sweater))
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.purse))
        
        try await asyncStore.remove([BoutiqueItem.sweater, BoutiqueItem.purse])
        XCTAssertFalse(asyncStore.items.contains(BoutiqueItem.sweater))
        XCTAssertFalse(asyncStore.items.contains(BoutiqueItem.purse))
    }
    
    @MainActor
    func testRemoveAll() async throws {
        try await asyncStore.insert(BoutiqueItem.coat)
        XCTAssertEqual(asyncStore.items.count, 1)
        try await asyncStore.removeAll()
        
        try await asyncStore.insert(BoutiqueItem.uniqueItems)
        XCTAssertEqual(asyncStore.items.count, 4)
        try await asyncStore.removeAll()
        XCTAssertTrue(asyncStore.items.isEmpty)
    }
    
    @MainActor
    func testChainingInsertOperations() async throws {
        try await asyncStore.insert(BoutiqueItem.uniqueItems)
        
        try await asyncStore
            .remove(BoutiqueItem.coat)
            .insert(BoutiqueItem.belt)
            .insert(BoutiqueItem.belt)
            .run()
        
        XCTAssertEqual(asyncStore.items.count, 3)
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.sweater))
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.purse))
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.belt))
        XCTAssertFalse(asyncStore.items.contains(BoutiqueItem.coat))
        
        try await asyncStore.removeAll()
        
        try await asyncStore
            .insert(BoutiqueItem.belt)
            .insert(BoutiqueItem.coat)
            .remove([BoutiqueItem.belt])
            .insert(BoutiqueItem.sweater)
            .run()
        
        XCTAssertEqual(asyncStore.items.count, 2)
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.coat))
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.sweater))
        XCTAssertFalse(asyncStore.items.contains(BoutiqueItem.belt))
        
        try await asyncStore
            .insert(BoutiqueItem.belt)
            .insert(BoutiqueItem.coat)
            .insert(BoutiqueItem.purse)
            .remove([BoutiqueItem.belt, .coat])
            .insert(BoutiqueItem.sweater)
            .run()
        
        XCTAssertEqual(asyncStore.items.count, 2)
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.sweater))
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.purse))
        XCTAssertFalse(asyncStore.items.contains(BoutiqueItem.coat))
        XCTAssertFalse(asyncStore.items.contains(BoutiqueItem.belt))
        
        try await asyncStore.removeAll()
        
        try await asyncStore
            .insert(BoutiqueItem.coat)
            .insert([BoutiqueItem.purse, BoutiqueItem.belt])
            .run()
        
        XCTAssertEqual(asyncStore.items.count, 3)
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.purse))
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.belt))
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.coat))
    }
    
    @MainActor
    func testChainingRemoveOperations() async throws {
        try await asyncStore
            .insert(BoutiqueItem.uniqueItems)
            .remove(BoutiqueItem.belt)
            .remove(BoutiqueItem.purse)
            .run()
        
        XCTAssertEqual(asyncStore.items.count, 2)
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.sweater))
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.coat))
        
        try await asyncStore.insert(BoutiqueItem.uniqueItems)
        XCTAssertEqual(asyncStore.items.count, 4)
        
        try await asyncStore
            .remove([BoutiqueItem.sweater, BoutiqueItem.coat])
            .remove(BoutiqueItem.belt)
            .run()
        
        XCTAssertEqual(asyncStore.items.count, 1)
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.purse))
        
        try await asyncStore
            .removeAll()
            .insert(BoutiqueItem.belt)
            .run()
        
        XCTAssertEqual(asyncStore.items.count, 1)
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.belt))
        
        try await asyncStore
            .removeAll()
            .remove(BoutiqueItem.belt)
            .insert(BoutiqueItem.belt)
            .run()
        
        XCTAssertEqual(asyncStore.items.count, 1)
        XCTAssertTrue(asyncStore.items.contains(BoutiqueItem.belt))
    }
    
    @MainActor
    func testChainingOperationsDontExecuteUnlessRun() async throws {
        let operation = try await asyncStore
            .insert(BoutiqueItem.coat)
            .insert([BoutiqueItem.purse, BoutiqueItem.belt])
        
        XCTAssertEqual(asyncStore.items.count, 0)
        XCTAssertFalse(asyncStore.items.contains(BoutiqueItem.purse))
        XCTAssertFalse(asyncStore.items.contains(BoutiqueItem.belt))
        XCTAssertFalse(asyncStore.items.contains(BoutiqueItem.coat))
        
        // Adding this line to get rid of the error about
        // `operation` being unused, given that's the point of the test.
        _ = operation
    }
    
    @MainActor
    func testPublishedItemsSubscription() async throws {
        let uniqueItems = BoutiqueItem.uniqueItems
        let expectation = XCTestExpectation(description: "uniqueItems is published and read")
        
        asyncStore.$items
            .dropFirst()
            .sink(receiveValue: { items in
                XCTAssertEqual(items, uniqueItems)
                expectation.fulfill()
            })
            .store(in: &cancellables)
        
        XCTAssertTrue(asyncStore.items.isEmpty)
        
        // Sets items under the hood
        try await asyncStore.insert(uniqueItems)
        wait(for: [expectation], timeout: 1)
    }
    
}
