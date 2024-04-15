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
        try await asyncStore.insert(.coat)
        XCTAssertTrue(asyncStore.items.contains(.coat))
        
        try await asyncStore.insert(.belt)
        XCTAssertTrue(asyncStore.items.contains(.belt))
        XCTAssertEqual(asyncStore.items.count, 2)
    }
    
    @MainActor
    func testInsertingItems() async throws {
        try await asyncStore.insert([.coat, .sweater, .sweater, .purse])
        XCTAssertTrue(asyncStore.items.contains(.coat))
        XCTAssertTrue(asyncStore.items.contains(.sweater))
        XCTAssertTrue(asyncStore.items.contains(.purse))
    }
    
    @MainActor
    func testInsertingDuplicateItems() async throws {
        XCTAssertTrue(asyncStore.items.isEmpty)
        try await asyncStore.insert(.allItems)
        XCTAssertEqual(asyncStore.items.count, 4)
    }
    
    @MainActor
    func testReadingItems() async throws {
        try await asyncStore.insert(.allItems)
        
        XCTAssertEqual(asyncStore.items[0], .coat)
        XCTAssertEqual(asyncStore.items[1], .sweater)
        XCTAssertEqual(asyncStore.items[2], .purse)
        XCTAssertEqual(asyncStore.items[3], .belt)
        
        XCTAssertEqual(asyncStore.items.count, 4)
    }
    
    @MainActor
    func testReadingPersistedItems() async throws {
        try await asyncStore.insert(.allItems)
        
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
        try await asyncStore.insert(.allItems)
        try await asyncStore.remove(.coat)
        
        XCTAssertFalse(asyncStore.items.contains(.coat))
        
        XCTAssertTrue(asyncStore.items.contains(.sweater))
        XCTAssertTrue(asyncStore.items.contains(.purse))
        
        try await asyncStore.remove([.sweater, .purse])
        XCTAssertFalse(asyncStore.items.contains(.sweater))
        XCTAssertFalse(asyncStore.items.contains(.purse))
    }
    
    @MainActor
    func testRemoveAll() async throws {
        try await asyncStore.insert(.coat)
        XCTAssertEqual(asyncStore.items.count, 1)
        try await asyncStore.removeAll()
        
        try await asyncStore.insert(.uniqueItems)
        XCTAssertEqual(asyncStore.items.count, 4)
        try await asyncStore.removeAll()
        XCTAssertTrue(asyncStore.items.isEmpty)
    }
    
    @MainActor
    func testChainingInsertOperations() async throws {
        try await asyncStore.insert(.uniqueItems)
        
        try await asyncStore
            .remove(.coat)
            .insert(.belt)
            .insert(.belt)
            .run()
        
        XCTAssertEqual(asyncStore.items.count, 3)
        XCTAssertTrue(asyncStore.items.contains(.sweater))
        XCTAssertTrue(asyncStore.items.contains(.purse))
        XCTAssertTrue(asyncStore.items.contains(.belt))
        XCTAssertFalse(asyncStore.items.contains(.coat))
        
        try await asyncStore.removeAll()
        
        try await asyncStore
            .insert(.belt)
            .insert(.coat)
            .remove([.belt])
            .insert(.sweater)
            .run()
        
        XCTAssertEqual(asyncStore.items.count, 2)
        XCTAssertTrue(asyncStore.items.contains(.coat))
        XCTAssertTrue(asyncStore.items.contains(.sweater))
        XCTAssertFalse(asyncStore.items.contains(.belt))
        
        try await asyncStore
            .insert(.belt)
            .insert(.coat)
            .insert(.purse)
            .remove([.belt, .coat])
            .insert(.sweater)
            .run()
        
        XCTAssertEqual(asyncStore.items.count, 2)
        XCTAssertTrue(asyncStore.items.contains(.sweater))
        XCTAssertTrue(asyncStore.items.contains(.purse))
        XCTAssertFalse(asyncStore.items.contains(.coat))
        XCTAssertFalse(asyncStore.items.contains(.belt))
        
        try await asyncStore.removeAll()
        
        try await asyncStore
            .insert(.coat)
            .insert([.purse, .belt])
            .run()
        
        XCTAssertEqual(asyncStore.items.count, 3)
        XCTAssertTrue(asyncStore.items.contains(.purse))
        XCTAssertTrue(asyncStore.items.contains(.belt))
        XCTAssertTrue(asyncStore.items.contains(.coat))
    }
    
    @MainActor
    func testChainingRemoveOperations() async throws {
        try await asyncStore
            .insert(.uniqueItems)
            .remove(.belt)
            .remove(.purse)
            .run()
        
        XCTAssertEqual(asyncStore.items.count, 2)
        XCTAssertTrue(asyncStore.items.contains(.sweater))
        XCTAssertTrue(asyncStore.items.contains(.coat))
        
        try await asyncStore.insert(.uniqueItems)
        XCTAssertEqual(asyncStore.items.count, 4)
        
        try await asyncStore
            .remove([.sweater, .coat])
            .remove(.belt)
            .run()
        
        XCTAssertEqual(asyncStore.items.count, 1)
        XCTAssertTrue(asyncStore.items.contains(.purse))
        
        try await asyncStore
            .removeAll()
            .insert(.belt)
            .run()
        
        XCTAssertEqual(asyncStore.items.count, 1)
        XCTAssertTrue(asyncStore.items.contains(.belt))
        
        try await asyncStore
            .removeAll()
            .remove(.belt)
            .insert(.belt)
            .run()
        
        XCTAssertEqual(asyncStore.items.count, 1)
        XCTAssertTrue(asyncStore.items.contains(.belt))
    }
    
    @MainActor
    func testChainingOperationsDontExecuteUnlessRun() async throws {
        let operation = try await asyncStore
            .insert(.coat)
            .insert([.purse, .belt])
        
        XCTAssertEqual(asyncStore.items.count, 0)
        XCTAssertFalse(asyncStore.items.contains(.purse))
        XCTAssertFalse(asyncStore.items.contains(.belt))
        XCTAssertFalse(asyncStore.items.contains(.coat))
        
        // Adding this line to get rid of the error about
        // `operation` being unused, given that's the point of the test.
        _ = operation
    }
    
    @MainActor
    func testPublishedItemsSubscription() async throws {
        let uniqueItems: [BoutiqueItem] = .uniqueItems
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
