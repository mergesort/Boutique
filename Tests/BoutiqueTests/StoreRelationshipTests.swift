@testable import Boutique
import Testing

@MainActor
@Suite("Store Relationship Tests", .serialized)
struct StoreRelationshipTests {
    @Test("Updating a parent replaces matching values in child arrays")
    func testUpdateReplacesMatchingValuesInChildArrays() async throws {
        let tagsStore = Self.makeTagsStore()
        let linksStore = Self.makeLinksStore()

        try await tagsStore.removeAll()
        try await linksStore.removeAll()

        tagsStore.addRelationship(updating: \.tags, in: linksStore)

        try await tagsStore.insert([.swift, .design])
        try await linksStore.insert([
            .boutique(tags: [.swift, .design], featuredTag: .swift),
            .plinky(tags: [.design], featuredTag: .design)
        ])

        try await tagsStore.insert(.updatedSwift)

        try #require(linksStore.items.count == 2)
        #expect(linksStore.items[0].tags == [.updatedSwift, .design])
        #expect(linksStore.items[0].featuredTag == .swift)
        #expect(linksStore.items[1].tags == [.design])
    }

    @Test("Updating a parent replaces matching optional child values")
    func testUpdateReplacesMatchingOptionalChildValues() async throws {
        let tagsStore = Self.makeTagsStore()
        let linksStore = Self.makeLinksStore()

        try await tagsStore.removeAll()
        try await linksStore.removeAll()

        tagsStore.addRelationship(updating: \.featuredTag, in: linksStore)

        try await tagsStore.insert([.swift, .design])
        try await linksStore.insert([
            .boutique(tags: [.swift, .design], featuredTag: .swift),
            .plinky(tags: [.design], featuredTag: .design)
        ])

        try await tagsStore.insert(.updatedSwift)

        try #require(linksStore.items.count == 2)
        #expect(linksStore.items[0].tags == [.swift, .design])
        #expect(linksStore.items[0].featuredTag == .updatedSwift)
        #expect(linksStore.items[1].featuredTag == .design)
    }

    @Test("Removing a parent clears matching values from child arrays")
    func testRemoveClearsMatchingValuesFromChildArrays() async throws {
        let tagsStore = Self.makeTagsStore()
        let linksStore = Self.makeLinksStore()

        try await tagsStore.removeAll()
        try await linksStore.removeAll()

        tagsStore.addRelationship(clearing: \.tags, in: linksStore)

        try await tagsStore.insert([.swift, .design])
        try await linksStore.insert([
            .boutique(tags: [.swift, .design], featuredTag: .swift),
            .plinky(tags: [.design], featuredTag: .design)
        ])

        try await tagsStore.remove(.swift)

        try #require(linksStore.items.count == 2)
        #expect(linksStore.items[0].tags == [.design])
        #expect(linksStore.items[0].featuredTag == .swift)
        #expect(linksStore.items[1].tags == [.design])
    }

    @Test("Removing a parent nullifies matching optional child values")
    func testRemoveNullifiesMatchingOptionalChildValues() async throws {
        let tagsStore = Self.makeTagsStore()
        let linksStore = Self.makeLinksStore()

        try await tagsStore.removeAll()
        try await linksStore.removeAll()

        tagsStore.addRelationship(nullifying: \.featuredTag, in: linksStore)

        try await tagsStore.insert([.swift, .design])
        try await linksStore.insert([
            .boutique(tags: [.swift, .design], featuredTag: .swift),
            .plinky(tags: [.design], featuredTag: .design)
        ])

        try await tagsStore.remove(.swift)

        try #require(linksStore.items.count == 2)
        #expect(linksStore.items[0].tags == [.swift, .design])
        #expect(linksStore.items[0].featuredTag == nil)
        #expect(linksStore.items[1].featuredTag == .design)
    }

    @Test("Removing multiple parents updates child stores in one batch")
    func testRemoveMultipleParentsUpdatesChildStoresInOneBatch() async throws {
        let tagsStore = Self.makeTagsStore()
        let linksStore = Self.makeLinksStore()

        try await tagsStore.removeAll()
        try await linksStore.removeAll()

        tagsStore.addRelationship(clearing: \.tags, in: linksStore)
        tagsStore.addRelationship(nullifying: \.featuredTag, in: linksStore)

        try await tagsStore.insert([.swift, .design, .offline])
        try await linksStore.insert([
            .boutique(tags: [.swift, .design, .offline], featuredTag: .swift),
            .plinky(tags: [.design, .offline], featuredTag: .design)
        ])

        try await tagsStore.remove([.swift, .design])

        try #require(linksStore.items.count == 2)
        #expect(linksStore.items[0].tags == [.offline])
        #expect(linksStore.items[0].featuredTag == nil)
        #expect(linksStore.items[1].tags == [.offline])
        #expect(linksStore.items[1].featuredTag == nil)
    }

    @Test("Removing a stale parent value propagates the stored value")
    func testRemoveStaleParentValuePropagatesStoredValue() async throws {
        let tagsStore = Self.makeTagsStore()
        let linksStore = Self.makeLinksStore()

        try await tagsStore.removeAll()
        try await linksStore.removeAll()

        tagsStore.addRelationship(clearing: \.tags, in: linksStore)
        tagsStore.addRelationship(nullifying: \.featuredTag, in: linksStore)

        try await tagsStore.insert(.updatedSwift)
        try await linksStore.insert(.boutique(tags: [.updatedSwift], featuredTag: .updatedSwift))

        try await tagsStore.remove(.swift)

        try #require(linksStore.items.count == 1)
        #expect(linksStore.items[0].tags == [])
        #expect(linksStore.items[0].featuredTag == nil)
    }

    @Test("Removing stale parent values in a batch propagates stored values")
    func testRemoveStaleParentValuesInBatchPropagatesStoredValues() async throws {
        let tagsStore = Self.makeTagsStore()
        let linksStore = Self.makeLinksStore()

        try await tagsStore.removeAll()
        try await linksStore.removeAll()

        tagsStore.addRelationship(clearing: \.tags, in: linksStore)
        tagsStore.addRelationship(nullifying: \.featuredTag, in: linksStore)

        try await tagsStore.insert([.updatedSwift, .updatedDesign, .offline])
        try await linksStore.insert([
            .boutique(tags: [.updatedSwift, .updatedDesign], featuredTag: .updatedSwift),
            .plinky(tags: [.updatedDesign, .offline], featuredTag: .updatedDesign)
        ])

        try await tagsStore.remove([.swift, .design])

        try #require(linksStore.items.count == 2)
        #expect(linksStore.items[0].tags == [])
        #expect(linksStore.items[0].featuredTag == nil)
        #expect(linksStore.items[1].tags == [.offline])
        #expect(linksStore.items[1].featuredTag == nil)
    }

    @Test("Remove all then insert updates replacements and removes missing parents")
    func testRemoveAllThenInsertUpdatesReplacementsAndRemovesMissingParents() async throws {
        let tagsStore = Self.makeTagsStore()
        let linksStore = Self.makeLinksStore()

        try await tagsStore.removeAll()
        try await linksStore.removeAll()

        tagsStore.addRelationship(updating: \.tags, in: linksStore)
        tagsStore.addRelationship(updating: \.featuredTag, in: linksStore)
        tagsStore.addRelationship(clearing: \.tags, in: linksStore)
        tagsStore.addRelationship(nullifying: \.featuredTag, in: linksStore)

        try await tagsStore.insert([.swift, .design, .offline])
        try await linksStore.insert([
            .boutique(tags: [.swift, .design], featuredTag: .swift),
            .plinky(tags: [.design, .offline], featuredTag: .design)
        ])

        try await tagsStore.removeAll().insert([.updatedSwift, .offline]).run()

        try #require(linksStore.items.count == 2)
        #expect(linksStore.items[0].tags == [.updatedSwift])
        #expect(linksStore.items[0].featuredTag == .updatedSwift)
        #expect(linksStore.items[1].tags == [.offline])
        #expect(linksStore.items[1].featuredTag == nil)
    }

    @Test("Remove then insert updates replacements and removes missing parents")
    func testRemoveThenInsertUpdatesReplacementsAndRemovesMissingParents() async throws {
        let tagsStore = Self.makeTagsStore()
        let linksStore = Self.makeLinksStore()

        try await tagsStore.removeAll()
        try await linksStore.removeAll()

        tagsStore.addRelationship(updating: \.tags, in: linksStore)
        tagsStore.addRelationship(updating: \.featuredTag, in: linksStore)
        tagsStore.addRelationship(clearing: \.tags, in: linksStore)
        tagsStore.addRelationship(nullifying: \.featuredTag, in: linksStore)

        var observedUpdateCount = 0
        var observedRemoveCount = 0

        tagsStore.addRelationship(to: linksStore, on: .update) { changes, _ in
            observedUpdateCount = changes.count
        }
        tagsStore.addRelationship(to: linksStore, on: .remove) { changes, _ in
            observedRemoveCount = changes.count
        }

        try await tagsStore.insert([.swift, .design, .offline])
        try await linksStore.insert([
            .boutique(tags: [.swift, .design, .offline], featuredTag: .swift),
            .plinky(tags: [.design, .offline], featuredTag: .design)
        ])

        try await tagsStore.remove([.swift, .design]).insert([.updatedSwift]).run()

        try #require(linksStore.items.count == 2)
        #expect(linksStore.items[0].tags == [.updatedSwift, .offline])
        #expect(linksStore.items[0].featuredTag == .updatedSwift)
        #expect(linksStore.items[1].tags == [.offline])
        #expect(linksStore.items[1].featuredTag == nil)
        #expect(observedUpdateCount == 1)
        #expect(observedRemoveCount == 1)
    }

    @Test("Custom relationships receive parent changes and child store")
    func testCustomRelationshipsReceiveParentChangesAndChildStore() async throws {
        let tagsStore = Self.makeTagsStore()
        let linksStore = Self.makeLinksStore()

        try await tagsStore.removeAll()
        try await linksStore.removeAll()

        var observedChanges = [StoreRelationshipChange<RelationshipTag>]()
        var observedChildCount = 0

        tagsStore.addRelationship(to: linksStore, on: .update) { changes, linksStore in
            observedChanges = changes
            observedChildCount = linksStore.items.count
        }

        try await tagsStore.insert(.swift)
        try await linksStore.insert(.boutique(tags: [.swift], featuredTag: .swift))

        try await tagsStore.insert(.updatedSwift)

        #expect(observedChanges.count == 1)
        #expect(observedChanges.first?.oldValue == .swift)
        #expect(observedChanges.first?.newValue == .updatedSwift)
        #expect(observedChildCount == 1)
    }
}

private extension StoreRelationshipTests {
    static func makeTagsStore() -> Store<RelationshipTag> {
        Store<RelationshipTag>(
            storage: SQLiteStorageEngine.default(appendingPath: "RelationshipTests/Tags"),
            cacheIdentifier: \.id
        )
    }

    static func makeLinksStore() -> Store<RelationshipLink> {
        Store<RelationshipLink>(
            storage: SQLiteStorageEngine.default(appendingPath: "RelationshipTests/Links"),
            cacheIdentifier: \.id
        )
    }
}

private struct RelationshipTag: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let title: String
}

private extension RelationshipTag {
    static let swift = RelationshipTag(id: "swift", title: "Swift")
    static let updatedSwift = RelationshipTag(id: "swift", title: "SwiftUI")
    static let design = RelationshipTag(id: "design", title: "Design")
    static let updatedDesign = RelationshipTag(id: "design", title: "Design Systems")
    static let offline = RelationshipTag(id: "offline", title: "Offline")
}

private struct RelationshipLink: Codable, Equatable, Sendable, Identifiable {
    let id: String
    var title: String
    var tags: [RelationshipTag]
    var featuredTag: RelationshipTag?
}

private extension RelationshipLink {
    static func boutique(tags: [RelationshipTag], featuredTag: RelationshipTag?) -> RelationshipLink {
        RelationshipLink(id: "boutique", title: "Boutique", tags: tags, featuredTag: featuredTag)
    }

    static func plinky(tags: [RelationshipTag], featuredTag: RelationshipTag?) -> RelationshipLink {
        RelationshipLink(id: "plinky", title: "Plinky", tags: tags, featuredTag: featuredTag)
    }
}
