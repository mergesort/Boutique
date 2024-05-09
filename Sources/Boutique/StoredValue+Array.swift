public extension StoredValue where Item: RangeReplaceableCollection {
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
    @MainActor
    func append(_ item: Item.Element) {
        var updatedArray = self.wrappedValue
        updatedArray.append(item)
        self.set(updatedArray)
    }

    @MainActor
    /// A function that takes a value and removes it from an array if that value exists in the array,
    /// or adds it to the array if the value doesn't exist.
    /// - Parameter value: The value to add or remove from an array.
    func togglePresence<Value: Equatable>(_ value: Value) where Item == [Value] {
        var updatedArray = self.wrappedValue
        updatedArray.togglePresence(value)
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
    @MainActor
    func append<Value>(_ value: Value) throws where Item == [Value] {
        var updatedArray = self.wrappedValue ?? []
        updatedArray.append(value)
        try self.set(updatedArray)
    }
}

public extension AsyncStoredValue where Item: RangeReplaceableCollection {
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
    func append(_ item: Item.Element) async throws {
        var updatedArray = self.wrappedValue
        updatedArray.append(item)
        try await self.set(updatedArray)
    }


    @MainActor
    /// A function that takes a value and removes it from an array if that value exists in the array,
    /// or adds it to the array if the value doesn't exist.
    /// - Parameter value: The value to add or remove from an array.
    func togglePresence<Value: Equatable>(_ value: Value) async throws where Item == [Value] {
        var updatedArray = self.wrappedValue
        updatedArray.togglePresence(value)
        try await self.set(updatedArray)
    }
}

private extension Array where Element: Equatable {
    /// Adds a tag to an array if the tag doesn't exist in the array, otherwise removes the tag from the array.
    /// This is useful for actions like a user tapping a button, where the current existence
    /// of the tag in the array may not be known.
    ///
    /// - Parameter tag: The tag to add or remove
    mutating func togglePresence(_ item: Element) {
        if self.contains(where: { $0 == item }) {
            self.removeAll(where: { $0 == item })
        } else {
            self.append(item)
        }
    }
}
