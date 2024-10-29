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
    func append(_ item: Item.Element) {
        var updatedArray = self.wrappedValue
        updatedArray.append(item)
        self.set(updatedArray)
    }

    /// A function that takes a value and removes it from an array if that value exists in the array,
    /// or adds it to the array if the value doesn't exist.
    /// - Parameter value: The value to add or remove from an array.
    func togglePresence<Value: Equatable>(_ value: Value) where Item == [Value] {
        var updatedArray = self.wrappedValue
        updatedArray.togglePresence(value)
        self.set(updatedArray)
    }
}

public extension StoredValue where Item: RangeReplaceableCollection, Item.Element: Equatable {
    /// A function to replace a value in a @``StoredValue`` represented by an `Array`
    /// without having to manually make an intermediate copy for every value update.
    ///
    /// This is meant to provide a simple ergonomic improvement, avoiding callsites like this.
    /// ```
    /// guard let index = self.redPandaList.firstIndex(where: { $0.name == "Himalaya" }) else return
    /// var updatedRedPandaList = self.redPandaList
    /// updatedRedPandaList[index] = RedPanda(name: "Pabu")
    /// self.$redPandaList.set(updatedRedPandaList)
    /// ```
    ///
    /// Instead this function provides a much simpler alternative.
    /// ```
    /// self.$redPandaList.replace(RedPanda(name: "Himalaya"), RedPanda(name: "Pabu"))
    /// ```
    @MainActor
    @discardableResult
    func replace(_ item: Item.Element, with updatedItem: Item.Element) -> Bool {
        guard let index = self.wrappedValue.firstIndex(where: { $0 == item }) else { return false }

        var updatedArray = self.wrappedValue
        updatedArray.remove(at: index)
        updatedArray.insert(updatedItem, at: index)
        self.set(updatedArray)

        return true
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

    /// A function to replace a value in a @``StoredValue`` represented by an `Array`
    /// without having to manually make an intermediate copy for every value update.
    ///
    /// This is meant to provide a simple ergonomic improvement, avoiding callsites like this.
    /// ```
    /// guard let index = self.redPandaList.firstIndex(where: { $0.name == "Himalaya" }) else return
    /// var updatedRedPandaList = self.redPandaList
    /// updatedRedPandaList[index] = RedPanda(name: "Pabu")
    /// self.$redPandaList.set(updatedRedPandaList)
    /// ```
    ///
    /// Instead this function provides a much simpler alternative.
    /// ```
    /// try self.$redPandaList.replace(RedPanda(name: "Himalaya"), RedPanda(name: "Pabu"))
    /// ```
    func replace<Value: Equatable>(_ item: Item.Element, with updatedItem: Item.Element) throws -> Bool where Item == [Value] {
        guard let array = self.wrappedValue else { return false }
        guard let index = array.firstIndex(where: { $0 == item }) else { return false }

        var updatedArray = array
        updatedArray.remove(at: index)
        updatedArray.insert(updatedItem, at: index)
        try self.set(updatedArray)

        return true
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
