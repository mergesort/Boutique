import Foundation

public extension Store where Item: Identifiable, Item.ID == String {

    /// Initializes a new `Store` for persisting items to a memory cache and a storage engine, acting as a source of truth.
    ///
    /// This initializer eschews providing a `cacheIdentifier` when our `Item` conforms to `Identifiable`
    /// with an `id` that is a `String`. While it's not required for your `Item` to conform to `Identifiable`,
    /// many SwiftUI-related objects do so this initializer provides a nice convenience.
    ///
    /// **How The Store Works**
    ///
    /// A `Store` is a higher level abstraction than ``ObjectStorage``, containing and leveraging
    /// an in-memory store, the `items` array, and a ``StorageEngine`` for it's persistence layer.
    ///
    /// The `StorageEngine` you initialize a `Store` with (such as ``DiskStorageEngine`` or ``SQLiteStorageEngine``)
    /// will be where items are stored permanently. If you do not provide a ``StorageEngine`` parameter
    /// then the `Store` will default to using an ``SQLiteStorageEngine`` with a database
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
    /// - Parameter storage: A `StorageEngine` to initialize a `Store` instance with.
    ///   If no parameter is provided the default is `SQLiteStorageEngine(directory: .documents(appendingPath: "data"))`
    convenience init(storage: StorageEngine) {
        self.init(storage: storage, cacheIdentifier: \.id)
    }

}
