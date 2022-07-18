import Foundation

public extension Store {

    /// An invalidation strategy for a `Store` instance.
    ///
    /// ## Discussion
    /// 
    /// A CacheInvalidationStrategy provides control over how old items in the `Store`
    /// and disk cache are handled when new items are added to the `Store`.
    ///
    /// If you are downloading completely new data from the server and want to replace the current cache,
    /// a good strategy to choose would be `removeAll` to remove stale data.
    ///
    /// If your changes are purely additive[^1] such as a new message being added to a group chat,
    /// then you can use `removeNone`, that way old messages are not cleared out when caching new ones.
    ///
    /// If you'd like to build your own caching/removal policy, then `remove(items:)` is an appropriate policy.
    /// This gives you additional control over which items remain and which are evicted.
    /// An example of this would be if you shipped a bug that corrupted models and want to overwrite them,
    /// but not remove all of videos that were cached in that time.
    /// (Get creative and create your own higher level strategies!)
    ///
    /// Even if you make additive changes with a policy like `removeNone` or `removeItems`,
    /// if you cache a new version of an item with the same `cacheIdentifier`, the new item will replace the old item
    /// since you can only have one item per `cacheIdentifier`.
    enum CacheInvalidationStrategy<Item> {
        /// Removes no items from the `Store` and disk cache, ostensibly a no-op.
        case removeNone

        /// Removes a specific set of items from the `Store` and disk cache before saving new items.
        case remove(items: [Item])

        /// Removes all of the items from the in-memory and disk cache before saving new items.
        case removeAll
    }

}
