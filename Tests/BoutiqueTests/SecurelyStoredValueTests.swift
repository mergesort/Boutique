import Boutique
import SwiftUI
import Testing

@MainActor
@Suite("@SecurelyStoredValue Tests")
struct SecurelyStoredValueTests {
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

    @SecurelyStoredValue<String>(key: "secureGroupString", group: "com.boutique.tests")
    private var storedGroupValue

    init() async throws {
        if self.storedExistingValue == nil {
            try self.$storedExistingValue.set("Existence")
        }

        try self.$storedPassword.remove()
        try self.$storedBool.remove()
        try self.$storedItem.remove()
        try self.$storedArray.remove()
        try self.$storedDictionary.remove()
        try self.$storedBinding.remove()
        try self.$storedGroupValue.remove()
    }

    @Test("Test that the previous SecurelyStoredValue was persisted")
    func testPersistedValueExists() {
        // Ensure that values not explicitly removed from the keychain continue to persist across runs
        #expect(self.storedExistingValue != nil)
    }

    @Test("Test that SecurelyStoredValue operations work as expected")
    func testStoredValueOperations() async throws {
        #expect(self.storedPassword == nil)

        try self.$storedPassword.set("p@ssw0rd")
        #expect(self.storedPassword == "p@ssw0rd")

        try self.$storedPassword.remove()
        #expect(self.storedPassword == nil)
    }

    @Test("Test that SecurelyStoredValue works with custom types")
    func testStoredValueCustomType() async throws {
        #expect(self.storedItem == nil)

        try self.$storedItem.set(.sweater)
        #expect(self.storedItem == .sweater)

        try self.$storedItem.set(.belt)
        #expect(self.storedItem == .belt)

        try self.$storedItem.remove()
        #expect(self.storedItem == nil)
    }

    @Test("Test that SecurelyStoredValue works with array operations")
    func testStoredArrayOperations() async throws {
        #expect(self.storedArray == nil)

        try self.$storedArray.set([.belt, .sweater])
        #expect(self.storedArray == [.belt, .sweater])

        try self.$storedArray.remove()
        #expect(self.storedArray == nil)
    }

    @Test("Test that SecurelyStoredValue works when a group is specified")
    func testStoredGroupValue() async throws {
        #expect(self.storedGroupValue == nil)

        try self.$storedGroupValue.set("p@ssw0rd")
        #expect(self.storedGroupValue == "p@ssw0rd")

        try self.$storedGroupValue.remove()
        #expect(self.storedGroupValue == nil)
    }

    @Test("Test that SecurelyStoredValue works with boolean values")
    func testStoredBooleanValues() async throws {
        #expect(self.storedBool == nil)

        try self.$storedBool.set(true)
        #expect(self.storedBool == true)

        try self.$storedBool.set(false)
        #expect(self.storedBool == false)

        try self.$storedBool.toggle()
        #expect(self.storedBool == true)
    }

    @Test("Test the StoredValue.update function when StoredValue is a dictionary")
    func testStoredValueDictionaryUpdate() async throws {
        #expect(self.storedDictionary == nil)

        try self.$storedDictionary.update(key: BoutiqueItem.sweater.merchantID, value: .sweater)
        #expect(self.storedDictionary == [BoutiqueItem.sweater.merchantID : .sweater])

        try self.$storedDictionary.update(key: BoutiqueItem.belt.merchantID, value: nil)
        #expect(self.storedDictionary == [BoutiqueItem.sweater.merchantID : .sweater])

        try self.$storedDictionary.update(key: BoutiqueItem.sweater.merchantID, value: nil)
        #expect(self.storedDictionary == [:])
    }

    @Test("Test the StoredValue.append function when StoredValue is an array")
    func testStoredValueArrayAppend() async throws {
        #expect(self.storedArray == nil)

        try self.$storedArray.append(.sweater)
        #expect(self.storedArray == [.sweater])

        try self.$storedArray.append(.belt)
        #expect(self.storedArray == [.sweater, .belt])
    }

    @Test("Test StoredValue.binding")
    func testStoredBinding() async throws {
        #expect(self.storedBinding == nil)

        // Using wrappedValue for our tests to work around the fact that Binding doesn't conform to Equatable
        #expect(self.$storedBinding.binding.wrappedValue == nil)

        try self.$storedBinding.set(.belt)
        #expect(self.$storedBinding.binding.wrappedValue == Binding.constant(.belt).wrappedValue)
    }

    @Test("Test the ability to observe an AsyncStream of StoredValue.values", .timeLimit(.minutes(1)))
    func testStoredValuesAsyncStream() async throws {
        let populateValuesTask = Task {
            var values: [BoutiqueItem?] = []
            for await value in self.$storedItem.values {
                values.append(value)
                print(values)
                if values.count == 4 {
                    #expect(values == [nil, .sweater, .purse, .belt])
                    return true
                }
            }

            return false
        }

        Task {
            try self.$storedItem.set(.sweater)
            try self.$storedItem.set(.purse)
            try self.$storedItem.set(.belt)
        }

        let populateValuesTaskCompleted = await populateValuesTask.value
        try #require(populateValuesTaskCompleted)
    }

}
