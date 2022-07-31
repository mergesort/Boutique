import Boutique
import Combine
import XCTest

final class StoredValueTests: XCTestCase {

    private var cancellables: Set<AnyCancellable> = []

    @StoredValue<BoutiqueItem>(key: "storedItem")
    private var storedItem

    @StoredValue<BoutiqueItem>(key: "defaultValueItem")
    private var defaultValueItem = BoutiqueItem.coat

    @StoredValue<BoutiqueItem>(key: "defaultNilValueItem")
    private var defaultNilValueItem = nil

    @StoredValue<BoutiqueItem>(key: "defaultDirectoryItem", directory: .temporary(appendingPath: "Test"))
    private var directoryInitializedItem = BoutiqueItem.sweater

    override func setUp() async throws {
        try await self.$storedItem.reset()
    }

    @MainActor
    func testStoredValueOperations() async throws {
        XCTAssertEqual(self.storedItem, nil)

        try await self.$storedItem.set(BoutiqueItem.belt)
        XCTAssertEqual(self.storedItem, BoutiqueItem.belt)

        try await self.$storedItem.reset()
        XCTAssertEqual(self.storedItem, nil)

        try await self.$storedItem.set(BoutiqueItem.sweater)
        XCTAssertEqual(self.storedItem, BoutiqueItem.sweater)
    }

    @MainActor
    func testDefaultValue() async throws {
        XCTAssertEqual(self.defaultValueItem, BoutiqueItem.coat)
        XCTAssertEqual(self.defaultNilValueItem, nil)
    }

    @MainActor
    func testDirectoryInitializedValue() async throws {
        XCTAssertEqual(self.directoryInitializedItem, BoutiqueItem.sweater)

        try await self.$directoryInitializedItem.set(BoutiqueItem.belt)
        XCTAssertEqual(self.directoryInitializedItem, BoutiqueItem.belt)

        try await self.$directoryInitializedItem.reset()
        XCTAssertEqual(self.defaultNilValueItem, nil)
    }

    @MainActor
    func testPublishedValueSubscription() async throws {
        let expectation = XCTestExpectation(description: "@StoredValue publishes values correctly")

        var values: [BoutiqueItem] = []
        try await self.$storedItem.set(BoutiqueItem.coat)

        self.$storedItem.publisher
            .sink(receiveValue: { item in
                if let item = item {
                    values.append(item)
                }

                if values.count == 4 {
                    XCTAssertEqual(values, [BoutiqueItem.coat, .sweater, .purse, .belt])
                    expectation.fulfill()
                }
            })
            .store(in: &cancellables)

        try await self.$storedItem.set(BoutiqueItem.sweater)
        try await self.$storedItem.set(BoutiqueItem.purse)
        try await self.$storedItem.set(BoutiqueItem.belt)

        wait(for: [expectation], timeout: 1)
    }
}
