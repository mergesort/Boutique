import Combine

@propertyWrapper
struct Stored<Object: Codable & Equatable> {

    private let box: Box

    init(in store: Store<Object>) {
        self.box = Box(store)
    }

    @MainActor
    var wrappedValue: [Object] {
        box.store.items
    }

    var projectedValue: Store<Object> {
        box.store
    }

    @MainActor static subscript<Instance: ObservableObject>(
        _enclosingInstance instance: Instance,
        wrapped wrappedKeyPath: KeyPath<Instance, [Object]>,
        storage storageKeyPath: KeyPath<Instance, Stored>
    ) -> [Object] where Instance.ObjectWillChangePublisher == ObservableObjectPublisher {
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

extension Stored {

    private class Box {
        let store: Store<Object>
        var cancellable: AnyCancellable?

        init(_ store: Store<Object>) {
            self.store = store
        }
    }

}
