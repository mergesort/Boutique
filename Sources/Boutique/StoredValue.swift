import Combine
import Foundation

/// The @``StoredValue`` property wrapper to automagically persist a single `Item` rather than
/// an array of items that would be persisted in a ``Store`` or using @``Stored``.
///
/// There are two notable differences between @``Store`` and @``StoredValue``.
/// 1. A @``StoredValue`` stores only one item, as opposed to a @``Store`` which stores
/// an array of items exposed as the `items: [Item]` property. A @``StoredValue`` exposes only
/// one value, an `Item?`. This is useful for similar use cases as `UserDefaults`,
/// where it's common to store only an item such as the app's `lastOpenedDate`,
/// an object of the user's preferences, configurations, and more.
///
/// 2. When you use a @``Store`` you have to consider how the item will be stored,
/// but with @``StoredValue`` a database will be transparently created for you to store the item.
/// This ensures that you will be able to retrieve the item quickly since there is only one item,
/// useful for situations where you need a value at the launch of your app.
///
/// Creating a @``StoredValue`` is straightforward and easy, resembling the `@AppStorage` API.
///
/// You can initialize the @``StoredValue`` with a default value like you would any other Swift property.
/// ```
/// @StoredValue(key: "redPanda")
/// private var redPanda = RedPanda(cuteRating: 100)
/// ```
///
/// It's perfectly reasonable to not provide a default value for your @``StoredValue``,
/// but you will have to define such as the below example.
/// ```
/// @StoredValue<RedPanda>(key: "pandaRojo")
/// private var spanishRedPanda
/// ```
///
/// Using @``StoredValue`` is also straightforward, there are only two functions.
/// To change the values of the @``StoredValue``, you can use the ``set(_:)`` and ``reset()`` functions.
/// ```
/// $redPanda.set(RedPanda(cuteRating: 99)) // The @StoredValue has a new red panda
/// $redPanda.reset() // The @StoredValue is nil
/// ```
/// One last bit of advice, when calling ``set(_:)`` and ``reset()`` don't forget to put a `$`
/// in front of the the `$storedValue`.
///
/// See: ``set(_:)`` and ``reset()`` docs for a more in depth explanation.
@propertyWrapper
public struct StoredValue<Item: Codable & Equatable> {

    private let box: Box

    /// Initializes an ``StoredValue``.
    ///
    /// - Parameters:
    ///   - wrappedValue: An value set when initializing a @``StoredValue``
    ///   - key: The key to store.
    ///   - directory: A directory where @``StoredValue`` will be saved.
    ///   The default location should generally be used but is if you need to specify a location
    ///   for where values are stored, such as the `.sharedContainer` for extensions.
    public init(wrappedValue: Item? = nil, key: String, directory: FileManager.Directory = .defaultStorageDirectory(appendingPath: "")) {
        let directory = FileManager.Directory(url: directory.url.appendingPathComponent(key))
        let innerStore = Store<UniqueItem>(storage: SQLiteStorageEngine(directory: directory)!, cacheIdentifier: \.id)
        self.box = Box(innerStore)

        do { try wrappedValue.map(self.synchronousSet) } catch { }
    }

    @MainActor
    /// The currently stored value
    public var wrappedValue: Item? {
        self.box.store.items.first?.value
    }

    public var projectedValue: StoredValue<Item> { self }

    @MainActor public static subscript<Instance>(
        _enclosingInstance instance: Instance,
        wrapped wrappedKeyPath: KeyPath<Instance, Item?>,
        storage storageKeyPath: KeyPath<Instance, Self>
    ) -> Item? {
        let wrapper = instance[keyPath: storageKeyPath]

        if wrapper.box.cancellable == nil {
            wrapper.box.cancellable = wrapper.box.store
                .objectWillChange
                .sink(receiveValue: { [instance] in
                    if let objectWillChangePublisher = instance as? ObservableObjectPublisher {
                        objectWillChangePublisher.send()
                    }
                })
        }

        return wrapper.wrappedValue
    }

    /// A Combine publisher that allows you to observe any changes to the @``StoredValue``.
    public var publisher: AnyPublisher<Item?, Never> {
        return self.box.store.$items.map(\.first?.value).eraseToAnyPublisher()
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
    public func set(_ value: Item) async throws {
        try await self.box.store.add(UniqueItem(value: value))
    }

    /// Sets the @``StoredValue`` to nil.
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
    public func reset() async throws {
        try await self.box.store.removeAll()
    }

}

private extension StoredValue {

    // A synchronous version of set to seed default values in @StoredValue initializers
    func synchronousSet(_ value: Item) throws {
        Task {
            try await self.set(value)
        }
    }

}

private extension StoredValue {

    final class Box {
        let store: Store<UniqueItem>
        var cancellable: AnyCancellable?
        init(_ store: Store<UniqueItem>) {
            self.store = store
        }
    }

    // An internal type to box the item being saved in the Store ensuring
    // we can only ever have one item due to the hard-coded `cacheIdentifier`.
    struct UniqueItem: Codable, Equatable {
        var id: String { "unique-value" }
        var value: Item
    }

}
