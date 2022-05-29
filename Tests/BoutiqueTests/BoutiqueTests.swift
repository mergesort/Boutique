import XCTest
@testable import Boutique

final class BoutiqueTests: XCTestCase {

    private var store: Store<BoutiqueItem>!

    override func setUp() async throws {
        store = Store<BoutiqueItem>(storagePath: Self.testStoragePath, cacheIdentifier: \.merchantID)

        // Can't believe this hack is needed but there is an issue in recent Xcode builds
        // where if you access files on disk too soon on launch you'll get a permissions error.
        try await Task.sleep(nanoseconds: 100_000_000)

        try await store.removeAll()
    }

    @MainActor
    func testAddingItem() async throws {
        try await store.add(Self.coat)
        XCTAssert(store.items.contains(Self.coat))
    }

    @MainActor
    func testAddingItems() async throws {
        try await store.add([Self.coat, Self.sweater, Self.sweater, Self.purse])
        XCTAssert(store.items.contains(Self.coat))
        XCTAssert(store.items.contains(Self.sweater))
        XCTAssert(store.items.contains(Self.purse))
    }

    @MainActor
    func testAddingDuplicateItems() async throws {
        XCTAssert(store.items.isEmpty)
        try await store.add(Self.allObjects)
        XCTAssert(store.items.count == 4)
    }

    @MainActor
    func testReadingItems() async throws {
        try await store.add(Self.allObjects)

        XCTAssert(store.items[0] == Self.coat)
        XCTAssert(store.items[1] == Self.sweater)
        XCTAssert(store.items[2] == Self.purse)
        XCTAssert(store.items[3] == Self.belt)

        XCTAssert(store.items.count == 4)
    }

    @MainActor
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

    @MainActor
    func testRemoveAll() async throws {
        try await store.add(Self.coat)
        XCTAssert(store.items.count == 1)
        try await store.removeAll()

        try await store.add(Self.allObjects)
        XCTAssert(store.items.count == 4)
        try await store.removeAll()
        XCTAssert(store.items.isEmpty)
    }

    @MainActor
    func testRemoveNoneCacheInvalidationStrategy() async throws {
        let gloves = BoutiqueItem(merchantID: "999", value: "Gloves")
        try await store.add(gloves)

        try await store.add(BoutiqueTests.allObjects, invalidationStrategy: .removeNone)
        XCTAssert(store.items.contains(gloves))
    }

    @MainActor
    func testRemoveItemsCacheInvalidationStrategy() async throws {
        let gloves = BoutiqueItem(merchantID: "999", value: "Gloves")
        try await store.add(gloves)
        XCTAssert(store.items.contains(gloves))

        let duplicateGloves = BoutiqueItem(merchantID: "1000", value: "Gloves")
        try await store.add(duplicateGloves, invalidationStrategy: .remove(items: [gloves]))

        XCTAssertFalse(store.items.contains(where: { $0.merchantID == "999" }))

        XCTAssert(store.items.contains(where: { $0.merchantID == "1000" }))
    }

    @MainActor
    func testRemoveAllCacheInvalidationStrategy() async throws {
        let gloves = BoutiqueItem(merchantID: "999", value: "Gloves")
        try await store.add(gloves)
        XCTAssert(store.items.contains(gloves))

        try await store.add(BoutiqueTests.allObjects, invalidationStrategy: .removeAll)
        XCTAssertFalse(store.items.contains(gloves))
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

    static let testStoragePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Tests")

}
