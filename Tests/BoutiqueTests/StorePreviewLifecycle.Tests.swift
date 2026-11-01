@testable import Boutique
import Foundation
import Testing

#if DEBUG
@MainActor
@Suite("Store preview lifecycle", .timeLimit(.minutes(1)))
struct StorePreviewLifecycleTests {
    enum Overload: String, CaseIterable, Sendable {
        case keypath, identifiable, uuid
    }

    @Test("Preview fixtures stay loaded and preview instances mutate independently", arguments: Overload.allCases)
    func suppliedFixturesSurviveLoading(overload: Overload) async throws {
        if overload == .uuid {
            let original = UUIDItem(id: UUID(), payload: 1)
            let added = UUIDItem(id: UUID(), payload: 2)
            let store = Store<UUIDItem>.previewStore(items: [original])
            let other = Store<UUIDItem>.previewStore(items: [original])
            try await self.verifyLifecycle(store: store, other: other, original: original, added: added)
        } else {
            let original = StringItem(id: "fixture", payload: 1)
            let added = StringItem(id: "added", payload: 2)
            let store = self.makeStringStore(items: [original], overload: overload)
            let other = self.makeStringStore(items: [original], overload: overload)
            try await self.verifyLifecycle(store: store, other: other, original: original, added: added)
        }
    }
}

private extension StorePreviewLifecycleTests {
    struct StringItem: Codable, Sendable, Equatable, Identifiable {
        let id: String
        let payload: Int
    }

    struct UUIDItem: Codable, Sendable, Equatable, Identifiable {
        let id: UUID
        let payload: Int
    }

    func makeStringStore(items: [StringItem], overload: Overload) -> Store<StringItem> {
        if overload == .keypath {
            return .previewStore(items: items, cacheIdentifier: \.id)
        }
        return .previewStore(items: items)
    }

    func verifyLifecycle<Item: StorableItem & Equatable>(store: Store<Item>, other: Store<Item>, original: Item, added: Item) async throws {
        #expect(store.items == [original])
        #expect(other.items == [original])
        var events = store.events.makeAsyncIterator()
        let loaded = await events.next()
        #expect(loaded?.operation == .loaded)
        #expect(loaded?.items == [original])

        try await store.itemsHaveLoaded()
        try await other.itemsHaveLoaded()
        #expect(store.items == [original])
        #expect(other.items == [original])

        try await store.insert(added)
        let insertion = await events.next()
        #expect(insertion?.operation == .insert)
        #expect(insertion?.items == [added])
        #expect(store.items == [original, added])
        #expect(other.items == [original])

        try await store.remove(original)
        let removal = await events.next()
        #expect(removal?.operation == .remove)
        #expect(removal?.items == [original])
        #expect(store.items == [added])

        try await store.removeAll()
        let clear = await events.next()
        #expect(clear?.operation == .remove)
        #expect(clear?.items == [added])
        #expect(store.items.isEmpty)
        #expect(other.items == [original])
        try await store.itemsHaveLoaded()
        #expect(store.items.isEmpty)
    }
}
#endif
