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
        .task({
            await self.monitorImageStoreEvents()
        })
    }
}

private extension ContentView {
    func monitorImageStoreEvents() async {
        for await value in self.imagesController.$images.events {
            switch value.operation {

            case .initial:
                print("[Store Event: initial] Our Images Store has initialized")

            case .loaded:
                print("[Store Event: loaded] Our Images Store has loaded with images", value.items.map(\.url))

            case .insert:
                print("[Store Event: insert] Our Images Store inserted images", value.items.map(\.url))

            case .remove:
                print("[Store Event: remove] Our Images Store removed images", value.items.map(\.url))
            }
        }
    }
}
