import Foundation
import Observation

@Observable
@MainActor
@propertyWrapper
public final class StoredValue<Item: Codable & Sendable> {
    private let observationRegistrar = ObservationRegistrar()
    private let valueSubject: AsyncValueSubject<Item>
    private let cachedValue: CachedValue<Item>

    private let defaultValue: Item
    private let key: String
    private let userDefaults: UserDefaults

    /// Initializes a new @``StoredValue``.
    ///
    /// - Parameters:
    ///   - key: The key to use when storing the value in `UserDefaults`.
    ///   - storage: The `UserDefaults` to use when storing the value.
    public init(wrappedValue: Item, key: String, storage userDefaults: UserDefaults = UserDefaults.standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.userDefaults = userDefaults

        let initialValue = Self.storedValue(forKey: key, userDefaults: userDefaults, defaultValue: defaultValue)
        self.valueSubject = AsyncValueSubject(initialValue)
        self.valueSubject.send(initialValue)

        self.cachedValue = CachedValue(retrieveValue: {
            Self.storedValue(forKey: key, userDefaults: userDefaults, defaultValue: initialValue)
        })
    }

    /// Initializes a new ``StoredValue`` directly, without using a property wrapper.
    ///
    /// - Parameters:
    ///   - key: The key to use when storing the value in `UserDefaults`.
    ///   - defaultValue: The default value to use when no value is stored.
    ///   - storage: The `UserDefaults` to use when storing the value.
    public convenience init(key: String, default defaultValue: Item, storage userDefaults: UserDefaults = UserDefaults.standard) {
        self.init(wrappedValue: defaultValue, key: key, storage: userDefaults)
    }

    /// The currently stored value
    public var wrappedValue: Item {
        get {
            self.retrieveItem()
        }
        set {
            self.persistItem(newValue)
        }
    }

    /// A ``StoredValue`` which exposes ``set(_:)`` and ``reset()`` functions alongside an `AsyncStream` of ``values``.
    public var projectedValue: StoredValue<Item> { self }

    /// An `AsyncStream` that emits all value changes of a @``StoredValue``.
    ///
    /// This stream will emit the initial value when subscribed to, and will further emit
    /// any changes to the value when ``set(_:)`` or ``reset()`` are called.
    public var values: AsyncStream<Item> {
        self.valueSubject.values
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
    /// is a `StoredValue<Item>`. That means you are accessing the `storedValue` you're interacting
    /// with, a value type `Item`. But it is the `projectedValue` that is the `StoredValue<Item>`,
    /// that property and has the ``set(_:) function.
    ///
    /// This follows similar conventions to the `@Published` property wrapper.
    /// `@Published var items: [Item]` allows you to use `items` as a regular `[Item]`,
    /// but `$items` projects `AnyPublisher<[Item], Never>` so you can subscribe to changes items produces.
    /// Within Boutique the @Stored property wrapper works very similarly.
    ///
    /// - Parameter item: The value to set @``StoredValue`` to.
    public func set(_ item: Item) {
        self.persistItem(item)
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
        self.persistItem(self.defaultValue)
    }
}

private extension StoredValue {
    func retrieveItem() -> Item {
        observationRegistrar.access(self, keyPath: \.wrappedValue)

        return self.cachedValue.retrieveValue()
    }

    func persistItem(_ item: Item) {
        observationRegistrar.withMutation(of: self, keyPath: \.wrappedValue) {
            let boxedValue = BoxedValue(value: item)
            if let data = try? JSONCoders.encoder.encode(boxedValue) {
                self.userDefaults.set(data, forKey: self.key)
                self.cachedValue.set(item)
                self.valueSubject.send(item)
            }
        }
    }

    static func storedValue(forKey key: String, userDefaults: UserDefaults, defaultValue: Item) -> Item {
        if let storedValue = userDefaults.data(forKey: key),
           let boxedValue = try? JSONCoders.decoder.decode(BoxedValue<Item>.self, from: storedValue) {
            return boxedValue.value
        } else {
            return defaultValue
        }
    }
}
