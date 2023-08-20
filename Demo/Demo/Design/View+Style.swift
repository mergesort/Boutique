import SwiftUI

extension View {
    func centerCroppedCardStyle() -> some View {
        self.scaledToFill()
            .clipped()
            .cornerRadius(8.0)
    }

    func primaryBorder() -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 8.0)
                .stroke(Color.palette.primary, lineWidth: 4.0)
        )
    }
}
