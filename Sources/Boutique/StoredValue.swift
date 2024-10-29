import Foundation
import Observation

@Observable
@MainActor
@propertyWrapper
public final class StoredValue<Item: Codable & Sendable> {
    private let observationRegistrar = ObservationRegistrar()

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

    public convenience init(key: String, default defaultValue: Item, storage userDefaults: UserDefaults = UserDefaults.standard) {
        self.init(wrappedValue: defaultValue, key: key, storage: userDefaults)
    }

    public var wrappedValue: Item {
        get {
            self.retrieveItem()
        }
        set {
            self.persistItem(newValue)
        }
    }

    public var projectedValue: StoredValue<Item> { self }

    public var values: AsyncStream<Item> {
        self.valueSubject.values
    }

    public func set(_ item: Item) {
        self.persistItem(item)
    }

    public func reset() {
        self.persistItem(self.defaultValue)
    }
}

private extension StoredValue {
    func retrieveItem() -> Item {
        observationRegistrar.access(self, keyPath: \.wrappedValue)

        return self.cachedValue.retrieveValue()
    }

    func persistItem(_ item: Item) {
        observationRegistrar.willSet(self, keyPath: \.wrappedValue)

        // Persist the new value
        let boxedValue = BoxedValue(value: item)
        if let data = try? JSONCoders.encoder.encode(boxedValue) {
            self.userDefaults.set(data, forKey: self.key)
            self.cachedValue.set(item)
            self.valueSubject.send(item)

            observationRegistrar.didSet(self, keyPath: \.wrappedValue)
        }
    }

    static func storedValue(forKey key: String, userDefaults: UserDefaults, defaultValue: Item) -> Item {
        if let storedValue = userDefaults.data(forKey: key),
           let boxedValue = try? JSONCoders.decoder.decode(BoxedValue<Item>.self, from: storedValue) {
            return boxedValue.value
        } else {
            return defaultValue
        }
    }
}
