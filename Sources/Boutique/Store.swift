import Bodega
import Combine
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
    private var cancellables = Set<AnyCancellable>()

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
        self.objectStorage = ObjectStorage(storagePath: storagePath)
        self.cacheIdentifier = cacheIdentifier

        Task { @MainActor in
            self.items = await self.allPersistedItems()
        }
    }

    /// Adds an item to the store.
    /// - Parameters:
    ///   - item: The item you are adding to the `Store`.
    ///   - invalidationStrategy: An optional `CacheInvalidationStrategy` you can provide when adding an item
    ///   defaulting to `.removeNone`.
    public func add(_ item: Item, invalidationStrategy: CacheInvalidationStrategy<Item> = .removeNone) async throws {
        try await self.add([item], invalidationStrategy: invalidationStrategy)
    }

    /// Adds a list of items to the store.
    ///
    /// Prefer adding multiple items using this method instead of calling multiple times
    /// ``add(_:invalidationStrategy:)-5y90k`` in succession to avoid making multiple separate dispatches to the `@MainActor`.
    /// - Parameters:
    ///   - items: The items to add to the store.
    ///   - invalidationStrategy: An optional invalidation strategy for this add operation.
    public func add(_ items: [Item], invalidationStrategy: CacheInvalidationStrategy<Item> = .removeNone) async throws {
        var updatedItems: [Item] = await self.items

        try await self.removePersistedItems(strategy: invalidationStrategy)
        self.invalidateCache(strategy: invalidationStrategy, items: &updatedItems)

        // Prevent duplicate values from being written multiple times.
        // This could cause a discrepancy between the data in memory
        // and on disk since files on the file system can't have
        // duplicate filenames but can be duplicated in memory.
        let uniqueItems = items.uniqueElements(matching: self.cacheIdentifier)
        var itemKeys = uniqueItems.map({ $0[keyPath: self.cacheIdentifier] })

        for item in uniqueItems {
            if let matchingIdentifierIndex = itemKeys.firstIndex(of: item[keyPath: self.cacheIdentifier]),
               case let matchingIdentifier = itemKeys[matchingIdentifierIndex],
               let index = updatedItems.firstIndex(where: { $0[keyPath: self.cacheIdentifier] == matchingIdentifier }) {
                    // We found a matching element with potentially different data so replace it in-place
                    updatedItems.remove(at: index)
                    updatedItems.insert(item, at: index)
                } else {
                    // Append it to the cache if it doesn't already exist
                    updatedItems.append(item)
                }

            itemKeys.removeAll(where: { $0 == item[keyPath: self.cacheIdentifier] })
        }

        try await self.persistItems(updatedItems)

        // We can't capture a mutable array (updatedItems) in the closure below so we make an immutable copy.
        // An implicitly captured closure variable is captured by reference while
        // a variable captured in the capture group is captured by value.
        await MainActor.run { [updatedItems] in
            self.items = updatedItems
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
        let itemKeys = items.map({ $0[keyPath: self.cacheIdentifier] })

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
        let itemKeys = items.map({ $0[keyPath: self.cacheIdentifier] })
            .map({ CacheKey($0) })

        for cacheKey in itemKeys {
            try await self.objectStorage.removeObject(forKey: cacheKey)
        }
    }

    func removeAllPersistedItems() async throws {
        try await self.objectStorage.removeAllObjects()
    }

    func invalidateCache(strategy: CacheInvalidationStrategy<Item>, items: inout [Item]) {
        switch strategy {

        case .removeNone:
            break

        case .remove(let itemsToRemove):
            items = items.filter({ !itemsToRemove.contains($0) })

        case .removeAll:
            items = []

        }
    }

    func removePersistedItems(strategy: CacheInvalidationStrategy<Item>) async throws {
        switch strategy {

        case .removeNone:
            break

        case .remove(let itemsToRemove):
            try await self.remove(itemsToRemove)

        case .removeAll:
            try await self.removeAllPersistedItems()

        }
    }

}

private extension Array where Element: Equatable {

    func uniqueElements(matching keyPath: KeyPath<Element, String>) -> [Element] {
        var result = [Element]()

        for element in self {
            if !result.contains(where: { $0[keyPath: keyPath] == element[keyPath: keyPath] }) {
                result.append(element)
            }
        }

        return result
    }

}
