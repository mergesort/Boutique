import Foundation

extension StoredValue {
    /// A function to set the value of a property inside of a @``StoredValue`` object
    /// without having to manually make an intermediate copy for every value update.
    ///
    /// This is meant to provide a simple ergonomic improvement for complex objects,
    /// avoiding callsites like this.
    ///
    /// ```
    /// struct 3DCoordinates: Codable {
    ///     let x: Double
    ///     let y: Double
    ///     let z: Double
    /// }
    ///
    /// var coordinates = self.coordinates
    /// coordinates.x = 1.0
    /// self.$coordinates.set(coordinates)
    /// ```
    ///
    /// Instead this function provides a much simpler alternative.
    /// ```
    /// self.$coordinates.set(\.x, to: 1.0)
    /// ```
    public func set<Value>(_ keyPath: WritableKeyPath<Item, Value>, to value: Value) {
        var updatedValue = self.wrappedValue
        updatedValue[keyPath: keyPath] = value
        self.set(updatedValue)
    }
}

extension SecurelyStoredValue {
    /// A function to set the value of a property inside of a @``StoredValue`` object
    /// without having to manually make an intermediate copy for every value update.
    ///
    /// This is meant to provide a simple ergonomic improvement for complex objects,
    /// avoiding callsites like this.
    ///
    /// ```
    /// struct 3DCoordinates: Codable {
    ///     let x: Double
    ///     let y: Double
    ///     let z: Double
    /// }
    ///
    /// var coordinates = self.coordinates
    /// coordinates.x = 1.0
    /// try self.$coordinates.set(coordinates)
    /// ```
    ///
    /// Instead this function provides a much simpler alternative.
    /// ```
    /// try self.$coordinates.set(\.x, to: 1.0)
    /// ```
    public func set<Value>(_ keyPath: WritableKeyPath<Item, Value>, to value: Value) throws {
        if let wrappedValue {
            var updatedValue = wrappedValue
            updatedValue[keyPath: keyPath] = value
            try self.set(updatedValue)
        } else {
            throw KeychainError.couldNotAccessKeychain
        }
    }
}
