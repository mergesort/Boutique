import Foundation
import Observation
import SwiftUI

/// The @``SecurelyStoredValue`` property wrapper automagically persists a single `Item` in the system `Keychain`
/// rather than an array of items that would be persisted in a ``Store`` or using @``Stored``.
///
/// You should use @``SecurelyStoredValue`` rather than @``StoredValue`` when you need to store
/// sensitive values such as passwords or auth tokens, since a @``StoredValue`` will be persisted in `UserDefaults`.
///
/// This fulfills the same needs as many other Keychain wrappers, but in a Boutique-like manner.
///
/// Values are delivered synchronously and are available on app launch, using the system `Keychain`
/// as the backing store.
///
/// Unlike @``StoredValue`` properties, @``SecurelyStoredValue`` properties cannot be provided a default value.
/// ```
/// @SecurelyStoredValue<RedPanda>(key: "redPanda")
/// private var redPanda
/// ```
///
/// Since keychain values may or may not exist, a @``SecurelyStoredValue`` is nullable by default.
/// Something to watch out for: You do not need to specify your type as nullable. If you do so
/// the type will be a double optional (`??`) rather than optional (`?`).
/// ```
/// @SecurelyStoredValue<RedPanda?>(key: "redPanda")
/// ```
///
/// Using @``SecurelyStoredValue`` is also straightforward, there are only two functions.
/// To change the value of the @``SecurelyStoredValue``, you can use the ``set(_:)`` and ``remove()`` functions.
/// ```
/// $redPanda.set(RedPanda(cuteRating: 99)) // The @SecurelyStoredValue has a new red panda
/// $redPanda.remove() // The @SecurelyStoredValue is nil
/// ```
///
/// One last bit of advice, when calling ``set(_:)`` and ``remove()`` don't forget to put a `$`
/// in front of the the `$storedValue`.
///
/// See: ``set(_:)`` and ``remove()`` docs for a more in depth explanation.
///
/// When using `@SecurelyStoredValue` in an `@Observable` class, you should add the `@ObservationIgnored` attribute
/// to prevent duplicate observation tracking:
///
/// ```swift
/// @Observable
/// final class AppState {
///     @ObservationIgnored
///     @SecurelyStoredValue<String>(key: "userID")
/// }
/// ```
@MainActor
@Observable
@propertyWrapper
public final class SecurelyStoredValue<Item: StorableItem>: DynamicProperty {
    private let observationRegistrar = ObservationRegistrar()
    private let valueSubject = AsyncValueSubject<Item?>(nil)

    private let key: String
    private let service: String?
    private let group: String?

    /// Initializes a new @``SecurelyStoredValue``.
    ///
    /// - Parameters:
    ///   - key: The key to use when storing the value in the keychain.
    ///   - service: The service to use when storing the value in the keychain.
    ///   - group: The group to use when storing the value in the keychain.
    public init(key: String, service: KeychainService? = nil, group: KeychainGroup? = nil) {
        self.key = key
        self.service = service?.value
        self.group = group?.value

        let initialValue = try? Self.storedValue(group: group?.value, service: self.keychainService, account: key)
        self.valueSubject.send(initialValue)
    }

    /// The currently stored value
    public var wrappedValue: Item? {
        self.retrieveItem()
    }

    /// A ``SecurelyStoredValue`` which exposes ``set(_:)`` and ``remove()`` functions alongside an `AsyncStream` of ``values``.
    public var projectedValue: SecurelyStoredValue<Item> { self }

    /// An `AsyncStream` that emits all value changes of a @``SecurelyStoredValue``.
    ///
    /// This stream will emit the initial value when subscribed to, and will further emit
    /// any changes to the value when ``set(_:)`` or ``remove()`` are called.
    public var values: AsyncStream<Item?> {
        self.valueSubject.values
    }

    /// Sets a value for the @``SecurelyStoredValue`` property.
    ///
    /// You may run into an error that says
    ///
    /// ```
    /// "'set' is inaccessible due to 'internal' protection level."
    /// ```
    ///
    /// If that occurs the fix is straightforward. Rather than calling `storedValue.set(newValue)`
    /// you need to call `$storedValue.set(newValue)`, with a dollar sign ($) in front of `storedValue`.
    ///
    /// When using a property wrapper the ``wrappedValue`` is an `Item`, but the `projectedValue`
    /// is a `SecurelyStoredValue<Item>`. That means you are accessing the `storedValue` you're interacting
    /// with, a value type `Item`. But it is the `projectedValue` that is the `SecurelyStoredValue<Item>`,
    /// that property and has the ``set(_:) function.
    ///
    /// This follows similar conventions to property wrappers like `@Published`.
    /// `@Published var items: [Item]` allows you to use `items` as a regular `[Item]`,
    /// but `$items` projects `AnyPublisher<[Item], Never>` so you can subscribe to changes items produces.
    /// Within Boutique the @Stored property wrapper works very similarly.
    ///
    /// - Parameter value: The value to set @``SecurelyStoredValue`` to.
    public func set(_ value: Item?) throws {
        if let value {
            if self.wrappedValue == nil {
                try self.insert(value)
            } else {
                try self.update(value)
            }
        } else {
            try self.remove()
        }
    }

    /// Removes the @``SecurelyStoredValue``.
    ///
    /// You may run into an error that says
    ///
    /// ```
    /// "'remove' is inaccessible due to 'internal' protection level."
    /// ```
    ///
    /// If that occurs the fix is straightforward. Rather than calling `storedValue.remove()`
    /// you need to call `$storedValue.remove()`, with a dollar sign ($) in front of `storedValue`.
    ///
    /// When using a property wrapper the ``wrappedValue`` is an `Item`, but the `projectedValue`
    /// is a `SecurelyStoredValue<Item>`. That means you are accessing the `storedValue` you're interacting
    /// with, a value type `Item`. But it is the `projectedValue` that is the `SecurelyStoredValue<Item>`,
    /// that property and has the ``set(_:) function.
    ///
    /// This follows similar conventions to property wrappers like `@Published`.
    /// `@Published var items: [Item]` allows you to use `items` as a regular `[Item]`,
    /// but `$items` projects `AnyPublisher<[Item], Never>` so you can subscribe to changes items produces.
    /// Within Boutique the @Stored property wrapper works very similarly.
    @MainActor
    public func remove() throws {
        let currentValue = self.valueSubject.value
        var keychainQuery = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: self.keychainService,
            kSecAttrAccount: self.key
        ]
        .withGroup(self.group)
        .mapToStringDictionary()

		#if os(macOS)
        // This line must exist on OS X, but must not exist on iOS.
        // Source: https://github.com/square/Valet/blob/c095ce0ac15716bee167aefc273e17c2c3cd4919/Sources/Valet/Internal/SecItem.swift#L123
        keychainQuery[kSecMatchLimit as String] = kSecMatchLimitAll
		#endif

        let status = SecItemDelete(keychainQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
        guard currentValue != nil else { return }

        self.publishValueChange(nil)
    }
}

extension SecurelyStoredValue {
    func refreshValue(from readValue: () throws -> Item?) -> Item? {
        do {
            let retrievedValue = try readValue()
            self.valueSubject.value = retrievedValue
            return retrievedValue
        } catch {
            return self.valueSubject.value
        }
    }
}

// MARK: Private

private extension SecurelyStoredValue {
    static func storedValue(group: String?, service: String, account: String) throws -> Item? {
        let keychainQuery = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true
        ]
        .withGroup(group)
        .mapToStringDictionary()

        var extractedData: AnyObject?
        let status = SecItemCopyMatching(keychainQuery as CFDictionary, &extractedData)

        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        guard let extractedData = extractedData as? Data else { throw KeychainError.couldNotAccessKeychain }

        return try JSONCoders.decoder.decodeBoxedData(data: extractedData)
    }

    func insert(_ value: Item) throws {
        try self.write(value, operation: .insert)
    }

    func addItem(_ value: Item) throws -> OSStatus {
        let keychainQuery = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: self.keychainService,
            kSecAttrAccount: self.key,
            kSecValueData: try JSONCoders.encoder.encodeBoxedData(item: value)
        ]
        .withGroup(self.group)
        .mapToStringDictionary()

        return SecItemAdd(keychainQuery as CFDictionary, nil)
    }

    func update(_ value: Item) throws {
        try self.write(value, operation: .update)
    }

    func updateItem(_ value: Item) throws -> OSStatus {
        let keychainQuery = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: self.keychainService,
            kSecAttrAccount: self.key
        ]
        .withGroup(self.group)
        .mapToStringDictionary()

        let attributesToUpdate = [
            kSecValueData: try JSONCoders.encoder.encodeBoxedData(item: value)
        ]
        .mapToStringDictionary()

        return SecItemUpdate(keychainQuery as CFDictionary, attributesToUpdate as CFDictionary)
    }

    /// Writes a value by moving between insert and update as the Keychain reports its current state.
    ///
    /// The cached value determines the first operation, but another process may change
    /// the Keychain before that operation executes. An insert that finds an existing item
    /// transitions to update, while an update that finds no item transitions to insert.
    ///
    /// A third attempt handles the item changing again between those first two operations.
    /// The value is published only after an operation succeeds, and any other Keychain status
    /// fails the operation immediately.
    func write(_ value: Item, operation: KeychainWriteOperation) throws {
        try KeychainWriteOperation.perform(operation) { operation in
            try operation == .insert ? self.addItem(value) : self.updateItem(value)
        }

        self.publishValueChange(value)
    }

    func retrieveItem() -> Item? {
        observationRegistrar.access(self, keyPath: \.wrappedValue)

        return self.refreshValue(from: {
            try Self.storedValue(group: self.group, service: self.keychainService, account: self.key)
        })
    }

    func publishValueChange(_ value: Item?) {
        observationRegistrar.withMutation(of: self, keyPath: \.wrappedValue) {
            self.valueSubject.send(value)
        }
    }

    var keychainService: String {
        self.service ?? Self.defaultService
    }

    static var defaultService: String {
        // Force unwrapping because if the app somehow has a nil bundleIdentifier
        // we have much bigger problems than a nil bundleIdentifier.
        Bundle.main.bundleIdentifier!
    }
}

// MARK: KeychainWriteOperation

enum KeychainWriteOperation {
    case insert
    case update

    static func perform(_ initialOperation: Self, using performOperation: (Self) throws -> OSStatus) throws {
        let maximumAttempts = 3
        var operation = initialOperation
        var status = errSecSuccess

        for _ in 0..<maximumAttempts {
            status = try performOperation(operation)

            switch (operation, status) {
            case (_, errSecSuccess):
                return

            case (.insert, errSecDuplicateItem):
                operation = .update

            case (.update, errSecItemNotFound):
                operation = .insert

            default:
                throw KeychainError(status: status)
            }
        }

        throw KeychainError(status: status)
    }
}

// MARK: Dictionary

private extension Dictionary where Key == CFString, Value == Any {
    func mapToStringDictionary() -> [String : Any] {
        Dictionary<String, Any>(
            uniqueKeysWithValues: self.map({ key, value in
                return (key as String, value)
            })
        )
    }

    func withGroup(_ group: String?) -> [CFString : Any] {
        var dictionary = self
        if let group {
            dictionary[kSecAttrAccessGroup] = group
        }

        return dictionary
    }
}
