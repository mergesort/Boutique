import Boutique
import Combine
import SwiftUI
import XCTest

final class StoredValueTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    @StoredValue<BoutiqueItem>(key: "storedItem")
    private var storedItem = BoutiqueItem.coat

    @StoredValue<BoutiqueItem?>(key: "storedNilValue")
    private var storedNilValue = nil

    @StoredValue(key: "storedBoolValue")
    private var storedBoolValue = false

    @StoredValue(key: "storedDictionary")
    private var storedDictionaryValue: [String : BoutiqueItem] = [:]

    @StoredValue(key: "storedArray")
    private var storedArrayValue: [BoutiqueItem] = []

    @StoredValue(key: "storedBinding")
    private var storedBinding = BoutiqueItem.sweater

    @MainActor
    override func setUp() {
        self.$storedItem.reset()
        self.$storedBoolValue.reset()
        self.$storedNilValue.reset()
        self.$storedDictionaryValue.reset()
        self.$storedArrayValue.reset()
        self.$storedBinding.reset()
    }

    func testStoredValueOperations() async throws {
        XCTAssertEqual(self.storedItem, BoutiqueItem.coat)

        await self.$storedItem.set(BoutiqueItem.belt)
        XCTAssertEqual(self.storedItem, BoutiqueItem.belt)

        await self.$storedItem.reset()
        XCTAssertEqual(self.storedItem, BoutiqueItem.coat)

        await self.$storedItem.set(BoutiqueItem.sweater)
        XCTAssertEqual(self.storedItem, BoutiqueItem.sweater)
    }

    @MainActor
    func testStoredValueOnMainActorOperations() async throws {
        XCTAssertEqual(self.storedItem, BoutiqueItem.coat)

        self.$storedItem.set(BoutiqueItem.belt)
        XCTAssertEqual(self.storedItem, BoutiqueItem.belt)

        self.$storedItem.reset()
        XCTAssertEqual(self.storedItem, BoutiqueItem.coat)

        self.$storedItem.set(BoutiqueItem.sweater)
        XCTAssertEqual(self.storedItem, BoutiqueItem.sweater)
    }

    func testStoredNilValue() async throws {
        XCTAssertEqual(self.storedNilValue, nil)

        await self.$storedNilValue.set(BoutiqueItem.belt)
        XCTAssertEqual(self.storedNilValue, BoutiqueItem.belt)

        await self.$storedNilValue.reset()
        XCTAssertEqual(self.storedNilValue, nil)

        await self.$storedNilValue.set(BoutiqueItem.sweater)
        XCTAssertEqual(self.storedNilValue, BoutiqueItem.sweater)
    }

    func testStoredBoolValueToggle() async throws {
        XCTAssertEqual(self.storedBoolValue, false)

        await self.$storedBoolValue.toggle()
        XCTAssertEqual(self.storedBoolValue, true)

        await self.$storedBoolValue.set(false)
        XCTAssertEqual(self.storedBoolValue, false)

        await self.$storedBoolValue.toggle()
        XCTAssertEqual(self.storedBoolValue, true)
    }

    func testStoredDictionaryValueUpdate() async throws {
        XCTAssertEqual(self.storedDictionaryValue, [:])

        await self.$storedDictionaryValue.update(key: BoutiqueItem.sweater.merchantID, value: BoutiqueItem.sweater)
        XCTAssertEqual(self.storedDictionaryValue, [BoutiqueItem.sweater.merchantID : BoutiqueItem.sweater])

        await self.$storedDictionaryValue.update(key: BoutiqueItem.belt.merchantID, value: nil)
        XCTAssertEqual(self.storedDictionaryValue, [BoutiqueItem.sweater.merchantID : BoutiqueItem.sweater])

        await self.$storedDictionaryValue.update(key: BoutiqueItem.sweater.merchantID, value: nil)
        XCTAssertEqual(self.storedDictionaryValue, [:])
    }

    func testStoredArrayValueAppend() async throws {
        XCTAssertEqual(self.storedArrayValue, [])

        await self.$storedArrayValue.append(BoutiqueItem.sweater)
        XCTAssertEqual(self.storedArrayValue, [BoutiqueItem.sweater])

        await self.$storedArrayValue.append(BoutiqueItem.belt)
        XCTAssertEqual(self.storedArrayValue, [BoutiqueItem.sweater, BoutiqueItem.belt])
    }

    @MainActor
    func testStoredBinding() async throws {
        // Using wrappedValue for our tests to work around the fact that Binding doesn't conform to Equatable
        XCTAssertEqual(self.$storedBinding.binding.wrappedValue, Binding.constant(BoutiqueItem.sweater).wrappedValue)

        self.$storedBinding.set(BoutiqueItem.belt)

        XCTAssertEqual(self.$storedBinding.binding.wrappedValue, Binding.constant(BoutiqueItem.belt).wrappedValue)
    }

    func testPublishedValueSubscription() async throws {
        let expectation = XCTestExpectation(description: "@StoredValue publishes values correctly")

        var values: [BoutiqueItem] = []

        self.$storedItem.publisher
            .sink(receiveValue: { item in
                values.append(item)

                if values.count == 4 {
                    XCTAssertEqual(values, [BoutiqueItem.coat, .purse, .sweater, .belt])
                    expectation.fulfill()
                }
            })
            .store(in: &cancellables)

        await self.$storedItem.set(BoutiqueItem.purse)
        await self.$storedItem.set(BoutiqueItem.sweater)
        await self.$storedItem.set(BoutiqueItem.belt)

        await fulfillment(of: [expectation], timeout: 1)
    }
}

