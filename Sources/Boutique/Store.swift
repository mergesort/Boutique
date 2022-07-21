import Bodega
import OrderedCollections
import Foundation

/// A general storage persistence layer.
///
/// A `Store` for your app which provides you a dual-layered data architecture with a very simple API.
/// The `Store` exposes a `@Published` property for your data, which allows you to read it's data synchronously
/// using `store.items`, or subscribe to `store.$items` reactively for real-time changes and updates.
///
/// Under the hood the `Store` is doing the work of saving all changes to disk when you add or remove objects,
/// which allows you to build an offline-first app for free, no extra code required.
public final class Store<Item: Codable & Equatable>: ObservableObject {

    private let storagePath: URL
    private let objectStorage: ObjectStorage
    private let cacheIdentifier: KeyPath<Item, String>

    /// The items held onto by the `Store`.
    ///
    /// The user can read the state of `items` at any time
    /// or subscribe to it however they wish, but you desire making modifications to `items`
    /// you must use `.add()`, `.remove()`, or `.removeAll()`.
    @MainActor @Published public private(set) var items: [Item] = []

    /// Initializes a `Store` with a memory cache and a disk cache, uniquely identifying items by the given identifier.
    /// - Parameters:
    ///   - storagePath: A URL representing the folder on disk that your files will be written to.
    ///   - cacheIdentifier: A `KeyPath` from the `Object` pointing to a `String`, which the `Store`
    ///   will use to create a unique identifier for the object when it's saved on disk.
    ///
    ///   Since `cacheIdentifier` is a `KeyPath` rather than a `String`, a good strategy for generating
    ///   a stable and unique `cacheIdentifier` is to conform to `Identifiable` and point to `\.id`.
    ///   That is *not* required though, and you are free to use any `String` property on your `Object`
    ///   or even a type which can be converted into a `String` such as `\.url.path`.
    public init(storagePath: URL, cacheIdentifier: KeyPath<Item, String>) {
        self.storagePath = storagePath
        self.objectStorage = ObjectStorage(directory: FileManager.Directory(url: storagePath))
        self.cacheIdentifier = cacheIdentifier

        Task { @MainActor in
            self.items = await self.allPersistedItems()
        }
    }

    /// Adds an item to the store.
    /// - Parameters:
    ///   - item: The item you are adding to the `Store`.
    ///   - invalidationStrategy: An optional `ItemRemovalStrategy` you can provide when adding an item
    ///   defaulting to nil, meaning no items should be **removed** before adding a new item.
    public func add(_ item: Item, removingExistingItems existingItemsStrategy: ItemRemovalStrategy<Item>? = nil) async throws {
        try await self.add([item], removingExistingItems: existingItemsStrategy)
    }

    /// Adds a list of items to the store.
    ///
    /// Prefer adding multiple items using this method instead of calling multiple times
    /// ``add(_:removingExistingItems:)-40rsm`` in succession to avoid making multiple separate dispatches to the `@MainActor`.
    /// - Parameters:
    ///   - items: The items to add to the store.
    ///   - invalidationStrategy: An optional `ItemRemovalStrategy` you can provide when adding items
    ///   defaulting to nil, meaning no items should be removed **before** adding new items.
    public func add(_ items: [Item], removingExistingItems existingItemsStrategy: ItemRemovalStrategy<Item>? = nil) async throws {
        var currentItems: [Item] = await self.items

        if let strategy = existingItemsStrategy {
            // Remove items from memory and the store based on the cache invalidation strategy
            try await self.invalidateItems(withStrategy: strategy, items: &currentItems)
        }

        var addedItemsDictionary = OrderedDictionary<String, Item>()

        // Deduplicate items passed into `add(items:)` by taking advantage
        // of the fact that an OrderedDictionary can't have duplicate keys.
        for item in items {
            let identifier = item[keyPath: self.cacheIdentifier]
            addedItemsDictionary[identifier] = item
        }

        // Take the current items array and turn it into an OrderedDictionary.
        let currentItemsKeys = currentItems.map({ $0[keyPath: self.cacheIdentifier] })
        var currentValuesDictionary = OrderedDictionary<String, Item>(uniqueKeys: currentItemsKeys, values: currentItems)

        // Add the new items into the dictionary representation of our items.
        for item in addedItemsDictionary {
            let identifier = item.value[keyPath: self.cacheIdentifier]
            currentValuesDictionary[identifier] = item.value
        }

        // We persist only the newly added items, rather than rewriting all of the items
        try await self.persistItems(Array(addedItemsDictionary.values))

        await MainActor.run { [currentValuesDictionary] in
            self.items = Array(currentValuesDictionary.values)
        }
    }

    /// Removes an item from the store.
    /// - Parameter item: The item you are removing from the `Store`.
    public func remove(_ item: Item) async throws {
        try await self.remove([item])
    }

    /// Removes a list of items from the store.
    ///
    /// Prefer removing multiple items using this method
    /// avoid making multiple separate dispatches to the `@MainActor`.
    /// - Parameter item: The items you are removing from the `Store`.
    public func remove(_ items: [Item]) async throws {
        let itemKeys = Set(items.map({ $0[keyPath: self.cacheIdentifier] }))

        try await self.removePersistedItems(items: items)

        await MainActor.run {
            self.items.removeAll(where: { item in
                itemKeys.contains(item[keyPath: self.cacheIdentifier])
            })
        }
    }

    /// Removes all items from the store and disk cache.
    ///
    /// A separate method for performance reasons, handling removal of all data
    /// in one operation rather than iterating over every item in the `Store` and disk cache.
    public func removeAll() async throws {
        try await self.removeAllPersistedItems()

        await MainActor.run {
            self.items = []
        }
    }

}

private extension Store {

    func allPersistedItems() async -> [Item] {
        var items: [Item] = []

        for key in await self.objectStorage.allKeys() {
            if let object: Item = await self.objectStorage.object(forKey: key) {
                items.append(object)
            }
        }

        return items
    }

    func persistItems(_ items: [Item]) async throws {
        for item in items {
            try await self.objectStorage.store(item, forKey: CacheKey(item[keyPath: self.cacheIdentifier]))
        }
    }

    func removePersistedItems(items: [Item]) async throws {
        let itemKeys = items.map({ CacheKey($0[keyPath: self.cacheIdentifier]) })

        for cacheKey in itemKeys {
            try await self.objectStorage.removeObject(forKey: cacheKey)
        }
    }

    func removeAllPersistedItems() async throws {
        try await self.objectStorage.removeAllObjects()
    }

    func invalidateItems(withStrategy strategy: ItemRemovalStrategy<Item>, items: inout [Item]) async throws {
        let itemsToInvalidate = strategy.invalidatedItems(items)

        // If we're using the `.removeNone` strategy then there are no items to invalidate and we can return early
        guard itemsToInvalidate.count != 0 else { return }

        // If we're using the `.removeAll` strategy then we want to remove all the data without iterating
        // Else, we're using a strategy and need to iterate over all of the `itemsToInvalidate` and invalidate them
        if items.count == itemsToInvalidate.count {
            items = []
            try await self.removeAllPersistedItems()
        } else {
            items = items.filter { itemsToInvalidate.contains($0) }
            let itemKeys = items.map({ CacheKey(verbatim: $0[keyPath: self.cacheIdentifier]) })
            for keys in itemKeys {
                try await self.objectStorage.removeObject(forKey: keys)
            }
        }
    }

}
