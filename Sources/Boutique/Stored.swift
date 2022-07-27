import Combine

/// A `@Stored` property wrapper to automagically initialize a `Store`.
@propertyWrapper
public struct Stored<Item: Codable & Equatable> {

    private let box: Box

    public init(in store: Store<Item>) {
        self.box = Box(store)
    }

    @MainActor
    public var wrappedValue: [Item] {
        box.store.items
    }

    public var projectedValue: Store<Item> {
        box.store
    }

    @MainActor public static subscript<Instance>(
        _enclosingInstance instance: Instance,
        wrapped wrappedKeyPath: KeyPath<Instance, [Item]>,
        storage storageKeyPath: KeyPath<Instance, Self>
    ) -> [Item] {
        let wrapper = instance[keyPath: storageKeyPath]

        if wrapper.box.cancellable == nil {
            wrapper.box.cancellable = wrapper.projectedValue
                .objectWillChange
                .sink(receiveValue: {
                    if let objectWillChangePublisher = instance as? ObservableObjectPublisher {
                        objectWillChangePublisher.send()
                    }
                })
        }

        return wrapper.wrappedValue
    }

}

private extension Stored {

    final class Box {
        let store: Store<Item>
        var cancellable: AnyCancellable?

        init(_ store: Store<Item>) {
            self.store = store
        }
    }

}
