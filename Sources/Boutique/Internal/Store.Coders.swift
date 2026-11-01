import Foundation

extension Store {
    // Each store owns its coders on a separate actor. Store observation and events
    // remain on MainActor, while conversion of entire collections does not.
    actor Coders {
        private let encoder = JSONEncoder()
        private let decoder = JSONDecoder()

        func decode(_ data: [Data]) throws -> [Item] {
            try data.map({ try self.decoder.decode(Item.self, from: $0) })
        }

        func encode(_ item: Item) throws -> Data {
            try self.encoder.encode(item)
        }

        func encode(_ items: [Item]) throws -> [Data] {
            try items.map({ try self.encoder.encode($0) })
        }
    }
}
