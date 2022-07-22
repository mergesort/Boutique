@_exported import Bodega
import OrderedCollections
import Foundation

/// A general storage persistence layer.
///
/// A `Store` for your app which provides you a dual-layered data architecture with a very simple API.
/// The `Store` exposes a `@Published` property for your data, which allows you to read it's data synchronously
/// using `store.items`, or subscribe to `store.$items` reactively for real-time changes and updates.
///
/// Under the hood the `Store` is doing the work of saving all changes to a persistence layer
/// when you add or remove items, which allows you to build an offline-first app
/// for free, all inclusive, no extra code required.
public final class Store<Item: Codable & Equatable>: ObservableObject {

    private let storageEngine: StorageEngine
    private let cacheIdentifier: KeyPath<Item, String>

    /// The items held onto by the `Store`.
    ///
    /// The user can read the state of `items` at any time
    /// or subscribe to it however they wish, but you desire making modifications to `items`
    /// you must use `.add()`, `.remove()`, or `.removeAll()`.
    @MainActor @Published public private(set) var items: [Item] = []

    /// Initializes a new `Store` for persisting items to a memory cache and a storage engine, acting as a source of truth.
    ///
    /// **How The Store Works**
    ///
    /// A `Store` is a higher level abstraction than ``Bodega/ObjectStorage``, containing and leveraging
    /// an in-memory store, the `items` array, and a `StrorageEngine` for it's persistence layer.
    ///
    /// The `StorageEngine` you initialize a `Store` with (such as `DiskStorageEngine` or `SQLiteStorageEngine`)
    /// will be where items are stored permanently. If you do not provide a `StorageEngine` parameter
    /// then the `Store` will default to using an ``/Bodega/SQLiteStorageEngine`` with a database
    /// located in the app's Documents directory, in a "Data" subdirectory.
    ///
    /// As a user you will always be interacting with the `Store`s memory layer,
    /// represented by the `Store`'s array of `items`. This means after initializing a `Store`
    /// with a `StorageEngine` you never have to think about how the data is being saved.
    ///
    /// The `SQLiteStorageEngine` is a safe, fast, and easy database to based on SQLite, a great default!
    /// **If you prefer to use your own persistence layer or want to save your items
    /// to another location, you can use the `storage` parameter like so**
    /// ```
    /// SQLiteStorageEngine(directory: .documents(appendingPath: "Assets"))
    /// ```
    ///
    /// **How Cache Identifiers Work**
    ///
    /// The `cacheIdentifier` generates a unique `String` representing a key for storing
    /// your item in the underlying persistence layer (the `StorageEngine`).
    ///
    /// The `cacheIdentifier` is `KeyPath` rather than a `String`, a good strategy for generating
    /// a stable and unique `cacheIdentifier` is to conform to `Identifiable` and point to `\.id`.
    /// That is *not* required though, and you are free to use any `String` property on your `Item`
    /// or even a type which can be converted into a `String` such as `\.url.path`.
    ///
    /// - Parameters:
    ///   - storage: A `StorageEngine` to initialize a `Store` instance with.
    ///   If no parameter is provided the default is `SQLiteStorageEngine(directory: .documents(appendingPath: "Data"))`
    ///   - cacheIdentifier: A `KeyPath` from the `Item` pointing to a `String`, which the `Store`
    ///   will use to create a unique identifier for the item when it's saved.
    public init(storage: StorageEngine = SQLiteStorageEngine(directory: .documents(appendingPath: "Data"))!, cacheIdentifier: KeyPath<Item, String>) {
        self.storageEngine = storage
        self.cacheIdentifier = cacheIdentifier

        Task { @MainActor in
            do {
                let decoder = JSONDecoder()
                self.items = try await self.storageEngine.readAllData()
                    .map({ try decoder.decode(Item.self, from: $0) })
            } catch {
                self.items = []
            }
        }
    }

    /// Adds an item to the store.
    /// - Parameters:
    ///   - item: The item you are adding to the `Store`.
    ///   - invalidationStrategy: An optional `CacheInvalidationStrategy` you can provide when adding an item
    ///   defaulting to `.removeNone`.
    public func add(_ item: Item) async throws {
        try await self.add([item])
    }

    /// Adds a list of items to the store.
    ///
    /// Prefer adding multiple items using this method instead of calling multiple times
    /// ``add(_:invalidationStrategy:)-5y90k`` in succession to avoid making multiple separate dispatches to the `@MainActor`.
    /// - Parameters:
    ///   - items: The items to add to the store.
    ///   - invalidationStrategy: An optional invalidation strategy for this add operation.
    public func add(_ items: [Item]) async throws {
        var addedItemsDictionary = OrderedDictionary<String, Item>()

        // Deduplicate items passed into `add(items:)` by taking advantage
        // of the fact that an OrderedDictionary can't have duplicate keys.
        for item in items {
            let identifier = item[keyPath: self.cacheIdentifier]
            addedItemsDictionary[identifier] = item
        }

        // Take the current items array and turn it into an OrderedDictionary.
        let currentItems: [Item] = await self.items
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

    /// Removes all items from the store's memory cache and storage engine.
    ///
    /// A separate method for performance reasons, handling removal of all data
    /// in one operation rather than iterating over every item in the `Store` and `StorageEngine`.
    public func removeAll() async throws {
        try await self.storageEngine.removeAllData()

        await MainActor.run {
            self.items = []
        }
    }

}

private extension Store {

    func persistItems(_ items: [Item]) async throws {
        let itemKeys = items.map({ CacheKey($0[keyPath: self.cacheIdentifier]) })
        let encoder = JSONEncoder()
        let dataAndKeys = try zip(itemKeys, items)
            .map({ (key: $0, data: try encoder.encode($1)) })

        try await self.storageEngine.write(dataAndKeys)
    }

    func removePersistedItems(items: [Item]) async throws {
        let itemKeys = items.map({ CacheKey($0[keyPath: self.cacheIdentifier]) })
        try await self.storageEngine.remove(keys: itemKeys)
    }

}
