import Boutique
import Testing

extension Store {
    func validateStoreEvent(event: StoreEvent<BoutiqueItem>) throws {
        if self.items.isEmpty {
            try #require(event.operation == .initial || event.operation == .loaded || event.operation == .remove)
        } else {
            try #require(event.operation == .insert)
        }
    }
}
