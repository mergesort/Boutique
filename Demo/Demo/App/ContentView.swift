import SwiftUI

struct ContentView: View {
    @StateObject private var carouselFocusController = ScrollFocusController<String>()
    @StateObject private var imagesController = ImagesController()

    var body: some View {
        VStack(spacing: 0.0) {
            FavoritesCarouselView()
                .padding(.bottom, 8.0)
                .environmentObject(carouselFocusController)
                .environmentObject(imagesController)

            Divider()

            Spacer()

            RedPandaCardView()
                .environmentObject(carouselFocusController)
        }
        .padding(.horizontal, 16.0)
        .background(Color.palette.background)
    }
}
