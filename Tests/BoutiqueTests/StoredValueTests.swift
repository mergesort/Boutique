import Boutique
import SwiftUI
import Testing

@MainActor
@Suite("@StoredValue Tests")
struct StoredValueTests {
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

    init() {
        self.$storedItem.reset()
        self.$storedBoolValue.reset()
        self.$storedNilValue.reset()
        self.$storedDictionaryValue.reset()
        self.$storedArrayValue.reset()
        self.$storedBinding.reset()
    }

    @Test("Test that StoredValue operations work as expected")
    func testStoredValueOperations() async throws {
        #expect(self.storedItem == .coat)

        self.$storedItem.set(.belt)
        #expect(self.storedItem == .belt)

        self.$storedItem.reset()
        #expect(self.storedItem == .coat)

        self.$storedItem.set(.sweater)
        #expect(self.storedItem == .sweater)
    }

    @Test("Test that a StoredValue can be nilled out")
    func testStoredValueNilSupport() async throws {
        #expect(self.storedNilValue == nil)

        self.$storedNilValue.set(.belt)
        #expect(self.storedNilValue == .belt)

        self.$storedNilValue.reset()
        #expect(self.storedNilValue == nil)

        self.$storedNilValue.set(.sweater)
        #expect(self.storedNilValue == .sweater)
    }

    @Test("Test the StoredValue.toggle function")
    func testStoredValueBoolToggle() async throws {
        #expect(self.storedBoolValue == false)

        self.$storedBoolValue.toggle()
        #expect(self.storedBoolValue == true)

        self.$storedBoolValue.set(false)
        #expect(self.storedBoolValue == false)

        self.$storedBoolValue.toggle()
        #expect(self.storedBoolValue == true)
    }

    @Test("Test the StoredValue.update function when StoredValue is a dictionary")
    func testStoredValueDictionaryUpdate() async throws {
        #expect(self.storedDictionaryValue == [:])

        self.$storedDictionaryValue.update(key: BoutiqueItem.sweater.merchantID, value: .sweater)
        #expect(self.storedDictionaryValue == [BoutiqueItem.sweater.merchantID : .sweater])

        self.$storedDictionaryValue.update(key: BoutiqueItem.belt.merchantID, value: nil)
        #expect(self.storedDictionaryValue == [BoutiqueItem.sweater.merchantID : .sweater])

        self.$storedDictionaryValue.update(key: BoutiqueItem.sweater.merchantID, value: nil)
        #expect(self.storedDictionaryValue == [:])
    }

    @Test("Test the StoredValue.append function when StoredValue is an array")
    func testStoredValueArrayAppend() async throws {
        #expect(self.storedArrayValue == [])

        self.$storedArrayValue.append(.sweater)
        #expect(self.storedArrayValue == [.sweater])

        self.$storedArrayValue.append(.belt)
        #expect(self.storedArrayValue == [.sweater, .belt])
    }

    @Test("Test the StoredValue.togglePresence function when StoredValue is an array")
    func testStoredValueArrayTogglePresence() async throws {
        #expect(self.storedArrayValue == [])

        self.$storedArrayValue.togglePresence(.sweater)
        #expect(self.storedArrayValue == [.sweater])

        self.$storedArrayValue.togglePresence(.sweater)
        #expect(self.storedArrayValue == [])

        self.$storedArrayValue.togglePresence(.sweater)
        self.$storedArrayValue.togglePresence(.belt)
        #expect(self.storedArrayValue == [.sweater, .belt])

        self.$storedArrayValue.togglePresence(.belt)
        #expect(self.storedArrayValue == [.sweater])
    }

    @Test("Test StoredValue.binding")
    func testStoredBinding() async throws {
        // Using wrappedValue for our tests to work around the fact that Binding doesn't conform to Equatable
        #expect(self.$storedBinding.binding.wrappedValue == Binding.constant(.sweater).wrappedValue)

        self.$storedBinding.set(.belt)

        #expect(self.$storedBinding.binding.wrappedValue == Binding.constant(.belt).wrappedValue)
    }

    @Test("Test the ability to observe an AsyncStream of StoredValue.values", .timeLimit(.minutes(1)))
    func testStoredValuesAsyncStream() async throws {
        let populateStoredValueTask = Task {
            var values: [BoutiqueItem] = []
            for await value in self.$storedItem.values {
                values.append(value)
                if values.count == 4 {
                    #expect(values == [.coat, .sweater, .purse, .belt])
                    return true
                }
            }

            return false
        }

        Task {
            self.$storedItem.set(.sweater)
            self.$storedItem.set(.purse)
            self.$storedItem.set(.belt)
        }

        let populateStoredValueTaskCompleted = await populateStoredValueTask.value
        try #require(populateStoredValueTaskCompleted)
    }
}
