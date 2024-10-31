/// An event associated with an operation performed a ``Store``.
public struct StoreEvent<Item: StorableItem>: StorableItem {
    public let operation: Operation
    public let items: [Item]

    public enum Operation: StorableItem {
        case initial, loaded, insert, remove
    }
}

internal extension StoreEvent {
    static var initial: StoreEvent<Item> {
        StoreEvent(operation: .initial, items: [])
    }

    static func loaded(_ items: [Item]) -> StoreEvent<Item> {
        StoreEvent(operation: .loaded, items: items)
    }

    static func insert(_ items: [Item]) -> StoreEvent<Item> {
        StoreEvent(operation: .insert, items: items)
    }

    static func remove(_ items: [Item]) -> StoreEvent<Item> {
        StoreEvent(operation: .remove, items: items)
    }
}
