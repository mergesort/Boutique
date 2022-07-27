import Combine

/// A `@StoredValue` property wrapper to automagically persist any item rather than
/// an array of items that would be persisted in a `Store` or using `@Stored`.
@propertyWrapper
public struct StoredValue<Item: Codable & Equatable> {

    private let box: Box

    public init(using storage: StorageEngine = SQLiteStorageEngine(directory: .documents(appendingPath: "Data"))!) {
        let innerStore = Store<UniqueItem>(storage: storage, cacheIdentifier: \.id)
        self.box = Box(innerStore)
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
        return box.store.$items.map(\.first?.value).eraseToAnyPublisher()
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
