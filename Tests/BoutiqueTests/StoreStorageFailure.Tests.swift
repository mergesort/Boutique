import Boutique
import Foundation
import Testing

@MainActor
struct StoreStorageFailureTests {
	@Test func diskReadFailureReachesLoadersAndBlocksMutationsUntilReopening() async throws {
		let root = FileManager.Directory.temporary(appendingPath: "StoreStorageFailureTests.\(UUID())")
		let directory = FileManager.Directory(url: root.url.appendingPathComponent("store"))
		let backup = root.url.appendingPathComponent("saved-store")
		let storage = DiskStorageEngine(directory: directory)
		let saved = Item(id: "saved", value: 1)
		let data = try JSONEncoder().encode(saved)
		let key = CacheKey(saved.id)

		defer { try? FileManager.default.removeItem(at: root.url) }

		try await storage.write(data, key: key)
		try FileManager.default.moveItem(at: directory.url, to: backup)
		try Data("Not a directory".utf8).write(to: directory.url)

		let store = Self.makeStore(storage: storage)

		await #expect(throws: CocoaError.self, performing: {
			try await store.itemsHaveLoaded()
		})

		await #expect(throws: CocoaError.self, performing: {
			_ = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
		})

		#expect(store.items.isEmpty)

		// Restore writable storage before mutations: their failure must come from
		// the failed load, not from a destination that still cannot be written.
		try FileManager.default.removeItem(at: directory.url)
		try FileManager.default.moveItem(at: backup, to: directory.url)

		await #expect(throws: CocoaError.self, performing: {
			try await store.insert(Item(id: "new", value: 2))
		})

		await #expect(throws: CocoaError.self, performing: {
			try await store.remove(saved)
		})

		#expect(store.items.isEmpty)

		let records = try await storage.readAllDataAndKeys()
		#expect(records.count == 1)
		#expect(records.first?.key.value == key.value)
		#expect(records.first?.data == data)

		let reopened = try await Store<Item>(storage: storage, cacheIdentifier: \.id)
		#expect(reopened.items == [saved])
	}
}

private extension StoreStorageFailureTests {
	static func makeStore(storage: DiskStorageEngine) -> Store<Item> {
		Store(storage: storage, cacheIdentifier: \.id)
	}

	struct Item: Codable, Equatable, Sendable {
		let id: String
		let value: Int
	}
}
