import Combine
import Foundation
import SwiftUI

/// The @``StoredValue`` property wrapper to automagically persist a single `Item` in `UserDefaults`
/// rather than an array of items that would be persisted in a ``Store`` or using @``Stored``.
///
/// You should use a @``StoredValue`` if you're only storing a single item, as opposed to a @``Store``
/// which stores an array of items exposed as the `items: [Item]` property.
///
/// This is useful for similar use cases as `UserDefaults`, where it's common to store only a single item
/// such as the app's `lastOpenedDate`, an object of the user's preferences, configurations, and more.
///
/// Results are delivered synchronously so values are available on app launch, using `UserDefaults` as the
/// backing store to accomplish this. If you wish to use your own `StorageEngine` you can use @``AsyncStoredValue``.
///
/// You must initialize a @``StoredValue`` with a default value like you would any other Swift property.
/// ```
/// @StoredValue(key: "redPanda")
/// private var redPanda = RedPanda(cuteRating: 100)
/// ```
///
/// A @``StoredValue`` can be nullable, but in that case you will have to specify the type as well.
/// ```
/// @StoredValue<RedPanda?>(key: "pandaRojo")
/// private var spanishRedPanda = nil
/// ```
///
/// Using @``StoredValue`` is also straightforward, there are only two functions.
/// To change the value of the @``StoredValue``, you can use the ``set(_:)`` and ``reset()`` functions.
/// ```
/// $redPanda.set(RedPanda(cuteRating: 99)) // The @StoredValue has a new red panda
/// $redPanda.reset() // The @AsyncStoredValue is nil
/// ```
///
/// One last bit of advice, when calling ``set(_:)`` and ``reset()`` don't forget to put a `$`
/// in front of the the `$storedValue`.
///
/// See: ``set(_:)`` and ``reset()`` docs for a more in depth explanation.
@propertyWrapper
public struct StoredValue<Item: Codable & Equatable> {

    private let cancellableBox = CancellableBox()
    private let defaultValue: Item
    private let key: String
    private let userDefaults: UserDefaults
    private let itemSubject: CurrentValueSubject<Item, Never>

    public init(wrappedValue: Item, key: String, storage userDefaults: UserDefaults = UserDefaults.standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.userDefaults = userDefaults

        let initialValue = Self.storedValue(forKey: key, userDefaults: userDefaults, defaultValue: defaultValue)
        self.itemSubject = CurrentValueSubject(initialValue)
    }

    /// The currently stored value
    public var wrappedValue: Item {
        Self.storedValue(forKey: self.key, userDefaults: self.userDefaults, defaultValue: self.defaultValue)
    }

    /// A `StoredValue` which exposes ``set(_:)`` and ``reset()`` functions alongside a ``publisher``.
    public var projectedValue: StoredValue<Item> { self }

    /// A Combine publisher that allows you to observe all changes to the @``StoredValue``.
    public var publisher: AnyPublisher<Item, Never> {
        self.itemSubject.eraseToAnyPublisher()
    }

    /// Sets a value for the @``StoredValue`` property.
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
    /// is a `StoredValue<Item>`. That means when you access `storedValue` you're interacting
    /// with the item itself, of type `Item`. But it's the `projectedValue` that is
    /// the `StoredValue<Item>` type, and has the ``set(_:) function.
    ///
    /// This follows similar conventions to the `@Published` property wrapper.
    /// `@Published var items: [Item]` would let you use `items` as a regular `[Item]`,
    /// but $items projects `AnyPublisher<[Item], Never>` so you can subscribe to changes items produces.
    /// Within Boutique the @Stored property wrapper works very similarly.
    /// - Parameter value: The value to set @``StoredValue`` to.
    public func set(_ value: Item) {
        let boxedValue = BoxedValue(value: value)
        if let data = try? JSONEncoder().encode(boxedValue) {
            self.userDefaults.set(data, forKey: self.key)

            Task { @MainActor in
                self.itemSubject.send(value)
            }
        }
    }

    /// Resets the @``StoredValue`` to the default value.
    ///
    /// You may run into an error that says
    ///
    /// ```
    /// "'reset' is inaccessible due to 'internal' protection level."
    /// ```
    ///
    /// If that occurs the fix is straightforward. Rather than calling `storedValue.reset()`
    /// you need to call `$storedValue.reset()`, with a dollar sign ($) in front of `storedValue`.
    ///
    /// When using a property wrapper the ``wrappedValue`` is an `Item`, but the `projectedValue`
    /// is a `StoredValue<Item>`. That means when you access `storedValue` you're interacting
    /// with the item itself, of type `Item`. But it's the `projectedValue` that is
    /// the `StoredValue<Item>` type, and has the ``reset()`` function.
    ///
    /// This follows similar conventions to the `@Published` property wrapper.
    /// `@Published var items: [Item]` would let you use `items` as a regular `[Item]`,
    /// but $items projects `AnyPublisher<[Item], Never>` so you can subscribe to changes items produces.
    /// Within Boutique the @Stored property wrapper works very similarly.
    public func reset() {
        let boxedValue = BoxedValue(value: self.defaultValue)
        if let data = try? JSONEncoder().encode(boxedValue) {
            self.userDefaults.set(data, forKey: self.key)

            Task { @MainActor in
                self.itemSubject.send(self.defaultValue)
            }
        }
    }

    public static subscript<Instance>(
        _enclosingInstance instance: Instance,
        wrapped wrappedKeyPath: KeyPath<Instance, Item>,
        storage storageKeyPath: KeyPath<Instance, Self>
    ) -> Item {
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

private extension StoredValue {

    static func storedValue(forKey key: String, userDefaults: UserDefaults, defaultValue: Item) -> Item {
        if let storedValue = userDefaults.object(forKey: key) as? Data,
           let boxedValue = try? JSONDecoder().decode(BoxedValue<Item>.self, from: storedValue) {
            return boxedValue.value
        } else {
            return defaultValue
        }
    }

}

private extension StoredValue {

    private struct BoxedValue<T: Codable>: Codable {
        var value: T
    }

    final class CancellableBox {
        var cancellable: AnyCancellable?
    }

}
