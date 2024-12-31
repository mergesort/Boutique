import Foundation

/// `CachedValue` exists internally for the purpose of creating a reference value, preventing the need
/// to create a `JSONDecoder` and invoke a decode step every time we need to access a `StoredValue` externally.
internal final class CachedValue<Item: Codable> {
    private var cachedValue: Item?
    public var retrieveValue: () -> Item

    init(retrieveValue: @escaping () -> Item) {
        self.retrieveValue = retrieveValue
        self.cachedValue = self.retrieveValue()
    }

    func set(_ value: Item) {
        self.cachedValue = value
    }

    var wrappedValue: Item? {
        if let cachedValue {
            cachedValue
        } else {
            self.retrieveValue()
        }
    }
}
