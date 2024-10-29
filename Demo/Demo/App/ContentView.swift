import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    @StateObject private var carouselFocusController = ScrollFocusController<String>()
    @State private var imagesController = ImagesController()

    var body: some View {
        VStack(spacing: 0.0) {
            FavoritesCarouselView()
                .padding(.bottom, 8.0)
                .environmentObject(carouselFocusController)
                .environment(imagesController)

            Divider()

            Spacer()

            RedPandaCardView()
                .environmentObject(carouselFocusController)
        }
        .padding(.horizontal, 16.0)
        .background(Color.palette.background)
        .onChange(of: self.appState.funkyRedPandaModeEnabled) { oldValue, newValue in
            print("Funky red panda mode was \(oldValue) and now is \(newValue)")
        }
    }
}
