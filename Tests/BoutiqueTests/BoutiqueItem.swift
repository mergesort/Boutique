import Foundation

struct BoutiqueItem: Codable, Equatable, Identifiable {
    var id: String {
        self.merchantID
    }

    let merchantID: String
    let value: String
}

extension BoutiqueItem {
    static let coat = BoutiqueItem(
        merchantID: "1",
        value: "Coat"
    )

    static let sweater = BoutiqueItem(
        merchantID: "2",
        value: "Sweater"
    )

    static let purse = BoutiqueItem(
        merchantID: "3",
        value: "Purse"
    )

    static let belt = BoutiqueItem(
        merchantID: "4",
        value: "Belt"
    )

    static let duplicateBelt = BoutiqueItem(
        merchantID: "4",
        value: "Belt"
    )
}

extension [BoutiqueItem] {
    static let allItems: [BoutiqueItem] = [
        .coat,
        .sweater,
        .purse,
        .belt,
        .duplicateBelt
    ]

    static let uniqueItems: [BoutiqueItem] = [
        .coat,
        .sweater,
        .purse,
        .belt,
    ]
}
