import Combine

/// The @``Stored`` property wrapper to automagically initialize a ``Store``.
@propertyWrapper
public struct Stored<Item: Codable> {

    private let cancellableBox: CancellableBox

    /// Initializes a @``Stored`` property that will be exposed as an `[Item]` and project a `Store<Item>`.
    /// - Parameter store: The store that will be wrapped to expose as an array.
    public init(in store: Store<Item>) {
        self.cancellableBox = CancellableBox(store)
    }

    @MainActor
    /// The currently stored items
    public var wrappedValue: [Item] {
        cancellableBox.store.items
    }

    public var projectedValue: Store<Item> {
        cancellableBox.store
    }

    @MainActor public static subscript<Instance>(
        _enclosingInstance instance: Instance,
        wrapped wrappedKeyPath: KeyPath<Instance, [Item]>,
        storage storageKeyPath: KeyPath<Instance, Self>
    ) -> [Item] {
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

private extension Stored {

    final class CancellableBox {
        let store: Store<Item>
        var cancellable: AnyCancellable?

        init(_ store: Store<Item>) {
            self.store = store
        }
    }

}
