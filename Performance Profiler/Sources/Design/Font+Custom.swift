import SwiftUI

extension Font {

    static func telegramaRaw(style: UIFont.TextStyle, weight: Font.Weight = .regular) -> Font {
        Font.custom(
            "Telegrama Raw",
            size: UIFont.preferredFont(forTextStyle: style).pointSize
        )
        .weight(weight)
    }

}
