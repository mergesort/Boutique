import Foundation

public extension Store {

    /// An invalidation strategy for a `Store` instance.
    ///
    /// An `ItemRemovalStrategy` provides control over how items are removed from the `Store`
    /// and disk cache when you are adding new items to the `Store`.
    ///
    /// There are a handful of provided strategies provided, `.all`, `.items(_:)`,
    /// and `.items(where:)`. Because these are defined as structs rather than an enum,
    /// you are able to extend `ItemRemovalStrategy` to define your own strategies.
    ///
    /// If you are downloading completely new data from the server and want to replace the current cache,
    /// a good strategy to choose would be `.all` to remove stale data.
    ///
    /// If you'd like to build your own caching/removal policy, then `.items(_:)` or `.items(where:)`
    /// are appropriate policies, they give you additional control over which items remain and which are evicted.
    /// An example of this would be if you shipped a bug that corrupted models and want to overwrite them,
    /// but not remove all of videos that were cached in that time.
    ///
    /// If you need inspiration, here's a policy that will remove all animals that aren't household pets.
    ///
    /// ```
    /// private extension Store.ItemRemovalStrategy {
    ///    static var removeAllWildAnimals: Store.ItemRemovalStrategy<Animal> {
    ///        return ItemRemovalStrategy(
    ///            invalidatedItems: { items in
    ///                items.filter({ $0.name == "dog" || $0.name == "cat" || $0.name == "hedgehog" })
    ///            }
    ///        )
    ///    }
    /// }
    /// ```
    ///
    /// Even if you make additive changes with a policy like `.items(_:)` or `.items(where:)`,
    /// caching a new version of an item with the same `cacheIdentifier` will lead to
    /// the new item replacing the old item since you can only have one item per `cacheIdentifier`.
    struct ItemRemovalStrategy<Item: Codable & Equatable> {

        public init(invalidatedItems: @escaping ([Item]) -> [Item]) { self.invalidatedItems = invalidatedItems }

        public var invalidatedItems: ([Item]) -> [Item]

        /// Removes all of the items from the in-memory and disk cache before saving new items.
        public static var all: ItemRemovalStrategy {
            ItemRemovalStrategy(invalidatedItems: { $0 })
        }

        /// Removes the specific items you provide from the `Store` and disk cache before saving new items.
        /// - Parameter itemsToRemove: The items being removed.
        /// - Returns: A `ItemRemovalStrategy` where the items provided are removed
        /// from the `Store` and disk cache before saving new items.
        public static func items(_ itemsToRemove: [Item]) -> ItemRemovalStrategy {
            ItemRemovalStrategy(invalidatedItems: { _ in itemsToRemove })
        }

        /// Removes items from the `Store` and disk cache based on a provided predicate before saving new items.
        /// - Parameter predicate: The predicate to query for which items should be removed from the `Store` and disk cache.
        /// - Returns: A `ItemRemovalStrategy` where the predicate removes items
        /// from the `Store` and disk cache before saving new items.
        public static func items(where predicate: @escaping (Item) -> Bool) -> ItemRemovalStrategy<Item> {
            ItemRemovalStrategy(
                invalidatedItems: { items in
                    items.filter { !predicate($0) }
                }
            )
        }
    }

}
