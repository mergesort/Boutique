import Boutique
import SwiftUI

/// A view that displays a `RemoteImage`.
struct RemoteImageView: View {

    var image: RemoteImage

    var body: some View {
        let currentImage = UIImage(data: image.dataRepresentation) ?? UIImage()

        Image(uiImage: currentImage)
            .resizable()
    }

}
