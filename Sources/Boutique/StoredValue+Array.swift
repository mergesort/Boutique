public extension StoredValue {
    /// A function to append a @``StoredValue`` represented by an `Array`
    /// without having to manually make an intermediate copy for every value update.
    ///
    /// This is meant to provide a simple ergonomic improvement, avoiding callsites like this.
    /// ```
    /// var updatedRedPandaList = self.redPandaList
    /// updatedRedPandaList.append("Pabu")
    /// self.$redPandaList.set(updatedRedPandaList)
    /// ```
    ///
    /// Instead this function provides a much simpler alternative.
    /// ```
    /// try await self.$redPandaList.append("Pabu")
    /// ```
    func append<Value>(_ value: Value) where Item == [Value] {
        var updatedArray = self.wrappedValue
        updatedArray.append(value)
        self.set(updatedArray)
    }
}

public extension SecurelyStoredValue {
    /// A function to append a @``SecurelyStoredValue`` represented by an `Array`
    /// without having to manually make an intermediate copy for every value update.
    ///
    /// This is meant to provide a simple ergonomic improvement, avoiding callsites like this.
    /// ```
    /// var updatedRedPandaList = self.redPandaList
    /// updatedRedPandaList.append("Pabu")
    /// self.$redPandaList.set(updatedRedPandaList)
    /// ```
    ///
    /// Instead this function provides a much simpler alternative.
    /// ```
    /// try await self.$redPandaList.append("Pabu")
    /// ```
    ///
    /// To better match expected uses calling append on a currently nil SecurelyStoredValue
    /// will return a single element array of the passed in value, 
    /// rather than returning nil or throwing an error.
    func append<Value>(_ value: Value) throws where Item == [Value] {
        var updatedArray = self.wrappedValue ?? []
        updatedArray.append(value)
        try self.set(updatedArray)
    }
}

public extension AsyncStoredValue {
    /// A function to append a @``StoredValue`` represented by an `Array`
    /// without having to manually make an intermediate copy for every value update.
    ///
    /// This is meant to provide a simple ergonomic improvement, avoiding callsites like this.
    /// ```
    /// var updatedRedPandaList = self.redPandaList
    /// updatedRedPandaList.append("Pabu")
    /// self.$redPandaList.set(updatedRedPandaList)
    /// ```
    ///
    /// Instead this function provides a much simpler alternative.
    /// ```
    /// try await self.$redPandaList.append("Pabu")
    /// ```
    func append<Value>(_ value: Value) async throws where Item == [Value] {
        var updatedArray = self.wrappedValue
        updatedArray.append(value)
        try await self.set(updatedArray)
    }
}
