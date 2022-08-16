import Boutique
import Combine
import XCTest

final class StoredValueTests: XCTestCase {

    private var cancellables: Set<AnyCancellable> = []

    @StoredValue<BoutiqueItem>(key: "storedItem")
    private var storedItem = BoutiqueItem.coat

    @StoredValue<BoutiqueItem?>(key: "storedNilValue")
    private var storedNilValue = nil

    @StoredValue(key: "storedBoolValue")
    private var storedBoolValue = false

    override func setUp() {
        self.$storedItem.reset()
        self.$storedNilValue.reset()
        self.$storedBoolValue.reset()
    }

    func testStoredValueOperations() async throws {
        XCTAssertEqual(self.storedItem, BoutiqueItem.coat)

        self.$storedItem.set(BoutiqueItem.belt)
        XCTAssertEqual(self.storedItem, BoutiqueItem.belt)

        self.$storedItem.reset()
        XCTAssertEqual(self.storedItem, BoutiqueItem.coat)

        self.$storedItem.set(BoutiqueItem.sweater)
        XCTAssertEqual(self.storedItem, BoutiqueItem.sweater)
    }

    func testStoredNilValue() async throws {
        XCTAssertEqual(self.storedNilValue, nil)

        self.$storedNilValue.set(BoutiqueItem.belt)
        XCTAssertEqual(self.storedNilValue, BoutiqueItem.belt)

        self.$storedNilValue.reset()
        XCTAssertEqual(self.storedNilValue, nil)

        self.$storedNilValue.set(BoutiqueItem.sweater)
        XCTAssertEqual(self.storedNilValue, BoutiqueItem.sweater)
    }

    func testStoredBoolValueToggle() async throws {
        XCTAssertEqual(self.storedBoolValue, false)

        self.$storedBoolValue.toggle()
        XCTAssertEqual(self.storedBoolValue, true)

        self.$storedBoolValue.set(false)
        XCTAssertEqual(self.storedBoolValue, false)

        self.$storedBoolValue.toggle()
        XCTAssertEqual(self.storedBoolValue, true)
    }

    func testPublishedValueSubscription() async throws {
        let expectation = XCTestExpectation(description: "@StoredValue publishes values correctly")

        var values: [BoutiqueItem] = []

        self.$storedItem.publisher
            .sink(receiveValue: { item in
                values.append(item)

                if values.count == 4 {
                    XCTAssertEqual(values, [BoutiqueItem.coat, .purse, .sweater, .belt])
                    expectation.fulfill()
                }
            })
            .store(in: &cancellables)

        self.$storedItem.set(BoutiqueItem.purse)
        self.$storedItem.set(BoutiqueItem.sweater)
        self.$storedItem.set(BoutiqueItem.belt)

        wait(for: [expectation], timeout: 1)
    }

}
