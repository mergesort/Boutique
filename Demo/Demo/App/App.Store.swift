import Boutique

extension Store where Item == RemoteImage {

    /// The app's default images store`.
    ///
    /// Stores are low-cost and can be plugged into Controllers interchangeably, or even accessed independently.
    /// What does this mean? We decouple Controllers from Stores so if you want one global store for images
    /// you want cached and accessible throughout the app, you can have that. Or if you want to create many
    /// small or even temp stores, that's perfectly fine too, in fact that makes it great for testing.
    static let imagesStore = Store<RemoteImage>(
        storage: SQLiteStorageEngine.default(appendingPath: "Images")
    )
}
