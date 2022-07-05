import SwiftUI

struct TerminalView: View {
    let statistics: [PerformanceStatisticItem]

    var body: some View {
        VStack(spacing: 16.0) {
            Spacer().frame(height: 16.0)

            ForEach(statistics) { statistic in
                PerformanceStatisticView(
                    leadingText: statistic.title,
                    trailingText: statistic.measurement
                )
                .foregroundColor(Color.palette.terminalYellow)
            }

            Spacer().frame(height: 16.0)
        }
        .background(Color.palette.terminalBackground)
        .cornerRadius(16.0)
    }
}
