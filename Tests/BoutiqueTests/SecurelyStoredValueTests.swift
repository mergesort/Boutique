@testable import Boutique
import Foundation
import Observation
import SwiftUI
import Testing

@MainActor
@Suite("@SecurelyStoredValue Tests")
struct SecurelyStoredValueTests {
    @SecurelyStoredValue<String>(key: "securePassword", service: .test)
    private var storedPassword

    @SecurelyStoredValue<Bool>(key: "secureBool", service: .test)
    private var storedBool

    @SecurelyStoredValue<BoutiqueItem>(key: "secureValueWithDefault", service: .test)
    private var storedItem

    @SecurelyStoredValue<[BoutiqueItem]>(key: "secureArray", service: .test)
    private var storedArray

    @SecurelyStoredValue<[String : BoutiqueItem]>(key: "secureDictionary", service: .test)
    private var storedDictionary

    @SecurelyStoredValue<BoutiqueItem>(key: "secureBinding", service: .test)
    private var storedBinding

    @SecurelyStoredValue<String>(key: "Boutique.SecurelyStoredValue.Test", service: .test)
    private var storedExistingValue

    @SecurelyStoredValue<String>(key: "secureGroupString", service: .test, group: "com.boutique.tests")
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
        let populateStoredValueTask = Task {
            var values: [BoutiqueItem?] = []
            for await value in self.$storedItem.values {
                values.append(value)

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

        let populateStoredValueTaskCompleted = await populateStoredValueTask.value
        try #require(populateStoredValueTaskCompleted)
    }

    @Test("Test that wrappers using the same key read the latest value")
    func testStoredValuesUsingSameKeyRemainSynchronized() throws {
        let key = "secureSynchronization.\(UUID().uuidString)"
        let writer = SecurelyStoredValue<String>(key: key, service: .test)
        let reader = SecurelyStoredValue<String>(key: key, service: .test)

        defer {
            try? writer.remove()
        }

        try writer.set("Persisted Value")
        #expect(reader.wrappedValue == "Persisted Value")

        try writer.remove()
        #expect(reader.wrappedValue == nil)
    }

    @Test("Test that read failures return the last successful value")
    func testStoredValueReadFailureReturnsLastSuccessfulValue() throws {
        let storedValue = SecurelyStoredValue<String>(key: "secureReadFailure.\(UUID().uuidString)", service: .test)

        defer {
            try? storedValue.remove()
        }

        try storedValue.set("Cached Value")

        let retrievedValue = storedValue.refreshValue(from: {
            throw ReadError()
        })

        #expect(retrievedValue == "Cached Value")
    }

    @Test("Test that a missing Keychain item clears the current value")
    func testMissingStoredValueClearsCurrentValue() throws {
        let storedValue = SecurelyStoredValue<String>(key: "secureMissingValue.\(UUID().uuidString)", service: .test)

        defer {
            try? storedValue.remove()
        }

        try storedValue.set("Cached Value")

        let retrievedValue = storedValue.refreshValue(from: {
            nil
        })

        #expect(retrievedValue == nil)

        let currentValue = storedValue.refreshValue(from: {
            throw ReadError()
        })
        #expect(currentValue == nil)
    }

    @Test("Test that setting nil publishes the removal", .timeLimit(.minutes(1)))
    func testSettingNilPublishesRemoval() async throws {
        let storedValue = SecurelyStoredValue<String>(key: "secureNilRemoval.\(UUID().uuidString)", service: .test)
        try storedValue.set("Persisted Value")

        var values = storedValue.values.makeAsyncIterator()
        let initialValue = await values.next()

        try storedValue.set(nil)

        let removedValue = await values.next()
        #expect(initialValue == "Persisted Value")
        #expect(removedValue == .some(nil))
    }

    @Test("Test that removing a missing value succeeds")
    func testRemovingMissingStoredValueSucceeds() throws {
        let storedValue = SecurelyStoredValue<String>(key: "secureMissingRemoval.\(UUID().uuidString)", service: .test)

        try storedValue.remove()
        try storedValue.remove()

        #expect(storedValue.wrappedValue == nil)
    }

    @Test("Test that writes publish Observation changes exactly once")
    func testWriteObservationNotifications() throws {
        let storedValue = SecurelyStoredValue<String>(key: "secureObservation.\(UUID().uuidString)", service: .test)
        let counter = ObservationCounter()

        defer {
            try? storedValue.remove()
        }

        withObservationTracking {
            _ = storedValue.wrappedValue
        } onChange: {
            counter.increment()
        }
        try storedValue.set("Inserted Value")
        #expect(counter.count == 1)

        withObservationTracking {
            _ = storedValue.wrappedValue
        } onChange: {
            counter.increment()
        }
        try storedValue.set("Updated Value")
        #expect(counter.count == 2)
    }

    @Test("Test that Keychain writes recover when the item changes between operations", arguments: [
        KeychainWriteRaceScenario(initialOperation: .insert, statuses: [errSecDuplicateItem, errSecItemNotFound, errSecSuccess], expectedOperations: [.insert, .update, .insert]),
        KeychainWriteRaceScenario(initialOperation: .update, statuses: [errSecItemNotFound, errSecDuplicateItem, errSecSuccess], expectedOperations: [.update, .insert, .update])
    ])
    func testKeychainWriteRaceRecovery(scenario: KeychainWriteRaceScenario) throws {
        var attemptedOperations: [KeychainWriteOperation] = []
        var statusIndex = 0

        try KeychainWriteOperation.perform(scenario.initialOperation) { operation in
            guard statusIndex < scenario.statuses.count else { throw ReadError() }

            attemptedOperations.append(operation)
            defer { statusIndex += 1 }
            return scenario.statuses[statusIndex]
        }

        #expect(attemptedOperations == scenario.expectedOperations)
    }

    @Test("Test that Keychain writes fail after three recoverable races")
    func testKeychainWriteRaceExhaustion() {
        var attemptedOperations: [KeychainWriteOperation] = []

        #expect(throws: KeychainError.self) {
            try KeychainWriteOperation.perform(.insert) { operation in
                attemptedOperations.append(operation)
                return operation == .insert ? errSecDuplicateItem : errSecItemNotFound
            }
        }

        #expect(attemptedOperations == [.insert, .update, .insert])
    }

}

// MARK: ReadError

private struct ReadError: Error {}

// MARK: KeychainWriteRaceScenario

struct KeychainWriteRaceScenario: Sendable {
    let initialOperation: KeychainWriteOperation
    let statuses: [OSStatus]
    let expectedOperations: [KeychainWriteOperation]
}

// MARK: ObservationCounter

private final class ObservationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        self.lock.withLock {
            self.value
        }
    }

    func increment() {
        self.lock.withLock {
            self.value += 1
        }
    }
}
