import Boutique
import Combine
import SwiftUI
import XCTest

final class AsyncStoredValueTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    @AsyncStoredValue<BoutiqueItem>(storage: SQLiteStorageEngine.default(appendingPath: "storedItem"))
    private var storedItem = BoutiqueItem.coat

    @AsyncStoredValue(storage: SQLiteStorageEngine.default(appendingPath: "storedBool"))
    private var storedBoolValue = false

    @AsyncStoredValue(storage: SQLiteStorageEngine.default(appendingPath: "storedDictionary"))
    private var storedDictionaryValue: [String : String] = [:]

    @AsyncStoredValue(storage: SQLiteStorageEngine.default(appendingPath: "storedArray"))
    private var storedArrayValue: [BoutiqueItem] = []

    @AsyncStoredValue(storage: SQLiteStorageEngine.default(appendingPath: "storedBinding"))
    private var storedBinding = BoutiqueItem.sweater

    override func setUp() async throws {
        try await self.$storedItem.reset()
        try await self.$storedBoolValue.reset()
        try await self.$storedDictionaryValue.reset()
        try await self.$storedArrayValue.reset()
        try await self.$storedBinding.reset()
    }

    func testStorageEngineBackedStoredValue() async throws {
        XCTAssertEqual(self.storedItem, .coat)

        try await self.$storedItem.set(.belt)
        XCTAssertEqual(self.storedItem, .belt)

        try await self.$storedItem.reset()
        XCTAssertEqual(self.storedItem, .coat)
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

    func testStoredDictionaryValueUpdate() async throws {
        XCTAssertEqual(self.storedDictionaryValue, [:])

        try await self.$storedDictionaryValue.update(key: BoutiqueItem.sweater.merchantID, value: BoutiqueItem.sweater.value)
        XCTAssertEqual(self.storedDictionaryValue, [BoutiqueItem.sweater.merchantID : BoutiqueItem.sweater.value])

        try await self.$storedDictionaryValue.update(key: BoutiqueItem.belt.merchantID, value: nil)
        XCTAssertEqual(self.storedDictionaryValue, [BoutiqueItem.sweater.merchantID : BoutiqueItem.sweater.value])

        try await self.$storedDictionaryValue.update(key: BoutiqueItem.sweater.merchantID, value: nil)
        XCTAssertEqual(self.storedDictionaryValue, [:])
    }

    func testStoredArrayValueAppend() async throws {
        XCTAssertEqual(self.storedArrayValue, [])

        try await self.$storedArrayValue.append(.sweater)
        XCTAssertEqual(self.storedArrayValue, [.sweater])

        try await self.$storedArrayValue.append(.belt)
        XCTAssertEqual(self.storedArrayValue, [.sweater, .belt])
    }

    func testStoredArrayValueTogglePresence() async throws {
        XCTAssertEqual(self.storedArrayValue, [])

        try await self.$storedArrayValue.togglePresence(.sweater)
        XCTAssertEqual(self.storedArrayValue, [.sweater])

        try await self.$storedArrayValue.togglePresence(.sweater)
        XCTAssertEqual(self.storedArrayValue, [])

        try await self.$storedArrayValue.togglePresence(.sweater)
        try await self.$storedArrayValue.togglePresence(.belt)
        XCTAssertEqual(self.storedArrayValue, [.sweater, .belt])

        try await self.$storedArrayValue.togglePresence(.belt)
        XCTAssertEqual(self.storedArrayValue, [.sweater])
    }

    func testStoredBinding() async throws {
        XCTAssertEqual(self.$storedBinding.binding.wrappedValue, Binding.constant(.sweater).wrappedValue)

        try await self.$storedBinding.set(.belt)
        XCTAssertEqual(self.$storedBinding.binding.wrappedValue, Binding.constant(.belt).wrappedValue)
    }

    func testStoredValuePublishedSubscription() async throws {
        let expectation = XCTestExpectation(description: "@AsyncStoredValue publishes values correctly")

        var values: [BoutiqueItem] = []

        self.$storedItem.publisher
            .sink(receiveValue: { item in
                values.append(item)

                if values.count == 4 {
                    XCTAssertEqual(values, [.coat, .sweater, .purse, .belt])
                    expectation.fulfill()
                }
            })
            .store(in: &cancellables)

        try await self.$storedItem.set(.sweater)
        try await self.$storedItem.set(.purse)
        try await self.$storedItem.set(.belt)

        wait(for: [expectation], timeout: 1)
    }
}
