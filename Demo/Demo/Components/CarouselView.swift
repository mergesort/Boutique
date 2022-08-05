import SwiftUI

/// A View for displaying content in a horizontally scrolling grid.
struct CarouselView<Item: Identifiable, ContentView: View>: View {

    var items: [Item]
    var contentView: (Item) -> ContentView

    @EnvironmentObject private var focusController: ScrollFocusController<String>
    @State private var customPreferenceKey: String = ""

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { reader in
                HStack(alignment: .top, spacing: 16.0) {
                    ForEach(items) { item in
                        contentView(item)
                            .tag(item.id)
                    }
                }
                .onReceive(self.focusController.publisher, perform: { id in
                    if let id = id {
                        withAnimation {
                            reader.scrollTo(id)
                        }
                    }
                })
            }
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

}
