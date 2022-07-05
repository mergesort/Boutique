import Foundation

struct PerformanceStatisticItem: Identifiable {
    let title: String
    let measurement: String

    var id: UUID {
        UUID()
    }
}
