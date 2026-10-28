extension Store {
    /// An invalidation strategy for a `Store` instance.
    ///
    /// An `ItemRemovalStrategy` provides control over how items are removed from the `Store`
    /// and `StorageEngine` cache when you are inserting new items into the `Store`.
    ///
    /// This type used to be used publicly but now it's only used internally.
    /// The built-in strategies are `.all` and `.items(_:)`.
    struct ItemRemovalStrategy<RemovedItem: Codable> {
        enum RemovalScope {
            case selectedItems
            case allStoredItems
        }

        let removalScope: RemovalScope
        var removedItems: ([RemovedItem]) -> [RemovedItem]

        init(removalScope: RemovalScope = .selectedItems, removedItems: @escaping ([RemovedItem]) -> [RemovedItem]) {
            self.removalScope = removalScope
            self.removedItems = removedItems
        }

        /// Removes all of the items from the in-memory and the StorageEngine cache before saving new items.
        ///
        /// This also clears stored records that are absent from the Store's in-memory cache.
        static var all: ItemRemovalStrategy {
            ItemRemovalStrategy(removalScope: .allStoredItems, removedItems: { $0 })
        }

        /// Removes the specific items you provide from the `Store` and disk cache before saving new items.
        ///
        /// - Parameter itemsToRemove: The items being removed.
        /// - Returns: A `ItemRemovalStrategy` where the items provided are removed
        /// from the `Store` and disk cache before saving new items.
        static func items(_ itemsToRemove: [RemovedItem]) -> ItemRemovalStrategy {
            ItemRemovalStrategy(removedItems: { _ in itemsToRemove })
        }
    }
}
