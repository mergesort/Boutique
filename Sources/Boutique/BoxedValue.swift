import Combine
import Foundation

extension JSONEncoder {
    func encodeBoxedData<Item: Codable>(item: Item) throws -> Data {
        return try JSONCoders.encoder.encode(
            BoxedValue(value: item)
        )
    }
}

extension JSONDecoder {
    func decodeBoxedData<Item: Codable>(data: Data) throws -> Item {
        return try self.decode(
            BoxedValue.self, from: data
        )
        .value
    }
}

struct BoxedValue<T: Codable>: Codable {
    var value: T
}
