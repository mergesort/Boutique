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

    @MainActor public static subscript<Instance: ObservableObject>(
        _enclosingInstance instance: Instance,
        wrapped wrappedKeyPath: KeyPath<Instance, [Item]>,
        storage storageKeyPath: KeyPath<Instance, Stored>
    ) -> [Item] where Instance.ObjectWillChangePublisher == ObservableObjectPublisher {
        let wrapper = instance[keyPath: storageKeyPath]

        if wrapper.box.cancellable == nil {
            wrapper.box.cancellable = wrapper.projectedValue
                .objectWillChange
                .sink(receiveValue: { [objectWillChange = instance.objectWillChange] in
                    objectWillChange.send()
                })
        }

        return wrapper.wrappedValue
    }
}

private extension Stored {

    class Box {
        let store: Store<Item>
        var cancellable: AnyCancellable?

        init(_ store: Store<Item>) {
            self.store = store
        }
    }

}
