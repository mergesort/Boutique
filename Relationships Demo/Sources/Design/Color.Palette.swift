import SwiftUI

extension Color {
    static let palette = Color.Palette()
}

extension Color {
    struct Palette {
        var appBackground: Color {
            Color(red: colorValue(10), green: colorValue(10), blue: colorValue(10))
        }
    }
}

private extension Color {
    static func colorValue(_ fromRGBValue: Int) -> Double {
        return Double(fromRGBValue)/255.0
    }
}
