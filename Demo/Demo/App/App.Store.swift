import Boutique

extension Store where Item == RemoteImage {
    /// The app's default images store`.
    ///
    /// Stores are low-cost and can be plugged into Controllers interchangeably, or even accessed independently.
    /// What does this mean? We decouple Controllers from Stores so if you want one global store for images
    /// you want cached and accessible throughout the app, you can have that. Or if you want to create many
    /// small or even temp stores, that's perfectly fine too, in fact that makes it great for testing.
    ///
    /// Stores are initialized with a `StorageEngine`, the data source that will be persisting your data.
    /// We're using one of the two `StorageEngine`s provided by Bodega, the `SQLiteStorageEngine`.
    /// The `SQLiteStorageEngine` is a safe, fast, and easy database to based on SQLite, a great default!
    ///
    /// Another built-in `StorageEngine` you can use is the `DiskStorageEngine`, a `StorageEngine`
    /// based on storing items as files on the file system. The ``DiskStorageEngine`` prioritizes
    /// simplicity over speed, it is very easy to use and understand.
    ///
    /// What's super cool about the `StorageEngine` protocol is that you can conform to it
    /// to integrate your own persistence layer into Boutique. If you're using Realm, Core Data, CloudKit,
    /// or even your own API server, you can model them as a `StorageEngine` to use in a `Store`.
    ///
    /// This will enable you to have a realtime updating app just like any other Boutique-based app,
    /// but with your very own data layer. You can even endlessly compose `StorageEngine`s to create a
    /// complex data pipeline that hits your API and saves items into a database, all in one API call.
    static let imagesStore = Store<RemoteImage>(
        storage: SQLiteStorageEngine.default(appendingPath: "Images")
    )
}
