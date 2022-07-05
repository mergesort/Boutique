import SwiftUI

extension View {

    func ghostEffectShadow(_ color: Color) -> some View {
        self.shadow(color: color.opacity(0.7), radius: 2.0, x: 2.0, y: 2.0)
    }

    func textShadow() -> some View {
        self.ghostEffectShadow(Color.white)
    }

}
