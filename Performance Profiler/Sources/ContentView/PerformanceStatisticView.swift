import SwiftUI

struct PerformanceStatisticView: View {
    let leadingText: String
    let trailingText: String

    @SizeClassDependentValue(regular: UIFont.TextStyle.title1, compact: UIFont.TextStyle.body) private var fontStyle

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(leadingText)
                .shadow(color: .palette.terminalYellow.opacity(0.7), radius: 2.0, x: 2.0, y: 2.0)

            Spacer()

            Text(trailingText)
                .shadow(color: .palette.terminalYellow.opacity(0.7), radius: 2.0, x: 2.0, y: 2.0)
        }
        .font(.telegramaRaw(style: fontStyle))
        .padding(.horizontal, 16.0)
    }
}
