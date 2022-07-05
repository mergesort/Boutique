import Foundation

public struct RichNote: Codable, Equatable {
    public var id: String
    public let createdAt: Date
    public let updatedAt: Date
    public let isSynchronized: Bool
    public let title: String
    public let attachedURL: URL
    public let text: String
    public let tags: [Tag]
    public let annotations: [Annotation]
    public let imageAttachment: Image?
}

extension RichNote {

    static var demoNote: RichNote {
        RichNote(
            id: UUID().uuidString,
            createdAt: .now.addingTimeInterval(-72000),
            updatedAt: .now,
            isSynchronized: false,
            title: "Birthday Party Plans",
            attachedURL: URL(string: "https://xkcd.com/1581/")!,
            text: String.loremIpsum.random,
            tags: [
                Tag(title: "Dwight", color: "#FAFAFA"),
                Tag(title: "Pam", color: "#ACABFF"),
                Tag(title: "Jim", color: "#888888"),
                Tag(title: "Angela", color: "#001248"),
                Tag(title: "Shared", color: "#11CC11")
            ],
            annotations: [
                Annotation(
                    text: String.loremIpsum.tenWords
                ),
                Annotation(
                    text: String.loremIpsum.twentyFiveWords
                ),
                Annotation(
                    text: String.loremIpsum.fiftyWords
                )
            ],
            imageAttachment: Image(url: URL(string: "https://imgs.xkcd.com/comics/birthday_2x.png")!, width: 635, height: 871)
        )
    }

}

public struct Tag: Codable, Equatable {
    let title: String
    let color: String
}

public struct Annotation: Codable, Equatable {
    let text: String
}

public struct Image: Codable, Equatable {
    let url: URL
    let width: Float
    let height: Float
}

extension String {

    static var loremIpsum: LoremIpsum { LoremIpsum() }

    struct LoremIpsum {

    }

}

extension String.LoremIpsum {

    var tenWords: String {
        return "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Aenean commodo"
    }

    var twentyFiveWords: String {
        return "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur"
    }

    var fiftyWords: String {
        return "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Donec quam felis, ultricies nec, pellentesque eu, pretium quis, sem. Nulla consequat massa quis enim. Donec pede justo, fringilla vel, aliquet nec, vulputate"
    }

    var oneHundredWords: String {
        return "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Donec quam felis, ultricies nec, pellentesque eu, pretium quis, sem. Nulla consequat massa quis enim. Donec pede justo, fringilla vel, aliquet nec, vulputate eget, arcu. In enim justo, rhoncus ut, imperdiet a, venenatis vitae, justo. Nullam dictum felis eu pede mollis pretium. Integer tincidunt. Cras dapibus. Vivamus elementum semper nisi. Aenean vulputate eleifend tellus. Aenean leo ligula, porttitor eu, consequat vitae, eleifend ac, enim. Aliquam lorem ante, dapibus in, viverra quis, feugiat a"
    }

    var random: String {
        return [self.tenWords, self.twentyFiveWords, self.fiftyWords, self.oneHundredWords].randomElement() ?? self.twentyFiveWords
    }
}
