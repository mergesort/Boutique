import Boutique
import Testing

extension Store {
    func validateStoreEvent(event: StoreEvent<BoutiqueItem>) throws {
        if self.items.isEmpty {
            try #require(event.operation == .initialized || event.operation == .loaded || event.operation == .remove)
        } else {
            try #require(event.operation == .insert)
        }
    }
}
