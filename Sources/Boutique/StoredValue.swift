import Combine

/// A `@StoredValue` property wrapper to automagically persist any item rather than
/// an array of items that would be persisted in a `Store` or using `@Stored`.
@propertyWrapper
public struct StoredValue<Item: Codable & Equatable> {

    private let box: Box
    private let key: String

    public init(key: String, storage: StorageEngine = SQLiteStorageEngine(directory: .defaultStorageDirectory(appendingPath: "Data"))!) {
        let innerStore = Store<UniqueItem>(storage: storage, cacheIdentifier: \.id)
        self.key = key
        self.box = Box(innerStore)
    }

    @MainActor
    public var wrappedValue: Item? {
        self.box.store.items.first(where: { $0.id == key })?.value
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
        return box.store.$items
            .map { $0.first(where: { $0.id == key })?.value }
            .eraseToAnyPublisher()
    }

    /// Sets a value for the `@StoredValue` property.
    /// - Parameter value: The value to set `@StoredValue` to.
    public func set(_ value: Item) async throws {
        try await self.box.store.add(
            UniqueItem(
                id: self.key,
                value: value
            )
        )
    }

    /// Sets the `@StoredValue` to nil.
    @MainActor
    public func reset() async throws {
        if let item = self.box.store.items.first(where: { $0.id == key }) {
            try await self.box.store.remove(item)
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
        var id: String
        var value: Item
    }

}
