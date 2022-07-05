import SwiftUI

struct CountButton: View {

    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.title2)
            .buttonStyle(.borderedProminent)
            .foregroundColor(.white)
            .tint(color)
    }

}
