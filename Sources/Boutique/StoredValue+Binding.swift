import SwiftUI

public extension StoredValue {
    /// A convenient way to create a `Binding` from a `StoredValue`.
    ///
    /// - Returns: A `Binding<Item>` of the `StoredValue<Item>` provided.
    @MainActor
    var binding: Binding<Item> {
        Binding(get: {
            self.wrappedValue
        }, set: {
            self.projectedValue.set($0)
        })
    }
}

public extension SecurelyStoredValue {
    /// A convenient way to create a `Binding` from a `SecurelyStoredValue`.
    ///
    /// - Returns: A `Binding<Item?>` of the `SecurelyStoredValue<Item>` provided.
    @MainActor
    var binding: Binding<Item?> {
        Binding(get: {
            self.wrappedValue
        }, set: {
            try? self.projectedValue.set($0)
        })
    }
}

public extension AsyncStoredValue {
    /// A convenient way to create a `Binding` from an `AsyncStoredValue`.
    /// 
    /// - Returns: A `Binding<Item>` of the `AsyncStoredValue<Item>` provided.
    var binding: Binding<Item> {
        Binding(get: {
            self.wrappedValue
        }, set: { value in
            Task {
                try await self.projectedValue.set(value)
            }
        })
    }
}
