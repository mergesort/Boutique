@testable import Boutique
import Combine
import XCTest

@MainActor
final class BoutiqueTests: XCTestCase {

    private var store: Store<BoutiqueItem>!
    private var cancellables: Set<AnyCancellable> = []

    @MainActor
    override func setUp() async throws {
        store = Store<BoutiqueItem>(storagePath: Self.testStoragePath, cacheIdentifier: \.merchantID)
        try await store.removeAll()
    }

    func testAddingItem() async throws {
        try await store.add(Self.coat)
        XCTAssert(store.items.contains(Self.coat))
    }

    func testAddingItems() async throws {
        try await store.add([Self.coat, Self.sweater, Self.sweater, Self.purse])
        XCTAssert(store.items.contains(Self.coat))
        XCTAssert(store.items.contains(Self.sweater))
        XCTAssert(store.items.contains(Self.purse))
    }

    func testAddingDuplicateItems() async throws {
        XCTAssert(store.items.isEmpty)
        try await store.add(Self.allObjects)
        XCTAssertEqual(store.items.count, 4)
    }

    func testReadingItems() async throws {
        try await store.add(Self.allObjects)

        XCTAssertEqual(store.items, [Self.coat, Self.sweater, Self.purse, Self.belt])
    }

    func testRemovingItems() async throws {
        try await store.add(Self.allObjects)
        try await store.remove(Self.coat)

        XCTAssertFalse(store.items.contains(Self.coat))

        XCTAssert(store.items.contains(Self.sweater))
        XCTAssert(store.items.contains(Self.purse))

        try await store.remove([Self.sweater, Self.purse])
        XCTAssertFalse(store.items.contains(Self.sweater))
        XCTAssertFalse(store.items.contains(Self.purse))
    }

    func testRemoveAll() async throws {
        try await store.add(Self.coat)
        XCTAssertEqual(store.items.count, 1)
        try await store.removeAll()

        try await store.add(Self.uniqueObjects)
        XCTAssertEqual(store.items.count, 4)
        try await store.removeAll()
        XCTAssert(store.items.isEmpty)
    }

    func testRemoveNoneCacheInvalidationStrategy() async throws {
        let gloves = BoutiqueItem(merchantID: "999", value: "Gloves")
        try await store.add(gloves)

        try await store.add(BoutiqueTests.allObjects, invalidationStrategy: .removeNone)
        XCTAssert(store.items.contains(gloves))
    }

    func testRemoveItemsCacheInvalidationStrategy() async throws {
        let gloves = BoutiqueItem(merchantID: "999", value: "Gloves")
        try await store.add(gloves)
        XCTAssert(store.items.contains(gloves))

        let duplicateGloves = BoutiqueItem(merchantID: "1000", value: "Gloves")
        try await store.add(duplicateGloves, invalidationStrategy: .remove(items: [gloves]))

        XCTAssertFalse(store.items.contains(where: { $0.merchantID == "999" }))

        XCTAssert(store.items.contains(where: { $0.merchantID == "1000" }))
    }

    func testRemoveAllCacheInvalidationStrategy() async throws {
        let gloves = BoutiqueItem(merchantID: "999", value: "Gloves")
        try await store.add(gloves)
        XCTAssert(store.items.contains(gloves))

        try await store.add(BoutiqueTests.allObjects, invalidationStrategy: .removeAll)
        XCTAssertFalse(store.items.contains(gloves))
    }

    func testPublishedItemsSubscription() async throws {
        let uniqueObjects = Self.uniqueObjects
        let expectation = XCTestExpectation(description: "uniqueObjects is published and read")

        store.$items
            .dropFirst()
            .sink(receiveValue: { items in
                XCTAssertTrue(items == uniqueObjects)
                expectation.fulfill()
            })
            .store(in: &cancellables)

        XCTAssert(store.items.isEmpty)

        // Sets items under the hood
        try await store.add(uniqueObjects)
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

    static let allObjects = [
        BoutiqueTests.coat,
        BoutiqueTests.sweater,
        BoutiqueTests.purse,
        BoutiqueTests.belt,
        BoutiqueTests.duplicateBelt
    ]

    static let uniqueObjects = [
        BoutiqueTests.coat,
        BoutiqueTests.sweater,
        BoutiqueTests.purse,
        BoutiqueTests.belt,
    ]

    static let testStoragePath = Store<BoutiqueItem>.temporaryDirectory(appendingPath: "Tests")

}
