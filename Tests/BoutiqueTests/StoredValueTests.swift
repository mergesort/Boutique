import Boutique
import XCTest

final class StoredValueTests: XCTestCase {

    // make sure these actually work

    @StoredValue<BoutiqueItem>(key: "storedItem")
    private var storedItem

    @StoredValue<BoutiqueItem>(key: "defaultValueItem")
    private var defaultValueItem = BoutiqueItem.coat

    @StoredValue<BoutiqueItem>(key: "defaultNilValueItem")
    private var defaultNilValueItem = nil

    override func setUp() async throws {
        try await self.$storedItem.reset()
    }

    @MainActor
    func testStoredValueOperations() async throws {
        XCTAssertEqual(self.storedItem, nil)

        try await self.$storedItem.set(BoutiqueItem.belt)
        XCTAssertEqual(self.storedItem, BoutiqueItem.belt)

        try await self.$storedItem.reset()
        XCTAssertEqual(self.storedItem, nil)

        try await self.$storedItem.set(BoutiqueItem.sweater)
        XCTAssertEqual(self.storedItem, BoutiqueItem.sweater)
    }

    @MainActor
    func testDefaultValue() async throws {
        XCTAssertEqual(self.defaultValueItem, BoutiqueItem.coat)
        XCTAssertEqual(self.defaultNilValueItem, nil)
    }

}
