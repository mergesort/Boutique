import SwiftUI

extension Color {
    static let palette = Color.Palette()
}

extension Color {

    struct Palette {
        var terminalYellow: Color {
            Color(red: colorValue(242), green: colorValue(168), blue: colorValue(59))
        }

        var terminalOrange: Color {
            Color(red: colorValue(230), green: colorValue(94), blue: colorValue(41))
        }

        var terminalBackground: Color {
            Color(red: colorValue(20), green: colorValue(20), blue: colorValue(20))
        }

        var appBackground: Color {
            Color(red: colorValue(10), green: colorValue(10), blue: colorValue(10))
        }

        var add: Color {
            Color(red: colorValue(87), green: colorValue(189), blue: colorValue(83))
        }

        var remove: Color {
            Color(red: colorValue(153), green: colorValue(30), blue: colorValue(23))
        }

    }

}

// I'm too lazy to build a real palette for this project so with this mediocre code.
private extension Color {

    static func colorValue(_ fromRGBValue: Int) -> Double {
        return Double(fromRGBValue)/255.0
    }

}

