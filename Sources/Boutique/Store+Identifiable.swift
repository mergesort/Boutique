import Foundation

public extension Store where Item: Identifiable, Item.ID == String {

    /// Initializes a fresh `Store` with a memory cache (represented by `items`), and a disk cache. Previus state is not automatically restored.
    /// This initializer eschews providing a `cacheIdentifier` when our `Object` conforms to `Identifiable`
    /// with a `String` for it's `id`. While it's not required for your `Object` to conform to `Identifiable`,
    /// many SwiftUI-related objects do so this initializer provides a nice convenience.
    /// - Parameter storagePath: A URL representing the folder on disk that your files will be written to.
    convenience init(storagePath: URL) {
        self.init(storagePath: storagePath, cacheIdentifier: \.id)
    }
    
    /// Initializes a fresh `Store` with a memory cache (represented by `items`), and a disk cache, potentially restoring the data from the disk.
    /// This initializer eschews providing a `cacheIdentifier` when our `Object` conforms to `Identifiable`
    /// with a `String` for it's `id`. While it's not required for your `Object` to conform to `Identifiable`,
    /// many SwiftUI-related objects do so this initializer provides a nice convenience.
    /// - Parameter storagePath: A URL representing the folder on disk that your files will be written to.
    convenience init(storagePath: URL, prefetchPersistedItems: Bool) async {
        await self.init(storagePath: storagePath, cacheIdentifier: \.id, prefetchPersistedItems: prefetchPersistedItems)
    }

}
