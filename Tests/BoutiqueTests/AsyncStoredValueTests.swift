import Boutique
import Combine
import XCTest

final class AsyncStoredValueTests: XCTestCase {

    private var cancellables: Set<AnyCancellable> = []

    @AsyncStoredValue<BoutiqueItem>(storage: SQLiteStorageEngine.default(appendingPath: "storedItem"))
    private var storedItem = BoutiqueItem.coat

    @AsyncStoredValue(storage: SQLiteStorageEngine.default(appendingPath: "storedBool"))
    private var storedBoolValue = false

    override func setUp() async throws {
        try await self.$storedBoolValue.reset()
        try await self.$storedItem.reset()
    }

    func testStorageEngineBackedStoredValue() async throws {
        XCTAssertEqual(self.storedItem, BoutiqueItem.coat)

        try await self.$storedItem.set(BoutiqueItem.belt)
        XCTAssertEqual(self.storedItem, BoutiqueItem.belt)

        try await self.$storedItem.reset()
        XCTAssertEqual(self.storedItem, BoutiqueItem.coat)
    }

    func testBoolAsyncStoredValue() async throws {
        XCTAssertEqual(self.storedBoolValue, false)

        try await self.$storedBoolValue.toggle()
        XCTAssertEqual(self.storedBoolValue, true)

        try await self.$storedBoolValue.set(false)
        XCTAssertEqual(self.storedBoolValue, false)

        try await self.$storedBoolValue.toggle()
        XCTAssertEqual(self.storedBoolValue, true)
    }

    func testStoredBoolValueToggle() async throws {
        XCTAssertEqual(self.storedBoolValue, false)

        try await self.$storedBoolValue.toggle()
        XCTAssertEqual(self.storedBoolValue, true)

        try await self.$storedBoolValue.set(false)
        XCTAssertEqual(self.storedBoolValue, false)

        try await self.$storedBoolValue.toggle()
        XCTAssertEqual(self.storedBoolValue, true)
    }

    func testStoredValuePublishedSubscription() async throws {
        let expectation = XCTestExpectation(description: "@AsyncStoredValue publishes values correctly")

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
