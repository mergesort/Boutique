import Boutique
import Combine
import SwiftUI
import XCTest

final class StoredValueTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    @StoredValue<BoutiqueItem>(key: "storedItem")
    private var storedItem = .coat

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

    override func setUp() {
        self.$storedItem.reset()
        self.$storedBoolValue.reset()
        self.$storedNilValue.reset()
        self.$storedDictionaryValue.reset()
        self.$storedArrayValue.reset()
        self.$storedBinding.reset()
    }

    func testStoredValueOperations() async throws {
        XCTAssertEqual(self.storedItem, .coat)

        self.$storedItem.set(.belt)
        XCTAssertEqual(self.storedItem, .belt)

        self.$storedItem.reset()
        XCTAssertEqual(self.storedItem, .coat)

        self.$storedItem.set(.sweater)
        XCTAssertEqual(self.storedItem, .sweater)
    }

    @MainActor
    func testStoredValueOnMainActorOperations() async throws {
        XCTAssertEqual(self.storedItem, .coat)

        self.$storedItem.set(.belt)
        XCTAssertEqual(self.storedItem, .belt)

        self.$storedItem.reset()
        XCTAssertEqual(self.storedItem, .coat)

        self.$storedItem.set(.sweater)
        XCTAssertEqual(self.storedItem, .sweater)
    }

    func testStoredNilValue() async throws {
        XCTAssertEqual(self.storedNilValue, nil)

        self.$storedNilValue.set(.belt)
        XCTAssertEqual(self.storedNilValue, .belt)

        self.$storedNilValue.reset()
        XCTAssertEqual(self.storedNilValue, nil)

        self.$storedNilValue.set(.sweater)
        XCTAssertEqual(self.storedNilValue, .sweater)
    }

    func testStoredBoolValueToggle() async throws {
        XCTAssertEqual(self.storedBoolValue, false)

        self.$storedBoolValue.toggle()
        XCTAssertEqual(self.storedBoolValue, true)

        self.$storedBoolValue.set(false)
        XCTAssertEqual(self.storedBoolValue, false)

        self.$storedBoolValue.toggle()
        XCTAssertEqual(self.storedBoolValue, true)
    }

    func testStoredDictionaryValueUpdate() async throws {
        XCTAssertEqual(self.storedDictionaryValue, [:])

        self.$storedDictionaryValue.update(key: BoutiqueItem.sweater.merchantID, value: .sweater)
        XCTAssertEqual(self.storedDictionaryValue, [BoutiqueItem.sweater.merchantID : .sweater])

        self.$storedDictionaryValue.update(key: BoutiqueItem.belt.merchantID, value: nil)
        XCTAssertEqual(self.storedDictionaryValue, [BoutiqueItem.sweater.merchantID : .sweater])

        self.$storedDictionaryValue.update(key: BoutiqueItem.sweater.merchantID, value: nil)
        XCTAssertEqual(self.storedDictionaryValue, [:])
    }

    func testStoredArrayValueAppend() async throws {
        XCTAssertEqual(self.storedArrayValue, [])

        self.$storedArrayValue.append(.sweater)
        XCTAssertEqual(self.storedArrayValue, [.sweater])

        self.$storedArrayValue.append(.belt)
        XCTAssertEqual(self.storedArrayValue, [.sweater, .belt])
    }

    func testStoredArrayValueTogglePresence() async throws {
        XCTAssertEqual(self.storedArrayValue, [])

        self.$storedArrayValue.togglePresence(.sweater)
        XCTAssertEqual(self.storedArrayValue, [.sweater])

        self.$storedArrayValue.togglePresence(.sweater)
        XCTAssertEqual(self.storedArrayValue, [])

        self.$storedArrayValue.togglePresence(.sweater)
        self.$storedArrayValue.togglePresence(.belt)
        XCTAssertEqual(self.storedArrayValue, [.sweater, .belt])

        self.$storedArrayValue.togglePresence(.belt)
        XCTAssertEqual(self.storedArrayValue, [.sweater])
    }

    func testStoredBinding() async throws {
        // Using wrappedValue for our tests to work around the fact that Binding doesn't conform to Equatable
        XCTAssertEqual(self.$storedBinding.binding.wrappedValue, Binding.constant(.sweater).wrappedValue)

        self.$storedBinding.set(.belt)

        XCTAssertEqual(self.$storedBinding.binding.wrappedValue, Binding.constant(.belt).wrappedValue)
    }

    func testStoredValueAsyncStream() async throws {
        var values: [BoutiqueItem] = []

        let expectation = expectation(description: "Received all values")

        let task = Task {
            for await value in self.$storedItem.values {
                values.append(value)
                if values.count == 4 {
                    expectation.fulfill()
                    break
                }
            }
        }

        // Ensure we get the initial value
        try await Task.sleep(for: .seconds(0.1))

        self.$storedItem.set(.sweater)
        self.$storedItem.set(.purse)
        self.$storedItem.set(.belt)

        await fulfillment(of: [expectation], timeout: 1.0)

        task.cancel()

        XCTAssertEqual(values, [.coat, .sweater, .purse, .belt])
    }
}
