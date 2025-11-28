@testable import Boutique
import Testing
import Foundation

// MARK: - Test Models

struct Tag: Codable, Sendable, Equatable, Identifiable {
    let id: String
    var name: String
    var color: String
}

struct RichLink: Codable, Sendable, Equatable, Identifiable {
    let id: String
    var url: String
    var tags: [Tag]
}

struct Article: Codable, Sendable, Equatable, Identifiable {
    let id: String
    var title: String
    var primaryTag: Tag?
}

struct Document: Codable, Sendable, Equatable, Identifiable {
    let id: String
    var title: String
    var category: Tag
}

// MARK: - Test Data

extension Tag {
    static let productivity = Tag(id: "1", name: "Productivity", color: "blue")
    static let design = Tag(id: "2", name: "Design", color: "purple")
    static let coding = Tag(id: "3", name: "Coding", color: "green")
    static let research = Tag(id: "4", name: "Research", color: "orange")

    static let updatedProductivity = Tag(id: "1", name: "Productivity Pro", color: "darkblue")
}

extension RichLink {
    static let link1 = RichLink(
        id: "link1",
        url: "https://example.com/1",
        tags: [.productivity, .design]
    )

    static let link2 = RichLink(
        id: "link2",
        url: "https://example.com/2",
        tags: [.coding, .productivity]
    )

    static let link3 = RichLink(
        id: "link3",
        url: "https://example.com/3",
        tags: [.design]
    )

    static let link4 = RichLink(
        id: "link4",
        url: "https://example.com/4",
        tags: []
    )
}

extension Article {
    static let article1 = Article(
        id: "article1",
        title: "Getting Started",
        primaryTag: .productivity
    )

    static let article2 = Article(
        id: "article2",
        title: "Advanced Topics",
        primaryTag: .coding
    )

    static let article3 = Article(
        id: "article3",
        title: "No Tag Article",
        primaryTag: nil
    )
}

extension Document {
    static let doc1 = Document(
        id: "doc1",
        title: "Design Guidelines",
        category: .design
    )

    static let doc2 = Document(
        id: "doc2",
        title: "Code Review",
        category: .coding
    )
}

// MARK: - Array Relationship Tests

@MainActor
@Suite("Store Relationship Tests - Array", .serialized)
struct StoreRelationshipArrayTests {
    private var tagsStore: Store<Tag>!
    private var richLinksStore: Store<RichLink>!

    init() async throws {
        func makeTagsStore() -> Store<Tag> {
            Store<Tag>(
                storage: SQLiteStorageEngine.default(appendingPath: "RelationshipTests/Tags"),
                cacheIdentifier: \.id
            )
        }

        func makeRichLinksStore() -> Store<RichLink> {
            Store<RichLink>(
                storage: SQLiteStorageEngine.default(appendingPath: "RelationshipTests/RichLinks"),
                cacheIdentifier: \.id
            )
        }

        tagsStore = makeTagsStore()
        richLinksStore = makeRichLinksStore()

        try await tagsStore.removeAll()
        try await richLinksStore.removeAll()
    }

    @Test("Test nullify action on remove with array relationship")
    func testNullifyOnRemove() async throws {
        // Insert tags and links
        try await tagsStore.insert([.productivity, .design, .coding])
        try await richLinksStore.insert([.link1, .link2, .link3, .link4])

        // Establish relationship: when a tag is removed, remove it from all RichLink.tags arrays
        tagsStore.addRelationship(
            when: .onRemove,
            to: richLinksStore,
            via: \.tags,
            action: .nullify
        )

        // Wait a bit for the relationship to be established
        try await Task.sleep(for: .milliseconds(100))

        // Remove the productivity tag
        try await tagsStore.remove(.productivity)

        // Wait for the relationship handler to process
        try await Task.sleep(for: .milliseconds(100))

        // Verify the productivity tag was removed from link1 and link2
        let updatedLink1 = richLinksStore.items.first(where: { $0.id == "link1" })
        let updatedLink2 = richLinksStore.items.first(where: { $0.id == "link2" })
        let updatedLink3 = richLinksStore.items.first(where: { $0.id == "link3" })
        let updatedLink4 = richLinksStore.items.first(where: { $0.id == "link4" })

        #expect(updatedLink1?.tags.count == 1)
        #expect(updatedLink1?.tags.contains(.design) == true)
        #expect(updatedLink1?.tags.contains(.productivity) == false)

        #expect(updatedLink2?.tags.count == 1)
        #expect(updatedLink2?.tags.contains(.coding) == true)
        #expect(updatedLink2?.tags.contains(.productivity) == false)

        #expect(updatedLink3?.tags.count == 1)
        #expect(updatedLink3?.tags.contains(.design) == true)

        #expect(updatedLink4?.tags.isEmpty == true)
    }

    @Test("Test delete action on remove with array relationship")
    func testDeleteOnRemove() async throws {
        // Insert tags and links
        try await tagsStore.insert([.productivity, .design, .coding])
        try await richLinksStore.insert([.link1, .link2, .link3, .link4])

        // Establish relationship: when a tag is removed, delete any RichLink that contains it
        tagsStore.addRelationship(
            when: .onRemove,
            to: richLinksStore,
            via: \.tags,
            action: .delete
        )

        try await Task.sleep(for: .milliseconds(100))

        // Remove the productivity tag
        try await tagsStore.remove(.productivity)

        try await Task.sleep(for: .milliseconds(100))

        // Verify link1 and link2 were deleted (they had the productivity tag)
        #expect(richLinksStore.items.count == 2)
        #expect(richLinksStore.items.contains(where: { $0.id == "link1" }) == false)
        #expect(richLinksStore.items.contains(where: { $0.id == "link2" }) == false)
        #expect(richLinksStore.items.contains(where: { $0.id == "link3" }) == true)
        #expect(richLinksStore.items.contains(where: { $0.id == "link4" }) == true)
    }

    @Test("Test update action on insert with array relationship")
    func testUpdateOnInsert() async throws {
        // Insert original tags
        try await tagsStore.insert([.productivity, .design, .coding])

        // Insert links with the original tags
        try await richLinksStore.insert([.link1, .link2])

        // Establish relationship: when a tag is updated, update it in all RichLink.tags arrays
        tagsStore.addRelationship(
            when: .onInsert,
            to: richLinksStore,
            via: \.tags,
            action: .update
        )

        try await Task.sleep(for: .milliseconds(100))

        // Update the productivity tag
        try await tagsStore.insert(.updatedProductivity)

        try await Task.sleep(for: .milliseconds(100))

        // Verify the productivity tag was updated in link1 and link2
        let updatedLink1 = richLinksStore.items.first(where: { $0.id == "link1" })
        let updatedLink2 = richLinksStore.items.first(where: { $0.id == "link2" })

        let link1ProductivityTag = updatedLink1?.tags.first(where: { $0.id == "1" })
        let link2ProductivityTag = updatedLink2?.tags.first(where: { $0.id == "1" })

        #expect(link1ProductivityTag?.name == "Productivity Pro")
        #expect(link1ProductivityTag?.color == "darkblue")

        #expect(link2ProductivityTag?.name == "Productivity Pro")
        #expect(link2ProductivityTag?.color == "darkblue")
    }

    @Test("Test onChange event handles both insert and remove")
    func testOnChange() async throws {
        // Insert tags and links
        try await tagsStore.insert([.productivity, .design])
        try await richLinksStore.insert([.link1, .link2])

        // Establish relationship with onChange
        tagsStore.addRelationship(
            when: .onChange,
            to: richLinksStore,
            via: \.tags,
            action: .nullify
        )

        try await Task.sleep(for: .milliseconds(100))

        // Test remove
        try await tagsStore.remove(.productivity)
        try await Task.sleep(for: .milliseconds(100))

        let afterRemove = richLinksStore.items.first(where: { $0.id == "link1" })
        #expect(afterRemove?.tags.contains(.productivity) == false)
        #expect(afterRemove?.tags.contains(.design) == true)

        // Insert the coding tag (not in any links yet, so no changes expected)
        try await tagsStore.insert(.coding)
        try await Task.sleep(for: .milliseconds(100))

        // No changes should occur since .nullify on insert doesn't do anything
        let afterInsert = richLinksStore.items.first(where: { $0.id == "link1" })
        #expect(afterInsert?.tags.count == 1)
    }

    @Test("Test batch operations are used")
    func testBatchOperations() async throws {
        // Create many links with the same tag
        var links: [RichLink] = []
        for i in 0..<100 {
            links.append(RichLink(
                id: "link\(i)",
                url: "https://example.com/\(i)",
                tags: [.productivity]
            ))
        }

        try await tagsStore.insert(.productivity)
        try await richLinksStore.insert(links)

        tagsStore.addRelationship(
            when: .onRemove,
            to: richLinksStore,
            via: \.tags,
            action: .nullify
        )

        try await Task.sleep(for: .milliseconds(100))

        // Remove the tag - this should use batch operations
        try await tagsStore.remove(.productivity)
        try await Task.sleep(for: .milliseconds(200))

        // All links should have empty tags
        for link in richLinksStore.items {
            #expect(link.tags.isEmpty)
        }
    }
}

// MARK: - Optional Relationship Tests

@MainActor
@Suite("Store Relationship Tests - Optional", .serialized)
struct StoreRelationshipOptionalTests {
    private var tagsStore: Store<Tag>!
    private var articlesStore: Store<Article>!

    init() async throws {
        func makeTagsStore() -> Store<Tag> {
            Store<Tag>(
                storage: SQLiteStorageEngine.default(appendingPath: "RelationshipTests/TagsOptional"),
                cacheIdentifier: \.id
            )
        }

        func makeArticlesStore() -> Store<Article> {
            Store<Article>(
                storage: SQLiteStorageEngine.default(appendingPath: "RelationshipTests/Articles"),
                cacheIdentifier: \.id
            )
        }

        tagsStore = makeTagsStore()
        articlesStore = makeArticlesStore()

        try await tagsStore.removeAll()
        try await articlesStore.removeAll()
    }

    @Test("Test nullify action on remove with optional relationship")
    func testNullifyOnRemove() async throws {
        try await tagsStore.insert([.productivity, .coding])
        try await articlesStore.insert([.article1, .article2, .article3])

        tagsStore.addRelationship(
            when: .onRemove,
            to: articlesStore,
            via: \.primaryTag,
            action: .nullify
        )

        try await Task.sleep(for: .milliseconds(100))

        try await tagsStore.remove(.productivity)
        try await Task.sleep(for: .milliseconds(100))

        let updatedArticle1 = articlesStore.items.first(where: { $0.id == "article1" })
        let updatedArticle2 = articlesStore.items.first(where: { $0.id == "article2" })
        let updatedArticle3 = articlesStore.items.first(where: { $0.id == "article3" })

        #expect(updatedArticle1?.primaryTag == nil)
        #expect(updatedArticle2?.primaryTag == .coding)
        #expect(updatedArticle3?.primaryTag == nil)
    }

    @Test("Test delete action on remove with optional relationship")
    func testDeleteOnRemove() async throws {
        try await tagsStore.insert([.productivity, .coding])
        try await articlesStore.insert([.article1, .article2, .article3])

        tagsStore.addRelationship(
            when: .onRemove,
            to: articlesStore,
            via: \.primaryTag,
            action: .delete
        )

        try await Task.sleep(for: .milliseconds(100))

        try await tagsStore.remove(.productivity)
        try await Task.sleep(for: .milliseconds(100))

        #expect(articlesStore.items.count == 2)
        #expect(articlesStore.items.contains(where: { $0.id == "article1" }) == false)
        #expect(articlesStore.items.contains(where: { $0.id == "article2" }) == true)
        #expect(articlesStore.items.contains(where: { $0.id == "article3" }) == true)
    }

    @Test("Test update action on insert with optional relationship")
    func testUpdateOnInsert() async throws {
        try await tagsStore.insert(.productivity)
        try await articlesStore.insert([.article1, .article3])

        tagsStore.addRelationship(
            when: .onInsert,
            to: articlesStore,
            via: \.primaryTag,
            action: .update
        )

        try await Task.sleep(for: .milliseconds(100))

        try await tagsStore.insert(.updatedProductivity)
        try await Task.sleep(for: .milliseconds(100))

        let updatedArticle1 = articlesStore.items.first(where: { $0.id == "article1" })
        let updatedArticle3 = articlesStore.items.first(where: { $0.id == "article3" })

        #expect(updatedArticle1?.primaryTag?.name == "Productivity Pro")
        #expect(updatedArticle1?.primaryTag?.color == "darkblue")
        #expect(updatedArticle3?.primaryTag == nil)
    }
}

// MARK: - Required Relationship Tests

@MainActor
@Suite("Store Relationship Tests - Required", .serialized)
struct StoreRelationshipRequiredTests {
    private var tagsStore: Store<Tag>!
    private var documentsStore: Store<Document>!

    init() async throws {
        func makeTagsStore() -> Store<Tag> {
            Store<Tag>(
                storage: SQLiteStorageEngine.default(appendingPath: "RelationshipTests/TagsRequired"),
                cacheIdentifier: \.id
            )
        }

        func makeDocumentsStore() -> Store<Document> {
            Store<Document>(
                storage: SQLiteStorageEngine.default(appendingPath: "RelationshipTests/Documents"),
                cacheIdentifier: \.id
            )
        }

        tagsStore = makeTagsStore()
        documentsStore = makeDocumentsStore()

        try await tagsStore.removeAll()
        try await documentsStore.removeAll()
    }

    @Test("Test delete action on remove with required relationship")
    func testDeleteOnRemove() async throws {
        try await tagsStore.insert([.design, .coding])
        try await documentsStore.insert([.doc1, .doc2])

        // Required fields can only be deleted, not nullified
        tagsStore.addRelationship(
            when: .onRemove,
            to: documentsStore,
            via: \.category,
            action: .delete
        )

        try await Task.sleep(for: .milliseconds(100))

        try await tagsStore.remove(.design)
        try await Task.sleep(for: .milliseconds(100))

        #expect(documentsStore.items.count == 1)
        #expect(documentsStore.items.contains(where: { $0.id == "doc1" }) == false)
        #expect(documentsStore.items.contains(where: { $0.id == "doc2" }) == true)
    }

    @Test("Test update action on insert with required relationship")
    func testUpdateOnInsert() async throws {
        try await tagsStore.insert(.design)
        try await documentsStore.insert(.doc1)

        tagsStore.addRelationship(
            when: .onInsert,
            to: documentsStore,
            via: \.category,
            action: .update
        )

        try await Task.sleep(for: .milliseconds(100))

        let updatedDesign = Tag(id: "2", name: "Design Master", color: "violet")
        try await tagsStore.insert(updatedDesign)
        try await Task.sleep(for: .milliseconds(100))

        let updatedDoc1 = documentsStore.items.first(where: { $0.id == "doc1" })

        #expect(updatedDoc1?.category.name == "Design Master")
        #expect(updatedDoc1?.category.color == "violet")
    }
}

// MARK: - Custom Comparison Tests

@MainActor
@Suite("Store Relationship Tests - Custom Comparison", .serialized)
struct StoreRelationshipCustomComparisonTests {
    private var tagsStore: Store<Tag>!
    private var richLinksStore: Store<RichLink>!

    init() async throws {
        func makeTagsStore() -> Store<Tag> {
            Store<Tag>(
                storage: SQLiteStorageEngine.default(appendingPath: "RelationshipTests/TagsCustom"),
                cacheIdentifier: \.id
            )
        }

        func makeRichLinksStore() -> Store<RichLink> {
            Store<RichLink>(
                storage: SQLiteStorageEngine.default(appendingPath: "RelationshipTests/RichLinksCustom"),
                cacheIdentifier: \.id
            )
        }

        tagsStore = makeTagsStore()
        richLinksStore = makeRichLinksStore()

        try await tagsStore.removeAll()
        try await richLinksStore.removeAll()
    }

    @Test("Test custom comparison function")
    func testCustomComparison() async throws {
        try await tagsStore.insert([.productivity, .design])
        try await richLinksStore.insert([.link1])

        // Custom comparison that compares by name instead of id
        let customComparison: (Tag, Tag) -> Bool = { lhs, rhs in
            lhs.name == rhs.name
        }

        tagsStore.addRelationship(
            when: .onRemove,
            to: richLinksStore,
            via: \.tags,
            action: .nullify,
            compareUsing: customComparison
        )

        try await Task.sleep(for: .milliseconds(100))

        // Create a tag with different id but same name
        let productivityWithDifferentId = Tag(id: "999", name: "Productivity", color: "red")
        try await tagsStore.remove(productivityWithDifferentId)
        try await Task.sleep(for: .milliseconds(100))

        // The productivity tag should still be removed from link1 because names match
        let updatedLink1 = richLinksStore.items.first(where: { $0.id == "link1" })
        #expect(updatedLink1?.tags.count == 1)
        #expect(updatedLink1?.tags.contains(.design) == true)
    }
}
