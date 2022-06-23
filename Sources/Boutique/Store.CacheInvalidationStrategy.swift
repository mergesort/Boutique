import Foundation

public extension Store {

    /// An invalidation strategy for a `Store` instance.
    ///
    /// ## Discussion
    /// 
    /// A CacheInvalidationStrategy provides control over how old objects in the `Store`
    /// and disk cache are handled when new objects are added to the `Store`.
    ///
    /// If you are downloading completely new data from the server and want to replace the current cache,
    /// a good strategy to choose would be `removeAll` to remove stale data.
    ///
    /// If your changes are purely additive[^1] such as a new message being added to a group chat,
    /// then you can use `removeNone`, that way old messages are not cleared out when caching new ones.
    ///
    /// If you'd like to build your own caching/removal policy, then `remove(items:)` is an appropriate policy.
    /// This gives you additional control over which objects remain and which are evicted.
    /// An example of this would be if you shipped a bug that corrupted models and want to overwrite them,
    /// but not remove all of videos that were cached in that time.
    /// (Get creative and create your own higher level strategies!)
    ///
    /// Even if you make additive changes with a policy like `removeNone` or `removeItems`,
    /// if you cache a new version of an object with the same `cacheIdentifier`, the new object will replace the old item
    /// since you can only have one object per `cacheIdentifier`.
    enum CacheInvalidationStrategy<Object> {
        /// Removes no objects from the `Store` and disk cache, ostensibly a no-op.
        case removeNone

        /// Removes a specific set of objects from the `Store` and disk cache before saving new objects.
        case remove(items: [Object])

        /// Removes all of the objects from the in-memory and disk cache before saving new objects.
        case removeAll
    }

}
