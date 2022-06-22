import Bodega
import Foundation

// An extension with common folders for storing data.
public extension Store {

    /// Returns a URL to a subfolder created in the documents directory based on the `pathComponent`.
    /// - Parameter pathComponent: A path to append to the platform's documents directory.
    static func documentsDirectory(appendingPath pathComponent: String) -> URL {
        DiskStorage.documentsDirectory(appendingPath: pathComponent)
    }

    /// Returns a URL to a subfolder created in the caches directory based on the `pathComponent`.
    /// - Parameter pathComponent: A path to append to the platform's caches directory.
    static func cachesDirectory(appendingPath pathComponent: String) -> URL {
        DiskStorage.cachesDirectory(appendingPath: pathComponent)
    }

    /// Returns a URL to a subfolder created in the temporary directory based on the `pathComponent`.
    /// - Parameter pathComponent: A path to append to the platform's temporary directory.
    static func temporaryDirectory(appendingPath pathComponent: String) -> URL {
        DiskStorage.temporaryDirectory(appendingPath: pathComponent)
    }

    /// For apps that use the App Groups feature this function returns a URL that
    /// appends a path to the app's group shared directory.
    ///
    /// - Parameters:
    ///   - identifier: The app's group identifier as declared in your app's App Groups Entitlement.
    ///   - pathComponent: A path to append to the app's group shared directory.
    /// - Returns: A URL to a subfolder created in the app's group shared directory.
    static func sharedContainerDirectory(forAppGroupIdentifier identifier: String, appendingPath pathComponent: String) -> URL {
        DiskStorage.sharedContainerDirectory(forAppGroupIdentifier: identifier, appendingPath: pathComponent)
    }

}
