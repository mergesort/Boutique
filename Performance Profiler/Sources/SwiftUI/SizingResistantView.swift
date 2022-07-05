import SwiftUI

/// A wrapper to be used around buttons it's not their content size
/// that determines how a V/HStack sizes the Views.
struct SizingResistantView<Content: View>: View {
    var content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
    }
}
