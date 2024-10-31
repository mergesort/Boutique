import Foundation

extension Store {
    /// An invalidation strategy for a `Store` instance.
    ///
    /// An `ItemRemovalStrategy` provides control over how items are removed from the `Store`
    /// and `StorageEngine` cache when you are inserting new items into the `Store`.
    ///
    /// This type used to be used publicly but now it's only used internally. As a result you
    /// can no longer construct your own strategies, only `.all` and `.items(_:)` remain.

    struct ItemRemovalStrategy<RemovedItem: Codable> {
        public init(removedItems: @escaping ([RemovedItem]) -> [RemovedItem]) { self.removedItems = removedItems }

        public var removedItems: ([RemovedItem]) -> [RemovedItem]

        /// Removes all of the items from the in-memory and the StorageEngine cache before saving new items.
        internal static var all: ItemRemovalStrategy {
            ItemRemovalStrategy(removedItems: { $0 })
        }

        /// Removes the specific items you provide from the `Store` and disk cache before saving new items.
        /// 
        /// - Parameter itemsToRemove: The items being removed.
        /// - Returns: A `ItemRemovalStrategy` where the items provided are removed
        /// from the `Store` and disk cache before saving new items.
        internal static func items(_ itemsToRemove: [RemovedItem]) -> ItemRemovalStrategy {
            ItemRemovalStrategy(removedItems: { _ in itemsToRemove })
        }
    }
}
