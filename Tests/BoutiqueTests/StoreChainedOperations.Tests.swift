@testable import Boutique
import Foundation
import Testing

@MainActor
@Suite("Store chained removal persistence")
struct StoreChainedRemovalTests {
    enum Backend: String, CaseIterable, Sendable {
        case disk, sqlite

        func makeStorage(directory: FileManager.Directory) throws -> any StorageEngine {
            switch self {
            case .disk:
                return DiskStorageEngine(directory: directory)
            case .sqlite:
                return try #require(SQLiteStorageEngine(directory: directory))
            }
        }
    }

    enum Removal: String, CaseIterable, Sendable {
        case all, oneItemBatch, multipleItemBatch
    }

    enum Insertion: String, CaseIterable, Sendable {
        case single, batch, emptyBatch
    }

    @Test("Chained removals preserve exact values after reopening", arguments: Backend.allCases, Removal.allCases)
    func chainedRemovalsPersist(backend: Backend, removal: Removal) async throws {
        for insertion in Insertion.allCases {
            let context = "backend=\(backend), removal=\(removal), insertion=\(insertion)"
            let directory = FileManager.Directory.temporary(appendingPath: "Boutique-ChainedRemoval-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: directory.url) }

            let storage = try backend.makeStorage(directory: directory)
            let store = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
            let first = Item(id: "first/é", payload: 1)
            let second = Item(id: "second", payload: 2)
            let keeper = Item(id: "keeper", payload: 3)
            let initial = [first, second, keeper]
            try await store.insert(initial)
            try #require(store.items == initial, "\(context)")
            try #require(await storage.keyCount() == initial.count, "\(context)")

            var operation: Store<Item>.Operation
            let survivors: [Item]
            switch removal {
            case .all:
                operation = try await store.removeAll()
                survivors = []
            case .oneItemBatch:
                operation = try await store.remove([first])
                survivors = [second, keeper]
            case .multipleItemBatch:
                operation = try await store.remove([first, second])
                survivors = [keeper]
            }

            let newItem = Item(id: "new", payload: 4)
            let otherNewItem = Item(id: "other-new", payload: 5)
            let inserted: [Item]
            switch insertion {
            case .single:
                operation = try await operation.insert(newItem)
                inserted = [newItem]
            case .batch:
                operation = try await operation.insert([newItem, otherNewItem])
                inserted = [newItem, otherNewItem]
            case .emptyBatch:
                operation = try await operation.insert([Item]())
                inserted = []
            }

            #expect(store.items == initial, "queued operations ran early: \(context)")
            try await operation.run()

            let expected = survivors + inserted
            #expect(store.items == expected, "\(context)")
            #expect(await storage.keyCount() == expected.count, "\(context)")

            let reopenedStorage = try backend.makeStorage(directory: directory)
            let reopened = try await Store<Item>(storage: reopenedStorage, cacheIdentifier: \.id)
            #expect(reopened.items.sorted(by: { $0.id < $1.id }) == expected.sorted(by: { $0.id < $1.id }), "reopened values: \(context)")
        }
    }
}

private extension StoreChainedRemovalTests {
    struct Item: Codable, Sendable, Equatable {
        let id: String
        let payload: Int
    }
}
