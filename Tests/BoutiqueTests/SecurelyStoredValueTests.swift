import Boutique
import Combine
import SwiftUI
import XCTest

final class SecurelyStoredValueTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    @SecurelyStoredValue<String>(key: "securePassword")
    private var storedPassword

    @SecurelyStoredValue<Bool>(key: "secureBool")
    private var storedBool

    @SecurelyStoredValue<BoutiqueItem>(key: "secureValueWithDefault")
    private var storedItem

    @SecurelyStoredValue<[BoutiqueItem]>(key: "secureArray")
    private var storedArray

    @SecurelyStoredValue<[String : BoutiqueItem]>(key: "secureDictionary")
    private var storedDictionary

    @SecurelyStoredValue<BoutiqueItem>(key: "secureBinding")
    private var storedBinding

    @SecurelyStoredValue<String>(key: "Boutique.SecurelyStoredValue.Test")
    private var storedExistingValue

    override func setUp() async throws {
        if self.storedExistingValue == nil {
            try self.$storedExistingValue.set("Existence")
        }
    }

    override func tearDown() async throws {
        try self.$storedPassword.remove()
        try self.$storedBool.remove()
        try self.$storedItem.remove()
        try self.$storedArray.remove()
        try self.$storedDictionary.remove()
        try self.$storedBinding.remove()
    }

    func testExistingValuePersists() {
        // Ensure that values not explicitly removed from the keychain continue to persist across runs
        XCTAssertNotEqual(self.storedExistingValue, nil)
    }

    func testStoredValue() throws {
        XCTAssertEqual(self.storedPassword, nil)

        try self.$storedPassword.set("p@ssw0rd")
        XCTAssertEqual(self.storedPassword, "p@ssw0rd")

        try self.$storedPassword.remove()
        XCTAssertEqual(self.storedPassword, nil)
    }

    func testStoredCustomType() throws {
        XCTAssertEqual(self.storedItem, nil)

        try self.$storedItem.set(.sweater)
        XCTAssertEqual(self.storedItem, .sweater)

        try self.$storedItem.set(.belt)
        XCTAssertEqual(self.storedItem, .belt)

        try self.$storedItem.remove()
        XCTAssertEqual(self.storedItem, nil)
    }

    func testStoredArray() throws {
        // Strings
        XCTAssertEqual(self.storedArray, nil)

        try self.$storedArray.set([.belt, .sweater])
        XCTAssertEqual(self.storedArray, [.belt, .sweater])

        try self.$storedArray.remove()
        XCTAssertEqual(self.storedArray, nil)
    }

    func testStoredBoolean() async throws {
        XCTAssertEqual(self.storedBool, nil)

        try self.$storedBool.set(true)
        XCTAssertEqual(self.storedBool, true)

        try self.$storedBool.set(false)
        XCTAssertEqual(self.storedBool, false)

        try self.$storedBool.toggle()
        XCTAssertEqual(self.storedBool, true)
    }

    func testStoredDictionary() async throws {
        XCTAssertEqual(self.storedDictionary, nil)

        try self.$storedDictionary.update(key: BoutiqueItem.sweater.merchantID, value: BoutiqueItem.sweater)
        XCTAssertEqual(self.storedDictionary, [BoutiqueItem.sweater.merchantID : BoutiqueItem.sweater])

        try self.$storedDictionary.update(key: BoutiqueItem.belt.merchantID, value: nil)
        XCTAssertEqual(self.storedDictionary, [BoutiqueItem.sweater.merchantID : BoutiqueItem.sweater])

        try self.$storedDictionary.update(key: BoutiqueItem.sweater.merchantID, value: nil)
        XCTAssertEqual(self.storedDictionary, [:])
    }

    func testStoredArrayValueAppend() async throws {
        XCTAssertEqual(self.storedArray, nil)

        try self.$storedArray.append(BoutiqueItem.sweater)
        XCTAssertEqual(self.storedArray, [BoutiqueItem.sweater])

        try self.$storedArray.append(BoutiqueItem.belt)
        XCTAssertEqual(self.storedArray, [BoutiqueItem.sweater, BoutiqueItem.belt])
    }

    func testStoredBinding() async throws {
        XCTAssertEqual(self.storedBinding, nil)
        
        // Using wrappedValue for our tests to work around the fact that Binding doesn't conform to Equatable
        XCTAssertEqual(self.$storedBinding.binding.wrappedValue, nil)

        try self.$storedBinding.set(BoutiqueItem.belt)
        XCTAssertEqual(self.$storedBinding.binding.wrappedValue, Binding.constant(BoutiqueItem.belt).wrappedValue)
    }

    func testPublishedValueSubscription() async throws {
        let expectation = XCTestExpectation(description: "@SecurelyStoredValue publishes values correctly")

        var values: [BoutiqueItem] = []

        self.$storedItem.publisher
            .sink(receiveValue: { item in
                if let item {
                    values.append(item)
                }

                if values.count == 4 {
                    XCTAssertEqual(values, [BoutiqueItem.coat, .purse, .sweater, .belt])
                    expectation.fulfill()
                }
            })
            .store(in: &cancellables)

        try self.$storedItem.set(BoutiqueItem.coat)
        try self.$storedItem.set(BoutiqueItem.purse)
        try self.$storedItem.set(BoutiqueItem.sweater)
        try self.$storedItem.set(BoutiqueItem.belt)

        await fulfillment(of: [expectation], timeout: 1)
    }
}
