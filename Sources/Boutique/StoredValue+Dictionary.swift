public extension StoredValue {

    /// A function to set a @``StoredValue`` represented by a `Dictionary`
    /// without having to manually make an intermediate copy for every value update.
    ///
    /// This is meant to provide a simple ergonomic improvement, avoiding callsites like this.
    /// ```
    /// var updatedRedPandaList = try await self.redPandaList
    /// updatedRedPandaList["best"] = "Pabu"
    /// self.$redPandaList.set(updatedRedPandaList)
    /// ```
    ///
    /// Instead having a much simpler alternative.
    /// ```
    /// try await self.$redPandaList.update(key: "best", value: "Pabu")
    /// ```
    func update<Key: Hashable, Value>(key: Key, value: Value?) where Item == [Key: Value] {
        var updatedDictionary = self.wrappedValue
        updatedDictionary[key] = value
        self.set(updatedDictionary)
    }

}

public extension AsyncStoredValue {

    /// A function to set an @``AsyncStoredValue`` represented by a `Dictionary`
    /// without having to manually make an intermediate copy for every value update.
    ///
    /// This is meant to provide a simple ergonomic improvement, avoiding callsites like this.
    /// ```
    /// var updatedRedPandaList = try await self.redPandaList
    /// updatedRedPandaList["best"] = "Pabu"
    /// try await self.$redPandaList.set(updatedRedPandaList)
    /// ```
    ///
    /// Instead having a much simpler alternative.
    /// ```
    /// try await self.$redPandaList.update(key: "best", value: "Pabu")
    /// ```
    func update<Key: Hashable, Value>(key: Key, value: Value?) async throws where Item == [Key: Value] {
        var updatedDictionary = self.wrappedValue
        updatedDictionary[key] = value
        try await self.set(updatedDictionary)
    }


}
