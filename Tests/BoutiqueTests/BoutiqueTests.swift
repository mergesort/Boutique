@testable import Boutique
import Combine
import XCTest

final class BoutiqueTests: XCTestCase {

    private var store: Store<BoutiqueItem>!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() async throws {
        store = Store<BoutiqueItem>(
            storage: SQLiteStorageEngine(directory: .temporary(appendingPath: "Tests"))!,
            cacheIdentifier: \.merchantID)

        try await store.removeAll()
    }

    @MainActor
    func testAddingItem() async throws {
        try await store.add(Self.coat)
        XCTAssertTrue(store.items.contains(Self.coat))
    }

    @MainActor
    func testAddingItems() async throws {
        try await store.add([Self.coat, Self.sweater, Self.sweater, Self.purse])
        XCTAssertTrue(store.items.contains(Self.coat))
        XCTAssertTrue(store.items.contains(Self.sweater))
        XCTAssertTrue(store.items.contains(Self.purse))
    }

    @MainActor
    func testAddingDuplicateItems() async throws {
        XCTAssertTrue(store.items.isEmpty)
        try await store.add(Self.allItems)
        XCTAssertEqual(store.items.count, 4)
    }

    @MainActor
    func testReadingItems() async throws {
        try await store.add(Self.allItems)

        XCTAssertEqual(store.items[0], Self.coat)
        XCTAssertEqual(store.items[1], Self.sweater)
        XCTAssertEqual(store.items[2], Self.purse)
        XCTAssertEqual(store.items[3], Self.belt)

        XCTAssertEqual(store.items.count, 4)
    }

    @MainActor
    func testRemovingItems() async throws {
        try await store.add(Self.allItems)
        try await store.remove(Self.coat)

        XCTAssertFalse(store.items.contains(Self.coat))

        XCTAssertTrue(store.items.contains(Self.sweater))
        XCTAssertTrue(store.items.contains(Self.purse))

        try await store.remove([Self.sweater, Self.purse])
        XCTAssertFalse(store.items.contains(Self.sweater))
        XCTAssertFalse(store.items.contains(Self.purse))
    }

    @MainActor
    func testRemoveAll() async throws {
        try await store.add(Self.coat)
        XCTAssertEqual(store.items.count, 1)
        try await store.removeAll()

        try await store.add(Self.uniqueItems)
        XCTAssertEqual(store.items.count, 4)
        try await store.removeAll()
        XCTAssertTrue(store.items.isEmpty)
    }

    @MainActor
    func testRemoveNoneCacheInvalidationStrategy() async throws {
        let gloves = BoutiqueItem(merchantID: "999", value: "Gloves")
        try await store.add(gloves)

        try await store.add(BoutiqueTests.allItems, invalidationStrategy: .removeNone)
        XCTAssertTrue(store.items.contains(gloves))
    }

    @MainActor
    func testRemoveItemsCacheInvalidationStrategy() async throws {
        let gloves = BoutiqueItem(merchantID: "999", value: "Gloves")
        try await store.add(gloves)
        XCTAssertTrue(store.items.contains(gloves))

        let duplicateGloves = BoutiqueItem(merchantID: "1000", value: "Gloves")
        try await store.add(duplicateGloves, invalidationStrategy: .remove(items: [gloves]))

        XCTAssertFalse(store.items.contains(where: { $0.merchantID == "999" }))

        XCTAssertTrue(store.items.contains(where: { $0.merchantID == "1000" }))
    }

    @MainActor
    func testRemoveAllCacheInvalidationStrategy() async throws {
        let gloves = BoutiqueItem(merchantID: "999", value: "Gloves")
        try await store.add(gloves)
        XCTAssertTrue(store.items.contains(gloves))

        try await store.add(BoutiqueTests.allItems, invalidationStrategy: .removeAll)
        XCTAssertFalse(store.items.contains(gloves))
    }

    @MainActor
    func testPublishedItemsSubscription() async throws {
        let uniqueItems = Self.uniqueItems
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

private struct BoutiqueItem: Codable, Equatable {
    let merchantID: String
    let value: String
}

private extension BoutiqueTests {

    static let coat = BoutiqueItem(
        merchantID: "1",
        value: "Coat"
    )

    static let sweater = BoutiqueItem(
        merchantID: "2",
        value: "Sweater"
    )

    static let purse = BoutiqueItem(
        merchantID: "3",
        value: "Purse"
    )

    static let belt = BoutiqueItem(
        merchantID: "4",
        value: "Belt"
    )

    static let duplicateBelt = BoutiqueItem(
        merchantID: "4",
        value: "Belt"
    )

    static let allItems = [
        BoutiqueTests.coat,
        BoutiqueTests.sweater,
        BoutiqueTests.purse,
        BoutiqueTests.belt,
        BoutiqueTests.duplicateBelt
    ]

    static let uniqueItems = [
        BoutiqueTests.coat,
        BoutiqueTests.sweater,
        BoutiqueTests.purse,
        BoutiqueTests.belt,
    ]

}
