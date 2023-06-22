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
    /// Instead having a much simpler alternative.
    /// ```
    /// try await self.$redPandaList.append("Pabu")
    /// ```
    func append<Value>(_ value: Value) where Item == [Value] {
        var updatedArray = self.wrappedValue
        updatedArray.append(value)
        self.set(updatedArray)
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
    /// Instead having a much simpler alternative.
    /// ```
    /// try await self.$redPandaList.append("Pabu")
    /// ```
    func append<Value>(_ value: Value) async throws where Item == [Value] {
        var updatedArray = self.wrappedValue
        updatedArray.append(value)
        try await self.set(updatedArray)
    }
}
