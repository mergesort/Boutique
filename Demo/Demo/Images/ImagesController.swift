import Boutique
import SwiftUI

// You may prefer to decouple a `Controller` from it's `Store`, and that's very easily doable.
// Instead of a property in the `Controller` such as `@Stored(in: Store.imagesStore) var images`
// you would instead create a `Controller` with a custom initializer takes in a `Store` like so.
//
// @Stored var images: [RemoteImage]
//
// init(store: Store<RemoteImage>) {
//     self._images = Stored(in: store)
// }
//
// And whenever you instantiate a `Controller` you provide it a `Store`.
// @StateObject private var imagesController = ImagesController(store: Store.imagesStore)

/// A controller that allows you to fetch images remotely, and save or delete them from a `Store`.
final class ImagesController: ObservableObject {
    /// The `Store` that we'll be using to save images.
    @Stored(in: .imagesStore) var images

    /// Fetches `RemoteImage` from the API, providing the user with a red panda if the request succeeds.
    /// - Returns: The `RemoteImage` requested.
    func fetchImage() async throws -> RemoteImage {
        // Hit the API that provides you a random image's metadata
        let imageURL = URL(string: "https://image.redpanda.club/random/json")!
        let randomImageRequest = URLRequest(url: imageURL)
        let (randomImageJSONData, _) = try await URLSession.shared.data(for: randomImageRequest)

        let imageResponse = try JSONDecoder().decode(RemoteImageResponse.self, from: randomImageJSONData)

        // Download the image at the URL we received from the API
        let imageRequest = URLRequest(url: imageResponse.url)
        let (imageData, _) = try await URLSession.shared.data(for: imageRequest)

        // Lazy error handling, sorry, please do it better in your app
        guard let pngData = UIImage(data: imageData)?.pngData() else { throw DownloadError.badData }

        return RemoteImage(createdAt: .now, url: imageResponse.url, width: imageResponse.width, height: imageResponse.height, dataRepresentation: pngData)
    }

    /// Saves an image to the `Store` in memory and on disk.
    /// - Parameter image: A `RemoteImage` to be saved.
    func saveImage(image: RemoteImage) async throws {
        try await self.$images.insert(image)
    }

    // This function is unused but I wanted to demonstrate how you can chain operations together
    func saveImageAfterClearingCache(image: RemoteImage) async throws {
        try await self.$images
            .removeAll()
            .insert(image)
            .run()
    }

    /// Removes one image from the `Store` in memory and on disk.
    /// - Parameter image: A `RemoteImage` to be removed.
    func removeImage(image: RemoteImage) async throws {
        try await self.$images.remove(image)
    }

    /// Removes all of the images from the `Store` in memory and on disk.
    func clearAllImages() async throws {
        try await self.$images.removeAll()
    }
}

extension ImagesController {
    /// A few simple errors we can throw in case we receive bad data.
    enum DownloadError: Error {
        case badData
        case unexpectedStatusCode
    }
}

private extension ImagesController {
    /// A type representing the API response providing image metadata from the API we're interacting with.
    struct RemoteImageResponse: Codable {
        let width: Float
        let height: Float
        let key: String
        let url: URL
    }
}
