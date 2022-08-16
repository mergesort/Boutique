// This code is used in `@Stored`, `@StoredValue`, and `@AsyncStoredValue`
// but I gotta be honest I have no idea how this works but it does.
//
// Basically there's a proxy that extracts the nested ObservableObjectPublisher
// but I don't know how it works. You can thank Ian Keen (@iankay on Twitter)
// for this code, he's an absolutely brilliant developer and great guy.

import Combine

protocol ObservableObjectProxy {
    func extractObjectWillChange<T>(_ instance: T) -> ObservableObjectPublisher
}

struct Proxy<Base> {
    func extract<A, B, C>(_ instance: A, _ extract: (Base) -> B) -> C {
        return extract(instance as! Base) as! C
    }
}

extension Proxy: ObservableObjectProxy where Base: ObservableObject, Base.ObjectWillChangePublisher == ObservableObjectPublisher {
    func extractObjectWillChange<T>(_ instance: T) -> ObservableObjectPublisher {
        extract(instance) { $0.objectWillChange }
    }
}
