import Foundation
import Observation

@Observable
@propertyWrapper
public final class StoredValue<Item: Codable> {
    private let defaultValue: Item
    private let key: String
    private let userDefaults: UserDefaults
    private let valueSubject: AsyncValueSubject<Item>
    private let cachedValue: CachedValue<Item>

    public init(wrappedValue: Item, key: String, storage userDefaults: UserDefaults = UserDefaults.standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.userDefaults = userDefaults

        let initialValue = Self.storedValue(forKey: key, userDefaults: userDefaults, defaultValue: defaultValue)
        self.valueSubject = AsyncValueSubject(initialValue)
        self.valueSubject.send(initialValue)

        self.cachedValue = CachedValue(retrieveValue: {
            Self.storedValue(forKey: key, userDefaults: userDefaults, defaultValue: initialValue)
        })
    }

    public var wrappedValue: Item {
        self.cachedValue.retrieveValue()
    }

    public var projectedValue: StoredValue<Item> { self }

    public var values: AsyncStream<Item> {
        self.valueSubject.values
    }

    @MainActor
    public func set(_ value: Item) {
        let boxedValue = BoxedValue(value: value)
        if let data = try? JSONCoders.encoder.encode(boxedValue) {
            self.userDefaults.set(data, forKey: self.key)
            self.cachedValue.set(value)
            self.valueSubject.send(value)
        }
    }

    @MainActor
    public func reset() {
        let boxedValue = BoxedValue(value: self.defaultValue)
        if let data = try? JSONCoders.encoder.encode(boxedValue) {
            self.userDefaults.set(data, forKey: self.key)
            self.cachedValue.set(self.defaultValue)
            self.valueSubject.send(self.defaultValue)
        }
    }
}

private extension StoredValue {
    static func storedValue(forKey key: String, userDefaults: UserDefaults, defaultValue: Item) -> Item {
        if let storedValue = userDefaults.object(forKey: key) as? Data,
           let boxedValue = try? JSONCoders.decoder.decode(BoxedValue<Item>.self, from: storedValue) {
            return boxedValue.value
        } else {
            return defaultValue
        }
    }
}
