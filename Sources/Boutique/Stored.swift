import Observation

/// The @``Stored`` property wrapper to automagically initialize a ``Store``.
@MainActor
@propertyWrapper
public struct Stored<Item: Codable & Sendable> {
    private let store: Store<Item>

    /// Initializes a @``Stored`` property that will be exposed as an `[Item]` and project a `Store<Item>`.
    /// - Parameter store: The store that will be wrapped to expose as an array.
    public init(in store: Store<Item>) {
        self.store = store
    }

    /// The currently stored items
    public var wrappedValue: [Item] {
        self.store.items
    }

    public var projectedValue: Store<Item> {
        self.store
    }
}
