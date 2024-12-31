import Combine

/// The @``AsyncStoredValue`` property wrapper to automagically persist a single `Item` in a `StorageEngine`
/// rather than an array of items that would be persisted in a ``Store`` or using @``Stored``.
///
/// You should use an @``AsyncStoredValue`` if you're only storing a single item, as opposed to a @``Store``
/// which stores an array of items exposed as the `items: [Item]` property.
///
/// This is useful for similar use cases as `UserDefaults`, where it's common to store only a single item
/// such as the app's `lastOpenedDate`, an object of the user's preferences, configurations, and more.
///
/// Results are delivered asynchronously so you cannot depend on this value to be available on-demand.
/// **If you need to access a value at app launch you should consider using** ``StoredValue`` which has
/// the same API but stores data into `UserDefaults`.
///
/// You must initialize an @``AsyncStoredValue`` with a default value like you would any other Swift property.
/// ```
/// @AsyncStoredValue(storage: SQLiteStorageEngine.default(appendingPath: "RedPandaStorage"))
/// private var redPanda = RedPanda(cuteRating: 100)
/// ```
///
/// An @``AsyncStoredValue`` can be nullable but in that case you will have to specify the type as well.
/// ```
/// @AsyncStoredValue<RedPanda?>(storage: SQLiteStorageEngine.default(appendingPath: "SpanishRedPandaStorage"))
/// private var spanishRedPanda = nil
/// ```
///
/// Using @``AsyncStoredValue`` is also straightforward, there are only two functions.
/// To change the value of the @``AsyncStoredValue``, you can use the ``set(_:)`` and ``reset()`` functions.
/// ```
/// $redPanda.set(RedPanda(cuteRating: 99)) // The @AsyncStoredValue has a new red panda
/// $redPanda.reset() // The @AsyncStoredValue is nil
/// ```
///
/// One last bit of advice, when calling ``set(_:)`` and ``reset()`` don't forget to put a `$`
/// in front of the the `$storedValue`.
///
/// See: ``set(_:)`` and ``reset()`` docs for a more in depth explanation.
@MainActor
@propertyWrapper
public struct AsyncStoredValue<Item: Codable & Equatable> {
    private let cancellableBox: CancellableBox
    private let defaultValue: Item

    /// Initializes an @``AsyncStoredValue``.
    ///
    /// This initializer allows you to specify an item to save and a `StorageEngine` where the `Item` should be stored.
    /// For example if you were to create a `StorageEngine` that has it's own concept of keys or even allows
    /// you to store items in the Keychain, you would need to be able to provide the underlying storage mechanism.
    /// 
    /// - Parameters:
    ///   - wrappedValue: An value set when initializing an @``AsyncStoredValue``
    ///   - storage: A `StorageEngine` that defines where the value will be stored.
    public init(wrappedValue: Item, storage: StorageEngine) {
        let innerStore = Store<UniqueItem>(storage: storage, cacheIdentifier: \.id)
        self.cancellableBox = CancellableBox(innerStore)

        self.defaultValue = wrappedValue
    }

    /// The currently stored value
    public var wrappedValue: Item {
        self.cancellableBox.store.items.first?.value ?? self.defaultValue
    }

    /// An @``AsyncStoredValue`` which exposes ``set(_:)`` and ``reset()`` functions alongside a ``publisher``.
    public var projectedValue: AsyncStoredValue<Item> { self }

    /// A Combine publisher that allows you to observe any changes to the @``AsyncStoredValue``.
    public var publisher: AnyPublisher<Item, Never> {
        self.cancellableBox.store.$items.map({
            $0.first?.value ?? self.defaultValue
        })
        .eraseToAnyPublisher()
    }

    /// Sets a value for the @``AsyncStoredValue`` property.
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
    /// is a `AsyncStoredValue<Item>`. That means you are accessing the `storedValue` you're interacting
    /// with, a value type `Item`. But it is the `projectedValue` that is the `AsyncStoredValue<Item>`,
    /// that property and has the ``set(_:) function.
    ///
    /// This follows similar conventions to the `@Published` property wrapper.
    /// `@Published var items: [Item]` allows you to use `items` as a regular `[Item]`,
    /// but `$items` projects `AnyPublisher<[Item], Never>` so you can subscribe to changes items produces.
    /// Within Boutique the @Stored property wrapper works very similarly.
    ///
    /// - Parameter value: The value to set @``AsyncStoredValue`` to.
    public func set(_ value: Item) async throws {
        try await self.cancellableBox.store.insert(UniqueItem(value: value))
    }

    /// Resets the @``AsyncStoredValue`` to the default value.
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
    /// is a `AsyncStoredValue<Item>`. That means when you access `storedValue` you're interacting
    /// with the item itself, of type `Item`. But it's the `projectedValue` that is
    /// the `AsyncStoredValue<Item>` type, and has the ``reset()`` function.
    ///
    /// This follows similar conventions to the `@Published` property wrapper.
    /// `@Published var items: [Item]` would let you use `items` as a regular `[Item]`,
    /// but $items projects `AnyPublisher<[Item], Never>` so you can subscribe to changes items produces.
    /// Within Boutique the @Stored property wrapper works very similarly.
    public func reset() async throws {
        try await self.cancellableBox.store.removeAll()
    }

    public static subscript<Instance>(
        _enclosingInstance instance: Instance,
        wrapped wrappedKeyPath: KeyPath<Instance, Item>,
        storage storageKeyPath: KeyPath<Instance, Self>
    ) -> Item {
        let wrapper = instance[keyPath: storageKeyPath]

        if wrapper.cancellableBox.cancellable == nil {
            wrapper.cancellableBox.cancellable = wrapper.cancellableBox.store
                .objectWillChange
                .sink(receiveValue: { [instance] in
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

private extension AsyncStoredValue {
    // An internal type to box the item being saved in the Store ensuring
    // we can only ever have one item due to the hard-coded `cacheIdentifier`.
    struct UniqueItem: Codable, Equatable {
        var id: String { "unique-value" }
        var value: Item
    }

    final class CancellableBox {
        let store: Store<UniqueItem>
        var cancellable: AnyCancellable?

        init(_ store: Store<UniqueItem>) {
            self.store = store
        }
    }
}
