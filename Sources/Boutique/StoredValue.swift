import Combine
import Foundation

/// A `@StoredValue` property wrapper to automagically persist a single `Item` rather than
/// an array of items that would be persisted in a `Store` or using `@Stored`.
@propertyWrapper
public struct StoredValue<Item: Codable & Equatable> {

    private let box: Box

    /// Initializes a `@StoredValue`.
    ///
    /// There are two notable differences between `@Store` and `@StoredValue`.
    /// 1. A `@StoredValue` stores only one item, as opposed to a `@Store` which stores
    /// an array of items exposed as the `items: [Item]` property. A `@StoredValue` exposes only
    /// one value, an `Item?`. This is useful for similar use cases as `UserDefaults`,
    /// where it's common to store only an item such as the app's `lastOpenedDate`,
    /// an object of the user's preferences, configurations, and more.
    /// 2. When you use a `@Store` you have to consider how the item will be stored,
    /// but with `@StoredValue` a database will be transparently created for you to store the item.
    /// This ensures that you will be able to retrieve the item quickly since there is only one item,
    /// useful for situations where you need a value at the launch of your app.
    ///
    /// Creating a `@StoredValue` is straightforward and easy, resembling the `@AppStorage` API.
    ///
    /// You can initialize the `@StoredValue` with a default value like you would any other Swift property.
    /// ```
    /// @StoredValue(key: "redPanda")
    /// private var redPanda = RedPanda(cuteRating: 100)
    /// ```
    ///
    /// It's perfectly reasonable to not provide a default value for your `@StoredValue`,
    /// but you will have to define such as the below example.
    /// ```
    /// @StoredValue<RedPanda>(key: "pandaRojo")
    /// private var spanishRedPanda
    /// ```
    ///
    /// - Parameters:
    ///   - wrappedValue: An value set when initializing a `@StoredValue`
    ///   - key: The key to store.
    ///   - directory: A directory where `@StoredValue` will be saved.
    ///   The default location should generally be used but is if you need to specify a location
    ///   for where values are stored, such as the `.sharedContainer` for extensions.
    public init(wrappedValue: Item? = nil, key: String, directory: FileManager.Directory = .defaultStorageDirectory(appendingPath: "")) {
        let directory = FileManager.Directory(url: directory.url.appendingPathComponent(key))
        let innerStore = Store<UniqueItem>(storage: SQLiteStorageEngine(directory: directory)!, cacheIdentifier: \.id)
        self.box = Box(innerStore)

        do { try wrappedValue.map(self.synchronousSet) } catch { }
    }

    @MainActor
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

    /// A Combine publisher that allows you to observe any changes to the `@StoredValue`.
    public var publisher: AnyPublisher<Item?, Never> {
        return self.box.store.$items.map(\.first?.value).eraseToAnyPublisher()
    }

    /// Sets a value for the `@StoredValue` property.
    /// - Parameter value: The value to set `@StoredValue` to.
    public func set(_ value: Item) async throws {
        try await self.box.store.add(UniqueItem(value: value))
    }

    /// Sets the `@StoredValue` to nil.
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
