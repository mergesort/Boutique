import Foundation

public extension Store {

    /// An invalidation strategy for a `Store` instance.
    ///
    /// A StoredItemsInvalidationStrategy provides control over how old items in the `Store`
    /// and disk cache are handled when new items are added to the `Store`.
    ///
    /// There are a handful of provided strategies provided, `.removeNone`, `.removeAll`,
    /// `.remove(items:)`, and `.remove(where:)`. Because these are defined as structs
    /// rather than an enum, you are able to extend `CacheInvalidationStrategy` to define your own strategies.
    ///
    /// If you are downloading completely new data from the server and want to replace the current cache,
    /// a good strategy to choose would be `removeAll` to remove stale data.
    ///
    /// If your changes are purely additive[^1] such as a new message being added to a group chat,
    /// then you can use `removeNone`, that way old messages are not cleared out when caching new ones.
    ///
    /// If you'd like to build your own caching/removal policy, then `remove(items:)` or `remove(where:)`
    /// are appropriate policies, they give you additional control over which items remain and which are evicted.
    /// An example of this would be if you shipped a bug that corrupted models and want to overwrite them,
    /// but not remove all of videos that were cached in that time.
    ///
    /// If you need inspiration, here's a policy that will remove all animals that aren't household pets.
    ///
    /// ```
    /// private extension Store.CacheInvalidationStrategy {
    ///    static var removeAllWildAnimals: Store.CacheInvalidationStrategy<BoutiqueItem> {
    ///        return CacheInvalidationStrategy(
    ///            invalidatedItems: { items in
    ///                items.filter({ $0.name == "dog" || $0.name == "cat" || $0.name == "hedgehog" })
    ///            }
    ///        )
    ///    }
    /// }
    /// ```
    ///
    /// Even if you make additive changes with a policy like `removeNone` or `removeItems`,
    /// if you cache a new version of an item with the same `cacheIdentifier`, the new item
    /// will replace the old item since you can only have one item per `cacheIdentifier`.
    struct CacheInvalidationStrategy<Item: Codable & Equatable> {

        public init(invalidatedItems: @escaping ([Item]) -> [Item]) { self.invalidatedItems = invalidatedItems }

        /// An invalidation strategy that removes no items, generally the default.
        public static var removeNone: CacheInvalidationStrategy {
            CacheInvalidationStrategy(
                invalidatedItems: { _ in [] }
            )
        }

        /// Removes all of the items from the in-memory and disk cache before saving new items.
        public static var removeAll: CacheInvalidationStrategy {
            CacheInvalidationStrategy(
                invalidatedItems: { $0 }
            )
        }

        /// Removes a specific set of items from the `Store` and disk cache before saving new items.
        /// - Parameter itemsToRemove: The items being removed
        /// - Returns: A `CacheInvalidationStrategy` where the items provided are removed
        /// from the `Store` and disk cache before saving new items.
        public static func remove(items itemsToRemove: [Item]) -> CacheInvalidationStrategy {
            CacheInvalidationStrategy(
                invalidatedItems: { _ in itemsToRemove }
            )
        }


        /// Removes items from the `Store` and disk cache based on a provided predicate before saving new items.
        /// - Parameter predicate: The predicate to query for which items should be removed from the `Store` and disk cache.
        /// - Returns: A `CacheInvalidationStrategy` where the predicate removes items
        /// from the `Store` and disk cache before saving new items.
        public static func remove(where predicate: @escaping (Item) -> Bool) -> CacheInvalidationStrategy<Item> {
            CacheInvalidationStrategy(
                invalidatedItems: { items in
                    items.filter { !predicate($0) }
                }
            )
        }

        public var invalidatedItems: ([Item]) -> [Item]
    }

}
