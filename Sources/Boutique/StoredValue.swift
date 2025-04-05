import Foundation
import Observation

/// The @``StoredValue`` property wrapper to automagically persist a single `Item` in `UserDefaults`
/// rather than an array of items that would be persisted in a ``Store`` or using @``Stored``.
///
/// You should use a @``StoredValue`` if you're only storing a single item, as opposed to a @``Store``
/// which stores an array of items exposed as the `items: [Item]` property.
///
/// This is useful for similar use cases as `UserDefaults`, where it's common to store only a single item
/// such as the app's `lastOpenedDate`, an object of the user's preferences, configurations, and more.
///
/// Values are delivered synchronously and are available on app launch, using `UserDefaults` as the
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
///
/// When using `@StoredValue` in an `@Observable` class, you should add the `@ObservationIgnored` attribute
/// to prevent duplicate observation tracking:
///
/// ```swift
/// @Observable
/// final class Preferences {
///     @ObservationIgnored
///     @StoredValue(key: "hasHapticsEnabled")
///     var hasHapticsEnabled = false
///
///     @ObservationIgnored
///     @StoredValue(key: "lastOpenedDate")
///     var lastOpenedDate: Date? = nil
/// }
/// ```
@MainActor
@Observable
@propertyWrapper
public final class StoredValue<Item: StorableItem> {
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
        self.cachedValue.wrappedValue
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
    /// This follows similar conventions to property wrappers like `@Published`.
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
    /// This follows similar conventions to property wrappers like `@Published`.
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

        return self.cachedValue.wrappedValue
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
