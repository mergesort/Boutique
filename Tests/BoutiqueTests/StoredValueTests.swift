import Boutique
import Combine
import XCTest

final class StoredValueTests: XCTestCase {

    private var cancellables: Set<AnyCancellable> = []

    @StoredValue<BoutiqueItem>(key: "storedItem")
    private var storedItem = BoutiqueItem.coat

    @StoredValue<BoutiqueItem?>(key: "nilStoredValue")
    private var nilStoredValue = nil

    @StoredValue(key: "boolStoredValue")
    private var boolStoredValue = false

    @StoredValue<BoutiqueItem>(key: "defaultDirectoryItem", directory: .temporary(appendingPath: "Test"))
    private var directoryInitializedItem = BoutiqueItem.sweater

    @StoredValue<BoutiqueItem>(storage: SQLiteStorageEngine.default(appendingPath: "storageEngineBackedStoredValue"))
    private var storageEngineBackedStoredValue = BoutiqueItem.sweater

    override func setUp() async throws {
        try await self.$storedItem.reset()
        try await self.$nilStoredValue.reset()
        try await self.$boolStoredValue.reset()
        try await self.$directoryInitializedItem.reset()
        try await self.$storageEngineBackedStoredValue.reset()
    }

    func testStoredValueOperations() async throws {
        XCTAssertEqual(self.storedItem, BoutiqueItem.coat)

        try await self.$storedItem.set(BoutiqueItem.belt)
        XCTAssertEqual(self.storedItem, BoutiqueItem.belt)

        try await self.$storedItem.reset()
        XCTAssertEqual(self.storedItem, BoutiqueItem.coat)

        try await self.$storedItem.set(BoutiqueItem.sweater)
        XCTAssertEqual(self.storedItem, BoutiqueItem.sweater)
    }

    func testStorageEngineBackedStoredValue() async throws {
        XCTAssertEqual(self.storageEngineBackedStoredValue, BoutiqueItem.sweater)

        try await self.$storageEngineBackedStoredValue.set(BoutiqueItem.belt)
        XCTAssertEqual(self.storageEngineBackedStoredValue, BoutiqueItem.belt)

        try await self.$storageEngineBackedStoredValue.reset()
        XCTAssertEqual(self.storageEngineBackedStoredValue, BoutiqueItem.sweater)
    }

    func testNilStoredValue() async throws {
        XCTAssertEqual(self.nilStoredValue, nil)

        try await self.$nilStoredValue.set(BoutiqueItem.belt)
        XCTAssertEqual(self.nilStoredValue, BoutiqueItem.belt)

        try await self.$nilStoredValue.reset()
        XCTAssertEqual(self.nilStoredValue, nil)

        try await self.$nilStoredValue.set(BoutiqueItem.sweater)
        XCTAssertEqual(self.nilStoredValue, BoutiqueItem.sweater)
    }

    func testDirectoryInitializedValue() async throws {
        XCTAssertEqual(self.directoryInitializedItem, BoutiqueItem.sweater)

        try await self.$directoryInitializedItem.set(BoutiqueItem.belt)
        XCTAssertEqual(self.directoryInitializedItem, BoutiqueItem.belt)

        try await self.$directoryInitializedItem.reset()
        XCTAssertEqual(self.directoryInitializedItem, BoutiqueItem.sweater)
    }

    func testBoolStoredValueToggle() async throws {
        XCTAssertEqual(self.boolStoredValue, false)

        try await self.$boolStoredValue.toggle()
        XCTAssertEqual(self.boolStoredValue, true)

        try await self.$boolStoredValue.set(false)
        XCTAssertEqual(self.boolStoredValue, false)

        try await self.$boolStoredValue.toggle()
        XCTAssertEqual(self.boolStoredValue, true)
    }

    func testPublishedValueSubscription() async throws {
        let expectation = XCTestExpectation(description: "@StoredValue publishes values correctly")

        var values: [BoutiqueItem] = []

        self.$storedItem.publisher
            .sink(receiveValue: { item in
                values.append(item)

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
