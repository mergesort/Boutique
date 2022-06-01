import Bodega
import Combine
import Foundation

public final class Store<Object: Codable & Equatable>: ObservableObject {

    private let storagePath: URL
    private let objectStorage: ObjectStorage
    private let cacheIdentifier: KeyPath<Object, String>
    private var cancellables = Set<AnyCancellable>()

    @MainActor @Published public private(set) var items: [Object] = []

    public init(storagePath: URL, cacheIdentifier: KeyPath<Object, String>) {
        self.storagePath = storagePath
        self.objectStorage = ObjectStorage(storagePath: storagePath)
        self.cacheIdentifier = cacheIdentifier

        self.$items
            .sink(receiveValue: { items in
                Task {
                    try await self.persistItems(items)
                }
            })
            .store(in: &cancellables)

        Task { @MainActor in
            self.items = await self.allPersistedItems()
        }
    }

    public func add(_ item: Object, invalidationStrategy: CacheInvalidationStrategy<Object> = .removeNone) async throws {
        try await self.add([item], invalidationStrategy: invalidationStrategy)
    }

    public func add(_ items: [Object], invalidationStrategy: CacheInvalidationStrategy<Object> = .removeNone) async throws {
        var currentItems: [Object] = await self.items

        try await self.removePersistedItems(strategy: invalidationStrategy)
        self.invalidateCache(strategy: invalidationStrategy, items: &currentItems)

        // Prevent duplicate values from being written multiple times.
        // This could cause a discrepancy between the data in memory
        // and on disk since files on the file system can't have
        // duplicate filenames but can be duplicated in memory.
        let uniqueItems = items.uniqueElements(matching: self.cacheIdentifier)
        var itemKeys = uniqueItems.map({ $0[keyPath: self.cacheIdentifier] })

        for item in uniqueItems {
            if let matchingIdentifierIndex = itemKeys.firstIndex(of: item[keyPath: self.cacheIdentifier]),
               case let matchingIdentifier = itemKeys[matchingIdentifierIndex],
               let index = currentItems.firstIndex(where: { $0[keyPath: self.cacheIdentifier] == matchingIdentifier }) {
                    // We found a matching element with potentially different data so replace it in-place
                    currentItems.remove(at: index)
                    currentItems.insert(item, at: index)
                } else {
                    // Append it to the cache if it doesn't already exist
                    currentItems.append(item)
                }

            itemKeys.removeAll(where: { $0 == item[keyPath: self.cacheIdentifier] })
        }

        // We can't capture a mutable array (currentItems) in the closure below so we make an immutable copy
        let itemsToSet = currentItems
        await MainActor.run {
            self.items = itemsToSet
        }
    }

    public func remove(_ item: Object) async throws {
        let itemKey = item[keyPath: self.cacheIdentifier]
        let cacheKey = CacheKey(itemKey)

        try await self.removePersistedItem(forKey: cacheKey)

        await MainActor.run {
            self.items.removeAll(where: {
                itemKey == $0[keyPath: self.cacheIdentifier]
            })
        }
    }

    public func remove(_ items: [Object]) async throws {
        let itemKeys = items.map { $0[keyPath: self.cacheIdentifier] }
        let cacheKeys = itemKeys.map({ CacheKey($0) })

        for cacheKey in cacheKeys {
            try await self.removePersistedItem(forKey: cacheKey)
        }

        await MainActor.run {
            self.items.removeAll(where: { item in
                itemKeys.contains(item[keyPath: self.cacheIdentifier])
            })
        }
    }

    public func removeAll() async throws {
        try await self.removeAllPersistedItems()

        await MainActor.run {
            self.items = []
        }
    }

}

private extension Store {

    func allPersistedItems() async -> [Object] {
        var items: [Object] = []

        for key in await self.objectStorage.allKeys() {
            if let object: Object = await self.objectStorage.object(forKey: key) {
                items.append(object)
            }
        }

        return items
    }

    func persistItems(_ items: [Object]) async throws {
        for item in items {
            try await self.objectStorage.store(item, forKey: CacheKey(item[keyPath: self.cacheIdentifier]))
        }
    }

    func removePersistedItem(forKey cacheKey: CacheKey) async throws {
        do {
            try await self.objectStorage.removeObject(forKey: cacheKey)
        } catch CocoaError.fileNoSuchFile {
            print("We treat deleting a non-existent file/folder as a successful removal rather than throwing")
        } catch {
            throw error
        }
    }

    func removeAllPersistedItems() async throws {
        do {
            try await self.objectStorage.removeAllObjects()
        } catch CocoaError.fileNoSuchFile {
            print("We treat deleting a non-existent file/folder as a successful removal rather than throwing")
        } catch {
            throw error
        }
    }

}

// MARK: Store.CacheInvalidationStrategy

public extension Store {

    enum CacheInvalidationStrategy<Object> {
        case removeNone
        case remove(items: [Object])
        case removeAll
    }

}

private extension Store {

    func invalidateCache(strategy: CacheInvalidationStrategy<Object>, items: inout [Object]) {
        switch strategy {

        case .removeNone:
            break

        case .remove(let itemsToRemove):
            items = items.filter({ !itemsToRemove.contains($0) })

        case .removeAll:
            items = []

        }
    }

    func removePersistedItems(strategy: CacheInvalidationStrategy<Object>) async throws {
        switch strategy {

        case .removeNone:
            break

        case .remove(let itemsToRemove):
            try await self.remove(itemsToRemove)

        case .removeAll:
            try await self.removeAllPersistedItems()

        }
    }

}

private extension Array where Element: Equatable {

    func uniqueElements(matching keyPath: KeyPath<Element, String>) -> [Element] {
        var result = [Element]()

        for element in self {
            if !result.contains(where: { $0[keyPath: keyPath] == element[keyPath: keyPath] }) {
                result.append(element)
            }
        }

        return result
    }

}
