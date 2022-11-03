@_exported import Bodega
import OrderedCollections
import Foundation

/// A fancy persistence layer.
///
/// A ``Store`` for your app which provides you a dual-layered data architecture with a very simple API.
/// The ``Store`` exposes a `@Published` property for your data, which allows you to read it's data synchronously
/// using `store.items`, or subscribe to `store.$items` reactively for real-time changes and updates.
///
/// Under the hood the ``Store`` is doing the work of saving all changes to a persistence layer
/// when you insert or remove items, which allows you to build an offline-first app
/// for free, all inclusive, *no extra code required*.
///
/// **How The Store Works**
///
/// A ``Store`` is a higher level abstraction than Bodega's `ObjectStorage`, containing and leveraging
/// an in-memory store, the ``items`` array, and a `StorageEngine` for it's persistence layer.
///
/// The `StorageEngine` you initialize a ``Store`` with (such as `DiskStorageEngine` or `SQLiteStorageEngine`)
/// will be where items are stored permanently. If you do not provide a `StorageEngine` parameter
/// then the ``Store`` will default to using an Bodega's SQLiteStorageEngine with a database
/// located in the app's `defaultStorageDirectory`, in a "Data" subdirectory.
///
/// As a user you will always be interacting with the ``Store``s memory layer,
/// represented by the ``Store``'s array of ``items``. This means after initializing a ``Store``
/// with a `StorageEngine` you never have to think about how the data is being saved.
///
/// The `SQLiteStorageEngine` is a safe, fast, and easy database to based on SQLite, a great default!
///
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
public final class Store<Item: Codable & Equatable>: ObservableObject {

    private let storageEngine: StorageEngine
    private let cacheIdentifier: KeyPath<Item, String>

    /// The items held onto by the ``Store``.
    ///
    /// The user can read the state of ``items`` at any time
    /// or subscribe to it however they wish, but you desire making modifications to ``items``
    /// you must use ``insert(_:)-7z2oe``, ``remove(_:)-3nzlq``, or ``removeAll()-9zfmy``.
    @MainActor @Published public private(set) var items: [Item] = []

    /// Initializes a new ``Store`` for persisting items to a memory cache
    /// and a storage engine, to act as a source of truth.
    ///
    /// - Parameters:
    ///   - storage: A `StorageEngine` to initialize a ``Store`` instance with.
    ///   - cacheIdentifier: A `KeyPath` from the `Item` pointing to a `String`, which the ``Store``
    ///   will use to create a unique identifier for the item when it's saved.
    public init(storage: StorageEngine, cacheIdentifier: KeyPath<Item, String>) {
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
    ///
    /// When an item is inserted with the same `cacheIdentifier` as an item that already exists in the ``Store``
    /// the item being inserted will replace the item in the ``Store``. You can think of the ``Store`` as a bag
    /// of items, removing complexity when it comes to managing items, indices, and more,
    /// but it also means you need to choose well thought out and uniquely identifying `cacheIdentifier`s.
    /// - Parameters:
    ///   - item: The item you are adding to the ``Store``.
    /// - Returns: An ``Operation`` that can be used to add an item as part of a chain.
    @_disfavoredOverload
    @available(
        *, deprecated,
         renamed: "insert",
         message: "This method is functionally equivalent to `insert` and will be removed in v3. After using Boutique in practice for a while I decided that insert was a more semantically correct name for this operation on a Store, if you'd like to learn more you can see the discussion here. https://github.com/mergesort/Boutique/discussions/36"
    )
    public func add(_ item: Item) async throws -> Operation {
        let operation = Operation(store: self)
        return try await operation.insert(item)
    }

    /// Inserts an item into the store.
    ///
    /// When an item is inserted with the same `cacheIdentifier` as an item that already exists in the ``Store``
    /// the item being inserted will replace the item in the ``Store``. You can think of the ``Store`` as a bag
    /// of items, removing complexity when it comes to managing items, indices, and more,
    /// but it also means you need to choose well thought out and uniquely identifying `cacheIdentifier`s.
    /// - Parameters:
    ///   - item: The item you are inserting into the ``Store``.
    /// - Returns: An ``Operation`` that can be used to insert an item as part of a chain.
    @_disfavoredOverload
    public func insert(_ item: Item) async throws -> Operation {
        let operation = Operation(store: self)
        return try await operation.insert(item)
    }

    /// Adds an item to the ``Store``.
    ///
    /// When an item is inserted with the same `cacheIdentifier` as an item that already exists in the ``Store``
    /// the item being inserted will replace the item in the ``Store``. You can think of the ``Store`` as a bag
    /// of items, removing complexity when it comes to managing items, indices, and more,
    /// but it also means you need to choose well thought out and uniquely identifying `cacheIdentifier`s.
    /// - Parameters:
    ///   - item: The item you are adding to the ``Store``.
    @available(
        *, deprecated,
         renamed: "insert",
         message: "This method is functionally equivalent to `insert` and will be removed in v3. After using Boutique in practice for a while I decided that insert was a more semantically correct name for this operation on a Store, if you'd like to learn more you can see the discussion here. https://github.com/mergesort/Boutique/discussions/36"
    )
    public func add(_ item: Item) async throws {
        try await self.performInsert(item)
    }

    /// Inserts an item into the ``Store``.
    ///
    /// When an item is inserted with the same `cacheIdentifier` as an item that already exists in the ``Store``
    /// the item being inserted will replace the item in the ``Store``. You can think of the ``Store`` as a bag
    /// of items, removing complexity when it comes to managing items, indices, and more,
    /// but it also means you need to choose well thought out and uniquely identifying `cacheIdentifier`s.
    /// - Parameters:
    ///   - item: The item you are inserting into the ``Store``.
    public func insert(_ item: Item) async throws {
        try await self.performInsert(item)
    }

    /// Adds an array of items to the ``Store``.
    ///
    /// Prefer adding multiple items using this method instead of calling ``add(_:)-1ausm``
    /// multiple times to avoid making multiple separate dispatches to the `@MainActor`.
    /// - Parameters:
    ///   - items: The items to add to the store.
    /// - Returns: An ``Operation`` that can be used to add items as part of a chain.
    @_disfavoredOverload
    @available(
        *, deprecated,
        renamed: "insert",
        message: "This method is functionally equivalent to `insert` and will be removed in v3. After using Boutique in practice for a while I decided that insert was a more semantically correct name for this operation on a Store, if you'd like to learn more you can see the discussion here. https://github.com/mergesort/Boutique/discussions/36"
    )
    public func add(_ items: [Item]) async throws -> Operation {
        let operation = Operation(store: self)
        return try await operation.insert(items)
    }

    /// Inserts an array of items into the ``Store``.
    ///
    /// Prefer inserting multiple items using this method instead of calling ``insert(_:)-7z2oe``
    /// multiple times to avoid making multiple separate dispatches to the `@MainActor`.
    /// - Parameters:
    ///   - items: The items to insert into the store.
    /// - Returns: An ``Operation`` that can be used to insert items as part of a chain.
    @_disfavoredOverload
    public func insert(_ items: [Item]) async throws -> Operation {
        let operation = Operation(store: self)
        return try await operation.insert(items)
    }

    /// Adds an array of items to the ``Store``.
    ///
    /// Prefer adding multiple items using this method instead of calling ``insert(_:)-7z2oe``
    /// multiple times to avoid making multiple separate dispatches to the `@MainActor`.
    /// - Parameters:
    ///   - items: The items to add to the store.
    @available(
        *, deprecated,
         renamed: "insert",
         message: "This method is functionally equivalent to `insert` and will be removed in v3. After using Boutique in practice for a while I decided that insert was a more semantically correct name for this operation on a Store, if you'd like to learn more you can see the discussion here. https://github.com/mergesort/Boutique/discussions/36"
    )
    public func add(_ items: [Item]) async throws {
        try await self.performInsert(items)
    }

    /// Inserts an array of items into the ``Store``.
    ///
    /// Prefer inserting multiple items using this method instead of calling ``insert(_:)-3j9hw``
    /// multiple times to avoid making multiple separate dispatches to the `@MainActor`.
    /// - Parameters:
    ///   - items: The items to insert into the store.
    public func insert(_ items: [Item]) async throws {
        try await self.performInsert(items)
    }

    /// Removes an item from the ``Store``.
    /// - Parameter item: The item you are removing from the ``Store``.
    /// - Returns: An ``Operation`` that can be used to remove an item as part of a chain.
    @_disfavoredOverload
    public func remove(_ item: Item) async throws -> Operation {
        let operation = Operation(store: self)
        return try await operation.remove(item)
    }

    /// Removes an item from the ``Store``.
    /// - Parameter item: The item you are removing from the ``Store``.
    public func remove(_ item: Item) async throws {
        try await self.performRemove(item)
    }

    /// Removes a list of items from the ``Store``.
    ///
    /// Prefer removing multiple items using this method instead of calling ``remove(_:)-51ya6``
    /// multiple times to avoid making multiple separate dispatches to the `@MainActor`.
    /// - Parameter items: The items you are removing from the ``Store``.
    /// - Returns: An ``Operation`` that can be used to remove items as part of a chain.
    @_disfavoredOverload
    public func remove(_ items: [Item]) async throws -> Operation {
        let operation = Operation(store: self)
        return try await operation.remove(items)
    }

    /// Removes a list of items from the ``Store``.
    ///
    /// Prefer removing multiple items using this method instead of calling ``remove(_:)-5dwyv``
    /// multiple times to avoid making multiple separate dispatches to the `@MainActor`.
    /// - Parameter items: The items you are removing from the ``Store``.
    public func remove(_ items: [Item]) async throws {
        try await self.performRemove(items)
    }

    /// Removes all items from the store's memory cache and storage engine.
    ///
    /// A separate method you should use when removing all data rather than calling
    /// ``remove(_:)-1w3lx`` or ``remove(_:)-51ya6`` multiple times.
    /// This method handles removing all of the data in one operation rather than iterating over every item
    /// in the ``Store``, avoiding multiple dispatches to the `@MainActor`, with far better performance.
    /// - Returns: An ``Operation`` that can be used to remove items as part of a chain.
    @_disfavoredOverload
    public func removeAll() async throws -> Operation {
        let operation = Operation(store: self)
        return try await operation.removeAll()
    }

    /// Removes all items from the store's memory cache and storage engine.
    ///
    /// A separate method you should use when removing all data rather than calling
    /// ``remove(_:)-5dwyv`` or ``remove(_:)-3nzlq`` multiple times.
    /// This method handles removing all of the data in one operation rather than iterating over every item
    /// in the ``Store``, avoiding multiple dispatches to the `@MainActor`, with far better performance.
    public func removeAll() async throws {
        try await self.performRemoveAll()
    }

}

#if DEBUG
public extension Store {

    /// A ``Store`` to be used for SwiftUI Previews and only SwiftUI Previews!
    ///
    /// This version of a ``Store`` allows you to pass in the ``items`` you would like to render
    /// in a SwiftUI Preview. It will create a a ``Store`` that **only** holds items in memory
    /// so it should not be used in production, nor will it compile for Release builds.
    ///
    /// - Parameters:
    ///   - items: The items that the ``Store`` will be initialized with.
    ///   - cacheIdentifier: A `KeyPath` from the `Item` pointing to a `String`, which the ``Store``
    ///   will use to create a unique identifier for the item when it's saved.
    /// - Returns: A ``Store`` that populates items in memory so you can pass a ``Store`` to @``Stored`` in SwiftUI Previews.
    static func previewStore(items: [Item], cacheIdentifier: KeyPath<Item, String>) -> Store<Item> {
        let store = Store(
            storage: SQLiteStorageEngine(directory: .temporary(appendingPath: "Previews"))!, // No files are written to disk
            cacheIdentifier: cacheIdentifier
        )

        Task.detached { @MainActor in
            store.items = items
        }

        return store
    }

}
#endif

// Internal versions of the `insert`, `remove`, and `removeAll` function code pths so we can avoid duplicating code.
internal extension Store {

    func performInsert(_ item: Item, firstRemovingExistingItems existingItemsStrategy: ItemRemovalStrategy<Item>? = nil) async throws {
        var currentItems = await self.items

        if let strategy = existingItemsStrategy {
            // Remove items from disk and memory based on the cache invalidation strategy
            try await self.removeItems(withStrategy: strategy, items: &currentItems)
        }

        // Take the current items array and turn it into an OrderedDictionary.
        let identifier = item[keyPath: self.cacheIdentifier]
        let currentItemsKeys = currentItems.map({ $0[keyPath: self.cacheIdentifier] })
        var currentValuesDictionary = OrderedDictionary<String, Item>(uniqueKeys: currentItemsKeys, values: currentItems)
        currentValuesDictionary[identifier] = item

        // We persist only the newly added items, rather than rewriting all of the items
        try await self.persistItem(item)

        await MainActor.run { [currentValuesDictionary] in
            self.items = Array(currentValuesDictionary.values)
        }
    }

    func performInsert(_ items: [Item], firstRemovingExistingItems existingItemsStrategy: ItemRemovalStrategy<Item>? = nil) async throws {
        var currentItems = await self.items

        if let strategy = existingItemsStrategy {
            // Remove items from disk and memory based on the cache invalidation strategy
            try await self.removeItems(withStrategy: strategy, items: &currentItems)
        }

        var insertedItemsDictionary = OrderedDictionary<String, Item>()

        // Deduplicate items passed into `insert(items:)` by taking advantage
        // of the fact that an OrderedDictionary can't have duplicate keys.
        for item in items {
            let identifier = item[keyPath: self.cacheIdentifier]
            insertedItemsDictionary[identifier] = item
        }

        // Take the current items array and turn it into an OrderedDictionary.
        let currentItemsKeys = currentItems.map({ $0[keyPath: self.cacheIdentifier] })
        var currentValuesDictionary = OrderedDictionary<String, Item>(uniqueKeys: currentItemsKeys, values: currentItems)

        // Add the new items into the dictionary representation of our items.
        for item in insertedItemsDictionary {
            let identifier = item.value[keyPath: self.cacheIdentifier]
            currentValuesDictionary[identifier] = item.value
        }

        // We persist only the newly added items, rather than rewriting all of the items
        try await self.persistItems(Array(insertedItemsDictionary.values))

        await MainActor.run { [currentValuesDictionary] in
            self.items = Array(currentValuesDictionary.values)
        }
    }

    func performRemove(_ item: Item) async throws {
        try await self.removePersistedItem(item)

        let cacheKeyString = item[keyPath: self.cacheIdentifier]
        let itemKeys = Set([cacheKeyString])

        await MainActor.run {
            self.items.removeAll(where: { item in
                itemKeys.contains(item[keyPath: self.cacheIdentifier])
            })
        }
    }

    func performRemove(_ items: [Item]) async throws {
        let itemKeys = Set(items.map({ $0[keyPath: self.cacheIdentifier] }))

        try await self.removePersistedItems(items: items)

        await MainActor.run {
            self.items.removeAll(where: { item in
                itemKeys.contains(item[keyPath: self.cacheIdentifier])
            })
        }
    }

    func performRemoveAll() async throws {
        try await self.storageEngine.removeAllData()

        await MainActor.run {
            self.items = []
        }
    }

}

private extension Store {

    func persistItem(_ item: Item) async throws {
        let cacheKey = CacheKey(item[keyPath: self.cacheIdentifier])
        let encoder = JSONEncoder()

        try await self.storageEngine.write(try encoder.encode(item), key: cacheKey)
    }

    func persistItems(_ items: [Item]) async throws {
        let itemKeys = items.map({ CacheKey($0[keyPath: self.cacheIdentifier]) })
        let encoder = JSONEncoder()
        let dataAndKeys = try zip(itemKeys, items)
            .map({ (key: $0, data: try encoder.encode($1)) })

        try await self.storageEngine.write(dataAndKeys)
    }

    func removePersistedItem(_ item: Item) async throws {
        let cacheKey = CacheKey(item[keyPath: self.cacheIdentifier])
        try await self.storageEngine.remove(key: cacheKey)
    }

    func removePersistedItems(items: [Item]) async throws {
        let itemKeys = items.map({ CacheKey($0[keyPath: self.cacheIdentifier]) })
        try await self.storageEngine.remove(keys: itemKeys)
    }

    func removeItems(withStrategy strategy: ItemRemovalStrategy<Item>, items: inout [Item]) async throws {
        let itemsToRemove = strategy.removedItems(items)

        // If we're using the `.removeNone` strategy then there are no items to invalidate and we can return early
        guard itemsToRemove.count != 0 else { return }

        // If we're using the `.removeAll` strategy then we want to remove all the data without iterating
        // Else, we're using a strategy and need to iterate over all of the `itemsToInvalidate` and invalidate them
        if items.count == itemsToRemove.count {
            items = []
            try await self.storageEngine.removeAllData()
        } else {
            items = items.filter { !itemsToRemove.contains($0) }
            let itemKeys = items.map({ CacheKey(verbatim: $0[keyPath: self.cacheIdentifier]) })

            if itemKeys.count == 1 {
                try await self.storageEngine.remove(key: itemKeys[0])
            } else {
                try await self.storageEngine.remove(keys: itemKeys)
            }
        }
    }

}
