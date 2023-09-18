import Combine
import Foundation
import SwiftUI

/// The @``SecurelyStoredValue`` property wrapper automagically persists a single `Item` in the system `Keychain`
/// rather than an array of items that would be persisted in a ``Store`` or using @``Stored``.
///
/// You should use @``SecurelyStoredValue`` rather than @``StoredValue`` when you need to store
/// sensitive values such as passwords or auth tokens, since a @``StoredValue`` will be persisted in `UserDefaults`.
///
/// This is fulfills the same needs as many other Keychain wrappers, but in a Boutique-like manner.
///
/// Values are delivered synchronously and are available on app launch, using the system `Keychain`
/// as the backing store. If you wish to use your own `StorageEngine` you can use @``AsyncStoredValue``.
///
/// Unlike @``StoredValue`` properties @``SecurelyStoredValue`` properties cannot be provided a default value.
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
@propertyWrapper
public struct SecurelyStoredValue<Item: Codable> {
    private let cancellableBox = CancellableBox()
    private let itemSubject = CurrentValueSubject<Item?, Never>(nil)
    private let key: String
    private let group: String?
    private let service: String?

    public init(key: String, group: KeychainGroup? = nil, service: KeychainService? = nil) {
        self.key = key
        self.group = group?.value
        self.service = service?.value
    }

    /// The currently stored value
    public var wrappedValue: Item? {
        Self.storedValue(service: self.keychainService, account: self.key, group: self.group)
    }

    /// A ``SecurelyStoredValue`` which exposes ``set(_:)`` and ``remove()`` functions alongside a ``publisher``.
    public var projectedValue: SecurelyStoredValue<Item> { self }

    /// A Combine publisher that allows you to observe all changes to the @``SecurelyStoredValue``.
    public var publisher: AnyPublisher<Item?, Never> {
        self.itemSubject.eraseToAnyPublisher()
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
    /// This follows similar conventions to the `@Published` property wrapper.
    /// `@Published var items: [Item]` allows you to use `items` as a regular `[Item]`,
    /// but `$items` projects `AnyPublisher<[Item], Never>` so you can subscribe to changes items produces.
    /// Within Boutique the @Stored property wrapper works very similarly.
    ///
    /// - Parameter value: The value to set @``SecurelyStoredValue`` to.
    @MainActor
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
    /// This follows similar conventions to the `@Published` property wrapper.
    /// `@Published var items: [Item]` allows you to use `items` as a regular `[Item]`,
    /// but `$items` projects `AnyPublisher<[Item], Never>` so you can subscribe to changes items produces.
    /// Within Boutique the @Stored property wrapper works very similarly.
    @MainActor
    public func remove() throws {
        if self.wrappedValue != nil {
            try self.removeItem()
        }
    }

    public static subscript<Instance>(
        _enclosingInstance instance: Instance,
        wrapped wrappedKeyPath: KeyPath<Instance, Item?>,
        storage storageKeyPath: KeyPath<Instance, Self>
    ) -> Item? {
        let wrapper = instance[keyPath: storageKeyPath]

        if wrapper.cancellableBox.cancellable == nil {
            wrapper.cancellableBox.cancellable = wrapper.itemSubject
                .receive(on: RunLoop.main)
                .sink(receiveValue: { [instance] _ in
                    func publisher<T>(_ value: T) -> ObservableObjectPublisher? {
                        return (Proxy<T>() as? ObservableObjectProxy)?.extractObjectWillChange(value)
                    }

                    let objectWillChangePublisher = _openExistential(instance as Any, do: publisher)
                    objectWillChangePublisher?.send()
                })
        }

        return wrapper.wrappedValue
    }
}

private extension SecurelyStoredValue {
    static func storedValue(service: String, account: String, group: String?) -> Item? {
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
        guard let extractedData = extractedData as? Data else { return nil }

        return try? JSONCoders.decoder.decodeBoxedData(data: extractedData)
    }

    func insert(_ value: Item) throws {
        let keychainQuery = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: self.keychainService,
            kSecAttrAccount: self.key,
            kSecValueData: try JSONCoders.encoder.encodeBoxedData(item: value)
        ]
        .withGroup(self.group)
        .mapToStringDictionary()

        let status = SecItemAdd(keychainQuery as CFDictionary, nil)

        if status == errSecSuccess || status == errSecDuplicateItem {
            self.itemSubject.send(value)
        } else {
            throw KeychainError(status: status)
        }
    }

    func update(_ value: Item) throws {
        let keychainQuery = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: self.keychainService,
            kSecAttrAccount: self.key,
            kSecValueData: try JSONCoders.encoder.encodeBoxedData(item: value)
        ]
        .withGroup(self.group)
        .mapToStringDictionary()

        let status = SecItemUpdate(keychainQuery as CFDictionary, keychainQuery as CFDictionary)

        if status == errSecSuccess {
            self.itemSubject.send(value)
        } else {
            throw KeychainError(status: status)
        }
    }

    func removeItem() throws {
        var keychainQuery = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: self.keychainService,
            kSecAttrAccount: key
        ]
        .withGroup(self.group)
        .mapToStringDictionary()

#if os(macOS)
        // This line must exist on OS X, but must not exist on iOS.
        // Source: https://github.com/square/Valet/blob/c095ce0ac15716bee167aefc273e17c2c3cd4919/Sources/Valet/Internal/SecItem.swift#L123
        keychainQuery[kSecMatchLimit as String] = kSecMatchLimitAll
#endif
        let status = SecItemDelete(keychainQuery as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            self.itemSubject.send(nil)
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

private extension SecurelyStoredValue {
    final class CancellableBox {
        var cancellable: AnyCancellable?
    }
}
