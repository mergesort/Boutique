/// An event associated with an operation performed on a ``Store``.
///
/// `StoreEvent` provides a way to observe specific operations that occur on a ``Store``,
/// including when it's initialized, loaded, and when items are inserted or removed.
/// Each event includes the operation type and the items affected by that operation.
///
/// You can observe these events using the ``Store/events`` property, like so:
///
/// ```swift
/// func monitorStoreEvents() async {
///     for await event in store.events {
///         switch event.operation {
///         case .initialized:
///             print("Store has initialized")
///         case .loaded:
///             print("Store has loaded with items", event.items)
///         case .insert:
///             print("Store inserted items", event.items)
///         case .remove:
///             print("Store removed items", event.items)
///         }
///     }
/// }
/// ```
public struct StoreEvent<Item: StorableItem>: StorableItem {
    /// The type of operation that occurred on the ``Store`` through a ``StoreEvent``.
    public let operation: Operation
    
    /// The items affected by the operation.
    /// For `.initialized`, this will be an empty array.
    /// For `.loaded`, this will contain all items loaded from storage.
    /// For `.insert`, this will contain the newly inserted items.
    /// For `.remove`, this will contain the removed items.
    public let items: [Item]

    /// The type of operation that can occur on a ``Store``.
    public enum Operation: StorableItem {
        /// The ``Store`` has been initialized but items have not yet been loaded.
        case initialized
        
        /// The ``Store`` has loaded its items from storage.
        case loaded
        
        /// Items have been inserted into the ``Store``.
        case insert
        
        /// Items have been removed from the ``Store``.
        case remove
    }
}

internal extension StoreEvent {
    static var initial: StoreEvent<Item> {
        StoreEvent(operation: .initialized, items: [])
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
